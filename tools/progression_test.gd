extends SceneTree

## Save, unlock and objective logic, headless.
##
##   godot --headless --script res://tools/progression_test.gd
##
## Wipes the save file, so do not run it while you care about your progress.

var _fail := 0


func _initialize() -> void:
	_run()
	quit(0 if _fail == 0 else 1)


func _check(label: String, got, want) -> void:
	var ok: bool = str(got) == str(want)
	if not ok:
		_fail += 1
	print("     %-52s %s" % [label, "ok" if ok else "FAIL got=%s want=%s" % [got, want]])


func _run() -> void:
	print("")
	print("  save round-trip")
	var p := Progression.new()
	p.wipe()
	_check("starts with only Standard", p.unlocked, ["standard"])
	_check("level 1 unlocked", p.is_level_unlocked(0), true)
	_check("level 2 locked", p.is_level_unlocked(1), false)

	p.record_result(0, true, 2700, 2)
	p.unlock_marble("precision")
	p.remember_loadout(0, ["standard", "precision"] as Array[String])

	var q := Progression.new()
	q.load()
	_check("completion persisted", q.is_level_complete(0), true)
	_check("best score persisted", q.score_for(0), 2700)
	_check("medals persisted", q.medals_for(0), 2)
	_check("unlock persisted", q.has_marble("precision"), true)
	_check("level 2 now unlocked", q.is_level_unlocked(1), true)
	_check("loadout persisted", q.loadout_for(0, ["standard", "standard"] as Array[String]), ["standard", "precision"])
	_check("saved deck of the wrong size is rejected",
		q.loadout_for(0, ["standard"] as Array[String]), ["standard"])

	print("")
	print("  best score only improves, and only on a win")
	q.record_result(0, true, 1000, 1)
	_check("lower score ignored", q.score_for(0), 2700)
	_check("lower medals ignored", q.medals_for(0), 2)
	q.record_result(0, false, 9999, 3)
	_check("loss records no score", q.score_for(0), 2700)
	q.record_result(0, true, 5000, 3)
	_check("higher score kept", q.score_for(0), 5000)

	print("")
	print("  corrupt save does not crash")
	var f := FileAccess.open(Progression.PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var r := Progression.new()
	r.load()
	_check("falls back to defaults", r.unlocked, ["standard"])

	print("")
	print("  objectives")
	var s := {
		"ring_outs": 3, "sinks": 0, "shots_used": 5, "marbles_lost": 0,
		"bank_shots": 1, "multi_hits": 2, "knockouts": 2, "won_match": true,
		"magnet_affected": 2,
		"direct_hit_by": {"precision": 1}, "ring_out_by": {"heavy": 1},
		"bank_shot_by": {"rubber": 1}, "alive_at_end": {"sticky": true},
	}
	_check("ring_out 3 met", Objectives.met({"type": "ring_out", "count": 3}, s), true)
	_check("ring_out 4 unmet", Objectives.met({"type": "ring_out", "count": 4}, s), false)
	_check("within_shots 5 met", Objectives.met({"type": "within_shots", "count": 5}, s), true)
	_check("within_shots 4 unmet", Objectives.met({"type": "within_shots", "count": 4}, s), false)
	_check("no_marble_lost met", Objectives.met({"type": "no_marble_lost"}, s), true)
	_check("precision hit target",
		Objectives.met({"type": "marble_hits_target", "marble": "precision"}, s), true)
	_check("heavy ringed out",
		Objectives.met({"type": "marble_rings_out", "marble": "heavy"}, s), true)
	_check("rubber banked",
		Objectives.met({"type": "marble_bank_shot", "marble": "rubber"}, s), true)
	_check("sticky survived",
		Objectives.met({"type": "marble_survives", "marble": "sticky"}, s), true)
	_check("magnet moved two", Objectives.met({"type": "magnet_affects", "count": 2}, s), true)

	print("")
	print("  every level is well formed")
	var seen := {}
	for i in Levels.count():
		var lvl: Dictionary = Levels.ALL[i]
		var tag := "L%02d %s" % [i + 1, lvl["name"]]
		if lvl.get("primary", []).is_empty():
			print("     %-52s FAIL no primary objective" % tag); _fail += 1
		if seen.has(lvl["name"]):
			print("     %-52s FAIL duplicate name" % tag); _fail += 1
		seen[lvl["name"]] = true
		if lvl["bag"].size() != 8:
			print("     %-52s FAIL bag is %d, want 8" % [tag, lvl["bag"].size()]); _fail += 1

		# Every objective type must be one Objectives knows about.
		for o in lvl.get("primary", []) + lvl.get("additional", []) + lvl.get("secondary", []):
			Objectives.describe(o)
			Objectives.met(o, {})

		# Authored clusters must not start interpenetrating (§66).
		var pts: Array = lvl["targets"]
		for a in pts.size():
			for b in range(a + 1, pts.size()):
				var d: float = (pts[a] - pts[b]).length()
				if d < 0.25:
					print("     %-52s FAIL targets %.3f m apart" % [tag, d]); _fail += 1

		# A bank-shot objective needs something to bank off.
		for o in lvl.get("additional", []) + lvl.get("secondary", []):
			if o["type"] in ["bank_shot", "marble_bank_shot"] and lvl["bumpers"].is_empty():
				print("     %-52s FAIL bank objective, no bank surface" % tag); _fail += 1

		# A trial must actually lend what it demands.
		for o in lvl.get("additional", []):
			if o.has("marble") and not (o["marble"] in lvl["bag"]):
				print("     %-52s FAIL demands %s, not in bag" % [tag, o["marble"]]); _fail += 1

	print("     %d levels checked" % Levels.count())

	print("")
	print("  unlock chain reaches every marble")
	var fresh := Progression.new()
	fresh.wipe()
	for i in Levels.count():
		var lvl: Dictionary = Levels.ALL[i]
		# Can the level be played with what is owned plus what it lends?
		var allowed := Levels.allowed_marbles(lvl, fresh)
		for id in lvl["bag"]:
			if not (id in allowed):
				print("     L%02d bag contains %s which is not available yet" % [i + 1, id])
				_fail += 1
		var reward: Dictionary = lvl.get("reward", {})
		if reward.has("unlock"):
			fresh.unlock_marble(reward["unlock"])
	for id in MarbleData.DEFS:
		if id == "target":
			continue
		if not fresh.has_marble(id):
			print("     %s is never unlocked by the campaign" % id)
			_fail += 1
	_check("all six owned after chapter 1", fresh.unlocked.size(), 6)

	print("")
	if _fail == 0:
		print("  PASS — progression, objectives and level data are consistent.")
	else:
		print("  FAIL — %d problem(s)." % _fail)
	print("")
	Progression.new().wipe()
