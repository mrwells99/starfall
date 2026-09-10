extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps=30
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1000,520))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(500,250))
	var base:=ColorRect.new();base.color=Color("0e1220");base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(base)
	var grid:=GridContainer.new();grid.columns=5;grid.position=Vector2(25,24);grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",17);root.add_child(grid)
	for spell in preload("res://scripts/kits.gd").get_kit("Outlaw"):
		var col:=VBoxContainer.new();grid.add_child(col)
		var icon:=TextureRect.new();icon.texture=preload("res://scripts/ability_art.gd").texture_for(spell.name,"Outlaw")
		icon.custom_minimum_size=Vector2(175,175);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;col.add_child(icon)
		var label:=Label.new();label.text=spell.name;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;col.add_child(label)
		var row:=HBoxContainer.new();col.add_child(row)
		var small:=TextureRect.new();small.texture=icon.texture;small.custom_minimum_size=Vector2(35,35);small.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;row.add_child(small)
		var note:=Label.new();note.text="  Placeholder";note.modulate=Color("8fa0b6");row.add_child(note)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/outlaw-forge-v2/ability-icons.png")
	print("OUTLAW_ICONS_REVIEWED 10 source icons and 10 hotbar-size previews")
	quit()
