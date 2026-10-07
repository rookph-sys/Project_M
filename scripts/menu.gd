extends CanvasLayer

## Campaign shell: level select, deck builder, collection (SPEC §80).
##
## ponytail: one CanvasLayer with three swapped panels, built in code. Separate
## scenes per screen would mean three .tscn files to keep in sync with the data
## they display, for three screens that are each a list and some buttons.

signal play_requested(level_index: int, bag: Array)

enum Screen { LEVELS, DECK, COLLECTION, SETTINGS }

const SLOTS := 8

var prog: Progression
var settings: Settings
var screen: Screen = Screen.LEVELS
var _level_index := 0
var _bag: Array[String] = []

var _root: Control
var _title: Label
var _subtitle: Label
var _body: VBoxContainer
var _footer: Label


func setup(progression: Progression, opts: Settings) -> void:
	prog = progression
	settings = opts
	layer = 20
	_build()
	show_levels()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.035, 0.048, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 70
	col.offset_right = -70
	col.offset_top = 46
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)

	_title = _label(42, Color(0.95, 0.96, 1.0))
	col.add_child(_title)
	_subtitle = _label(17, Color(0.60, 0.66, 0.78))
	col.add_child(_subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	col.add_child(spacer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)

	_footer = _label(15, Color(0.45, 0.50, 0.62))
	col.add_child(_footer)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()
		_body.remove_child(c)


func _button(text: String, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	if enabled:
		_add_hover_lift(b)
	return b


## Rows lean toward the cursor. Cheap, and it makes a list of buttons feel like
## objects rather than regions of a page.
func _add_hover_lift(b: Button) -> void:
	b.pivot_offset = Vector2(0, 23)
	b.mouse_entered.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(1.012, 1.10), 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.12))


# ----------------------------------------------------------- level select ----

func show_levels() -> void:
	screen = Screen.LEVELS
	visible = true
	_clear_body()
	_title.text = "PROJECT MARBLES"
	_subtitle.text = "Chapter 1 — %d of %d cleared" % [_cleared_count(), Levels.count()]
	_footer.text = "[C] collection      [O] settings      [Esc] back      click a level to play"

	for i in Levels.count():
		var lvl: Dictionary = Levels.ALL[i]
		var unlocked: bool = prog.is_level_unlocked(i)
		var done: bool = prog.is_level_complete(i)
		var m: int = prog.medals_for(i)

		var label := "%2d.  %-22s" % [i + 1, lvl["name"] if unlocked else "? ? ?"]
		if unlocked:
			label += "   %s" % ("★".repeat(m) + "☆".repeat(3 - m))
			if done:
				label += "   best %d" % prog.score_for(i)
			label += "      %s" % _mode_name(lvl)
			if lvl.has("loaned"):
				label += "   ·   TRIAL: %s" % MarbleData.get_def(lvl["loaned"][0])["name"]
		else:
			label += "   locked"

		var b := _button(label, unlocked)
		if unlocked:
			b.pressed.connect(_on_level_picked.bind(i))
		_body.add_child(b)


func _mode_name(lvl: Dictionary) -> String:
	match lvl["mode"]:
		"ringer": return "Ringer"
		"holes": return "Holes"
		"duel": return "Duel vs %s AI" % MarbleAI.PROFILES[lvl["ai_level"]]["name"]
	return lvl["mode"]


func _cleared_count() -> int:
	var n := 0
	for i in Levels.count():
		if prog.is_level_complete(i):
			n += 1
	return n


func _on_level_picked(index: int) -> void:
	_level_index = index
	var lvl: Dictionary = Levels.ALL[index]
	# §28 — the deck builder only appears once it has been earned, and only
	# when the level actually leaves a choice to make.
	var choices := Levels.allowed_marbles(lvl, prog)
	if not prog.deck_builder_unlocked or choices.size() <= 1:
		emit_signal("play_requested", index, lvl["bag"].duplicate())
		visible = false
		return
	var default_bag: Array[String] = []
	default_bag.assign(lvl["bag"])
	_bag = prog.loadout_for(index, default_bag)
	show_deck()


# ----------------------------------------------------------- deck builder ----

