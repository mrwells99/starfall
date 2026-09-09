extends PanelContainer

const Kits = preload("res://scripts/kits.gd")
var label: Label
var content_key := ""
var state_label: Label
var column: VBoxContainer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	var background := StyleBoxFlat.new()
	background.bg_color = Color("101a28")
	background.border_color = Color("e8be78")
	background.set_border_width_all(1)
	background.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("eef2f6"))
	column.add_child(label)
	state_label = Label.new()
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color("ffc0c5"))
	column.add_child(state_label)
	state_label.hide()
	hide()

func present(ability: Dictionary, champion: String, pointer: Vector2, bounds: Vector2) -> void:
	state_label.hide()
	show_text(Kits.description(ability, champion), pointer, bounds)

# Auras reuse this panel rather than adding a second tooltip that would need its
# own placement and sizing logic.
func present_text(text: String, pointer: Vector2, bounds: Vector2) -> void:
	state_label.hide()
	show_text(text, pointer, bounds)

func present_availability(text: String, reason: String, pointer: Vector2, bounds: Vector2) -> void:
	var changed := state_label.text != "UNAVAILABLE · " + reason or state_label.visible != (not reason.is_empty())
	state_label.visible = not reason.is_empty()
	state_label.text = "UNAVAILABLE · " + reason
	state_label.custom_minimum_size.x = minf(360, bounds.x - 40)
	show_text(text.replace("\n\n", "\n") if not reason.is_empty() else text, pointer, bounds)
	if changed: reset_size()
	position = Vector2(clampf(pointer.x + 16, 8, maxf(8, bounds.x - size.x - 8)), maxf(8, pointer.y - size.y - 16))

func show_text(text: String, pointer: Vector2, bounds: Vector2) -> void:
	var width := minf(360, bounds.x - 40)
	var key := "%s:%s" % [width, text]
	if key != content_key:
		content_key = key
		label.custom_minimum_size = Vector2(width, 0)
		label.size = Vector2(width, 0)
		label.text = text
		reset_size()
	show()
	# Place above hotbar hover, keeping the whole tooltip within the viewport.
	position = Vector2(clampf(pointer.x + 16, 8, maxf(8, bounds.x - size.x - 8)), maxf(8, pointer.y - size.y - 16))
