extends CanvasLayer

## Campaign shell: level select, deck builder, collection (SPEC §80).
##
## ponytail: one CanvasLayer with three swapped panels, built in code. Separate
## scenes per screen would mean three .tscn files to keep in sync with the data
## they display, for three screens that are each a list and some buttons.

signal play_requested(level_index: int, bag: Array)

enum Screen { LEVELS, DECK, COLLECTION }

const SLOTS := 8

var prog: Progression
var screen: Screen = Screen.LEVELS
var _level_index := 0
var _bag: Array[String] = []

var _root: Control
var _title: Label
var _subtitle: Label
var _body: VBoxContainer
var _footer: Label


func setup(progression: Progression) -> void:
	prog = progression
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
	return b


# ----------------------------------------------------------- level select ----

func show_levels() -> void:
	screen = Screen.LEVELS
	visible = true
	_clear_body()
	_title.text = "PROJECT MARBLES"
	_subtitle.text = "Chapter 1 — %d of %d cleared" % [_cleared_count(), Levels.count()]
	_footer.text = "[C] collection      [Esc] back      click a level to play"

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

	var avail := _label(16, Color(0.6, 0.66, 0.78))
	avail.text = "AVAILABLE"
	_body.add_child(avail)

	for id in Levels.allowed_marbles(lvl, prog):
		var d: Dictionary = MarbleData.get_def(id)
		var legal: bool = _can_add(id)
		var loaned: String = "   (loaned for this trial)" if id in lvl.get("loaned", []) else ""
		var b := _button("%-11s %s%s" % [d["name"], d["desc"], loaned], legal)
		b.add_theme_color_override("font_color", d["color"])
		b.pressed.connect(_on_marble_added.bind(id))
		_body.add_child(b)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	_body.add_child(gap2)

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
		match screen:
			Screen.DECK: show_levels()
			Screen.COLLECTION: show_levels()
			_: pass
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("collection") and screen == Screen.LEVELS:
		show_collection()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("confirm") and screen == Screen.DECK:
		_on_start()
		get_viewport().set_input_as_handled()
