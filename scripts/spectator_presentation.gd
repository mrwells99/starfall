extends RefCounted
## Local presentation driven by replicated HP and existing reliable combat events.
var game
var card: PanelContainer
var heading: Label
var watching: Label
var recap: Label
var previous: Button
var next: Button
var target_id := -1
var active := false
var history: Array[Dictionary] = []
var death_text := ""

func install(arena) -> void:
	game = arena
	card = PanelContainer.new()
	card.name = "SpectatorCard"
	card.custom_minimum_size.x = 520
	card.add_theme_stylebox_override("panel", game.ui_box(Color("101421f5"), Color("80647f"), 12, 2))
	game.ui.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	heading = game.add_label(column, "ELIMINATED", 23)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("efb4b5"))
	watching = game.add_label(column, "", 17)
	watching.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	previous = game.add_button(row, "← Previous teammate", func(): cycle(-1))
	next = game.add_button(row, "Next teammate →", func(): cycle(1))
	var hint = game.add_label(column, "", 12)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", game.UI_TEXT_DIM)
	column.add_child(game.ui_rule())
	recap = game.add_label(column, "", 13)
	recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.hide()

func reset() -> void:
	target_id = -1
	active = false
	history.clear()
	death_text = ""
	if card != null: card.hide()

func eliminated() -> bool:
	return not game.world_mode and game.phase == "match" and game.actors.has(game.local_id) and game.actors[game.local_id].hp <= 0

func survivors() -> Array[int]:
	var ids: Array[int] = []
	if not game.actors.has(game.local_id): return ids
	for actor in game.actors.values():
		if actor.team == game.actors[game.local_id].team and actor.hp > 0 and actor.actor_id != game.local_id:
			ids.append(actor.actor_id)
	ids.sort()
	return ids

func cycle(direction: int) -> void:
	var ids := survivors()
	if ids.is_empty():
		target_id = -1
		return
	var index := ids.find(target_id)
	select_target(ids[posmod(index + direction, ids.size())])
	refresh()

func select_target(id: int) -> void:
	if target_id == id: return
	target_id = id
	if game.actors.has(id): game.pivot.rotation.y = game.actors[id].rotation.y

func refresh() -> void:
	if card == null: return
	var now := eliminated()
	if now and not active:
		game.release_mouse()
		game.selected_id = -1
		game.focus_id = -1
	active = now
	card.visible = active and not game.panel.visible and not game.edit_mode
	if not active:
		target_id = -1
		return
	var ids := survivors()
	if not target_id in ids: select_target(ids[0] if not ids.is_empty() else -1)
	heading.text = "ELIMINATED   ·   %d TEAMMATE%s ALIVE" % [ids.size(), "" if ids.size() == 1 else "S"]
	watching.text = "Following %s · Teammate %d" % [game.actors[target_id].champion, ids.find(target_id) + 1] if target_id != -1 else "Your team is out — waiting for the round result"
	previous.disabled = ids.size() < 2
	next.disabled = ids.size() < 2
	card.get_child(0).get_node("Hint").text = "%s / %s to switch  ·  No respawn this round" % [game.control_label("target_previous"), game.control_label("target_next")]
	recap.text = death_text if not death_text.is_empty() else "No recent damage details available."
	card.reset_size()
	card.position = Vector2((game.ui.size.x - card.size.x) * 0.5, game.ui.size.y - card.size.y - 24)

func follow_id() -> int:
	if eliminated():
		var ids := survivors()
		if not target_id in ids: select_target(ids[0] if not ids.is_empty() else -1)
		if target_id != -1: return target_id
	return game.local_id

func record(source: int, victim: int, text: String) -> void:
	if game.world_mode or victim != game.local_id or not game.actors.has(source) or not death_text.is_empty(): return
	if game.actors[source].team == game.actors[game.local_id].team: return
	if text.begins_with("+"): return
	var label: String = game.actors[source].champion
	var now := Time.get_ticks_msec()
	while not history.is_empty() and now - int(history[0].time) > 8000: history.pop_front()
	if text == "DEFEATED":
		var lines := PackedStringArray(["Defeated by %s" % label, "Recent incoming events · last 8 seconds"])
		for entry in history.slice(maxi(0, history.size() - 3)):
			lines.append(entry.text)
		death_text = "\n".join(lines)
		return
	var detail := "%s damage" % text.trim_prefix("−") if text.begins_with("−") else text.capitalize()
	history.append({"time": now, "text": "%s · %s" % [label, detail]})
	if history.size() > 12: history.pop_front()
