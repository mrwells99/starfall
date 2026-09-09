extends Node3D
## Authored arena architecture. Visuals only; arena_layout owns all collision.
## Its editor-ready scene carries authored meshes, shared PBR and baked light.

const COVER_POSITION := Vector3(-6, 0, 5)
const SCENE_PATH := "res://scenes/sanctum_quality_slice.tscn"
var has_surround := false

func build() -> bool:
	if ResourceLoader.exists(SCENE_PATH):
		var scene := load(SCENE_PATH) as PackedScene
		if scene != null:
			var visuals := scene.instantiate()
			if not visuals.get_meta("full_arena", false):
				visuals.free()
				return false
			var lights := visuals.get_node_or_null("BakeLights")
			if lights != null:
				lights.free()
			# These authored resources carry index-only LODs generated offline.
			# Select cheaper distant detail without changing collision or the bake.
			for mesh in visuals.find_children("*", "MeshInstance3D", true, false):
				mesh.lod_bias = 0.5
			add_child(visuals)
			var corner = load("res://scripts/sanctum_corner.gd").new()
			add_child(corner)
			corner.build(visuals)
			has_surround = true
			return true
	return false # The caller retains procedural geometry if the scene is absent.
