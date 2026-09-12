extends "res://tools/mend_standing_preview.gd"
## Bake the approved standing study into a portable, mesh-free animation.
func _initialize() -> void: call_deferred("bake")

func bake() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(SOURCE,state) == OK)
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var rig: Skeleton3D = scene.find_children("*","Skeleton3D",true,false)[0]
	var source_player: AnimationPlayer = scene.find_children("*","AnimationPlayer",true,false)[0]
	source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var work := source_player.get_animation("Fixing_Kneeling")
	var idle := source_player.get_animation("Idle_Loop")
	var animation := Animation.new()
	animation.length = 125.0/24.0
	animation.loop_mode = Animation.LOOP_LINEAR
	for bone in rig.get_bone_count():
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
			var track := animation.add_track(type)
			animation.track_set_path(track,NodePath("Skeleton3D:"+rig.get_bone_name(bone)))
	var frames := ceili(animation.length*30)
	for frame in frames+1:
		var time := minf(frame/30.0,animation.length)
		var phase := fmod(time/animation.length,1.0)
		sample_source(rig,idle,fmod(phase*2.0,1.0)*idle.length)
		var base: Array = []
		for bone in rig.get_bone_count(): base.append(rig.get_bone_pose(bone))
		sample_source(rig,work,minf(phase*animation.length,work.length))
		stand_up(rig,base)
		look_at_hands(rig)
		for bone in rig.get_bone_count():
			animation.position_track_insert_key(bone*3,time,rig.get_bone_pose_position(bone))
			animation.rotation_track_insert_key(bone*3+1,time,rig.get_bone_pose_rotation(bone))
			animation.scale_track_insert_key(bone*3+2,time,rig.get_bone_pose_scale(bone))
	var library := AnimationLibrary.new()
	library.add_animation("Mend",animation)
	assert(ResourceSaver.save(library,"res://assets/animations/outlaw_mend.tres") == OK)
	print("OUTLAW_MEND_BAKED bones=",rig.get_bone_count()," length=",animation.length," frames=",frames+1)
	scene.free()
	quit()
