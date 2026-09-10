extends SceneTree
## Actual game-camera review; never captures the owner's mouse while rendering.
var game
var actor
var frames := []
const OUTPUT := "res://artifacts/outlaw-detonation-aim/review/"
class ReviewConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass
class ReviewArena extends "res://scripts/arena.gd":
	func capture_mouse() -> void: has_capture_origin = true
	func release_mouse(_restore_position: bool = true) -> void:
		movement_controls.left = false; movement_controls.right = false; has_capture_origin = false

func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1280,800))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,60))
	DisplayServer.window_set_title("Outlaw — Defense Detonation aiming review")
	game = ReviewArena.new(); game.config = ReviewConfig.new(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.champion_choice.select(game.Kits.NAMES.find("Outlaw")); game.local_match(); game.phase = "match"
	actor = game.actors[game.local_id]
	actor.position = Vector3(0,.05,5); actor.rotation.y = 0; actor.presentation_grounded = true; actor.reset_physics_interpolation()
	game.actors[2].position = Vector3(0,.05,-6); game.actors[2].reset_physics_interpolation()
	game.pivot.rotation.y = 0; game.local_yaw = 0
	game.movement_controls.zoom_target = 9.0; game.arm.spring_length = 9.0
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for frame in 20: await step()
	await capture("normal")
	var aim_csv := FileAccess.open(OUTPUT+"aim-frames.csv",FileAccess.WRITE)
	aim_csv.store_line("frame,time_seconds,enabled,blend_weight,blend_velocity,camera_distance_m,gun_raise_weight,reticle_visible")
	actor.identity.defense_detonation = 2
	game.send_action(game.assignment.find(8))
	for frame in 18:
		await step()
		var aim = game.outlaw_aim_test
		aim_csv.store_line("%d,%.6f,%s,%.6f,%.6f,%.6f,%.6f,%s" % [frame,(frame+1)/30.0,aim.enabled,aim.weight,aim.transition_velocity,game.arm.spring_length,actor.champion_model.outlaw_art.test_aim_weight,aim.reticle.visible])
		if frame == 2: await capture("entering")
	await capture("aimed")
	game.outlaw_aim_test.aim_pitch = .45
	for frame in 10: await step()
	await capture("aim-up")
	game.outlaw_aim_test.aim_pitch = -.55
	for frame in 10: await step()
	await capture("aim-down")
	game.send_action(game.assignment.find(8))
	for frame in 18:
		await step()
		var aim = game.outlaw_aim_test
		aim_csv.store_line("%d,%.6f,%s,%.6f,%.6f,%.6f,%.6f,%s" % [frame+18,(frame+1)/30.0,aim.enabled,aim.weight,aim.transition_velocity,game.arm.spring_length,actor.champion_model.outlaw_art.test_aim_weight,aim.reticle.visible])
	aim_csv.close()
	await capture("returned")
	# Record each ordinary zoom frame separately from the shoulder transition.
	var csv := FileAccess.open(OUTPUT+"zoom-frames.csv",FileAccess.WRITE)
	csv.store_line("frame,time_seconds,wheel_steps,requested_distance_m,zoom_velocity_m_s,target_m")
	for frame in 90:
		var wheel_steps := 0.0
		if frame in [3,6,9]: wheel_steps = 1.0
		if frame in [35,38]: wheel_steps = -.5
		if wheel_steps != 0:
			var event := InputEventMouseButton.new(); event.pressed = true
			event.button_index = MOUSE_BUTTON_WHEEL_UP if wheel_steps > 0 else MOUSE_BUTTON_WHEEL_DOWN
			event.factor = absf(wheel_steps); game._unhandled_input(event)
		await step()
		csv.store_line("%d,%.6f,%.2f,%.6f,%.6f,%.6f" % [frame,frame/30.0,wheel_steps,game.arm.spring_length,game.movement_controls.zoom_velocity,game.movement_controls.zoom_target])
		if frame in [3,6,9,30,40,60]: await capture("zoom-%02d" % frame)
	csv.close()
	await review_backflip()
	# Retain real frame-by-frame transitions for timing/pose review or video encoding.
	if "--sequence" in OS.get_cmdline_user_args():
		for frame in 120:
			if frame in [15,75]: game.outlaw_aim_test.toggle()
			if frame in [55,110]: game.outlaw_aim_test.leave()
			await step()
			await capture("frame-%04d" % frame)
	game.clear_actors(); game.queue_free(); await process_frame; await process_frame
	print("OUTLAW_AIM_REVIEW_CAPTURED")
	quit()

func step() -> void:
	await physics_frame
	game.application_focused = true
	game._process(1.0/30)
	game.outlaw_aim_test.physics_tick()
	game.update_visuals(1.0/30)
	actor.champion_model.outlaw_art.skeleton.force_update_all_bone_transforms()
	await process_frame

func review_backflip() -> void:
	actor.position = Vector3(0,.025,0); actor.velocity = Vector3.ZERO; actor.move_input = Vector2.ZERO
	actor.rotation.y = 0; actor.presentation_grounded = null; actor.reset_physics_interpolation()
	for frame in 8:
		await physics_frame
		game.simulate_movement(actor,1.0/60)
	var side := Camera3D.new(); game.add_child(side)
	side.global_position = Vector3(3.5,5.5,3.5); side.look_at(Vector3(0,2,3.5)); side.make_current()
	await capture("backflip-before")
	game.try_spell(actor.actor_id,3,-1)
	var drive := func():
		actor.input_age = 0
		game.tick_actor(actor,1.0/Engine.physics_ticks_per_second)
	physics_frame.connect(drive)
	var checkpoints := [.05,.1,.2,.4,.7,1.0]
	var captured := 0
	for frame in 80:
		await step()
		if captured < checkpoints.size() and actor.identity.backflip_elapsed >= checkpoints[captured]:
			await capture("backflip-%02d" % captured)
			captured += 1
		if not actor.identity.backflip_active: break
	physics_frame.disconnect(drive)
	for frame in 6: await step()
	await capture("backflip-landed")
	game.camera.make_current(); side.queue_free()

func capture(label: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+label+".png")
