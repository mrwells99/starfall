extends RefCounted
## Fixed-length bone-only leg solve used during Null's movement transitions.
## Skeleton-space global-bone goals; caller owns trajectory/contact choice. No mesh access,
## position/scale/rest writes, actor travel, pelvis correction, or automatic ground locking.
const SIDES := ["L", "R"]
const EPS := 0.000001
const REACH_MARGIN := 0.00001
var rig: Skeleton3D
var legs: Dictionary = {}
var last_axis: Dictionary = {}
var last_bend: Dictionary = {}
var total_solves := 0
var limited_solves := 0
var rejected_solves := 0
var fallback_bends := 0
## Opt-in per-frame knee-plane continuity; zero preserves original B for Outlaw/A.
var continuity_max_angle := 0.0
var continuity_limited_solves := 0

func build(skeleton: Skeleton3D) -> void:
	rig = skeleton
	assert(rig != null)
	legs.clear()
	reset()
	for side in SIDES:
		var thigh := rig.find_bone("DEF-thigh." + side)
		var shin := rig.find_bone("DEF-shin." + side)
		var foot := rig.find_bone("DEF-foot." + side)
		var toe := rig.find_bone("DEF-toe." + side)
		assert(thigh >= 0 and shin >= 0 and foot >= 0 and toe >= 0)
		assert(rig.get_bone_parent(shin) == thigh and rig.get_bone_parent(foot) == shin)
		var hip_rest := rig.get_bone_global_rest(thigh).origin
		var knee_rest := rig.get_bone_global_rest(shin).origin
		var ankle_rest := rig.get_bone_global_rest(foot).origin
		var axis := (ankle_rest - hip_rest).normalized()
		var bend := knee_rest - hip_rest
		bend -= axis * bend.dot(axis)
		if bend.length() <= EPS:
			bend = _orthogonal(axis)
		legs[side] = {"thigh": thigh, "shin": shin, "foot": foot, "toe": toe,
			"upper_length": hip_rest.distance_to(knee_rest), "lower_length": knee_rest.distance_to(ankle_rest),
			"rest_axis": axis, "rest_bend": bend.normalized()}

func reset() -> void:
	last_axis.clear()
	last_bend.clear()
	total_solves = 0
	limited_solves = 0
	rejected_solves = 0
	fallback_bends = 0
	continuity_max_angle = 0.0
	continuity_limited_solves = 0

func ankle(side: String) -> Vector3:
	return rig.get_bone_global_pose(legs[side].foot).origin

func source_bend(side: String) -> Vector3:
	var leg: Dictionary = legs[side]
	var hip := rig.get_bone_global_pose(leg.thigh).origin
	var knee := rig.get_bone_global_pose(leg.shin).origin
	var axis := _source_axis(side, ankle(side) - hip)
	var bend := knee - hip
	bend -= axis * bend.dot(axis)
	return bend.normalized() if bend.length() > EPS else Vector3.ZERO

func _orthogonal(axis: Vector3) -> Vector3:
	return axis.cross(Vector3.RIGHT if absf(axis.x) < .9 else Vector3.UP).normalized()

func _source_axis(side: String, vector: Vector3) -> Vector3:
	if vector.length() > EPS:
		return vector.normalized()
	return last_axis.get(side, legs[side].rest_axis)

func between(from: Vector3, to: Vector3, antiparallel_axis: Vector3) -> Quaternion:
	var dot := clampf(from.dot(to), -1.0, 1.0)
	if dot < -1.0 + 0.0000001:
		var axis := antiparallel_axis - from * antiparallel_axis.dot(from)
		if axis.length() < EPS:
			axis = _orthogonal(from)
		return Quaternion(axis.normalized(), PI)
	# Preserve the cross term even at tiny angles; an identity threshold causes a dead zone.
	var cross := from.cross(to)
	return Quaternion(cross.x, cross.y, cross.z, 1.0 + dot).normalized()

func bend_for_goal(side: String, hip: Vector3, knee: Vector3, old_axis: Vector3, goal_axis: Vector3, hint: Vector3) -> Vector3:
	var bend := hint - old_axis * hint.dot(old_axis)
	if bend.length() < EPS:
		bend = knee - hip
		bend -= old_axis * bend.dot(old_axis)
	if bend.length() < EPS and last_bend.has(side):
		bend = between(last_axis[side], old_axis, last_bend[side]) * last_bend[side]
		bend -= old_axis * bend.dot(old_axis)
	if bend.length() < EPS:
		fallback_bends += 1
		var leg: Dictionary = legs[side]
		bend = between(leg.rest_axis, old_axis, leg.rest_bend) * leg.rest_bend
		bend -= old_axis * bend.dot(old_axis)
	if bend.length() < EPS:
		bend = _orthogonal(old_axis)
	bend = bend.normalized()
	# Transport the source pole rather than projecting a fixed world-forward pole,
	# which can change hemisphere when the goal crosses that direction.
	var transported := between(old_axis, goal_axis, bend) * bend
	transported -= goal_axis * transported.dot(goal_axis)
	if transported.length() < EPS:
		transported = _orthogonal(goal_axis)
	transported = transported.normalized()
	if continuity_max_angle > 0.0 and last_bend.has(side):
		var carried: Vector3 = between(last_axis[side], goal_axis, last_bend[side]) * last_bend[side]
		var angle := carried.angle_to(transported)
		if angle > continuity_max_angle:
			transported = carried.slerp(transported, continuity_max_angle / angle).normalized()
			continuity_limited_solves += 1
	last_axis[side] = goal_axis
	last_bend[side] = transported
	return transported

