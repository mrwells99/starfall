extends RefCounted
# Blender-authored Fulcrum presentation. Combat and collision remain on the actor.
var asset: PackedScene
var pose_only := false
const RUN_CADENCE_SCALE := .90
const BACKPEDAL_CADENCE_SCALE := 1.15
const BACKPEDAL_REFERENCE_SPEED := 3.8
const JUMP_BODY_BLEND_SECONDS := .16
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var last_position := Vector3.ZERO
var initialized := false
var filtered_speed := 0.0
var clip := "Idle"
var clip_names: Dictionary = {}
var materials: Array[StandardMaterial3D] = []
var material_state := -1
var base_colors: Array[Color] = []
var was_casting := false
var was_airborne := false
var transient_clip := ""
var transient_left := 0.0
var previous_gcd := 0.0
var previous_cooldowns: Array = []
var previous_cast_remaining := 0.0
var jump_pose = preload("res://scripts/fulcrum_jump_pose.gd").new()
var pose_blend = preload("res://scripts/fulcrum_pose_blend.gd").new()
var lasso_pose = preload("res://scripts/lasso_pose.gd").new()
var network_motion = preload("res://scripts/network_animation_motion.gd").new()

func build(host: Node3D, team_color: Color) -> void:
 if asset == null: asset = preload("res://scripts/character_asset_cache.gd").get_scene("res://assets/characters/fulcrum.glb")
 model = asset.instantiate()
 model.name = "FulcrumAuthored"
 # Blender -Y is glTF +Z; game combatants face -Z.
 model.rotation.y = PI
 host.add_child(model)
 for child in model.find_children("*", "Node", true, false):
  if child is AnimationPlayer:
   player = child
  if child is Skeleton3D:
   skeleton = child
  if child is MeshInstance3D:
   if host.torso == null or child.name == "Fulcrum_SkinnedModel":
    host.torso = child
   for surface in child.mesh.get_surface_count():
    var original: Material = child.mesh.surface_get_material(surface)
    if original is StandardMaterial3D:
     var material: StandardMaterial3D = original.duplicate()
     material.cull_mode = BaseMaterial3D.CULL_DISABLED
     if "TeamInlay" in material.resource_name:
      material.albedo_color = team_color
     child.set_surface_override_material(surface, material)
     materials.append(material)
     base_colors.append(material.albedo_color)
 assert(player != null and skeleton != null, "Fulcrum requires its imported skeleton and animations")
 preload("res://scripts/character_asset_cache.gd").restore_libraries(model,player)
 for animation_name in player.get_animation_list():
  var short_name: String = String(animation_name).get_slice("/", String(animation_name).count("/"))
  clip_names[short_name] = animation_name
  if short_name != "RESET":
   player.get_animation(animation_name).loop_mode = Animation.LOOP_NONE if short_name in ["CastEnter", "CastRelease", "CastExit", "JumpStart", "JumpLand"] else Animation.LOOP_LINEAR
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 jump_pose.build(skeleton, player, clip_names["JumpStart"])
 player.play(clip_names["Idle"])
 player.advance(0)
 pose_blend.build(skeleton)
 lasso_pose.build(skeleton)

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
 lasso_pose.capture_if_needed(actor)
 var displacement := Vector3.ZERO
 if initialized and delta > 0:
  displacement = actor.global_position - last_position
  displacement.y = 0
  if displacement.length() > 1.0:
   displacement = Vector3.ZERO
 last_position = actor.global_position
 initialized = true
 displacement = network_motion.displacement(actor, displacement, delta)
 var measured := displacement.length() / maxf(delta, 0.0001)
 filtered_speed = measured
 var alive: bool = actor.hp > 0
 var stunned: bool = actor.stunned > 0
 var casting: bool = actor.casting >= 0 and alive
 var resolved_action := false
 if previous_cooldowns.size() == actor.cooldowns.size():
  for i in actor.cooldowns.size():
   resolved_action = resolved_action or float(actor.cooldowns[i]) > float(previous_cooldowns[i]) + .15
   previous_cooldowns[i] = actor.cooldowns[i]
 else:
  previous_cooldowns = actor.cooldowns.duplicate()
 var instant_action: bool = not casting and not was_casting and (resolved_action or actor.gcd > previous_gcd + .15)
 previous_gcd = actor.gcd
 var desired := "Idle"
 var rate := 1.0
 var vertical_speed: float = network_motion.vertical(actor, delta)
 if alive and not stunned:
  var previous_transient := transient_left
  transient_left = maxf(0.0, transient_left - delta)
  if previous_transient > 0 and transient_left == 0 and transient_clip == "CastRelease":
   transient_clip = "CastExit"; transient_left = player.get_animation(clip_names["CastExit"]).length
  if filtered_speed > 0.12:
   var local_motion := actor.global_basis.inverse() * displacement
   var running := filtered_speed > 1.8
   var sprinting := filtered_speed > 5.5
   var prefix := "Sprint" if sprinting else ("Run" if running else "Walk")
   # Eight sectors in actor-local space: forward, diagonals, sides, back.
   var angle := atan2(local_motion.x, -local_motion.z)
   var sector := posmod(roundi(angle / (PI / 4.0)), 8)
   var backpedaling := sector in [3, 4, 5]
   if backpedaling: prefix = "Walk"
   var suffixes := ["", "ForwardRight", "Right", "BackwardRight", "Backward", "BackwardLeft", "Left", "ForwardLeft"]
   desired = prefix + suffixes[sector]
   if not running and sector in [2, 6]: desired = "StrafeRight" if sector == 2 else "StrafeLeft"
   rate = clampf(filtered_speed / (4.4 if sprinting else (2.8 if running else 1.35)), 0.55, 2.5)
   if backpedaling:
    # Use the reversed walking gait, even at normal/buffed travel speeds.
    rate = clampf(filtered_speed / BACKPEDAL_REFERENCE_SPEED * BACKPEDAL_CADENCE_SCALE, .55, 2.5)
   elif running: rate *= RUN_CADENCE_SCALE
  var airborne := not actor.is_on_floor() and (was_airborne or absf(actor.velocity.y) > .1)
  if actor.presentation_grounded != null:
   airborne = not bool(actor.presentation_grounded)
  if airborne:
   if not was_airborne:
    jump_pose.begin(vertical_speed)
    transient_clip = "JumpStart"; transient_left = minf(.18, player.get_animation(clip_names["JumpStart"]).length)
   desired = "JumpStart" if transient_left > 0 and transient_clip == "JumpStart" else "JumpLoop"
   rate = 1.0
  elif was_airborne:
   transient_clip = "JumpLand"; transient_left = .15
  if casting:
   if not was_casting:
    transient_clip = "CastEnter"; transient_left = player.get_animation(clip_names["CastEnter"]).length
   desired = "CastEnter" if transient_left > 0 and transient_clip == "CastEnter" else "Cast"
   rate = 1.0
  elif was_casting:
   transient_clip = "CastRelease" if resolved_action or previous_cast_remaining <= delta + .05 else "CastExit"
   transient_left = player.get_animation(clip_names[transient_clip]).length
  elif instant_action:
   transient_clip = "CastRelease"; transient_left = player.get_animation(clip_names["CastRelease"]).length
  if not casting and not airborne and transient_left > 0 and filtered_speed <= .12:
   desired = transient_clip; rate = 1.0
  was_airborne = airborne
  was_casting = casting
 elif not alive:
  was_casting = false; was_airborne = false; transient_left = 0
  jump_pose.weight = 0.0
 else:
  desired = clip
  was_casting = casting
 previous_cast_remaining = actor.cast_left
 if desired != clip:
  var phase := player.current_animation_position / maxf(player.current_animation_length, .001)
  var locomotion_change := is_locomotion(clip) and is_locomotion(desired)
  # A little extra easing for the torso/head when entering or changing jump
  # clips. Keep the same authored poses and the existing arm transition.
  var jump_transition := desired.begins_with("Jump") or clip.begins_with("Jump")
  pose_blend.begin(pose_blend.duration_for(clip, desired), JUMP_BODY_BLEND_SECONDS if jump_transition else 0.0)
  clip = desired
  player.play(clip_names[clip], 0.0)
  if locomotion_change: player.seek(phase * player.get_animation(clip_names[clip]).length, false)
 player.speed_scale = lerpf(player.speed_scale, rate, 1.0 - exp(-delta * 18.0)) if is_locomotion(desired) else 1.0
 if alive and not stunned:
  player.advance(delta)
  jump_pose.apply(vertical_speed, was_airborne, delta, casting)
  pose_blend.apply(delta)
 host.rotation.x = move_toward(host.rotation.x, 0.0 if alive else -PI * 0.5, delta * 5.0)
 host.rotation.z = sin(Time.get_ticks_msec() * 0.015) * 0.025 if stunned and alive else 0.0
 # Upload material parameters only when impact/death appearance changes.
 lasso_pose.apply(self,host,actor,delta)
 # Rewriting every surface every physics tick scales poorly in team fights.
 var next_material_state := (1 if actor.flash > 0 else 0) + (2 if not alive else 0)
 if next_material_state != material_state:
  material_state = next_material_state
  for i in materials.size():
   materials[i].albedo_color = Color.WHITE if actor.flash > 0 else (base_colors[i] if alive else base_colors[i].lerp(Color("333744"), 0.7))

func is_locomotion(name: String) -> bool:
 return name.begins_with("Walk") or name.begins_with("Run") or name.begins_with("Sprint") or name.begins_with("Strafe")
