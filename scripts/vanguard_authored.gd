extends "res://scripts/model_forge_art.gd"
const StrikeFX = preload("res://scripts/vanguard_strike.gd")
var attack_left := 0.0
var shield_left := 0.0
var pulse_left := 0.0
var last_hp := -1.0
var recoil_left := 0.0
var ward: MeshInstance3D
var pulse: MeshInstance3D

func _init() -> void:
 asset_path = "res://assets/characters/vanguard.glb"
 class_title = "Vanguard"

func build(host: Node3D, team_color: Color) -> void:
 super.build(host, team_color)
 if pose_only: return
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
 pose_blend.begin(.055)
 clip = "Strike"
 player.play(clip_names[clip], 0)
 player.seek(.16, false)

func override_clip(desired: String, alive: bool, stunned: bool, delta: float) -> String:
 if not alive:
  attack_left = 0
 elif attack_left > 0:
  if not stunned: attack_left = maxf(0, attack_left - delta)
  return "Strike"
 return desired

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
 super.animate(host, delta, actor)
 if pose_only:
  if last_hp >= 0 and actor.hp < last_hp and actor.hp > 0: recoil_left = .18
  last_hp = actor.hp
  recoil_left = maxf(0.0, recoil_left - delta)
  model.position.z = .025 * sin(recoil_left / .18 * PI)
  return
 var alive: bool = actor.hp > 0
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
