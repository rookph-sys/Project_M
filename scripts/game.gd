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
var match_stats := {}
var prog := Progression.new()
var last_result := {}
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
var _menu: CanvasLayer = null
var _pending_bag: Array[String] = []
var _settings := Settings.new()


func _ready() -> void:
	prog.load()
	_settings.load()
	_register_actions()
	_build_static_world()
	_audio = MarbleAudio.new()
	add_child(_audio)
	_settings.apply_audio()
	_audio.start_music(_settings.music_volume)
	_juice = Juice.new()
	add_child(_juice)
	_juice.setup(_cam, _settings)
	_hud = preload("res://scripts/hud.gd").new()
	_hud.text_scale = _settings.text_scale
	add_child(_hud)
	_menu = preload("res://scripts/menu.gd").new()
	add_child(_menu)
	_menu.setup(prog, _settings)
	_menu.play_requested.connect(_on_play_requested)
	_build_fade()

	var jump := _start_level()
	if jump >= 0:
		_menu.visible = false
		load_level(jump)
	else:
		load_level(0)
		_menu.show_levels()


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
	return -1      # no argument: start on the campaign screen


# §71 — gameplay never queries raw keys; everything goes through actions.
func _register_actions() -> void:
	# §71 — everything goes through actions, so a pad is a binding change
	# rather than a second code path through the gameplay.
	var mouse := {
		"shoot": MOUSE_BUTTON_LEFT,
		"cancel": MOUSE_BUTTON_RIGHT,
	}
	for name in mouse:
		_ensure_action(name)
		var e := InputEventMouseButton.new()
		e.button_index = mouse[name]
		InputMap.action_add_event(name, e)

	var keys := {
		"restart": KEY_R, "next_level": KEY_N, "prev_level": KEY_P,
		"debug": KEY_F1, "to_menu": KEY_ESCAPE,
		"cancel_menu": KEY_ESCAPE, "collection": KEY_C, "confirm": KEY_ENTER,
		"settings": KEY_O,
	}
	for name in keys:
		_ensure_action(name)
		var e := InputEventKey.new()
		e.physical_keycode = keys[name]
		InputMap.action_add_event(name, e)

	for i in 8:
		var n := "slot_%d" % (i + 1)
		_ensure_action(n)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_1 + i
		InputMap.action_add_event(n, e)

	# §8.1 controller: A confirms, B cancels, shoulders cycle the bag,
	# Start pauses. Sticks and the right trigger are read as axes in _process.
	var pad := {
		"shoot": JOY_BUTTON_A,
		"confirm": JOY_BUTTON_A,
		"cancel": JOY_BUTTON_B,
		"cancel_menu": JOY_BUTTON_B,
		"to_menu": JOY_BUTTON_START,
		"restart": JOY_BUTTON_Y,
		"slot_next": JOY_BUTTON_RIGHT_SHOULDER,
		"slot_prev": JOY_BUTTON_LEFT_SHOULDER,
		"collection": JOY_BUTTON_X,
	}
	for name in pad:
		_ensure_action(name)
		var e := InputEventJoypadButton.new()
		e.button_index = pad[name]
		InputMap.action_add_event(name, e)


