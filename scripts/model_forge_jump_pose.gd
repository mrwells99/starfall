extends RefCounted
## Arms follow the physical jump arc, rather than the looping clip's clock.
## 7 m/s is the current gameplay takeoff speed; no physics is changed here.
const REFERENCE_TAKEOFF_SPEED := 7.0
var bones: Array[int] = []
var apex: Array[Quaternion] = []
var takeoff: Array[Quaternion] = []
var skeleton: Skeleton3D
var lift := 0.0
var weight := 0.0
var launch_speed := REFERENCE_TAKEOFF_SPEED

func build(rig: Skeleton3D, player: AnimationPlayer, jump_clip: String) -> void:
 skeleton = rig
 for side in ["L", "R"]:
  var shoulder := skeleton.find_bone("DEF-shoulder." + side)
  for index in skeleton.get_bone_count():
   var ancestor := index
   while ancestor >= 0:
    if ancestor == shoulder:
     bones.append(index)
     break
    ancestor = skeleton.get_bone_parent(ancestor)
 player.play(jump_clip)
 # The source takeoff's quarter pose has relaxed elbows (~51/72 degrees),
 # whereas its airborne loop approaches a straight left elbow.
 player.seek(player.get_animation(jump_clip).length * .25, true)
 for index in bones:
  apex.append(skeleton.get_bone_pose_rotation(index))
  takeoff.append(skeleton.get_bone_pose_rotation(index))

func begin(vertical_speed: float) -> void:
 # Preserve the actual arms at takeoff, including the current running pose.
 for i in bones.size(): takeoff[i] = skeleton.get_bone_pose_rotation(bones[i])
 launch_speed = maxf(REFERENCE_TAKEOFF_SPEED, vertical_speed)
 weight = 1.0

func apply(vertical_speed: float, airborne: bool, delta: float, casting: bool) -> void:
 # h/h_apex = 1 - (v/v_takeoff)^2 for a ballistic jump. Both halves use
 # the same curve: zero near takeoff, one at apex, zero on the return.
 lift = clampf(1.0 - pow(vertical_speed / launch_speed, 2.0), 0.0, 1.0) if airborne else 0.0
 weight = 1.0 if airborne else move_toward(weight, 0.0, delta / .12)
 if weight <= 0.0 or casting: return
 for i in bones.size():
  var desired := takeoff[i].slerp(apex[i], lift)
  skeleton.set_bone_pose_rotation(bones[i], skeleton.get_bone_pose_rotation(bones[i]).slerp(desired, weight))
