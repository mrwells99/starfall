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
var upper_body := {}
## Guard only repeated early interruptions; ordinary approved B remains exact.
const RAPID_INTERRUPT_WINDOW := .14
const BURST_KNEE_RATE := deg_to_rad(900.0)
const BURST_LEG_DURATION := .31
const BURST_LEG_RESPONSE := 14.0
const BURST_UPPER_RESPONSE := 9.0
var burst_guard_enabled := true
var rapid_interruptions := 0
var burst_guard_active := false
var burst_leg_frames := 0
## Small horizontal follow-through, separate from the history that drives B.
const FOLLOW_FRACTION := .20
const FOLLOW_MAX_SPEED := .7
const FOLLOW_MAX_DISTANCE := .025
const FOLLOW_SECONDS := .12
const FOLLOW_MAX_ANGLE := deg_to_rad(4.0)
var follow_enabled := true
var follow_elapsed := FOLLOW_SECONDS
var follow_velocity := PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
var follow_start := PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
var follow_offset := PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
var follow_base_pose := {}
var follow_base_feet := PackedVector3Array()
var follow_solver
var follow_frames := 0
## Soft ceiling for extra horizontal planting during movement transitions.
## Authored stride endpoints remain free; only the transition's extra reach is trimmed.
const PLANT_REACH := Vector2(.48,.46) # anatomical left / right, metres from its hip
const PLANT_SOFT_BAND := .04
var plant_limit_enabled := true
var plant_limits := PackedFloat32Array([INF,INF])
var plant_source_reach := PackedFloat32Array([0.0,0.0])
var plant_limit_frames := 0

func limit_plant_goal(side: int, goal: Vector3, soften: bool) -> Vector3:
	var limit:float=plant_limits[side]
	if not is_finite(limit):return goal
	var leg:Dictionary=leg_solver.legs["L" if side==0 else "R"]
	var hip:Vector3=skeleton.get_bone_global_pose(leg.thigh).origin
	var horizontal:=Vector3(goal.x-hip.x,0.0,goal.z-hip.z)
	var distance:=horizontal.length()
	var start:=limit-PLANT_SOFT_BAND
	if distance<=start:return goal
	var bounded:=minf(distance,limit)
	if soften:
		# C1 shoulder: unchanged slope at entry, zero slope at the ceiling.
		var t:=clampf((distance-start)/(2.0*PLANT_SOFT_BAND),0.0,1.0)
		bounded=start+PLANT_SOFT_BAND*(2.0*t-t*t)
	if bounded<distance:
		plant_limit_frames+=1
		horizontal*=bounded/distance
		goal.x=hip.x+horizontal.x
		goal.z=hip.z+horizontal.z
	return goal

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
	for bone in rig.get_bone_count():
		var name:=String(rig.get_bone_name(bone))
		upper_body[bone]=name in ["DEF-spine.001","DEF-spine.002","DEF-spine.003","DEF-neck","DEF-head"] or name.begins_with("DEF-shoulder.") or name.begins_with("DEF-upper_arm.") or name.begins_with("DEF-forearm.") or name.begins_with("DEF-hand.") or name.begins_with("DEF-f_") or name.begins_with("DEF-thumb")
	leg_solver=load("res://scripts/null_transition_feet.gd").new()
	leg_solver.build(rig)
	follow_solver=load("res://scripts/null_transition_feet.gd").new()
	follow_solver.build(rig)
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
	rapid_interruptions = mini(rapid_interruptions + 1, 2) if inertial_enabled and ready and elapsed < RAPID_INTERRUPT_WINDOW else 0
	burst_guard_active = burst_guard_enabled and rapid_interruptions >= 1
	super.begin(seconds,body_seconds)
	if burst_guard_active and follow_enabled:
		# Both phase matching and this velocity use the unadorned base history.
		# Captured IK follow-through must never become input to another pulse.
		for bone in follow_base_pose:from_pose[bone]=follow_base_pose[bone]
		follow_start=follow_offset.duplicate()
		follow_elapsed=0.0
		for side in 2:
			var velocity:=Vector3.ZERO
			if current_feet.size()==2 and previous_feet.size()==2 and frame_delta>.00001 and frame_delta<.10:
				velocity=(current_feet[side]-previous_feet[side])/frame_delta
			velocity.y=0.0
			follow_velocity[side]=(velocity*FOLLOW_FRACTION).limit_length(FOLLOW_MAX_SPEED)
	else:
		clear_follow()
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
	for side in 2:
		var leg:Dictionary=leg_solver.legs["L" if side==0 else "R"]
		var reach:Vector3=source_global[leg.foot].origin-source_global[leg.thigh].origin
		reach.y=0.0
		plant_source_reach[side]=reach.length()
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

