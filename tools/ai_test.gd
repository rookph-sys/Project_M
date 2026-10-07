extends SceneTree

## Does the AI actually play? Headless.
##
##   godot --headless --script res://tools/ai_test.gd
##
## Plays full Knockout matches with a deliberately mediocre bot on the player
## side, and reports how often the AI wins, how long it thinks, and how many
## of its shots achieve anything. An AI that cannot beat a bot firing roughly
## at the opposing marbles is not worth shipping.

const MATCHES := 3

var _results := []


func _initialize() -> void:
	_run()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame

	for level_idx in [7, 9]:      # First Duel (Easy) and Final Table (Normal)
		print("")
		var lvl: Dictionary = Levels.ALL[level_idx]
		print("  %s — AI %s" % [lvl["name"],
			MarbleAI.PROFILES[lvl["ai_level"]]["name"]])
		print("     match   player   ai    result   avg think   candidates")
		var ai_wins := 0
		var think_total := 0
		var think_n := 0
		var considered := 0
		for m in MATCHES:
			var r := await _match(game, level_idx, 900 + m * 37)
			if r["ai_won"]:
				ai_wins += 1
			think_total += r["think_total"]
			think_n += r["turns"]
			considered = r["considered"]
			print("     %2d      %d        %d     %-6s   %4d ms     %d" % [
				m + 1, r["player_points"], r["ai_points"],
				"AI" if r["ai_won"] else ("draw" if r["draw"] else "player"),
				r["think_avg"], r["considered"]])
		_results.append({
			"name": lvl["name"],
			"ai_win_rate": float(ai_wins) / MATCHES,
			"think_avg": think_total / maxi(think_n, 1),
			"considered": considered,
		})

	_report()


func _match(game, level_idx: int, seed_value: int) -> Dictionary:
	game.load_level(level_idx)
	await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var think_total := 0
	var turns := 0
	var considered := 0
	var guard := 0

	while game.state != game.St.WON and game.state != game.St.LOST and guard < 40:
		guard += 1

		if game.state == game.St.AI_TURN:
			var waited := 0.0
			while game.state == game.St.AI_TURN and waited < 20.0:
				await process_frame
				waited += 1.0 / 60.0
			if game._ai:
				think_total += game._ai.last_think_ms
				considered = game._ai.last_considered
				turns += 1
			await _settle(game)
			continue

		if game.state == game.St.PLACE:
			if game.shots_left <= 0:
				await process_frame
				continue
			_bot_shot(game, rng)
			await _settle(game)
			continue

		await process_frame

	return {
		"player_points": game.match_points[0],
		"ai_points": game.match_points[1],
		"ai_won": game.state == game.St.LOST,
		"draw": false,
		"think_total": think_total,
		"think_avg": think_total / maxi(turns, 1),
		"turns": turns,
		"considered": considered,
	}


## A mediocre but not stupid player: aim at an AI marble if one is on the
## table, otherwise push toward the middle.
func _bot_shot(game, rng: RandomNumberGenerator) -> void:
	var aim := Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 1.2))
	for m in game.marbles:
		if is_instance_valid(m) and m.owner_id == game.ACTOR_AI \
				and m.state != Marble.State.CAPTURED \
				and m.state != Marble.State.LOST:
			aim = Vector2(m.position.x, m.position.z)
			break
	for attempt in 6:
		var from := Vector2(clampf(aim.x * 0.6 + rng.randf_range(-0.4, 0.4), -2.7, 2.7), -1.85)
		var dir := Vector3(aim.x - from.x, 0, aim.y - from.y).normalized()
		dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-2.5, 2.5)))
		if game.submit_shot(from, dir, rng.randf_range(0.65, 1.0)):
			return


func _settle(game) -> void:
	var waited := 0.0
	while game.state == game.St.RESOLVE and waited < 20.0:
		await process_frame
		waited += 1.0 / 60.0


func _report() -> void:
	print("")
	for r in _results:
		print("  %-16s AI win rate %3.0f%%   avg think %d ms   %d candidates/turn"
			% [r["name"], r["ai_win_rate"] * 100.0, r["think_avg"], r["considered"]])
	print("")

	var ok := true
	for r in _results:
		if r["think_avg"] > MarbleAI.THINK_BUDGET_MS:
			print("  FAIL — %s exceeds the think budget." % r["name"])
			ok = false
	# The AI is meant to be beatable, not dominant; but a working AI should
	# clear half against a bot that only roughly aims.
	if _results[-1]["ai_win_rate"] < 0.5:
		print("  FAIL — Normal AI wins %.0f%% against a mediocre bot; expected >= 50%%."
			% (_results[-1]["ai_win_rate"] * 100.0))
		ok = false

	if ok:
		print("  PASS — AI plays inside its budget and holds its own.")
	quit(0 if ok else 1)
