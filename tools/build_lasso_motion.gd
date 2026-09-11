extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file("res://art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb",state) == OK)
	var scene := doc.generate_scene(state)
	root.add_child(scene)
	var player: AnimationPlayer
	var rig: Skeleton3D
	for node in scene.find_children("*","Node",true,false):
		if node is AnimationPlayer: player = node
		if node is Skeleton3D: rig = node
	assert(player != null and rig != null)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var data = load("res://scripts/lasso_motion_data.gd").new()
	for i in rig.get_bone_count(): data.bones.append(rig.get_bone_name(i))
	for name in ["Death01", "Roll", "Spell_Simple_Enter"]:
		var found := ""
		for candidate in player.get_animation_list():
			if String(candidate).get_slice("/", String(candidate).count("/")) == name: found = candidate
		assert(not found.is_empty())
		var animation := player.get_animation(found)
		animation.loop_mode = Animation.LOOP_NONE
		player.play(found)
		var frames: Array = []
		for i in ceili(animation.length * 30) + 1:
			player.seek(minf(animation.length, i / 30.0),true)
			var frame: Array[Transform3D] = []
			for b in rig.get_bone_count(): frame.append(rig.get_bone_pose(b))
			frames.append(frame)
		data.clips[name] = {"length":animation.length, "frames":frames}
		print(name, " ", animation.length, "s / ", frames.size(), " frames")
	assert(ResourceSaver.save(data,"res://assets/characters/lasso_motion.tres") == OK)
	print("LASSO_MOTION_BUILT ", data.bones.size(), " native bones")
	quit()
