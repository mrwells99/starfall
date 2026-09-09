extends SceneTree
var arena
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func press(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.local_match()
	arena.phase = "match"
	var actor = arena.actors[arena.local_id]
	actor.owner_peer = 1
	actor.position = Vector3(0, 0.01, 4)
	actor.rotation.y = 0
	for i in range(10):
		await physics_frame
		arena.simulate_movement(actor, 1.0 / 60)
	await physics_frame
	var start: Vector3 = actor.position
	arena.prediction.predict(arena, actor, {"seq": 1, "move": Vector2(1, 0), "yaw": 0.0, "jump": false, "delta": 1.0 / 60})
	check(actor.position.x > start.x and is_equal_approx(actor.velocity.x, 6.5), "First input moves immediately at full speed without a server reply")
	var right: Vector3 = actor.position
	arena.prediction.predict(arena, actor, {"seq": 2, "move": Vector2(-1, 0), "yaw": 0.0, "jump": false, "delta": 1.0 / 60})
	check(actor.position.x < right.x and is_equal_approx(actor.velocity.x, -6.5), "Direction reversal changes velocity in the same tick")
	var left: Vector3 = actor.position
	arena.prediction.predict(arena, actor, {"seq": 3, "move": Vector2.ZERO, "yaw": 0.0, "jump": false, "delta": 1.0 / 60})
	check(is_equal_approx(actor.position.x, left.x) and actor.velocity.x == 0, "Releasing input stops immediately")
	actor.stunned = 2
	arena.prediction.predict(arena, actor, {"seq": 4, "move": Vector2(1, 0), "yaw": 0.0, "jump": false, "delta": 1.0 / 60})
	check(actor.velocity.x == 0, "Prediction cannot bypass stun")
	actor.stunned = 0
	actor.identity.root = 2
	arena.simulate_movement(actor, 1.0 / 60)
	check(actor.velocity.x == 0, "Prediction cannot bypass roots")
	actor.identity.root = 0
	actor.identity.slow = 1
	arena.simulate_movement(actor, 1.0 / 60)
	check(is_equal_approx(actor.velocity.x, 6.5 * 0.55), "Prediction uses authoritative slow strength")
	actor.identity.slow = 0
	actor.position = Vector3(-6, 0, 9)
	actor.move_input = Vector2(0, -1)
	for i in range(60):
		await physics_frame
		arena.simulate_movement(actor, 1.0 / 60)
	check(actor.position.z > 7, "Predicted movement collides with the arena pillar")
	arena.prediction.pending = {"pos": Vector3(0, 0, 4), "yaw": 0.0, "velocity": Vector3.ZERO, "move_ack": 4, "motion_revision": 1}
	arena.prediction.reconcile(arena, actor)
	check(actor.position == Vector3(0, 0, 4) and arena.prediction.history.is_empty(), "Authoritative displacement clears stale prediction and corrects position")
	arena.prediction.revision = 1
	arena.prediction.history = [{"seq": 6, "move": Vector2(1, 0), "yaw": 0.0, "jump": false, "delta": 1.0 / 60}]
	arena.prediction.pending = {"pos": Vector3(0, 0, 0), "yaw": 0.0, "velocity": Vector3.ZERO, "move_ack": 5, "motion_revision": 1}
	arena.prediction.reconcile(arena, actor)
	check(actor.position.x > 0, "Unacknowledged input replays after authoritative correction")
	arena.prediction.reset()
	check(arena.prediction.history.is_empty() and arena.prediction.pending.is_empty(), "Round reset clears prediction history")
	arena.controls.assign(arena, "forward", 0, KEY_J)
	press(KEY_W, true)
	check(arena.controls.held("forward") == 0, "Old movement binding no longer moves")
	press(KEY_W, false)
	press(KEY_J, true)
	check(arena.controls.held("forward") == 1, "Rebound movement key is held immediately")
	press(KEY_J, false)
	arena.controls.assign(arena, "forward", 1, KEY_UP)
	press(KEY_UP, true)
	check(arena.controls.held("forward") == 1, "Secondary movement binding works")
	press(KEY_UP, false)
	arena.controls.assign(arena, "forward", 0, KEY_1)
	check(arena.binds[0] == KEY_J and arena.controls.value(arena, "forward", 0) == KEY_1, "Movement/bar conflicts swap instead of firing two actions")
	arena.controls.assign(arena, "bar_7", 1, KEY_K | KEY_MASK_CTRL)
	check(arena.controls.secondary[7] == (KEY_K | KEY_MASK_CTRL), "Secondary bar supports modifiers")
	arena.rebinding = 1
	arena.finish_rebind(KEY_K | KEY_MASK_CTRL)
	check(arena.binds[1] == (KEY_K | KEY_MASK_CTRL) and arena.controls.secondary[7] == KEY_2, "Existing bar editor shares cross-menu conflict handling")
	var old: int = arena.binds[0]
	arena.controls.assign(arena, "bar_0", 0, KEY_ESCAPE)
	check(arena.binds[0] == old, "Reserved menu key cannot be stolen")
	var cfg = load("res://scripts/user_config.gd").new()
	arena.controls.assign(arena, "target_arena_2", 0, KEY_F8)
	arena.controls.assign(arena, "focus_arena_3", 1, KEY_F9)
	arena.controls.save(cfg)
	var loaded = load("res://scripts/key_bindings.gd").new()
	loaded.setup(arena.TOTAL_SLOTS)
	loaded.load_from(cfg)
	check(loaded.actions == arena.controls.actions and loaded.secondary == arena.controls.secondary, "General and secondary binds round-trip through preferences")
	arena.keybind_menu.open()
	check(arena.keybind_menu.visible and arena.keybind_menu.buttons.size() == (arena.controls.actions.size() + arena.TOTAL_SLOTS) * 2, "Menu lists primary/secondary binds for every control and bar slot")
	arena.keybind_menu.begin("backward", 0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	arena.keybind_menu.handle(escape)
	check(arena.keybind_menu.pending.is_empty() and arena.keybind_menu.visible, "Escape cancels capture without leaving the menu")
	arena.keybind_menu.search.text = "Supernova"
	arena.keybind_menu.search.text_changed.emit("Supernova")
	check(arena.keybind_menu.buttons.has("bar_7:0") and arena.keybind_menu.buttons.size() == 2, "Search finds an ability by its current name")
	arena.keybind_menu.clear_binding("bar_7", 1)
	check(arena.controls.secondary[7] == 0, "Clear removes only the chosen binding")
	var assignment: Array = arena.assignment.duplicate()
	arena.reset_all_keybinds()
	check(arena.assignment == assignment and arena.controls.actions == arena.controls.DEFAULTS, "Reset keys preserves the action bar layout")
	arena.keybind_menu.close()
	print("Movement/keybind checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
