extends SceneTree
## Render UI at exact viewport sizes without environment cost on software CI.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.disable_3d = true
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode_choice.select(1)
	game.local_match()
	game.phase = "match"
	game.selected_id = 4
	game.focus_id = 5
	game.actors[2].hp = 24
	game.actors[2].stunned = 2.8
	game.actors[3].shield = 4
	game.actors[4].casting = 0
	game.actors[4].cast_left = 0.9
	game.actors[5].locked = 3.5
	# Staged expired effects expose all six DR symbols without changing spells.
	for category in game.CC.CATEGORIES:
		game.actors[4].dr_states[category] = {"count": 2, "remaining": 12.0}
	game.actors[5].dr_states.stun = {"count": 3, "remaining": 8.0}
	game.actors[2].dr_states.stun = {"count": 2, "remaining": 15.0}
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3440, 1440)]:
		DisplayServer.window_set_size(dimensions)
		root.size = dimensions
		await process_frame
		await process_frame
		game.combat_text.interrupts[5] = Time.get_ticks_msec() + 1200
		game.update_visuals(0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/team-hud-%dx%d.png" % [dimensions.x, dimensions.y])
		print("TEAM HUD CAPTURE ", root.size)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