func _ensure_action(name: String) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)   # deadzone, §47


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
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.12
	e.glow_hdr_threshold = 0.92
	e.ssao_enabled = true
	e.ssao_radius = 0.35
	e.ssao_intensity = 1.4
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
	fmat.albedo_color = Color(0.072, 0.077, 0.092)
	fmat.roughness = 0.62
	fmat.metallic = 0.12
	fmat.metallic_specular = 0.3
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

	# A deck chosen in the builder wins; otherwise the level default.
	bag.assign(_pending_bag if _pending_bag.size() == 8 else level["bag"])
	_pending_bag.clear()
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
	match_stats = {
		"ring_outs": 0, "sinks": 0, "shots_used": 0, "marbles_lost": 0,
		"bank_shots": 0, "multi_hits": 0, "chain_hits": 0, "knockouts": 0,
		"magnet_affected": 0, "won_match": false,
		"direct_hit_by": {}, "ring_out_by": {}, "bank_shot_by": {},
		"alive_at_end": {},
	}
	last_result = {}
	score = 0
	_held = null
	_aiming = false
	_slowmo_fired = false
	_end_slowmo()

	for p in level["holes"]:
		holes.append(p)
		_spawn_hole(p)
	for p in level["bumpers"]:
		_spawn_bumper(p)
	for p in level["targets"]:
		var m := _spawn_marble("target", Vector3(p.x, MarbleData.RADIUS, p.y), true)
		targets.append(m)

	state = St.PLACE
	_close_menu()
	_hud.flash(level["name"], level["hint"])


