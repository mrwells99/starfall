extends RefCounted
## Menu layout with a selection-only cached champion portrait.
var game
var scroll: ScrollContainer
var stack: VBoxContainer
var wordmark: Label
var eyebrow: Label
var metrics: VBoxContainer
const STAT_KEYS = ["damage", "healing", "kills", "interrupts", "cc"]
var status_card: PanelContainer
var preview: TextureRect
var hero: HBoxContainer
var introduction: VBoxContainer
var error_card: PanelContainer
var error_text: Label

func install(arena) -> void:
	game = arena
	stack = game.result_text.get_parent()
	var margin := stack.get_parent()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	stack.reparent(scroll)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	error_card = PanelContainer.new()
	error_card.add_theme_stylebox_override("panel", game.ui_box(Color("302032"), Color("bd7e91"), 8))
	stack.add_child(error_card)
	stack.move_child(error_card, 3)
	var error_column := VBoxContainer.new()
	error_card.add_child(error_column)
	var error_title = game.add_label(error_column, "CONNECTION NOTICE", 15)
	error_title.add_theme_color_override("font_color", Color("ffc0c5"))
	error_text = game.add_label(error_column, "", 15)
	error_text.custom_minimum_size.x = 560
	error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_text.add_theme_color_override("font_color", Color("ffe5eb"))
	game.add_button(error_column, "Dismiss", func(): game.status = ""; show_error(""))
	error_card.hide()
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
	metrics = VBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	stack.add_child(metrics)
	stack.move_child(metrics, game.round_summary.get_index())
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
	game.sync_control_profile()
	error_card.visible = not error_text.text.is_empty() and game.phase == "menu" and game.menu_state == "main"
	var results: bool = game.phase == "results" and game.menu_state != "settings"
	metrics.visible = results
	wordmark.visible = not results
	var selecting: bool = game.phase == "menu" and game.menu_state in ["online", "offline", "queue", "host", "join", "abilities"]
	preview.show_champion(game.Kits.NAMES[game.champion_choice.selected], selecting)
	status_card.visible = game.menu_state != "abilities" and not error_card.visible
	hero.visible = selecting
	introduction.show_champion(game.Kits.NAMES[game.champion_choice.selected], selecting and game.menu_state in ["online", "offline", "abilities"])
	wordmark.add_theme_font_size_override("font_size", 28 if selecting else 42)
	eyebrow.visible = not selecting
	stack.add_theme_constant_override("separation", 10 if selecting or results else 14)
	# The scoreboard presents the accessible summary columns.
	game.round_summary.visible = false
	var win: bool = game.actors.has(game.local_id) and game.actors[game.local_id].team == game.winner
	game.result_text.add_theme_font_size_override("font_size", 36 if results else 24)
	game.result_text.add_theme_color_override("font_color", Color("a6eedc") if results and win else (Color("efb4b5") if results else game.UI_TEXT))
	if results:
		game.result_text.text = "VICTORY" if win else "DEFEAT"
		eyebrow.text = "ROUND COMPLETE   /   %s TEAM WINS" % ("BLUE" if game.winner == 0 else "RED")
		refresh_scoreboard()
	else:
		eyebrow.text = "C O S M I C   G L A D I A T O R S"
		if game.phase == "menu" and game.menu_state != "settings":
			game.result_text.text = {"main":"Enter the arena", "online":"Find your next fight", "offline":"Hone your champion", "queue":"Join the competition", "host":"Bring your rivals", "join":"Your party awaits", "abilities":"Explore your champion"}.get(game.menu_state, "Enter the arena")
	layout.call_deferred()

func score_row(parent: Control, cells: Array, tint: Color, heading: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	for i in range(cells.size()):
		var label = game.add_label(row, str(cells[i]), 11 if heading else 15)
		label.custom_minimum_size = Vector2(172 if i == 0 else 78, 26)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i == 0 else Control.SIZE_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_color", tint)

func refresh_scoreboard() -> void:
	for child in metrics.get_children():
		metrics.remove_child(child)
		child.queue_free()
	var ids: Array = game.actors.keys()
	ids.sort()
	for team in [game.winner, 1 - game.winner]:
		var tint := Color("9dcafa") if team == 0 else Color("f0a9b5")
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", game.ui_box(Color("191e30"), tint.darkened(0.55), 8))
		metrics.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		card.add_child(column)
		var title = game.add_label(column, "%s TEAM  /  %s" % ["BLUE" if team == 0 else "RED", "WINNER" if team == game.winner else "DEFEATED"], 13)
		title.add_theme_color_override("font_color", tint)
		score_row(column, ["CHAMPION", "DAMAGE\nDONE", "HEALING\nDONE", "KILLING\nBLOWS", "INTERRUPTS\nLANDED", "CCs\nLANDED"], game.UI_TEXT_DIM, true)
		var totals := [0.0, 0.0, 0.0, 0.0, 0.0]
		for id in ids:
			var actor = game.actors[id]
			if actor.team != team: continue
			var cells: Array = ["%s · %s" % [actor.champion, "YOU" if id == game.local_id else "#%s" % id]]
			for i in range(STAT_KEYS.size()):
				var value: float = actor.match_stats.get(STAT_KEYS[i], 0)
				totals[i] += value
				cells.append(str(roundi(value)))
			score_row(column, cells, tint if id == game.local_id else game.UI_TEXT)
		column.add_child(HSeparator.new())
		var total_cells: Array = ["TEAM TOTAL"]
		for value in totals: total_cells.append(str(roundi(value)))
		score_row(column, total_cells, tint)

func layout() -> void:
	if not is_instance_valid(game.panel): return
	var chrome: float = game.panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	if preview.visible:
		var other_height: float = stack.get_combined_minimum_size().y - hero.get_combined_minimum_size().y
		var portrait_height := clampf(game.ui.size.y - other_height - chrome - 32.0, 150.0, 360.0)
		preview.custom_minimum_size = Vector2(portrait_height * 0.75, portrait_height)
	scroll.custom_minimum_size.y = minf(stack.get_combined_minimum_size().y, maxf(120, game.ui.size.y - chrome - 32))
	game.panel.reset_size()
	game.panel.position = (game.ui.size - game.panel.size) * 0.5

func show_error(message: String) -> void:
	if error_card == null: return
	error_text.text = message
	game.refresh_menu()
