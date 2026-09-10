extends RefCounted
## Short transitions between final visible poses, including the jump arm layer.
## Capturing the displayed pose also permits interruption without snapping back.
var skeleton: Skeleton3D
var from_pose: Array[Transform3D] = []
var elapsed := 0.0
var duration := 0.0
var body_duration := 0.0
var body_bones: PackedInt32Array = []

func build(rig: Skeleton3D) -> void:
 skeleton = rig
 from_pose.resize(skeleton.get_bone_count())
 for name in ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head"]:
  var index := skeleton.find_bone(name)
  if index >= 0: body_bones.append(index)

static func is_locomotion(name: String) -> bool:
 return name.begins_with("Walk") or name.begins_with("Run") or name.begins_with("Sprint") or name.begins_with("Strafe")

static func duration_for(previous: String, next: String) -> float:
 if next == "JumpStart": return .08
 if previous.begins_with("Cast") or next.begins_with("Cast"): return .12
 if is_locomotion(previous) and is_locomotion(next): return .12
 return .10

func begin(seconds: float, body_seconds: float = 0.0) -> void:
 duration = maxf(seconds, .001)
 body_duration = maxf(duration, body_seconds)
 elapsed = 0.0
 for i in from_pose.size(): from_pose[i] = skeleton.get_bone_pose(i)

func apply(delta: float) -> void:
 if duration <= 0.0 or elapsed >= body_duration: return
 elapsed = minf(body_duration, elapsed + maxf(delta, 0.0))
 var progress := minf(elapsed / duration, 1.0)
 # Smoothstep has gentle start/end slopes and reaches the target on time.
 var blend := progress * progress * (3.0 - 2.0 * progress)
 var body_progress := elapsed / body_duration
 var body_blend := body_progress * body_progress * (3.0 - 2.0 * body_progress)
 for i in from_pose.size():
  skeleton.set_bone_pose(i, from_pose[i].interpolate_with(skeleton.get_bone_pose(i), body_blend if i in body_bones else blend))
