extends RefCounted
## Portable command gestures; same sampled rotations on visible and compact rigs.
const BANK=preload("res://assets/animations/fulcrum_commands.res")
const Clock=preload("res://scripts/snapshot_animation_clock.gd")
var rig:Skeleton3D
var bones:=PackedInt32Array()
var base:Array[Quaternion]=[]
var displayed:Array[Quaternion]=[]
var entry:Array[Quaternion]=[]
var key:=""
var release_left:=0.0
var clock=Clock.new()

func build(skeleton:Skeleton3D):
	rig=skeleton
	var sample:Animation=BANK.get_animation("RuinRight")
	for track in sample.get_track_count():
		bones.append(rig.find_bone(sample.track_get_path(track).get_subname(0)))
		assert(bones[-1]>=0)

func prepare():
	# Remove last frame's overlay before the accepted locomotion/jump pipeline.
	if base.size()==bones.size():
		for i in bones.size():rig.set_bone_pose_rotation(bones[i],base[i])

func apply(actor,delta:float):
	base.clear()
	for bone in bones:base.append(rig.get_bone_pose_rotation(bone))
	var next:="";var clip:="";var reported:=0.0
	var charging:bool=actor.casting>=0 and actor.kit[actor.casting].kind=="divide"
	if actor.hp>0 and actor.stunned<=0:
		if charging:
			next="charge";clip="DivideCharge";reported=maxf(0,actor.cast_duration-actor.cast_left)
		elif actor.casting<0:
			var events:Array=actor.identity.get("fulcrum_slashes",[])
			if not events.is_empty():
				var event:Dictionary=events[-1]
				clip={"ruin_right":"RuinRight","ruin_left":"RuinLeft","divide":"DivideRelease"}.get(event.kind,"")
				if not clip.is_empty() and event.age<BANK.get_animation(clip).length:
					next=str(event.serial);reported=event.age
	if next!=key:
		entry=displayed.duplicate() if displayed.size()==bones.size() else base.duplicate()
		if next.is_empty() and not key.is_empty():release_left=.12
		else:release_left=0
		key=next;clock.reset()
	if not key.is_empty():
		var animation:Animation=BANK.get_animation(clip)
		var age:float=clock.advance(reported,delta,actor.presentation_snapshot_serial,actor.motion_revision,animation.length)
		var onset:=smoothstep(0,.035,age)
		var release:=1.0 if charging else 1-smoothstep(animation.length-.18,animation.length,age)
		for i in bones.size():
			var target:=animation.rotation_track_interpolate(i,age)
			var pose:=base[i].slerp(entry[i].slerp(target,onset),release)
			rig.set_bone_pose_rotation(bones[i],pose.normalized())
	elif release_left>0 and actor.hp>0 and actor.stunned<=0:
		release_left=maxf(0,release_left-delta)
		for i in bones.size():rig.set_bone_pose_rotation(bones[i],base[i].slerp(entry[i],smoothstep(0,.12,release_left)))
	displayed.clear()
	for bone in bones:displayed.append(rig.get_bone_pose_rotation(bone))
