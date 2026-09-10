extends SceneTree
## Staged native review. Uses the secondary display and never writes user settings.
var stage: Node3D
var player: AnimationPlayer
var model: Node3D
var camera: Camera3D
var output := "res://artifacts/fulcrum-turn-r004"
func _initialize() -> void:
	call_deferred("run")
func capture(label: String, clip: String, time: float) -> void:
	player.play(clip)
	player.seek(time, true)
	player.pause()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
func run() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	# Windows secondary display is the 1920x1080 screen at the left (Godot index 0).
	var screen := 0
	DisplayServer.window_set_current_screen(screen)
	DisplayServer.window_set_size(Vector2i(1000, 820))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(screen) + Vector2i(40, 50))
	DisplayServer.window_set_title("Fulcrum UAL — staged animation review")
	print("REVIEW_SCREEN ", screen, " POSITION ", DisplayServer.screen_get_position(screen), " SIZE ", DisplayServer.screen_get_size(screen))
	if "--arena" in OS.get_cmdline_user_args():
		await review_arena()
		return
	stage = Node3D.new(); root.add_child(stage)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := output + "/fulcrum.glb"
	if "--library" in OS.get_cmdline_user_args(): path = "res://Godot/AnimationLibrary_Godot_Standard.glb"
	assert(document.append_from_file(path, state) == OK)
	model = document.generate_scene(state)
	stage.add_child(model)
	model.rotation.y = PI
	for node in model.find_children("*", "Node", true, false):
		if node is AnimationPlayer: player = node
		if node is MeshInstance3D:
			for i in node.mesh.get_surface_count():
				var m = node.mesh.surface_get_material(i)
				if m is StandardMaterial3D: m.cull_mode = BaseMaterial3D.CULL_DISABLED
	print("REVIEW_CLIPS ", player.get_animation_list())
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("161923")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b5bfd8")
	environment.environment.ambient_light_energy = .5
	environment.environment.glow_enabled = true
	stage.add_child(environment)
	for i in 2:
		var light := DirectionalLight3D.new(); stage.add_child(light)
		light.rotation_degrees = Vector3(-40, -30 if i==0 else 140, 0)
		light.light_energy = 1.0 if i==0 else .5
	var floor_mesh := MeshInstance3D.new(); floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12, 12)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("282d38")
	floor_mesh.material_override = mat; stage.add_child(floor_mesh)
	camera = Camera3D.new(); stage.add_child(camera)
	camera.position = Vector3(2.5,1.8,-4.2); camera.look_at(Vector3(0,.95,0)); camera.fov = 36; camera.current = true
	if "--library" in OS.get_cmdline_user_args():
		for clip in ["Walk_Loop", "Walk_Formal_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Spell_Simple_Enter", "Spell_Simple_Idle_Loop", "Spell_Simple_Shoot", "Jump_Loop"]:
			for phase in [0.25,0.65]: await capture("library-"+clip+"-"+str(phase), clip, player.get_animation(clip).length*phase)
	else:
		for clip in ["Idle","StrafeLeft","StrafeRight","RunLeft","RunRight","SprintForwardLeft","WalkBackwardLeft","WalkBackwardRight","Cast","JumpLoop"]:
			for phase in [.25,.65]: await capture("fitted-"+clip+"-"+str(phase),clip,player.get_animation(clip).length*phase)
		camera.position = Vector3(-2,1.7,4); camera.look_at(Vector3(0,.95,0))
		await capture("fitted-back", "Walk", .3)
	print("FULCRUM_UAL_REVIEW_COMPLETE")
	stage.queue_free(); await process_frame
	quit()

func review_arena() -> void:
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false); arena.set_process(false)
	arena.mode = 1
	arena.roster = {1:{"champion":"Fulcrum","team":0},2:{"champion":"Ember","team":1}}
	arena.begin_round(); arena.phase = "match"
	arena.ui.hide()
	var actor = arena.actors[1]
	actor.position = Vector3.ZERO
	model = actor.champion_model.fulcrum_art.model
	player = actor.champion_model.fulcrum_art.player
	camera = Camera3D.new(); arena.add_child(camera)
	camera.position = Vector3(2.5,1.8,-4.2); camera.look_at(Vector3(0,.95,0)); camera.fov=36; camera.current=true
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1000,820))
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,50))
	await capture("arena-idle", "Idle", .4)
	await capture("arena-sprint", "Sprint", .22)
	await capture("arena-cast", "Cast", .6)
	print("FULCRUM_UAL_ARENA_REVIEW_COMPLETE")
	arena.queue_free(); await process_frame
	quit()
