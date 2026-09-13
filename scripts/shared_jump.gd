extends RefCounted
## Shared approved Null Living balance B. No travel, ability or networking ownership.
const BANKS={
	"Ember":preload("res://assets/animations/ember_jump_b.res"),
	"Luminary":preload("res://assets/animations/luminary_jump_b.res"),
	"Fulcrum":preload("res://assets/animations/fulcrum_jump_b.res"),
	"Vanguard":preload("res://assets/animations/vanguard_jump_b.res"),
	"Outlaw":preload("res://assets/animations/outlaw_jump_b.res")
}
const AIR_LIFE_VARIANT := "B"
var omni_jump=preload("res://scripts/omni_jump_pose.gd").new()
var skeleton:Skeleton3D
var air_life_bones:=PackedInt32Array()
var fall_bones:=PackedInt32Array()
var fall_axes:=PackedVector3Array()
var fall_age:=-1.0
var title:=""
var focus:=-1
var focus_hand:=-1
var active_actor:CharacterBody3D

func build(art,class_title:String)->void:
	title=class_title;skeleton=art.skeleton
	omni_jump.build(art,BANKS[title])
	omni_jump.apply_equipment=false
	omni_jump.entry_seconds=.28;omni_jump.landing_move_seconds=.38;omni_jump.landing_idle_seconds=.54
	for name in ["DEF-spine.002","DEF-spine.003","DEF-neck","DEF-head","DEF-shoulder.L","DEF-shoulder.R","DEF-upper_arm.L","DEF-upper_arm.R","DEF-forearm.L","DEF-forearm.R"]:
		air_life_bones.append(skeleton.find_bone(name))
	for name in ["DEF-forearm.L","DEF-forearm.R","DEF-thigh.L","DEF-thigh.R","DEF-shin.L","DEF-shin.R"]:
		fall_bones.append(skeleton.find_bone(name))
	fall_axes=BANKS[title].get_meta("fall_elbow_axes")
	if title=="Fulcrum":
		focus=skeleton.find_bone("gravity.focus");focus_hand=skeleton.find_bone("DEF-hand.L")

func ordinary_jump_allowed(art,actor)->bool:
	if actor.hp<=0 or actor.stunned>0 or actor.casting>=0 or art.was_casting or not actor.charge.is_empty():return false
	if art.transient_left>0 and art.transient_clip.begins_with("Cast"):return false
	if title=="Vanguard" and art.attack_left>0:return false
	if actor.gcd>art.previous_gcd+.15:return false
	if art.previous_cooldowns.size()==actor.cooldowns.size():
		for i in actor.cooldowns.size():
			if float(actor.cooldowns[i])>float(art.previous_cooldowns[i])+.15:return false
	return art.lasso_pose.Lasso.state(actor).is_empty() and not art.lasso_pose.Lasso.knockdown_active(actor) and art.lasso_pose.phase.is_empty() and art.lasso_pose.blend_time>=.10

func begin_frame(art,actor:CharacterBody3D,delta:float)->void:
	active_actor=actor
	omni_jump.begin_frame(art,actor,delta,ordinary_jump_allowed(art,actor),false)

func finish_frame(art,actor:CharacterBody3D,delta:float)->void:
	if not omni_jump.allowed:
		omni_jump.finish_frame(art,actor,delta)
		fall_age=-1.0
		return
	var offset:=Vector3.ZERO
	if focus>=0:offset=skeleton.get_bone_global_pose(focus).origin-skeleton.get_bone_global_pose(focus_hand).origin
	var equipment=art.get("equipment")
	if title=="Vanguard":equipment.capture()
	omni_jump.finish_frame(art,actor,delta)
	apply_air_life(actor)
	apply_extended_fall(actor,delta)
	if not omni_jump.allowed:return
	var airborne:bool=not bool(actor.presentation_grounded) if actor.presentation_grounded!=null else not actor.is_on_floor()
	if not airborne and omni_jump.landing_age>=omni_jump.landing_idle_seconds:return
	if focus>=0:
		var point:=skeleton.get_bone_global_pose(focus_hand).origin+offset
		var parent:=skeleton.get_bone_parent(focus)
		skeleton.set_bone_pose_position(focus,skeleton.get_bone_global_pose(parent).affine_inverse()*point if parent>=0 else point)
	elif equipment!=null:
		if title=="Vanguard":
			equipment.follow_jump()
			equipment.precise_aim=true
		equipment.apply()
		if title=="Vanguard":equipment.precise_aim=false

