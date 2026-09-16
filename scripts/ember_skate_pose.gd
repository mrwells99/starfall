extends RefCounted
## Reversible local pose layer shared by visible and compact server rigs.
## A small hop compresses into an alternating push/glide, with smooth release.
var rig: Skeleton3D
var previous: Dictionary = {}
var weight := 0.0
var clock = preload("res://scripts/snapshot_animation_clock.gd").new()
var serial := -1
var age := 0.0
var base: Dictionary = {}

func build(skeleton: Skeleton3D) -> void:
	rig = skeleton
	for name in ["DEF-hips","DEF-spine.001","DEF-spine.002","DEF-thigh.L","DEF-thigh.R","DEF-shin.L","DEF-shin.R","DEF-foot.L","DEF-foot.R","DEF-upper_arm.L","DEF-upper_arm.R","DEF-forearm.L","DEF-forearm.R"]:
		var bone := rig.find_bone(name)
		if bone >= 0: base[bone] = rig.get_bone_rest(bone).basis.get_rotation_quaternion()

func restore() -> void:
	for bone in previous: rig.set_bone_pose(bone,previous[bone])
	previous.clear()

func rotate(name: String, degrees: Vector3, amount: float) -> void:
	var bone := rig.find_bone(name)
	if bone < 0: return
	if not previous.has(bone): previous[bone] = rig.get_bone_pose(bone)
	var target: Quaternion = base.get(bone,Quaternion.IDENTITY) * Quaternion.from_euler(degrees*PI/180.0)
	rig.set_bone_pose_rotation(bone,rig.get_bone_pose_rotation(bone).slerp(target,amount))

func apply(actor, delta: float) -> void:
	var left := float(actor.identity.get("cinder_left",0.0))
	var active: bool = actor.hp>0 and left>0 and actor.stunned<=0 and int(actor.identity.get("ash_phase",0))==0
	var current := int(actor.identity.get("cinder_serial",0))
	if current != serial:
		serial=current; clock.reset()
	if active: age=clock.advance(3.0-left,delta,actor.presentation_snapshot_serial,current,3.0)
	weight=move_toward(weight,1.0 if active else 0.0,delta/(.14 if active else .24))
	if weight <= 0: return
	var blend := smoothstep(0,1,weight)
	var hop := sin(clampf(age/.34,0,1)*PI)
	var stride := sin(maxf(0,age-.26)*TAU/1.05)
	rotate("DEF-hips",Vector3(-12,0,stride*2),blend)
	rotate("DEF-spine.001",Vector3(-8,0,-stride*2),blend)
	for side in ["L","R"]:
		var sign_value := 1.0 if side=="L" else -1.0
		var push := maxf(0,stride*sign_value)
		rotate("DEF-thigh."+side,Vector3(22+hop*16-push*18,sign_value*8,sign_value*(7+push*13)),blend)
		rotate("DEF-shin."+side,Vector3(-34-hop*18+push*20,0,0),blend)
		rotate("DEF-foot."+side,Vector3(10,sign_value*6,0),blend)
		rotate("DEF-upper_arm."+side,Vector3(8+push*9,0,sign_value*34),blend)
		rotate("DEF-forearm."+side,Vector3(-28,0,0),blend)
	var hips := rig.find_bone("DEF-hips")
	if hips>=0:
		var p := rig.get_bone_pose_position(hips)
		p.y += blend*(hop*.16-.06)
		rig.set_bone_pose_position(hips,p)
