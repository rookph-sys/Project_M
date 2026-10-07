class_name Levels
extends RefCounted

## Chapter 1 — the ten-level vertical slice (SPEC §64).
##
## Positions are Vector2(X, Z) in arena space (§65). Objectives are data, not
## code (§59): `primary` and `additional` must both pass to clear, `secondary`
## is optional and worth a medal each.
##
## `loaned` lends a marble the player has not unlocked yet, for a Trial (§58).
## `available` restricts what the deck builder may draw from; empty means
## everything the player owns.

const ALL := [
{
	"name": "First Flick",
	"mode": "ringer",
	"bag": ["standard", "standard", "standard", "standard",
			"standard", "standard", "standard", "standard"],
	"available": ["standard"],
	# Four marbles against your eight. The opponent is present from the first
	# level, but a tutorial you lose is not a tutorial.
	"ai_bag": ["standard", "standard", "standard", "standard"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(-0.22, 0.00), Vector2(0.22, 0.00),
				Vector2(0.00, 0.22), Vector2(0.00, -0.22)],
	"holes": [], "bumpers": [],
	"shots": 8,
	"primary": [{"type": "win_match"}],
	"secondary": [{"type": "within_shots", "count": 6}],
	"reward": {"deck_builder": true},
	"hint": "Click the blue strip to place, drag back, release. Beat the AI to the reds.",
},
{
	"name": "Break the Cluster",
	"mode": "ringer",
	"bag": ["standard", "standard", "standard", "standard",
			"standard", "standard", "standard", "standard"],
	"available": ["standard"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "standard"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(-0.32, 0.00), Vector2(0.32, 0.00),
				Vector2(-0.16, 0.28), Vector2(0.16, 0.28),
				Vector2(-0.16, -0.28), Vector2(0.16, -0.28)],
	"holes": [], "bumpers": [],
	"shots": 8,
	"primary": [{"type": "win_match"}],
	"secondary": [{"type": "multi_hit", "count": 1}],
	"hint": "Six reds and an opponent. Hit the cluster off-centre to spread it.",
},
{
	"name": "Precision Trial",
	"mode": "ringer",
	"bag": ["precision", "standard", "standard", "standard",
			"standard", "standard", "standard", "standard"],
	"loaned": ["precision"],
	"available": ["standard", "precision"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "standard", "standard"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(-0.40, 0.10), Vector2(-0.15, 0.10),
				Vector2(0.10, 0.10), Vector2(0.35, 0.10),
				Vector2(0.00, 0.40)],
	"holes": [], "bumpers": [],
	"shots": 7,
	"primary": [{"type": "win_match"}],
	"additional": [{"type": "marble_hits_target", "marble": "precision", "count": 1}],
	"secondary": [{"type": "within_shots", "count": 5}],
	"reward": {"unlock": "precision"},
	"hint": "PINPOINT sends the marble it touches exactly where you aimed.",
},
{
	"name": "First Hole",
	"mode": "holes",
	"bag": ["standard", "standard", "standard", "standard",
			"standard", "standard", "precision", "precision"],
	"available": ["standard", "precision"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "standard", "precision", "standard"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(-0.65, 0.20), Vector2(0.65, 0.20), Vector2(0.00, -0.45)],
	"holes": [Vector2(0.00, 0.70)],
	"bumpers": [],
	"shots": 8,
	"primary": [{"type": "win_match"}],
	"secondary": [{"type": "no_marble_lost"}],
	"hint": "Race the AI to the hole. Your own marble down it costs you 250.",
},
{
	"name": "Heavy Trial",
	"mode": "ringer",
	"bag": ["heavy", "standard", "standard", "standard",
			"standard", "standard", "standard", "standard"],
	"loaned": ["heavy"],
	"available": ["standard", "precision", "heavy"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "standard", "precision", "standard"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(0.00, 0.00),
				Vector2(0.27, 0.00), Vector2(-0.27, 0.00),
				Vector2(0.14, 0.23), Vector2(-0.14, 0.23),
				Vector2(0.14, -0.23), Vector2(-0.14, -0.23)],
	"holes": [], "bumpers": [],
	"shots": 7,
	"primary": [{"type": "win_match"}],
	"additional": [{"type": "marble_rings_out", "marble": "heavy", "count": 1}],
	"secondary": [{"type": "within_shots", "count": 5}],
	"reward": {"unlock": "heavy"},
	"hint": "BREAKER adds a huge shove to Heavy's first contact.",
},
{
	"name": "Around the Wall",
	"mode": "ringer",
	"bag": ["rubber", "standard", "standard", "standard",
			"standard", "standard", "precision", "heavy"],
	"loaned": ["rubber"],
	"available": ["standard", "precision", "heavy", "rubber"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "precision", "heavy", "standard"],
	"ai_level": MarbleAI.Level.NORMAL,
	"targets": [Vector2(-0.50, 0.55), Vector2(0.00, 0.60),
				Vector2(0.50, 0.55), Vector2(0.00, 0.90)],
	"holes": [],
	"bumpers": [Vector2(-0.62, -0.10), Vector2(0.62, -0.10)],
	"shots": 7,
	"primary": [{"type": "win_match"}],
	"additional": [{"type": "marble_bank_shot", "marble": "rubber", "count": 1}],
	"secondary": [{"type": "multi_hit", "count": 1}],
	"reward": {"unlock": "rubber"},
	"hint": "Bank Rubber off a bumper first. RICOCHET keeps it going afterwards.",
},
{
	"name": "Magnetic Pull",
	"mode": "holes",
	"bag": ["magnet", "standard", "standard", "standard",
			"standard", "precision", "heavy", "rubber"],
	"loaned": ["magnet"],
	"available": ["standard", "precision", "heavy", "rubber", "magnet"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "precision", "heavy", "rubber", "standard"],
	"ai_level": MarbleAI.Level.NORMAL,
	"targets": [Vector2(-0.42, 0.35), Vector2(0.42, 0.35),
				Vector2(0.00, 0.78), Vector2(0.00, -0.10)],
	"holes": [Vector2(0.00, 0.35)],
	"bumpers": [],
	"shots": 7,
	"primary": [{"type": "win_match"}],
	"additional": [{"type": "magnet_affects", "count": 2}],
	"secondary": [{"type": "no_marble_lost"}],
	"reward": {"unlock": "magnet"},
	"hint": "PULSE drags everything nearby when Magnet stops. Park it past the hole.",
},
{
	"name": "First Duel",
	"mode": "ringer",
	"bag": ["standard", "standard", "standard", "precision",
			"heavy", "rubber", "magnet", "standard"],
	"available": ["standard", "precision", "heavy", "rubber", "magnet"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "standard", "standard", "standard"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(0.00, 0.00),
				Vector2(0.27, 0.00), Vector2(-0.27, 0.00),
				Vector2(0.14, 0.23), Vector2(-0.14, 0.23),
				Vector2(0.14, -0.23), Vector2(-0.14, -0.23)],
	"holes": [], "bumpers": [],
	"shots": 8,
	"primary": [{"type": "win_match"}],
	"secondary": [{"type": "knock_out", "count": 2}],
	"reward": {"unlock_trial": "sticky"},
	"hint": "Race the AI for the reds. Knocking its marble off the table also scores.",
},
{
	"name": "Hold Your Ground",
	"mode": "ringer",
	"bag": ["sticky", "standard", "standard", "precision",
			"heavy", "rubber", "magnet", "standard"],
	"loaned": ["sticky"],
	"available": ["standard", "precision", "heavy", "rubber", "magnet", "sticky"],
	"ai_bag": ["standard", "standard", "standard", "standard",
			   "standard", "standard", "heavy", "precision"],
	"ai_level": MarbleAI.Level.EASY,
	"targets": [Vector2(0.00, 0.00),
				Vector2(0.26, 0.10), Vector2(-0.26, 0.10),
				Vector2(0.13, 0.32), Vector2(-0.13, 0.32),
				Vector2(0.13, -0.26), Vector2(-0.13, -0.26)],
	"holes": [], "bumpers": [],
	"shots": 8,
	"primary": [{"type": "win_match"}],
	"additional": [{"type": "marble_survives", "marble": "sticky"}],
	"secondary": [{"type": "knock_out", "count": 2}],
	"reward": {"unlock": "sticky"},
	"hint": "ANCHOR bolts Sticky down where it stops. Wall off the ring with it.",
},
{
	"name": "Final Table",
	"mode": "ringer",
	"bag": ["standard", "standard", "heavy", "heavy",
			"rubber", "precision", "sticky", "magnet"],
	"available": [],
	"ai_bag": ["standard", "standard", "standard", "heavy",
			   "rubber", "precision", "sticky", "magnet"],
	"ai_level": MarbleAI.Level.NORMAL,
	"targets": [Vector2(0.00, 0.00),
				Vector2(0.26, 0.10), Vector2(-0.26, 0.10),
				Vector2(0.13, 0.32), Vector2(-0.13, 0.32),
				Vector2(0.13, -0.26), Vector2(-0.13, -0.26),
				Vector2(0.00, 0.58)],
	"holes": [],
	"bumpers": [Vector2(-0.85, 0.00), Vector2(0.85, 0.00)],
	"shots": 8,
	"primary": [{"type": "win_match"}],
	"secondary": [{"type": "bank_shot", "count": 1},
				  {"type": "max_marbles_lost", "count": 3}],
	"reward": {"chapter_complete": 1},
	"hint": "Everything you have, against the Normal AI. Chapter 1 finale.",
},
]


static func count() -> int:
	return ALL.size()


## What the deck builder may offer: the level's allow-list, intersected with
## what the player owns, plus anything the level is lending them.
static func allowed_marbles(level: Dictionary, prog: Progression) -> Array[String]:
	var out: Array[String] = []
	var allow: Array = level.get("available", [])
	var loaned: Array = level.get("loaned", [])
	for id in MarbleData.DEFS:
		if id == "target":
			continue
		if not allow.is_empty() and not (id in allow):
			continue
		if prog.has_marble(id) or id in loaned:
			out.append(id)
	return out
