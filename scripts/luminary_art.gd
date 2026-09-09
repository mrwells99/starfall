extends RefCounted
# Blender-authored Luminary presentation. Combat and collision remain on the actor.
const ASSET = preload("res://assets/characters/luminary.glb")
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var last_position := Vector3.ZERO
var initialized := false
var filtered_speed := 0.0
var clip := "Idle"
var clip_names: Dictionary = {}
var materials: Array[StandardMaterial3D] = []
var base_colors: Array[Color] = []

func build(host: Node3D, team_color: Color) -> void:
 model = ASSET.instantiate()
 model.name = "LuminaryAuthored"
 # Blender -Y is glTF +Z; game combatants face -Z.
 model.rotation.y = PI
 host.add_child(model)
 for child in model.find_children("*", "Node", true, false):
  if child is AnimationPlayer:
   player = child
  if child is Skeleton3D:
   skeleton = child
  if child is MeshInstance3D:
   if host.torso == null:
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
 assert(player != null and skeleton != null, "Luminary requires its imported skeleton and animations")
 for animation_name in player.get_animation_list():
  var short_name: String = String(animation_name).get_slice("/", String(animation_name).count("/"))
  clip_names[short_name] = animation_name
  if short_name != "RESET":
   player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 player.play(clip_names["Idle"])
 player.advance(0)

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
 var displacement := Vector3.ZERO
 if initialized and delta > 0:
  displacement = actor.global_position - last_position
  displacement.y = 0
  if displacement.length() > 1.0:
   displacement = Vector3.ZERO
 last_position = actor.global_position
 initialized = true
 var measured := displacement.length() / maxf(delta, 0.0001)
 filtered_speed = lerpf(filtered_speed, measured, 1.0 - exp(-delta * 12.0))
 var alive: bool = actor.hp > 0
 var stunned: bool = actor.stunned > 0
 var casting: bool = actor.casting >= 0 and alive
 var desired := "Idle"
 var rate := 1.0
 if alive and not stunned:
  if casting:
   desired = "Cast"
  elif filtered_speed > 0.12:
   var local_motion := actor.global_basis.inverse() * displacement
   if absf(local_motion.x) > absf(local_motion.z) * 1.15:
    desired = "StrafeLeft" if local_motion.x < 0 else "StrafeRight"
   elif local_motion.z > 0:
    desired = "WalkBackward"
   else:
    desired = "Run" if filtered_speed > 1.8 else "Walk"
   # Smooth bounded cadence avoids snapshot corrections racing the skeleton.
   rate = clampf(filtered_speed / (3.88 if desired == "Run" else 0.72), 0.55, 1.9)
 if desired != clip:
  clip = desired
  player.play(clip_names[clip], 0.20)
 player.speed_scale = lerpf(player.speed_scale, rate, 1.0 - exp(-delta * 10.0))
 if alive and not stunned:
  player.advance(delta)
 host.rotation.x = move_toward(host.rotation.x, 0.0 if alive else -PI * 0.5, delta * 5.0)
 host.rotation.z = sin(Time.get_ticks_msec() * 0.015) * 0.025 if stunned and alive else 0.0
 for i in materials.size():
  materials[i].albedo_color = Color.WHITE if actor.flash > 0 else (base_colors[i] if alive else base_colors[i].lerp(Color("333744"), 0.7))
