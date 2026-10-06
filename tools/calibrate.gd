extends SceneTree

## §73 Phase 1 acceptance test, headless.
##
##   godot --headless --script res://tools/calibrate.gd
##
## Fires each marble on an empty table and measures how far it actually
## travels. Travel distance is the contract (§24), so when a marble misses its
## target this prints the linear_damp that would fix it.
##
## Rolling couples linear and angular damping, so the naive distance = v0/damp
## is wrong — the real curve is distance = v0 / ((5/7)(lin + 0.4*ang)). That is
## why these numbers have to be measured rather than derived on paper.

const TOL := 0.10
const MAX_SECONDS := 20.0

var _floor: StaticBody3D
var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_build_floor()
	await physics_frame

	print("")
	print("  marble      power   target    actual     err    verdict")
	print("  ---------------------------------------------------------")

	# §73 Test A/B/C — the power curve must be close to linear.
	for power in [0.25, 0.50, 1.00]:
		var target: float = MarbleData.get_def("standard")["target_dist"] * power
		await _measure_and_report("standard", power, target)

	print("")
	for id in ["heavy", "rubber", "precision", "sticky", "magnet"]:
		var target: float = MarbleData.get_def(id)["target_dist"]
		await _measure_and_report(id, 1.0, target)

	print("")
	await _repeatability()

	if _failures > 0:
		print("")
		print("  solving lin_damp from measurement — paste into marble_data.gd:")
		print("")
		for id in ["standard", "heavy", "rubber", "precision", "sticky", "magnet"]:
			var solved := await _solve(id)
			print("    %-10s lin_damp %.3f" % [id, solved])

	print("")
	if _failures == 0:
		print("  PASS — every marble is inside +/-%d%%." % int(TOL * 100))
	else:
		print("  FAIL — %d measurement(s) outside tolerance." % _failures)
	print("")
	quit(0 if _failures == 0 else 1)


## Newton-iterate lin_damp until the marble lands on its travel target.
## Distance is inversely proportional to (lin + 0.4*ang), so this converges in
## two or three passes.
func _solve(id: String) -> float:
	var d: Dictionary = MarbleData.get_def(id)
	var target: float = d["target_dist"]
	var ang: float = d["ang_damp"]
	var lin: float = d["lin_damp"]
	for i in 5:
		var dist := await _shoot(id, 1.0, lin)
		if absf(dist - target) / target < 0.015:
			break
		var combined: float = lin + 0.4 * ang
		lin = combined * (dist / target) - 0.4 * ang
		lin = maxf(lin, 0.05)
	return lin


func _build_floor() -> void:
	_floor = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Long enough that nothing rolls off the end during a measurement.
	box.size = Vector3(4.0, 0.2, 40.0)
	cs.shape = box
	_floor.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.50
	pm.bounce = 0.0
	_floor.physics_material_override = pm
	_floor.position = Vector3(0, -0.10, 18.0)
	root.add_child(_floor)


func _measure_and_report(id: String, power: float, target: float) -> void:
	var dist := await _shoot(id, power)
	var err := (dist - target) / target
	var ok: bool = absf(err) <= TOL
	if not ok:
		_failures += 1

	var line := "  %-10s  %4.2f   %5.2f m   %5.2f m   %+5.1f%%   %s" % [
		id, power, target, dist, err * 100.0, "ok" if ok else "OFF"]

	if not ok:
		var d: Dictionary = MarbleData.get_def(id)
		# distance is inversely proportional to the combined damping term, so
		# one Newton step lands essentially on the target.
		var combined: float = d["lin_damp"] + 0.4 * d["ang_damp"]
		var wanted: float = combined * (dist / target)
		line += "   -> lin_damp %.3f" % (wanted - 0.4 * d["ang_damp"])
	print(line)


func _shoot(id: String, power: float, damp_override: float = -1.0) -> float:
	var m := Marble.new()
	root.add_child(m)
	m.setup(id, false)
	m.position = Vector3(0, MarbleData.RADIUS, 0)
	if damp_override > 0.0:
		m.linear_damp = damp_override
	await physics_frame
	await physics_frame

	var start := m.position
	m.launch(Vector3.FORWARD * -1.0, power)   # +Z

	var elapsed := 0.0
	var step := 1.0 / Engine.physics_ticks_per_second
	while not m.is_resting() and elapsed < MAX_SECONDS:
		await physics_frame
		elapsed += step

	var dist := Vector2(m.position.x - start.x, m.position.z - start.z).length()
	m.queue_free()
	await physics_frame
	return dist


## §73 Test D — same input, same build, same result.
func _repeatability() -> void:
	var first := 0.0
	var spread := 0.0
	for i in 12:
		var d := await _shoot("standard", 0.75)
		if i == 0:
			first = d
		else:
			spread = maxf(spread, absf(d - first))
	var ok := spread <= 0.02
	if not ok:
		_failures += 1
	print("  repeatability (12 identical shots)   spread %.4f m   %s"
		% [spread, "ok" if ok else "OFF (want <= 0.02)"])
