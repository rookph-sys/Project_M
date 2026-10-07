class_name Marble
extends RigidBody3D

## Runtime marble. Owns settle detection (§31) and ring/hole/arena state (§36-39).

signal settled(marble: Marble)
signal captured(marble: Marble, reason: String)
signal hit_marble(other: Marble, impact_speed: float)
signal hit_surface(body: Node, impact_speed: float)

enum State { RESERVE, PLACED, ACTIVE, CAPTURED, SUNK, LOST }

# §31 settle thresholds
const SETTLE_LINEAR := 0.035
const SETTLE_ANGULAR := 0.60
const SETTLE_HOLD := 0.30

# §31 velocity floor — kills the 5-second exponential tail.
# Kept deliberately low and sharp: the floor removes a *fixed* distance from
# every shot, so a wide floor bends the power->distance curve away from linear
# and makes soft shots feel disproportionately weak.
const FLOOR_SPEED := 0.25
const FLOOR_DECEL := 0.80

var def_id := "standard"
var def: Dictionary
var state: State = State.RESERVE
var is_target := false
var owner_id := -1            # 0 player, 1 AI, -1 neutral target
var shot_this_turn := false
var has_triggered_stop_ability := false
var is_anchored := false

var _settle_timer := 0.0
var _is_settled := true
var _force_settle := false
var _force_ramp := 0.0
var _mesh: MeshInstance3D
var _halo: MeshInstance3D = null
var _marker: Label3D = null
var _contact_cooldown := 0.0
var _pending_linear := Vector3.ZERO
var _pending_angular := Vector3.ZERO
var _pending_add := Vector3.ZERO
var _has_pending := false


func setup(id: String, as_target: bool) -> void:
	def_id = id
	def = MarbleData.get_def(id)
	is_target = as_target

	mass = def["mass"]
	# §2 G-1 — MUST be REPLACE. The default COMBINE adds the world's default
	# damping on top, which silently shortens every travel distance.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = def["lin_damp"]
	angular_damp = def["ang_damp"]

	# §2 — engine sleep is off; we decide when a marble has settled.
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8

	var pm := PhysicsMaterial.new()
	pm.friction = def["friction"]
	pm.bounce = def["bounce"]
	physics_material_override = pm

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = MarbleData.RADIUS
	shape.shape = sphere
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = MarbleData.RADIUS
	sm.height = MarbleData.RADIUS * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	_mesh.mesh = sm
	# §51 — colourful glass on a dark table. At ~45px a marble reads by its
	# highlight and rim, not by surface detail, so the budget goes into a tight
	# specular and a strong rim rather than texture.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def["color"]
	mat.metallic = 0.35
	mat.metallic_specular = 0.85
	mat.roughness = 0.08
	mat.rim_enabled = true
	mat.rim = 0.85
	mat.rim_tint = 0.3
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.9
	mat.clearcoat_roughness = 0.05
	var glow: Color = def["color"]
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 0.12
	_mesh.material_override = mat
	add_child(_mesh)

	body_entered.connect(_on_body_entered)


## §16 — fire. Linear impulse plus the matching rolling spin, so the marble
## never goes through a sliding phase (that phase is what makes travel
## distance depend on friction instead of damping, and the curve non-linear).
func launch(direction: Vector3, power: float) -> void:
	var p: float = maxf(power, MarbleData.MIN_POWER)
	var dir := direction.normalized()
	var impulse := MarbleData.impulse_for(def_id, p)

	# Queued, not written here. A marble is often placed and fired within the
	# same frame (submit_shot, and the AI later), and a velocity written before
	# the body has finished registering with the physics space is silently
	# dropped — the marble then only has its spin and crawls a metre instead of
	# travelling five. _integrate_forces always runs with the body live.
	var v := dir * (impulse / mass)
	_pending_linear = v
	_pending_angular = Vector3.UP.cross(v) / MarbleData.RADIUS
	_has_pending = true

	state = State.ACTIVE
	shot_this_turn = true
	_is_settled = false
	_settle_timer = 0.0


## Applied inside the physics server, where the body is guaranteed live.
func _integrate_forces(st: PhysicsDirectBodyState3D) -> void:
	if _has_pending:
		st.linear_velocity = _pending_linear
		st.angular_velocity = _pending_angular
		_has_pending = false
	if _pending_add != Vector3.ZERO:
		st.linear_velocity += _pending_add
		_pending_add = Vector3.ZERO


