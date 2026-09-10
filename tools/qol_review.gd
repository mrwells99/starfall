extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.disable_3d = true
	root.gui_embed_subwindows = true
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	for factor in [1.0, 1.25]:
		root.content_scale_factor = factor
		for screen in ["offline", "settings", "comfort", "practice", "edit"]:
			game.player_options.dialog.hide()
			game.toggle_edit_mode(false)
			game.leave_session("")
			game.menu_state = screen if screen in ["offline", "settings"] else "settings"
			if screen in ["practice", "edit"]:
				game.local_match()
				game.phase = "match"
				game.panel.show()
				if screen == "edit": game.toggle_edit_mode(true)
			game.refresh_menu()
			if screen == "comfort": game.player_options.open()
			for i in range(5): await process_frame
			game.update_visuals(0)
			await process_frame
			await RenderingServer.frame_post_draw
			if game.panel.visible and not Rect2(Vector2.ZERO, game.ui.size).encloses(game.panel.get_global_rect()):
				push_error("Menu overflow: %s scale %.2f %s in %s" % [screen, factor, game.panel.get_global_rect(), game.ui.size])
				failures += 1
			root.get_texture().get_image().save_png("res://artifacts/qol-%s-%d.png" % [screen, roundi(factor * 100)])
	game.queue_free()
	await process_frame
	await process_frame
	print("QOL VISUAL REVIEW COMPLETE failures=", failures)
	quit(1 if failures else 0)
