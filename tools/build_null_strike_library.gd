extends SceneTree
## Extract only upper-body pose curves from the supplied CC0 animation library.
const SOURCE := "res://art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb"
const BONES := ["DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head", "DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L", "DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(SOURCE, state) == OK)
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var rig: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	print("Library clips: ", player.get_animation_list())
	var library := AnimationLibrary.new()
	for source in ["Punch_Jab", "Sword_Attack"]:
		var name := ""
		for candidate in player.get_animation_list():
			if String(candidate).get_slice("/", String(candidate).count("/")) == source: name = candidate
		assert(not name.is_empty())
		var animation := Animation.new()
		animation.length = player.get_animation(name).length
		for bone in BONES:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("Skeleton3D:" + bone))
		player.play(name)
		for frame in ceili(animation.length * 60) + 1:
			var time := minf(animation.length, frame / 60.0)
			player.seek(time, true)
			for i in BONES.size():
				var bone := rig.find_bone(BONES[i])
				# Shoulder orientations are stored in skeleton space so an upper-body
				# transplant keeps the original strike direction without its hip turn.
				var rotation := rig.get_bone_global_pose(bone).basis.get_rotation_quaternion() if BONES[i].begins_with("DEF-shoulder") else rig.get_bone_pose_rotation(bone)
				animation.rotation_track_insert_key(i, time, rotation)
		library.add_animation(source, animation)
		print(source, " duration: ", animation.length)
	DirAccess.make_dir_recursive_absolute("res://assets/animations")
	assert(ResourceSaver.save(library, "res://assets/animations/null_strikes_v3.tres") == OK)
	scene.queue_free()
	await process_frame
	print("NULL_STRIKE_LIBRARY_EXTRACTED")
	quit()
