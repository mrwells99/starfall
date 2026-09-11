extends Control

# Screen-space lettering stays crisp while the tail follows the speaker in 3D.
const FILL := Color("171426")
const EDGE := Color("8876bb")
var message: Label
var age := 0.0
var lifetime := 5.0
var card := StyleBoxFlat.new()
var tail := Vector2.ZERO

func point_to(point: Vector2) -> void:
	tail = point - position
	queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.bg_color = FILL
	card.border_color = EDGE
	card.set_border_width_all(1)
	card.set_corner_radius_all(12)
	card.corner_detail = 10
	card.shadow_color = Color(0.025, 0.01, 0.06, 0.45)
	card.shadow_size = 8
	card.shadow_offset = Vector2(0, 3)
	message = Label.new()
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_font_size_override("font_size", 17)
	message.add_theme_color_override("font_color", Color("f5f0ff"))
	message.add_theme_constant_override("line_spacing", 3)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	hide()

func say(text: String) -> void:
	age = 0.0
	lifetime = clampf(3.5 + text.length() * 0.035, 4.5, 12.0)
	message.text = text
	var font := message.get_theme_font("font")
	var width := clampf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 36, 96, 300)
	message.position = Vector2(18, 12)
	message.size = Vector2(width - 36, 0)
	message.size.y = message.get_minimum_size().y
	size = Vector2(width, message.size.y + 24)
	modulate.a = 0
	queue_redraw()

func advance(delta: float) -> bool:
	age += delta
	modulate.a = minf(clampf(age / 0.16, 0, 1), clampf((lifetime - age) / 0.65, 0, 1))
	return age < lifetime

func _draw() -> void:
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	var center := clampf(tail.x, 18, size.x - 18)
	draw_colored_polygon(PackedVector2Array([Vector2(center - 9, size.y - 1), Vector2(center, size.y + 9), Vector2(center + 9, size.y - 1)]), FILL)
	draw_polyline(PackedVector2Array([Vector2(center - 9, size.y), Vector2(center, size.y + 9), Vector2(center + 9, size.y)]), EDGE, 1.0, true)
	if tail.y > size.y + 14:
		draw_line(Vector2(center, size.y + 9), tail, Color(0.65, 0.57, 0.8, 0.65), 1, true)
		draw_circle(tail, 2, Color("e6c58a"), true, -1, true)
	# A restrained gold glint ties the bubble to the sanctum's UI palette.
	draw_line(Vector2(size.x / 2 - 14, 1), Vector2(size.x / 2 + 14, 1), Color("e6c58a"), 2.0, true)
