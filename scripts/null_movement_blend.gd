extends "res://scripts/model_forge_pose_blend.gd"
## Null movement transitions: cached poses and short-window bone-only leg IK; no mesh sampling.
var inertial_enabled := false
var pending := false
var ready := false
var previous_pose: Array[Transform3D] = []
var displayed_pose: Array[Transform3D] = []
var frame_delta := 1.0/60.0
var offsets := []
var current_feet := PackedVector3Array()
var previous_feet := PackedVector3Array()
var feet_indices := PackedInt32Array()
var pelvis_index := -1
var limit_count := 0
var leg_solver
var foot_offsets := []
var foot_rotation_offsets := {}
var reach_limited := 0

func global_poses(local: Array[Transform3D]) -> Array[Transform3D]:
	var result:Array[Transform3D]=[]
	for i in local.size():
		var parent:=skeleton.get_bone_parent(i)
		result.append(result[parent]*local[i] if parent>=0 else local[i])
	return result

func build(rig: Skeleton3D) -> void:
	super.build(rig)
	feet_indices=PackedInt32Array([rig.find_bone("DEF-foot.L"),rig.find_bone("DEF-foot.R")])
	pelvis_index=rig.find_bone("DEF-hips")
	leg_solver=load("res://scripts/null_transition_feet.gd").new()
	leg_solver.build(rig)
	finish_frame(1.0/60.0)

static func qlog(value: Quaternion) -> Vector3:
	var q := value.normalized()
	if q.w<0:q=-q
	var xyz := Vector3(q.x,q.y,q.z)
	var n := xyz.length()
	return xyz*2.0 if n<.0000001 else xyz*(2.0*atan2(n,q.w)/n)

static func qexp(value: Vector3) -> Quaternion:
	var angle:=value.length()
	return Quaternion.IDENTITY if angle<.0000001 else Quaternion(value/angle,angle)

func begin(seconds: float, body_seconds: float=0.0) -> void:
	super.begin(seconds,body_seconds)
	pending=inertial_enabled
	ready=false

func sample_pose(animation: Animation, time: float) -> Array[Transform3D]:
	var pose: Array[Transform3D]=[]
	for b in skeleton.get_bone_count():pose.append(skeleton.get_bone_rest(b))
	var t:=fposmod(time,animation.length)
	for tr in animation.get_track_count():
		var path:=animation.track_get_path(tr)
		if path.get_subname_count()!=1:continue
		var b:=skeleton.find_bone(String(path.get_subname(0)))
		if b<0:continue
		match animation.track_get_type(tr):
			Animation.TYPE_POSITION_3D:pose[b].origin=animation.position_track_interpolate(tr,t)
			Animation.TYPE_ROTATION_3D:pose[b].basis=Basis(animation.rotation_track_interpolate(tr,t))
			Animation.TYPE_SCALE_3D:pose[b].basis=pose[b].basis.orthonormalized().scaled_local(animation.scale_track_interpolate(tr,t))
	return pose

func prepare(animation: Animation, time: float, rate: float) -> void:
	if not pending:return
	var target:=sample_pose(animation,time)
	var future:=sample_pose(animation,time+.004*rate)
	var source_global:=global_poses(from_pose)
	var target_global:=global_poses(target)
	var future_global:=global_poses(future)
	var previous_global:=global_poses(previous_pose) if previous_pose.size()==from_pose.size() else source_global
	foot_offsets=[]
	foot_rotation_offsets={}
	for index in feet_indices:
		var incoming_velocity:Vector3=(source_global[index].origin-previous_global[index].origin)/maxf(frame_delta,.0001)
		foot_offsets.append([source_global[index].origin-target_global[index].origin,incoming_velocity-(future_global[index].origin-target_global[index].origin)/.004,source_global[index].origin.y])
	for bone in ["DEF-foot.L","DEF-toe.L","DEF-foot.R","DEF-toe.R"]:
		var index:=skeleton.find_bone(bone)
		var from_q:=source_global[index].basis.orthonormalized().get_rotation_quaternion()
		var to_q:=target_global[index].basis.orthonormalized().get_rotation_quaternion()
		var future_q:=future_global[index].basis.orthonormalized().get_rotation_quaternion()
		var previous_q:=previous_global[index].basis.orthonormalized().get_rotation_quaternion()
		foot_rotation_offsets[index]=[qlog(from_q*to_q.inverse()),qlog(from_q*previous_q.inverse())/maxf(frame_delta,.0001)-qlog(future_q*to_q.inverse())/.004]
	offsets.clear()
	for b in skeleton.get_bone_count():
		var incoming_p:=Vector3.ZERO
		var incoming_q:=Vector3.ZERO
		if previous_pose.size()==from_pose.size() and frame_delta>.00001 and frame_delta<.10:
			incoming_p=(from_pose[b].origin-previous_pose[b].origin)/frame_delta
			incoming_q=qlog(from_pose[b].basis.get_rotation_quaternion()*previous_pose[b].basis.get_rotation_quaternion().inverse())/frame_delta
		var q:=target[b].basis.get_rotation_quaternion()
		offsets.append([
			from_pose[b].origin-target[b].origin,
			incoming_p-(future[b].origin-target[b].origin)/.004,
			qlog(from_pose[b].basis.get_rotation_quaternion()*q.inverse()),
			incoming_q-qlog(future[b].basis.get_rotation_quaternion()*q.inverse())/.004
		])
	pending=false
	ready=true

