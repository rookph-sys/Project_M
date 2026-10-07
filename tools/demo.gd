extends SceneTree

## Records a scripted gameplay demo (no human input), for sending to artists
## and collaborators.
##
##   godot --write-movie demo.avi --script res://tools/demo.gd --resolution 1600x900
##
## Shots are hand-picked rather than random so the clip shows the game playing
## well: clean breaks, a chain reaction, every marble colour, both modes.

const FPS := 60.0


func _initialize() -> void:
	_run()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _wait(1.0)

	# Level 1 — the basic break.
	game.load_level(0)
	await _wait(2.5)
	await _shot(game, 0, Vector2(0.10, -1.85), Vector2(0.0, 0.22), 0.80)
	await _wait(0.8)
	await _shot(game, 0, Vector2(-0.30, -1.85), Vector2(-0.22, 0.0), 0.72)
	await _wait(1.2)

	# Level 2 — six-marble cluster, bigger scatter.
	game.load_level(1)
	await _wait(2.0)
	await _shot(game, 0, Vector2(0.0, -1.85), Vector2(0.0, -0.28), 0.90)
	await _wait(0.8)
	await _shot(game, 0, Vector2(-0.6, -1.85), Vector2(-0.32, 0.0), 0.80)
	await _wait(1.2)

	# Level 3 — holes.
	game.load_level(2)
	await _wait(2.0)
	await _shot(game, 0, Vector2(-0.5, -1.85), Vector2(-0.65, 0.20), 0.70)
	await _wait(0.8)
	await _shot(game, 0, Vector2(0.5, -1.85), Vector2(0.65, 0.20), 0.70)
	await _wait(1.2)

	# Level 4 — every marble type, so each colour and weight is on screen.
	game.load_level(3)
	await _wait(2.0)
	for slot in [2, 3, 4, 5, 6]:          # heavy, rubber, precision, sticky, magnet
		await _shot(game, slot, Vector2(randf_range(-0.6, 0.6), -1.85), Vector2(0.0, 0.0), 0.85)
		await _wait(0.6)
	await _wait(2.0)
	quit()


func _shot(game, slot: int, from: Vector2, at: Vector2, power: float) -> void:
	if game.state != game.St.PLACE:
		return
	if slot < game.bag.size() and not game.bag_used[slot]:
		game.selected = slot
	var dir := Vector3(at.x - from.x, 0, at.y - from.y).normalized()
	game.submit_shot(from, dir, power)
	var t := 0.0
	while game.state == game.St.RESOLVE and t < 12.0:
		await process_frame
		t += 1.0 / FPS


func _wait(seconds: float) -> void:
	for i in int(seconds * FPS):
		await process_frame
