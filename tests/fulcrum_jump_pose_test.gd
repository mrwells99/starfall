extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func bend(rig: Skeleton3D, side: String) -> float:
 var a := rig.get_bone_global_pose(rig.find_bone("DEF-upper_arm."+side)).origin
 var b := rig.get_bone_global_pose(rig.find_bone("DEF-forearm."+side)).origin
 var c := rig.get_bone_global_pose(rig.find_bone("DEF-hand."+side)).origin
 return rad_to_deg((b-a).angle_to(c-b))
func run() -> void:
 var actor = load("res://scripts/combatant.gd").new()
 root.add_child(actor); actor.setup(1,1,0,"Fulcrum")
 var art = actor.champion_model.fulcrum_art
 var pose = art.jump_pose
 check(pose.bones.size() >= 30, "Both full arm chains including fingers are cached")
 actor.presentation_grounded = true; actor.champion_model.animate(.016,actor)
 var rest: Array[Quaternion] = []
 for index in pose.bones: rest.append(art.skeleton.get_bone_pose_rotation(index))
 actor.presentation_grounded = false
 var lifts: Array[float] = []
 var hands: Array = []
 for velocity in [7.0,5.0,3.0,0.0,-3.0,-5.0,-7.0]:
  actor.presentation_vertical_speed = velocity
  actor.position.y = maxf(0.0,(49.0-velocity*velocity)/40.0)
  actor.champion_model.animate(.05,actor)
  lifts.append(pose.lift)
  for side in ["L","R"]:
   check(bend(art.skeleton,side) > 25, "Elbow stays bent at vertical velocity %s on %s" % [velocity,side])
  hands.append([art.skeleton.get_bone_global_pose(art.skeleton.find_bone("DEF-hand.L")).origin.y,art.skeleton.get_bone_global_pose(art.skeleton.find_bone("DEF-hand.R")).origin.y])
 check(lifts[0] == 0 and lifts[3] == 1 and lifts[6] == 0, "Arms start lowered, peak at zero velocity and return on descent")
 check(lifts[0] < lifts[1] and lifts[1] < lifts[2] and lifts[2] < lifts[3], "Lift increases through ascent")
 check(lifts[3] > lifts[4] and lifts[4] > lifts[5] and lifts[5] > lifts[6], "Lift decreases through descent")
 check(is_equal_approx(lifts[1],lifts[5]) and is_equal_approx(lifts[2],lifts[4]), "Equal ascent/descent velocities use the same pose weight")
 for i in pose.bones.size():
  check(art.skeleton.get_bone_pose_rotation(pose.bones[i]).angle_to(rest[i]) < .001, "Arm returns to its original takeoff joint rotation")
 for side in 2:
  check(hands[3][side] > hands[0][side] and hands[3][side] > hands[6][side], "Wrist is higher at apex than takeoff/return")
 # Constant velocity must not cycle the arms with the looping jump clip.
 actor.presentation_vertical_speed = 0; actor.champion_model.animate(.016,actor)
 var held: Quaternion = art.skeleton.get_bone_pose_rotation(pose.bones[2])
 actor.champion_model.animate(.25,actor)
 check(held.angle_to(art.skeleton.get_bone_pose_rotation(pose.bones[2])) < .001, "Apex arm pose is independent of clip playback time")
 # Compare the authored weapon-hand offset before and after the arm layer.
 art.player.play(art.clip_names["JumpLoop"]); art.player.advance(.01)
 var offset: Vector3 = art.skeleton.get_bone_global_pose(pose.focus).origin - art.skeleton.get_bone_global_pose(pose.hand).origin
 pose.apply(0,true,.016,false)
 var corrected: Vector3 = art.skeleton.get_bone_global_pose(pose.focus).origin - art.skeleton.get_bone_global_pose(pose.hand).origin
 check(offset.distance_to(corrected) < .0001, "Gravity weapon retains its authored hand-relative offset")
 # Replicated velocity is cosmetic and does not overwrite local simulation.
 var state: Dictionary = actor.snapshot(); state.grounded=false; state.velocity=Vector3(0,-3,0)
 actor.velocity=Vector3(2,5,1); actor.receive(state)
 actor.champion_model.animate(.016,actor)
 check(is_equal_approx(pose.lift,1.0-9.0/49.0) and actor.velocity == Vector3(2,5,1), "Remote jump uses snapshot velocity without changing movement")
 actor.presentation_grounded=true
 for i in 12: actor.champion_model.animate(1.0/60.0,actor)
 check(pose.weight == 0 and art.clip == "Idle", "Landing releases the arm layer")
 # End the remote fixture; the following cadence probes author local displacement.
 actor.presentation_snapshot_serial=0
 for travel_speed in [1.2,4.0,6.5]:
  var physical_velocity: Vector3 = actor.velocity
  for i in 60:
   actor.position += Vector3.FORWARD*travel_speed/60.0
   actor.champion_model.animate(1.0/60.0,actor)
  var expected: float = travel_speed/(4.4 if travel_speed>5.5 else (2.8 if travel_speed>1.8 else 1.35))
  if travel_speed>1.8: expected*=.9
  check(absf(art.player.speed_scale-expected)<.005, "Only jog/sprint cadence is ten percent slower at %s m/s" % travel_speed)
  check(actor.velocity==physical_velocity, "Cadence change does not modify gameplay velocity")
 print("JUMP_ARM_MEASUREMENTS ",hands)
 actor.queue_free(); await process_frame
 print("Fulcrum jump arms: %d passed / %d total" % [checks-failures,checks])
 quit(1 if failures else 0)
