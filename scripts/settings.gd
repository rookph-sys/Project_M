class_name Settings
extends RefCounted

## Player options, including the accessibility ones SPEC §71 asks for from the
## start rather than as a late retrofit.
##
## Kept separate from Progression: wiping your campaign should not reset your
## accessibility choices, and vice versa.

const PATH := "user://settings.json"

enum AimLine { OFF, SHORT, LONG }

var screen_shake := 1.0        # 0 disables it entirely
var slow_motion := true
var aim_line: AimLine = AimLine.SHORT
var colorblind := false        # adds shape markers instead of relying on hue
var text_scale := 1.0
var master_volume := 0.8
var music_volume := 0.5
var ai_think_visible := true   # show the opponent's deliberation pause


func clamp_all() -> void:
	screen_shake = clampf(screen_shake, 0.0, 1.0)
	text_scale = clampf(text_scale, 0.8, 1.6)
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)


func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(master, master_volume <= 0.001)


## Aim guide length in metres for a given marble, honouring the option.
func guide_length(marble_guide: float) -> float:
	match aim_line:
		AimLine.OFF: return 0.0
		AimLine.LONG: return marble_guide * 2.2
		_: return marble_guide


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"screen_shake": screen_shake,
		"slow_motion": slow_motion,
		"aim_line": int(aim_line),
		"colorblind": colorblind,
		"text_scale": text_scale,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"ai_think_visible": ai_think_visible,
	}, "\t"))
	f.close()


func load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("settings unreadable; using defaults")
		return
	screen_shake = float(d.get("screen_shake", screen_shake))
	slow_motion = bool(d.get("slow_motion", slow_motion))
	aim_line = int(d.get("aim_line", int(aim_line))) as AimLine
	colorblind = bool(d.get("colorblind", colorblind))
	text_scale = float(d.get("text_scale", text_scale))
	master_volume = float(d.get("master_volume", master_volume))
	music_volume = float(d.get("music_volume", music_volume))
	ai_think_visible = bool(d.get("ai_think_visible", ai_think_visible))
	clamp_all()
	apply_audio()


## §71 — targets must be tellable from player marbles without relying on hue.
## Returns a short tag drawn next to the marble when colourblind mode is on.
func marker_for(owner_id: int, is_target: bool) -> String:
	if not colorblind:
		return ""
	if is_target:
		return "◆"
	return "●" if owner_id == 0 else "▲"
