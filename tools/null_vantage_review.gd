extends "res://tools/hitbox_review.gd"
## Reproducible actual-runtime front/side phase review, not a rebuilt model.
var caption: Label
var old_version := false

func run() -> void:
	old_version="--before" in OS.get_cmdline_user_args()
	output="res://artifacts/null-vantage-20260912/"+("before-review/" if old_version else "review/")
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps=30
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1000,700));root.content_scale_size=Vector2i(1000,700)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(30,40))
	print("VANTAGE_REVIEW screen=",DisplayServer.window_get_current_screen()," primary=",DisplayServer.get_primary_screen())
	stage=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("171c29")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c5d1e7");environment.environment.ambient_light_energy=.8
	stage.add_child(environment)
	for i in 2:
		var light:=DirectionalLight3D.new();stage.add_child(light)
		light.rotation_degrees=Vector3(-35,-30 if i==0 else 150,0);light.light_energy=1.5 if i==0 else .7
	camera=Camera3D.new();stage.add_child(camera);camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.4
	camera.position=Vector3(0,1.0,-7);camera.look_at(Vector3(0,1.0,0))
	var layer:=CanvasLayer.new();stage.add_child(layer)
	caption=Label.new();layer.add_child(caption);caption.position=Vector2(25,20);caption.add_theme_font_size_override("font_size",24)
	var sheet:=Image.create(2000,840,false,Image.FORMAT_RGB8)
	var samples: Array=[["Idle",-1.0],["Lift",.18],["Gather",.36],["Tip forward",.49],["Dive entry",.55],["Dive",.68],["Dive late",.82],["Recover",.92]]
	for index in samples.size():
		make_pair()
		for actor in actors:
			for frame in 30: actor.champion_model.animate(1.0/60,actor)
		if index==0:
			var art=actors[0].champion_model.null_art
			for bone in ["DEF-hips","DEF-spine.002","DEF-upper_arm.L","DEF-forearm.L","DEF-hand.L","DEF-upper_arm.R","DEF-hand.R"]:
				var id: int=art.skeleton.find_bone(bone)
				print(bone," local/global=",art.skeleton.get_bone_global_pose(id))
		else:
			var t:=0.0
			while t<float(samples[index][1])-.000001:
				var dt:=minf(1.0/60,float(samples[index][1])-t);t+=dt
				for actor in actors: apply_frame(actor,t,dt)
		caption.text="VANTAGE POINT  /  "+samples[index][0].to_upper()+"     FRONT + SIDE"
		await RenderingServer.frame_post_draw
		var picture:=root.get_texture().get_image()
		picture.save_png(output+"pose-%d.png"%index)
		picture.convert(Image.FORMAT_RGB8)
		picture.resize(500,350,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(picture,Rect2i(0,0,500,350),Vector2i(index%4*500,index/4*420))
		for actor in actors:actor.body_hitboxes.update();draw_body(actor)
		await capture("hitboxes-%d"%index)
	sheet.save_png(output+"sequence.png")
	print("NULL_VANTAGE_REVIEW_CAPTURED")
	stage.free();await process_frame;quit()

func make_pair() -> void:
	for actor in actors:actor.free()
	actors.clear()
	if overlay!=null:overlay.free()
	overlay=Node3D.new();stage.add_child(overlay)
	for side in 2:
		var actor=load("res://scripts/combatant.gd").new();stage.add_child(actor);actor.setup(side+1,1,0,"Null")
		actor.set_process(false);actor.set_physics_process(false)
		actor.position.x=1.05 if side==0 else -1.05
		actor.rotation.y=0 if side==0 else PI*.5
		actor.presentation_grounded=true
		for decoration in [actor.health_pivot,actor.team_marker,actor.nameplate]:
			if is_instance_valid(decoration):decoration.hide()
		actor.setup_hitboxes();actors.append(actor)

func apply_frame(actor,t: float,delta: float) -> void:
	var phase: String="lift" if t<.5 else ("dive" if t<.85 else "recover")
	var elapsed: float=t if phase=="lift" else t-(.5 if phase=="dive" else .85)
	var direction:=Vector3(0,-.6,-.8)
	actor.identity.null_vantage={"phase":phase,"elapsed":elapsed,"direction":Vector3.UP if phase=="lift" else direction}
	actor.presentation_grounded=phase=="recover"
	actor.presentation_vertical_speed=(16.0-24.0*t) if phase=="lift" else (-15.0 if phase=="dive" else 0.0)
	actor.velocity.y=actor.presentation_vertical_speed
	actor.champion_model.animate(delta,actor)
