extends Node3D

## Project Marbles — Phase 1 playable (SPEC-PvE-v0.3 §75).
##
## In scope: arena, 6 marbles, placement, aim, power, flick, rolling physics,
## settle detection, ring out, holes, scoring, restart.
## Not in scope: AI, Knockout, deck builder, save, campaign.

const ARENA_W := 7.20
const ARENA_D := 4.80
const RING_R := 1.45
const OUT_MARGIN := 0.08
const KILL_Y := -0.30

# §12 launch zone
const LZ_X := 2.80
const LZ_Z_NEAR := -2.05
const LZ_Z_FAR := -1.65

const PLACE_MIN_DIST := 0.21
const RING_OUT_DIST := RING_R + MarbleData.RADIUS  # 1.55
const HOLE_CAPTURE := 0.16
const HOLE_VISUAL := 0.18
const BUMPER_R := 0.18
const BUMPER_H := 0.30

const MAX_DRAG := 1.40          # metres of drag for 100% power
const RESOLVE_STABLE := 0.20    # §34
const SWEEP_START := 3.00     # §35 start retiring stragglers
const SOFT_TIMEOUT := 7.00
const HARD_TIMEOUT := 11.0

enum St { PLACE, AIM, RESOLVE, AI_TURN, WON, LOST }

const ACTOR_PLAYER := 0
const ACTOR_AI := 1

const HALO_PLAYER := Color(0.25, 0.62, 1.00)
const HALO_AI := Color(1.00, 0.28, 0.26)

var state: St = St.PLACE
var level_idx := 0
var level: Dictionary

var bag: Array[String] = []
var bag_used: Array[bool] = []
var selected := 0

# Knockout only: the AI keeps its own bag and launches from the far strip.
var ai_bag: Array[String] = []
var ai_bag_used: Array[bool] = []
var ai_selected := 0
var turn_actor := ACTOR_PLAYER
var match_points := [0, 0]
var is_versus := false        # player vs AI, alternating turns
var has_ring := false         # red targets scored by ring-out
var _ai: MarbleAI = null

var shots_left := 0
var goal := 0
var progress := 0
var score := 0

var marbles: Array[Marble] = []
var targets: Array[Marble] = []
var holes: Array[Vector2] = []

var _held: Marble = null          # placed, not yet fired
var _aiming := false
var _aim_dir := Vector3.FORWARD
var _aim_power := 0.0
var _mouse_world := Vector3.ZERO

var _resolve_time := 0.0
var _stable_time := 0.0
var _shot_ctx := {}

var _cam: Camera3D
var _cam_home := Vector3(0.0, 4.20, -3.55)
var _cam_shake := 0.0
var _audio: MarbleAudio
var _hud: CanvasLayer
var _ghost: MeshInstance3D
var _aim_line: MeshInstance3D
var _pull_line: MeshInstance3D
var _lz_vis: MeshInstance3D
var _dynamic: Node3D
var _debug := false


func _ready() -> void:
	_register_actions()
	_build_static_world()
	_audio = MarbleAudio.new()
	add_child(_audio)
	_hud = preload("res://scripts/hud.gd").new()
	add_child(_hud)
	load_level(_start_level())


## `--level N` jumps straight into a level, so a duel can be opened without
## pressing N five times. Also handy for testing a single stage.
func _start_level() -> int:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.begins_with("--level="):
			return int(a.substr(8)) - 1
		if a == "--level" and i + 1 < args.size():
			return int(args[i + 1]) - 1
	return 0


# §71 — gameplay never queries raw keys; everything goes through actions.
func _register_actions() -> void:
	var defs := {
		"shoot": [MOUSE_BUTTON_LEFT],
		"cancel": [MOUSE_BUTTON_RIGHT],
	}
	for name in defs:
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name)
		for btn in defs[name]:
			var e := InputEventMouseButton.new()
			e.button_index = btn
			InputMap.action_add_event(name, e)

	var keys := {
		"restart": KEY_R, "next_level": KEY_N, "prev_level": KEY_P,
		"debug": KEY_F1, "quit": KEY_ESCAPE,
	}
	for name in keys:
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name)
		var e := InputEventKey.new()
		e.physical_keycode = keys[name]
		InputMap.action_add_event(name, e)

	for i in 8:
		var n := "slot_%d" % (i + 1)
		if InputMap.has_action(n):
			continue
		InputMap.add_action(n)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_1 + i
		InputMap.action_add_event(n, e)


