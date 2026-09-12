extends SceneTree
var actor
var art

func _initialize() -> void: call_deferred("run")

func advance(seconds: float, moving: bool = false) -> void:
	for i in ceili(seconds * 60):
		if moving: actor.position.z -= 7.5 / 60.0
		art.animate(actor.champion_model, 1.0 / 60, actor)
		await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(960, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202936")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("303641")
	floor_mesh.material_override = stone
	stage.add_child(floor_mesh)
	actor = load("res://scripts/combatant.gd").new()
	stage.add_child(actor)
	actor.setup(1, 1, 0, "Null")
	actor.presentation_grounded = true
	actor.health_pivot.hide()
	art = actor.champion_model.null_art
	var camera := Camera3D.new()
	actor.add_child(camera)
	camera.position = Vector3(2.5, 2.4, 3.7)
	camera.look_at(Vector3(0, .8, 0))
	camera.current = true
	await advance(.2)
	assert(not art.haste_wind.visible, "Wind must be absent without Haste")
	actor.identity.null_haste = 6.0
	await advance(.45, true)
	assert(art.haste_wind.visible, "Haste should show moving wind")
	DirAccess.make_dir_recursive_absolute("res://artifacts/null-haste")
	root.get_texture().get_image().save_png("res://artifacts/null-haste/running.png")
	actor.identity.stealth = true
	art.target_stealth_alpha = 0.0
	await advance(.6, true)
	assert(not art.haste_wind.visible, "Haste must not expose a fully hidden Null")
	actor.identity.stealth = false
	art.target_stealth_alpha = 1.0
	await advance(.6)
	assert(art.haste_wind.visible, "Wind resumes on reveal while Haste remains active")
	actor.identity.null_haste = 0.0
	await advance(.4)
	assert(not art.haste_wind.visible, "Wind fades out when Haste expires")
	actor.identity.null_haste = 6.0
	await advance(.3)
	actor.hp = 0
	await advance(.02)
	assert(not art.haste_wind.visible, "Dead Null must not show Haste wind")
	print("Haste wind review: activation, expiry, concealment, reveal and death passed")
	stage.queue_free()
	await process_frame
	quit()
