extends RefCounted
## Class grips applied after the approved arm and final-pose layers.
var skeleton: Skeleton3D
var class_title := ""
var hands: Array[int] = []
var weapon := -1
var raw_offset := Vector3.ZERO
var wrist_offsets: Array[Vector3] = []
var hand_rotations: Array[Basis] = []
var uppers: Array[int] = []
var forearms: Array[int] = []
var upper_lengths: Array[float] = []
var forearm_lengths: Array[float] = []
var handwork_weight := 0.0
var weapon_scale := Vector3.ONE
var staff_grip: Dictionary = {}

func build(title: String, rig: Skeleton3D) -> void:
 class_title = title
 skeleton = rig
 if title == "Ember": return
 hands = [rig.find_bone("DEF-hand.L"), rig.find_bone("DEF-hand.R")]
 weapon = rig.find_bone("staff" if title == "Luminary" else "weapon")
 assert(weapon >= 0 and hands[0] >= 0 and hands[1] >= 0)
 weapon_scale = rig.get_bone_pose_scale(weapon)
 if title == "Luminary":
  for bone in rig.get_bone_count():
   var name := String(rig.get_bone_name(bone))
   if name.ends_with(".R") and (name.begins_with("DEF-f_") or name.begins_with("DEF-thumb")):
    staff_grip[bone] = rig.get_bone_pose_rotation(bone)
 if title == "Vanguard":
  var inverse := rig.get_bone_global_pose(weapon).affine_inverse()
  for index in hands:
   var relative := inverse * rig.get_bone_global_pose(index)
   wrist_offsets.append(relative.origin)
   hand_rotations.append(relative.basis)
  for side in 2:
   var suffix := "L" if side==0 else "R"
   uppers.append(rig.find_bone("DEF-upper_arm."+suffix))
   forearms.append(rig.find_bone("DEF-forearm."+suffix))
   upper_lengths.append(rig.get_bone_rest(forearms[side]).origin.length())
   forearm_lengths.append(rig.get_bone_rest(hands[side]).origin.length())
 capture()

func midpoint() -> Vector3:
 return (skeleton.get_bone_global_pose(hands[0]).origin + skeleton.get_bone_global_pose(hands[1]).origin)*.5

func capture() -> void:
 if class_title == "Vanguard":
  # Undo only our temporary Mend concealment before evaluating the rigid grip.
  skeleton.set_bone_pose_scale(weapon,weapon_scale)
  raw_offset = skeleton.get_bone_global_pose(weapon).origin - midpoint()

func follow_jump() -> void:
 if class_title != "Vanguard": return
 var pose := skeleton.get_bone_global_pose(weapon)
 pose.origin = midpoint()+raw_offset
 set_global(weapon,pose)

func set_global(index: int, value: Transform3D) -> void:
 var parent := skeleton.get_bone_parent(index)
 skeleton.set_bone_pose(index, skeleton.get_bone_global_pose(parent).affine_inverse()*value if parent >= 0 else value)

func aim(index: int, child: int, target: Vector3) -> void:
 var pose := skeleton.get_bone_global_pose(index)
 var current := (skeleton.get_bone_global_pose(child).origin-pose.origin).normalized()
 var desired := (target-pose.origin).normalized()
 pose.basis = Basis(Quaternion(current,desired))*pose.basis
 set_global(index,pose)

func apply() -> void:
 if weapon < 0: return
 if class_title == "Vanguard": skeleton.set_bone_pose_scale(weapon,weapon_scale)
 var pose := skeleton.get_bone_global_pose(weapon)
 if class_title == "Luminary":
  var hand := skeleton.get_bone_global_pose(hands[1])
  pose.origin = hand*Vector3(0,.055,.012)
  # Blender's +Z staff becomes Godot +Y. Keep the upright authored basis.
  pose.basis = skeleton.get_bone_global_rest(weapon).basis
  set_global(weapon,pose)
  for bone in staff_grip:
   skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(staff_grip[bone],handwork_weight))
  return
 # Mend frees both arms. Save the authored pose before the usual two-hand
 # solve, then blend the solve away with the cast's entry/recovery weight.
 var work_pose: Dictionary = {}
 if handwork_weight > 0:
  for bone in uppers+forearms+hands: work_pose[bone] = skeleton.get_bone_pose(bone)
 # A short reach projection moves the rigid weapon, never scales either arm.
 for iteration in 8:
  var projected := false
  for side in 2:
   var origin := skeleton.get_bone_global_pose(uppers[side]).origin
   var a := upper_lengths[side]
   var b := forearm_lengths[side]
   var delta := pose*wrist_offsets[side]-origin
   if delta.length() > (a+b)*.95:
    pose.origin -= delta.normalized()*(delta.length()-(a+b)*.95)
    projected = true
  if not projected: break
 set_global(weapon,pose)
 for side in 2:
  var upper := uppers[side]
  var fore := forearms[side]
  var origin := skeleton.get_bone_global_pose(upper).origin
  var wrist := pose*wrist_offsets[side]
  var a := upper_lengths[side]
  var b := forearm_lengths[side]
  var delta := wrist-origin
  var distance := maxf(delta.length(),.001)
  var axis := delta/distance
  var along := (a*a-b*b+distance*distance)/(2*distance)
  var height := sqrt(maxf(0,a*a-along*along))
  var pole := Vector3(1 if side==0 else -1,-.45,-.1)
  var bend := (pole-axis*pole.dot(axis)).normalized()
  aim(upper,fore,origin+axis*along+bend*height)
  aim(fore,hands[side],wrist)
  set_global(hands[side],Transform3D(pose.basis*hand_rotations[side],wrist))
 for bone in work_pose:
  skeleton.set_bone_pose(bone,skeleton.get_bone_pose(bone).interpolate_with(work_pose[bone],handwork_weight))
 skeleton.set_bone_pose_scale(weapon,weapon_scale*(1.0-.999*handwork_weight))