# ---------------------------------------------------------------- world ----

func _build_static_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.035, 0.045)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.38, 0.48)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -35, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)

	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.near = 0.10
	_cam.far = 50.0
	_cam.position = _cam_home
	add_child(_cam)
	_cam.look_at(Vector3.ZERO, Vector3.UP)

	# Table. No perimeter walls — SPEC §9 option A: marbles roll off the edge.
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(ARENA_W, 0.20, ARENA_D)
	fs.shape = fbox
	floor_body.add_child(fs)
	var fm := MeshInstance3D.new()
	var fmesh := BoxMesh.new()
	fmesh.size = Vector3(ARENA_W, 0.20, ARENA_D)
	fm.mesh = fmesh
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.085, 0.09, 0.105)
	fmat.roughness = 0.85
	fm.material_override = fmat
	floor_body.add_child(fm)
	floor_body.position = Vector3(0, -0.10, 0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.50
	pm.bounce = 0.0
	floor_body.physics_material_override = pm
	add_child(floor_body)

	# Ring — purely logical (§11), drawn flat on the table.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RING_R - 0.012
	tm.outer_radius = RING_R + 0.012
	tm.rings = 64
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.95, 0.80, 0.30)
	rmat.emission_enabled = true
	rmat.emission = Color(0.95, 0.75, 0.20)
	rmat.emission_energy_multiplier = 0.45
	ring.material_override = rmat
	ring.position = Vector3(0, 0.004, 0)
	add_child(ring)

	_lz_vis = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(LZ_X * 2.0, 0.004, LZ_Z_FAR - LZ_Z_NEAR)
	_lz_vis.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lmat.albedo_color = Color(0.30, 0.65, 1.0, 0.10)
	lmat.emission_enabled = true
	lmat.emission = Color(0.30, 0.65, 1.0)
	lmat.emission_energy_multiplier = 0.25
	_lz_vis.material_override = lmat
	_lz_vis.position = Vector3(0, 0.003, (LZ_Z_NEAR + LZ_Z_FAR) * 0.5)
	add_child(_lz_vis)

	_ghost = _make_ghost()
	add_child(_ghost)
	_aim_line = _make_line(Color(0.45, 1.0, 0.65))
	add_child(_aim_line)
	_pull_line = _make_line(Color(1.0, 0.55, 0.35))
	add_child(_pull_line)

	_dynamic = Node3D.new()
	add_child(_dynamic)


func _make_ghost() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = MarbleData.RADIUS
	sm.height = MarbleData.RADIUS * 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.35)
	m.material_override = mat
	m.visible = false
	return m


func _make_line(c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.016, 0.016, 1.0)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.visible = false
	return m


