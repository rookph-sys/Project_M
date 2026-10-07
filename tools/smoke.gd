extends SceneTree

## End-to-end check of the turn loop, headless.
##
##   godot --headless --script res://tools/smoke.gd
##
## Plays every level by firing straight at the cluster until it wins or runs
## out of shots. Catches what the physics test cannot: state-machine dead
## ends, scoring that never fires, objectives that can never complete, and
## resolution that never terminates.

const MAX_WAIT := 25.0

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame

	print("")
	for i in Levels.ALL.size():
		await _play(game, i)
	print("")

	if _fail == 0:
		print("  PASS — every level plays through without stalling.")
	else:
		print("  FAIL — %d problem(s)." % _fail)
	print("")
	quit(0 if _fail == 0 else 1)


func _play(game, idx: int) -> void:
	game.load_level(idx)
	await physics_frame

	var lvl: Dictionary = Levels.ALL[idx]
	if lvl["mode"] == "duel":
		return      # covered by tools/ai_test.gd, which drives both sides
	var shots := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + idx

	while game.state == game.St.PLACE and shots < lvl["shots"]:
		# A rough stand-in for a player: pick any live target, line up on it,
		# and hit it hard. Not good play — just good enough that a winnable
		# level sometimes gets won, so "0 progress" means a real bug.
		var aim := _pick_target(game, rng)
		var fired := false
		for attempt in 6:
			var from := Vector2(
				clampf(aim.x * 0.5 + rng.randf_range(-0.35, 0.35), -2.7, 2.7), -1.85)
			var dir := Vector3(aim.x - from.x, 0, aim.y - from.y).normalized()
			dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-1.5, 1.5)))
			if game.submit_shot(from, dir, rng.randf_range(0.70, 1.00)):
				fired = true
				break
		if not fired:
			print("  L%d %-18s  shot %d: no valid placement after 6 tries"
				% [idx + 1, lvl["name"], shots + 1])
			_fail += 1
			return
		shots += 1

		var waited := 0.0
		var step := 1.0 / Engine.physics_ticks_per_second
		while (game.state == game.St.RESOLVE or game.state == game.St.AI_TURN) \
				and waited < MAX_WAIT:
			await physics_frame
			waited += step

		if game.state == game.St.RESOLVE:
			print("  L%d %-18s  resolution never ended (>%.0fs)"
				% [idx + 1, lvl["name"], MAX_WAIT])
			_fail += 1
			return
		if waited > 4.0:
			print("  L%d %-18s  slow shot: %.1fs to settle" % [idx + 1, lvl["name"], waited])

	var outcome := "WON " if game.state == game.St.WON else (
			"lost" if game.state == game.St.LOST else "stuck:%s" % game.St.keys()[game.state])
	if game.state != game.St.WON and game.state != game.St.LOST:
		_fail += 1

	print("  L%d %-18s  %-5s  rings %d  sinks %d  shots %d  score %d  medals %d"
		% [idx + 1, lvl["name"], outcome, game.match_stats["ring_outs"],
		   game.match_stats["sinks"], shots, game.score,
		   game.last_result.get("medals", 0)])


func _pick_target(game, rng: RandomNumberGenerator) -> Vector2:
	var live: Array[Vector2] = []
	for t in game.targets:
		if is_instance_valid(t) and t.state != Marble.State.CAPTURED \
				and t.state != Marble.State.SUNK and t.state != Marble.State.LOST:
			live.append(Vector2(t.position.x, t.position.z))
	if live.is_empty():
		return Vector2.ZERO
	return live[rng.randi() % live.size()]
