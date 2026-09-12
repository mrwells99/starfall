extends SceneTree
## Actual model and damage-volume renders; no generated concept art.
const Bodies = preload("res://scripts/body_hitboxes.gd")
var stage: Node3D
var camera: Camera3D
var heading: Label
var actors := []
var overlay: Node3D
var view_labels := []
var legend: Label
var expanded := false
var null_only := false
var output := "res://artifacts/aimed-combat/review/"

func _initialize() -> void: call_deferred("run")

func capsule(parent: Node3D, start: Vector3, end: Vector3, radius: float, head: bool) -> void:
	var item := MeshInstance3D.new()
	var mesh := CapsuleMesh.new(); mesh.radius = radius; mesh.height = start.distance_to(end)+radius*2; mesh.radial_segments = 16; mesh.rings = 4
	item.mesh = mesh; item.position = (start+end)*.5
	if start.distance_squared_to(end) > .000001: item.basis = Basis(Quaternion(Vector3.UP,(end-start).normalized()))
	var color := Color("ffc878") if head else Color("53ecdf")
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.no_depth_test = true; mat.albedo_color = Color(color,.12)
	item.material_override = mat; item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	var lines := ImmediateMesh.new(); lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := start.distance_to(end)*.5
	for ring_y in [-half,half]:
		for i in 32:
			for a in [TAU*i/32.0,TAU*(i+1)/32.0]: lines.surface_add_vertex(Vector3(cos(a)*radius,ring_y,sin(a)*radius))
	for azimuth in [0.0,PI*.5,PI,PI*1.5]:
		var lateral := Vector3(cos(azimuth),0,sin(azimuth))
		lines.surface_add_vertex(lateral*radius+Vector3.UP*half); lines.surface_add_vertex(lateral*radius-Vector3.UP*half)
		for sign_y in [-1,1]:
			for i in 8:
				for angle in [PI*.5*i/8.0,PI*.5*(i+1)/8.0]:
					lines.surface_add_vertex(lateral*radius*cos(angle)+Vector3.UP*sign_y*(half+radius*sin(angle)))
	lines.surface_end()
	var wire := MeshInstance3D.new(); wire.mesh = lines
	var wire_mat := StandardMaterial3D.new(); wire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; wire_mat.no_depth_test = true; wire_mat.albedo_color = Color(color,.75); wire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wire.material_override = wire_mat; wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.add_child(wire)

func run() -> void:
	expanded = "--aim-expanded" in OS.get_cmdline_user_args()
	null_only = "--class=null" in OS.get_cmdline_user_args()
	if null_only: output="res://artifacts/null-forge-v2/review/"
	if expanded: output = "res://artifacts/outlaw-balance-trinket-hitboxes/review/"
	Engine.max_fps = 30
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	root.content_scale_size = Vector2i(1600,1000)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(100,35))
	DisplayServer.window_set_title("Starfall · body hitbox review")
	stage = Node3D.new(); root.add_child(stage)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("101824")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color("c5d1e7"); environment.environment.ambient_light_energy = .75
	stage.add_child(environment)
	for i in 2:
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-25,-30 if i == 0 else 150,0); light.light_energy = 1.5 if i == 0 else .65; stage.add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 2.95; camera.position = Vector3(0,1.1,-7); stage.add_child(camera); camera.look_at(Vector3(0,1.1,0)); camera.current = true
	var ui := CanvasLayer.new(); stage.add_child(ui)
	heading = Label.new(); heading.position = Vector2(45,28); heading.add_theme_font_size_override("font_size",34); ui.add_child(heading)
	var subtitle := Label.new(); subtitle.position = Vector2(45,78); subtitle.text = "BODY HITBOXES  /  19 padded capsules  /  weapons & flowing cloth excluded"; subtitle.add_theme_color_override("font_color",Color("9eafc8")); ui.add_child(subtitle)
	for side in 2:
		var label := Label.new(); label.position = Vector2(400+side*790,132); label.text = "FRONT" if side == 0 else "SIDE"; label.add_theme_font_size_override("font_size",20); ui.add_child(label)
		view_labels.append(label)
	legend = Label.new(); legend.position = Vector2(45,914); legend.text = "CYAN · body      GOLD · head (same damage)\nOverlay is visible through clothing to show the actual volumes."; legend.add_theme_font_size_override("font_size",19); ui.add_child(legend)
	if expanded:
		camera.size = 3.7
		subtitle.text = "AIMING VOLUMES  /  2x horizontal width and depth  /  1.25x height"
		legend.text = "CYAN · body      GOLD · head (same damage)\nOnly aimed damage volumes are enlarged; character size and movement collision stay the same."
	DirAccess.make_dir_recursive_absolute(output)
	for title in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw","Null"]:
		if null_only and title!="Null":continue
		await show_class(title,"idle")
		await capture(title.to_lower())
	if null_only:
		for pose in ["stealth","lift","dive","recover","stab"]:
			await show_class("Null",pose); await capture("null-"+pose)
		await show_class("Null","idle"); overlay.hide()
		subtitle.text="MODEL FORGE V2  /  twin sentient blades  /  charcoal, black and silver"
		legend.text="Actual runtime model. Use the separate body-hitbox views to inspect damage volumes."
		await capture("null-model")
		print("NULL_REVIEW_CAPTURED 7 images");quit();return
	await show_class("Outlaw","roll"); await capture("outlaw-roll")
	await show_class("Outlaw","backflip"); await capture("outlaw-backflip")
	await overview(ui); await capture("all-classes")
	print("HITBOX_REVIEW_CAPTURED 8 images")
	quit()

