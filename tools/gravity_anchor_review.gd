extends SceneTree
## Reproducible in-arena r001 review; -- --capture writes a short motion sequence.
const OUTPUT := "res://artifacts/spell-forge/fulcrum/gravity-anchor/r001"
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("ANCHOR REVIEW start")
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	Engine.max_fps = 30
	DirAccess.make_dir_recursive_absolute(OUTPUT + "/motion")
	if "--studio" in OS.get_cmdline_user_args():
		await studio()
		quit()
		return
	game = load("res://arena.tscn").instantiate()
	print("ANCHOR REVIEW scene loaded")
	root.add_child(game)
	print("ANCHOR REVIEW scene ready")
	game.set_physics_process(false)
	game.mode = 3
	game.roster = {1: {"champion": "Fulcrum", "team": 0}, 4: {"champion": "Fulcrum", "team": 1}}
	game.begin_round()
	print("ANCHOR REVIEW actors ready")
	game.phase = "match"
	game.local_id = 1
	for actor in game.actors.values():
		actor.owner_peer = actor.actor_id
		actor.position = Vector3((actor.actor_id - 3) * 1.4, 0, -3)
	game.actors[1].position = Vector3(-2, 0, 1)
	game.actors[2].position = Vector3(3, 0, -2)
	game.actors[1].identity.anchor_pos = Vector3.ZERO
	game.actors[1].identity.anchor_left = 20.0
	game.actors[2].identity.anchor_pos = Vector3(4, 0, -4)
	game.actors[2].identity.anchor_left = 20.0
	game.update_visuals(0)
	game.ui.hide()
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(0, 5.5, 10)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var title := Label.new()
	title.text = "GRAVITY ANCHOR  /  r001\nGameplay distance • allied and enemy anchors"
	title.position = Vector2(32, 26)
	title.add_theme_font_size_override("font_size", 23)
	layer.add_child(title)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/gameplay.png")
	if "--still" in OS.get_cmdline_user_args():
		print("ANCHOR GAMEPLAY CAPTURE COMPLETE")
		quit()
		return
	camera.position = Vector3(0, 2.3, 4)
	camera.look_at(Vector3(0, 0.9, 0))
	title.text = "GRAVITY ANCHOR  /  r001\nPlacement → suspended core → expiry"
	var marker = game.actors[1].get_node("GravityMarker")
	marker.set_process(false)
	for i in range(60):
		var t := i / 10.0
		marker.sync(20.0 - t, Vector3.ZERO, 1.0, true, t < 5.5, false)
		marker.set_process(false)
		marker.age = t
		marker.apply_pose()
		if i >= 55: title.text = "GRAVITY ANCHOR  /  r001\nExpiry / consumed anchor — visual clears immediately"
		await process_frame
		await RenderingServer.frame_post_draw
		if i == 25: root.get_texture().get_image().save_png(OUTPUT + "/detail.png")
		if "--capture" in OS.get_cmdline_user_args():
			root.get_texture().get_image().save_png(OUTPUT + "/motion/%04d.png" % i)
	print("ANCHOR REVIEW COMPLETE")
	quit()

func studio() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("090815")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bda9ef")
	environment.environment.ambient_light_energy = 0.7
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	environment.environment.glow_intensity = 0.6
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.8
	scene.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("151122")
	mat.roughness = 0.8
	floor_mesh.material_override = mat
	scene.add_child(floor_mesh)
	var marker = preload("res://scripts/gravity_anchor_effect.gd").new()
	scene.add_child(marker)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(2.8, 2.1, 4.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	camera.look_at(Vector3(0, 0.95, 0))
	camera.current = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var title := Label.new()
	title.text = "FULCRUM  /  GRAVITY ANCHOR\nFirst draft · r001"
	title.position = Vector2(42, 34)
	title.add_theme_font_size_override("font_size", 24)
	layer.add_child(title)
	for i in range(60):
		var t := i / 10.0
		marker.sync(20.0 - t, Vector3.ZERO, 1.0, true, t < 5.5, false)
		marker.set_process(false)
		marker.age = t
		marker.apply_pose()
		await process_frame
		await RenderingServer.frame_post_draw
		var screen := root.get_texture().get_image()
		if i == 25: screen.save_png(OUTPUT + "/studio.png")
		if "--capture" in OS.get_cmdline_user_args(): screen.save_png(OUTPUT + "/motion/%04d.png" % i)
	print("ANCHOR STUDIO COMPLETE")
