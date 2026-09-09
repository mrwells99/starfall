extends SceneTree
## Fast rendered layout review using the UI fixture; art has its own native review.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.disable_3d = true
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_physics_process(false)
	var failures := 0
	for dimensions in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(dimensions)
		await process_frame
		for state in ["main", "online", "offline", "queue", "host", "join", "settings", "pause", "victory", "defeat"]:
			game.phase = "menu"
			game.menu_state = state
			if state in ["pause", "victory", "defeat"]:
				game.local_match()
				game.phase = "match"
				if state != "pause":
					game.elapsed = 93
					game.finish_round(game.epoch, 0 if state == "victory" else 1, game.make_snapshot())
			game.panel.show()
			game.refresh_menu()
			for frame in range(4): await process_frame
			var bounds := Rect2(Vector2.ZERO, game.ui.size)
			if not bounds.encloses(game.panel.get_global_rect()):
				push_error("Menu overflow %s %s panel=%s bounds=%s" % [dimensions, state, game.panel.get_global_rect(), bounds])
				failures += 1
			for control in [game.main_row, game.settings_row, game.offline_row, game.online_row, game.join_row, game.menu_presentation.metrics]:
				if control.is_visible_in_tree() and not game.panel.get_global_rect().encloses(control.get_global_rect()):
					push_error("Control overflow %s %s" % [dimensions, state])
					failures += 1
		print("MENU LAYOUT REVIEW %s complete" % dimensions)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