func _span_line(line: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.01:
		line.visible = false
		return
	line.visible = true
	line.position = from + d * 0.5
	line.look_at_from_position(from + d * 0.5, to, Vector3.UP)
	line.scale = Vector3(1, 1, len)


# ---------------------------------------------------------------- level ----

func load_level(idx: int) -> void:
	level_idx = wrapi(idx, 0, Levels.ALL.size())
	level = Levels.ALL[level_idx]

	for c in _dynamic.get_children():
		c.queue_free()
	marbles.clear()
	targets.clear()
	holes.clear()

	bag.assign(level["bag"])
	bag_used.clear()
	for i in bag.size():
		bag_used.append(false)
	selected = 0

	is_versus = level["mode"] == "duel"
	has_ring = level["mode"] == "ringer" or level["mode"] == "duel"
	match_points = [0, 0]
	turn_actor = ACTOR_PLAYER
	ai_bag.clear()
	ai_bag_used.clear()
	ai_selected = 0
	if is_versus:
		ai_bag.assign(level["ai_bag"])
		for i in ai_bag.size():
			ai_bag_used.append(false)
		_ai = MarbleAI.new(level["ai_level"])

	shots_left = level["shots"]
	goal = level["goal"]
	progress = 0
	score = 0
	_held = null
	_aiming = false

	for p in level["holes"]:
		holes.append(p)
		_spawn_hole(p)
	for p in level["bumpers"]:
		_spawn_bumper(p)
	for p in level["targets"]:
		var m := _spawn_marble("target", Vector3(p.x, MarbleData.RADIUS, p.y), true)
		targets.append(m)

	state = St.PLACE
	_hud.flash(level["name"], level["hint"])


func _spawn_marble(id: String, pos: Vector3, as_target: bool, owner: int = -1) -> Marble:
	var m := Marble.new()
	_dynamic.add_child(m)
	m.setup(id, as_target)
	m.owner_id = owner
	if owner >= 0 and is_versus:
		m.set_owner_halo(HALO_PLAYER if owner == ACTOR_PLAYER else HALO_AI)
	m.position = pos
	m.settled.connect(_on_marble_settled)
	m.hit_marble.connect(_on_hit_marble.bind(m))
	m.hit_surface.connect(_on_hit_surface.bind(m))
	marbles.append(m)
	return m


func _spawn_hole(p: Vector2) -> void:
	var m := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = HOLE_VISUAL
	cy.bottom_radius = HOLE_VISUAL
	cy.height = 0.012
	m.mesh = cy
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.01, 0.015)
	mat.roughness = 1.0
	m.material_override = mat
	m.position = Vector3(p.x, 0.004, p.y)
	_dynamic.add_child(m)


func _spawn_bumper(p: Vector2) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BUMPER_R
	cyl.height = BUMPER_H
	cs.shape = cyl
	b.add_child(cs)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BUMPER_R
	cm.bottom_radius = BUMPER_R
	cm.height = BUMPER_H
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.55, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.5, 0.9)
	mat.emission_energy_multiplier = 0.35
	mat.metallic = 0.3
	m.material_override = mat
	b.add_child(m)
	# §23 — bank surface: slick and very bouncy.
	var pm := PhysicsMaterial.new()
	pm.friction = 0.08
	pm.bounce = 1.0
	b.physics_material_override = pm
	b.position = Vector3(p.x, BUMPER_H * 0.5, p.y)
	b.set_meta("bank_surface", true)
	_dynamic.add_child(b)


# ---------------------------------------------------------------- input ----

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("quit"):
		get_tree().quit()
	if ev.is_action_pressed("debug"):
		_debug = not _debug
	if ev.is_action_pressed("restart"):
		load_level(level_idx)
		return
	if ev.is_action_pressed("next_level"):
		load_level(level_idx + 1)
		return
	if ev.is_action_pressed("prev_level"):
		load_level(level_idx - 1)
		return

	for i in 8:
		if ev.is_action_pressed("slot_%d" % (i + 1)) and state == St.PLACE:
			if i < bag.size() and not bag_used[i]:
				selected = i

	if state == St.PLACE and ev.is_action_pressed("shoot"):
		_try_place()
	elif state == St.AIM:
		if ev.is_action_pressed("shoot"):
			_aiming = true
		elif ev.is_action_released("shoot"):
			if _aiming and _aim_power > 0.0:
				_fire()
			_aiming = false
		elif ev.is_action_pressed("cancel"):
			_cancel_placement()


func _mouse_to_table() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var from := _cam.project_ray_origin(mp)
	var dir := _cam.project_ray_normal(mp)
	var plane := Plane(Vector3.UP, MarbleData.RADIUS)
	var hit = plane.intersects_ray(from, dir)
	return hit if hit != null else Vector3.ZERO


func _clamp_to_zone(p: Vector3, actor: int = ACTOR_PLAYER) -> Vector3:
	var z := zone_for(actor)
	return Vector3(
		clampf(p.x, z.position.x, z.position.x + z.size.x),
		MarbleData.RADIUS,
		clampf(p.z, z.position.y, z.position.y + z.size.y))


