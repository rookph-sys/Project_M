class_name ShotSim
extends RefCounted

## Fast 2D disc simulator used to predict shot outcomes (SPEC §19).
##
## Godot has no equivalent of Unity's Physics.Simulate(scene): the tick rate is
## global and a second World3D cannot be stepped independently. So the AI gets
## its own simulator instead of a second physics world.
##
## That is cheaper than it sounds. The arena is flat, every marble is the same
## radius, and gravity does nothing to planar motion — so the third dimension
## contributes nothing a prediction needs. This runs a few thousand times
## faster than the real engine and is exactly repeatable.
##
## What it deliberately does NOT model: spin transfer between marbles, and
## sliding-to-rolling transitions. Those are the main source of prediction
## error; tools/sim_check.gd measures whether the error stays inside the 0.05 m
## budget from §20.

const DT := 1.0 / 120.0
const FLOOR_SPEED := 0.25        # mirrors Marble.FLOOR_SPEED
const FLOOR_DECEL := 0.80
const SETTLE_SPEED := 0.035
const MAX_STEPS := 720           # 6 s; a straggler past that is retired anyway

enum Owner { PLAYER = 0, AI = 1, TARGET = 2 }

# Parallel arrays rather than objects: this is the hot loop, and the AI runs it
# dozens of times per turn.
var px := PackedFloat64Array()
var py := PackedFloat64Array()
var vx := PackedFloat64Array()
var vy := PackedFloat64Array()
var mass := PackedFloat64Array()
var damp := PackedFloat64Array()
var rest := PackedFloat64Array()
var owner := PackedInt32Array()
var alive := PackedInt32Array()

var radius := 0.10
var half_w := 3.60
var half_d := 2.40
var out_margin := 0.08
var ring_radius := 0.0           # 0 disables ring-out scoring
var ring_out_dist := 0.0
var hole_capture := 0.16
var holes := PackedVector2Array()
var bumpers := PackedVector3Array()   # x, z, radius

## Fraction of a collision impulse that survives the struck marble spinning
## up. A sphere that starts sliding keeps 5/7 of its speed once it rolls, and
## the real engine pays that cost on every contact while an ideal 2D elastic
## collision does not. Without this the sim is optimistic and predicts
## knock-outs that do not happen.
##
## Theory says 5/7 = 0.714; fitting against live physics says ~0.55, the extra
## loss coming from contact friction and off-centre hits. Agreement plateaus
## from 0.55 downwards, so the exact value below that barely matters.
var spin_transfer := 0.55

var _n := 0


func clear() -> void:
	px.clear(); py.clear(); vx.clear(); vy.clear()
	mass.clear(); damp.clear(); rest.clear()
	owner.clear(); alive.clear()
	_n = 0


func add_disc(pos: Vector2, m: float, d: float, e: float, own: int) -> int:
	px.append(pos.x); py.append(pos.y)
	vx.append(0.0); vy.append(0.0)
	mass.append(m); damp.append(d); rest.append(e)
	owner.append(own); alive.append(1)
	_n += 1
	return _n - 1


## Planar damping that reproduces a marble's measured travel distance.
##
## The naive v0/lin_damp is wrong twice over: angular damping also bleeds
## linear speed through the rolling constraint, and the velocity floor removes
## a fixed tail. Rather than model either, solve the coefficient straight from
## the distance the marble is contracted to travel (§24) — which is the number
## that was measured against the real engine in the first place.
## Fitted against live Jolt physics by tools/sim_check.gd. Prefer this over
## the derived value: the real marble keeps more speed mid-roll than a pure
## exponential, because friction needs time to spin it up.
static func sim_damping(def: Dictionary) -> float:
	return def.get("sim_damp", damping_for(def))


static func damping_for(def: Dictionary) -> float:
	var v0: float = (MarbleData.BASE_SHOT_IMPULSE * def["shot_mult"]) / def["mass"]
	var tail: float = (FLOOR_SPEED * FLOOR_SPEED) / (2.0 * FLOOR_DECEL)
	var target: float = maxf(def["target_dist"] - tail, 0.10)
	return (v0 - FLOOR_SPEED) / target


func launch(idx: int, dir: Vector2, power: float, def: Dictionary) -> void:
	var p: float = maxf(power, MarbleData.MIN_POWER)
	var speed: float = (MarbleData.BASE_SHOT_IMPULSE * p * def["shot_mult"]) / def["mass"]
	var d := dir.normalized()
	vx[idx] = d.x * speed
	vy[idx] = d.y * speed


