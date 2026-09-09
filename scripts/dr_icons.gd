extends GridContainer
const CC = preload("res://scripts/crowd_control.gd")
const COLORS := [Color("efc86e"), Color("79ded6"), Color("bf95ed"), Color("77b8ed"), Color("ee8690"), Color("84ce93")]
var game
var left_side := false
var textures: Dictionary = {}
func install(arena) -> void:
	game = arena
	columns = 3
	position = Vector2(224, 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	for i in range(CC.CATEGORIES.size()):
		var category: String = CC.CATEGORIES[i]
		var path := "res://assets/icons/dr/%s.png" % category
		if ResourceLoader.exists(path): textures[category] = load(path)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(30, 30)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color("101522")
		box.border_color = COLORS[i]
		box.set_border_width_all(1)
		chip.add_theme_stylebox_override("panel", box)
		add_child(chip)
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = textures.get(category)
		chip.add_child(art)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		chip.add_child(label)
		chip.hide()
func sync(actor) -> void:
	for i in range(CC.CATEGORIES.size()):
		var category: String = CC.CATEGORIES[i]
		var chip: PanelContainer = get_child(i)
		var track: Dictionary = actor.dr_states.get(category, {})
		chip.visible = actor.hp > 0 and int(track.get("count", 0)) > 0 and float(track.get("remaining", 0)) > 0
		if not chip.visible:
			chip.remove_meta("aura")
			continue
		var stage := mini(int(track.count), 3)
		var next: String = ["", "50% duration", "25% duration", "immune"][stage]
		var description := "Next %s: %s. Full duration returns %.1fs from now, 18s after the last effect in this category ends. Other categories and interrupts are independent." % [CC.NAMES[i].to_lower(), next, track.remaining]
		chip.set_meta("aura", {"key": "dr_" + category, "name": CC.NAMES[i] + " DR", "remaining": track.remaining, "description": description, "source": "", "color": COLORS[i]})
		chip.get_child(1).text = str(ceili(track.remaining))
		var box: StyleBoxFlat = chip.get_theme_stylebox("panel")
		box.set_border_width_all(2 if stage == 3 else 1)

	if left_side: position.x = 106 - get_combined_minimum_size().x
