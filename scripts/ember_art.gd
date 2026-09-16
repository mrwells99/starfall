extends "res://scripts/model_forge_art.gd"
# Identity-specific asset; accepted v2 animation is shared.
var skate = preload("res://scripts/ember_skate_pose.gd").new()
func _init() -> void:
 asset_path = "res://assets/characters/ember.glb"
 class_title = "Ember"

func build(host: Node3D, team_color: Color) -> void:
 super.build(host,team_color)
 skate.build(skeleton)

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
 skate.restore()
 super.animate(host,delta,actor)
 skate.apply(actor,delta)
