extends RefCounted
## Shared baked upper-body wind-up; no runtime IK, root motion or gameplay timer writes.
const LIBRARY = preload("res://assets/animations/null_blindside.res")
var rig: Skeleton3D
var animation: Animation
var bones := PackedInt32Array()
var entry: Array[Quaternion] = []
var release: Array[Quaternion] = []
var active := false
var release_left := 0.0
var elapsed := 0.0
var last_action_serial := -1
var clock = preload("res://scripts/snapshot_animation_clock.gd").new()

func build(skeleton: Skeleton3D) -> void:
	rig = skeleton
	animation = LIBRARY.get_animation("BlindsideCross")
	for tr in animation.get_track_count():
		bones.append(rig.find_bone(animation.track_get_path(tr).get_subname(0)))
		assert(bones[-1] >= 0)

func smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t*t*t*(10.0+t*(-15.0+6.0*t))

func prepare(actor, delta: float) -> void:
	var casting: bool = actor.hp > 0 and actor.stunned <= 0 and actor.casting >= 0 and actor.kit[actor.casting].kind == "blindside"
	if casting and not active:
		entry.clear()
		for bone in bones: entry.append(rig.get_bone_pose_rotation(bone))
		clock.reset(); release_left = 0.0
	elif active and not casting:
		release.clear()
		for bone in bones: release.append(rig.get_bone_pose_rotation(bone))
		release_left = .18
	active = casting
	if active:
		var duration: float = actor.kit[actor.casting].cast
		# Reuse the full smooth baked gesture at the current gameplay cast duration.
		elapsed = clock.advance(duration-actor.cast_left, delta, actor.presentation_snapshot_serial, actor.motion_revision, duration) * animation.length / duration
	elif actor.hp <= 0 or actor.stunned > 0:
		release_left = 0.0
	# A subsequent attack owns its arms immediately; it already captures the displayed pose.
	var serial: int = actor.identity.get("null_action_serial", 0)
	if not active and serial != last_action_serial and actor.identity.get("null_action", "") != "blindside":
		release_left = 0.0
	last_action_serial = serial

func apply(delta: float) -> void:
	if active:
		# Decay the difference from the actual incoming pose while the baked gesture advances.
		var carry := 1.0-smooth(elapsed/.27)
		for tr in bones.size():
			var start := animation.rotation_track_interpolate(tr, 0.0)
			var target := animation.rotation_track_interpolate(tr, elapsed)
			var offset := entry[tr]*start.inverse()
			rig.set_bone_pose_rotation(bones[tr], (Quaternion.IDENTITY.slerp(offset,carry)*target).normalized())
	elif release_left > 0.0:
		release_left = maxf(0.0, release_left-maxf(delta,0.0))
		var weight := smooth(release_left/.18)
		for i in bones.size():
			var bone := bones[i]
			rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone).slerp(release[i],weight))
