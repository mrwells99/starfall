extends SceneTree
## Render the actual Null against a striped backdrop through repeated Stealth
## cycles. Also runs headless for material binding and observer regressions.
var failures:=0
var checks:=0
var actor
var enemy
var art
var rendered:=false
var output:="res://artifacts/null-visibility-fix"
var worst_frame_ms:=0.0

func _initialize() -> void: call_deferred("run")

func ck(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)

func advance(seconds: float) -> void:
	for frame in ceili(seconds*60):
		var start:=Time.get_ticks_usec()
		art.animate(actor.champion_model,1.0/60,actor)
		if rendered: await RenderingServer.frame_post_draw
		worst_frame_ms=maxf(worst_frame_ms,(Time.get_ticks_usec()-start)/1000.0)

func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")

func solid_bindings() -> bool:
	for binding in art.stealth_surfaces:
		var material: Material=binding.mesh.get_active_material(binding.surface)
		if material!=art.solid_materials[binding.index] or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	return art.model.visible and art.last_alpha==1.0

func run() -> void:
	rendered=DisplayServer.get_name()!="headless"
	if rendered:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_size(Vector2i(720,720))
		DisplayServer.window_set_current_screen(0)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(50,60))
		Engine.max_fps=60
		DirAccess.make_dir_recursive_absolute(output)
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("46686e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.8;stage.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);stage.add_child(light)
	for i in 12:
		var stripe:=MeshInstance3D.new();stripe.mesh=BoxMesh.new();stripe.mesh.size=Vector3(.3,4,.05)
		stripe.position=Vector3((i-5.5)*.3,1,1)
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color("e8ba61") if i%2==0 else Color("46686e")
		stripe.material_override=mat;stage.add_child(stripe)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,1.2,-4.5)
	camera.look_at(Vector3(0,1,0));camera.current=true
	actor=load("res://scripts/combatant.gd").new();stage.add_child(actor);actor.setup(1,1,0,"Null")
	actor.presentation_grounded=true;actor.health_pivot.hide()
	art=actor.champion_model.null_art
	enemy=load("res://scripts/combatant.gd").new();stage.add_child(enemy);enemy.setup(2,2,1,"Ember",false)
	enemy.position=Vector3(10,0,0)
	var fade=load("res://scripts/camera_character_fade.gd").new()
	fade.update(actor)
	ck(art.shadow_casters.size() > 0 and actor.champion_model.find_child("NullStealthGroundShadow",true,false) == null,"Animated model shadows replace the circular ground blob")
	ck(art.shadow_material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED,"Camera costume fading leaves the shadow material alone")
	for caster in art.shadow_casters:
		ck(caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and caster.skin == caster.get_parent().skin and caster.get_node(caster.skeleton) == art.skeleton,"Shadow shares the visible mesh's skin and live skeleton")
	ck(art.stealth_material_warmup!=null and art.stealth_material_warmup.get_child_count()==art.stealth_surfaces.size(),"Transparent Stealth material pipeline is prewarmed before first cast")
	art.visibility_for(actor,actor);await advance(.5)
	ck(solid_bindings(),"Spawn renders solid with camera fade installed")
	ck(art.shadow_material.albedo_color.a==1.0,"Spawn has a full-strength shadow")
	await capture("spawn-solid")
	worst_frame_ms=0
	var fade_ids: Array=[]
	for material in art.fade_materials: fade_ids.append(material.get_instance_id())
	for cycle in 3:
		actor.identity.stealth=true;art.visibility_for(actor,actor)
		await advance(.2)
		ck(art.last_alpha>.5 and art.last_alpha<1,"Self fade has a gradual midpoint")
		ck(art.shadow_alpha>0 and is_equal_approx(art.shadow_material.albedo_color.a,2.0*art.last_alpha-1.0),"Owner's shadow fades toward zero over the same duration as the body fade")
		await advance(.30)
		ck(is_equal_approx(art.last_alpha,.5),"Self Stealth reaches half opacity")
		ck(art.shadow_material.albedo_color.a==0.0,"Self Stealth reaches exactly zero shadow")
		actor.flash=.2;await advance(.02)
		var flash_alpha:=true
		for material in art.materials: flash_alpha=flash_alpha and is_equal_approx(material.albedo_color.a,.5)
		ck(flash_alpha,"Tint update cannot overwrite Stealth alpha")
		actor.flash=0;await advance(.02)
		if cycle==0: await capture("self-stealth")
		actor.identity.stealth=false;art.visibility_for(actor,actor);await advance(.2)
		ck(art.last_alpha>.5 and art.last_alpha<1,"Toggle-off reveal stays gradual at 0.2 seconds")
		ck(art.shadow_alpha>0 and art.shadow_alpha<1 and is_equal_approx(art.shadow_material.albedo_color.a,2.0*art.last_alpha-1.0),"Owner's shadow fades back from zero smoothly during reveal")
		await advance(.35)
		ck(solid_bindings(),"Toggle off restores exact original solid materials")
		ck(art.shadow_material.albedo_color.a==1.0,"Toggle off restores full shadow strength")
		if cycle==0: await capture("revealed-solid")
		actor.identity.stealth=true;art.visibility_for(actor,enemy);await advance(.2)
		ck(art.last_alpha>0 and art.last_alpha<1 and art.model.visible,"Enemy fade remains gradual")
		ck(is_equal_approx(art.shadow_material.albedo_color.a,art.last_alpha),"Animated shadow follows the enemy fade midpoint")
		await advance(.30);ck(not art.model.visible,"Undetected enemy sees fully hidden Null")
		actor.identity.stealth=false;art.visibility_for(actor,enemy);await advance(.2)
		ck(art.last_alpha>0 and art.last_alpha<1,"Enemy reveal stays gradual at 0.2 seconds")
		ck(is_equal_approx(art.shadow_material.albedo_color.a,art.last_alpha),"Animated shadow follows the enemy reveal midpoint")
		await advance(.35)
		ck(solid_bindings(),"Enemy reveal restores solid material bindings")
	# Toggling early reverses from the current shadow strength without a snap.
	actor.identity.stealth=true;art.visibility_for(actor,actor);await advance(.2)
	var interrupted_alpha: float=art.shadow_alpha
	actor.identity.stealth=false;art.visibility_for(actor,actor);art.animate(actor.champion_model,0,actor)
	ck(is_equal_approx(art.shadow_alpha,interrupted_alpha),"Interrupted entry preserves shadow strength at the toggle")
	await advance(.2)
	ck(art.shadow_alpha>interrupted_alpha and art.shadow_alpha<1,"Interrupted entry smoothly reverses into reveal")
	await advance(.35)
	ck(art.shadow_material.albedo_color.a==1.0,"Interrupted entry finishes at full shadow strength")
	var retained:=true
	for i in fade_ids.size(): retained=retained and fade_ids[i]==art.fade_materials[i].get_instance_id()
	ck(retained,"Repeated transitions reuse retained fade resources")
	fade.reset()
	var restored:=true
	for variants in [art.solid_materials,art.fade_materials]:
		for material in variants: restored=restored and material.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED
	ck(restored,"Stopping camera follow restores both material variants")
	print("Null visibility checks: %d passed / %d total; largest transition frame %.2f ms" % [checks-failures,checks,worst_frame_ms])
	stage.queue_free();await process_frame;quit(1 if failures else 0)
