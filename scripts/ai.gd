class_name MarbleAI
extends RefCounted

## PvE opponent (SPEC §60-62).
##
## Generates candidate shots, simulates each one with ShotSim, scores the
## outcome, takes the best, then deliberately degrades it by the difficulty's
## aim and power error. It never sees anything the player cannot see and never
## bends the rules — the only thing difficulty changes is how hard it looks
## and how straight it shoots.

enum Level { EASY, NORMAL, HARD }

const PROFILES := {
	Level.EASY:   {"candidates": 24,  "aim_error": 4.0, "power_error": 0.08, "name": "Easy"},
	Level.NORMAL: {"candidates": 64,  "aim_error": 1.5, "power_error": 0.03, "name": "Normal"},
	Level.HARD:   {"candidates": 160, "aim_error": 0.8, "power_error": 0.01, "name": "Hard"},
}

# §61 — a hard ceiling on thinking. Whatever has been found by then is played.
const THINK_BUDGET_MS := 1500

# §62 utility weights. These rank the AI's own options and have nothing to do
# with the player's score.
const W_ENEMY_OUT := 1000.0
const W_SELF_OUT := -1200.0
const W_ENEMY_TOWARD_EDGE := 100.0
const W_SELF_TOWARD_EDGE := -100.0
const W_CENTRE_SAFETY := 40.0
const W_MULTI_CONTACT := 30.0

var level: Level = Level.NORMAL
var rng := RandomNumberGenerator.new()
var last_think_ms := 0
var last_considered := 0


func _init(difficulty: Level = Level.NORMAL, seed_value: int = 0) -> void:
	level = difficulty
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func profile() -> Dictionary:
	return PROFILES[level]


## Picks a shot for `actor` from the current board.
##
## `board` is what the caller can see: live marbles with position, owner and
## marble id; the arena; and the launch strip this actor may place in.
## Returns {slot, place, dir, power} or {} if nothing is playable.
func choose_shot(board: Dictionary, actor: int) -> Dictionary:
	var start := Time.get_ticks_msec()
	last_considered = 0

	var reserve: Array = board["reserve"]        # [{slot, id}]
	if reserve.is_empty():
		return {}

	var budget: int = profile()["candidates"]
	var plan := _allocate(budget, reserve.size())

	var best := {}
	var best_score := -INF

	for marble in _pick_marbles(reserve, plan["marbles"]):
		for place in _placements(board, plan["places"]):
			for dir in _directions(board, place, plan["angles"]):
				for power in _powers(plan["powers"]):
					if Time.get_ticks_msec() - start > THINK_BUDGET_MS:
						last_think_ms = Time.get_ticks_msec() - start
						return best
					last_considered += 1
					var score := _evaluate(board, actor, marble, place, dir, power)
					if score > best_score:
						best_score = score
						best = {"slot": marble["slot"], "place": place,
								"dir": dir, "power": power}

	last_think_ms = Time.get_ticks_msec() - start
	if best.is_empty():
		return {}
	return _apply_difficulty_error(best)


## Splits the candidate budget across the four choices a shot is made of.
func _allocate(budget: int, reserve_count: int) -> Dictionary:
	var marbles: int = clampi(int(round(sqrt(budget) / 2.0)), 1, mini(3, reserve_count))
	var powers := 2 if budget < 100 else 3
	var rest: int = maxi(budget / (marbles * powers), 4)
	var places: int = clampi(int(round(sqrt(float(rest)))), 1, 5)
	var angles: int = maxi(rest / maxi(places, 1), 2)
	return {"marbles": marbles, "places": places, "angles": angles, "powers": powers}


func _pick_marbles(reserve: Array, count: int) -> Array:
	# Cheap heuristic ordering so a small budget still spends itself on the
	# marbles most likely to matter: heavy hits hardest, standard is reliable.
	var ranked := reserve.duplicate()
	ranked.sort_custom(func(a, b):
		return _marble_priority(a["id"]) > _marble_priority(b["id"]))
	return ranked.slice(0, count)


func _marble_priority(id: String) -> float:
	var d: Dictionary = MarbleData.get_def(id)
	# Momentum at full power — what actually shifts another marble.
	return MarbleData.BASE_SHOT_IMPULSE * d["shot_mult"]


func _placements(board: Dictionary, count: int) -> Array[Vector2]:
	var zone: Rect2 = board["launch_zone"]
	var out: Array[Vector2] = []
	var z: float = zone.position.y + zone.size.y * 0.5
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		out.append(Vector2(zone.position.x + zone.size.x * t, z))
	return out