func apply_inertial(delta: float) -> void:
	if not inertial_enabled:
		super.apply(delta)
		return
	if not ready or elapsed>=duration:return
	elapsed=minf(duration,elapsed+maxf(delta,0.0))
	var u:=clampf(elapsed/duration,0.0,1.0)
	var a:=1.0-10.0*pow(u,3)+15.0*pow(u,4)-6.0*pow(u,5)
	var velocity_window:=minf(.118,duration)
	var v:=clampf(elapsed/velocity_window,0.0,1.0)
	var b:=velocity_window*(v-6.0*pow(v,3)+8.0*pow(v,4)-3.0*pow(v,5))
	# Preserve approved B's pelvis/legs/foot trajectories exactly. Only the
	# unconstrained upper body receives the extra 6% settling window.
	var lower_duration:=duration/1.06
	var lower_u:=clampf(elapsed/lower_duration,0.0,1.0)
	var lower_a:=1.0-10.0*pow(lower_u,3)+15.0*pow(lower_u,4)-6.0*pow(lower_u,5)
	var lower_window:=minf(.11,lower_duration)
	var lower_v:=clampf(elapsed/lower_window,0.0,1.0)
	var lower_b:=lower_window*(lower_v-6.0*pow(lower_v,3)+8.0*pow(lower_v,4)-3.0*pow(lower_v,5))
	var raw_feet:=PackedVector3Array()
	var raw_rotations:={}
	for index in feet_indices:raw_feet.append(skeleton.get_bone_global_pose(index).origin)
	for index in foot_rotation_offsets:raw_rotations[index]=skeleton.get_bone_global_pose(index).basis.orthonormalized().get_rotation_quaternion()
	# Repeatedly recycling solved leg velocities pumps energy into interrupted
	# inertial blends. During a burst, use a short, non-extrapolating follow from
	# the last displayed lower pose instead. The advancing clip remains the target.
	var burst_lower := burst_guard_active and displayed_pose.size()==offsets.size()
	var burst_weight := 1.0
	var burst_upper_weight := 1.0
	var displayed_global: Array[Transform3D] = []
	if burst_lower:
		burst_leg_frames+=1
		var remaining := maxf(BURST_LEG_DURATION-(elapsed-maxf(delta,0.0)),maxf(delta,.000001))
		burst_weight=clampf(maxf(1.0-exp(-maxf(delta,0.0)*BURST_LEG_RESPONSE),delta/remaining),0.0,1.0)
		var upper_remaining := maxf(duration-(elapsed-maxf(delta,0.0)),maxf(delta,.000001))
		burst_upper_weight=clampf(maxf(1.0-exp(-maxf(delta,0.0)*BURST_UPPER_RESPONSE),delta/upper_remaining),0.0,1.0)
		displayed_global=global_poses(displayed_pose)
	for i in offsets.size():
		if burst_lower:
			# Upper body keeps the long settling window, but must not accumulate
			# extrapolated twist either as the supporting pelvis changes underneath.
			skeleton.set_bone_pose(i,displayed_pose[i].interpolate_with(skeleton.get_bone_pose(i),burst_upper_weight if upper_body[i] else burst_weight))
			continue
		var o:Array=offsets[i]
		var pose_a:float=a if upper_body[i] else lower_a
		var pose_b:float=b if upper_body[i] else lower_b
		var displacement:Vector3=o[0]*pose_a+o[1]*pose_b
		if i==pelvis_index:
			for axis in 3:
				var bounded:=clampf(displacement[axis],minf(0.0,o[0][axis])-.015,maxf(0.0,o[0][axis])+.015)
				if absf(bounded-displacement[axis])>.000001:limit_count+=1
				displacement[axis]=bounded
		var angular:Vector3=o[2]*pose_a+o[3]*pose_b
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
		if burst_lower:
			var previous_q:=displayed_global[index].basis.orthonormalized().get_rotation_quaternion()
			leg_solver.set_global_rotation(index,Basis(previous_q.slerp(raw_rotations[index],burst_weight)))
			continue
		var o:Array=foot_rotation_offsets[index]
		var angular:Vector3=o[0]*lower_a+o[1]*lower_b
		if angular.length()>o[0].length()+.04:angular=angular.normalized()*(o[0].length()+.04)
		leg_solver.set_global_rotation(index,Basis(qexp(angular)*raw_rotations[index]))
	for side in 2:
		var o:Array=foot_offsets[side]
		var goal:Vector3=raw_feet[side]+o[0]*lower_a+o[1]*lower_b
		if burst_lower:
			goal=displayed_global[feet_indices[side]].origin.lerp(raw_feet[side],burst_weight)
		if plant_limit_enabled and burst_lower:
			var leg:Dictionary=leg_solver.legs["L" if side==0 else "R"]
			var hip:Vector3=skeleton.get_bone_global_pose(leg.thigh).origin
			var raw_horizontal:=Vector3(raw_feet[side].x-hip.x,0.0,raw_feet[side].z-hip.z)
			# Arrive gently from the current pose, and release into the authored
			# stride at the end. Reversals replace this envelope, never add impulses.
			var enter:=smoothstep(0.0,.08,elapsed)
			var release:=smoothstep(maxf(0.0,lower_duration-.10),lower_duration,elapsed)
			var source_limit:=lerpf(maxf(PLANT_REACH[side],plant_source_reach[side]+PLANT_SOFT_BAND),PLANT_REACH[side],enter)
			var target_limit:=lerpf(PLANT_REACH[side],maxf(PLANT_REACH[side],raw_horizontal.length()+PLANT_SOFT_BAND),release)
			plant_limits[side]=maxf(source_limit,target_limit)
			goal=limit_plant_goal(side,goal,true)
		# Do not carry downward velocity below both source and destination paths.
		if not burst_lower:goal.y=maxf(goal.y,minf(float(o[2]),raw_feet[side].y)-.005)
		var label:="L" if side==0 else "R"
		var solved:Dictionary=leg_solver.solve_leg(label,goal,leg_solver.source_bend(label),true)
		if solved.get("limited",false):reach_limited+=1
	if burst_lower:apply_follow(delta)

