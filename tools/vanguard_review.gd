extends SceneTree

const Fighter = preload("res://scripts/combatant.gd")
const Lighting = preload("res://scripts/sanctum_lighting.gd")
var stage: Node3D
var fighters: Array = []

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/vanguard_rebuild_20260908/godot-" + filename + ".png")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1400, 900))
	root.size = Vector2i(1400, 900)
	DirAccess.make_dir_recursive_absolute("res://artifacts/vanguard_rebuild_20260908")
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("101521")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Lighting.AMBIENT_COLOR
	world.environment.ambient_light_energy = Lighting.AMBIENT_ENERGY
	world.environment.glow_enabled = true
	world.environment.glow_hdr_threshold = 1.35
	world.environment.tonemap_exposure = Lighting.EXPOSURE
	stage.add_child(world)
	for i in 3:
		var light := DirectionalLight3D.new()
		Lighting.apply_directional(light, i)
		stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("242b37")
	floor_mat.roughness = 0.95
	floor_mesh.material_override = floor_mat
	stage.add_child(floor_mesh)
	for i in 3:
		var fighter := Fighter.new()
		fighter.setup(i + 1, 1, 1 if i == 2 else 0, "Vanguard")
		stage.add_child(fighter)
		fighter.position.x = (i - 1) * 1.9
		fighter.rotation.y = PI + 0.28
		fighter.nameplate.hide()
		fighter.health_pivot.hide()
		fighter.cast_pivot.hide()
		fighters.append(fighter)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.4
	camera.position = Vector3(0, 2.5, 7)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.current = true
	for f in fighters:
		f.champion_model.animate(0, f)
	await capture("front")
	for f in fighters:
		f.rotation.y = -0.28
	await capture("back")
	for f in fighters:
		f.rotation.y = PI + 0.28
	fighters[1].shield = 5
	fighters[1].champion_model.animate(0.12, fighters[1])
	fighters[2].champion_model.present_strike()
	fighters[2].champion_model.animate(0.07, fighters[2])
	await capture("iron-skin-and-strike")
	paused = true
	preload("res://scripts/vanguard_strike.gd").spawn(stage, fighters[2].position, fighters[2].position - fighters[2].basis.z * 1.5, fighters[2].base_color)
	await capture("strike-effect")
	paused = false
	# Deterministic motion frames, useful for spotting feet/cape intersections.
	for frame in 8:
		for f in fighters:
			f.position.z -= 0.06
			f.champion_model.animate(0.04, f)
		await capture("motion-%02d" % frame)
	print("Vanguard review captured using the Sanctum directional/ambient profile.")
	stage.queue_free()
	await process_frame
	# Actual arena camera, lighting, opponents and cover for distance readability.
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.mode = 3
	arena.roster = {1: {"champion": "Vanguard", "team": 0}}
	arena.begin_round()
	arena.phase = "match"
	arena.ui.hide()
	arena.update_visuals(0)
	for i in 12:
		await process_frame
	await capture("gameplay")
	var hero = arena.actors[arena.local_id]
	hero.position = Vector3.ZERO
	hero.rotation.y = 0
	hero.shield = 5
	hero.champion_model.animate(0.12, hero)
	var portrait := Camera3D.new()
	arena.add_child(portrait)
	portrait.position = Vector3(2.7, 1.9, -3.7)
	portrait.fov = 42
	portrait.look_at(Vector3(0, 1.05, 0))
	portrait.current = true
	await capture("sanctum-portrait")
	quit()
