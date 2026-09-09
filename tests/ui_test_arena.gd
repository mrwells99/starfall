extends "res://scripts/arena.gd"
## UI interaction needs real controls, input, cameras and collision, but not
## environment art. Rendered map/character suites cover that separately.
func build_arena() -> void:
	_build_collision()