func clear_follow() -> void:
	follow_elapsed=FOLLOW_SECONDS
	follow_velocity=PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
	follow_start=PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
	follow_offset=PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
	follow_base_pose.clear()
	follow_base_feet=PackedVector3Array()

func apply_follow(delta: float) -> void:
	if not follow_enabled or follow_elapsed>=FOLLOW_SECONDS:return
	follow_elapsed=minf(FOLLOW_SECONDS,follow_elapsed+maxf(delta,0.0))
	var u:=follow_elapsed/FOLLOW_SECONDS
	var decay:=1.0-u*u*(3.0-2.0*u)
	var carry:=follow_elapsed*(1.0-u)*(1.0-u)
	follow_solver.reset()
	for side in 2:
		var label:="L" if side==0 else "R"
		var leg:Dictionary=follow_solver.legs[label]
		for bone in [leg.thigh,leg.shin,leg.foot,leg.toe]:follow_base_pose[bone]=skeleton.get_bone_pose(bone)
		var base_foot:Vector3=follow_solver.ankle(label)
		follow_base_feet.append(base_foot)
		var offset:Vector3=(follow_start[side]*decay+follow_velocity[side]*carry).limit_length(FOLLOW_MAX_DISTANCE)
		offset.y=0.0
		# Cosmetic carry cannot extend the foot past the same planting ceiling.
		offset=limit_plant_goal(side,base_foot+offset,false)-base_foot
		follow_offset[side]=Vector3.ZERO
		if offset.length_squared()<.0000000001:continue
		var foot_basis:=skeleton.get_bone_global_pose(leg.foot).basis
		var toe_basis:=skeleton.get_bone_global_pose(leg.toe).basis
		follow_solver.solve_leg(label,base_foot+offset,follow_solver.source_bend(label),true)
		var wanted:=[skeleton.get_bone_pose_rotation(leg.thigh),skeleton.get_bone_pose_rotation(leg.shin)]
		var weight:=1.0
		var bones:=[leg.thigh,leg.shin]
		for index in 2:
			var base_q:Quaternion=follow_base_pose[bones[index]].basis.get_rotation_quaternion()
			var angle:=qlog(wanted[index]*base_q.inverse()).length()
			if angle>FOLLOW_MAX_ANGLE:weight=minf(weight,FOLLOW_MAX_ANGLE/angle)
		# Bound the final solved result too: tiny goals near a straight knee can
		# otherwise cause large joint changes. No lower foot or longer limb.
		for attempt in 8:
			for index in 2:
				var base_q:Quaternion=follow_base_pose[bones[index]].basis.get_rotation_quaternion()
				skeleton.set_bone_pose_rotation(bones[index],base_q.slerp(wanted[index],weight).normalized())
			var actual:Vector3=follow_solver.ankle(label)-base_foot
			var actual_foot:Vector3=base_foot+actual
			var inside_plant:=actual_foot.distance_squared_to(limit_plant_goal(side,actual_foot,false))<.0000000001
			if actual.length()<=FOLLOW_MAX_DISTANCE and actual.y>=-.002 and inside_plant:
				follow_offset[side]=actual
				break
			weight=weight*.5 if attempt<6 else 0.0
		follow_solver.set_global_rotation(leg.foot,foot_basis)
		follow_solver.set_global_rotation(leg.toe,toe_basis)
		if follow_offset[side].length()>.00001:follow_frames+=1

