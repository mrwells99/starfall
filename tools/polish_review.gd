extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func capture(title: String) -> void:
	game.update_visuals(0)
	if title == "availability":
		var actor = game.actors[game.local_id]
		game.ability_tooltip.present_availability(game.Kits.description(actor.kit[0], actor.champion), game.ability_block_reason(actor, 0, game.selected_id), Vector2(470, 640), game.ui.size)
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
	game.menu_state = "online"
	for i in range(game.Kits.NAMES.size()):
		game.champion_choice.select(i)
		game.refresh_menu()
		await capture("select-" + game.Kits.NAMES[i].to_lower())
	var portrait = game.menu_presentation.preview
	var original_rotation: float = portrait.current_model.rotation.y
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	portrait._gui_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(100, 0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	portrait._gui_input(drag)
	press.pressed = false
	portrait._gui_input(press)
	if is_equal_approx(portrait.current_model.rotation.y, original_rotation) or portrait.dragging:
		push_error("Portrait drag did not rotate and release")
		quit(1)
		return
	await capture("select-rotated")
	if RenderingServer.viewport_get_update_mode(portrait.viewport.get_viewport_rid()) != RenderingServer.VIEWPORT_UPDATE_DISABLED:
		push_error("Portrait kept rendering after drag stopped")
		quit(1)
		return
	game.champion_choice.select(0)
	game.menu_state = "offline"
	game.refresh_menu()
	await capture("offline")
	game.menu_presentation.introduction.rows[0].mouse_entered.emit()
	await capture("ability-guide")
	game.menu_presentation.introduction.clear_hover()
	game.menu_presentation.introduction.all_button.pressed.emit()
	await capture("all-abilities")
	game.menu_presentation.introduction.all_button.pressed.emit()
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
	game.selected_id = 4
	game.actors[1].position = Vector3(0, 0, 6)
	game.actors[4].position = Vector3(0, 0, -15)
	await capture("availability")
	game.show_event(game.epoch, 4, game.local_id, "STUN", game.RED)
	game.show_event(game.epoch, 4, game.local_id, "−42", game.RED)
	game.show_event(game.epoch, 4, game.local_id, "DEFEATED", game.GOLD)
	game.actors[game.local_id].hp = 0
	for actor in game.actors.values():
		actor.position = Vector3((actor.actor_id % 3 - 1) * 3, 0.1, 3 if actor.team == 0 else -5)
		actor.reset_physics_interpolation()
	game.update_visuals(0)
	await create_timer(0.3).timeout
	await capture("spectator")
	game.spectator.cycle(1)
	await create_timer(0.3).timeout
	await capture("spectator-next")
	game.actors[game.local_id].hp = 100
	game.elapsed = 93
	for actor in game.actors.values():
		if actor.team == 1: actor.hp = 0
	game.finish_round(game.epoch, 0, game.make_snapshot())
	await capture("results")
	for actor in game.actors.values():
		actor.hp = 100 if actor.team == 1 else 0
	game.finish_round(game.epoch, 1, game.make_snapshot())
	await capture("defeat")
	game.phase = "match"
	game.refresh_menu()
	await capture("pause")
	game.world_mode = true
	game.roster = {1: {"champion": "Ember", "team": 0}}
	game.begin_round()
	game.panel.hide()
	game.update_visuals(0)
	game.menu_camera.make_current()
	game.menu_camera.position = Vector3(0, 10, 3)
	game.menu_camera.look_at(Vector3(0, 1, -8))
	await capture("world-dummies")
	print("POLISH CAPTURES COMPLETE; releasing scene")
	game.queue_free()
	await process_frame
	await process_frame
	print("POLISH RENDER REVIEW COMPLETE actual_size=%s renderer=%s" % [root.size, RenderingServer.get_current_rendering_method()])
	quit()
