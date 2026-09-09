extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func capture(title: String) -> void:
	game.update_visuals(0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/polish-" + title + ".png")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Polish review needs a rendered window")
		quit(1)
		return
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	await create_timer(0.3).timeout
	await capture("menu")
	game.menu_state = "settings"
	game.refresh_menu()
	await capture("settings")
	var env = game.find_child("CosmicEnvironment", true, false).environment
	var graphics = load("res://scripts/sanctum_graphics.gd")
	graphics.apply_profile(game, "High")
	if not env.ssil_enabled or not env.volumetric_fog_enabled:
		push_error("High profile missing effects on Forward+")
	graphics.apply_profile(game, "Balanced")
	if env.ssil_enabled or env.volumetric_fog_enabled or not env.ssao_enabled:
		push_error("Balanced profile did not remove optional GPU passes")
	graphics.apply_profile(game, "Performance")
	if env.ssao_enabled or root.msaa_3d != Viewport.MSAA_DISABLED:
		push_error("Performance profile did not remove AO/MSAA")
	graphics.apply_profile(game, "Balanced")
	game.menu_state = "offline"
	game.mode_choice.select(1)
	game.local_match()
	game.set_physics_process(false)
	game.phase = "match"
	await create_timer(0.3).timeout
	await capture("availability")
	game.elapsed = 93
	for actor in game.actors.values():
		if actor.team == 1: actor.hp = 0
	game.finish_round(game.epoch, 0, game.make_snapshot())
	await capture("results")
	print("POLISH RENDER REVIEW COMPLETE actual_size=%s renderer=%s" % [root.size, RenderingServer.get_current_rendering_method()])
	quit()
