extends SceneTree
var game
var checks := 0
var failures := 0
class MemoryConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func button(index: int, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = down
	event.position = Vector2(40, 40)
	return event
func key_event(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	root.disable_3d = true
	game = load("res://tests/ui_test_arena.gd").new()
	game.config = MemoryConfig.new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.local_match()
	game.phase = "match"
	game.panel.hide()
	game.application_focused = true
	var controls = game.movement_controls
	var actor = game.actors[game.local_id]
	var foe = game.actors[2]
	check_shift_jump()
	check_turn_in_place()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(900, 0)
	motion.screen_relative = Vector2(50, 0)
	var before: float = game.pivot.rotation.y
	Input.parse_input_event(button(MOUSE_BUTTON_RIGHT, true))
	controls.cancel()
	check(not controls.input(motion) and game.pivot.rotation.y == before, "A held button without a world gesture does not turn camera")
	Input.parse_input_event(button(MOUSE_BUTTON_LEFT, true))
	check(controls.sample(0) == Vector2.ZERO, "Two physically held UI-owned buttons do not move the player")
	Input.parse_input_event(button(MOUSE_BUTTON_LEFT, false))
	Input.parse_input_event(button(MOUSE_BUTTON_RIGHT, false))
	game.local_yaw = 0
	game.pivot.rotation.y = 1.2
	controls.begin(button(MOUSE_BUTTON_RIGHT, true))
	check(is_equal_approx(game.local_yaw, 1.2), "Steering aligns facing without waiting for mouse motion")
	game.player_options.sensitivity = 1
	for scale in [0.9, 1.0, 1.1, 1.25]:
		root.content_scale_factor = scale
		before = game.pivot.rotation.y
		controls.input(motion)
		check(is_equal_approx(before - game.pivot.rotation.y, 0.2), "Steering uses unscaled displacement at every UI scale")
	controls.input(button(MOUSE_BUTTON_LEFT, true))
	check(controls.sample(0) == Vector2(0, -1), "Second button joins world gesture and moves forward")
	controls.input(button(MOUSE_BUTTON_RIGHT, false))
	before = game.local_yaw
	controls.input(motion)
	check(game.local_yaw == before and controls.sample(0) == Vector2.ZERO, "Release right transitions to free orbit without forward movement")
	controls.input(button(MOUSE_BUTTON_LEFT, false))
	check(not controls.left and not controls.right, "Releasing final button ends gesture")
	controls.begin(button(MOUSE_BUTTON_LEFT, true))
	controls.input(button(MOUSE_BUTTON_RIGHT, true))
	controls.input(button(MOUSE_BUTTON_LEFT, false))
	check(controls.right and not controls.left and controls.sample(0) == Vector2.ZERO, "Other release order retains steering and stops mouse-run")
	game.release_mouse()
	check(not controls.left and not controls.right, "Explicit cursor release also terminates gesture ownership")
	controls.cancel()
	actor.stunned = 2
	game.local_yaw = 0
	game.pivot.rotation.y = 2
	controls.begin(button(MOUSE_BUTTON_RIGHT, true))
	controls.input(motion)
	check(game.local_yaw == 0, "Stun permits camera inspection but blocks steering facing")
	controls.cancel()
	key_event(KEY_Q, true)
	before = game.local_yaw
	controls.sample(0.5)
	check(game.local_yaw == before, "Keyboard turning does not accumulate hidden facing while stunned")
	key_event(KEY_Q, false)
	actor.stunned = 0
	controls.cancel()
	controls.action(game.controls.actions.autorun[0])
	check(controls.autorun and controls.sample(0).y == -1, "Autorun persists without a held key")
	key_event(KEY_S, true)
	check(controls.sample(0).y == 1 and not controls.autorun, "Backward intervention cancels autorun immediately")
	key_event(KEY_S, false)
	controls.autorun = true
	controls.begin(button(MOUSE_BUTTON_RIGHT, true))
	game.application_focused = false
	controls.sample(0)
	check(not controls.autorun and not controls.right, "Focus loss ends movement gestures and autorun")
	game.application_focused = true
	key_event(KEY_W, true)
	controls.cancel()
	check(controls.sample(0) == Vector2.ZERO, "Cancelled held movement requires release")
	key_event(KEY_W, false)
	controls.sample(0)
	key_event(KEY_W, true)
	check(controls.sample(0).y == -1, "A fresh key press resumes movement")
	key_event(KEY_W, false)
	var binding: int = game.controls.MOUSE_FLAG | MOUSE_BUTTON_XBUTTON1 | KEY_MASK_SHIFT
	game.controls.assign(game, "autorun", 1, binding)
	var mouse := button(MOUSE_BUTTON_XBUTTON1, true)
	mouse.shift_pressed = true
	check(game.event_binding(mouse) == binding and game.controls.label(binding) == "Shift+Mouse 4", "Mouse bindings support modifiers and readable labels")
	check(game.controls.reserved(game.controls.MOUSE_FLAG | MOUSE_BUTTON_RIGHT), "Camera mouse buttons cannot be stolen")
	game.controls.save(game.config)
	var loaded = load("res://scripts/key_bindings.gd").new()
	loaded.setup(game.TOTAL_SLOTS)
	loaded.load_from(game.config)
	check(loaded.actions.autorun[1] == binding, "Mouse binding survives preference reload")
	var bars: Array = game.binds.duplicate()
	var layout: Array = game.assignment.duplicate()
	game.controls.apply_preset(game, true)
	check(game.controls.actions.turn_left[0] == KEY_A and game.controls.actions.strafe_left[0] == KEY_Q, "Classic preset applies movement keys")
	check(game.binds == bars and game.assignment == layout, "Preset preserves all action bar bindings and layout")
	game.controls.apply_preset(game, false)
	game.controls.put(game, "bar_0", 1, KEY_Q)
	var saved: Dictionary = game.controls.actions.duplicate(true)
	check(game.controls.apply_preset(game, true).begins_with("Preset not applied") and game.controls.actions == saved, "Preset conflict refuses atomically without stealing a spell key")
	game.controls.put(game, "bar_0", 1, 0)
	game.controls.suppressed.clear()
	actor.position = Vector3(0, 0.01, 0)
	actor.move_input = Vector2.ZERO
	actor.owner_peer = 1
	for i in range(6):
		await physics_frame
		game.simulate_movement(actor, 1.0 / 60)
	foe.position = Vector3(0, 0, 3)
	game.selected_id = foe.actor_id
	actor.rotation.y = 0
	game.local_yaw = PI
	actor.casting = -1
	actor.gcd = 0
	actor.cooldowns.fill(0.0)
	game.send_action(0)
	check(actor.casting == 0, "Turn then cast before physics uses current facing")
	actor.casting = -1
	actor.gcd = 0
	actor.rotation.y = 0
	actor.last_input_seq = 100
	actor.move_input = Vector2(1, 0)
	game.apply_action_intent(actor.actor_id, 0, foe.actor_id, 90, Vector2.ZERO, PI, false)
	check(actor.casting == 0 and actor.rotation.y == 0 and actor.move_input == Vector2(1, 0) and actor.last_input_seq == 100, "Late action validates own facing while preserving newer movement")
	actor.casting = -1
	actor.gcd = 0
	actor.stunned = 2
	game.apply_action_intent(actor.actor_id, 0, foe.actor_id, 101, Vector2.ZERO, PI, false)
	check(actor.casting == -1 and actor.rotation.y == 0, "Action intent cannot bypass stun")
	actor.stunned = 0
	actor.last_input_seq = -1
	# Command 1 with jump event 1 is lost. Command 2 repeats the same event.
	game.accept_movement(actor.actor_id, 2, Vector2.ZERO, 0, 1, -1, 17, false, actor.motion_revision, false)
	check(actor.jump_queued and actor.last_jump_id == 1, "Repeated jump event survives a dropped first command")
	game.simulate_movement(actor, 1.0 / 60, true)
	check(actor.velocity.y > 6, "Recovered jump takes off")
	game.accept_movement(actor.actor_id, 3, Vector2.ZERO, 0, 1, -1, 34, false, actor.motion_revision, false)
	check(not actor.jump_queued, "Repeated event after lost acknowledgment cannot jump twice")
	game.accept_movement(actor.actor_id, 1, Vector2.ZERO, 0, 2, -1, 0, false, actor.motion_revision, false)
	check(actor.last_jump_id == 1, "Reordered older command cannot introduce a jump")
	game.accept_movement(actor.actor_id, 4, Vector2.ZERO, 0, 2, -1, 400, false, actor.motion_revision, false)
	check(not actor.jump_queued and actor.last_jump_id == 2, "Expired jump is rejected and acknowledged")
	game.accept_movement(actor.actor_id, 5, Vector2.ZERO, 0, 3, -1, 0, false, actor.motion_revision - 1, false)
	check(not actor.jump_queued and actor.last_jump_id == 3, "Pre-displacement jump cannot replay after teleport")
	var accepted: bool = game.accept_movement(actor.actor_id, 999, Vector2(NAN, 0), 0, 4, -1, 0, false, actor.motion_revision, false)
	check(not accepted and actor.last_input_seq == 5, "Invalid input does not poison sequence ordering")
	actor.identity.root = 2
	game.accept_movement(actor.actor_id, 6, Vector2.ZERO, 0, 4, -1, 0, false, actor.motion_revision, true)
	check(not actor.jump_queued and actor.jump_buffer == 0, "Root rejects jump and buffer")
	actor.identity.root = 0
	actor.position = Vector3(0, 2, 0)
	actor.velocity = Vector3(0, -1, 0)
	actor.jump_queued = true
	actor.jump_buffer = 0.1
	game.simulate_movement(actor, 1.0 / 60, false)
	check(actor.jump_buffer > 0 and actor.velocity.y < 0, "Optional buffer retains a short pre-landing press")
	game.simulate_movement(actor, 1.0 / 60, true)
	check(actor.velocity.y > 6 and actor.jump_buffer == 0, "Buffered jump fires once on landing")
	actor.jump_queued = true
	actor.jump_buffer = 0
	game.simulate_movement(actor, 1.0 / 60, false)
	check(not actor.jump_queued and actor.jump_buffer == 0, "Buffer disabled preserves press-only behavior")
	actor.move_input = Vector2(1, 0)
	actor.rotation.y = 0
	actor.walking = true
	game.simulate_movement(actor, 1.0 / 60, true)
	check(is_equal_approx(actor.velocity.x, 3.25), "Walk speed is bounded by shared simulation")
	actor.walking = false
	game.simulate_movement(actor, 1.0 / 60, true)
	check(is_equal_approx(actor.velocity.x, 6.5), "Running retains original speed")
	game.player_options.camera_follow = true
	game.local_yaw = 0
	game.pivot.rotation.y = 1
	controls.follow_delay = 0
	controls.tick(0.1)
	check(game.pivot.rotation.y < 1 and game.local_yaw == 0, "Camera follow changes camera without turning actor")
	controls.begin(button(MOUSE_BUTTON_LEFT, true))
	before = game.pivot.rotation.y
	controls.tick(0.1)
	check(game.pivot.rotation.y == before, "Manual orbit suspends camera follow")
	controls.cancel()
	game.player_options.camera_follow = false
	game.player_options.jump_buffer = true
	game.player_options.turn_speed = 3.0
	game.player_options.save()
	game.player_options.jump_buffer = false
	game.player_options.load_preferences()
	check(game.player_options.jump_buffer and game.player_options.turn_speed == 3.0, "Movement comfort settings persist")
	# Exercise actual arena ramps rather than assuming a generic step solver is needed.
	actor.position = Vector3(15, 0.01, 11)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2(0, -1)
	actor.jump_buffer = 0
	for i in range(70):
		await physics_frame
		game.simulate_movement(actor, 1.0 / 60)
	check(actor.position.y > 1.1 and actor.position.z < 6, "Character traverses uphill ramp onto terrace without a jump")
	actor.move_input = Vector2(0, 1)
	for i in range(130):
		await physics_frame
		game.simulate_movement(actor, 1.0 / 60)
	check(actor.position.y < 0.1 and actor.position.z > 10 and actor.is_on_floor(), "Character traverses downhill ramp back onto arena floor")
	game.clear_actors()
	check(game.pending_jump_id == 0 and game.jump_serial == 0 and not controls.autorun, "Round teardown clears transient movement")
	print("Movement controls checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)

func check_shift_jump() -> void:
	var bindings = game.controls
	var saved_actions: Dictionary = bindings.actions.duplicate(true)
	var saved_binds: Array = game.binds.duplicate()
	var saved_secondary: Array = bindings.secondary.duplicate()
	bindings.actions.jump = [KEY_SPACE, 0]
	var chord := KEY_SPACE | KEY_MASK_SHIFT
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	event.shift_pressed = true
	game.queued_jump = false
	game._unhandled_input(event)
	check(game.queued_jump, "Unbound Shift+Space still queues the normal Space jump")
	check(bindings.matches_jump(game, KEY_SPACE), "Plain Space still jumps")
	bindings.actions.walk[1] = chord
	check(not bindings.matches_jump(game, chord), "Explicit secondary control binding prevents Shift jump fallback")
	bindings.actions.walk[1] = 0
	game.binds[0] = chord
	check(not bindings.matches_jump(game, chord), "Explicit primary ability binding prevents Shift jump fallback")
	game.binds[0] = saved_binds[0]
	bindings.secondary[0] = chord
	check(not bindings.matches_jump(game, chord), "Explicit secondary ability binding prevents Shift jump fallback")
	bindings.secondary[0] = saved_secondary[0]
	bindings.actions.jump = [0, chord]
	check(bindings.matches_jump(game, chord) and not bindings.matches_jump(game, KEY_SPACE), "Explicit Shift+Space jump remains distinct from unbound Space")
	bindings.actions.jump = [KEY_J, 0]
	check(bindings.matches_jump(game, KEY_J | KEY_MASK_SHIFT) and not bindings.matches_jump(game, chord), "Shift fallback follows a rebound jump key")
	bindings.actions.jump = [KEY_SPACE, 0]
	check(not bindings.matches_jump(game, chord | KEY_MASK_CTRL), "Shift fallback does not discard other modifiers")
	game.queued_jump = false
	event.echo = true
	game._unhandled_input(event)
	check(not game.queued_jump, "Shift jump ignores key repeat")
	event.echo = false
	event.pressed = false
	game._unhandled_input(event)
	check(not game.queued_jump, "Shift jump ignores key release")
	bindings.actions = saved_actions
	game.binds.assign(saved_binds)
	bindings.secondary = saved_secondary
	game.queued_jump = false

func check_turn_in_place() -> void:
	var controls = game.movement_controls
	for aiming in [false, true]:
		game.outlaw_aim_test.enabled = aiming
		for steering in [false, true]:
			controls.right = steering
			for entry in [[KEY_Q, 1.0], [KEY_E, -1.0]]:
				game.local_yaw = 0
				game.pivot.rotation.y = 0
				key_event(entry[0], true)
				var movement: Vector2 = controls.sample(0.1)
				check(movement == Vector2.ZERO and is_equal_approx(game.local_yaw, entry[1] * 0.1 * game.player_options.turn_speed), "Turn key rotates in place (aim=%s, RMB=%s, key=%s)" % [aiming, steering, entry[0]])
				key_event(entry[0], false)
			key_event(KEY_A, true)
			check(controls.sample(0) == Vector2(-1, 0), "Strafe remains independent (aim=%s, RMB=%s)" % [aiming, steering])
			key_event(KEY_A, false)
	game.outlaw_aim_test.enabled = false
	controls.right = false