func apply_base_extended_fall(actor:CharacterBody3D,delta:float)->void:
	if not omni_jump.allowed:
		fall_age=-1.0
		return
	var airborne:bool=not bool(actor.presentation_grounded) if actor.presentation_grounded!=null else not actor.is_on_floor()
	if airborne and omni_jump.jump_age<=delta*1.5:fall_age=-1.0
	if not airborne and omni_jump.landing_age>=omni_jump.landing_move_seconds:
		fall_age=-1.0
		return
	var velocity:Vector3=actor.velocity if actor.presentation_velocity==null else actor.presentation_velocity
	if airborne and fall_age<0 and velocity.y < -omni_jump.launch:fall_age=0.0
	if fall_age<0:return
	# Normal-height jumps are untouched. A lower landing gets a continuing falling
	# pose, never another takeoff or a timed landing. Corrections do not feed back.
	var weight:=omni_jump.smooth_unit(fall_age/.24)
	if not airborne:weight*=1.0-omni_jump.smooth_unit(omni_jump.landing_age/omni_jump.landing_move_seconds)
	var phase:=fall_age*TAU/1.8
	var lift:=.28*(.5-.5*cos(phase))*weight
	for i in 2:
		var bone:=fall_bones[i]
		skeleton.set_bone_pose_rotation(bone,(skeleton.get_bone_pose_rotation(bone)*Quaternion(fall_axes[i],lift)).normalized())
	# Small coordinated leg settling: no ankle/toe searching, root offsets or IK.
	var settle:=sin(phase*.82)*weight
	for i in range(2,6):
		var bone:=fall_bones[i]
		var angle:float=(-.025 if i<4 else .045)*settle
		skeleton.set_bone_pose_rotation(bone,(skeleton.get_bone_pose_rotation(bone)*Quaternion(Vector3.RIGHT,angle)).normalized())
	fall_age+=delta

func apply_air_life(actor:CharacterBody3D)->void:
	if not omni_jump.allowed or air_life_bones.is_empty():return
	var airborne:bool=not bool(actor.presentation_grounded) if actor.presentation_grounded!=null else not actor.is_on_floor()
	if not airborne and omni_jump.landing_age>=omni_jump.landing_move_seconds:return
	var age:float=omni_jump.jump_age
	var weight:=omni_jump.smooth_unit(age/.20)
	if not airborne:weight*=1.0-omni_jump.smooth_unit(omni_jump.landing_age/omni_jump.landing_move_seconds)
	weight*=.65 if AIR_LIFE_VARIANT=="A" else 1.0
	var phase:=age*TAU/1.95
	var breath:=sin(phase)
	var follow:=sin(phase-.30)
	var balance:=sin(phase*.73+1.1)
	# One coordinated impulse/breath and a delayed counter-response, not random noise.
	# Head partly counters chest tilt to stay attentive while the body moves beneath it.
	var motion:=[Vector3(.019*breath,0,.008*balance),Vector3(.032*breath,.022*balance,.015*balance),Vector3(-.016*follow,.016*sin(phase*.73-.24),-.006*balance),Vector3(-.028*follow,.027*sin(phase*.73-.24),-.010*balance),Vector3(.009*follow,0,.009*balance),Vector3(.008*sin(phase-.42),0,-.009*balance),Vector3(.012*follow,.008*balance,.006*breath),Vector3(.010*sin(phase-.42),-.008*balance,-.006*breath)]
	for i in motion.size():
		var bone:=air_life_bones[i]
		skeleton.set_bone_pose_rotation(bone,(Basis.from_euler(motion[i]*weight).get_rotation_quaternion()*skeleton.get_bone_pose_rotation(bone)).normalized())
	for i in 2:
		var bone:=air_life_bones[8+i]
		var bend:=.042*sin(phase+(.16 if i==0 else -.20))*weight
		skeleton.set_bone_pose_rotation(bone,(skeleton.get_bone_pose_rotation(bone)*Quaternion(fall_axes[i],bend)).normalized())

func apply_extended_fall(actor:CharacterBody3D,delta:float)->void:
	apply_base_extended_fall(actor,delta)
	if not omni_jump.allowed or fall_age<0:return
	var airborne:bool=not bool(actor.presentation_grounded) if actor.presentation_grounded!=null else not actor.is_on_floor()
	var age:=maxf(0,fall_age-delta)
	var weight:=omni_jump.smooth_unit(age/.24)
	if not airborne:weight*=1.0-omni_jump.smooth_unit(omni_jump.landing_age/omni_jump.landing_move_seconds)
	var phase:=age*TAU/1.8
	var old_lift:=.28*(.5-.5*cos(phase))
	var difference:float=.08 if AIR_LIFE_VARIANT=="A" else .16
	for i in 2:
		var lift:=.27*(.5-.5*cos(phase+(difference if i==0 else -difference)))
		var bone:=fall_bones[i]
		skeleton.set_bone_pose_rotation(bone,(skeleton.get_bone_pose_rotation(bone)*Quaternion(fall_axes[i],(lift-old_lift)*weight)).normalized())