func _spawn_marble(id: String, pos: Vector3, as_target: bool, owner: int = -1) -> Marble:
	var m := Marble.new()
	_dynamic.add_child(m)
	m.setup(id, as_target)
	m.owner_id = owner
	if owner >= 0 and is_versus:
		m.set_owner_halo(HALO_PLAYER if owner == ACTOR_PLAYER else HALO_AI)
	m.set_marker(_settings.marker_for(owner, as_target))
	m.enable_trail()
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
	# Esc goes back to the campaign rather than quitting — losing a duel to a
	# stray keypress is not an acceptable way to leave a match.
	if ev.is_action_pressed("to_menu"):
		_open_menu()
		return
	if ev.is_action_pressed("debug"):
		_debug = not _debug
	if ev.is_action_pressed("restart"):
		_transition(func(): load_level(level_idx))
		return
	if ev.is_action_pressed("next_level"):
		_transition(func(): load_level(level_idx + 1))
		return
	if ev.is_action_pressed("prev_level"):
		_transition(func(): load_level(level_idx - 1))
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

	_combo_in_shot = 0
	_shot_ctx = {
		"marble": m,
		"marble_id": m.def_id,
		"aim": _aim_dir,
		"ability_fired": false,
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
		match_stats["shots_used"] = match_stats.get("shots_used", 0) + 1
		prog.bump("shots_fired")
		prog.note_marble_use(m.def_id)
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
	_tick_slowmo()
	# One source of truth for which layer is showing.
	if _menu:
		_hud.visible = not _menu.visible
	if not pad_active:
		_mouse_world = _mouse_to_table()
	_update_controller(delta)
	_lz_vis.visible = state == St.PLACE or state == St.AIM

	_update_camera(delta)

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

	var guide: float = _settings.guide_length(_held.def["aim_guide"])
	if guide > 0.0:
		_span_line(_aim_line, origin, origin + _aim_dir * guide)
	else:
		_aim_line.visible = false
	_span_line(_pull_line, origin, _mouse_world)
	_tint_aim(_aim_power)


## Green at a feather touch, red at full power — the one piece of the aim
## readout that still works with the guide line turned off.
func _tint_aim(power: float) -> void:
	var g: Color = Color(0.45, 1.0, 0.65).lerp(Color(1.0, 0.35, 0.25), power)
	_aim_line.material_override.albedo_color = g
	_aim_line.material_override.emission = g
	_pull_line.material_override.albedo_color = g
	_pull_line.material_override.emission = g


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
					match_stats["knockouts"] += 1
				else:
					score -= 250
					match_stats["marbles_lost"] += 1
				_pop()
			elif not m.is_target:
				score -= 250
				match_stats["marbles_lost"] += 1
				_shot_ctx["lost"] = _shot_ctx.get("lost", 0) + 1
			continue

		# Holes (§39) — horizontal centre inside the capture radius.
		for h in holes:
			if Vector2(p.x - h.x, p.z - h.y).length() < HOLE_CAPTURE:
				m.mark_captured("sunk")
				_audio.sink()
				if m.is_target and level["mode"] == "holes":
					match_stats["sinks"] += 1
					score += 1000
					_shot_ctx["sinks"] = _shot_ctx.get("sinks", 0) + 1
					_pop(p, 1000, Color(0.5, 0.85, 1.0))
				elif not m.is_target:
					score -= 250     # §40
					match_stats["marbles_lost"] += 1
					_audio.marble_lost()
					_juice.popup(p, "-250", Color(1.0, 0.35, 0.3), 0)
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
					score += 1000
				if turn_actor == ACTOR_PLAYER:
					match_stats["ring_outs"] += 1
					var by: String = _shot_ctx.get("marble_id", "")
					if by != "":
						match_stats["ring_out_by"][by] = match_stats["ring_out_by"].get(by, 0) + 1
				_shot_ctx["ring_outs"] = _shot_ctx.get("ring_outs", 0) + 1
				_pop(p, 1000, Color(1.0, 0.85, 0.3))


func _pop(at: Vector3 = Vector3.ZERO, points: int = 1000, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	_score_feedback(at, points, color)
	if state == St.RESOLVE and not is_versus and _primary_met():
		_trigger_slowmo()


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

	# §59 — primary and additional both have to pass.
	var cleared: bool = Objectives.all_met(level.get("primary", []), match_stats) \
			and Objectives.all_met(level.get("additional", []), match_stats)
	if cleared:
		score += shots_left * 200          # §49 unused shots
		score += 300                       # §54 perfect finish
		_finish(true)
		return

	if shots_left <= 0 or not Objectives.still_possible(
			level, match_stats, _live_targets(), shots_left):
		_finish(false)
		return

	state = St.PLACE


## Applies rewards, writes the save, and reports what changed (§25, §55, §65).
func _finish(won: bool) -> void:
	_record_survivors()
	state = St.WON if won else St.LOST

	var earned: int = Objectives.medals_earned(level, match_stats, won)
	var news: Dictionary = prog.record_result(level_idx, won, score, earned)

	var unlocked_now := ""
	if won:
		var reward: Dictionary = level.get("reward", {})
		if reward.has("deck_builder"):
			prog.deck_builder_unlocked = true
			prog.save()
		if reward.has("unlock") and prog.unlock_marble(reward["unlock"]):
			unlocked_now = MarbleData.get_def(reward["unlock"])["name"]

	last_result = {
		"won": won, "score": score, "medals": earned,
		"unlocked": unlocked_now, "news": news,
	}
	_audio.fanfare() if won else _audio.failure()
	_show_result_banner()


func _show_result_banner() -> void:
	var r := last_result
	if not r["won"]:
		var why: String = "OUT OF SHOTS" if shots_left <= 0 else "OBJECTIVE FAILED"
		_hud.flash(why, _objective_summary() + "      [R] retry")
		return

	_juice.popup(Vector3.ZERO, "PERFECT!", Color(1.0, 0.9, 0.35), 4)
	_juice.flash(Color(1.0, 0.95, 0.6), 0.12)
	_juice.hit_stop(0.12)
	var stars := "★".repeat(r["medals"]) + "☆".repeat(3 - r["medals"])
	var line := "Score %d   %s" % [r["score"], stars]
	if r["unlocked"] != "":
		line += "      %s UNLOCKED" % r["unlocked"].to_upper()
	line += "      [N] next   [R] retry"
	_hud.flash("LEVEL CLEAR", line)


func _objective_summary() -> String:
	var parts: Array[String] = []
	for o in level.get("primary", []) + level.get("additional", []):
		if not Objectives.met(o, match_stats):
			parts.append(Objectives.describe(o))
	return "Missed: " + ", ".join(parts) if not parts.is_empty() else ""


## Trials ask whether a specific marble is still on the table at the end.
func _record_survivors() -> void:
	for m in marbles:
		if not is_instance_valid(m) or m.owner_id != ACTOR_PLAYER:
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK \
				or m.state == Marble.State.LOST:
			continue
		match_stats["alive_at_end"][m.def_id] = true


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
	if p != a:
		_finish_duel(p > a, "%d - %d" % [p, a])
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
		_finish_duel(false, "%d - %d draw" % [p, a])
	else:
		_finish_duel(diff > 0.0, "%d - %d on edge safety" % [p, a])


## A duel is won on points, but the level still has to pass its objectives —
## `marble_survives` in the Sticky trial, for instance.
func _finish_duel(points_won: bool, detail: String) -> void:
	_record_survivors()
	match_stats["won_match"] = points_won
	var cleared: bool = points_won \
			and Objectives.all_met(level.get("primary", []), match_stats) \
			and Objectives.all_met(level.get("additional", []), match_stats)
	_finish(cleared)
	_hud.sub_detail(detail)


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
					 "owner": own, "anchored": m.is_anchored})
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


