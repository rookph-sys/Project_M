class_name Juice
extends CanvasLayer

## Feedback layer (SPEC §55, §2.4).
##
## What is taken from Balatro here is the philosophy §52 lists — strong
## feedback, large numbers, fast transitions, escalation — not its look. No
## card layout, no palette, no CRT.
##
## The rule everything below follows: an event's loudness scales with how much
## it mattered. A glancing tap gets a tick. The shot that wins the level gets
## the works.

const POP_RISE := 86.0           # pixels a score popup drifts upward
const POP_LIFE := 0.95

var cam: Camera3D
var settings: Settings

var _flash: ColorRect
var _vignette: ColorRect
var _combo_label: Label
var _combo_t := 0.0
var _hit_stop_until := 0


func setup(camera: Camera3D, opts: Settings) -> void:
	cam = camera
	settings = opts
	layer = 15                   # above the HUD (10), below the menu (20)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_combo_label = _make_label(72)
	_combo_label.modulate.a = 0.0
	# Parked on the empty left side rather than centred: popups fly out from
	# wherever the marble crossed the line, and a centred combo sat on top of
	# them about half the time.
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_label.anchor_top = 0.5
	_combo_label.offset_left = 62
	_combo_label.offset_top = -40
	add_child(_combo_label)


func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A number that punches out of the point it happened at.
##
## `step` is how many scoring events this shot has already produced: each one
## lands bigger, higher and hotter than the last. That escalation is the single
## most load-bearing piece of juice in the whole game.
func popup(world_pos: Vector3, text: String, base_color: Color, step: int = 0) -> void:
	if cam == null:
		return
	var size: int = int(round((62 + step * 14) * _text_scale()))
	var l := _make_label(size)
	l.text = text
	var hot: Color = base_color.lerp(Color(1.0, 0.92, 0.35), minf(step * 0.22, 0.85))
	l.add_theme_color_override("font_color", hot)
	add_child(l)

	var at := cam.unproject_position(world_pos)
	l.position = at - Vector2(140, 44)
	l.size = Vector2(280, 88)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.25, 0.25)
	l.rotation = randf_range(-0.13, 0.13)

	var t := create_tween()
	t.set_parallel(true)
	# Overshoot then settle — a straight scale-in reads as a UI element, the
	# overshoot reads as an impact.
	t.tween_property(l, "scale", Vector2.ONE * (1.0 + step * 0.06), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y - POP_RISE, POP_LIFE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, POP_LIFE * 0.6).set_delay(POP_LIFE * 0.4)
	t.chain().tween_callback(l.queue_free)


## Big centred multiplier, Balatro's one unmissable readout.
func combo(count: int) -> void:
	if count < 2:
		return
	_combo_label.text = "%d× COMBO" % count
	_combo_label.add_theme_font_size_override("font_size",
		int(round((64 + count * 12) * _text_scale())))
	_combo_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.25), minf(count * 0.2, 1.0)))
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_label.scale = Vector2(0.5, 0.5)
	_combo_label.modulate.a = 1.0
	_combo_label.rotation = randf_range(-0.05, 0.05)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_combo_label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_combo_label, "modulate:a", 0.0, 0.5).set_delay(0.55)


## A wash of colour over the whole screen. Kept brief and low-alpha; this is
## seasoning, and at full strength it reads as a bug.
func flash(color: Color, strength: float = 0.25) -> void:
	var s: float = strength * _shake_scale()
	if s <= 0.001:
		return
	# Deliberately subtle. At the first strength I tried this tinted the whole
	# table and read as a rendering fault rather than as impact.
	_flash.color = Color(color.r, color.g, color.b, clampf(s, 0.0, 0.14))
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.18)


## A true freeze: the scene tree pauses, so zero physics steps run and the
## simulation cannot drift. Unlike Engine.time_scale, which does change results
## because the engine keeps integrating at a rate the game code cannot see.
func hit_stop(seconds: float) -> void:
	if seconds <= 0.0 or get_tree().paused:
		return
	get_tree().paused = true
	# process_always, or the timer would be frozen along with everything else.
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(func(): get_tree().paused = false)


func _text_scale() -> float:
	return settings.text_scale if settings else 1.0


func _shake_scale() -> float:
	# The screen-shake slider governs full-screen effects too: someone who
	# turned shake down did not ask for the screen to strobe instead.
	return settings.screen_shake if settings else 1.0


# --------------------------------------------------- impact distortion ----

var _shock: ColorRect
var _shock_mat: ShaderMaterial
var _shock_t := 0.0
var _shock_power := 0.0


func _ready() -> void:
	_shock = ColorRect.new()
	_shock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shock_mat = ShaderMaterial.new()
	_shock_mat.shader = load("res://shaders/impact.gdshader")
	_shock.material = _shock_mat
	# Behind the popups and the flash, in front of the 3D view.
	add_child(_shock)
	move_child(_shock, 0)
	_shock_mat.set_shader_parameter("strength", 0.0)


## Kick a shockwave off from a world point.
func shockwave(world_pos: Vector3, power: float) -> void:
	if cam == null or _shock_mat == null:
		return
	# Honour the shake slider: this is a full-screen effect and someone who
	# turned shake off did not ask for the picture to warp instead.
	var p: float = clampf(power, 0.0, 1.0) * _shake_scale()
	if p <= 0.02 or p < _shock_power * 0.6:
		return
	var vp := get_viewport().get_visible_rect().size
	var at := cam.unproject_position(world_pos)
	_shock_mat.set_shader_parameter("centre", at / vp)
	_shock_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_shock_power = p
	_shock_t = 0.0


func _process(delta: float) -> void:
	if _shock_power <= 0.001:
		return
	_shock_t += delta * 2.6
	if _shock_t >= 1.0:
		_shock_power = 0.0
		_shock_mat.set_shader_parameter("strength", 0.0)
		return
	var fade: float = _shock_power * (1.0 - _shock_t)
	_shock_mat.set_shader_parameter("wave", _shock_t * 0.75)
	_shock_mat.set_shader_parameter("strength", fade)
	_shock_mat.set_shader_parameter("aberration", fade * 2.2)
