extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var model = load("res://assets/characters/fulcrum.glb").instantiate()
 root.add_child(model)
 var player: AnimationPlayer
 var skeleton: Skeleton3D
 for node in model.find_children("*","Node",true,false):
  if node is AnimationPlayer: player=node
  if node is Skeleton3D: skeleton=node
 for clip in ["Idle","JumpStart","JumpLoop","JumpLand"]:
  player.play(clip)
  for phase in [0.0,.25,.5,.75]:
   player.seek(player.get_animation(clip).length*phase,true)
   print(clip," ",phase," hands ",skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.L")).origin," ",skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.R")).origin)
   for side in ["L","R"]:
    var a := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-upper_arm."+side)).origin
    var b := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-forearm."+side)).origin
    var c := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand."+side)).origin
    print("elbow ",side," bend ",rad_to_deg((b-a).angle_to(c-b)))
 for i in skeleton.get_bone_count():
  if "arm" in skeleton.get_bone_name(i) or "shoulder" in skeleton.get_bone_name(i):print(skeleton.get_bone_name(i))
 model.queue_free(); await process_frame; quit()
