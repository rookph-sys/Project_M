class_name Bosses
extends RefCounted

## Boss tables break one rule each (SPEC-ROGUELIKE §7).
##
## The point of a boss is that the build you brought stops working for one
## table, so a run cannot be a single plan executed eight times. Each one
## invalidates a different habit: The Blind takes away the aim guide, The
## Slick takes away stopping where you meant to, The Duelist takes away having
## the table to yourself.

const ALL := {
	"the_void": {
		"name": "The Void",
		"desc": "The ring is 25% wider.",
		"ring_scale": 1.25,
	},
	"the_anchor": {
		"name": "The Anchor",
		"desc": "Red marbles weigh double.",
		"target_mass_scale": 2.0,
	},
	"the_slick": {
		"name": "The Slick",
		"desc": "The table is frictionless. Nothing stops where you meant it to.",
		"friction_scale": 0.15,
	},
	"the_blind": {
		"name": "The Blind",
		"desc": "No aim guide.",
		"no_aim_guide": true,
	},
	"the_miser": {
		"name": "The Miser",
		"desc": "This table pays nothing.",
		"no_payout": true,
	},
	"the_duelist": {
		"name": "The Duelist",
		"desc": "An opponent contests the same reds.",
		"ai_level": 1,          # MarbleAI.Level.NORMAL
	},
	"the_tithe": {
		"name": "The Tithe",
		"desc": "Every shot costs $1.",
		"shot_cost": 1,
	},
	"the_cage": {
		"name": "The Cage",
		"desc": "Two fewer shots.",
		"shots_delta": -2,
	},
}


static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})