## Override direction while keeping speed — used by Pinpoint, which sends the
## struck marble along the line the shooter was aimed at.
func redirect(dir: Vector2, speed_scale: float = 1.0) -> void:
	var speed := linear_velocity.length() * speed_scale
	var v := Vector3(dir.x, 0.0, dir.y).normalized() * speed
	_pending_linear = v
	_pending_angular = Vector3.UP.cross(v) / MarbleData.RADIUS
	_has_pending = true
	wake()


## Anchor: the marble stops being pushable for the rest of the match. It still
## blocks — that is the whole point — but nothing can shift it again.
func anchor() -> void:
	is_anchored = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	if _halo:
		_halo.scale = Vector3(1.25, 1.0, 1.25)


## Nudge an already-resting marble (the magnet pulse, §30).
func add_velocity(v: Vector3) -> void:
	_pending_add += v
	wake()


func wake() -> void:
	_is_settled = false
	_settle_timer = 0.0


func is_resting() -> bool:
	return _is_settled


func force_settle() -> void:
	if _is_settled:
		return
	_force_settle = true
	_force_ramp = 0.0


func _physics_process(_delta: float) -> void:
	# Use the FIXED step, never the delta handed in: Engine.time_scale scales
	# that delta while Jolt keeps integrating on its own fixed tick. Reading the
	# scaled value made damping and settle detection disagree with the engine,
	# so slow motion quietly changed how far a marble travelled.
	var delta := 1.0 / float(Engine.physics_ticks_per_second)
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)

	if state == State.CAPTURED or state == State.SUNK or state == State.LOST:
		return

	var speed := linear_velocity.length()

	# §35 — force settle ramps velocity down over 0.30 s rather than snapping,
	# so a marble never freezes mid-roll on the ring line.
	if _force_settle:
		_force_ramp += delta
		var k: float = clampf(1.0 - _force_ramp / 0.30, 0.0, 1.0)
		linear_velocity *= k
		angular_velocity *= k
		if _force_ramp >= 0.30:
			_snap_to_rest()
			return

	# §31 velocity floor — constant deceleration under 0.5 m/s. Exponential
	# damping alone asymptotes and leaves ~1.7 s of near-motionless crawl.
	elif speed > 0.0 and speed < FLOOR_SPEED:
		var drop := FLOOR_DECEL * delta
		if drop >= speed:
			linear_velocity = Vector3.ZERO
		else:
			linear_velocity -= linear_velocity.normalized() * drop

	if _is_settled:
		return

	if linear_velocity.length() <= SETTLE_LINEAR and angular_velocity.length() <= SETTLE_ANGULAR:
		_settle_timer += delta
		if _settle_timer >= SETTLE_HOLD:
			_snap_to_rest()
	else:
		_settle_timer = 0.0


# §32 — zero out so there is no end-of-shot jitter.
func _snap_to_rest() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_is_settled = true
	_force_settle = false
	_settle_timer = 0.0
	settled.emit(self)


func mark_captured(reason: String) -> void:
	if state == State.CAPTURED or state == State.SUNK or state == State.LOST:
		return
	state = State.CAPTURED if reason == "ring_out" else (State.SUNK if reason == "sunk" else State.LOST)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	# §36 — stop interacting with live marbles, but stay in the scene until the
	# shot has fully resolved. Removing a body mid-resolution changes the
	# outcome of every collision after it.
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(2, false)
	_is_settled = true
	captured.emit(self, reason)


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(_mesh, "scale", Vector3.ZERO, 0.18)
	t.tween_callback(queue_free)


## Ground ring marking whose marble this is. Drawn on the floor rather than on
## the sphere, because the sphere is rolling — a mark on the marble itself
## would tumble and the colour would read as part of the marble.
## §71 — a shape tag so ownership does not depend on telling red from blue.
func set_marker(tag: String) -> void:
	if tag == "":
		return
	_marker = Label3D.new()
	_marker.text = tag
	_marker.font_size = 64
	_marker.pixel_size = 0.0016
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.modulate = Color(1, 1, 1, 0.95)
	_marker.outline_size = 18
	_marker.outline_modulate = Color(0, 0, 0, 0.9)
	_marker.top_level = true
	add_child(_marker)