func _score_shot() -> void:
	if _shot_ctx.is_empty():
		return
	var scoring: int = _shot_ctx.get("ring_outs", 0) + _shot_ctx.get("sinks", 0)
	if scoring == 0:
		return

	var by: String = _shot_ctx.get("marble_id", "")

	# §51 multi hit — every direct objective-relevant contact after the first.
	var direct: int = _shot_ctx["direct_targets"].size()
	if direct >= 2:
		score += (direct - 1) * 75
		match_stats["multi_hits"] += 1

	# §50 bank shot — a bank surface touched before the first direct target.
	if _shot_ctx["touched_bank"]:
		score += 150
		match_stats["bank_shots"] += 1
		if by != "":
			match_stats["bank_shot_by"][by] = match_stats["bank_shot_by"].get(by, 0) + 1

	# §52 chain — scoring targets the shooter never touched itself.
	var indirect: int = maxi(0, scoring - direct)
	score += indirect * 125
	if indirect > 0:
		match_stats["chain_hits"] += 1

	_shot_ctx.clear()


# --------------------------------------------------------------- events ----

func _on_marble_settled(m: Marble) -> void:
	# §33 — abilities fire once, on the marble's own first rest after its shot.
	if m.has_triggered_stop_ability or m.def["ability"] == "":
		return
	m.has_triggered_stop_ability = true
	_ability_on_stop(m)


## §30 — one pulse, strength falls off linearly to the radius.
func _magnet_pulse(src: Marble) -> void:
	for m in marbles:
		if m == src or not is_instance_valid(m):
			continue
		if m.state == Marble.State.CAPTURED or m.state == Marble.State.SUNK:
			continue
		if m.is_anchored:
			continue      # an anchored marble is not going anywhere
		var d := Vector2(m.position.x - src.position.x, m.position.z - src.position.z)
		var dist := d.length()
		if dist >= MarbleData.MAGNET_RADIUS or dist < 0.001:
			continue
		if m.is_target and src.owner_id == ACTOR_PLAYER:
			match_stats["magnet_affected"] += 1
		var strength := 1.0 - dist / MarbleData.MAGNET_RADIUS
		var imp := MarbleData.MAGNET_MAX_IMPULSE * strength
		var dir := Vector3(-d.x, 0, -d.y).normalized()
		m.add_velocity(dir * (imp / m.mass))
	_cam_shake = maxf(_cam_shake, 0.4)


func _on_hit_marble(other: Marble, speed: float, src: Marble) -> void:
	_audio.impact(speed)
	_impact_feedback(src, other, speed)
	if _shot_ctx.is_empty() or _shot_ctx["marble"] != src:
		return

	# OnFirstCollision (§13) — once per shot, on the first marble touched.
	if not _shot_ctx.get("ability_fired", false):
		_shot_ctx["ability_fired"] = true
		_ability_on_first_collision(src, other)

	if _is_objective_relevant(other):
		_shot_ctx["direct_targets"][other.get_instance_id()] = true
		if src.owner_id == ACTOR_PLAYER:
			var id := src.def_id
			match_stats["direct_hit_by"][id] = match_stats["direct_hit_by"].get(id, 0) + 1


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