func set_global_rotation(bone: int, basis: Basis) -> void:
	var parent := rig.get_bone_parent(bone)
	var parent_basis := rig.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var rotation := (parent_basis.inverse() * basis.orthonormalized()).orthonormalized().get_rotation_quaternion().normalized()
	# Equivalent quaternion signs must not manufacture an angular-velocity discontinuity.
	if rotation.dot(rig.get_bone_pose_rotation(bone)) < 0.0:
		rotation = -rotation
	rig.set_bone_pose_rotation(bone, rotation)
	rig.force_update_all_bone_transforms()

func solve_leg(side: String, goal: Vector3, bend_hint: Vector3 = Vector3.ZERO, limit_unreachable: bool = true) -> Dictionary:
	assert(legs.has(side))
	assert(goal.is_finite() and bend_hint.is_finite())
	total_solves += 1
	rig.force_update_all_bone_transforms()
	var leg: Dictionary = legs[side]
	var hip := rig.get_bone_global_pose(leg.thigh).origin
	var knee := rig.get_bone_global_pose(leg.shin).origin
	var old_ankle := ankle(side)
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(old_ankle)
	if upper_length < EPS or lower_length < EPS:
		rejected_solves += 1
		return {"accepted": false, "reason": "degenerate input segment"}
	# Reject incoming scale/stretch; never repair it by altering the accepted anatomy.
	if absf(upper_length - leg.upper_length) > .00005 or absf(lower_length - leg.lower_length) > .00005:
		rejected_solves += 1
		return {"accepted": false, "reason": "incoming segment length differs from rest"}
	var vector := goal - hip
	var requested_distance := vector.length()
	var old_axis := _source_axis(side, old_ankle - hip)
	var goal_axis := vector.normalized() if requested_distance > EPS else old_axis
	var minimum := absf(upper_length - lower_length) + REACH_MARGIN
	var maximum := upper_length + lower_length - REACH_MARGIN
	var distance := clampf(requested_distance, minimum, maximum)
	var limited := absf(distance - requested_distance) > EPS
	if limited and not limit_unreachable:
		rejected_solves += 1
		return {"accepted": false, "reason": "unreachable target rejected", "requested_goal": goal, "reachable_distance": [minimum, maximum]}
	if limited:
		limited_solves += 1
	var limited_goal := hip + goal_axis * distance
	var bend := bend_for_goal(side, hip, knee, old_axis, goal_axis, bend_hint)
	var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var wanted_knee := hip + goal_axis * along + bend * height
	var foot_basis := rig.get_bone_global_pose(leg.foot).basis.orthonormalized()
	var toe_basis := rig.get_bone_global_pose(leg.toe).basis.orthonormalized()
	var upper_basis := rig.get_bone_global_pose(leg.thigh).basis.orthonormalized()
	var upper_delta := between((knee - hip).normalized(), (wanted_knee - hip).normalized(), bend)
	set_global_rotation(leg.thigh, Basis(upper_delta) * upper_basis)
	var current_knee := rig.get_bone_global_pose(leg.shin).origin
	var lower_basis := rig.get_bone_global_pose(leg.shin).basis.orthonormalized()
	var lower_delta := between((ankle(side) - current_knee).normalized(), (limited_goal - current_knee).normalized(), bend)
	set_global_rotation(leg.shin, Basis(lower_delta) * lower_basis)
	set_global_rotation(leg.foot, foot_basis)
	set_global_rotation(leg.toe, toe_basis)
	var result := ankle(side)
	assert(result.is_finite())
	return {"accepted": true, "limited": limited, "requested_goal": goal, "limited_goal": limited_goal,
		"actual_ankle": result, "goal_error_m": result.distance_to(goal), "limited_goal_error_m": result.distance_to(limited_goal),
		"bend_direction": bend, "knee": rig.get_bone_global_pose(leg.shin).origin,
		"source_lengths": [upper_length, lower_length], "segment_error_m": maxf(absf(hip.distance_to(rig.get_bone_global_pose(leg.shin).origin) - upper_length), absf(rig.get_bone_global_pose(leg.shin).origin.distance_to(result) - lower_length))}