func apply(delta: float) -> void:
	if not inertial_enabled:
		super.apply(delta)
		return
	if not ready or elapsed>=duration:return
	elapsed=minf(duration,elapsed+maxf(delta,0.0))
	var u:=clampf(elapsed/duration,0.0,1.0)
	var a:=1.0-10.0*pow(u,3)+15.0*pow(u,4)-6.0*pow(u,5)
	var velocity_window:=minf(.11,duration)
	var v:=clampf(elapsed/velocity_window,0.0,1.0)
	var b:=velocity_window*(v-6.0*pow(v,3)+8.0*pow(v,4)-3.0*pow(v,5))
	var raw_feet:=PackedVector3Array()
	var raw_rotations:={}
	for index in feet_indices:raw_feet.append(skeleton.get_bone_global_pose(index).origin)
	for index in foot_rotation_offsets:raw_rotations[index]=skeleton.get_bone_global_pose(index).basis.orthonormalized().get_rotation_quaternion()
	for i in offsets.size():
		var o:Array=offsets[i]
		var displacement:Vector3=o[0]*a+o[1]*b
		if i==pelvis_index:
			for axis in 3:
				var bounded:=clampf(displacement[axis],minf(0.0,o[0][axis])-.015,maxf(0.0,o[0][axis])+.015)
				if absf(bounded-displacement[axis])>.000001:limit_count+=1
				displacement[axis]=bounded
		var angular:Vector3=o[2]*a+o[3]*b
		var bound:float=o[2].length()+.08
		if angular.length()>bound:
			angular=angular.normalized()*bound
			limit_count+=1
		skeleton.set_bone_pose_position(i,skeleton.get_bone_pose_position(i)+displacement)
		skeleton.set_bone_pose_rotation(i,(qexp(angular)*skeleton.get_bone_pose_rotation(i)).normalized())
	# Joint-space blends can raise both feet while the pelvis is still arriving.
	# Carry the actual foot endpoints through the transition and solve fixed-length
	# leg chains to those paths. This runs only during the short transition window.
	for index in foot_rotation_offsets:
		var o:Array=foot_rotation_offsets[index]
		var angular:Vector3=o[0]*a+o[1]*b
		if angular.length()>o[0].length()+.04:angular=angular.normalized()*(o[0].length()+.04)
		leg_solver.set_global_rotation(index,Basis(qexp(angular)*raw_rotations[index]))
	for side in 2:
		var o:Array=foot_offsets[side]
		var goal:Vector3=raw_feet[side]+o[0]*a+o[1]*b
		# Do not carry downward velocity below both source and destination paths.
		goal.y=maxf(goal.y,minf(float(o[2]),raw_feet[side].y)-.005)
		var label:="L" if side==0 else "R"
		var solved:Dictionary=leg_solver.solve_leg(label,goal,leg_solver.source_bend(label),true)
		if solved.get("limited",false):reach_limited+=1

func finish_frame(delta: float) -> void:
	previous_pose=displayed_pose
	displayed_pose=[]
	for b in skeleton.get_bone_count():displayed_pose.append(skeleton.get_bone_pose(b))
	previous_feet=current_feet
	current_feet=PackedVector3Array()
	for b in feet_indices:current_feet.append(skeleton.get_bone_global_pose(b).origin)
	frame_delta=delta

func clear_velocity_history() -> void:
	previous_pose=[]
	displayed_pose=[]
	previous_feet=PackedVector3Array()
	current_feet=PackedVector3Array()