# ------------------------------------------------------------ abilities ----
#
# §12-13. Each marble has at most one ability, it fires on a physics event,
# it adds no new input, and it changes physics rather than scoring. Standard
# deliberately has none — it is the baseline everything is balanced against.

const BREAKER_BONUS := 3.20       # m/s added to the struck marble
const RICOCHET_BONUS := 2.10      # m/s the shooter regains off its first hit
const PINPOINT_SCALE := 1.25      # speed multiplier on the redirected marble

const ABILITY_COLOR := {
	"breaker": Color(1.00, 0.55, 0.15),
	"ricochet": Color(1.00, 0.45, 0.25),
	"pinpoint": Color(0.35, 0.85, 1.00),
	"anchor": Color(0.55, 0.90, 0.35),
	"magnet_pulse": Color(0.85, 0.45, 1.00),
}


## Fired by the shooter's first contact with another marble.
func _ability_on_first_collision(src: Marble, other: Marble) -> void:
	var id: String = src.def["ability"]
	var from := Vector2(src.position.x, src.position.z)
	var to := Vector2(other.position.x, other.position.z)
	var away := (to - from).normalized()

	match id:
		"breaker":
			other.add_velocity(Vector3(away.x, 0, away.y) * BREAKER_BONUS)
			_ability_burst(other.position, ABILITY_COLOR[id], 0.85)
			_cam_shake = maxf(_cam_shake, 1.0)
			_audio.impact(5.0)
		"ricochet":
			var v := src.linear_velocity
			if v.length() > 0.05:
				src.add_velocity(v.normalized() * RICOCHET_BONUS)
			_ability_burst(src.position, ABILITY_COLOR[id], 0.55)
			_audio.impact(3.2)
		"pinpoint":
			# The whole point: the target goes where you were aiming, not
			# wherever the contact geometry happened to send it.
			var aim := Vector2(_shot_ctx.get("aim", Vector3.FORWARD).x,
							   _shot_ctx.get("aim", Vector3.FORWARD).z)
			if aim.length() > 0.01:
				other.redirect(aim.normalized(), PINPOINT_SCALE)
			_ability_burst(other.position, ABILITY_COLOR[id], 0.70)
			_audio.impact(3.5)


## Fired the first time a marble comes to rest after its own shot (§33).
func _ability_on_stop(m: Marble) -> void:
	match m.def["ability"]:
		"anchor":
			m.anchor()
			_ability_burst(m.position, ABILITY_COLOR["anchor"], 0.45)
		"magnet_pulse":
			_magnet_pulse(m)
			_ability_burst(m.position, ABILITY_COLOR["magnet_pulse"],
				MarbleData.MAGNET_RADIUS)


## Expanding ring on the table. Abilities that cannot be seen may as well not
## exist, and a flat ring reads at this camera angle better than particles.
func _ability_burst(at: Vector3, color: Color, max_radius: float) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.07
	t.outer_radius = 0.10
	t.rings = 32
	ring.mesh = t
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = Vector3(at.x, 0.015, at.z)
	_dynamic.add_child(ring)

	# Grow the radii rather than scaling the node: a uniform scale thickens the
	# tube as well, which reads as a swelling donut instead of a shockwave.
	var band := 0.035
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "inner_radius", max_radius - band, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "outer_radius", max_radius, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.34).set_delay(0.06)
	tw.chain().tween_callback(ring.queue_free)


# --------------------------------------------------------------- shell ----

func _on_play_requested(index: int, chosen_bag: Array) -> void:
	_pending_bag.assign(chosen_bag)
	_transition(func(): load_level(index))


func _open_menu() -> void:
	if _menu == null:
		return
	_end_slowmo()
	_pending_bag.clear()
	_transition(func():
		_menu.show_levels()
		_hud.visible = false)


