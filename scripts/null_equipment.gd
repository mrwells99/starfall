extends RefCounted
## Both blades follow their hand parents after all animation layers.
var skeleton: Skeleton3D
var grip := {}
func build(_title: String, rig: Skeleton3D) -> void:
	skeleton=rig
	for i in rig.get_bone_count():
		var name:=rig.get_bone_name(i)
		if name.begins_with("DEF-f_") or name.begins_with("DEF-thumb"):
			grip[i]=rig.get_bone_pose_rotation(i)
	for side in ["L","R"]: assert(rig.find_bone("null.blade."+side)>=0)
func capture() -> void: pass
func follow_jump() -> void: pass
func apply() -> void:
	for i in grip:skeleton.set_bone_pose_rotation(i,grip[i])
