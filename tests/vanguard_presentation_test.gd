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
 check(art.skeleton.get_bone_count() == 45, "Full skeleton with six cape controls imported")
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
 var textured := 0
 var names: Array[String] = []
 for material in art.materials:
  names.append(material.resource_name)
  if material.albedo_texture != null:textured += 1
  check(not ("Skin" in material.resource_name or "Hair" in material.resource_name), "Sealed armor has no facial or hair material")
 check(textured >= 4, "Steel, alloy, cloth and crystal textures survive import")
 check("Vanguard_SealedVisorShadow" in names, "Sealed visor is imported")
 for bone_name in ["cape0","cape1","cape2","cape_tip0","cape_tip1","cape_tip2"]:
  var bone_index: int = art.skeleton.find_bone(bone_name)
  check(bone_index >= 0, "Cape control imported: " + bone_name)
  art.player.play(art.clip_names["Walk"]);art.player.seek(0,true)
  var start: Quaternion = art.skeleton.get_bone_pose_rotation(bone_index)
  art.player.seek(.6,true)
  check(start.angle_to(art.skeleton.get_bone_pose_rotation(bone_index)) > .003, "Cape moves during walk: " + bone_name)
 actor.flash = .1;visual.animate(.01,actor)
 check(art.materials[0].emission_enabled and art.materials[0].emission == Color.WHITE, "Textured armor has a visible impact flash")
 check(other.champion_model.vanguard_art.materials[0].emission == other.champion_model.vanguard_art.base_emissions[0], "Impact flash does not leak to another actor")
 actor.flash = 0;visual.animate(.01,actor)
 check(art.materials[0].emission == art.base_emissions[0], "Impact flash restores authored emission")
 # A hit must change uniform values without toggling shader features.
 for i in art.materials.size():
  var material: StandardMaterial3D = art.materials[i]
  check(material.emission_enabled, "Emission feature remains stable between hits")
  check(is_equal_approx(material.emission_energy_multiplier, art.base_emission_energy[i]), "Original glow energy is restored")
  if not art.base_emission_enabled[i]:
   check(is_zero_approx(material.emission_energy_multiplier), "Non-emissive armour stays dark between hits")
 actor.flash = .1;visual.animate(.01,actor)
 for material in art.materials:
  check(material.emission_enabled and is_equal_approx(material.emission_energy_multiplier, 2.0), "All surfaces flash without changing shader features")
 actor.flash = 0;actor.hp = 0;visual.animate(.01,actor)
 for i in art.materials.size():
  check(art.materials[i].emission_enabled and is_equal_approx(art.materials[i].emission_energy_multiplier, art.base_emission_energy[i] * .15), "Defeat dims energy without changing shader features")
 actor.hp = 100;visual.animate(.01,actor)
 var strike_fx = load("res://scripts/vanguard_strike.gd")
 var warmup: Node3D = visual.get_node("VanguardStrikeWarmup")
 var children_before: int = visual.get_child_count()
 strike_fx.prewarm(visual)
 check(not warmup.visible and visual.get_child_count() == children_before, "Character loading prewarms hidden impact resources only once")
 var effects := Node3D.new()
 root.add_child(effects)
 strike_fx.spawn(effects, Vector3.ZERO, Vector3.ZERO, Color.RED)
 check(effects.get_child_count() == 0, "Zero-length impacts remain suppressed")
 strike_fx.spawn(effects, Vector3.ZERO, Vector3.FORWARD, Color.RED)
 strike_fx.spawn(effects, Vector3.RIGHT, Vector3.RIGHT + Vector3.FORWARD, Color.BLUE)
 var first: Node3D = effects.get_child(0)
 var second: Node3D = effects.get_child(1)
 var first_arc: MeshInstance3D = first.get_node("Arc")
 var second_arc: MeshInstance3D = second.get_node("Arc")
 check(first_arc.mesh == second_arc.mesh, "Concurrent strikes reuse arc geometry")
 check(first.get_node("Impact").get_child(0).mesh == second.get_node("Impact").get_child(0).mesh, "Concurrent strikes reuse spark geometry")
 check(first_arc.material_override != second_arc.material_override, "Concurrent strikes own independent fade materials")
 check(first_arc.material_override.emission == Color.RED.lightened(.4) and second_arc.material_override.emission == Color.BLUE.lightened(.4), "Concurrent strike team colours stay independent")
 first_arc.material_override.albedo_color.a = .25
 check(is_equal_approx(second_arc.material_override.albedo_color.a, 1.0), "Fading one strike does not fade another")
 await create_timer(.35).timeout
 await process_frame
 check(effects.get_child_count() == 0, "Both transient strike effects clean up after their animations")
 check(is_instance_valid(warmup), "Prewarmed resources survive transient effect cleanup")
 effects.queue_free()
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