func show_class(title: String, pose: String) -> void:
	if expanded: camera.size = 4.2 if pose != "idle" else 3.7
	for actor in actors: actor.free()
	actors.clear()
	if overlay != null: overlay.free()
	overlay = Node3D.new(); stage.add_child(overlay)
	heading.text = title.to_upper()+"  /  "+pose.to_upper()
	for side in 2:
		var actor = load("res://scripts/combatant.gd").new(); stage.add_child(actor); actor.setup(side+1,1,0,title)
		actor.position.x = (1.5 if expanded else 1.03) * (1 if side == 0 else -1)
		actor.rotation.y = 0 if side == 0 else PI*.5
		actor.health_pivot.hide(); actor.team_marker.hide(); actor.presentation_grounded = true
		actors.append(actor)
		for i in 24: actor.champion_model.animate(1.0/60,actor)
		if title=="Null" and pose!="idle":
			for i in (6 if pose=="recover" else (15 if pose=="stab" else 30)):
				actor.identity.stealth=pose=="stealth"
				if pose=="stealth":actor.position.z-=2.0/60
				if pose in ["lift","dive","recover"]:
					actor.identity.null_vantage={"phase":pose,"elapsed":i/60.0,"direction":Vector3(0,-1,-1).normalized()}
					actor.presentation_grounded=false;actor.presentation_vertical_speed=10 if pose=="lift" else -12
				if pose=="stab" and i==1:actor.identity.null_action="stab";actor.identity.null_action_serial+=1
				actor.champion_model.animate(1.0/60,actor)
			actor.position.z=0
		elif pose != "idle":
			actor.identity.roll_direction = -actor.basis.z
			for i in (37 if pose == "backflip" else 17):
				actor.identity.roll_left = maxf(0,preload("res://scripts/outlaw_mechanics.gd").ROLL_SECONDS-float(i)/60) if pose == "roll" else 0
				actor.identity.backflip_active = pose == "backflip"
				actor.identity.backflip_elapsed = float(i)/60
				actor.presentation_grounded = pose != "backflip"; actor.velocity.y = 12-float(i)/3; actor.presentation_vertical_speed = actor.velocity.y
				actor.champion_model.animate(1.0/60,actor)
			actor.position.y = .65
		actor.setup_hitboxes(); actor.body_hitboxes.update()
		draw_body(actor)
	await process_frame

func capture(title: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+title+".png")

func draw_body(actor) -> void:
	var group := Node3D.new(); overlay.add_child(group)
	for i in Bodies.PARTS.size(): capsule(group,actor.body_hitboxes.points[i*2],actor.body_hitboxes.points[i*2+1],actor.body_hitboxes.radii[i],i == 4)
	if expanded: group.transform = Transform3D(Basis.from_scale(Bodies.AIM_SCALE), actor.position-actor.position*Bodies.AIM_SCALE)

func overview(ui: CanvasLayer) -> void:
	for actor in actors: actor.free()
	actors.clear(); overlay.free(); overlay = Node3D.new(); stage.add_child(overlay)
	for label in view_labels: label.hide()
	DisplayServer.window_set_size(Vector2i(1800,850)); root.content_scale_size = Vector2i(1800,850)
	heading.text = "STARFALL  /  EXPANDED AIMING HITBOXES" if expanded else "STARFALL  /  MAIN-BODY HITBOX FIT"
	legend.position.y = 776
	camera.size = 4.8 if expanded else 3.05
	for index in 6:
		var title: String = ["Ember","Luminary","Fulcrum","Vanguard","Outlaw","Null"][index]
		var actor = load("res://scripts/combatant.gd").new(); stage.add_child(actor); actor.setup(index+1,1,0,title)
		actor.position.x = (3.8-index*1.52) if expanded else (2.15-index*.86); actor.health_pivot.hide(); actor.team_marker.hide(); actor.presentation_grounded = true
		actors.append(actor)
		for frame in 24: actor.champion_model.animate(1.0/60,actor)
		actor.setup_hitboxes(); actor.body_hitboxes.update()
		draw_body(actor)
		var label := Label.new(); label.text = title.to_upper(); label.add_theme_font_size_override("font_size",21); label.position = Vector2(camera.unproject_position(actor.position).x-55,134); ui.add_child(label)
	await process_frame
