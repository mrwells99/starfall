extends RefCounted
## Menu layout with a selection-only cached champion portrait.
var game
var stack: VBoxContainer
var wordmark: Label
var eyebrow: Label
var metrics: HBoxContainer
var values: Array[Label] = []
var status_card: PanelContainer
var preview: TextureRect
var hero: HBoxContainer
var introduction: VBoxContainer

func install(arena) -> void:
	game = arena
	stack = game.result_text.get_parent()
	wordmark = stack.get_child(0)
	eyebrow = stack.get_child(1)
	wordmark.text = "S T A R F A L L"
	wordmark.add_theme_font_size_override("font_size", 42)
	eyebrow.text = "C O S M I C   G L A D I A T O R S"
	eyebrow.add_theme_font_size_override("font_size", 11)
	stack.add_theme_constant_override("separation", 14)
	game.panel.custom_minimum_size = Vector2(680, 0)
	var shell = game.ui_box(Color("101421f5"), Color("55546d"), 14, 1)
	shell.border_width_top = 3
	shell.shadow_size = 24
	shell.shadow_color = Color(0, 0, 0, 0.5)
	game.panel.add_theme_stylebox_override("panel", shell)
	for i in range(game.main_row.get_child_count()):
		var button: Button = game.main_row.get_child(i)
		var titles := ["ONLINE", "OFFLINE", "SETTINGS"]
		var descriptions := ["Compete with players", "Practice your champion", "Make it yours"]
		button.text = ""
		button.tooltip_text = titles[i].capitalize() + " — " + descriptions[i]
		button.custom_minimum_size = Vector2(190, 94)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 16
		content.offset_top = 19
		content.add_theme_constant_override("separation", 9)
		var title = game.add_label(content, titles[i], 18)
		title.add_theme_color_override("font_color", game.UI_ACCENT if i == 0 else game.UI_TEXT)
		var detail = game.add_label(content, descriptions[i], 12)
		detail.add_theme_color_override("font_color", game.UI_TEXT_DIM)
	preview = preload("res://scripts/champion_preview.gd").new()
	hero = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	stack.add_child(hero)
	stack.move_child(hero, game.champion_choice.get_index())
	hero.add_child(preview)
	preview.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	introduction = preload("res://scripts/champion_introduction.gd").new()
	hero.add_child(introduction)
	introduction.install(game)
	preview.hide()
	game.champion_choice.item_selected.connect(func(_index): refresh())
	metrics = HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 10)
	stack.add_child(metrics)
	stack.move_child(metrics, game.round_summary.get_index())
	for heading in ["ROUND TIME", "BLUE SURVIVORS", "RED SURVIVORS"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", game.ui_box(Color("191e30"), Color("323b53"), 8))
		metrics.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		var label = game.add_label(column, heading, 11)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", game.UI_TEXT_DIM)
		var value = game.add_label(column, "—", 28)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		values.append(value)
	status_card = PanelContainer.new()
	status_card.add_theme_stylebox_override("panel", game.ui_box(Color("171c2c"), Color("303a52"), 8))
	var index: int = game.lobby_text.get_index()
	stack.add_child(status_card)
	stack.move_child(status_card, index)
	game.lobby_text.reparent(status_card)
	game.lobby_text.custom_minimum_size = Vector2(0, 48)
	game.lobby_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.lobby_text.add_theme_font_size_override("font_size", 14)
	for button in [game.offline_rematch_button, game.start_button, game.resume_button]:
		button.custom_minimum_size.y = 48
		game.style_button(button, true)
	# Settings actions follow the values they apply.
	stack.move_child(game.settings_row, stack.get_child_count() - 1)
	game.ui.resized.connect(layout)

func refresh() -> void:
	var results: bool = game.phase == "results" and game.menu_state != "settings"
	metrics.visible = results
	var selecting: bool = game.phase == "menu" and game.menu_state in ["online", "offline", "queue", "host", "join", "abilities"]
	preview.show_champion(game.Kits.NAMES[game.champion_choice.selected], selecting)
	status_card.visible = game.menu_state != "abilities"
	hero.visible = selecting
	introduction.show_champion(game.Kits.NAMES[game.champion_choice.selected], selecting and game.menu_state in ["online", "offline", "abilities"])
	wordmark.add_theme_font_size_override("font_size", 28 if selecting else 42)
	eyebrow.visible = not selecting
	stack.add_theme_constant_override("separation", 10 if selecting else 14)
	# Keep the summary string for accessibility/test consumers; the cards present it.
	game.round_summary.visible = false
	var win: bool = game.actors.has(game.local_id) and game.actors[game.local_id].team == game.winner
	game.result_text.add_theme_font_size_override("font_size", 36 if results else 24)
	game.result_text.add_theme_color_override("font_color", Color("a6eedc") if results and win else (Color("efb4b5") if results else game.UI_TEXT))
	if results:
		game.result_text.text = "VICTORY" if win else "DEFEAT"
		eyebrow.text = "ROUND COMPLETE   /   %s TEAM WINS" % ("BLUE" if game.winner == 0 else "RED")
		var survivors := [0, 0]
		for actor in game.actors.values():
			if actor.hp > 0: survivors[actor.team] += 1
		var seconds := int(game.result_info.get("duration", game.elapsed))
		values[0].text = "%02d:%02d" % [seconds / 60, seconds % 60]
		values[1].text = "%d / %d" % [survivors[0], game.mode]
		values[2].text = "%d / %d" % [survivors[1], game.mode]
		values[1].add_theme_color_override("font_color", Color("9dcafa"))
		values[2].add_theme_color_override("font_color", Color("f0a9b5"))
	else:
		eyebrow.text = "C O S M I C   G L A D I A T O R S"
		if game.phase == "menu" and game.menu_state != "settings":
			game.result_text.text = {"main":"Enter the arena", "online":"Find your next fight", "offline":"Hone your champion", "queue":"Join the competition", "host":"Bring your rivals", "join":"Your party awaits", "abilities":"Explore your champion"}.get(game.menu_state, "Enter the arena")
	layout.call_deferred()

func layout() -> void:
	if not is_instance_valid(game.panel): return
	if preview.visible:
		# Spend remaining vertical space on the portrait without pushing actions
		# off short displays. Its 3:4 frame stays centered above the full-width picker.
		var other_height: float = game.panel.get_combined_minimum_size().y - hero.get_combined_minimum_size().y
		var portrait_height := clampf(game.ui.size.y - other_height - 40.0, 180.0, 360.0)
		preview.custom_minimum_size = Vector2(portrait_height * 0.75, portrait_height)
	game.panel.reset_size()
	game.panel.position = (game.ui.size - game.panel.size) * 0.5