func show_deck() -> void:
	screen = Screen.DECK
	visible = true
	_clear_body()
	var lvl: Dictionary = Levels.ALL[_level_index]
	_title.text = "DECK — %s" % lvl["name"]
	_subtitle.text = lvl["hint"]
	_footer.text = "[Enter] start      [Esc] back      Standard is unlimited, one of each special"

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	_body.add_child(slots)
	for i in SLOTS:
		var id: String = _bag[i] if i < _bag.size() else ""
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 74)
		b.add_theme_font_size_override("font_size", 15)
		b.text = "%d\n%s" % [i + 1, MarbleData.get_def(id)["name"] if id != "" else "—"]
		if id != "":
			var c: Color = MarbleData.get_def(id)["color"]
			b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(8)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(_on_slot_cleared.bind(i))
		slots.add_child(b)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	_body.add_child(gap)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	_body.add_child(head)
	if _preview_vp == null:
		head.add_child(_make_preview())
	else:
		var r := TextureRect.new()
		r.texture = _preview_vp.get_texture()
		r.custom_minimum_size = Vector2(220, 220)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(r)
	var avail := _label(16, Color(0.6, 0.66, 0.78))
	avail.text = "AVAILABLE"
	head.add_child(avail)

	for id in Levels.allowed_marbles(lvl, prog):
		var d: Dictionary = MarbleData.get_def(id)
		var legal: bool = _can_add(id)
		var loaned: String = "   (loaned for this trial)" if id in lvl.get("loaned", []) else ""
		var b := _button("%-11s %s%s" % [d["name"], d["desc"], loaned], legal)
		b.add_theme_color_override("font_color", d["color"])
		b.pressed.connect(_on_marble_added.bind(id))
		b.mouse_entered.connect(set_preview.bind(id))
		_body.add_child(b)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	_body.add_child(gap2)

	if _preview_id == "":
		set_preview(_bag[0] if not _bag.is_empty() and _bag[0] != "" else "standard")

	var full: bool = _filled() == SLOTS
	var start := _button("START  —  %d / %d slots filled" % [_filled(), SLOTS], full)
	start.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.pressed.connect(_on_start)
	_body.add_child(start)

	var fill := _button("Fill the rest with Standard")
	fill.alignment = HORIZONTAL_ALIGNMENT_CENTER
	fill.pressed.connect(_on_autofill)
	_body.add_child(fill)


func _filled() -> int:
	var n := 0
	for id in _bag:
		if id != "":
			n += 1
	return n


## §57 — Standard unlimited, at most one copy of each special.
func _can_add(id: String) -> bool:
	if _filled() >= SLOTS:
		return false
	if id == "standard":
		return true
	return not (id in _bag)


func _on_marble_added(id: String) -> void:
	if not _can_add(id):
		return
	for i in SLOTS:
		if i >= _bag.size():
			_bag.append("")
		if _bag[i] == "":
			_bag[i] = id
			break
	show_deck()


func _on_slot_cleared(index: int) -> void:
	if index < _bag.size():
		_bag[index] = ""
	show_deck()


func _on_autofill() -> void:
	for i in SLOTS:
		if i >= _bag.size():
			_bag.append("")
		if _bag[i] == "":
			_bag[i] = "standard"
	show_deck()


func _on_start() -> void:
	if _filled() != SLOTS:
		return
	prog.remember_loadout(_level_index, _bag)
	emit_signal("play_requested", _level_index, _bag.duplicate())
	visible = false


# ------------------------------------------------------------- collection ----

func show_collection() -> void:
	screen = Screen.COLLECTION
	visible = true
	_clear_body()
	_title.text = "COLLECTION"
	_subtitle.text = "%d of 6 marbles unlocked" % prog.unlocked.size()
	_footer.text = "[Esc] back"

	var usage: Dictionary = prog.stats.get("marble_usage", {})
	for id in MarbleData.DEFS:
		if id == "target":
			continue
		var d: Dictionary = MarbleData.get_def(id)
		var owned: bool = prog.has_marble(id)
		var row := _label(18, d["color"] if owned else Color(0.26, 0.28, 0.34))
		if owned:
			# §27 — bars, not raw physics numbers.
			row.text = "%-11s  %s   %s   used %d" % [
				d["name"], _bars(d), d["desc"], usage.get(id, 0)]
		else:
			row.text = "%-11s  ?????   locked — earn it in a Trial" % "???"
		row.custom_minimum_size = Vector2(0, 34)
		_body.add_child(row)


## §27 — Power / Weight / Bounce / Control as five-dot bars.
func _bars(d: Dictionary) -> String:
	var power: float = d["target_dist"] / 6.0
	var weight: float = d["mass"] / 1.8
	var bounce: float = d["bounce"]
	var control: float = 1.0 - (d["lin_damp"] - 1.0)
	return "P%s W%s B%s C%s" % [_dots(power), _dots(weight), _dots(bounce), _dots(control)]


func _dots(v: float) -> String:
	var n: int = clampi(int(round(v * 5.0)), 1, 5)
	return "●".repeat(n) + "○".repeat(5 - n)


# ------------------------------------------------------------------ input ----

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("cancel_menu"):
		_wipe_armed = false
		match screen:
			Screen.DECK: show_levels()
			Screen.COLLECTION: show_levels()
			Screen.SETTINGS: show_levels()
			_: pass
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("collection") and screen == Screen.LEVELS:
		show_collection()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("settings") and screen == Screen.LEVELS:
		show_settings()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("confirm") and screen == Screen.DECK:
		_on_start()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------- settings ----
#
# §71 wanted these from the start rather than bolted on at the end, because
# retrofitting a screen-shake slider means auditing every place that shakes.

