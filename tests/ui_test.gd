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
	print("UI checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
