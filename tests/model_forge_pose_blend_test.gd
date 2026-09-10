extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func read_pose(rig: Skeleton3D) -> Array[Transform3D]:
 var result: Array[Transform3D] = []
 for i in rig.get_bone_count(): result.append(rig.get_bone_pose(i))
 return result
func restore(rig: Skeleton3D, pose: Array[Transform3D]) -> void:
 for i in pose.size(): rig.set_bone_pose(i,pose[i])
func difference(a: Array[Transform3D], b: Array[Transform3D]) -> float:
 var result := 0.0
 for i in a.size():
  result=maxf(result,a[i].origin.distance_to(b[i].origin))
  result=maxf(result,a[i].basis.get_rotation_quaternion().angle_to(b[i].basis.get_rotation_quaternion()))
 return result
func run() -> void:
 var actor = load("res://scripts/combatant.gd").new()
 root.add_child(actor); actor.setup(1,1,0,"Ember")
 var art = actor.champion_model.ember_art
 var blend = art.pose_blend
 var rig: Skeleton3D = art.skeleton
 var clips: Array = art.clip_names.keys()
 for index in clips.size():
  var source: String = clips[index]
  var target: String = clips[(index+1)%clips.size()]
  art.player.play(art.clip_names[source],0); art.player.seek(art.player.current_animation_length*.2,true)
  var before := read_pose(rig)
  var seconds: float = blend.duration_for(source,target)
  check(seconds>=.08 and seconds<=.12,"Every clip has a short bounded transition")
  blend.begin(seconds)
  art.player.play(art.clip_names[target],0); art.player.seek(art.player.current_animation_length*.45,true)
  var after := read_pose(rig)
  blend.apply(0)
  check(difference(before,read_pose(rig))<.001,"Changing to "+target+" does not snap the displayed pose")
  restore(rig,after); blend.apply(seconds*.5)
  var middle := read_pose(rig)
  check(difference(before,middle)>.001 and difference(after,middle)>.001,"Transition actually passes through an intermediate pose: "+target)
  restore(rig,after); blend.apply(seconds*.5)
  check(difference(after,read_pose(rig))<.001 and blend.elapsed==blend.duration,"Target pose fully reached within 120 ms: "+target)
 # A jump may give only the torso/head a little more time to catch up.
 art.player.play(art.clip_names["SprintLeft"],0); art.player.seek(.2,true)
 var jump_from := read_pose(rig)
 blend.begin(.08,.16)
 art.player.play(art.clip_names["JumpStart"],0); art.player.seek(.12,true)
 var jump_to := read_pose(rig)
 blend.apply(.08)
 var softened := read_pose(rig)
 var chest := rig.find_bone("DEF-spine.003")
 var upper_arm := rig.find_bone("DEF-upper_arm.L")
 check(softened[chest].basis.get_rotation_quaternion().angle_to(jump_to[chest].basis.get_rotation_quaternion())>.001,"Jump torso continues easing after the short arm transition")
 check(softened[upper_arm].basis.get_rotation_quaternion().angle_to(jump_to[upper_arm].basis.get_rotation_quaternion())<.001,"Jump arm reaches its original target on its unchanged schedule")
 check(difference(jump_from,softened)>.001,"Directional takeoff pose moves toward the existing jump")
 restore(rig,jump_to); blend.apply(.08)
 check(difference(jump_to,read_pose(rig))<.001,"Torso reaches the unchanged authored jump pose within 160 ms")
 # A new input during a blend starts at the pose currently on screen.
 blend.begin(.12)
 art.player.play(art.clip_names["StrafeLeft"],0); art.player.advance(.02); blend.apply(.04)
 var interrupted := read_pose(rig)
 blend.begin(.12)
 art.player.play(art.clip_names["StrafeRight"],0); art.player.advance(.02); blend.apply(0)
 check(difference(interrupted,read_pose(rig))<.001,"Rapid reversal does not restart from an old clip pose")
 actor.presentation_grounded=true; art.clip="Idle"; art.player.play(art.clip_names["Idle"],0); art.player.advance(0)
 blend.duration=0; blend.elapsed=0; art.initialized=false
 actor.champion_model.animate(.016,actor)
 var motions := [Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3.BACK,Vector3.ZERO]
 var expected := ["Sprint","SprintLeft","SprintRight","WalkBackward","Idle"]
 for i in motions.size():
  actor.position+=motions[i]*6.5*.001
  var physical_transform: Transform3D = actor.transform
  var physical_velocity: Vector3 = actor.velocity
  var before := read_pose(rig)
  actor.champion_model.animate(.001,actor)
  check(art.clip==expected[i],"New direction selects its clip in the same update")
  check(difference(before,read_pose(rig))<.01,"First transition frame moves gently despite immediate input selection")
  check(actor.transform==physical_transform and actor.velocity==physical_velocity,"Smoothing never delays or modifies physical movement")
 actor.casting=0; actor.champion_model.animate(.001,actor)
 check(art.clip=="CastEnter" and blend.duration==.12,"Casting uses the final-pose transition")
 actor.stunned=1
 var elapsed_before: float=blend.elapsed
 var stunned_pose:=read_pose(rig)
 actor.champion_model.animate(.2,actor)
 check(blend.elapsed==elapsed_before and difference(stunned_pose,read_pose(rig))<.001,"Stun pauses transitions along with animation playback")
 actor.stunned=0; actor.casting=-1; actor.cast_left=0
 actor.presentation_grounded=false; actor.presentation_vertical_speed=7
 actor.champion_model.animate(.001,actor)
 check(art.clip=="JumpStart" and blend.duration==.08,"Takeoff uses a quicker transition to stay responsive")
 check(is_equal_approx(blend.body_duration,.16),"Only jump boundaries add a small torso/head easing window")
 actor.queue_free(); await process_frame
 print("Model Forge pose transitions: %d passed / %d total" % [checks-failures,checks])
 quit(1 if failures else 0)
