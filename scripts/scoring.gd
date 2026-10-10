class_name Scoring
extends RefCounted

## Chips × Mult (SPEC-ROGUELIKE §3).
##
## The whole reason for this shape: two numbers that grow from different
## sources and get multiplied. Chips come from what you hit, mult from how you
## hit it. Either alone is linear; together they go exponential, which is what
## lets a build keep pace with a target that grows 1.75× an ante.
##
## A shot is scored once, after its chain has resolved, so every charm sees
## the complete picture of what the shot did.

const CHIPS_RING_OUT := 10
const CHIPS_SINK := 12
const CHIPS_BANK := 5
const CHIPS_LOST := -8
const MULT_BASE := 1.0
const MULT_PER_CHAIN := 1.0        # per link past the first


## `shot` is what happened:
##   ring_outs, sinks, lost, banked, marble_id, is_last_shot
## `charms` is the run's held charm ids.
## Returns {chips, mult, score, money, lines} where `lines` explains the
## result for the UI — showing the sum is most of what makes it readable.
static func score_shot(shot: Dictionary, charms: Array) -> Dictionary:
	var ring_outs: int = shot.get("ring_outs", 0)
	var sinks: int = shot.get("sinks", 0)
	var lost: int = shot.get("lost", 0)
	var banked: bool = shot.get("banked", false)
	var marble_id: String = shot.get("marble_id", "")
	var scoring_events: int = ring_outs + sinks

	var lines: Array[String] = []
	var chips := 0.0
	var mult := MULT_BASE

	if ring_outs > 0:
		var c: float = ring_outs * (CHIPS_RING_OUT
			+ Charms.total(charms, "chips_per_ringout")
			+ Charms.by_marble(charms, "chips_by_marble", marble_id))
		chips += c
		lines.append("%d ring out  +%d chips" % [ring_outs, int(c)])

	if sinks > 0:
		var c: float = sinks * (CHIPS_SINK + Charms.total(charms, "chips_per_sink"))
		chips += c
		lines.append("%d sunk  +%d chips" % [sinks, int(c)])

	if banked and scoring_events > 0:
		chips += CHIPS_BANK
		lines.append("bank  +%d chips" % CHIPS_BANK)

	if lost > 0:
		chips += lost * CHIPS_LOST
		lines.append("%d lost  %d chips" % [lost, lost * CHIPS_LOST])

	# Nothing scored means nothing is multiplied — a wasted shot is wasted.
	if scoring_events == 0:
		return {"chips": int(chips), "mult": 0.0, "score": 0, "money": 0,
				"lines": lines}

	var chain: int = maxi(scoring_events - 1, 0)
	if chain > 0:
		var m: float = chain * (MULT_PER_CHAIN + Charms.total(charms, "mult_per_chain"))
		mult += m
		lines.append("chain x%d  +%.1f mult" % [scoring_events, m])

	if banked:
		var m: float = Charms.total(charms, "mult_per_bank")
		if m > 0.0:
			mult += m
			lines.append("bank  +%.1f mult" % m)

	var by_marble: float = Charms.by_marble(charms, "mult_by_marble", marble_id)
	if by_marble > 0.0:
		mult += by_marble
		lines.append("%s  +%.1f mult" % [marble_id, by_marble])

	var flat: float = Charms.total(charms, "mult_flat")
	if flat > 0.0:
		mult += flat

	# Multiplicative conditionals land last, on top of everything above —
	# which is exactly why they are the ones worth building around.
	if lost == 0:
		var k: float = Charms.product(charms, "mult_if_clean")
		if k > 1.0:
			mult *= k
			lines.append("clean  x%.1f mult" % k)

	if shot.get("is_last_shot", false):
		var k: float = Charms.product(charms, "mult_last_shot")
		if k > 1.0:
			mult *= k
			lines.append("last call  x%.1f mult" % k)

	var money: int = ring_outs * int(Charms.total(charms, "money_per_ringout"))

	return {
		"chips": int(round(chips)),
		"mult": mult,
		"score": int(round(maxf(chips, 0.0) * mult)),
		"money": money,
		"lines": lines,
	}


## Physics scales the run's charms and the current boss impose together.
static func world_scales(charms: Array, boss: Dictionary) -> Dictionary:
	return {
		"ring": Charms.product(charms, "ring_scale") * float(boss.get("ring_scale", 1.0)),
		"target_mass": Charms.product(charms, "target_mass_scale")
			* float(boss.get("target_mass_scale", 1.0)),
		"magnet_radius": Charms.product(charms, "magnet_radius_scale"),
		"friction": float(boss.get("friction_scale", 1.0)),
	}
