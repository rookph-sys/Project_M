class_name Progression
extends RefCounted

## Save data and campaign state (SPEC §30, §55, §57-58).
##
## ponytail: one JSON file, loaded once, written on change. No migration
## framework, no autosave thread, no compression — the whole payload is a few
## hundred bytes. `version` is here so a future format change has something to
## branch on, which is the one piece of future-proofing that actually pays.

const PATH := "user://save.json"
const VERSION := 1

## Marbles the player owns from the start. The rest are earned (§25).
const STARTING_MARBLES := ["standard"]

var unlocked: Array[String] = []
var completed: Dictionary = {}       # level_id -> true
var best_score: Dictionary = {}      # level_id -> int
var medals: Dictionary = {}          # level_id -> int (0-3)
var loadouts: Dictionary = {}        # level_id -> Array[String]
var stats: Dictionary = {}           # §31 lifetime counters
var deck_builder_unlocked := false
var unlocked_all_levels := false


func _init() -> void:
	reset()


func reset() -> void:
	unlocked.assign(STARTING_MARBLES)
	completed.clear()
	best_score.clear()
	medals.clear()
	loadouts.clear()
	deck_builder_unlocked = false
	unlocked_all_levels = false
	stats = {
		"shots_fired": 0, "targets_hit": 0, "marbles_knocked_out": 0,
		"marbles_sunk": 0, "bank_shots": 0, "multi_hits": 0,
		"wins": 0, "losses": 0, "playtime": 0.0,
		"marble_usage": {},
	}


func has_marble(id: String) -> bool:
	return id in unlocked


func unlock_marble(id: String) -> bool:
	if id in unlocked:
		return false
	unlocked.append(id)
	save()
	return true


## A level is playable once the one before it is done. Level 1 always is.
func is_level_unlocked(index: int) -> bool:
	if unlocked_all_levels or index <= 0:
		return true
	return completed.get(_key(index - 1), false)


func is_level_complete(index: int) -> bool:
	return completed.get(_key(index), false)


func score_for(index: int) -> int:
	return best_score.get(_key(index), 0)


func medals_for(index: int) -> int:
	return medals.get(_key(index), 0)


## §55 — a best score is only recorded on a win.
func record_result(index: int, won: bool, score: int, earned_medals: int) -> Dictionary:
	var key := _key(index)
	var news := {"first_clear": false, "new_best": false, "new_medals": 0}

	if won:
		news["first_clear"] = not completed.get(key, false)
		completed[key] = true
		if score > best_score.get(key, 0):
			best_score[key] = score
			news["new_best"] = not news["first_clear"]
		var before: int = medals.get(key, 0)
		if earned_medals > before:
			medals[key] = earned_medals
			news["new_medals"] = earned_medals - before
		stats["wins"] = stats.get("wins", 0) + 1
	else:
		stats["losses"] = stats.get("losses", 0) + 1

	save()
	return news


func remember_loadout(index: int, bag: Array[String]) -> void:
	loadouts[_key(index)] = bag.duplicate()
	save()


func loadout_for(index: int, fallback: Array[String]) -> Array[String]:
	var saved: Array = loadouts.get(_key(index), [])
	var out: Array[String] = []
	for id in saved:
		# Drop anything that is no longer legal — a marble could in principle
		# vanish from the roster between builds.
		if MarbleData.DEFS.has(id) and has_marble(id):
			out.append(id)
	if out.size() != fallback.size():
		return fallback.duplicate()
	return out


func bump(stat: String, amount: int = 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount


func note_marble_use(id: String) -> void:
	var usage: Dictionary = stats.get("marble_usage", {})
	usage[id] = usage.get(id, 0) + 1
	stats["marble_usage"] = usage


# ----------------------------------------------------------------- disk ----

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("could not write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({
		"version": VERSION,
		"unlocked": unlocked,
		"completed": completed,
		"best_score": best_score,
		"medals": medals,
		"loadouts": loadouts,
		"stats": stats,
		"deck_builder_unlocked": deck_builder_unlocked,
	}, "\t"))
	f.close()


func load() -> void:
	reset()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save file unreadable; starting fresh")
		return
	if int(parsed.get("version", 0)) != VERSION:
		push_warning("save file is version %s, expected %d; starting fresh"
			% [parsed.get("version", "?"), VERSION])
		return

	unlocked.assign(parsed.get("unlocked", STARTING_MARBLES))
	completed = parsed.get("completed", {})
	best_score = parsed.get("best_score", {})
	medals = parsed.get("medals", {})
	loadouts = parsed.get("loadouts", {})
	stats = parsed.get("stats", stats)
	deck_builder_unlocked = parsed.get("deck_builder_unlocked", false)


func wipe() -> void:
	reset()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	save()


# JSON object keys are strings, so level indices are stored as strings too —
# round-tripping ints through JSON would silently turn them into floats.
func _key(index: int) -> String:
	return "L%02d" % index


## Opens everything: every marble, the deck builder, and every level. Driven
## by `--unlock-all` so the game can be shown off without replaying the
## campaign first. Deliberately not saved to disk — it lasts for the run, so
## it cannot quietly overwrite somebody's real progress.
func unlock_everything() -> void:
	for id in MarbleData.DEFS:
		if id != "target" and not (id in unlocked):
			unlocked.append(id)
	deck_builder_unlocked = true
	unlocked_all_levels = true