## §12 — the AI launches from the mirrored strip on the far side.
func zone_for(actor: int) -> Rect2:
	if actor == ACTOR_AI:
		return Rect2(-LZ_X, -LZ_Z_FAR, LZ_X * 2.0, LZ_Z_FAR - LZ_Z_NEAR)
	return Rect2(-LZ_X, LZ_Z_NEAR, LZ_X * 2.0, LZ_Z_FAR - LZ_Z_NEAR)


# §13 — placement may not overlap anything.
func _placement_valid(p: Vector3) -> bool:
	for m in marbles:
		if not is_instance_valid(m) or m.state == Marble.State.CAPTURED \
				or m.state == Marble.State.SUNK or m.state == Marble.State.LOST:
			continue
		if Vector2(m.position.x - p.x, m.position.z - p.z).length() < PLACE_MIN_DIST:
			return false
	return true


func _try_place() -> void:
	# Re-project here rather than reusing _mouse_world: that is refreshed in
	# _process, so a click that lands before the next frame would place the
	# marble wherever the pointer was last frame.
	_mouse_world = _mouse_to_table()
	var p := _clamp_to_zone(_mouse_world)
	if not _place(p):
		return
	state = St.AIM
	_aiming = true


func _place(p: Vector3, actor: int = ACTOR_PLAYER) -> bool:
	var b: Array[String] = ai_bag if actor == ACTOR_AI else bag
	var used: Array[bool] = ai_bag_used if actor == ACTOR_AI else bag_used
	var slot: int = ai_selected if actor == ACTOR_AI else selected
	if slot >= b.size() or used[slot]:
		return false
	if actor == ACTOR_PLAYER and shots_left <= 0:
		return false
	if not _placement_valid(p):
		return false
	_held = _spawn_marble(b[slot], p, false, actor)
	# Deliberately NOT frozen. A marble placed at rest height just sits there,
	# and unfreezing on the same frame the shot velocity is written loses the
	# velocity — the body is still kinematic when the write lands.
	return true


## §69 — the single entry point a shot goes through, whoever authored it.
## Human input builds one of these by placing and dragging; the AI and the
## headless tests build one directly; a network client will post one.
func submit_shot(place: Vector2, dir: Vector3, power: float,
		actor: int = ACTOR_PLAYER) -> bool:
	if actor == ACTOR_PLAYER and state != St.PLACE:
		return false
	if actor == ACTOR_AI and state != St.AI_TURN:
		return false
	var p := _clamp_to_zone(Vector3(place.x, MarbleData.RADIUS, place.y), actor)
	if not _place(p, actor):
		return false
	_aim_dir = dir.normalized()
	_aim_power = clampf(power, 0.0, 1.0)
	_fire(actor)
	return true


func _cancel_placement() -> void:
	if _held and is_instance_valid(_held):
		marbles.erase(_held)
		_held.queue_free()
	_held = null
	_aiming = false
	state = St.PLACE


func _fire(actor: int = ACTOR_PLAYER) -> void:
	var m := _held
	_held = null

	_shot_ctx = {
		"marble": m,
		"touched_bank": false,
		"direct_targets": {},
		"indirect": {},
		"ring_outs": 0,
		"sinks": 0,
		"lost": 0,
	}
	m.launch(_aim_dir, _aim_power)
	if actor == ACTOR_AI:
		ai_bag_used[ai_selected] = true
		for i in ai_bag.size():
			if not ai_bag_used[i]:
				ai_selected = i
				break
	else:
		bag_used[selected] = true
		shots_left -= 1
		_advance_selection()
	_audio.impact(1.2 + _aim_power * 2.5)
	_aim_power = 0.0      # otherwise the power bar stays full after the shot
	state = St.RESOLVE
	_resolve_time = 0.0
	_stable_time = 0.0
	_aim_line.visible = false
	_pull_line.visible = false
	_ghost.visible = false


