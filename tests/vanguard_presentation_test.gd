extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var actor = load("res://scripts/combatant.gd").new()
 root.add_child(actor)
 actor.setup(1,1,0,"Vanguard")
 var visual = actor.champion_model
 var art = visual.vanguard_art
 check(art != null, "Vanguard uses the authored presentation")
 check(art.skeleton.get_bone_count() >= 35, "Full deformation skeleton imported")
 check(visual.torso != null and visual.torso.skin != null, "The model is skinned")
 print("Imported clips: ", art.player.get_animation_list())
 for clip in ["Idle","Walk","Run","WalkBackward","StrafeLeft","StrafeRight","Cast","Strike"]:
  check(art.clip_names.has(clip), "Clip imported: " + clip)
  if art.clip_names.has(clip):
   var anim: Animation = art.player.get_animation(art.clip_names[clip])
   check(anim.length > 0.5 and anim.get_track_count() > 20, "Clip has skeletal motion: " + clip)
   check(anim.loop_mode == (Animation.LOOP_NONE if clip == "Strike" else Animation.LOOP_LINEAR), "Clip loop behavior: " + clip)
   # Compare start/end skeleton poses after evaluating animation tracks.
   art.player.play(art.clip_names[clip]);art.player.seek(0,true)
   var poses: Array[Transform3D] = []
   for i in art.skeleton.get_bone_count():poses.append(art.skeleton.get_bone_pose(i))
   art.player.seek(anim.length-0.0001,true)
   for i in art.skeleton.get_bone_count():
    check(poses[i].origin.distance_to(art.skeleton.get_bone_pose(i).origin) < 0.003, "Loop translation closes: " + clip)
    check(poses[i].basis.get_rotation_quaternion().angle_to(art.skeleton.get_bone_pose(i).basis.get_rotation_quaternion()) < 0.012, "Loop rotation closes: " + clip)
 actor.champion_model.animate(1.0/60,actor)
 for i in 25:
  actor.position.z -= 1.5/60
  visual.animate(1.0/60,actor)
 check(art.clip == "Walk", "Forward movement plays Walk")
 for i in 35:
  actor.position.x -= 1.5/60
  visual.animate(1.0/60,actor)
 check(art.clip == "StrafeLeft", "Lateral movement plays StrafeLeft")
 for i in 35:
  actor.position.z += 1.5/60
  visual.animate(1.0/60,actor)
 check(art.clip == "WalkBackward", "Backward movement plays WalkBackward")
 actor.casting=0;visual.animate(.1,actor)
 check(art.clip == "Cast", "Casting transitions to authored Cast")
 actor.casting=-1
 for i in 90:visual.animate(1.0/60,actor)
 check(art.clip == "Idle", "Stopping blends to Idle")
 var transform_before: Transform3D = actor.transform
 actor.hp=0;visual.animate(.4,actor)
 check(visual.rotation.x < -1, "Defeat presentation retained")
 check(actor.transform == transform_before, "Animation never alters combat transform")
 actor.hp=100;visual.animate(.4,actor)
 check(is_zero_approx(visual.rotation.x), "Revive restores upright model")
 var collision: CollisionShape3D=actor.get_child(0)
 check(is_equal_approx(collision.shape.radius,.42) and is_equal_approx(collision.shape.height,1.8), "Collision dimensions preserved")
 visual.present_strike()
 visual.animate(.01,actor)
 check(art.clip == "Strike" and art.attack_left > 0, "Confirmed hit immediately starts hammer response")
 for i in 65:visual.animate(.02,actor)
 check(art.clip == "Idle", "Hammer attack recovers to idle")
 actor.shield=5;visual.animate(.01,actor)
 check(art.ward.visible and art.pulse.visible, "Iron Skin activates persistent ward and initial pulse")
 for i in 30:visual.animate(.02,actor)
 check(art.ward.visible and not art.pulse.visible, "Shield pulse expires independently")
 actor.shield=0;visual.animate(.01,actor)
 check(not art.ward.visible, "Dispel clears shield presentation")
 actor.hp=80;visual.animate(.01,actor)
 check(art.recoil_left>0, "HP loss triggers recoil")
 visual.animate(.3,actor);actor.hp=100;visual.animate(.01,actor)
 check(is_zero_approx(art.recoil_left), "Healing does not trigger recoil")
 actor.stunned=2
 var time_before: float=art.player.current_animation_position
 visual.animate(.1,actor)
 check(is_equal_approx(time_before,art.player.current_animation_position), "Stun pauses skeletal playback")
 actor.stunned=0
 for child in visual.find_children("*", "Node",true,false):
  check(not child is CollisionObject3D, "Authored art has no collision objects")
 var other=load("res://scripts/combatant.gd").new()
 root.add_child(other);other.setup(2,2,1,"Vanguard")
 check(art.materials[0] != other.champion_model.vanguard_art.materials[0], "Material state is isolated between actors")
 check(art.forged_materials[0] != other.champion_model.vanguard_art.forged_materials[0], "Shader state is isolated between actors")
 var triangles := 0
 for child in visual.find_children("*", "MeshInstance3D",true,false):
  for surface in child.mesh.get_surface_count():
   var arrays: Array = child.mesh.surface_get_arrays(surface)
   triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size())/3
 check(triangles < 130000, "Complete character stays below authored 130k triangle ceiling")
 print("Vanguard triangles: ",triangles)
 other.queue_free()
 print("Vanguard presentation: %d passed / %d total" % [checks-failures,checks])
 actor.queue_free();await process_frame
 quit(1 if failures else 0)
