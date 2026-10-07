extends SceneTree

## Can full power be reached from anywhere in the launch strip, pulling in the
## direction the shot actually needs? This is the bug the old world-space drag
## had: the common straight-up-the-table shot needs a straight-down pull into
## whatever window space is left below the marble.

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30: await process_frame
	game._menu.visible = false
	game.load_level(0)
	for i in 20: await process_frame

	var vp: Vector2 = root.get_visible_rect().size
	print("")
	print("  viewport %dx%d" % [vp.x, vp.y])
	print("     placement x    pull        max power   room below")
	for x in [-2.7, -1.35, 0.0, 1.35, 2.7]:
		var origin := Vector3(x, MarbleData.RADIUS, -1.85)
		var from: Vector2 = game._cam.unproject_position(origin)
		# Straight down the screen: the slingshot pull for a forward shot.
		var room: float = vp.y - from.y
		var reach: float = game._power_from_drag_at(origin, 1.0, from + Vector2(0, room))
		var ok: bool = reach >= 0.999
		if not ok:
			_fail += 1
		print("     %+5.2f m        down        %.2f        %4.0f px   %s"
			% [x, reach, room, "ok" if ok else "CANNOT REACH FULL"])

	# And a few other directions from the middle of the strip.
	var mid := Vector3(0.0, MarbleData.RADIUS, -1.85)
	var mid_px: Vector2 = game._cam.unproject_position(mid)
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var d: Vector2 = (dir as Vector2).normalized()
		var room: float = game._distance_to_edge(mid_px, d, vp)
		var reach: float = game._power_from_drag_at(mid, 1.0, mid_px + d * room)
		var ok: bool = reach >= 0.999
		if not ok:
			_fail += 1
		print("      0.00 m     (%+.0f,%+.0f)      %.2f        %4.0f px   %s"
			% [d.x, d.y, reach, room, "ok" if ok else "CANNOT REACH FULL"])

	print("")
	if _fail == 0:
		print("  PASS — full power is reachable from every tested spot.")
	else:
		print("  FAIL — %d spot(s) cannot reach full power." % _fail)
	print("")
	quit(0 if _fail == 0 else 1)
