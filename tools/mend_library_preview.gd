extends SceneTree
## Preview source animations only; no ability or character files are modified.
const OPTIONS := [
	["Fixing_Kneeling", "1. Kneeling hand-work", .65],
	["Spell_Simple_Idle_Loop", "2. Standing spell / hand-work", .95],
	["Interact", "3. Standing interaction", .95],
	["PickUp_Table", "4. Table-height handling", .95]
]
const OUTPUT := "res://artifacts/mend-library-preview/"
var players: Array[AnimationPlayer] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Engine.max_fps = 24
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(960,800))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,40))
	DisplayServer.window_set_title("Mend candidates · original animation library")
	root.content_scale_size = Vector2i(960,800)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file("res://art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb",state) == OK)
	for i in OPTIONS.size():
		var container := SubViewportContainer.new()
		container.position = Vector2((i%2)*480,(i/2)*400)
		container.size = Vector2(480,400)
		root.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480,400)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("17212e")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = .65
		stage.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35,-30,0)
		stage.add_child(light)
		var actor := document.generate_scene(state)
		stage.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clip: Animation = player.get_animation(OPTIONS[i][0])
		clip.loop_mode = Animation.LOOP_LINEAR
		player.play(OPTIONS[i][0])
		player.advance(0)
		players.append(player)
		print(OPTIONS[i][0], " duration=",clip.length)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(2,1.65,3.6)
		camera.fov = 33
		camera.look_at(Vector3(0,OPTIONS[i][2],0))
		camera.current = true
		var label := Label.new()
		label.position = container.position + Vector2(15,12)
		label.text = OPTIONS[i][1]+"\n"+OPTIONS[i][0]
		label.add_theme_font_size_override("font_size",17)
		root.add_child(label)
	DirAccess.make_dir_recursive_absolute(OUTPUT+"frames")
	for frame in 144:
		for player in players: player.advance(1.0/24)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+"frames/%04d.png" % frame)
	print("MEND_LIBRARY_PREVIEW_CAPTURED 144 frames")
	quit()
