extends RefCounted
## Retain visual assets between rounds without making them server dependencies.
static var scenes := {}
static var visual_warmed := false
static func get_scene(path: String) -> PackedScene:
	# Preserve the former client-side preload behavior at initial model setup,
	# rather than introducing a first-seen-class load during an active match.
	if path.begins_with("res://assets/characters/") and not visual_warmed:
		visual_warmed = true
		for title in ["ember","luminary","fulcrum","vanguard","outlaw","null"]:
			var visual_path: String = "res://assets/characters/"+title+".glb"
			scenes[visual_path] = load(visual_path)
	if not scenes.has(path): scenes[path] = load(path)
	return scenes[path]

static func restore_libraries(model: Node3D, player: AnimationPlayer) -> void:
	for library_name in model.get_meta("hitbox_libraries",{}):
		if not player.has_animation_library(library_name):
			player.add_animation_library(library_name,model.get_meta("hitbox_libraries")[library_name])
