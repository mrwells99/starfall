extends SceneTree

var arena
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func point_mouse(point: Vector2) -> void:
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)

func mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func click(point: Vector2) -> void:
	point_mouse(point)
	mouse_button(point, MOUSE_BUTTON_LEFT, true)
	mouse_button(point, MOUSE_BUTTON_LEFT, false)
	await process_frame
	arena.update_visuals(0)

func key_event(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI tests require a game window; run without --headless.")
		quit(1)
		return
	# The project now launches fullscreen, which would make the window size — and
	# therefore mouse coordinates and screenshot framing — depend on whoever's
	# monitor is running the suite. Pin it.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	Input.use_accumulated_input = false
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.mode_choice.select(1)
	arena.local_match()
	arena.set_physics_process(false)
	arena.phase = "match"
	arena.actors[1].position = Vector3(0, 0, 8)
	arena.actors[4].position = Vector3(0, 0, -2)
	arena.update_visuals(0)
	await create_timer(0.4).timeout
	await physics_frame
	await process_frame
	arena.update_visuals(0)
	var original: int = arena.selected_id
	var own_point: Vector2 = arena.camera.unproject_position(arena.actors[1].position + Vector3.UP)
	var enemy_point: Vector2 = arena.camera.unproject_position(arena.actors[4].position + Vector3.UP)
	await click(own_point)
	check(arena.selected_id == original, "Clicking own model does not target self")
	arena.selected_id = 1
	await click(enemy_point)
	check(arena.selected_id == 1, "Clicking enemy model does not change target")
	arena.selected_id = -1
	await click(enemy_point)
	check(arena.selected_id == -1, "Clicking a model does not acquire a cleared target")
	arena.selected_id = 4
	for attempt in range(3):
		point_mouse(own_point)
		mouse_button(own_point, MOUSE_BUTTON_LEFT, true)
		mouse_button(own_point, MOUSE_BUTTON_RIGHT, true)
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Both-button movement still captures mouse")
		mouse_button(own_point, MOUSE_BUTTON_LEFT, false)
		mouse_button(own_point, MOUSE_BUTTON_RIGHT, false)
		check(arena.selected_id == 4, "Repeated both-button movement preserves target")
	arena.update_visuals(0)
	await click(arena.player_frame.get_global_rect().get_center())
	check(arena.selected_id == 1, "Clicking player health frame selects self")
	await click(arena.party_buttons[1].get_global_rect().get_center())
	check(arena.selected_id == 2, "Clicking party frame selects ally")
	await click(arena.enemy_buttons[1].get_global_rect().get_center())
	check(arena.selected_id == 5, "Clicking enemy frame selects enemy")
	arena.focus_id = 4
	arena.update_visuals(0)
	await process_frame
	await click(arena.focus_frame.get_global_rect().get_center())
	check(arena.selected_id == 4, "Clicking focus frame selects focused actor")
	key_event(KEY_TAB)
	await process_frame
	key_event(KEY_TAB, false)
	check(arena.selected_id == 5, "Tab cycles enemy targets")
	key_event(KEY_F1)
	await process_frame
	key_event(KEY_F1, false)
	check(arena.selected_id == 1, "Friendly targeting keybind still works")
	arena.update_visuals(0)
	point_mouse(arena.ability_buttons[0].get_global_rect().get_center())
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.visible, "Hover shows custom tooltip")
	# One hover, everything on it. There is no Shift variant any more.
	var hovered: String = arena.ability_tooltip.label.text
	check(hovered.contains("Deal 16"), "Hover gives the effect description")
	check(hovered.contains("Cooldown") and hovered.contains("Range") and hovered.contains("Cost"),
		"Hover carries cast, range, cooldown and cost")
	check(hovered.contains("Instant") or hovered.contains("cast"), "Hover states cast time")
	check(not hovered.contains("Shift"), "Tooltip no longer advertises a Shift variant")
	await process_frame
	await process_frame
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.size.y < 220, "Tooltip stays compact after layout")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/tooltip-short.png")
	key_event(KEY_SHIFT)
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.label.text == hovered, "Holding Shift changes nothing")
	key_event(KEY_SHIFT, false)
	arena.panel.show()
	arena.update_ability_tooltip()
	check(not arena.ability_tooltip.visible, "Opening menu hides tooltip")
	arena.panel.hide()
	arena.capture_mouse()
	arena.update_ability_tooltip()
	check(not arena.ability_tooltip.visible, "Mouse-look hides tooltip")
	arena.release_mouse()
	for champion in arena.Kits.NAMES:
		for ability in arena.Kits.get_kit(champion):
			var text: String = arena.Kits.description(ability, champion)
			check(not arena.Kits.summary(ability).is_empty() and text.contains("Cooldown"),
				"Description coverage: " + ability.name)
			arena.ability_tooltip.present(ability, champion, Vector2(1100, 740), arena.ui.size)
			await process_frame
			await process_frame
			arena.ability_tooltip.present(ability, champion, Vector2(1100, 740), arena.ui.size)
			check(Rect2(Vector2.ZERO, arena.ui.size).encloses(arena.ability_tooltip.get_global_rect()), "Tooltip fits viewport: " + ability.name)
	# Cooldown sweep: an ability on cooldown shades its slot and shows a number;
	# an off-GCD ability must not be shaded by the global cooldown.
	var me = arena.actors[arena.local_id]
	me.cooldowns[1] = 6.0
	me.gcd = 1.2
	arena.update_visuals(0)
	check(arena.cooldown_overlays[1].remaining > 5.0 and not arena.cooldown_overlays[1].is_gcd,
		"Ability cooldown drives its own sweep")
	check(arena.cooldown_overlays[1].label.visible, "Ability cooldown shows a number")
	check(arena.cooldown_overlays[0].is_gcd and arena.cooldown_overlays[0].remaining > 0.0,
		"Global cooldown sweeps a ready slot")
	check(not arena.cooldown_overlays[0].label.visible, "Global cooldown shows no number")
	check(arena.cooldown_overlays[2].remaining == 0.0, "Off-GCD ability is not swept by the global cooldown")
	me.cooldowns[1] = 0.0
	me.gcd = 0.0
	arena.update_visuals(0)
	check(arena.cooldown_overlays[1].remaining == 0.0, "Sweep clears when the cooldown ends")
	check(arena.CooldownOverlay.format_time(72.0) == "2m" and arena.CooldownOverlay.format_time(12.4) == "13"
		and arena.CooldownOverlay.format_time(3.4) == "3.4", "Countdown formats like OmniCC")
	# --- aura chips on the unit frame -----------------------------------------
	var me2 = arena.actors[arena.local_id]
	me2.stunned = 3.0
	me2.shield = 5.0
	arena.update_visuals(0)
	var strip := arena.player_frame.get_child(4) as HBoxContainer
	var shown := 0
	for chip in strip.get_children():
		if (chip as PanelContainer).visible:
			shown += 1
	check(shown == 2, "Active auras appear as chips on the unit frame")
	var first := strip.get_child(0) as PanelContainer
	check(first.has_meta("aura") and (first.get_child(0) as Label).text.contains("Stunned"),
		"Aura chip is labelled and carries its data")
	# Hovering a chip explains the effect.
	point_mouse(first.get_global_rect().get_center())
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.visible and arena.ability_tooltip.label.text.contains("Cannot move"),
		"Hovering an aura describes it")
	me2.stunned = 0
	me2.shield = 0
	arena.update_visuals(0)
	var still := 0
	for chip in strip.get_children():
		if (chip as PanelContainer).visible:
			still += 1
	check(still == 0, "Chips clear when the effects expire")

	# --- edit mode: layout, keybinds, ability assignment ----------------------
	arena.toggle_edit_mode(true)
	check(arena.edit_mode and arena.edit_overlay.visible, "Edit mode shows its overlay")
	check(arena.ability_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Hotbar stops swallowing clicks while editing")
	# Swapping two slots moves the abilities, not the cooldowns underneath.
	var before_first: int = arena.assignment[0]
	var before_last: int = arena.assignment[6]
	arena.swap_slots(0, 6)
	check(arena.assignment[0] == before_last and arena.assignment[6] == before_first,
		"Dragging one slot onto another swaps the abilities")
	check(arena.kit_slot(0) == before_last, "Bar position resolves to the assigned ability")
	arena.swap_slots(0, 6)
	# Rebinding is de-duplicated: taking a key from another slot gives that slot
	# the key it replaced, so no key ever fires two abilities.
	arena.begin_rebind(2)
	check(arena.rebinding == 2, "Clicking a slot starts a rebind")
	arena.finish_rebind(KEY_1)
	check(arena.binds[2] == KEY_1 and arena.binds[0] != KEY_1, "Rebinding steals the key from its old slot")
	check(arena.binds[0] == KEY_3, "The displaced slot inherits the freed key")
	arena.reset_layout()
	check(arena.binds[0] == KEY_1 and arena.binds[2] == KEY_3 and arena.assignment[3] == 3,
		"Reset restores default binds and assignment")
	arena.toggle_edit_mode(false)
	check(not arena.edit_mode and not arena.edit_overlay.visible, "Done leaves edit mode")
	check(arena.ability_buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP, "Hotbar is clickable again")

	# A malformed saved assignment must be refused whole, not half-applied —
	# a duplicate entry would make one ability unreachable.
	arena.config.set_value("hud", "assignment", [0, 0, 1, 2, 3, 4, 5])
	arena.load_layout()
	var default_order := true
	for i in range(7):
		if arena.assignment[i] != i:
			default_order = false
	check(default_order, "A duplicated assignment is rejected")
	arena.config.set_value("hud", "assignment", [])

	print("UI checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
