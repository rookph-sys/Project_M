class_name Charms
extends RefCounted

## Persistent run modifiers — the Joker equivalent (SPEC-ROGUELIKE §6).
##
## This is where builds come from, so the rules matter more than the numbers:
## one sentence each, no new input, and they have to COMBINE rather than just
## stack. A charm that is simply "+N chips" with no interaction is filler.
##
## Fields are read by the scorer; a charm only needs the ones it uses.
##
##   chips_per_ringout / chips_per_sink   flat chips on each scoring event
##   mult_per_chain                        mult for every chain link past one
##   mult_flat                             mult added once per shot
##   mult_if_clean                         mult multiplier when nothing was lost
##   mult_last_shot                        mult multiplier on a table's last shot
##   mult_per_bank                         mult when the shot banked
##   chips_by_marble / mult_by_marble      keyed on the shooting marble's id
##   money_per_ringout, interest_cap_delta, unused_shot_bonus
##   shots_delta, charm_slots_delta
##   ring_scale, target_mass_scale, magnet_radius_scale   physics
##
## `rarity` gates when a charm can appear: 0 from the start, 1 from ante 3,
## 2 from ante 5.

const ALL := {
	"weighted_core": {
		"name": "Weighted Core", "cost": 5, "rarity": 0, "kind": "chips",
		"desc": "Every ring-out scores +6 chips.",
		"chips_per_ringout": 6,
	},
	"chain_gang": {
		"name": "Chain Gang", "cost": 6, "rarity": 0, "kind": "mult",
		"desc": "Every chain link past the first is worth +2 mult.",
		"mult_per_chain": 2,
	},
	"clean_break": {
		"name": "Clean Break", "cost": 6, "rarity": 1, "kind": "conditional",
		"desc": "Double mult on any shot that loses none of your marbles.",
		"mult_if_clean": 2.0,
	},
	"last_call": {
		"name": "Last Call", "cost": 7, "rarity": 1, "kind": "conditional",
		"desc": "Triple mult on the final shot of a table.",
		"mult_last_shot": 3.0,
	},
	"ricochet_plate": {
		"name": "Ricochet Plate", "cost": 5, "rarity": 0, "kind": "conditional",
		"desc": "A banked shot scores +4 mult.",
		"mult_per_bank": 4,
	},
	"ballast": {
		"name": "Ballast", "cost": 6, "rarity": 1, "kind": "conditional",
		"desc": "Heavy scores +15 chips when it rings one out.",
		"chips_by_marble": {"heavy": 15},
	},
	"scalpel": {
		"name": "Scalpel", "cost": 7, "rarity": 1, "kind": "conditional",
		"desc": "Precision scores +5 mult when it rings one out.",
		"mult_by_marble": {"precision": 5},
	},
	"lodestone": {
		"name": "Lodestone", "cost": 5, "rarity": 1, "kind": "physics",
		"desc": "Magnet's pulse reaches 60% further.",
		"magnet_radius_scale": 1.6,
	},
	"greased_rim": {
		"name": "Greased Rim", "cost": 6, "rarity": 2, "kind": "physics",
		"desc": "The ring is 12% smaller.",
		"ring_scale": 0.88,
	},
	"dead_weight": {
		"name": "Dead Weight", "cost": 6, "rarity": 1, "kind": "physics",
		"desc": "Red marbles are 30% lighter.",
		"target_mass_scale": 0.70,
	},
	"collector": {
		"name": "Collector", "cost": 4, "rarity": 0, "kind": "economy",
		"desc": "Earn $1 for every ring-out.",
		"money_per_ringout": 1,
	},
	"usurer": {
		"name": "Usurer", "cost": 7, "rarity": 2, "kind": "economy",
		"desc": "Interest caps at $10 instead of $5.",
		"interest_cap_delta": 5,
	},
	"patient": {
		"name": "Patient", "cost": 5, "rarity": 1, "kind": "economy",
		"desc": "Unused shots pay $2 each.",
		"unused_shot_bonus": 1,
	},
	"overdraw": {
		"name": "Overdraw", "cost": 8, "rarity": 2, "kind": "utility",
		"desc": "One extra shot on every table.",
		"shots_delta": 1,
	},
	"deep_pockets": {
		"name": "Deep Pockets", "cost": 8, "rarity": 2, "kind": "utility",
		"desc": "One extra charm slot.",
		"charm_slots_delta": 1,
	},
}


static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})


## Charms legal to offer at this ante, excluding ones already held.
static func pool_for(ante: int, held: Array) -> Array[String]:
	var tier := 0
	if ante >= 5:
		tier = 2
	elif ante >= 3:
		tier = 1
	var out: Array[String] = []
	for id in ALL:
		if ALL[id]["rarity"] <= tier and not (id in held):
			out.append(id)
	return out


## Sum a numeric field across the held charms.
static func total(held: Array, field: String) -> float:
	var n := 0.0
	for id in held:
		n += float(ALL[id].get(field, 0))
	return n


## Product of a multiplicative field (physics scales default to 1.0).
static func product(held: Array, field: String) -> float:
	var n := 1.0
	for id in held:
		n *= float(ALL[id].get(field, 1.0))
	return n


## Look up a per-marble bonus table across the held charms.
static func by_marble(held: Array, field: String, marble_id: String) -> float:
	var n := 0.0
	for id in held:
		var tbl: Dictionary = ALL[id].get(field, {})
		n += float(tbl.get(marble_id, 0))
	return n
