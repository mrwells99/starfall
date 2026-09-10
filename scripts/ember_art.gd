extends "res://scripts/model_forge_art.gd"
# Identity-specific asset; accepted v2 animation is shared.
func _init() -> void:
 asset = preload("res://assets/characters/ember.glb")
 class_title = "Ember"