func _advance_selection() -> void:
	for i in bag.size():
		var j := (selected + 1 + i) % bag.size()
		if not bag_used[j]:
			selected = j
			return


# --------------------------------------------------------------- update ----

func _process(delta: float) -> void:
	_mouse_world = _mouse_to_table()
	_lz_vis.visible = state == St.PLACE or state == St.AIM

	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 4.0)
		var s := _cam_shake * 0.06
		_cam.position = _cam_home + Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	elif _cam.position != _cam_home:
		_cam.position = _cam_home

	match state:
		St.PLACE:
			var p := _clamp_to_zone(_mouse_world)
			_ghost.visible = shots_left > 0
			_ghost.position = p
			var ok := _placement_valid(p)
			var col: Color = MarbleData.get_def(bag[selected])["color"] if selected < bag.size() else Color.WHITE
			_ghost.material_override.albedo_color = Color(col.r, col.g, col.b, 0.4) if ok \
					else Color(1.0, 0.2, 0.2, 0.45)
			_aim_line.visible = false
			_pull_line.visible = false
		St.AIM:
			_ghost.visible = false
			_update_aim()
		_:
			_ghost.visible = false

	_hud.refresh(self)


func _update_aim() -> void:
	if not is_instance_valid(_held):
		return
	var origin: Vector3 = _held.position
	var pull := origin - _mouse_world
	pull.y = 0.0
	var dist := pull.length()
	var scale: float = _held.def["drag_scale"]

	if dist < 0.04:
		_aim_power = 0.0
		_aim_line.visible = false
		_pull_line.visible = false
		return

	_aim_dir = pull.normalized()
	_aim_power = clampf(dist / (MAX_DRAG * scale), 0.0, 1.0)

	var guide: float = _held.def["aim_guide"]
	_span_line(_aim_line, origin, origin + _aim_dir * guide)
	_span_line(_pull_line, origin, _mouse_world)
	var g: Color = Color(0.45, 1.0, 0.65).lerp(Color(1.0, 0.35, 0.25), _aim_power)
	_aim_line.material_override.albedo_color = g
	_aim_line.material_override.emission = g


func _physics_process(delta: float) -> void:
	_check_captures()

	if state != St.RESOLVE:
		return

	_resolve_time += delta

	var moving := 0
	for m in marbles:
		if not is_instance_valid(m):
			continue
		if m.state == Marble.State.ACTIVE and not m.is_resting():
			moving += 1

	# §35 — graded sweep rather than one cliff at 10 s. A single marble settles
	# naturally in ~3.3 s; past that it is only ever a straggler crawling to a
	# halt, and waiting for it is dead time the player watches. Each stage
	# ramps velocity down over 0.3 s, and ring-out is still checked throughout,
	# so nothing is stolen from a marble that was about to score.
	var cut := 0.0
	if _resolve_time > HARD_TIMEOUT:
		cut = INF
	elif _resolve_time > SOFT_TIMEOUT:
		cut = 0.80
	elif _resolve_time > SWEEP_START:
		cut = 0.30
	if cut > 0.0:
		for m in marbles:
			if is_instance_valid(m) and m.linear_velocity.length() < cut:
				m.force_settle()

	if moving == 0:
		_stable_time += delta
		if _stable_time >= RESOLVE_STABLE:
			_end_shot()
	else:
		_stable_time = 0.0


