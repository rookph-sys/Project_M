extends SceneTree

## Plays a run end to end with a scripted shooter.
##
##   godot --headless --script res://tools/roguelike_test.gd
##
## Checks the loop holds together: tables assemble, shots score as chips x
## mult, cleared tables advance and pay, a failed table ends the run.

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	game._menu.visible = false
	game.start_run(20261010)
	await process_frame

	print("")
	print("  ante table        target   scored   shots   result")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tables := 0
	var guard := 0

	# Looping on run.phase directly would exit before the result line prints,
	# because _resolve_table flips the phase the moment a table ends.
	var running := true
	while running and guard < 400:
		guard += 1
		if guard <= 3 or guard % 80 == 0:
			print("   guard %d  state=%s  shots=%d  hand=%d  score=%d  phase=%s"
				% [guard, game.St.keys()[game.state], game.shots_left,
				   game.run.hand.size(), game.table_score,
				   Run.Phase.keys()[game.run.phase]])
		if game.state == game.St.PLACE and game.shots_left > 0:
			_shoot(game, rng)
			await _settle(game)
			continue
		if game.state == game.St.WON or game.state == game.St.LOST:
			var before := "%d %-12s %7d %8d %7d" % [
				game.run.ante, game.run.table_name(), game.run.target_score(),
				game.table_score, game.shots_left]
			var cleared: bool = game.state == game.St.WON
			tables += 1
			print("   %s   %s" % [before, "cleared" if cleared else "RUN OVER"])
			if not cleared:
				running = false
				continue
			if game.run.phase == Run.Phase.WON:
				running = false
				continue
			# Skip the shop; just take the next table.
			game.run.begin_table()
			game.load_table()
			await process_frame
			continue
		if game.state == game.St.PLACE and game.shots_left <= 0:
			await process_frame
			continue
		await process_frame

	print("")
	print("  tables played %d   money $%d   charms %d"
		% [tables, game.run.money, game.run.charms.size()])

	if tables == 0:
		print("  FAIL — no table ever resolved")
		_fail += 1
	if guard >= 400:
		print("  FAIL — loop never terminated")
		_fail += 1

	print("")
	if _fail == 0:
		print("  PASS — a run plays through.")
	else:
		print("  FAIL — %d problem(s)." % _fail)
	print("")
	quit(0 if _fail == 0 else 1)


func _shoot(game, rng: RandomNumberGenerator) -> void:
	var aim := Vector2.ZERO
	for t in game.targets:
		if is_instance_valid(t) and t.state == Marble.State.RESERVE:
			aim = Vector2(t.position.x, t.position.z)
			break
	for attempt in 6:
		var from := Vector2(clampf(aim.x * 0.5 + rng.randf_range(-0.4, 0.4), -2.7, 2.7), -1.85)
		var dir := Vector3(aim.x - from.x, 0, aim.y - from.y).normalized()
		dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-2.0, 2.0)))
		if game.submit_shot(from, dir, rng.randf_range(0.7, 1.0)):
			return


func _settle(game) -> void:
	var t := 0.0
	while game.state == game.St.RESOLVE and t < 25.0:
		await process_frame
		t += 1.0 / 60.0
