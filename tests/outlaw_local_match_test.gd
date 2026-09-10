extends SceneTree
## Full local-match startup, moving Deadeye, rendering, then leave/restart.
var game
var checks := 0
var failures := 0
var rendered := false

class ReviewConfig extends "res://scripts/user_config.gd":
	func load_config() -> void:
		if "--saved-config" in OS.get_cmdline_user_args(): data.load(PATH)
		set_value("graphics", "frame_limit", 60)
	func save_config() -> void: pass
	func apply_display() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func step(direction: Vector2) -> void:
	# move_and_slide uses the engine frame delta. Drive it on the physics clock
	# so a 30 FPS review doesn't move twice as far as its 60 Hz combat tick.
	await physics_frame
	var local = game.actors[game.local_id]
	local.move_input = direction
	for actor in game.actors.values():
		actor.input_age = 0
		game.tick_actor(actor, 1.0/60)
	game.update_visuals(1.0/60)

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	Engine.max_fps = 30
	if rendered:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 800))
		DisplayServer.window_set_current_screen(0)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(40, 50))
		DisplayServer.window_set_title("Starfall — Deadeye and local-match restart verification")
	game = load("res://arena.tscn").instantiate()
	game.config = ReviewConfig.new()
	root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.set_physics_process(false)
	# The usual camera-follow loop is paused with game input in this test.
	game.camera.reparent(game)
	game.camera.position=Vector3(10,8,16)
	game.camera.look_at(Vector3(0,1,0))
	game.load_layout()
	await process_frame; await process_frame
	game.champion_choice.select(game.Kits.NAMES.find("Outlaw"))
	var directions := [Vector2.UP,Vector2(1,-1).normalized(),Vector2.RIGHT,Vector2(1,1).normalized(),Vector2.DOWN,Vector2(-1,1).normalized(),Vector2.LEFT,Vector2(-1,-1).normalized()]
	var clips := ["Walk","WalkForwardRight","StrafeRight","WalkBackwardRight","WalkBackward","WalkBackwardLeft","StrafeLeft","WalkForwardLeft"]
	for round_index in 3:
		game.mode_choice.select(0 if round_index==0 else 1)
		game.local_match()
		game.phase="match"
		check(game.actors.size()==(2 if round_index==0 else 6), "Local match %d spawns the selected team size" % round_index)
		var local = game.actors[game.local_id]
		local.position=Vector3(0,.05,4);local.rotation.y=0
		var enemy_index := 0
		for actor in game.actors.values():
			if actor==local: continue
			# Keep opponents rendered and targetable, but prevent bot kicks and
			# stuns from interrupting the directional presentation regression.
			actor.owner_peer=actor.actor_id
			actor.move_input=Vector2.ZERO
			actor.position=Vector3((enemy_index-1)*3,.05,-4 if actor.team!=local.team else 8)
			if actor.team!=local.team: enemy_index+=1
		for actor in game.actors.values(): actor.reset_physics_interpolation()
		await physics_frame
		for frame in 10: await step(Vector2.ZERO)
		check(game.try_spell(game.local_id,9,-1), "Deadeye starts without a target in local match %d" % round_index)
		check(local.identity.outlaw_channel.get("marked",[]).size()==enemy_index, "Deadeye acquires every opponent")
		for sector in 8:
			for frame in 20: await step(directions[sector])
			var art = local.champion_model.outlaw_art
			check(art.clip==clips[sector] and art.player.current_animation==art.clip_names[clips[sector]], "Deadeye sector %d in match %d: expected %s, got %s at %s with velocity %s" % [sector,round_index,clips[sector],art.clip,local.position,local.velocity])
			check(local.casting==9, "Moving changes do not cancel Deadeye")
			if rendered and round_index==1 and sector==6:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/outlaw-forge-v2/deadeye-left-fixed.png")
		var expected := {}
		for enemy in game.actors.values():
			if enemy.team!=local.team:
				expected[enemy.actor_id]=60.0 if local.position.distance_to(enemy.position)<=18 and game.has_los(local,enemy) else 100.0
		for frame in 22: await step(Vector2.ZERO)
		check(local.casting==-1, "Deadeye completes without interrupting the match")
		for id in expected: check(game.actors[id].hp==expected[id], "Deadeye applies the correct final visibility and damage to %d" % id)
		game.leave_session("")
		await process_frame; await process_frame
		check(game.actors.is_empty(), "Leaving a match clears its actors before the next local startup")
	game.queue_free()
	await process_frame; await process_frame
	print("Outlaw local match checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
