extends RefCounted
## Source-native jab/cut upper-body layer, shared by visible and server rigs.
const LIBRARY = preload("res://assets/animations/null_strikes_v3.tres")
const PROFILES := {
	"stab": {"clip":"Punch_Jab", "duration":.44, "start":.035, "end":.70, "entry":.085, "release":.14, "body":.35},
	"backstab": {"clip":"Sword_Attack", "duration":.52, "start":.22, "end":.83, "entry":.10, "release":.16, "body":.5}
}
var skeleton: Skeleton3D
var bones: Array[int] = []
var names: Array[String] = []
var entry: Array[Quaternion] = []
var elapsed := 0.0
var remaining := 0.0
var profile: Dictionary = {}
var animation: Animation

func build(rig: Skeleton3D) -> void:
	skeleton = rig
	var reference: Animation = LIBRARY.get_animation("Punch_Jab")
	for track in reference.get_track_count():
		var name := String(reference.track_get_path(track).get_subname(0))
		names.append(name)
		bones.append(skeleton.find_bone(name))
		assert(bones[-1] >= 0)

func begin(kind: String) -> void:
	profile = PROFILES[kind]
	animation = LIBRARY.get_animation(profile.clip)
	elapsed = 0.0
	remaining = profile.duration
	entry.clear()
	# Snapshot the actual displayed pose, including Stealth and interrupted hits.
	for bone in bones: entry.append(skeleton.get_bone_pose_rotation(bone))

func apply(delta: float, enabled: bool) -> void:
	if remaining <= 0.0: return
	if not enabled:
		remaining = 0.0
		return
	elapsed = minf(float(profile.duration), elapsed + maxf(delta,0))
	remaining = maxf(0,float(profile.duration) - elapsed)
	var progress := elapsed / float(profile.duration)
	# Continuous interpolation preserves the acceleration authored in the library.
	var source_time := lerpf(float(profile.start),float(profile.end),progress)
	var blend_in := smoothstep(0,float(profile.entry),elapsed)
	var blend_out := smoothstep(0,float(profile.release),remaining)
	for track in bones.size():
		var bone := bones[track]
		var base := skeleton.get_bone_pose_rotation(bone)
		var target := animation.rotation_track_interpolate(track,source_time)
		if names[track].begins_with("DEF-shoulder"):
			var parent := skeleton.get_bone_parent(bone)
			target = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion().inverse() * target
		var weight := 1.0
		if names[track].begins_with("DEF-spine"): weight = profile.body
		elif names[track] in ["DEF-neck","DEF-head"]: weight = .15
		# Keep the support hand near its existing guard instead of boxing with it.
		elif names[track].ends_with(".R") and profile.clip == "Punch_Jab": weight = .55
		elif names[track].ends_with(".L") and profile.clip == "Sword_Attack": weight = .35
		target = base.slerp(target,weight)
		var strike := entry[track].slerp(target,blend_in)
		skeleton.set_bone_pose_rotation(bone,base.slerp(strike,blend_out))
