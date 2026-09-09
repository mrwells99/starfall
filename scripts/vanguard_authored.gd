extends RefCounted
# Blender-authored Vanguard presentation. Combat and collision remain on the actor.
const ASSET = preload("res://assets/characters/vanguard.glb")
const StrikeFX = preload("res://scripts/vanguard_strike.gd")
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
var base_emissions: Array[Color] = []
var base_emission_energy: Array[float] = []
var base_emission_enabled: Array[bool] = []
var attack_left := 0.0
var shield_left := 0.0
var pulse_left := 0.0
var last_hp := -1.0
var recoil_left := 0.0
var ward: MeshInstance3D
var pulse: MeshInstance3D
var base_colors: Array[Color] = []

func build(host: Node3D, team_color: Color) -> void:
 model = ASSET.instantiate()
 model.name = "VanguardAuthored"
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
      material.albedo_color = team_color.darkened(.58)
     materials.append(material)
     base_colors.append(material.albedo_color)
     base_emissions.append(material.emission)
     base_emission_energy.append(material.emission_energy_multiplier if material.emission_enabled else 0.0)
     base_emission_enabled.append(material.emission_enabled)
     # Keep shader features fixed. Toggling emission on impacts recompiles
     # pipelines; zero energy preserves the appearance of non-emissive armour.
     material.emission_enabled = true
     material.emission_energy_multiplier = base_emission_energy[-1]
     child.set_surface_override_material(surface, material)
 assert(player != null and skeleton != null, "Vanguard requires its imported skeleton and animations")
 for animation_name in player.get_animation_list():
  var short_name: String = String(animation_name).get_slice("/", String(animation_name).count("/"))
  clip_names[short_name] = animation_name
  if short_name != "RESET" and short_name != "Strike":
   player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 player.play(clip_names["Idle"])
 player.advance(0)
 ward = make_ring(host, team_color, .53)
 pulse = make_ring(host, team_color, .55)
 ward.visible = false
 pulse.visible = false
 StrikeFX.prewarm(host)

func make_ring(host: Node3D, color: Color, radius: float) -> MeshInstance3D:
 var ring := MeshInstance3D.new()
 var mesh := TorusMesh.new()
 mesh.inner_radius = radius - .012
 mesh.outer_radius = radius + .012
 mesh.rings = 40
 mesh.ring_segments = 6
 ring.mesh = mesh
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.emission_enabled = true
 material.emission = color
 material.emission_energy_multiplier = 2.5
 ring.material_override = material
 ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 host.add_child(ring)
 ring.position.y = .055
 return ring

func strike() -> void:
 attack_left = .64
 clip = "Strike"
 player.play(clip_names["Strike"], .055)
 player.seek(.16, true)

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
 filtered_speed = measured
 var alive: bool = actor.hp > 0
 var stunned: bool = actor.stunned > 0
 var casting: bool = actor.casting >= 0 and alive
 var desired := "Idle"
 var rate := 1.0
 if alive and not stunned:
  if attack_left > 0:
   desired = "Strike"
  elif casting:
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
   rate = clampf(filtered_speed / (2.74 if desired == "Run" else 0.54), 0.55, 2.4)
 if desired != clip:
  clip = desired
  player.play(clip_names[clip], 0.0 if desired in ["Idle", "Walk", "Run", "WalkBackward", "StrafeLeft", "StrafeRight"] else 0.12)
 player.speed_scale = 1.0 if desired == "Strike" else lerpf(player.speed_scale, rate, 1.0 - exp(-delta * 10.0))
 if alive and not stunned:
  player.advance(delta)
 host.rotation.x = move_toward(host.rotation.x, 0.0 if alive else -PI * 0.5, delta * 5.0)
 host.rotation.z = sin(Time.get_ticks_msec() * 0.015) * 0.025 if stunned and alive else 0.0
 # Upload material parameters only when impact/death appearance changes.
 # Rewriting every surface every physics tick scales poorly in team fights.
 var next_material_state := (1 if actor.flash > 0 else 0) + (2 if not alive else 0)
 if next_material_state != material_state:
  material_state = next_material_state
  for i in materials.size():
   materials[i].albedo_color = Color.WHITE if actor.flash > 0 else (base_colors[i] if alive else base_colors[i].lerp(Color("333744"), 0.7))
   # Texture-backed albedo is already white; add light so impact flashes remain visible.
   materials[i].emission = Color.WHITE if actor.flash > 0 else base_emissions[i]
   materials[i].emission_energy_multiplier = 2.0 if actor.flash > 0 else base_emission_energy[i] * (1.0 if alive else .15)

 if not alive:
  attack_left = 0.0
 elif not stunned:
  attack_left = maxf(0.0, attack_left - delta)
 if actor.shield > 0 and shield_left <= 0 and alive:
  pulse_left = .45
 shield_left = actor.shield
 pulse_left = maxf(0.0, pulse_left - delta)
 ward.visible = alive and actor.shield > 0
 pulse.visible = ward.visible and pulse_left > 0
 pulse.scale = Vector3.ONE * (1.0 + (.45 - pulse_left) * 1.8)
 if last_hp >= 0 and actor.hp < last_hp and alive:
  recoil_left = .18
 last_hp = actor.hp
 recoil_left = maxf(0.0, recoil_left - delta)
 model.position.z = .025 * sin(recoil_left / .18 * PI)
