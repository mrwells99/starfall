extends Control
const ALLY := Color("46e6cf")
const ENEMY := Color("ff4057")
var hostile := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if hostile:
		draw_colored_polygon(PackedVector2Array([Vector2(1, 2), Vector2(17, 2), Vector2(9, 17)]), ENEMY)
	else:
		draw_circle(Vector2(9, 9), 8, ALLY)