func _close_menu() -> void:
	if _menu:
		_menu.visible = false
	_hud.visible = true


# ----------------------------------------------------------- controller ----
#
# §8.1. The pad drives the same ShotCommand the mouse does; it only produces
# the placement point, direction and power differently. Pad mode switches on
# as soon as a stick or trigger moves, and back off on the next mouse motion,
# so nobody has to pick a control scheme in a menu.

const PAD_CURSOR_SPEED := 2.6      # metres per second
const PAD_DEADZONE := 0.22
const PAD_POWER_RATE := 1.6        # trigger seconds from 0 to full

var pad_active := false
var _pad_cursor := Vector3(0.0, MarbleData.RADIUS, -1.85)
var _pad_power := 0.0
var _pad_aim := Vector2(0, 1)


func _pad_vector(neg_x: JoyAxis, pos_y: JoyAxis) -> Vector2:
	var v := Vector2(
		Input.get_joy_axis(0, neg_x),
		Input.get_joy_axis(0, pos_y))
	return Vector2.ZERO if v.length() < PAD_DEADZONE else v


func _update_controller(delta: float) -> void:
	var move := _pad_vector(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var aim := _pad_vector(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	var trigger: float = maxf(0.0, Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT))

	if move != Vector2.ZERO or aim != Vector2.ZERO or trigger > 0.1:
		pad_active = true
	if not pad_active:
		return

	match state:
		St.PLACE:
			_pad_cursor += Vector3(move.x, 0, move.y) * PAD_CURSOR_SPEED * delta
			_pad_cursor = _clamp_to_zone(_pad_cursor, ACTOR_PLAYER)
			_mouse_world = _pad_cursor
			_pad_power = 0.0
		St.AIM:
			if aim != Vector2.ZERO:
				_pad_aim = aim.normalized()
			# Hold the trigger to wind up; release to fire.
			if trigger > 0.15:
				_pad_power = clampf(_pad_power + trigger * delta / PAD_POWER_RATE, 0.0, 1.0)
			elif _pad_power > MarbleData.MIN_POWER:
				_fire_pad()
				return
			_aim_dir = Vector3(_pad_aim.x, 0, _pad_aim.y)
			_aim_power = _pad_power
			if is_instance_valid(_held):
				var origin: Vector3 = _held.position
				var guide: float = _settings.guide_length(_held.def["aim_guide"])
				if guide > 0.0:
					_span_line(_aim_line, origin, origin + _aim_dir * guide)
				_span_line(_pull_line, origin, origin - _aim_dir * (_pad_power * MAX_DRAG))
				_tint_aim(_pad_power)


func _fire_pad() -> void:
	_aim_dir = Vector3(_pad_aim.x, 0, _pad_aim.y)
	_aim_power = _pad_power
	_pad_power = 0.0
	_fire()


# ---------------------------------------------------------- slow motion ----
#
# §54. Fired only at the moment the primary objectives become satisfied — the
# level is already won by then, and ring-outs are latched (§36), so the slower
# physics step cannot take a result away. It can at most add one, which is a
# gift rather than a bug. Anywhere earlier in a shot it would be changing a
# result the player had already earned.

const SLOWMO_SCALE := 0.30
const SLOWMO_SECONDS := 0.45

var _slowmo_until_ms := 0
var _slowmo_fired := false


func _trigger_slowmo() -> void:
	if not _settings.slow_motion or _slowmo_fired:
		return
	_slowmo_fired = true
	Engine.time_scale = SLOWMO_SCALE
	# Wall-clock, because _process delta is itself scaled while this is active.
	_slowmo_until_ms = Time.get_ticks_msec() + int(SLOWMO_SECONDS * 1000.0)
	_cam_shake = maxf(_cam_shake, 1.0)


func _tick_slowmo() -> void:
	if _slowmo_until_ms > 0 and Time.get_ticks_msec() >= _slowmo_until_ms:
		_end_slowmo()


func _end_slowmo() -> void:
	Engine.time_scale = 1.0
	_slowmo_until_ms = 0


func _primary_met() -> bool:
	return Objectives.all_met(level.get("primary", []), match_stats) \
		and Objectives.all_met(level.get("additional", []), match_stats)


# ---------------------------------------------------------- transitions ----

var _fade: ColorRect = null


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50          # above the menu, which is 20
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.03, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Fade out, run `mid`, fade back in. Keeps level loads from snapping.
func _transition(mid: Callable, out_time: float = 0.18, in_time: float = 0.26) -> void:
	if _fade == null:
		mid.call()
		return
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, out_time)
	t.tween_callback(mid)
	t.tween_property(_fade, "color:a", 0.0, in_time)


