class_name MarbleData
extends RefCounted

## Static marble definitions.
##
## ponytail: a const Dictionary, not six .tres Resources. The spec (§67) wants
## Resources, and it should get them once designers edit these without a
## programmer. Today nobody does, and .tres files would only add editor churn.

const RADIUS := 0.10
const BASE_SHOT_IMPULSE := 5.20
const MIN_POWER := 0.12

## Travel distance at 100% power is the contract (§24). `lin_damp` is derived
## from it by tools/calibrate.gd — do not hand-edit it without re-running that.
const DEFS := {
	"standard": {
		"name": "Standard", "color": Color(0.80, 0.84, 0.90),
		"mass": 1.00, "shot_mult": 1.00, "lin_damp": 1.129, "ang_damp": 0.45, "sim_damp": 0.9389,
		"friction": 0.40, "bounce": 0.82,
		"aim_guide": 1.40, "drag_scale": 1.00, "target_dist": 5.05,
		"ability": "", "desc": "The baseline. Nothing special, always viable.",
	},
	"heavy": {
		"name": "Heavy", "color": Color(0.28, 0.30, 0.34),
		"mass": 1.60, "shot_mult": 1.25, "lin_damp": 1.118, "ang_damp": 0.55, "sim_damp": 0.9533,
		"friction": 0.45, "bounce": 0.68,
		"aim_guide": 1.40, "drag_scale": 1.00, "target_dist": 4.00,
		"ability": "breaker", "desc": "BREAKER — its first hit blasts the target with a huge bonus shove.",
	},
	"rubber": {
		"name": "Rubber", "color": Color(0.95, 0.45, 0.25),
		"mass": 0.90, "shot_mult": 0.95, "lin_damp": 1.064, "ang_damp": 0.30, "sim_damp": 0.8542,
		"friction": 0.25, "bounce": 0.96,
		"aim_guide": 1.40, "drag_scale": 1.00, "target_dist": 5.80,
		"ability": "ricochet", "desc": "RICOCHET — regains speed off its first hit and carries on into more.",
	},
	"precision": {
		"name": "Precision", "color": Color(0.35, 0.80, 0.95),
		"mass": 0.85, "shot_mult": 0.72, "lin_damp": 1.419, "ang_damp": 0.50, "sim_damp": 1.1548,
		"friction": 0.40, "bounce": 0.80,
		"aim_guide": 2.40, "drag_scale": 1.25, "target_dist": 3.60,
		"ability": "pinpoint", "desc": "PINPOINT — sends the first marble it touches exactly where you aimed.",
	},
	"sticky": {
		"name": "Sticky", "color": Color(0.55, 0.85, 0.35),
		"mass": 1.10, "shot_mult": 0.90, "lin_damp": 1.566, "ang_damp": 1.10, "sim_damp": 1.4318,
		"friction": 0.75, "bounce": 0.22,
		"aim_guide": 1.40, "drag_scale": 1.00, "target_dist": 2.80,
		"ability": "anchor", "desc": "ANCHOR — once it stops it is bolted down. Nothing moves it again.",
	},
	"magnet": {
		"name": "Magnet", "color": Color(0.80, 0.40, 0.90),
		"mass": 1.00, "shot_mult": 0.95, "lin_damp": 1.168, "ang_damp": 0.50, "sim_damp": 0.9756,
		"friction": 0.40, "bounce": 0.80,
		"aim_guide": 1.40, "drag_scale": 1.00, "target_dist": 4.70,
		"ability": "magnet_pulse", "desc": "PULSE — on stopping, drags everything nearby hard toward it. Once.",
	},
	# Targets are not in the player's bag; they share Standard's physics.
	"target": {
		"name": "Target", "color": Color(0.90, 0.22, 0.25),
		"mass": 1.00, "shot_mult": 1.00, "lin_damp": 1.129, "ang_damp": 0.45, "sim_damp": 0.9389,
		"friction": 0.40, "bounce": 0.82,
		"aim_guide": 1.40, "drag_scale": 1.00, "target_dist": 5.05,
		"ability": "", "desc": "",
	},
}

const MAGNET_RADIUS := 1.15
const MAGNET_MAX_IMPULSE := 1.90


static func get_def(id: String) -> Dictionary:
	assert(DEFS.has(id), "unknown marble id: %s" % id)
	return DEFS[id]


## §16 — impulse magnitude for a shot.
static func impulse_for(id: String, power: float) -> float:
	return BASE_SHOT_IMPULSE * power * DEFS[id]["shot_mult"]
