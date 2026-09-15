extends RefCounted
## Fixed native fist grip; weapons are already children of their correct hands.
var skeleton: Skeleton3D
var grip: Dictionary = {}
var aim: Dictionary = {}
var knife_frames: Array[Dictionary] = []
var gun_frames: Array[Dictionary] = []
var shot_time := -1.0
var aim_weight := 0.0
var knife_weight := 0.0
var knife_time := 0.0
var handwork_weight := 0.0
var weapon_scales: Dictionary = {}

func build(_title: String, rig: Skeleton3D) -> void:
	skeleton = rig
	for i in rig.get_bone_count():
		var name := rig.get_bone_name(i)
		if name.begins_with("DEF-f_") or name.begins_with("DEF-thumb"):
			grip[i] = rig.get_bone_pose_rotation(i)
	assert(rig.find_bone("outlaw.gun") >= 0 and rig.find_bone("outlaw.knife") >= 0)
	for name in ["outlaw.gun","outlaw.knife"]:
		var bone := rig.find_bone(name)
		weapon_scales[bone] = rig.get_bone_pose_scale(bone)

func capture() -> void: pass
func follow_jump() -> void: pass

func apply() -> void:
	for i in aim:
		var desired: Quaternion = aim[i]
		if shot_time >= 0 and not gun_frames.is_empty():
			var frame := clampf(shot_time*30.0,0.0,float(gun_frames.size()-1))
			var first := floori(frame)
			desired = gun_frames[first][i].normalized().slerp(gun_frames[mini(first+1,gun_frames.size()-1)][i].normalized(),frame-first).normalized()
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(desired, aim_weight))
	if not knife_frames.is_empty() and knife_weight > 0:
		# Follow the native keys continuously instead of holding/jumping at 30 Hz.
		# Authored action paths and timing remain intact.
		var frame:=clampf(knife_time*30.0,0.0,float(knife_frames.size()-1))
		var first:=floori(frame)
		var second:=mini(first+1,knife_frames.size()-1)
		var sample:Dictionary=knife_frames[first]
		for i in sample:
			var desired:Quaternion=sample[i].normalized().slerp(knife_frames[second][i].normalized(),frame-first).normalized()
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(desired, knife_weight))
	for i in grip: skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(grip[i],1.0-handwork_weight))
	# Free the hands for Mend, restoring the existing weapons/grips on exit.
	for i in weapon_scales: skeleton.set_bone_pose_scale(i,weapon_scales[i]*(1.0-.999*handwork_weight))
