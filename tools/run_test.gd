extends SceneTree

## Run structure, scoring and charm interactions.
##
##   godot --headless --script res://tools/run_test.gd
##
## The question this has to answer is not "does it add up" but "is the curve
## survivable": can a plausible build keep pace with a target that grows 1.75x
## an ante? If not, the run is unwinnable and no amount of polish fixes it.

var _fail := 0


func _initialize() -> void:
	_run()
	quit(0 if _fail == 0 else 1)


func _check(label: String, got, want) -> void:
	var ok: bool = str(got) == str(want)
	if not ok:
		_fail += 1
	print("     %-50s %s" % [label, "ok" if ok else "FAIL got=%s want=%s" % [got, want]])


func _run() -> void:
	print("")
	print("  run structure")
	var r := Run.new()
	r.start(1234)
	_check("starts at ante 1, small table", "%d/%d" % [r.ante, r.table], "1/0")
	_check("starts with 8 standard", r.bag.size(), 8)
	_check("starts with $4", r.money, 4)
	_check("first target", r.target_score(), 30)

	r.table = 1
	_check("big table is 1.5x", r.target_score(), 45)
	r.table = 2
	_check("boss table is 2x", r.target_score(), 60)
	r.ante = 8
	r.table = 2
	_check("final boss target", r.target_score(), 3016)

	print("")
	print("  twenty-four tables, then the run is won")
	var r2 := Run.new()
	r2.start(99)
	var steps := 0
	while r2.phase != Run.Phase.WON and steps < 50:
		r2.clear_table(0)
		r2.begin_table()
		steps += 1
	_check("tables in a full run", steps, 24)
	_check("phase after the last", Run.Phase.keys()[r2.phase], "WON")

	print("")
	print("  scoring: chips x mult")
	var bare := Scoring.score_shot({"ring_outs": 1, "marble_id": "standard"}, [])
	_check("one ring out, no charms", "%d x %.1f = %d"
		% [bare["chips"], bare["mult"], bare["score"]], "10 x 1.0 = 10")

	var chain := Scoring.score_shot({"ring_outs": 3, "marble_id": "standard"}, [])
	_check("three in a chain", "%d x %.1f = %d"
		% [chain["chips"], chain["mult"], chain["score"]], "30 x 3.0 = 90")

	var miss := Scoring.score_shot({"ring_outs": 0, "lost": 1}, [])
	_check("a shot that scores nothing is worth nothing", miss["score"], 0)

	print("")
	print("  charms combine rather than just stack")
	var a := Scoring.score_shot({"ring_outs": 3, "marble_id": "standard"},
		["weighted_core"])
	_check("Weighted Core alone", a["score"], 144)          # (30+18) x 3
	var b := Scoring.score_shot({"ring_outs": 3, "marble_id": "standard"},
		["chain_gang"])
	_check("Chain Gang alone", b["score"], 210)             # 30 x 7
	var both := Scoring.score_shot({"ring_outs": 3, "marble_id": "standard"},
		["weighted_core", "chain_gang"])
	_check("both together", both["score"], 336)             # 48 x 7
	var sum_of_parts: int = a["score"] + b["score"] - chain["score"]
	if both["score"] <= sum_of_parts:
		print("     %-50s FAIL combo is not better than the sum" % "combination beats addition")
		_fail += 1
	else:
		print("     %-50s ok  (%d vs %d additive)"
			% ["combination beats addition", both["score"], sum_of_parts])

	print("")
	print("  conditionals")
	var clean := Scoring.score_shot(
		{"ring_outs": 2, "lost": 0, "marble_id": "standard"}, ["clean_break"])
	var dirty := Scoring.score_shot(
		{"ring_outs": 2, "lost": 1, "marble_id": "standard"}, ["clean_break"])
	_check("Clean Break pays when nothing is lost", clean["score"], 80)
	if dirty["score"] >= clean["score"]:
		print("     %-50s FAIL" % "Clean Break withheld after a loss")
		_fail += 1
	else:
		print("     %-50s ok" % "Clean Break withheld after a loss")

	var last := Scoring.score_shot(
		{"ring_outs": 2, "marble_id": "standard", "is_last_shot": true}, ["last_call"])
	_check("Last Call triples the final shot", last["score"], 120)

	var scalpel := Scoring.score_shot({"ring_outs": 1, "marble_id": "precision"},
		["scalpel"])
	var scalpel_wrong := Scoring.score_shot({"ring_outs": 1, "marble_id": "standard"},
		["scalpel"])
	_check("Scalpel fires for Precision", scalpel["score"], 60)
	_check("Scalpel ignores Standard", scalpel_wrong["score"], 10)

	_hand_tests()

	print("")
	print("  is the curve survivable?")
	_curve()

	print("")
	if _fail == 0:
		print("  PASS — run structure and scoring hold together.")
	else:
		print("  FAIL — %d problem(s)." % _fail)
	print("")


