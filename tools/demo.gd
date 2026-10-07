extends SceneTree

## Records a scripted walkthrough: campaign shell, each marble ability, and a
## duel against the AI. For capture, not for testing.
##
##   godot --write-movie demo.avi --fixed-fps 60 --script res://tools/demo.gd --resolution 1600x900
##
## Nothing here is interactive — every shot is hand-picked so the clip shows
## the game playing well rather than a bot flailing.

const FPS := 60.0

var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	root.add_child(_game)
	await _wait(0.6)

	# Give the save a plausible mid-campaign state so the screens have content.
	_game.prog.deck_builder_unlocked = true
	for id in ["precision", "heavy", "rubber", "magnet"]:
		_game.prog.unlock_marble(id)
	_game.prog.record_result(0, true, 2700, 3)
	_game.prog.record_result(1, true, 3100, 2)
	_game.prog.record_result(2, true, 2450, 2)
	_game.prog.record_result(3, true, 2900, 1)
	_game.prog.record_result(4, true, 4075, 2)

	_game._menu.show_levels()
	await _wait(3.4)
	_game._menu.show_collection()
	await _wait(4.0)
	_game._menu.show_levels()
	await _wait(1.2)
	_game._menu._on_level_picked(5)          # deck builder for Around the Wall
	await _wait(3.6)

	# L1 — the basic break.
	await _level(0)
	await _shot(0, Vector2(0.10, -1.85), Vector2(0.0, 0.22), 0.80)
	await _shot(0, Vector2(-0.30, -1.85), Vector2(-0.22, 0.0), 0.72)

	# L5 — Heavy, to show BREAKER.
	await _level(4)
	await _shot(0, Vector2(0.0, -1.85), Vector2(0.0, -0.23), 0.92)
	await _shot(1, Vector2(-0.4, -1.85), Vector2(-0.27, 0.0), 0.85)

	# L7 — Magnet, to show PULSE.
	await _level(6)
	await _shot(0, Vector2(0.0, -1.85), Vector2(0.0, 0.60), 0.52)
	await _shot(1, Vector2(-0.5, -1.85), Vector2(-0.42, 0.35), 0.72)

	# L8 — a few turns of the duel, so the AI and the halos are on screen.
	await _level(7)
	for i in 3:
		await _shot(i, Vector2(randf_range(-0.7, 0.7), -1.85), Vector2(0.0, 0.0), 0.88)
		await _wait_for_player()

	await _wait(2.5)
	quit()


func _level(index: int) -> void:
	_game.load_level(index)
	await _wait(2.2)


func _shot(slot: int, from: Vector2, at: Vector2, power: float) -> void:
	if _game.state != _game.St.PLACE:
		return
	if slot < _game.bag.size() and not _game.bag_used[slot]:
		_game.selected = slot
	var dir := (at - from).normalized()
	_game.submit_shot(from, Vector3(dir.x, 0, dir.y), power)
	var t := 0.0
	while _game.state == _game.St.RESOLVE and t < 12.0:
		await process_frame
		t += 1.0 / FPS
	await _wait(0.7)


## In a duel, hand back only once the AI has taken its turn too.
func _wait_for_player() -> void:
	var t := 0.0
	while _game.state != _game.St.PLACE and t < 25.0:
		await process_frame
		t += 1.0 / FPS


func _wait(seconds: float) -> void:
	for i in int(seconds * FPS):
		await process_frame
