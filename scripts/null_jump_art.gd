extends "res://scripts/null_living_art.gd"
## Approved Living balance B: elbow-led arc, coordinated air life, contact-ended fall.
const AIR_LIFE_VARIANT := "B"
var omni_jump=preload("res://scripts/omni_jump_pose.gd").new()
var air_life_bones:=PackedInt32Array()
var fall_bones:=PackedInt32Array()
var fall_axes:=PackedVector3Array()
var fall_age:=-1.0
var blindside_pose=preload("res://scripts/null_blindside_pose.gd").new()

func build(host:Node3D,color:Color)->void:
	super.build(host,color)
	blindside_pose.build(skeleton)
	omni_jump.build(self,preload("res://assets/animations/null_jump_b.res"))
	# Reuse B's bounded displayed-pose blend; no added pose filter or momentum loop.
	omni_jump.entry_seconds=.28
	omni_jump.landing_move_seconds=.38
	omni_jump.landing_idle_seconds=.54
	for bone_name in ["DEF-spine.002","DEF-spine.003","DEF-neck","DEF-head","DEF-shoulder.L","DEF-shoulder.R","DEF-upper_arm.L","DEF-upper_arm.R","DEF-forearm.L","DEF-forearm.R"]:
		air_life_bones.append(skeleton.find_bone(bone_name))
	for bone_name in ["DEF-forearm.L","DEF-forearm.R","DEF-thigh.L","DEF-thigh.R","DEF-shin.L","DEF-shin.R"]:
		fall_bones.append(skeleton.find_bone(bone_name))
	fall_axes=preload("res://assets/animations/null_jump_b.res").get_meta("fall_elbow_axes",PackedVector3Array([Vector3.RIGHT,Vector3.LEFT]))

func ordinary_jump_allowed(actor)->bool:
	var pending_strike:bool=action_serial>=0 and action_serial!=int(actor.identity.get("null_action_serial",0)) and actor.identity.get("null_action","") in ["stab","backstab"]
	var blindside_cast:bool=actor.casting>=0 and actor.kit[actor.casting].kind=="blindside"
	return actor.hp>0 and actor.stunned<=0 and (actor.casting<0 or blindside_cast) and not Null.busy(actor) and strike_left<=0 and not pending_strike and actor.charge.is_empty() and lasso_pose.Lasso.state(actor).is_empty() and not lasso_pose.Lasso.knockdown_active(actor) and lasso_pose.phase.is_empty() and lasso_pose.blend_time>=.10

func animate(host:Node3D,delta:float,actor:CharacterBody3D)->void:
	blindside_pose.prepare(actor,delta)
	omni_jump.begin_frame(self,actor,delta,ordinary_jump_allowed(actor),Null.stealthed(actor))
	super.animate(host,delta,actor)
	omni_jump.finish_frame(self,actor,delta)
	apply_air_life(actor)
	apply_extended_fall(actor,delta)
	blindside_pose.apply(delta)
	if blindside_pose.active or blindside_pose.release_left>0.0:equipment.apply()

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

func override_clip(desired:String,alive:bool,stunned:bool,delta:float)->String:
	if desired.begins_with("Jump") and omni_jump.allowed and alive and not stunned and active_actor!=null:
		return locomotion.choose(filtered_speed,active_actor.walking,false,Null.stealthed(active_actor))
	return super.override_clip(desired,alive,stunned,delta)
