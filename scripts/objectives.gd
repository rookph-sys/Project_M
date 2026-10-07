class_name Objectives
extends RefCounted

## Data-driven win conditions (GDD §19 / SPEC §59).
##
## Levels declare objectives as small dictionaries; nothing about winning is
## hardcoded in the game loop. Three tiers:
##
##   primary     must all pass to clear the level
##   additional  also must pass — used by Trials to force the player to
##               actually use the loaned marble rather than shelve it
##   secondary   optional, worth a medal each, never blocks progression
##
## ponytail: a match statement over type strings, not a class per objective.
## There are twelve of them and they are each two lines; a hierarchy would be
## more scaffolding than logic.


## `s` is the match stats dictionary game.gd accumulates.
static func met(obj: Dictionary, s: Dictionary) -> bool:
	var n: int = obj.get("count", 1)
	match obj["type"]:
		"ring_out":          return s.get("ring_outs", 0) >= n
		"sink":              return s.get("sinks", 0) >= n
		"win_match":         return s.get("won_match", false)
		"within_shots":      return s.get("shots_used", 99) <= n
		"multi_hit":         return s.get("multi_hits", 0) >= n
		"bank_shot":         return s.get("bank_shots", 0) >= n
		"no_marble_lost":    return s.get("marbles_lost", 0) == 0
		"max_marbles_lost":  return s.get("marbles_lost", 0) <= n
		"knock_out":         return s.get("knockouts", 0) >= n
		# Trial objectives — tied to one specific marble type.
		"marble_hits_target":
			return s.get("direct_hit_by", {}).get(obj["marble"], 0) >= n
		"marble_rings_out":
			return s.get("ring_out_by", {}).get(obj["marble"], 0) >= n
		"marble_bank_shot":
			return s.get("bank_shot_by", {}).get(obj["marble"], 0) >= n
		"magnet_affects":
			return s.get("magnet_affected", 0) >= n
		"marble_survives":
			return s.get("alive_at_end", {}).get(obj["marble"], false)
	push_warning("unknown objective type: %s" % obj["type"])
	return false


## Short line for the HUD.
static func describe(obj: Dictionary) -> String:
	var n: int = obj.get("count", 1)
	var marble: String = obj.get("marble", "")
	var name: String = MarbleData.DEFS[marble]["name"] if marble != "" else ""
	match obj["type"]:
		"ring_out":          return "Ring out %d" % n
		"sink":              return "Sink %d" % n
		"win_match":         return "Win the match"
		"within_shots":      return "Finish within %d shots" % n
		"multi_hit":         return "Land a multi-hit"
		"bank_shot":         return "Score a bank shot"
		"no_marble_lost":    return "Lose no marble"
		"max_marbles_lost":  return "Lose no more than %d marbles" % n
		"knock_out":         return "Knock out %d opponent marbles" % n
		"marble_hits_target":  return "%s must hit a target" % name
		"marble_rings_out":    return "%s must ring one out" % name
		"marble_bank_shot":    return "%s must bank a scoring shot" % name
		"magnet_affects":      return "Pulse must move %d targets" % n
		"marble_survives":     return "%s must survive" % name
	return obj["type"]


static func all_met(list: Array, s: Dictionary) -> bool:
	for o in list:
		if not met(o, s):
			return false
	return true


## §65 — one medal for clearing, one per secondary objective, max three.
static func medals_earned(level: Dictionary, s: Dictionary, won: bool) -> int:
	if not won:
		return 0
	var n := 1
	for o in level.get("secondary", []):
		if met(o, s):
			n += 1
	return mini(n, 3)


## Can the primary objectives still be reached? (§42)
## Only counting objectives can go impossible; a match-win cannot be ruled out
## until the match is actually over.
static func still_possible(level: Dictionary, s: Dictionary, live_targets: int,
		shots_left: int) -> bool:
	for o in level.get("primary", []) + level.get("additional", []):
		var n: int = o.get("count", 1)
		match o["type"]:
			"ring_out":
				if s.get("ring_outs", 0) + live_targets < n:
					return false
			"sink":
				if s.get("sinks", 0) + live_targets < n:
					return false
			"within_shots":
				if s.get("shots_used", 0) > n:
					return false
	return true