func _check_captures() -> void:
	for m in marbles:
		if not is_instance_valid(m):
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK \
				or m.state == Marble.State.LOST:
			continue

		var p := m.position

		# Arena out (§38) — no walls, so anything can roll off.
		if absf(p.x) > ARENA_W * 0.5 + OUT_MARGIN \
				or absf(p.z) > ARENA_D * 0.5 + OUT_MARGIN or p.y < KILL_Y:
			m.mark_captured("lost")
			# §45 — in Knockout the point goes to the other side regardless of
			# who knocked it off, including knocking out your own marble.
			if is_versus and m.owner_id >= 0:
				match_points[1 - m.owner_id] += 1
				if m.owner_id == ACTOR_AI:
					score += 1000
				else:
					score -= 250
				_pop()
			elif not m.is_target:
				score -= 250
				_shot_ctx["lost"] = _shot_ctx.get("lost", 0) + 1
			continue

		# Holes (§39) — horizontal centre inside the capture radius.
		for h in holes:
			if Vector2(p.x - h.x, p.z - h.y).length() < HOLE_CAPTURE:
				m.mark_captured("sunk")
				_audio.sink()
				if m.is_target and level["mode"] == "holes":
					progress += 1
					score += 1000
					_shot_ctx["sinks"] = _shot_ctx.get("sinks", 0) + 1
					_pop()
				elif not m.is_target:
					score -= 250     # §40
				break

		if m.state == Marble.State.SUNK:
			continue

		# Ring out (§36) — targets only; the player's own marbles are free to
		# leave the ring (§37).
		if has_ring and m.is_target:
			if Vector2(p.x, p.z).length() >= RING_OUT_DIST:
				m.mark_captured("ring_out")
				if is_versus:
					# Only one shot resolves at a time, so whoever is on turn
					# is the one who caused this.
					match_points[turn_actor] += 1
					score += 1000 if turn_actor == ACTOR_PLAYER else 0
				else:
					progress += 1
					score += 1000
				_shot_ctx["ring_outs"] = _shot_ctx.get("ring_outs", 0) + 1
				_pop()


func _pop() -> void:
	_cam_shake = maxf(_cam_shake, 0.7)


func _end_shot() -> void:
	_score_shot()

	# §36 — bodies are only removed once the shot has fully resolved.
	for m in marbles.duplicate():
		if not is_instance_valid(m):
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK \
				or m.state == Marble.State.LOST:
			marbles.erase(m)
			targets.erase(m)
			m.fade_out()
		else:
			m.shot_this_turn = false

	if is_versus:
		_end_knockout_turn()
		return

	if progress >= goal:
		score += shots_left * 200          # §49 unused shots
		score += 300                       # §54 perfect finish on the last shot
		state = St.WON
		_hud.flash("LEVEL CLEAR", "Score %d  ·  N for next level  ·  R to retry" % score)
		return

	if shots_left <= 0 or not _objective_still_possible():
		state = St.LOST
		_hud.flash("OUT OF SHOTS", "R to retry  ·  N for next level")
		return

	state = St.PLACE


# §43-47 — alternate turns until both bags are empty, then compare points.
func _end_knockout_turn() -> void:
	# A duel can also finish early: once the last red target is gone there is
	# nothing left to contest.
	if has_ring and _live_targets() == 0:
		_resolve_knockout()
		return

	var player_done: bool = shots_left <= 0
	var ai_done := true
	for u in ai_bag_used:
		if not u:
			ai_done = false
			break

	if player_done and ai_done:
		_resolve_knockout()
		return

	# Hand over, skipping a side that has nothing left to play.
	turn_actor = ACTOR_AI if turn_actor == ACTOR_PLAYER else ACTOR_PLAYER
	if turn_actor == ACTOR_AI and ai_done:
		turn_actor = ACTOR_PLAYER
	elif turn_actor == ACTOR_PLAYER and player_done:
		turn_actor = ACTOR_AI

	if turn_actor == ACTOR_AI:
		_begin_ai_turn()
	else:
		state = St.PLACE


func _live_targets() -> int:
	var n := 0
	for t in targets:
		if is_instance_valid(t) and t.state != Marble.State.CAPTURED \
				and t.state != Marble.State.SUNK and t.state != Marble.State.LOST:
			n += 1
	return n


