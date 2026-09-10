extends RefCounted
## Local comfort and practice preferences, kept separate from combat authority.
var game
var sensitivity := 1.0
var invert_y := false
var reduced_effects := false
var ui_scale := 1.0
var camera_follow := false
var jump_buffer := false
var turn_speed := 2.5
var follow_toggle: CheckButton
var buffer_toggle: CheckButton
var turn_field: SpinBox
var difficulty := 1
var passive := false
var difficulty_choice: OptionButton
var passive_toggle: CheckButton
var offline_options: HBoxContainer
var dialog: AcceptDialog
var sensitivity_field: SpinBox
var scale_choice: OptionButton
var invert_toggle: CheckButton
var reduced_toggle: CheckButton
const SCALES := [0.9, 1.0, 1.1, 1.25]
const THINK_INTERVALS := [0.85, 0.4, 0.2]
func install(arena) -> void:
	game = arena
	var stack = game.result_text.get_parent()
	offline_options = HBoxContainer.new()
	offline_options.alignment = BoxContainer.ALIGNMENT_CENTER
	offline_options.add_theme_constant_override("separation", 12)
	stack.add_child(offline_options)
	stack.move_child(offline_options, game.offline_row.get_index())
	difficulty_choice = OptionButton.new()
	for title in ["Bots: Easy", "Bots: Normal", "Bots: Hard"]: difficulty_choice.add_item(title)
	difficulty_choice.tooltip_text = "Easy: slower decisions and no interrupts. Normal: balanced reactions. Hard: quicker reactions, earlier interrupts, and focus on injured enemies. Health and damage stay the same."
	game.style_picker(difficulty_choice)
	offline_options.add_child(difficulty_choice)
	difficulty_choice.item_selected.connect(func(index): difficulty = index; save())
	passive_toggle = CheckButton.new()
	passive_toggle.text = "Passive opponents"
	passive_toggle.tooltip_text = "Offline only: opponents stand still and do not attack."
	offline_options.add_child(passive_toggle)
	passive_toggle.toggled.connect(func(on): passive = on; save())
	game.add_button(game.settings_row, "Comfort", open)
	dialog = AcceptDialog.new()
	dialog.title = "Comfort settings"
	dialog.ok_button_text = "Apply"
	dialog.min_size = Vector2i(560, 370)
	dialog.theme = Theme.new()
	dialog.theme.set_stylebox("panel", "AcceptDialog", game.ui_box(game.UI_VOID, game.UI_EDGE_HI, 10))
	dialog.theme.set_stylebox("embedded_border", "Window", game.ui_box(game.UI_VOID, game.UI_EDGE_HI, 10, 2))
	dialog.theme.set_color("title_color", "Window", game.UI_TEXT)
	game.add_child(dialog)
	game.style_button(dialog.get_ok_button(), true)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	game.add_label(column, "Mouse sensitivity", 16)
	sensitivity_field = SpinBox.new()
	sensitivity_field.min_value = 0.25
	sensitivity_field.max_value = 3
	sensitivity_field.step = 0.05
	column.add_child(sensitivity_field)
	sensitivity_field.get_line_edit().add_theme_stylebox_override("normal", game.ui_box(game.UI_VOID, game.UI_EDGE))
	sensitivity_field.get_line_edit().add_theme_color_override("font_color", game.UI_TEXT)
	invert_toggle = CheckButton.new()
	invert_toggle.text = "Invert vertical mouse look"
	column.add_child(invert_toggle)
	scale_choice = OptionButton.new()
	for value in SCALES: scale_choice.add_item("Interface & text: %d%%" % roundi(value * 100))
	game.style_picker(scale_choice)
	column.add_child(scale_choice)
	reduced_toggle = CheckButton.new()
	reduced_toggle.text = "Reduce combat flashes and decorative effects"
	column.add_child(reduced_toggle)
	game.add_label(column, "Ground boundaries, casts, and status indicators remain visible.", 14)
	game.add_label(column, "Keyboard turn speed (degrees / second)", 16)
	turn_field = SpinBox.new()
	turn_field.min_value = 60
	turn_field.max_value = 360
	turn_field.step = 1
	column.add_child(turn_field)
	follow_toggle = CheckButton.new()
	follow_toggle.text = "Return camera behind me while moving"
	column.add_child(follow_toggle)
	buffer_toggle = CheckButton.new()
	buffer_toggle.text = "Accept jump presses just before landing (100 ms)"
	buffer_toggle.tooltip_text = "Optional jump input buffer. Holding Space does not repeat jumps."
	column.add_child(buffer_toggle)
	game.add_label(column, "Autorun, walk, recenter, and mouse buttons are in Keybinds.", 14)
	dialog.confirmed.connect(apply)
func load_preferences() -> void:
	sensitivity = clampf(float(game.config.get_value("comfort", "sensitivity", 1.0)), 0.25, 3)
	invert_y = bool(game.config.get_value("comfort", "invert_y", false))
	reduced_effects = bool(game.config.get_value("comfort", "reduced_effects", false))
	ui_scale = float(game.config.get_value("comfort", "ui_scale", 1.0))
	if ui_scale not in SCALES: ui_scale = 1.0
	camera_follow = bool(game.config.get_value("comfort", "camera_follow", false))
	jump_buffer = bool(game.config.get_value("comfort", "jump_buffer", false))
	turn_speed = clampf(float(game.config.get_value("comfort", "turn_speed", 2.5)), deg_to_rad(60), deg_to_rad(360))
	difficulty = clampi(int(game.config.get_value("practice", "difficulty", 1)), 0, 2)
	passive = bool(game.config.get_value("practice", "passive", false))
	difficulty_choice.select(difficulty)
	passive_toggle.set_pressed_no_signal(passive)
	game.get_window().content_scale_factor = ui_scale
func open() -> void:
	game.movement_controls.cancel()
	follow_toggle.button_pressed = camera_follow
	buffer_toggle.button_pressed = jump_buffer
	turn_field.value = rad_to_deg(turn_speed)
	sensitivity_field.value = sensitivity
	invert_toggle.button_pressed = invert_y
	reduced_toggle.button_pressed = reduced_effects
	scale_choice.select(SCALES.find(ui_scale))
	dialog.popup_centered(Vector2i(560, 440))
func apply() -> void:
	camera_follow = follow_toggle.button_pressed
	jump_buffer = buffer_toggle.button_pressed
	turn_speed = deg_to_rad(turn_field.value)
	sensitivity = sensitivity_field.value
	invert_y = invert_toggle.button_pressed
	reduced_effects = reduced_toggle.button_pressed
	ui_scale = SCALES[scale_choice.selected]
	game.get_window().content_scale_factor = ui_scale
	save()
func save() -> void:
	for field in ["sensitivity", "invert_y", "reduced_effects", "ui_scale", "camera_follow", "jump_buffer", "turn_speed"]:
		game.config.set_value("comfort", field, get(field))
	game.config.set_value("practice", "difficulty", difficulty)
	game.config.set_value("practice", "passive", passive)
	game.config.save_config()
func refresh() -> void:
	offline_options.visible = game.phase == "menu" and game.menu_state == "offline"