## Fan of directions around the line to each interesting target, rather than a
## blind sweep of the whole circle — most of a 360° sweep is wasted on empty
## table.
func _directions(board: Dictionary, from: Vector2, count: int) -> Array[Vector2]:
	var targets: Array = board["aim_points"]
	var out: Array[Vector2] = []
	if targets.is_empty():
		for i in count:
			var a: float = TAU * float(i) / float(count)
			out.append(Vector2(cos(a), sin(a)))
		return out

	var per: int = maxi(1, count / targets.size())
	var spread := deg_to_rad(7.0)
	for t in targets:
		var base: Vector2 = (t - from).normalized()
		for i in per:
			var off: float = 0.0 if per == 1 else lerpf(-spread, spread, float(i) / float(per - 1))
			out.append(base.rotated(off))
	# One fan per target can overshoot the allocation when many marbles are on
	# the table; the budget in SPEC §60 is a total, not a per-target count.
	return out.slice(0, maxi(count, 1))


func _powers(count: int) -> Array[float]:
	if count <= 2:
		return [0.65, 0.95]
	return [0.50, 0.75, 1.00]


## Runs one candidate through the simulator and turns the result into utility.
func _evaluate(board: Dictionary, actor: int, marble: Dictionary,
		place: Vector2, dir: Vector2, power: float) -> float:
	var sim: ShotSim = _build_sim(board)
	var def: Dictionary = MarbleData.get_def(marble["id"])
	var shooter := sim.add_disc(place, def["mass"], ShotSim.sim_damping(def),
		def["bounce"], actor)
	sim.launch(shooter, dir, power, def)

	var before := _edge_profile(sim)
	var result: Dictionary = sim.run()
	var after := _edge_profile(sim)

	var enemy: int = 1 - actor
	var score := 0.0
	score += result["arena_out"][enemy] * W_ENEMY_OUT
	score += result["arena_out"][actor] * W_SELF_OUT
	score += result["ring_out"][ShotSim.Owner.TARGET] * W_ENEMY_OUT
	score += result["sunk"][ShotSim.Owner.TARGET] * W_ENEMY_OUT
	score += result["sunk"][actor] * W_SELF_OUT

	# Progress even when nothing left the table: did enemies get pushed toward
	# an edge, and did our own marbles stay away from one?
	for own in [actor, enemy]:
		var delta: float = before.get(own, 0.0) - after.get(own, 0.0)
		if own == enemy:
			score += delta * W_ENEMY_TOWARD_EDGE
		else:
			score -= delta * W_SELF_TOWARD_EDGE

	if sim.is_alive(shooter):
		score += sim.edge_safety(shooter) * W_CENTRE_SAFETY
	var touched: int = result["contacts"].size()
	if touched >= 2:
		score += (touched - 1) * W_MULTI_CONTACT

	return score


## Total edge safety per owner — how exposed each side currently is.
func _edge_profile(sim: ShotSim) -> Dictionary:
	var out := {}
	for i in sim.count():
		if not sim.is_alive(i):
			continue
		var o: int = sim.owner[i]
		out[o] = out.get(o, 0.0) + sim.edge_safety(i)
	return out


func _build_sim(board: Dictionary) -> ShotSim:
	var sim := ShotSim.new()
	sim.half_w = board["half_w"]
	sim.half_d = board["half_d"]
	sim.ring_out_dist = board.get("ring_out_dist", 0.0)
	sim.holes = board.get("holes", PackedVector2Array())
	sim.bumpers = board.get("bumpers", PackedVector3Array())
	for m in board["marbles"]:
		var d: Dictionary = MarbleData.get_def(m["id"])
		sim.add_disc(m["pos"], d["mass"], ShotSim.sim_damping(d), d["bounce"], m["owner"])
	return sim


## §60 — the chosen shot is then made worse on purpose. This is the only thing
## that separates the difficulties; the rules are identical.
func _apply_difficulty_error(shot: Dictionary) -> Dictionary:
	var p: Dictionary = profile()
	var angle := deg_to_rad(rng.randfn(0.0, p["aim_error"] / 2.0))
	var power_scale := 1.0 + rng.randfn(0.0, p["power_error"] / 2.0)
	shot["dir"] = (shot["dir"] as Vector2).rotated(angle)
	shot["power"] = clampf(shot["power"] * power_scale, MarbleData.MIN_POWER, 1.0)
	return shot
