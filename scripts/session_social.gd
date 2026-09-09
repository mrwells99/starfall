extends Control

var game
var chat: PanelContainer
var chat_heading: Label
var log_view: RichTextLabel
var entry: LineEdit
var duel_panel: VBoxContainer
var duel_label: Label
var challenge: Button
var accept: Button
var decline: Button
var lines: Array[String] = []

func setup(arena) -> void:
	game = arena
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat = PanelContainer.new()
	chat.name = "Chat"
	add_child(chat)
	chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	chat.offset_left = 18
	chat.offset_right = 338
	chat.offset_top = -178
	chat.offset_bottom = -18
	chat.add_theme_stylebox_override("panel", game.ui_box(Color(0.025, 0.035, 0.06, 0.78), game.UI_EDGE, 8))
	var column := VBoxContainer.new()
	chat.add_child(column)
	chat_heading = game.add_label(column, "CHAT", 14)
	log_view = RichTextLabel.new()
	log_view.custom_minimum_size = Vector2(300, 76)
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.bbcode_enabled = false
	log_view.scroll_following = true
	log_view.selection_enabled = true
	log_view.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(log_view)
	entry = LineEdit.new()
	entry.placeholder_text = "Message everyone here…"
	entry.max_length = 240
	entry.text_submitted.connect(submit)
	column.add_child(entry)
	duel_panel = VBoxContainer.new()
	add_child(duel_panel)
	duel_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	duel_panel.position += Vector2(-150, 135)
	duel_panel.custom_minimum_size.x = 300
	duel_label = game.add_label(duel_panel, "", 16)
	duel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	duel_panel.add_child(buttons)
	challenge = game.add_button(buttons, "Challenge to duel", func(): game.request_duel_action("challenge"))
	accept = game.add_button(buttons, "Accept", func(): game.request_duel_action("accept"))
	decline = game.add_button(buttons, "Decline", func(): game.request_duel_action("decline"))
	refresh()

func typing() -> bool:
	return entry != null and entry.has_focus()

func handle_input(event: InputEvent) -> bool:
	if typing():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			entry.clear()
			entry.release_focus()
			return true
		# Let the LineEdit receive text, while arena hotkeys stay blocked.
		return false
	if event is InputEventKey and event.pressed and not event.echo and game.controls.matches("chat", game.event_binding(event)) and not event.alt_pressed and chat.visible:
		game.release_mouse()
		game.queued_jump = false
		entry.grab_focus()
		return true
	return false

func submit(message: String) -> void:
	game.send_chat(message)
	entry.clear()
	entry.release_focus()

func append_message(message: String) -> void:
	lines.append(message)
	if lines.size() > 100:
		lines.pop_front()
	log_view.text = "\n".join(lines)

func reset() -> void:
	lines.clear()
	log_view.clear()
	entry.clear()
	entry.release_focus()

func refresh() -> void:
	chat_heading.text = "CHAT · %s to talk" % game.control_label("chat")
	var playing: bool = game.phase in ["match", "countdown", "results"] and game.actors.has(game.local_id)
	chat.visible = playing and not game.edit_mode and not game.panel.visible
	if not chat.visible:
		entry.release_focus()
	duel_panel.visible = playing and game.world_mode and not game.edit_mode and not game.panel.visible
	if not duel_panel.visible:
		return
	var offered: int = game.duel_offers.get(game.local_id, -1)
	var opponent: int = game.duels.get(game.local_id, -1)
	var target = game.actors.get(game.selected_id)
	var outgoing: bool = game.local_id in game.duel_offers.values()
	duel_label.text = "Select a player to duel"
	if opponent >= 0:
		duel_label.text = "Dueling %s" % game.actors[opponent].champion if game.actors.has(opponent) else "Duel ended"
	elif offered >= 0 and game.actors.has(offered):
		duel_label.text = "%s challenges you" % game.actors[offered].champion
	elif outgoing:
		duel_label.text = "Waiting for their answer…"
	elif target != null and target.actor_id != game.local_id:
		duel_label.text = target.champion
	challenge.visible = offered < 0 and opponent < 0 and not outgoing
	challenge.disabled = target == null or target.actor_id == game.local_id or target.hp <= 0 or game.actors[game.local_id].hp <= 0 or game.duels.has(game.selected_id)
	accept.visible = offered >= 0 and opponent < 0
	decline.visible = offered >= 0 or outgoing
	decline.text = "Decline" if offered >= 0 else "Cancel challenge"
