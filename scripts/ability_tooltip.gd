extends PanelContainer

const Kits = preload("res://scripts/kits.gd")
const AbilityArt = preload("res://scripts/ability_art.gd")
class StarPattern extends Control:
	const STARS := [Vector2(.10,.15),Vector2(.30,.31),Vector2(.54,.10),Vector2(.78,.23),Vector2(.90,.58),Vector2(.16,.70),Vector2(.42,.84),Vector2(.70,.73),Vector2(.91,.91)]
	var starred := false
	func _draw() -> void:
		if not starred: return
		draw_rect(Rect2(Vector2.ZERO,size),Color("101827"))
		for point in STARS:
			draw_circle(point*size,1.15 if point.x>.5 else .8,Color("91a5c8"))
		draw_line(Vector2(1,1),Vector2(size.x-1,1),Color("9f8054"),1)
		draw_line(Vector2(1,size.y-1),Vector2(size.x-1,size.y-1),Color("9f8054"),1)
var label: Label
var content_key := ""
var state_label: Label
var column: VBoxContainer
var header: HBoxContainer
var icon: TextureRect
var art_card: StarPattern
var heading: Label

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
	header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	art_card = StarPattern.new()
	art_card.custom_minimum_size = Vector2(54, 54)
	art_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(art_card)
	icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_card.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3; icon.offset_top = 3; icon.offset_right = -3; icon.offset_bottom = -3
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color("e8be78"))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	header.hide()
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
	set_illustration(ability, champion, AbilityArt.texture_for(ability.name, champion))
	state_label.hide()
	show_text(Kits.description(ability, champion).trim_prefix(String(ability.name) + "\n\n"), pointer, bounds)

func set_illustration(ability: Dictionary, champion: String, art: Texture2D) -> void:
	header.show()
	icon.texture = art
	heading.text = ability.name
	if art_card.starred != (champion == "Null"):
		art_card.starred = champion == "Null"
		art_card.queue_redraw()
	icon.self_modulate = Color(1,1,1,.9) if champion == "Null" else Color.WHITE

# Auras reuse this panel rather than adding a second tooltip that would need its
# own placement and sizing logic.
func present_text(text: String, pointer: Vector2, bounds: Vector2) -> void:
	header.hide()
	state_label.hide()
	show_text(text, pointer, bounds)

func present_availability(text: String, reason: String, pointer: Vector2, bounds: Vector2, ability: Dictionary = {}, champion: String = "") -> void:
	if ability.is_empty(): header.hide()
	else: set_illustration(ability, champion, AbilityArt.texture_for(ability.name, champion))
	var changed := state_label.text != "UNAVAILABLE · " + reason or state_label.visible != (not reason.is_empty())
	state_label.visible = not reason.is_empty()
	state_label.text = "UNAVAILABLE · " + reason
	state_label.custom_minimum_size = Vector2(minf(360, bounds.x - 40), 0)
	state_label.size = Vector2(state_label.custom_minimum_size.x, 0)
	var body := text
	# Remove the title before tightening unavailable tooltips; otherwise the
	# single-newline conversion prevents trim_prefix and repeats the heading.
	if not ability.is_empty(): body = body.trim_prefix(String(ability.name) + "\n\n")
	if not reason.is_empty(): body = body.replace("\n\n", "\n")
	show_text(body, pointer, bounds)
	if changed: reset_size()
	position = Vector2(clampf(pointer.x + 16, 8, maxf(8, bounds.x - size.x - 8)), maxf(8, pointer.y - size.y - 16))

func present_illustrated(ability: Dictionary, champion: String, art: Texture2D, pointer: Vector2, bounds: Vector2) -> void:
	set_illustration(ability, champion, art)
	state_label.hide()
	var description := Kits.description(ability, champion)
	show_text(description.trim_prefix(String(ability.name) + "\n\n"), pointer, bounds)

func show_text(text: String, pointer: Vector2, bounds: Vector2) -> void:
	var width := minf(360, bounds.x - 40)
	var key := "%s:%s" % [width, text]
	if key != content_key:
		content_key = key
		label.custom_minimum_size = Vector2(width, 0)
		label.size = Vector2(width, 0)
		label.text = text
		label.reset_size()
		if state_label.visible: state_label.reset_size()
		column.reset_size()
		reset_size()
	show()
	_fit_content()
	# Place above hotbar hover, keeping the whole tooltip within the viewport.
	position = Vector2(clampf(pointer.x + 16, 8, maxf(8, bounds.x - size.x - 8)), maxf(8, pointer.y - size.y - 16))

func _fit_content() -> void:
	# PanelContainer stretches its VBox child to the previous panel height. Size
	# this independent popup from its actual visible rows so a long tooltip can
	# also shrink cleanly when the next hovered ability is shorter.
	var rows := 2 + (1 if state_label.visible else 0)
	var height := 24.0 + header.get_combined_minimum_size().y + label.get_combined_minimum_size().y
	if state_label.visible: height += state_label.get_combined_minimum_size().y
	height += column.get_theme_constant("separation") * (rows - 1)
	size = Vector2(get_combined_minimum_size().x, height)
