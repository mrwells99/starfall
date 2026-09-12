extends SceneTree
var actor
var art

func _initialize() -> void: call_deferred("run")

func advance(seconds: float) -> void:
	for i in ceili(seconds * 60):
		art.animate(actor.champion_model, 1.0 / 60, actor)
		await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	root.get_texture().get_image().save_png("res://artifacts/null-regen/" + label + ".png")

func run() -> void:
	root.size = Vector2i(960,720)
	Engine.max_fps = 60
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202936")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40,40)
	floor_mesh.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("303641")
	floor_mesh.material_override = stone
	stage.add_child(floor_mesh)
	actor = load("res://scripts/combatant.gd").new()
	stage.add_child(actor)
	actor.setup(1,1,0,"Null")
	actor.presentation_grounded = true
	actor.health_pivot.hide()
	art = actor.champion_model.null_art
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.7,1.9,-4.0)
	camera.look_at(Vector3(0,1,0))
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://artifacts/null-regen")
	await advance(.2)
	assert(not art.regen_effect.visible, "No regeneration visuals at spawn")
	capture("inactive")
	actor.identity.null_regen = {"left":6.0}
	art.visibility_for(actor,actor)
	await advance(1.5)
	assert(art.regen_effect.visible and art.regen_effect.light.light_energy > 0, "Regen activates crosses and glow")
	capture("active")
	for mote in art.regen_effect.motes:
		assert(Vector2(mote.sprite.position.x,mote.sprite.position.z).length() <= .71, "Crosses stay close to the player")
	var mote: Dictionary = art.regen_effect.motes[-1]
	var start_y: float = mote.sprite.position.y
	var start_alpha: float = mote.material.albedo_color.a
	await advance(.3)
	assert(mote.sprite.position.y > start_y and mote.material.albedo_color.a > start_alpha, "New cross rises while gradually fading in")
	capture("rising")
	var opponent = load("res://scripts/combatant.gd").new()
	stage.add_child(opponent)
	opponent.setup(2,2,1,"Ember",false)
	actor.identity.stealth = true
	art.visibility_for(actor,opponent)
	assert(not art.regen_effect.visible and art.regen_effect.light.light_energy == 0, "Stealth immediately hides crosses and light from opponents")
	await advance(.6)
	capture("hidden")
	art.visibility_for(actor,actor)
	await advance(.6)
	assert(art.regen_effect.visible, "Owner retains regeneration visuals while stealthed")
	actor.identity.null_regen = {}
	await advance(.7)
	assert(not art.regen_effect.visible and art.regen_effect.light.light_energy == 0, "Effect fades away when regeneration expires")
	print("Regen visuals: activation, bounded drift, gradual rise/fade, Stealth visibility and expiry passed")
	stage.queue_free()
	await process_frame
	quit()