func _resolve_knockout() -> void:
	var p: int = match_points[ACTOR_PLAYER]
	var a: int = match_points[ACTOR_AI]
	if p > a:
		state = St.WON
		_hud.flash("MATCH WON", "%d - %d  ·  N for next level  ·  R to retry" % [p, a])
		return
	if p < a:
		state = St.LOST
		_hud.flash("MATCH LOST", "%d - %d  ·  R to retry" % [p, a])
		return

	# §47 tie-break: whichever side's surviving marbles sit further from an edge.
	var safety := [0.0, 0.0]
	for m in marbles:
		if not is_instance_valid(m) or m.owner_id < 0:
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK \
				or m.state == Marble.State.LOST:
			continue
		safety[m.owner_id] += minf(
			ARENA_W * 0.5 - absf(m.position.x),
			ARENA_D * 0.5 - absf(m.position.z))

	var diff: float = safety[ACTOR_PLAYER] - safety[ACTOR_AI]
	if absf(diff) < 0.01:
		state = St.LOST
		_hud.flash("DRAW", "%d - %d  ·  a draw does not clear the level  ·  R to retry" % [p, a])
	elif diff > 0.0:
		state = St.WON
		_hud.flash("MATCH WON", "%d - %d on safety  ·  N for next level" % [p, a])
	else:
		state = St.LOST
		_hud.flash("MATCH LOST", "%d - %d on safety  ·  R to retry" % [p, a])


func _begin_ai_turn() -> void:
	state = St.AI_TURN
	_ghost.visible = false
	_aim_line.visible = false
	_pull_line.visible = false
	_run_ai_turn()


## Think, then shoot. The pause is partly so the player can see whose turn it
## is, and partly so a 1.5 s search does not look like a freeze.
func _run_ai_turn() -> void:
	await _ai_pause(0.45)
	if state != St.AI_TURN:
		return

	var shot: Dictionary = _ai.choose_shot(_board_for_ai(), ACTOR_AI)
	if shot.is_empty():
		# Nothing playable — treat the turn as spent rather than hanging.
		for i in ai_bag_used.size():
			ai_bag_used[i] = true
		_end_knockout_turn()
		return

	ai_selected = shot["slot"]
	await _ai_pause(0.25)
	if state != St.AI_TURN:
		return

	# The AI's own spent marbles accumulate in its launch strip, so the spot it
	# picked may be occupied. Slide along the strip to the nearest free one.
	var place: Vector2 = _nearest_free_placement(shot["place"], ACTOR_AI)
	var d: Vector2 = shot["dir"]
	if not submit_shot(place, Vector3(d.x, 0, d.y), shot["power"], ACTOR_AI):
		# Nothing playable at all: spend the turn rather than stalling the
		# match. Without this the state machine sits in AI_TURN forever.
		push_warning("AI could not place a marble; skipping its turn")
		ai_bag_used[ai_selected] = true
		_end_knockout_turn()


## Walks outward from `want` along the launch strip for a legal spot.
func _nearest_free_placement(want: Vector2, actor: int) -> Vector2:
	var zone := zone_for(actor)
	var z: float = zone.position.y + zone.size.y * 0.5
	var start: float = clampf(want.x, zone.position.x, zone.position.x + zone.size.x)
	if _placement_valid(Vector3(start, MarbleData.RADIUS, z)):
		return Vector2(start, z)

	var step := PLACE_MIN_DIST * 0.5
	var reach: float = zone.size.x
	var offset := step
	while offset <= reach:
		for s in [1.0, -1.0]:
			var x: float = start + offset * s
			if x < zone.position.x or x > zone.position.x + zone.size.x:
				continue
			if _placement_valid(Vector3(x, MarbleData.RADIUS, z)):
				return Vector2(x, z)
		offset += step
	return Vector2(start, z)


