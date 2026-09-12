extends SceneTree
var actor
var art
var output := "res://artifacts/null-shadow-vanish/"
func _initialize() -> void: call_deferred("run")
func advance(seconds: float) -> void:
	for frame in ceili(seconds*24):
		actor.champion_model.animate(1.0/24,actor)
		await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+label+".png") == OK)
func run() -> void:
	Engine.max_fps = 24
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(960,720))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,40))
	DisplayServer.window_set_title("Null · animated shadow / stealth review")
	root.content_scale_size = Vector2i(960,720)
	if "--compat" in OS.get_cmdline_user_args(): output += "compat/"
	else: output += "forward/"
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new(); root.add_child(stage)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8a929a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .3
	stage.add_child(env)
	var sun := DirectionalLight3D.new(); stage.add_child(sun)
	sun.rotation_degrees = Vector3(-42,-45,0); sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30; sun.light_energy = 1.2
	var fill := DirectionalLight3D.new(); stage.add_child(fill)
	fill.rotation_degrees = Vector3(-30,140,0); fill.light_energy = .7
	var ground := MeshInstance3D.new(); ground.mesh = PlaneMesh.new(); ground.mesh.size = Vector2(20,20)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("b8b9bf"); mat.roughness = 1
	ground.material_override = mat; stage.add_child(ground)
	var camera := Camera3D.new(); stage.add_child(camera)
	camera.fov = 35
	camera.position = Vector3(4,5,-6); camera.look_at(Vector3(.3,.5,.3)); camera.current = true
	actor = load("res://scripts/combatant.gd").new(); stage.add_child(actor); actor.setup(1,1,0,"Null")
	actor.presentation_grounded = true; actor.health_pivot.hide(); actor.team_marker.hide()
	art = actor.champion_model.null_art
	var fade = load("res://scripts/camera_character_fade.gd").new(); fade.update(actor)
	assert(art.shadow_casters.size() > 0)
	assert(art.shadow_material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED)
	for caster in art.shadow_casters:
		assert(caster.skin == caster.get_parent().skin)
		assert(caster.get_node(caster.skeleton) == art.skeleton)
	await advance(.5); await capture("solid")
	actor.identity.stealth = true; art.target_stealth_alpha = 0.0
	await advance(.25); await capture("fading-out")
	await advance(.35); await capture("hidden")
	actor.identity.stealth = false; art.target_stealth_alpha = 1.0
	await advance(.25); await capture("fading-in")
	await advance(.35); await capture("restored")
	actor.identity.stealth = true; art.target_stealth_alpha = .5
	await advance(.25); await capture("self-fading-out")
	await advance(.35); await capture("self-stealth")
	assert(art.shadow_material.albedo_color.a == 0.0)
	assert(is_equal_approx(art.stealth_alpha,.5))
	actor.identity.stealth = false; art.target_stealth_alpha = 1.0
	await advance(.25); await capture("self-fading-in")
	await advance(.35); await capture("self-restored")
	assert(art.shadow_material.albedo_color.a == 1.0)
	print("NULL_ANIMATED_SHADOW_REVIEW_PASSED casters=",art.shadow_casters.size()," output=",output)
	fade.reset(); stage.free(); quit()
