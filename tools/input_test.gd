extends SceneTree

## Drives the real mouse path: press in the launch strip, drag back, release.
## Needs a rendering context (no --headless) because it projects screen
## coordinates onto the table through the camera.
##
##   godot --script res://tools/input_test.gd --resolution 1280x720

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 20:
		await process_frame

	print("")
	await _gesture(game, "place then drag back and release")
	print("")
	if _fail == 0:
		print("  PASS — mouse place/aim/fire works.")
	else:
		print("  FAIL — %d problem(s)." % _fail)
	print("")
	quit(0 if _fail == 0 else 1)


func _gesture(game, label: String) -> void:
	var cam: Camera3D = game._cam
	# A point inside the launch strip, and a point behind it to drag toward.
	var place_screen := cam.unproject_position(Vector3(0.0, MarbleData.RADIUS, -1.85))
	var drag_screen := cam.unproject_position(Vector3(0.0, MarbleData.RADIUS, -2.95))

	var shots_before: int = game.shots_left

	await _move(place_screen)
	await _button(place_screen, true)
	for i in 3:
		await process_frame

	if game.state != game.St.AIM:
		print("  press did not enter AIM (state=%s)" % game.St.keys()[game.state])
		_fail += 1
		return
	print("  press           -> state AIM, marble placed at z=%.2f" % game._held.position.z)

	await _move(drag_screen)
	for i in 3:
		await process_frame
	print("  drag back 1.1 m -> power %.2f, dir z=%+.2f" % [game._aim_power, game._aim_dir.z])
	if game._aim_power < 0.5:
		print("  drag produced too little power")
		_fail += 1

	await _button(drag_screen, false)
	for i in 3:
		await process_frame

	if game.state != game.St.RESOLVE:
		print("  release did not fire (state=%s)" % game.St.keys()[game.state])
		_fail += 1
		return
	print("  release         -> state RESOLVE, shots %d -> %d" % [shots_before, game.shots_left])

	var waited := 0.0
	while game.state == game.St.RESOLVE and waited < 15.0:
		await process_frame
		waited += 1.0 / 60.0
	print("  resolved in %.1fs -> state %s, progress %d/%d, score %d"
		% [waited, game.St.keys()[game.state], game.progress, game.goal, game.score])


func _move(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)
	await process_frame


func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)
	await process_frame