func finish_frame(delta: float) -> void:
	previous_pose=displayed_pose
	displayed_pose=[]
	for b in skeleton.get_bone_count():displayed_pose.append(skeleton.get_bone_pose(b))
	previous_feet=current_feet
	current_feet=PackedVector3Array()
	for b in feet_indices:current_feet.append(skeleton.get_bone_global_pose(b).origin)
	# The visible rig keeps the additive result, but all next-frame pose/phase/
	# velocity inputs use the independently evaluated, pre-follow-through base.
	if not follow_base_pose.is_empty():
		for bone in follow_base_pose:displayed_pose[bone]=follow_base_pose[bone]
		current_feet=follow_base_feet.duplicate()
	frame_delta=delta

func clear_velocity_history() -> void:
	plant_limits=PackedFloat32Array([INF,INF])
	plant_source_reach=PackedFloat32Array([0.0,0.0])
	previous_pose=[]
	displayed_pose=[]
	previous_feet=PackedVector3Array()
	current_feet=PackedVector3Array()
	clear_follow()
	rapid_interruptions=0
	burst_guard_active=false
	if leg_solver!=null:leg_solver.continuity_max_angle=0.0


# Tiny coherent moving hold, from actual Ready/LowIdle donor curves.
# No independent noise, lower-body offsets, random phase, or gameplay writes.
var life_library: AnimationLibrary
var life_bindings := {}
var life_low := false
var life_clock := 0.0
var life_elapsed := 100.0
var neck_index := -1
var life_peak_weight := 0.0

func load_life(library: AnimationLibrary) -> void:
	life_library=library
	neck_index=skeleton.find_bone("DEF-neck")
	for name in library.get_animation_list():
		var clip:=library.get_animation(name)
		var rows:=[]
		for track in clip.get_track_count():
			var bone:=skeleton.find_bone(String(clip.track_get_path(track).get_subname(0)))
			assert(bone>=0)
			rows.append([bone,track])
		life_bindings[name]=rows

func apply(delta: float) -> void:
	plant_limits=PackedFloat32Array([INF,INF])
	follow_base_pose.clear()
	follow_base_feet=PackedVector3Array()
	follow_offset=PackedVector3Array([Vector3.ZERO,Vector3.ZERO])
	if not burst_guard_enabled or not inertial_enabled or not ready or elapsed>=duration:
		burst_guard_active=false
	leg_solver.continuity_max_angle=BURST_KNEE_RATE*maxf(delta,0.0) if burst_guard_active else 0.0
	if pending:life_elapsed=0.0
	# prepare() clears pending before apply(), so use the first blend frame.
	if ready and elapsed<=0.0:life_elapsed=0.0
	apply_inertial(delta)
	life_clock+=maxf(0.0,delta)
	life_elapsed+=maxf(0.0,delta)
	if not inertial_enabled or not ready or life_library==null:return
	var enter:=clampf(life_elapsed/.16,0.0,1.0)
	var exit_weight:=clampf((duration+.20-life_elapsed)/.20,0.0,1.0)
	var weight:=enter*enter*(3.0-2.0*enter)*exit_weight*exit_weight*(3.0-2.0*exit_weight)
	life_peak_weight=maxf(life_peak_weight,weight)
	if weight<=.000001:return
	var name:="LowIdle" if life_low else "Ready"
	var clip:=life_library.get_animation(name)
	var time:=fposmod(life_clock*.9,clip.length)
	var neck_basis:=skeleton.get_bone_global_pose(neck_index).basis
	for row in life_bindings[name]:
		var rotation:=Quaternion.IDENTITY.slerp(clip.rotation_track_interpolate(row[1],time),weight)
		skeleton.set_bone_pose_rotation(row[0],(rotation*skeleton.get_bone_pose_rotation(row[0])).normalized())
	# Keep the existing head's gaze orientation; chest settling isn't another head nod.
	leg_solver.set_global_rotation(neck_index,neck_basis)
