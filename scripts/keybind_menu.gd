extends Control
var game
var listing: VBoxContainer
var hint: Label
var search: LineEdit
var pending := ""
var pending_column := 0
var buttons: Dictionary = {}

func setup(arena) -> void:
	game = arena
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.06, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 48
	panel.offset_right = -48
	panel.offset_top = 32
	panel.offset_bottom = -32
	panel.add_theme_stylebox_override("panel", game.ui_box(game.UI_PANEL, game.UI_EDGE, 8))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	game.add_label(box, "KEYBINDS", 28)
	game.add_label(box, "Movement, chat, targeting and all three action bars. Changes save immediately.", 16)
	search = LineEdit.new()
	search.placeholder_text = "Search actions or abilities…"
	search.text_changed.connect(func(_text): rebuild())
	box.add_child(search)
	hint = game.add_label(box, "Click a binding, then press a key or mouse button. Escape cancels. Conflicts swap places.", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.add_theme_constant_override("separation", 6)
	scroll.add_child(listing)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	game.add_button(footer, "Reset all keybinds", func():
		game.reset_all_keybinds()
		pending = ""
		hint.text = "Default keybinds restored. Your action bar layout is preserved."
		rebuild())
	var presets := HBoxContainer.new()
	box.add_child(presets)
	game.add_button(presets, "Classic movement: A/D turn", func(): hint.text = game.controls.apply_preset(game, true); rebuild())
	game.add_button(presets, "Strafe movement: A/D strafe", func(): hint.text = game.controls.apply_preset(game, false); rebuild())
	game.add_button(footer, "Done", close)
	game.add_label(footer, "Escape: cancel / close • F11: fullscreen", 14)
	hide()

func open() -> void:
	pending = ""
	search.text = ""
	game.panel.show()
	game.release_mouse()
	game.queued_jump = false
	rebuild()
	show()
	search.release_focus()

func close() -> void:
	pending = ""
	hide()

func rebuild() -> void:
	for child in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	buttons.clear()
	var champion: String = game.Kits.NAMES[game.champion_choice.selected]
	if game.actors.has(game.local_id):
		champion = game.actors[game.local_id].champion
	var kit: Array = game.Kits.get_kit(champion)
	var last_group := ""
	for action in game.controls.rows(game):
		var title: String
		var group := "Movement" if action in game.controls.MOVEMENT else "Chat, targeting and duels"
		if action.begins_with("target_arena_") or action.begins_with("focus_arena_"):
			group = "Arena targeting"
		if action.begins_with("bar_"):
			var slot := int(action.trim_prefix("bar_"))
			group = "Action bar %d" % (slot / game.BAR_SLOTS + 1)
			var ability: int = game.assignment[slot]
			title = "Button %d · %s" % [slot % game.BAR_SLOTS + 1, kit[ability].name if ability >= 0 and ability < kit.size() else "Empty slot"]
		else:
			title = game.controls.LABELS[action]
		if not search.text.is_empty() and not (group + " " + title).to_lower().contains(search.text.to_lower()):
			continue
		if group != last_group:
			var header := HBoxContainer.new()
			listing.add_child(header)
			var group_label: Label = game.add_label(header, group.to_upper(), 18)
			group_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for title_text in ["PRIMARY", "SECONDARY"]:
				var column_label: Label = game.add_label(header, title_text, 14)
				column_label.custom_minimum_size.x = 145
				column_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var gap := Control.new()
				gap.custom_minimum_size.x = 36
				header.add_child(gap)
			last_group = group
		var row := HBoxContainer.new()
		listing.add_child(row)
		var label: Label = game.add_label(row, title, 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for col in range(2):
			var code: int = game.controls.value(game, action, col)
			var button: Button = game.add_button(row, game.controls.label(code), begin.bind(action, col))
			button.custom_minimum_size.x = 145
			buttons[action + ":" + str(col)] = button
			var clear: Button = game.add_button(row, "×", clear_binding.bind(action, col))
			clear.custom_minimum_size.x = 36
			clear.tooltip_text = "Clear this binding"

func begin(action: String, column: int) -> void:
	if not pending.is_empty():
		rebuild()
	pending = action
	pending_column = column
	hint.text = "Press a key or mouse button for this binding… Escape cancels. Modifiers may be combined with a key."
	(buttons[action + ":" + str(column)] as Button).text = "Press input…"
	get_viewport().gui_release_focus()

func clear_binding(action: String, column: int) -> void:
	pending = ""
	hint.text = game.controls.assign(game, action, column, 0)
	game.save_layout()
	rebuild()

func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			if pending.is_empty():
				close()
			else:
				pending = ""
				hint.text = "Binding unchanged."
				rebuild()
			return true
		if not pending.is_empty():
			var code: int = game.event_binding(event)
			if code != 0:
				hint.text = game.controls.assign(game, pending, pending_column, code)
				if not game.controls.reserved(code):
					game.save_layout()
					pending = ""
					rebuild()
			return true
	return false
