class_name Run
extends RefCounted

## A single roguelike run (SPEC-ROGUELIKE §2-5).
##
## Eight antes, three tables each, escalating score targets. Fail a table and
## the run is over — that is the whole structure. Everything the player
## accumulates (bag, charms, money) lives here and dies with the run.

const ANTES := 8
const TABLES_PER_ANTE := 3

# Ante 1 should be close to free: two plain ring-outs, or one small chain.
# At 60 a weak opening hand simply could not reach it in five shots.
const BASE_TARGET := 30.0
const GROWTH := 1.75
const TABLE_MULT := [1.0, 1.5, 2.0]        # Small, Big, Boss
const TABLE_NAME := ["Small Table", "Big Table", "Boss Table"]
const TABLE_PAYOUT := [4, 5, 7]

const SHOTS_PER_TABLE := 5
const BAG_LIMIT := 12
const CHARM_SLOTS := 5

enum Phase { TABLE, SHOP, WON, LOST }

var ante := 1
var table := 0                   # 0 Small, 1 Big, 2 Boss
var phase: Phase = Phase.TABLE
var money := 4
var bag: Array[String] = []
var charms: Array[String] = []
var boss := ""                   # id of this ante's boss, chosen at ante start
var seed_value := 0

var rng := RandomNumberGenerator.new()


func start(run_seed: int = 0) -> void:
	seed_value = run_seed if run_seed != 0 else randi()
	rng.seed = seed_value
	ante = 1
	table = 0
	phase = Phase.TABLE
	money = 4
	charms.clear()
	bag.clear()
	for i in 8:
		bag.append("standard")
	_roll_boss()


func _roll_boss() -> void:
	var ids: Array = Bosses.ALL.keys()
	boss = ids[rng.randi() % ids.size()]


## §4 — the curve that forces a build rather than just good aim.
func target_score() -> int:
	return int(round(BASE_TARGET * pow(GROWTH, ante - 1) * TABLE_MULT[table]))


func table_name() -> String:
	return TABLE_NAME[table]


func is_boss() -> bool:
	return table == 2


func boss_def() -> Dictionary:
	return Bosses.ALL.get(boss, {}) if is_boss() else {}


func shots_for_table() -> int:
	var n := SHOTS_PER_TABLE
	if is_boss():
		n += int(boss_def().get("shots_delta", 0))
	for c in charms:
		n += int(Charms.ALL[c].get("shots_delta", 0))
	return maxi(n, 1)


func charm_slots() -> int:
	var n := CHARM_SLOTS
	for c in charms:
		n += int(Charms.ALL[c].get("charm_slots_delta", 0))
	return n


func has_charm(id: String) -> bool:
	return id in charms


func add_charm(id: String) -> bool:
	if charms.size() >= charm_slots() or has_charm(id):
		return false
	charms.append(id)
	return true


func add_marble(id: String) -> bool:
	if bag.size() >= BAG_LIMIT:
		return false
	bag.append(id)
	return true


# ------------------------------------------------------------ progress ----

## Table cleared. Pays out and advances; returns a summary for the UI.
func clear_table(shots_left: int) -> Dictionary:
	var payout: int = TABLE_PAYOUT[table]
	if is_boss() and boss_def().get("no_payout", false):
		payout = 0

	var per_shot := 1
	for c in charms:
		per_shot += int(Charms.ALL[c].get("unused_shot_bonus", 0))
	var unused: int = shots_left * per_shot if payout > 0 else 0

	var cap := 5
	for c in charms:
		cap += int(Charms.ALL[c].get("interest_cap_delta", 0))
	var interest: int = mini(money / 5, cap) if payout > 0 else 0

	money += payout + unused + interest

	_advance()
	return {
		"payout": payout, "unused": unused, "interest": interest,
		"total": payout + unused + interest,
	}


func _advance() -> void:
	table += 1
	if table >= TABLES_PER_ANTE:
		table = 0
		ante += 1
		if ante > ANTES:
			phase = Phase.WON
			return
		_roll_boss()
	phase = Phase.SHOP


func fail() -> void:
	phase = Phase.LOST


## Guarded: a finished run must not be resurrected by a stray call.
func begin_table() -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	phase = Phase.TABLE
	deal_table()


## 1 to 24 across a run — handy for pacing and for the UI.
func step() -> int:
	return (ante - 1) * TABLES_PER_ANTE + table + 1


# --------------------------------------------------------------- hand ----
#
# The bag is a deck, not a loadout. Each table shuffles it into a draw pile
# and deals a hand; after every shot you draw back up. You play what you are
# given.
#
# This is what makes bag composition a decision rather than a wish list.
# Adding a twelfth marble dilutes the eleven already in there, so "more" and
# "better" stop being the same thing — which is the tension a free pick from
# all eight never had.

const HAND_SIZE := 5

var hand: Array[String] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []


func deal_table() -> void:
	draw_pile = bag.duplicate()
	_shuffle(draw_pile)
	discard_pile.clear()
	hand.clear()
	for i in HAND_SIZE:
		_draw_one()


## Spend the marble in `slot` and draw a replacement.
func play_from_hand(slot: int) -> String:
	if slot < 0 or slot >= hand.size():
		return ""
	var id: String = hand[slot]
	hand.remove_at(slot)
	discard_pile.append(id)
	_draw_one()
	return id


func _draw_one() -> void:
	if draw_pile.is_empty():
		return          # deck exhausted: the hand simply shrinks
	hand.append(draw_pile.pop_back())


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## How many of `id` are in the whole bag — shown in the shop so the player can
## see what they are diluting.
func count_in_bag(id: String) -> int:
	var n := 0
	for m in bag:
		if m == id:
			n += 1
	return n
