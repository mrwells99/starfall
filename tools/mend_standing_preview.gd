extends SceneTree
## Isolated study: original hand-work over a standing base. No game installation.
const SOURCE := "res://art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb"
const OUTPUT := "res://artifacts/mend-standing-preview/"
const LIVING_OUTPUT := "res://artifacts/mend-standing-living-preview/"
var players: Array[AnimationPlayer] = []
var rigs: Array[Skeleton3D] = []
var standing: Array = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var living := "--living" in OS.get_cmdline_user_args()
	var output := LIVING_OUTPUT if living else OUTPUT
	Engine.max_fps = 24
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(960,600))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(40,40))
	DisplayServer.window_set_title("Mend study · standing hand-work · preview only")
	root.content_scale_size = Vector2i(960,600)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(SOURCE,state) == OK)
	for i in 2:
		var container := SubViewportContainer.new()
		container.position = Vector2(i*480,0)
		container.size = Vector2(480,600)
		root.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(480,600)
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
		# Each import gets its own state; generation mutates glTF bone-name mappings.
		var panel_state := GLTFState.new()
		assert(document.append_from_file(SOURCE,panel_state) == OK)
		var actor := document.generate_scene(panel_state)
		stage.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		var rig: Skeleton3D = actor.find_children("*","Skeleton3D",true,false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("Idle_Loop")
		player.advance(0)
		var base: Array[Transform3D] = []
		for bone in rig.get_bone_count(): base.append(rig.get_bone_pose(bone))
		standing.append(base)
		player.get_animation("Fixing_Kneeling").loop_mode = Animation.LOOP_LINEAR
		player.play("Fixing_Kneeling")
		players.append(player)
		rigs.append(rig)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(1.8,1.5,3.8) if i == 0 else Vector3(4.2,1.45,.3)
		camera.fov = 30
		camera.look_at(Vector3(0,.95,0))
		camera.current = true
		var label := Label.new()
		label.position = container.position+Vector2(20,18)
		label.text = "Standing hand-work · front" if i == 0 else "Standing hand-work · side"
		label.add_theme_font_size_override("font_size",21)
		root.add_child(label)
	var note := Label.new()
	note.position = Vector2(20,564)
	note.text = "Hand-work + breathing idle + downward gaze · Preview only — Mend unchanged" if living else "Fixing_Kneeling hands + standing stance · Preview only — Mend unchanged"
	root.add_child(note)
	assert(DirAccess.make_dir_recursive_absolute(output+"frames") == OK)
	var capture_count := 125
	if "--still" in OS.get_cmdline_user_args(): capture_count = 1
	for frame in capture_count:
		for i in 2:
			if living:
				# Two idle breathing cycles per hand-work loop, so the preview loops cleanly.
				var idle := players[i].get_animation("Idle_Loop")
				sample_source(rigs[i],idle,fmod(frame/125.0*2.0,1.0)*idle.length)
				for bone in rigs[i].get_bone_count(): standing[i][bone] = rigs[i].get_bone_pose(bone)
			sample_source(rigs[i],players[i].get_animation("Fixing_Kneeling"),frame/24.0)
			stand_up(rigs[i],standing[i])
			if living: look_at_hands(rigs[i])
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+"frames/%04d.png" % frame) == OK)
	print("MEND_STANDING_PREVIEW_CAPTURED ",capture_count," frames; production assets unchanged")
	quit()

func look_at_hands(rig: Skeleton3D) -> void:
	# Spread the downward gaze across neck/head while retaining idle motion.
	for name in ["DEF-neck","DEF-head"]:
		var bone := rig.find_bone(name)
		assert(bone >= 0)
		var parent := rig.get_bone_parent(bone)
		var parent_rotation := rig.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var pitch := Quaternion(Vector3.RIGHT,deg_to_rad(12 if name == "DEF-neck" else 18))
		rig.set_bone_pose_rotation(bone,parent_rotation.inverse()*pitch*parent_rotation*rig.get_bone_pose_rotation(bone))

func sample_source(rig: Skeleton3D, clip: Animation, time: float) -> void:
	# Explicit sampling also restores constant tracks before each additive edit;
	# AnimationPlayer can otherwise cache them and accumulate the arm correction.
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := rig.find_bone(path.get_subname(0))
		if bone < 0: continue
		match clip.track_get_type(track):
			Animation.TYPE_POSITION_3D: rig.set_bone_pose_position(bone,clip.position_track_interpolate(track,time))
			Animation.TYPE_ROTATION_3D: rig.set_bone_pose_rotation(bone,clip.rotation_track_interpolate(track,time))
			Animation.TYPE_SCALE_3D: rig.set_bone_pose_scale(bone,clip.scale_track_interpolate(track,time))

func stand_up(rig: Skeleton3D, base: Array) -> void:
	# Keep the authored shoulder/arm/hand/finger rhythm, replace kneeling legs,
	# pelvis and spine with the unmodified standing pose. No rest-bone edits.
	for bone in rig.get_bone_count():
		var name := String(rig.get_bone_name(bone))
		var arm := name.contains("shoulder") or name.contains("upper_arm") or name.contains("forearm") or name.contains("hand") or name.contains("thumb") or name.contains("f_index") or name.contains("f_middle") or name.contains("f_ring") or name.contains("f_pinky")
		if not arm:
			rig.set_bone_pose(bone,base[bone])
	# Re-angle the original asymmetric hand-work around a shared waist-high
	# work area now that the chest is upright rather than leaning over a knee.
	for side in ["L","R"]:
		var bone := rig.find_bone("DEF-upper_arm."+side)
		assert(bone >= 0)
		var parent := rig.get_bone_parent(bone)
		var parent_rotation := rig.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var inward := Quaternion(Vector3.BACK,deg_to_rad(-10 if side == "L" else 10))
		var lift := Quaternion(Vector3.RIGHT,deg_to_rad(37 if side == "L" else 5))*inward
		rig.set_bone_pose_rotation(bone,parent_rotation.inverse()*lift*parent_rotation*rig.get_bone_pose_rotation(bone))
