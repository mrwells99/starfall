extends SceneTree

const Art = preload("res://scripts/ability_art.gd")
const NULL_NAMES := [
	"Temporal Strike", "Backstab", "Kick", "Nerve Lock", "Stealth",
	"Haste", "Blindside", "Vantage Point", "Regen Pot", "Chronoshift",
]

func _initialize() -> void:
	call_deferred("run")

func heading(text: String, y: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(28, y)
	label.add_theme_font_size_override("font_size", 19)
	label.modulate = Color("dfb77b")
	root.add_child(label)

func tile(ability: String, champion: String, at: Vector2, size: int, small: bool) -> void:
	var col := VBoxContainer.new()
	col.position = at
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)
	var texture := Art.texture_for(ability, champion)
	assert(texture != null, "Missing artwork: " + ability)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	col.add_child(icon)
	var label := Label.new()
	label.text = ability
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	if small:
		var row := HBoxContainer.new()
		col.add_child(row)
		for px in [32, 42]:
			var hotbar := TextureRect.new()
			hotbar.texture = texture
			hotbar.custom_minimum_size = Vector2(px, px)
			hotbar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hotbar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			row.add_child(hotbar)
		var note := Label.new()
		note.text = " 32 / 42 px"
		note.add_theme_font_size_override("font_size", 12)
		note.modulate = Color("8fa0b6")
		row.add_child(note)

func run() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1080, 790))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(40, 60))
	var base := ColorRect.new()
	base.color = Color("0e1220")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)
	heading("OUTLAW  /  existing style reference", 15)
	var references := ["Starshot", "Severe", "Ward", "Mend", "Coin Toss"]
	for i in references.size():
		tile(references[i], "Outlaw", Vector2(28 + i * 208, 48), 130, false)
	heading("NULL  /  redrawn ability icons", 220)
	for i in NULL_NAMES.size():
		tile(NULL_NAMES[i], "Null", Vector2(28 + (i % 5) * 208, 258 + (i / 5) * 252), 170, true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/null-forge-v2/")
	var err := root.get_texture().get_image().save_png("res://artifacts/null-forge-v2/ability-icons-v2.png")
	assert(err == OK, "Could not save icon review")
	print("NULL_ICONS_REVIEWED: 10 revised icons at tooltip, 32px and 42px sizes; 5 Outlaw references")
	quit()