## What the AI is allowed to see — exactly what is on the table.
## A beat so the player can see whose turn it is. Skipped when there is no
## display, so headless test runs are not paced by cosmetics.
func _ai_pause(seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


func _board_for_ai() -> Dictionary:
	var live := []
	var aim_points: Array[Vector2] = []
	for m in marbles:
		if not is_instance_valid(m):
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK \
				or m.state == Marble.State.LOST:
			continue
		var own: int = m.owner_id if m.owner_id >= 0 else ShotSim.Owner.TARGET
		live.append({"pos": Vector2(m.position.x, m.position.z), "id": m.def_id,
					 "owner": own})
		if own != ACTOR_AI:
			aim_points.append(Vector2(m.position.x, m.position.z))

	var reserve := []
	for i in ai_bag.size():
		if not ai_bag_used[i]:
			reserve.append({"slot": i, "id": ai_bag[i]})

	var bump := PackedVector3Array()
	for p in level.get("bumpers", []):
		bump.append(Vector3(p.x, p.y, BUMPER_R))

	return {
		"marbles": live,
		"reserve": reserve,
		"aim_points": aim_points,
		"launch_zone": zone_for(ACTOR_AI),
		"half_w": ARENA_W * 0.5,
		"half_d": ARENA_D * 0.5,
		"ring_out_dist": RING_OUT_DIST if has_ring else 0.0,
		"holes": PackedVector2Array(holes),
		"bumpers": bump,
	}


# §42 — fail immediately once the objective is arithmetically unreachable.
func _objective_still_possible() -> bool:
	var live := 0
	for t in targets:
		if is_instance_valid(t) and t.state != Marble.State.CAPTURED \
				and t.state != Marble.State.SUNK and t.state != Marble.State.LOST:
			live += 1
	return progress + live >= goal


func _score_shot() -> void:
	if _shot_ctx.is_empty():
		return
	var scoring: int = _shot_ctx.get("ring_outs", 0) + _shot_ctx.get("sinks", 0)
	if scoring == 0:
		return

	# §51 multi hit — every direct objective-relevant contact after the first.
	var direct: int = _shot_ctx["direct_targets"].size()
	if direct >= 2:
		score += (direct - 1) * 75

	# §50 bank shot — a bank surface touched before the first direct target.
	if _shot_ctx["touched_bank"]:
		score += 150

	# §52 chain — scoring targets the shooter never touched itself.
	var indirect: int = maxi(0, scoring - direct)
	score += indirect * 125

	_shot_ctx.clear()


# --------------------------------------------------------------- events ----

func _on_marble_settled(m: Marble) -> void:
	# §33 — abilities fire once, on the marble's own first rest after its shot.
	if m.has_triggered_stop_ability or m.def["ability"] == "":
		return
	m.has_triggered_stop_ability = true
	if m.def["ability"] == "magnet_pulse":
		_magnet_pulse(m)


## §30 — one pulse, strength falls off linearly to the radius.
func _magnet_pulse(src: Marble) -> void:
	for m in marbles:
		if m == src or not is_instance_valid(m):
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK:
			continue
		var d := Vector2(m.position.x - src.position.x, m.position.z - src.position.z)
		var dist := d.length()
		if dist >= MarbleData.MAGNET_RADIUS or dist < 0.001:
			continue
		var strength := 1.0 - dist / MarbleData.MAGNET_RADIUS
		var imp := MarbleData.MAGNET_MAX_IMPULSE * strength
		var dir := Vector3(-d.x, 0, -d.y).normalized()
		m.add_velocity(dir * (imp / m.mass))
	_cam_shake = maxf(_cam_shake, 0.4)


func _on_hit_marble(other: Marble, speed: float, src: Marble) -> void:
	_audio.impact(speed)
	if speed > 2.0:
		_cam_shake = maxf(_cam_shake, clampf(speed / 7.0, 0.0, 0.8))
	if _shot_ctx.is_empty() or _shot_ctx["marble"] != src:
		return
	if _is_objective_relevant(other):
		_shot_ctx["direct_targets"][other.get_instance_id()] = true


func _on_hit_surface(body: Node, speed: float, src: Marble) -> void:
	var is_bank: bool = body.has_meta("bank_surface")
	if is_bank:
		_audio.impact(speed, true)
	if _shot_ctx.is_empty() or _shot_ctx["marble"] != src:
		return
	# The floor is a surface too, and every marble rests on it — only a real
	# bank surface counts, and only before the shooter reaches a target (§50).
	if is_bank and _shot_ctx["direct_targets"].is_empty():
		_shot_ctx["touched_bank"] = true


# §51 — in Ringer and Holes that means the red targets.
func _is_objective_relevant(m: Marble) -> bool:
	return m.is_target