## Runs to rest. Returns what the shot achieved, per owner.
func run() -> Dictionary:
	var ring_out := [0, 0, 0]
	var arena_out := [0, 0, 0]
	var sunk := [0, 0, 0]
	var contacts := {}
	var steps := 0

	while steps < MAX_STEPS:
		steps += 1
		if not _step(contacts):
			break
		_resolve_boundaries(ring_out, arena_out, sunk)

	return {
		"ring_out": ring_out,
		"arena_out": arena_out,
		"sunk": sunk,
		"contacts": contacts,
		"steps": steps,
	}


## One tick. Returns false once everything has come to rest.
func _step(contacts: Dictionary) -> bool:
	var moving := false

	for i in _n:
		if alive[i] == 0:
			continue
		var sx := vx[i]
		var sy := vy[i]
		var sp := sqrt(sx * sx + sy * sy)
		if sp <= SETTLE_SPEED:
			vx[i] = 0.0
			vy[i] = 0.0
			continue
		moving = true

		if sp < FLOOR_SPEED:
			var drop := FLOOR_DECEL * DT
			if drop >= sp:
				vx[i] = 0.0; vy[i] = 0.0
				continue
			var k := (sp - drop) / sp
			sx *= k; sy *= k
		else:
			var k: float = maxf(0.0, 1.0 - damp[i] * DT)
			sx *= k; sy *= k

		vx[i] = sx
		vy[i] = sy
		px[i] += sx * DT
		py[i] += sy * DT

	if not moving:
		return false

	_collide_discs(contacts)
	_collide_bumpers()
	return true


func _collide_discs(contacts: Dictionary) -> void:
	var min_d := radius * 2.0
	var min_d2 := min_d * min_d
	for i in _n:
		if alive[i] == 0:
			continue
		for j in range(i + 1, _n):
			if alive[j] == 0:
				continue
			var dx := px[j] - px[i]
			var dy := py[j] - py[i]
			var d2 := dx * dx + dy * dy
			if d2 >= min_d2 or d2 < 1e-12:
				continue

			var dist := sqrt(d2)
			var nx := dx / dist
			var ny := dy / dist

			# Push apart so they do not stay interpenetrating.
			var overlap := (min_d - dist) * 0.5
			px[i] -= nx * overlap; py[i] -= ny * overlap
			px[j] += nx * overlap; py[j] += ny * overlap

			var rvx := vx[j] - vx[i]
			var rvy := vy[j] - vy[i]
			var vn := rvx * nx + rvy * ny
			if vn > 0.0:
				continue   # already separating

			var e: float = minf(rest[i], rest[j])
			var inv_i := 1.0 / mass[i]
			var inv_j := 1.0 / mass[j]
			var jm := -(1.0 + e) * vn / (inv_i + inv_j) * spin_transfer

			vx[i] -= jm * nx * inv_i
			vy[i] -= jm * ny * inv_i
			vx[j] += jm * nx * inv_j
			vy[j] += jm * ny * inv_j

			contacts[i * 1000 + j] = true


func _collide_bumpers() -> void:
	for b in bumpers:
		var br: float = b.z + radius
		var br2 := br * br
		for i in _n:
			if alive[i] == 0:
				continue
			var dx := px[i] - b.x
			var dy := py[i] - b.y
			var d2 := dx * dx + dy * dy
			if d2 >= br2 or d2 < 1e-12:
				continue
			var dist := sqrt(d2)
			var nx := dx / dist
			var ny := dy / dist
			px[i] = b.x + nx * br
			py[i] = b.y + ny * br
			var vn := vx[i] * nx + vy[i] * ny
			if vn < 0.0:
				var e: float = rest[i]
				vx[i] -= (1.0 + e) * vn * nx
				vy[i] -= (1.0 + e) * vn * ny


func _resolve_boundaries(ring_out: Array, arena_out: Array, sunk: Array) -> void:
	for i in _n:
		if alive[i] == 0:
			continue
		var x := px[i]
		var y := py[i]

		if absf(x) > half_w + out_margin or absf(y) > half_d + out_margin:
			alive[i] = 0
			arena_out[owner[i]] += 1
			continue

		for h in holes:
			if Vector2(x - h.x, y - h.y).length() < hole_capture:
				alive[i] = 0
				sunk[owner[i]] += 1
				break
		if alive[i] == 0:
			continue

		if ring_out_dist > 0.0 and owner[i] == Owner.TARGET:
			if sqrt(x * x + y * y) >= ring_out_dist:
				alive[i] = 0
				ring_out[owner[i]] += 1


func position_of(idx: int) -> Vector2:
	return Vector2(px[idx], py[idx])


func is_alive(idx: int) -> bool:
	return alive[idx] == 1


func count() -> int:
	return _n


## Distance from the nearest table edge — the §47 tie-break metric, and a
## useful danger signal for the AI.
func edge_safety(idx: int) -> float:
	return minf(half_w - absf(px[idx]), half_d - absf(py[idx]))
