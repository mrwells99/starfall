extends "res://scripts/null_living_blend.gd"
## Fulcrum's existing independent orb attachment around the approved shared body.
var hand := -1
var focus := -1
var carry_offset := Vector3.ZERO
var from_weapon_offset := Vector3.ZERO
var movement_target := false

func build(rig:Skeleton3D) -> void:
	super.build(rig)
	hand=rig.find_bone("DEF-hand.L")
	focus=rig.find_bone("gravity.focus")
	assert(hand>=0 and focus>=0)
	carry_offset=rig.get_bone_global_pose(focus).origin-rig.get_bone_global_pose(hand).origin
	from_weapon_offset=carry_offset

func begin(seconds:float,body_seconds:float=0.0) -> void:
	from_weapon_offset=skeleton.get_bone_global_pose(focus).origin-skeleton.get_bone_global_pose(hand).origin
	super.begin(seconds,body_seconds)

func apply(delta:float) -> void:
	var target_offset:Vector3=carry_offset if movement_target else skeleton.get_bone_global_pose(focus).origin-skeleton.get_bone_global_pose(hand).origin
	var blending:=duration>0.0 and elapsed<body_duration
	super.apply(delta)
	if not movement_target and not blending:return
	var progress:=clampf(elapsed/maxf(duration,.001),0.0,1.0)
	var weight:=progress*progress*(3.0-2.0*progress)
	var target:=skeleton.get_bone_global_pose(hand).origin+from_weapon_offset.lerp(target_offset,weight)
	var parent:=skeleton.get_bone_parent(focus)
	skeleton.set_bone_pose_position(focus,skeleton.get_bone_global_pose(parent).affine_inverse()*target if parent>=0 else target)