func show_settings() -> void:
	screen = Screen.SETTINGS
	visible = true
	_clear_body()
	_title.text = "SETTINGS"
	_subtitle.text = "Accessibility and feel"
	_footer.text = "[Esc] back      changes save immediately"

	_slider("Screen shake", settings.screen_shake, 0.0, 1.0,
		func(v): settings.screen_shake = v)
	_toggle("Slow motion on the winning shot", settings.slow_motion,
		func(v): settings.slow_motion = v)
	_choice("Aim guide", ["Off", "Short", "Long"], int(settings.aim_line),
		func(v): settings.aim_line = v as Settings.AimLine)
	_toggle("Colourblind markers on marbles", settings.colorblind,
		func(v): settings.colorblind = v)
	_slider("Text size", settings.text_scale, 0.8, 1.6,
		func(v): settings.text_scale = v)
	_slider("Volume", settings.master_volume, 0.0, 1.0,
		func(v): settings.master_volume = v; settings.apply_audio())
	_toggle("Pause while the opponent thinks", settings.ai_think_visible,
		func(v): settings.ai_think_visible = v)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	_body.add_child(gap)
	var wipe := _button("Erase all campaign progress")
	wipe.alignment = HORIZONTAL_ALIGNMENT_CENTER
	wipe.pressed.connect(_on_wipe_requested)
	_body.add_child(wipe)


var _wipe_armed := false

## Erasing a campaign is not undoable, so it takes two deliberate clicks.
func _on_wipe_requested() -> void:
	if not _wipe_armed:
		_wipe_armed = true
		_footer.text = "[Esc] back      click again to confirm — this cannot be undone"
		return
	_wipe_armed = false
	prog.wipe()
	show_levels()


func _row(label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := _label(17, Color(0.82, 0.86, 0.95))
	l.text = label
	l.custom_minimum_size = Vector2(380, 40)
	row.add_child(l)
	_body.add_child(row)
	return row


func _slider(label: String, value: float, lo: float, hi: float, on_set: Callable) -> void:
	var row := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 32)
	var readout := _label(16, Color(0.55, 0.62, 0.75))
	readout.text = "%d%%" % roundi(value * 100.0)
	s.value_changed.connect(func(v):
		on_set.call(v)
		readout.text = "%d%%" % roundi(v * 100.0)
		settings.save())
	row.add_child(s)
	row.add_child(readout)


func _toggle(label: String, value: bool, on_set: Callable) -> void:
	var row := _row(label)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.text = "ON" if value else "OFF"
	b.custom_minimum_size = Vector2(90, 36)
	b.toggled.connect(func(v):
		b.text = "ON" if v else "OFF"
		on_set.call(v)
		settings.save())
	row.add_child(b)


func _choice(label: String, options: Array, index: int, on_set: Callable) -> void:
	var row := _row(label)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(90, 36)
		b.disabled = i == index
		b.pressed.connect(func():
			on_set.call(i)
			settings.save()
			show_settings())
		row.add_child(b)


# ---------------------------------------------------- 3D marble preview ----
#
# A real marble turning in a SubViewport, rather than a coloured rectangle.
# One viewport, reused — eight of them would cost eight renders a frame for a
# screen that is mostly reading text.

var _preview_vp: SubViewport
var _preview_marble: MeshInstance3D
var _preview_id := ""


func _make_preview() -> TextureRect:
	_preview_vp = SubViewport.new()
	_preview_vp.size = Vector2i(220, 220)
	_preview_vp.transparent_bg = true
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_preview_vp)

	var world := Node3D.new()
	_preview_vp.add_child(world)

	var cam3d := Camera3D.new()
	cam3d.position = Vector3(0, 0.07, 0.34)
	cam3d.fov = 40.0
	world.add_child(cam3d)
	cam3d.look_at(Vector3.ZERO, Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 2.2
	world.add_child(key)

	_preview_marble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.10
	sm.height = 0.20
	sm.radial_segments = 48
	sm.rings = 24
	_preview_marble.mesh = sm
	world.add_child(_preview_marble)

	var rect := TextureRect.new()
	rect.texture = _preview_vp.get_texture()
	rect.custom_minimum_size = Vector2(220, 220)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func set_preview(id: String) -> void:
	if _preview_marble == null or id == _preview_id or not MarbleData.DEFS.has(id):
		return
	_preview_id = id
	var d: Dictionary = MarbleData.get_def(id)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = d["color"]
	mat.metallic = 0.35
	mat.metallic_specular = 0.85
	mat.roughness = 0.08
	mat.rim_enabled = true
	mat.rim = 0.85
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.9
	_preview_marble.material_override = mat


func _process(delta: float) -> void:
	if _preview_marble and visible:
		_preview_marble.rotate_y(delta * 1.1)
		_preview_marble.rotate_x(delta * 0.35)
