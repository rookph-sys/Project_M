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

var _settle_timer := 0.0
var _is_settled := true
var _force_settle := false
var _force_ramp := 0.0
var _mesh: MeshInstance3D
var _halo: MeshInstance3D = null
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
	sm.radial_segments = 24
	sm.rings = 12
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def["color"]
	mat.metallic = 0.25
	mat.roughness = 0.18
	mat.rim_enabled = true
	mat.rim = 0.5
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


func _physics_process(delta: float) -> void:
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
