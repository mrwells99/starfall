extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	arena.set_process(false)
	arena.world_mode = true
	arena.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Vanguard", "team": 1}, 3: {"champion": "Fulcrum", "team": 0}}
	arena.begin_round()
	arena.panel.hide()
	arena.release_mouse()
	arena.camera.reparent(arena)
	arena.camera.position = Vector3(0, 7, 14)
	arena.camera.look_at(Vector3(0, 1.5, 0))
	arena.camera.make_current()
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 800)
	arena.actors[1].position = Vector3(-4, 0, 0)
	arena.actors[2].position = Vector3(0, 0, -1)
	arena.actors[3].position = Vector3(4, 0, 0)
	arena.update_visuals(0)
	await create_timer(0.5).timeout
	arena.relay_chat(1, "there you are! ✨")
	arena.relay_chat(2, "One more duel before we go?")
	arena.relay_chat(3, "Only if you promise to go easy on me this time.")
	await create_timer(0.4).timeout
	print("BUBBLE LAYOUT ui=%s social=%s duel=%s chat=%s" % [arena.ui.size, arena.social.size, arena.social.duel_panel.get_rect(), arena.social.chat.get_rect()])
	for bubble in arena.social.bubbles.values():
		print("BUBBLE %s visible=%s rect=%s" % [bubble.message.text, bubble.visible, bubble.get_rect()])
		if not bubble.visible:
			push_error("Chat bubble should be visible over the speaker")
			quit(1)
			return
	if DisplayServer.get_name() == "headless":
		quit()
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/chat-bubbles.png")
	print("Chat bubble visual capture passed")
	quit()