## Walk the ante curve against what a reasonable build scores by then, to
## check the run is winnable at all. Numbers are deliberately conservative:
## a three-chain a shot, five shots, charms acquired at a plausible rate.
func _curve() -> void:
	var builds := {
		1: [], 2: ["weighted_core"], 3: ["weighted_core", "chain_gang"],
		4: ["weighted_core", "chain_gang", "ricochet_plate"],
		5: ["weighted_core", "chain_gang", "ricochet_plate", "clean_break"],
		6: ["weighted_core", "chain_gang", "ricochet_plate", "clean_break", "scalpel"],
		7: ["weighted_core", "chain_gang", "ricochet_plate", "clean_break", "scalpel"],
		8: ["weighted_core", "chain_gang", "ricochet_plate", "clean_break", "scalpel"],
	}
	var r := Run.new()
	r.start(7)
	print("     ante   boss target   5 shots of a 3-chain   margin")
	for ante in range(1, 9):
		r.ante = ante
		r.table = 2
		var held: Array = builds[ante]
		var per_shot: int = Scoring.score_shot(
			{"ring_outs": 3, "lost": 0, "marble_id": "precision", "banked": true},
			held)["score"]
		var reachable: int = per_shot * 5
		var target: int = r.target_score()
		var ratio: float = float(reachable) / float(target)
		var verdict := "ok" if ratio >= 1.0 else "UNREACHABLE"
		if ratio < 1.0:
			_fail += 1
		print("      %d      %7d        %10d          x%.2f  %s"
			% [ante, target, reachable, ratio, verdict])


func _hand_tests() -> void:
	print("")
	print("  the bag is a deck")
	var r := Run.new()
	r.start(4242)
	r.bag.assign(["standard", "standard", "standard", "standard",
				  "heavy", "heavy", "rubber", "precision"])
	r.begin_table()
	_check("hand is dealt", r.hand.size(), Run.HAND_SIZE)
	_check("rest is in the draw pile", r.draw_pile.size(), 8 - Run.HAND_SIZE)

	var played: String = r.play_from_hand(0)
	_check("playing draws back up", r.hand.size(), Run.HAND_SIZE)
	_check("played marble is discarded", r.discard_pile, [played])

	# Exhaust the deck; the hand should shrink rather than break.
	var guard := 0
	while not r.hand.is_empty() and guard < 40:
		r.play_from_hand(0)
		guard += 1
	_check("deck exhausts cleanly", r.hand.size(), 0)
	_check("every marble was seen once", r.discard_pile.size(), 8)

	print("")
	print("  a bigger bag is a diluted bag")
	# The whole point of drawing: adding marbles has a cost. With one Heavy in
	# eight you see it often; one in twelve, much less.
	var small := _heavy_rate(8, 1, 3001)
	var large := _heavy_rate(12, 1, 3001)
	print("     1 Heavy in  8   seen in %.0f%% of opening hands" % (small * 100.0))
	print("     1 Heavy in 12   seen in %.0f%% of opening hands" % (large * 100.0))
	if large >= small:
		print("     %-50s FAIL" % "dilution actually reduces draw odds")
		_fail += 1
	else:
		print("     %-50s ok" % "dilution actually reduces draw odds")


## Fraction of opening hands containing at least one Heavy.
func _heavy_rate(bag_size: int, heavies: int, trials: int) -> float:
	var hits := 0
	for t in trials:
		var r := Run.new()
		r.start(t + 1)
		r.bag.clear()
		for i in heavies:
			r.bag.append("heavy")
		while r.bag.size() < bag_size:
			r.bag.append("standard")
		r.deal_table()
		if "heavy" in r.hand:
			hits += 1
	return float(hits) / float(trials)
