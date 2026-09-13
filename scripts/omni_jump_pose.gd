extends RefCounted
## Approved B's presentation-only flight/landing layer. Physics owns all travel.
## Immutable clip frames are decoded once; no ground queries or per-frame IK.
const Math = preload("res://scripts/null_movement_blend.gd")
class QuietJump extends "res://scripts/model_forge_jump_pose.gd":
	func apply(_v:float,_a:bool,_d:float,_c:bool)->void:pass
static var decoded := {}
var bones:=PackedInt32Array()
var clips:Dictionary
var rig:Skeleton3D
var native_jump
var quiet_jump=QuietJump.new()
var enabled:=true
var apply_equipment:=true
var allowed:=false
var airborne_previous:=false
var jump_age:=0.0
var landing_age:=2.0
var launch:=7.0
var low_at_start:=false
var filtered_direction:=Vector3.ZERO
var entry_pose:Array[Transform3D]=[]
var older_pose:Array[Transform3D]=[]
var before:Array[Transform3D]=[]
var entry_velocity:=PackedVector3Array()
var entry_spin:=PackedVector3Array()
var revision_seen:=-999
var jump_frames:=0
var sampled_time:=0.0
# Per-character boundary timing; defaults preserve original B on Outlaw.
var entry_seconds:=.18
var landing_move_seconds:=.29
var landing_idle_seconds:=.46

func build(art,bank:AnimationLibrary)->void:
	rig=art.skeleton
	native_jump=art.jump_pose
	var key:=bank.get_instance_id()
	if not decoded.has(key):
		var rows:={}
		for name in bank.get_animation_list():
			var animation:=bank.get_animation(name)
			var frames:=[]
			# Portable bakes contain contiguous position/rotation/scale triplets.
			for f in animation.track_get_key_count(0):
				var pose:Array[Transform3D]=[]
				for tr in range(0,animation.get_track_count(),3):
					pose.append(Transform3D(Basis(animation.track_get_key_value(tr+1,f)).scaled_local(animation.track_get_key_value(tr+2,f)),animation.track_get_key_value(tr,f)))
				frames.append(pose)
			rows[name]=frames
		decoded[key]=rows
	clips=decoded[key]
	var first:=bank.get_animation(bank.get_animation_list()[0])
	for tr in range(0,first.get_track_count(),3):
		var bone:=rig.find_bone(first.track_get_path(tr).get_subname(0))
		assert(bone>=0)
		bones.append(bone)

func capture()->Array[Transform3D]:
	var pose:Array[Transform3D]=[]
	for bone in bones:pose.append(rig.get_bone_pose(bone))
	return pose

static func smooth_unit(value:float)->float:
	var x:=clampf(value,0,1)
	return x*x*x*(10+x*(-15+6*x))

func timed_pose(name:String,t:float)->Array[Transform3D]:
	t=clampf(t,0,1.15999)
	var f:=mini(int(t*60),69)
	var weight:float=(t-f/60.0)/(minf((f+1)/60.0,1.16)-f/60.0)
	var frames:Array=clips[name]
	var pose:Array[Transform3D]=[]
	for i in bones.size():pose.append(frames[f][i].interpolate_with(frames[f+1][i],weight))
	return pose

func target_pose(t:float)->Array[Transform3D]:
	var prefix:="B_"+("Low_" if low_at_start else "")
	var magnitude:=minf(filtered_direction.length(),1.0)
	var rest:=timed_pose(prefix+"-1",t)
	if magnitude<.001:return rest
	var angle:=fposmod(atan2(filtered_direction.x,-filtered_direction.z),TAU)/(PI/4)
	var a:=int(floor(angle));var w:float=angle-floor(angle)
	var first:=timed_pose(prefix+str(a%8),t)
	var second:=timed_pose(prefix+str((a+1)%8),t)
	for i in first.size():first[i]=rest[i].interpolate_with(first[i].interpolate_with(second[i],w),magnitude)
	return first

func begin_frame(art,actor:CharacterBody3D,delta:float,can_jump:bool,low:bool)->void:
	before=capture()
	allowed=enabled and can_jump and delta>0 and delta<=.10
	if actor.motion_revision!=revision_seen:
		older_pose.clear();airborne_previous=false;landing_age=2.0
		revision_seen=actor.motion_revision
	art.jump_pose=quiet_jump if allowed else native_jump
	if not allowed:
		landing_age=2.0;airborne_previous=false
		return
	var airborne:bool=not bool(actor.presentation_grounded) if actor.presentation_grounded!=null else not actor.is_on_floor()
	var velocity:Vector3=actor.velocity if actor.presentation_velocity==null else actor.presentation_velocity
	var horizontal:Vector3=actor.global_basis.inverse()*Vector3(velocity.x,0,velocity.z)
	var requested:=horizontal.normalized()*clampf(horizontal.length()/.8,0,1)
	if airborne and not airborne_previous:
		jump_age=0;landing_age=2;launch=maxf(7,velocity.y);low_at_start=low
		filtered_direction=requested
		entry_pose=before
		entry_velocity.clear();entry_spin.clear()
		for i in before.size():
			var v:=Vector3.ZERO;var spin:=Vector3.ZERO
			if older_pose.size()==before.size():
				v=(before[i].origin-older_pose[i].origin)/delta
				spin=Math.qlog(before[i].basis.get_rotation_quaternion()*older_pose[i].basis.get_rotation_quaternion().inverse())/delta
			entry_velocity.append(v.limit_length(1.0)*.20)
			entry_spin.append(spin.limit_length(6.0)*.20)
	elif not airborne and airborne_previous:landing_age=0.0
	filtered_direction=filtered_direction.lerp(requested,1-exp(-delta*10))

func finish_frame(art,actor:CharacterBody3D,delta:float)->void:
	if not allowed:
		older_pose=before
		return
	var airborne:bool=not bool(actor.presentation_grounded) if actor.presentation_grounded!=null else not actor.is_on_floor()
	var velocity:Vector3=actor.velocity if actor.presentation_velocity==null else actor.presentation_velocity
	var horizontal:=Vector2(velocity.x,velocity.z).length()
	if airborne or landing_age<maxf(landing_move_seconds,landing_idle_seconds):
		var t:=.7*clampf((1.0-velocity.y/launch)*.5,0,.999) if airborne else .7+landing_age
		sampled_time=t
		var pose:=target_pose(t)
		var release:=1.0 if airborne else 1.0-smooth_unit(landing_age/(landing_move_seconds if horizontal>.3 else landing_idle_seconds))
		for i in bones.size():
			var target:Transform3D=pose[i]
			if airborne and jump_age<entry_seconds and entry_pose.size()==pose.size():
				var u:=clampf(jump_age/entry_seconds,0,1);var decay:=1-smooth_unit(u)
				var carry:=jump_age*pow(1-u,3)
				target.origin+=(entry_pose[i].origin-target.origin)*decay+entry_velocity[i]*carry
				var q:=target.basis.get_rotation_quaternion()
				var offset:Vector3=Math.qlog(entry_pose[i].basis.get_rotation_quaternion()*q.inverse())
				target.basis=Basis(Math.qexp(offset*decay+entry_spin[i]*carry)*q)
			rig.set_bone_pose(bones[i],rig.get_bone_pose(bones[i]).interpolate_with(target,release))
		if apply_equipment:art.equipment.apply()
		jump_frames+=1
	jump_age+=delta;landing_age+=delta;airborne_previous=airborne;older_pose=before
