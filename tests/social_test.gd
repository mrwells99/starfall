extends SceneTree
var arena
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	arena.toggle_edit_mode(true)
	arena.update_visuals(0)
	await process_frame
	ck(arena.cc_tracker.visible, "CC placeholder visible without a match")
	ck(arena.movable_at(arena.cc_tracker.get_global_rect().get_center()) == arena.cc_tracker, "CC preview can be picked up for dragging")
	arena.toggle_edit_mode(false)
	arena.update_cc_tracker()
	ck(not arena.cc_tracker.visible, "Preview hides outside edit mode")
	arena.world_mode = true
	arena.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Vanguard", "team": 0}, 3: {"champion": "Fulcrum", "team": 1}}
	arena.begin_round()
	arena.panel.hide()
	arena.selected_id = 2
	arena.social.refresh()
	await process_frame
	await process_frame
	ck(arena.social.chat.get_global_rect().intersection(arena.ui.get_global_rect()).size == arena.social.chat.size, "Chat stays inside the viewport")
	var chat_rect: Rect2 = arena.social.chat.get_global_rect()
	ck(is_equal_approx(chat_rect.position.x, 18.0) and is_equal_approx(arena.ui.size.y - chat_rect.end.y, 18.0), "Chat occupies the bottom-left corner")
	ck(chat_rect.size.y <= 160.0, "Chat leaves more vertical room for the arena")
	ck(chat_rect.encloses(arena.social.entry.get_global_rect()) and chat_rect.encloses(arena.social.log_view.get_global_rect()), "Compact chat contains the message entry and scrolling history")
	var original_ui_size: Vector2 = arena.ui.size
	arena.ui.size = Vector2(1600, 1000)
	await process_frame
	ck(is_equal_approx(arena.ui.size.y - arena.social.chat.get_global_rect().end.y, 18.0), "Chat stays in its corner when the viewport grows")
	arena.ui.size = original_ui_size
	await process_frame
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	ck(arena.social.handle_input(enter) and arena.social.typing(), "Enter opens compact chat")
	arena.social.entry.text = "unfinished message"
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ck(arena.social.handle_input(escape) and not arena.social.typing() and arena.social.entry.text.is_empty(), "Escape dismisses chat without sending a draft")
	ck(arena.social.duel_panel.visible and not arena.social.challenge.disabled, "World target has an enabled duel button")
	arena.social.challenge.pressed.emit()
	ck(arena.duel_offers.get(2) == 1, "UI challenge reaches authority")
	arena.local_id = 2
	arena.social.refresh()
	ck(arena.social.accept.visible and arena.social.decline.visible, "Invite shows Accept and Decline")
	arena.social.decline.pressed.emit()
	ck(arena.duel_offers.is_empty(), "Decline clears invite")
	arena.offer_duel(1, 2)
	arena.social.accept.pressed.emit()
	ck(arena.duels.get(2) == 1, "UI accepts duel")
	ck(arena.actors[1].team != arena.actors[2].team, "World participants sharing a lobby side can fight")
	arena.local_id = 1
	arena.actors[1].position = Vector3(0, 0, 0)
	arena.actors[2].position = Vector3(0, 0, -3)
	arena.actors[1].rotation.y = 0
	ck(arena.validate_spell(arena.actors[1], 0, 2) == "", "Actual spell validation allows the accepted opponent")
	arena.social.reset()
	arena.relay_chat(1, "hello [b]world[/b]\n!")
	ck(arena.social.lines.size() == 1 and "hello [b]world[/b]!" in arena.social.lines[0], "Chat is attributed, sanitized and literal")
	ck(arena.social.bubbles.has(1) and arena.social.bubbles[1].message.text == "hello [b]world[/b]!", "Bubble uses the authenticated speaker and literal sanitized text")
	var first_bubble = arena.social.bubbles[1]
	arena.relay_chat(1, "spam")
	arena.relay_chat(555, "spoof")
	ck(arena.social.lines.size() == 1, "Unknown senders and rapid spam refused")
	ck(arena.social.bubbles.size() == 1 and first_bubble.message.text == "hello [b]world[/b]!", "Rejected chat creates no bubble")
	arena.chat_last_sent.clear()
	arena.relay_chat(1, "x".repeat(241))
	ck(arena.social.lines.size() == 1, "Oversized message refused")
	arena.relay_chat(1, "x".repeat(240))
	await process_frame
	ck(arena.social.bubbles[1] == first_bubble and first_bubble.message.text.length() == 240, "New message replaces the existing speaker bubble")
	ck(first_bubble.size.x <= 300 and first_bubble.message.get_line_count() > 1 and first_bubble.message.size.y <= first_bubble.size.y - 24, "Long unbroken text wraps inside the bubble")
	first_bubble.advance(0.2)
	ck(is_equal_approx(first_bubble.modulate.a, 1), "Bubble finishes fading in")
	first_bubble.age = first_bubble.lifetime - 0.3
	first_bubble.advance(0)
	ck(first_bubble.modulate.a > 0 and first_bubble.modulate.a < 1, "Bubble fades out before expiry")
	arena.social._process(1)
	ck(arena.social.bubbles.is_empty(), "Expired bubbles are removed")
	arena.chat_message(arena.epoch - 1, "stale", 1, "stale")
	ck(arena.social.bubbles.is_empty(), "Old-round messages create no bubbles")
	arena.social.show_bubble(2, "See you!")
	for i in 110: arena.social.append_message(str(i))
	ck(arena.social.lines.size() == 100, "Chat history is bounded")
	arena.social.entry.grab_focus()
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.physical_keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	arena.gather_input(1.0 / 60)
	ck(arena.actors[1].move_input == Vector2.ZERO, "Typing blocks movement polling")
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	arena.social.entry.release_focus()
	arena.selected_id = 2
	arena.focus_id = 2
	arena.remove_world_actor(2)
	arena.social._process(0)
	ck(not arena.social.bubbles.has(2), "Departure removes the speaker bubble")
	ck(not arena.actors.has(2) and arena.duels.is_empty(), "Departure removes body and active duel")
	ck(arena.selected_id == -1 and arena.focus_id == -1, "Departure clears target and focus")
	arena.world_mode = false
	arena.social.refresh()
	ck(not arena.social.duel_panel.visible, "Duel UI is world-only")
	arena.camera.reparent(arena)
	arena.camera.position = Vector3(0, 7, 14)
	arena.camera.look_at(Vector3(0, 1.5, 0))
	arena.camera.make_current()
	arena.actors[1].position = Vector3(-2, 0, 0)
	arena.actors[3].position = Vector3(2, 0, 0)
	arena.social.show_bubble(1, "A nearby speaker with a longer message.")
	arena.social.show_bubble(3, "Another nearby speaker with a longer message.")
	arena.social._process(0.2)
	var left = arena.social.bubbles[1]
	var right = arena.social.bubbles[3]
	ck(left.visible and right.visible, "Nearby speakers both have visible bubbles")
	ck(not left.get_rect().intersects(right.get_rect()), "Nearby bubbles do not overlap")
	arena.world_mode = true
	arena.social.refresh()
	arena.social._process(0)
	ck(left.visible and right.visible and not left.get_rect().intersects(arena.social.duel_panel.get_rect()) and not right.get_rect().intersects(arena.social.duel_panel.get_rect()), "Bubbles avoid World duel controls")
	ck(left.mouse_filter == Control.MOUSE_FILTER_IGNORE and left.message.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bubbles never intercept gameplay mouse gestures")
	arena.panel.show()
	arena.social._process(0)
	ck(not left.visible and not right.visible, "Menus hide bubbles")
	arena.panel.hide()
	arena.actors[3].position = Vector3(0, 0, 30)
	arena.social._process(0)
	ck(not right.visible, "Speakers behind the camera are hidden")
	arena.actors[3].position = Vector3(0, 0, -60)
	arena.social._process(0)
	ck(not right.visible, "Distant speakers are hidden")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 10, 1)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = Vector3(0, 3, 7)
	await physics_frame
	arena.social._process(0)
	ck(not left.visible, "Scenery blocks overhead bubbles")
	wall.queue_free()
	arena.leave_session("")
	ck(arena.social.lines.is_empty(), "Leaving clears session chat")
	ck(arena.social.bubbles.is_empty(), "Leaving clears bubbles")
	print("Social checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