func set_owner_halo(color: Color) -> void:
	_halo = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.120
	t.outer_radius = 0.155
	t.rings = 24
	_halo.mesh = t
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo.material_override = mat
	# top_level so the halo does not tumble with the marble it follows.
	_halo.top_level = true
	add_child(_halo)


func _process(_delta: float) -> void:
	_update_trail()
	_update_squash()
	if _marker:
		_marker.global_position = global_position + Vector3(0, 0.17, 0)
		_marker.visible = state != State.CAPTURED and state != State.SUNK \
				and state != State.LOST
	if _halo == null:
		return
	if state == State.CAPTURED or state == State.SUNK or state == State.LOST:
		_halo.visible = false
		return
	_halo.global_position = global_position - Vector3(0, MarbleData.RADIUS - 0.006, 0)


func _on_body_entered(body: Node) -> void:
	if _contact_cooldown > 0.0:
		return
	_contact_cooldown = 0.02
	var impact := linear_velocity.length()
	if body is Marble:
		impact = (linear_velocity - (body as Marble).linear_velocity).length()
		hit_marble.emit(body as Marble, impact)
	else:
		hit_surface.emit(body, impact)


# --------------------------------------------------------------- trail ----
#
# §2.4. A fading ribbon behind a moving marble. It costs nothing when the
# marble is at rest, which is most of the time.

const TRAIL_MIN_SPEED := 0.9
const TRAIL_POINTS := 14

var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array[Vector3] = []


func enable_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = mat
	add_child(_trail)


func _update_trail() -> void:
	if _trail == null:
		return
	var speed := linear_velocity.length()
	if speed > TRAIL_MIN_SPEED:
		_trail_pts.append(global_position)
		while _trail_pts.size() > TRAIL_POINTS:
			_trail_pts.pop_front()
	elif not _trail_pts.is_empty():
		_trail_pts.pop_front()

	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return

	var col: Color = def["color"]
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_pts.size():
		var t := float(i) / float(_trail_pts.size() - 1)
		# Taper to nothing at the tail so it reads as motion, not a stick.
		var half: float = MarbleData.RADIUS * 0.75 * t
		var dir: Vector3 = (_trail_pts[mini(i + 1, _trail_pts.size() - 1)] - _trail_pts[maxi(i - 1, 0)])
		dir.y = 0.0
		if dir.length() < 0.0001:
			dir = Vector3.FORWARD
		var side := dir.normalized().cross(Vector3.UP) * half
		var p: Vector3 = _trail_pts[i]
		p.y = 0.02
		_trail_mesh.surface_set_color(Color(col.r, col.g, col.b, 0.55 * t * t))
		_trail_mesh.surface_add_vertex(p - side)
		_trail_mesh.surface_set_color(Color(col.r, col.g, col.b, 0.55 * t * t))
		_trail_mesh.surface_add_vertex(p + side)
	_trail_mesh.surface_end()


# ------------------------------------------------- squash and stretch ----
#
# §2.4. A rigid sphere that hits something and stays perfectly round reads as
# weightless. The collider never changes — only the mesh — so this is purely
# cosmetic and cannot affect a result.

var _squash := 0.0
var _squash_axis := Vector3.FORWARD


func squash(direction: Vector3, strength: float) -> void:
	if _mesh == null:
		return
	_squash_axis = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	_squash = clampf(maxf(_squash, strength), 0.0, 1.0)


func _update_squash() -> void:
	if _mesh == null:
		return
	if _squash <= 0.001:
		if _mesh.scale != Vector3.ONE:
			_mesh.scale = Vector3.ONE
			_mesh.basis = Basis.IDENTITY
		return
	_squash = maxf(0.0, _squash - 0.085)

	# Flatten along the impact axis, bulge across it, conserving volume enough
	# that it reads as rubber rather than as a scaling bug.
	var k: float = _squash * 0.42
	var along := 1.0 - k
	var across := 1.0 + k * 0.55
	var b := Basis.looking_at(_squash_axis, Vector3.UP)
	_mesh.transform = Transform3D(b.scaled(Vector3(across, across, along)), Vector3.ZERO)
