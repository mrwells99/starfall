extends "res://tools/hitbox_review.gd"
## Actual installed Outlaw presenter, including equipment and transition layers.
func run() -> void:
	var title := "Outlaw"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="): title = arg.trim_prefix("--class=")
	output = "res://artifacts/outlaw-mend-handwork/review/"
	if title != "Outlaw": output = "res://artifacts/shared-mend-handwork/review/"+title.to_lower()+"/"
	Engine.max_fps = 24
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(960,600))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,40))
	DisplayServer.window_set_title(title+" · installed Mend animation")
	root.content_scale_size = Vector2i(960,600)
	stage = Node3D.new(); root.add_child(stage)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("17212e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .8
	stage.add_child(env)
	for i in 2:
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35,-30 if i == 0 else 140,0)
		light.light_energy = 1.5 if i == 0 else .65; stage.add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.4; camera.position = Vector3(0,1.0,-6)
	stage.add_child(camera); camera.look_at(Vector3(0,1.0,0)); camera.current = true
	if title == "Luminary":
		camera.size = 3.15
		camera.position.y = 1.32
		camera.look_at(Vector3(0,1.32,0))
	heading = Label.new(); heading.position = Vector2(20,15)
	heading.add_theme_font_size_override("font_size",23); root.add_child(heading)
	var note := Label.new(); note.position = Vector2(20,558)
	note.text = title.to_upper()+" / MEND · Front & side · Actual installed animation"
	root.add_child(note)
	for i in 2:
		var actor = load("res://scripts/combatant.gd").new(); stage.add_child(actor)
		actor.setup(i+1,1,0,title); actor.presentation_grounded = true
		actor.position.x = .85 if i == 0 else -.85; actor.rotation.y = 0 if i == 0 else PI*.5
		actor.health_pivot.hide(); actor.team_marker.hide(); actor.setup_hitboxes(); actors.append(actor)
	overlay = Node3D.new(); stage.add_child(overlay)
	assert(DirAccess.make_dir_recursive_absolute(output+"frames") == OK)
	for frame in 120:
		var mending := frame >= 24 and frame < 72
		heading.text = "Mend · hand-work" if mending else ("Idle" if frame < 24 else "Mend · recovery")
		for actor in actors:
			actor.casting = -1
			if mending:
				for i in actor.kit.size():
					if actor.kit[i].kind == "self_heal": actor.casting = i
			actor.cast_left = (72-frame)/24.0 if mending else 0.0
			actor.champion_model.animate(1.0/24,actor); actor.body_hitboxes.update()
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+"frames/%04d.png" % frame) == OK)
		if frame in [20,45,60,80]:
			for actor in actors: draw_body(actor)
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(output+("idle" if frame == 20 else "mend-%d" % frame)+".png") == OK)
			for child in overlay.get_children(): child.free()
	print(title.to_upper(),"_MEND_REVIEW_CAPTURED 120 frames and front/side hitbox pictures")
	quit()
