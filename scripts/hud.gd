extends CanvasLayer

## §49 UI layout: objective and shots on top, bag along the bottom.
## Built in code so there is no .tscn to drift out of sync with the fields.

var _top: Label
var _score: Label
var _banner: Label
var _sub: Label
var _bag_row: HBoxContainer
var _info: Label
var _keys: Label
var _power_bg: ColorRect
var _power_fill: ColorRect
var _debug: Label
var _banner_t := 0.0
var _chips: Array[Panel] = []

const FONT_BIG := 44
const FONT_MED := 26
const FONT_SMALL := 18


func _ready() -> void:
	layer = 10

	_top = _label(FONT_MED, Color(0.92, 0.94, 1.0))
	_top.position = Vector2(42, 28)
	add_child(_top)

	_score = _label(FONT_MED, Color(0.95, 0.82, 0.35))
	_score.position = Vector2(42, 64)
	add_child(_score)

	_banner = _label(FONT_BIG, Color(1, 1, 1))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 150
	add_child(_banner)

	_sub = _label(FONT_SMALL, Color(0.7, 0.75, 0.85))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.offset_top = 206
	add_child(_sub)

	_power_bg = ColorRect.new()
	_power_bg.color = Color(1, 1, 1, 0.10)
	_power_bg.size = Vector2(320, 12)
	_power_bg.position = Vector2(42, 108)
	add_child(_power_bg)

	_power_fill = ColorRect.new()
	_power_fill.color = Color(0.45, 1.0, 0.65)
	_power_fill.size = Vector2(0, 12)
	_power_fill.position = Vector2(42, 108)
	add_child(_power_fill)

	_bag_row = HBoxContainer.new()
	_bag_row.add_theme_constant_override("separation", 10)
	_bag_row.anchor_top = 1.0
	_bag_row.anchor_bottom = 1.0
	_bag_row.offset_top = -102
	_bag_row.offset_left = 42
	add_child(_bag_row)

	# Above the chips, not through them.
	_info = _label(FONT_SMALL, Color(0.82, 0.86, 0.95))
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_top = -132
	_info.offset_left = 42
	add_child(_info)

	_keys = _label(15, Color(0.45, 0.5, 0.6))
	_keys.anchor_top = 1.0
	_keys.anchor_bottom = 1.0
	_keys.anchor_left = 1.0
	_keys.anchor_right = 1.0
	_keys.offset_top = -34
	_keys.offset_left = -640
	_keys.text = "[1-8] pick marble    [RMB] cancel    [R] retry    [N] next level    [F1] debug"
	add_child(_keys)

	_debug = _label(14, Color(0.5, 1.0, 0.6))
	_debug.anchor_left = 1.0
	_debug.anchor_right = 1.0
	_debug.offset_left = -300
	_debug.offset_top = 28
	_debug.visible = false
	add_child(_debug)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func sub_detail(extra: String) -> void:
	_sub.text = "%s      %s" % [extra, _sub.text]


func flash(title: String, sub: String) -> void:
	_banner.text = title
	_sub.text = sub
	_banner_t = 3.2


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		var a: float = clampf(_banner_t, 0.0, 1.0)
		_banner.modulate.a = a
		_sub.modulate.a = a
	else:
		_banner.modulate.a = 0.0
		_sub.modulate.a = 0.0


func refresh(g) -> void:
	if g.is_versus:
		var ai_left := 0
		for u in g.ai_bag_used:
			if not u:
				ai_left += 1
		var turn: String = "YOUR TURN" if g.turn_actor == g.ACTOR_PLAYER else "OPPONENT"
		if g.state == g.St.RESOLVE:
			turn = ""
		elif g.state == g.St.AI_TURN:
			turn = "OPPONENT THINKING"
		var reds: String = ("     REDS LEFT  %d" % g._live_targets()) if g.has_ring else ""
		_top.text = "YOU %d  —  %d AI          SHOTS  %d / %d%s        %s" % [
			g.match_points[0], g.match_points[1], g.shots_left, ai_left, reds, turn]
		_score.add_theme_color_override("font_color",
			g.HALO_PLAYER if g.turn_actor == g.ACTOR_PLAYER else g.HALO_AI)
	else:
		var goals: Array[String] = []
		for o in g.level.get("primary", []) + g.level.get("additional", []):
			var done: bool = Objectives.met(o, g.match_stats)
			goals.append("%s %s" % ["[x]" if done else "[ ]", Objectives.describe(o)])
		_top.text = "%s          SHOTS  %d" % ["     ".join(goals), g.shots_left]
	_score.text = "SCORE  %d" % g.score
	_power_fill.size.x = 320.0 * g._aim_power
	_power_fill.color = Color(0.45, 1.0, 0.65).lerp(Color(1.0, 0.35, 0.25), g._aim_power)

	_sync_bag(g)

	if g.selected < g.bag.size():
		var d: Dictionary = MarbleData.get_def(g.bag[g.selected])
		var ability: String = ("   ·   %s" % d["desc"]) if d["desc"] != "" else ""
		_info.text = "%s%s" % [d["name"], ability]
		var secondary: Array[String] = []
		for o in g.level.get("secondary", []):
			secondary.append("%s %s" % [
				"★" if Objectives.met(o, g.match_stats) else "☆",
				Objectives.describe(o)])
		if not secondary.is_empty():
			_info.text += "        " + "   ".join(secondary)

	_debug.visible = g._debug
	if g._debug:
		var active := 0
		var fastest := 0.0
		for m in g.marbles:
			if is_instance_valid(m) and not m.is_resting():
				active += 1
				fastest = maxf(fastest, m.linear_velocity.length())
		_debug.text = "\n".join([
			"fps            %d" % Engine.get_frames_per_second(),
			"physics tick   %d Hz" % Engine.physics_ticks_per_second,
			"state          %s" % g.St.keys()[g.state],
			"power          %.2f" % g._aim_power,
			"moving bodies  %d" % active,
			"fastest        %.3f m/s" % fastest,
			"resolve time   %.2f s" % g._resolve_time,
			"marbles        %d" % g.marbles.size(),
		])


func _sync_bag(g) -> void:
	if _chips.size() != g.bag.size():
		for c in _bag_row.get_children():
			c.queue_free()
		_chips.clear()
		for i in g.bag.size():
			var p := Panel.new()
			p.custom_minimum_size = Vector2(76, 76)
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(10)
			p.add_theme_stylebox_override("panel", sb)
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 15)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.anchor_right = 1.0
			l.anchor_bottom = 1.0
			p.add_child(l)
			_bag_row.add_child(p)
			_chips.append(p)

	for i in _chips.size():
		var p := _chips[i]
		var d: Dictionary = MarbleData.get_def(g.bag[i])
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
		var col: Color = d["color"]
		if g.bag_used[i]:
			sb.bg_color = Color(col.r, col.g, col.b, 0.12)
			sb.border_width_bottom = 0
			sb.set_border_width_all(0)
		else:
			sb.bg_color = Color(col.r, col.g, col.b, 0.85)
			sb.set_border_width_all(3 if i == g.selected else 0)
			sb.border_color = Color(1, 1, 1, 0.95)
		var l: Label = p.get_child(0)
		l.text = "%d\n%s" % [i + 1, d["name"]]
		l.add_theme_color_override("font_color",
			Color(1, 1, 1, 0.25) if g.bag_used[i] else Color(0.05, 0.05, 0.08))