# ---------------------------------------------------------------- juice ----

const HIT_STOP_LIGHT := 0.035
const HIT_STOP_HEAVY := 0.085

var _juice: Juice
var _combo_in_shot := 0
var _cam_kick := Vector3.ZERO
var _cam_zoom := 0.0


## Everything that happens when one marble strikes another, scaled by how hard.
func _impact_feedback(a: Marble, b: Marble, speed: float) -> void:
	var dir := (b.global_position - a.global_position).normalized()
	var hard: float = clampf(speed / 4.5, 0.0, 1.0)

	a.squash(dir, hard * 0.9)
	b.squash(-dir, hard)

	if hard > 0.12:
		_spawn_sparks(a.global_position.lerp(b.global_position, 0.5), b.def["color"], hard)
	if hard > 0.30:
		_cam_kick = dir * (hard * 0.30)
		_cam_zoom = maxf(_cam_zoom, hard * 0.28)
		_cam_shake = maxf(_cam_shake, hard * 0.9)
	# A freeze only on contacts worth noticing, or it feels like stutter.
	if hard > 0.55:
		_juice.hit_stop(HIT_STOP_LIGHT + (hard - 0.55) * HIT_STOP_HEAVY)


## A scoring event: the number flies, the combo climbs, the screen reacts.
func _score_feedback(at: Vector3, points: int, color: Color) -> void:
	_combo_in_shot += 1
	_juice.popup(at, "+%d" % points, color, _combo_in_shot - 1)
	_juice.combo(_combo_in_shot)
	_juice.flash(color, 0.05 + _combo_in_shot * 0.02)
	_juice.hit_stop(HIT_STOP_LIGHT + _combo_in_shot * 0.012)
	_cam_shake = maxf(_cam_shake, 0.8 + _combo_in_shot * 0.25)
	_cam_zoom = maxf(_cam_zoom, 0.3)
	# Each one in a chain rings a step higher — the escalation is the reward.
	_audio.score_event(0.9 + _combo_in_shot * 0.14)
	_spawn_sparks(at, color, 1.0)


func _spawn_sparks(at: Vector3, color: Color, strength: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(6 + strength * 22)
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = Vector3(at.x, MarbleData.RADIUS, at.z)

	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 75.0
	m.initial_velocity_min = 0.8 * strength
	m.initial_velocity_max = 2.6 * strength
	m.gravity = Vector3(0, -4.0, 0)
	m.scale_min = 0.012
	m.scale_max = 0.030
	m.color = color
	p.process_material = m

	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.draw_pass_1 = mesh

	_dynamic.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())


## Directional kick plus a brief push-in, on top of the random shake.
func _update_camera(delta: float) -> void:
	_cam_kick = _cam_kick.lerp(Vector3.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	_cam_zoom = lerpf(_cam_zoom, 0.0, clampf(delta * 6.0, 0.0, 1.0))

	var shake := Vector3.ZERO
	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 4.0)
		var s: float = _cam_shake * 0.06 * _settings.screen_shake
		shake = Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))

	var toward := (Vector3.ZERO - _cam_home).normalized() * _cam_zoom * 0.45
	_cam.position = _cam_home + shake + toward \
		+ _cam_kick * _settings.screen_shake
