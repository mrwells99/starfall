extends SceneTree
var game
var actor
var checks := 0
var failures := 0

class TestConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func step(delta := 1.0/60) -> void:
	game.outlaw_aim_test.physics_tick()
	game._process(delta)
	game.update_visuals(delta)
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	return event
func mouse(index: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new(); event.button_index = index; event.pressed = pressed
	return event
func settle() -> void:
	for frame in 30: step()

func click_hotbar(slot: int) -> void:
	var point: Vector2 = game.ability_buttons[slot].get_global_rect().get_center()
	var hover := InputEventMouseMotion.new(); hover.position = point; hover.global_position = point
	root.push_input(hover,true)
	for down in [true,false]:
		var event := mouse(MOUSE_BUTTON_LEFT,down); event.position = point; event.global_position = point
		root.push_input(event,true)
		await process_frame

func held_right_gesture(bar_slot: int) -> void:
	var preview = game.outlaw_aim_test
	var controls = game.movement_controls
	var motion := InputEventMouseMotion.new(); motion.screen_relative = Vector2(20,0)
	for rapid in [false,true]:
		controls.begin(mouse(MOUSE_BUTTON_RIGHT,true))
		var origin: Vector2 = game.mouse_capture_origin
		game.send_action(bar_slot)
		check(preview.enabled and controls.right,"Entering Detonation retains an already owned right-button hold")
		if rapid:
			for repeat in 3:
				step(); game.send_action(bar_slot); step(); game.send_action(bar_slot)
		else: settle()
		game._input(motion)
		game.send_action(bar_slot)
		check(not preview.enabled and controls.right and game.has_capture_origin and game.mouse_capture_origin == origin,"Exiting Detonation preserves held right-click and its original capture point, including rapid toggles")
		var yaw: float = game.pivot.rotation.y
		game._input(motion)
		check(game.pivot.rotation.y != yaw and is_equal_approx(game.local_yaw,game.pivot.rotation.y),"Held right-click resumes ordinary camera and character turning without another press")
		check(controls.sample(1.0/60) == Vector2.ZERO,"Resuming right-click does not invent two-button forward movement")
		game._input(mouse(MOUSE_BUTTON_RIGHT,false))
		check(not controls.right and not game.has_capture_origin,"Releasing after the transition ends the original camera gesture")
		settle()
	controls.begin(mouse(MOUSE_BUTTON_RIGHT,true)); game.send_action(bar_slot)
	game._input(mouse(MOUSE_BUTTON_RIGHT,false))
	check(preview.enabled and not controls.right,"Releasing right-click during aim does not leave aiming")
	game.send_action(bar_slot)
	check(not controls.right and not game.has_capture_origin,"A release during aim prevents a stuck right-click after exit")
	settle(); game.send_action(bar_slot)
	game._input(mouse(MOUSE_BUTTON_RIGHT,true)); game.send_action(bar_slot)
	check(controls.right and game.has_capture_origin,"A right-button press owned by aiming can continue as normal mouse look on exit")
	game._input(mouse(MOUSE_BUTTON_RIGHT,false)); settle()
	# Physical presses owned by UI must never turn into camera gestures.
	Input.parse_input_event(mouse(MOUSE_BUTTON_RIGHT,true)); controls.cancel()
	game.send_action(bar_slot); game.send_action(bar_slot)
	check(not controls.right and not game.has_capture_origin,"A physically held but unowned right button is not synthesized on exit")
	Input.parse_input_event(mouse(MOUSE_BUTTON_RIGHT,false)); settle()
	for reason in ["cast","roll","backflip","stun"]:
		controls.begin(mouse(MOUSE_BUTTON_RIGHT,true)); game.send_action(bar_slot)
		if reason == "cast": actor.casting = 0
		if reason == "roll": actor.identity.roll_left = .4
		if reason == "backflip": actor.identity.backflip_active = true
		if reason == "stun": actor.stunned = 1
		step()
		check(not preview.enabled and controls.right and game.has_capture_origin,"Aiming yields to "+reason+" while retaining the held camera gesture")
		actor.casting = -1; actor.identity.roll_left = 0; actor.identity.backflip_active = false; actor.stunned = 0
		game._input(mouse(MOUSE_BUTTON_RIGHT,false)); settle()
	for reason in ["focus","menu","death","reset"]:
		controls.begin(mouse(MOUSE_BUTTON_RIGHT,true)); game.send_action(bar_slot)
		if reason == "focus": game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		if reason == "menu": game.panel.show()
		if reason == "death": actor.hp = 0
		if reason == "reset": preview.reset()
		step()
		check(not preview.enabled and not controls.right and not game.has_capture_origin,"Losing "+reason+" discards a held aim gesture")
		game.application_focused = true; game.panel.hide(); actor.hp = 100
		game._input(mouse(MOUSE_BUTTON_RIGHT,false)); settle()
		check(not controls.right,"Returning from "+reason+" cannot restore stale mouse input")

func run() -> void:
	game = load("res://arena.tscn").instantiate(); game.config = TestConfig.new(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.champion_choice.select(game.Kits.NAMES.find("Outlaw")); game.local_match(); game.phase = "match"
	game.application_focused = true
	actor = game.actors[game.local_id]; actor.presentation_grounded = true
	actor.position = Vector3(0,.05,5); actor.reset_physics_interpolation()
	var preview = game.outlaw_aim_test
	settle()
	var aim_slot := 8
	var bar_slot: int = game.assignment.find(aim_slot)
	check(actor.kit[aim_slot].name == "Defense Detonation" and game.ability_buttons[bar_slot].visible,"Defense Detonation owns the visible aiming hotbar ability")
	check(game.AbilityArt.texture_for("Defense Detonation","Outlaw") != null and game.Kits.description(actor.kit[aim_slot],"Outlaw").contains("Firing is not available yet"),"Detonation retains its icon and clearly describes the unfinished firing stage")
	check(game.binds[bar_slot] == (KEY_2 | KEY_MASK_SHIFT),"Detonation retains Shift+2 and existing saved slot assignments")
	check(game.kit_slot(game.assignment.find(10)) == -1 and actor.kit[10].kind == "unavailable","Separate Aim Test slot is retired without shifting other abilities")
	check(not preview.reticle.visible,"Reticle is hidden before aiming")
	var before_kit: Array = actor.kit.duplicate(true)
	var before_health: float = game.actors[2].hp
	var before_cooldowns: Array = actor.cooldowns.duplicate()
	var before_seq: int = game.action_seq
	var normal_length: float = game.arm.spring_length
	var normal_pitch: float = game.arm.rotation.x
	var normal_fov: float = game.camera.fov
	var normal_zoom: float = game.movement_controls.zoom_target
	var normal_muzzle: Vector3 = actor.champion_model.outlaw_art.muzzle_position()
	# Dispatch through the actual ability hotbar, including GUI ownership.
	await process_frame
	await click_hotbar(bar_slot)
	check(preview.enabled,"Clicking Defense Detonation enters aiming even with zero stacks during this preparation pass")
	check(game.has_capture_origin and not game.movement_controls.left and not game.movement_controls.right,"Preview owns mouse look independently of held mouse gestures")
	var samples := []
	var crosshair_time := -1.0
	for frame in 24:
		step(); samples.append(game.arm.spring_length)
		if preview.reticle.visible and crosshair_time < 0: crosshair_time = (frame+1)/60.0
		if frame == 0:
			check(game.arm.spring_length < normal_length and game.arm.spring_length > normal_length-(normal_length-preview.SHOULDER_DISTANCE)*.1,"First camera step eases in without snapping")
			check(not preview.reticle.visible,"Reticle waits for the first camera clearance update")
		if frame == 6:
			check(actor.champion_model.outlaw_art.test_aim_weight > .1 and actor.champion_model.outlaw_art.test_aim_weight < .9,"Gun and camera raise together during transition")
	check(preview.reticle.visible and crosshair_time > 0 and crosshair_time <= .1,"Crosshair appears within 100ms, well before the shoulder pan finishes")
	print("DETONATION_CROSSHAIR_FIRST_VISIBLE_SECONDS: ",crosshair_time)
	check((normal_length-samples[0]) < (samples[0]-samples[1]),"Aiming accelerates across its first frames like normal wheel zoom")
	check((samples[15]-samples[16]) < (samples[1]-samples[2]),"Aiming decelerates gradually as the gun reaches its aimed position")
	check(is_equal_approx(actor.champion_model.outlaw_art.test_aim_weight,preview.weight),"Gun raise follows the same eased weight as the camera")
	settle()
	check(is_equal_approx(game.arm.spring_length,preview.SHOULDER_DISTANCE) and game.arm.position.x > .45,"Camera arrives close over the right shoulder")
	check(actor.champion_model.outlaw_art.muzzle_position().y > normal_muzzle.y+.15,"Pistol visibly rises from the relaxed grip")
	var monotonic := true
	for i in range(1,samples.size()): monotonic = monotonic and samples[i] <= samples[i-1]
	check(monotonic,"Camera moves in smoothly without overshoot")
	var art = actor.champion_model.outlaw_art
	for pitch in [-.65,0.0,.65]:
		preview.aim_pitch = pitch; settle()
		art.skeleton.force_update_all_bone_transforms()
		var hand: int = art.skeleton.find_bone("DEF-hand.R")
		var forward: Vector3 = (art.skeleton.global_basis*art.skeleton.get_bone_global_pose(hand).basis*Vector3.UP).normalized()
		check(forward.dot(art.test_aim_direction) > .995,"Gun follows the aimed pitch with the existing articulated arm")
	var motion := InputEventMouseMotion.new(); motion.screen_relative = Vector2(80,-30)
	var yaw: float = game.pivot.rotation.y
	check(preview.input(motion) and game.pivot.rotation.y != yaw,"Mouse movement steers the shoulder camera")
	for frame in 20: game.movement_controls.sample(1.0/60)
	check(absf(angle_difference(game.local_yaw,game.pivot.rotation.y)) < .005,"Character facing follows aim without an instant turn")
	check(preview.input(mouse(MOUSE_BUTTON_LEFT,true)),"Left-click remains a harmless preview input")
	check(preview.input(mouse(MOUSE_BUTTON_WHEEL_DOWN,true)) and normal_zoom == game.movement_controls.zoom_target,"Aim preview preserves saved camera zoom")
	for direction in [Vector3.RIGHT,Vector3.BACK]:
		for frame in 24:
			actor.position += direction*.07; step()
		check(art.clip == ("RunRight" if direction == Vector3.RIGHT else "WalkBackward"),"Aiming retains accepted lateral movement and reversed backpedal clips")
	actor.position = Vector3(0,.05,5); actor.rotation.y = 0; game.local_yaw = 0; game.pivot.rotation.y = 0; preview.aim_pitch = 0; settle()
	var wall := StaticBody3D.new(); wall.collision_layer = 1; wall.collision_mask = 0
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(.1,3,3); shape.shape = box
	wall.add_child(shape); game.add_child(wall); wall.global_position = game.pivot.global_position+Vector3(.3,0,0)
	await physics_frame; step()
	check(preview.shoulder_right < .2,"Shoulder offset stops before a nearby side wall")
	wall.position = game.pivot.global_position+Vector3(0,0,.85); box.size = Vector3(4,3,.1)
	for frame in 4: await physics_frame; step()
	check(game.arm.get_hit_length() > 0 and game.arm.get_hit_length() < 1.0,"Spring arm keeps the close camera in front of a rear wall")
	wall.free(); await physics_frame; settle()
	check(actor.kit == before_kit and actor.cooldowns == before_cooldowns and actor.gcd == 0 and game.actors[2].hp == before_health and game.action_seq == before_seq,"Aiming does not fire, damage, consume GCD/cooldowns or change the kit")
	check(not game.try_spell(actor.actor_id,aim_slot,2),"Server rejects a local camera utility submitted as a combat ability")
	game._input(key(KEY_ESCAPE))
	check(preview.enabled and not game.panel.visible,"Escape neither exits aiming nor opens an indirect exit through the menu")
	for down in [true,false]: game._input(mouse(MOUSE_BUTTON_RIGHT,down))
	check(preview.enabled and not game.movement_controls.right,"Right-click press and release keep aiming active without starting a camera gesture")
	var has_hint := false
	for label in game.ui.find_children("*","Label",true,false): has_hint = has_hint or label.text.contains("Aim Test active")
	check(not has_hint,"The persistent aiming instruction text is removed")
	await click_hotbar(bar_slot)
	check(not preview.enabled,"Clicking the same hotbar ability again exits aiming")
	check(not preview.reticle.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Exit immediately hides reticle and restores cursor")
	step()
	check(game.arm.spring_length > preview.SHOULDER_DISTANCE and game.arm.spring_length < normal_length,"Camera return is smoothed")
	settle()
	check(is_equal_approx(game.arm.spring_length,normal_length) and is_equal_approx(game.camera.fov,normal_fov) and is_equal_approx(game.arm.rotation.x,normal_pitch) and game.arm.position == Vector3.ZERO,"Normal camera settings are restored exactly")
	for count in [1,2,3]:
		actor.identity.defense_detonation = count
		game.send_action(bar_slot); settle()
		check(preview.enabled and game.proc_ready(actor,actor.kit[aim_slot]),"Detonation aiming works with %d available stack(s)" % count)
		preview.input(mouse(MOUSE_BUTTON_LEFT,true)); preview.input(mouse(MOUSE_BUTTON_LEFT,false))
		game.send_action(bar_slot); settle()
		check(not preview.enabled and actor.identity.defense_detonation == count and actor.casting == -1 and game.actors[2].hp == before_health and game.action_seq == before_seq,"Aiming/clicking/exiting retains every stack and sends no shot or legacy cast")
	actor.identity.defense_detonation = 0
	game.send_action(game.assignment.find(10))
	check(not preview.enabled and game.action_seq == before_seq,"Retired Aim Test action cannot toggle a duplicate ability or send a command")
	var aim_key := key(KEY_2); aim_key.shift_pressed = true
	actor.gcd = 1; actor.locked = 1; game.selected_id = -1
	game._unhandled_input(aim_key)
	check(preview.enabled and game.ability_block_reason(actor,aim_slot,-1).is_empty(),"Default hotkey enters without a target, GCD or spell-school availability")
	game._unhandled_input(aim_key)
	check(not preview.enabled and actor.gcd == 1 and actor.locked == 1,"Same hotbar key toggles off without modifying combat timers")
	actor.gcd = 0; actor.locked = 0; settle()
	# Move to another bar and use a secondary binding: dispatch must use assignment.
	var moved_slot := 18
	game.assignment[bar_slot] = -1; game.assignment[moved_slot] = aim_slot
	game.controls.put(game,"bar_18",1,KEY_F9)
	game._unhandled_input(key(KEY_F9))
	check(preview.enabled and game.action_seq == before_seq,"Moved utility works through a secondary hotbar binding without sending an RPC")
	game.send_action(moved_slot); settle()
	check(not preview.enabled,"Click dispatch on the reassigned slot toggles the utility off")
	game.assignment[moved_slot] = -1; game.assignment[bar_slot] = aim_slot
	game.controls.put(game,"bar_18",1,0)
	# Old snapshots omit the retired trailing local slot.
	var old_snapshot: Dictionary = actor.snapshot(); old_snapshot.cd.resize(10)
	actor.receive(old_snapshot)
	step()
	check(actor.cooldowns.size() == actor.kit.size() and actor.cooldowns[10] == 0 and old_snapshot.cd.size() == 10,"Older snapshots safely fill the retired local slot without mutating the packet")
	preview.toggle(); step()
	var halfway: float = game.arm.spring_length
	var before_velocity: float = preview.transition_velocity
	preview.leave()
	check(game.arm.spring_length == halfway and preview.transition_velocity == before_velocity,"Rapid exit preserves camera position and velocity at the input boundary")
	step(); halfway = game.arm.spring_length; before_velocity = preview.transition_velocity
	preview.toggle()
	check(game.arm.spring_length == halfway and preview.transition_velocity == before_velocity and preview.enabled,"Rapid re-entry preserves motion instead of restarting an easing curve")
	settle(); check(preview.input(mouse(MOUSE_BUTTON_RIGHT,true)) and preview.enabled,"Right-click cannot exit after a rapid reversal either")
	preview.input(mouse(MOUSE_BUTTON_RIGHT,false))
	game.send_action(bar_slot)
	settle()
	# Measure the actual transition at equal times, independent of render FPS.
	var weights := []
	for rate in [30,60,144]:
		preview.reset(); preview.toggle()
		for frame in int(rate/6): preview.tick(1.0/rate)
		weights.append(preview.weight)
		check(preview.weight > 0 and preview.weight < 1,"Aim spring stays bounded at %d FPS" % rate)
	check(absf(weights[0]-weights[1]) < .00001 and absf(weights[0]-weights[2]) < .00001,"Aim transition timing matches at 30, 60 and 144 FPS")
	# Both camera modes must retain precisely the same acceleration profile.
	preview.reset(); preview.toggle()
	game.movement_controls.zoom_target = 7; game.arm.spring_length = 8
	game.movement_controls.zoom_velocity = 0
	preview.advance_transition(.1); game.movement_controls.tick_zoom(.1)
	check(absf(preview.weight-(8-game.arm.spring_length)) < .00001,"Aim and wheel zoom use the same normalized spring response")
	preview.reset(); game.movement_controls.zoom_target = normal_zoom; game.arm.spring_length = normal_length
	game.movement_controls.zoom_velocity = 0; settle()
	for reason in ["cast","roll","backflip","stun"]:
		preview.toggle(); settle()
		if reason == "cast": actor.casting = 0
		if reason == "roll": actor.identity.roll_left = .4
		if reason == "backflip": actor.identity.backflip_active = true
		if reason == "stun": actor.stunned = 1
		step()
		check(not preview.enabled and not preview.reticle.visible,"Aiming yields to "+reason)
		actor.casting = -1; actor.identity.roll_left = 0; actor.identity.backflip_active = false; actor.stunned = 0
		settle()
	held_right_gesture(bar_slot)
	preview.toggle(); settle(); game.application_focused = false; step()
	check(not preview.owns_camera() and not preview.enabled and preview.transition_velocity == 0 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Losing focus releases camera, cursor and transition inertia")
	game.application_focused = true
	preview.toggle(); settle(); game.panel.show(); step()
	check(not preview.owns_camera() and not preview.reticle.visible,"Opening a menu clears the test")
	game.panel.hide(); preview.toggle(); settle(); actor.hp = 0; step()
	check(not preview.owns_camera() and not preview.reticle.visible,"Death leaves the test before spectator camera takes over")
	actor.hp = 100; settle(); preview.toggle(); settle(); game.clear_actors()
	check(not preview.owns_camera() and not preview.enabled and not preview.reticle.visible,"Round teardown clears all test state")
	for title in ["Ember","Luminary","Fulcrum","Vanguard"]:
		game.champion_choice.select(game.Kits.NAMES.find(title)); game.local_match(); game.phase = "match"; step()
		preview.toggle()
		var has_aim := false
		for spell in game.actors[game.local_id].kit: has_aim = has_aim or spell.kind == "defense_detonation"
		check(not has_aim and not preview.enabled,title+" has no aiming test")
	game.clear_actors(); game.queue_free(); await process_frame
	print("Outlaw aim preview checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
