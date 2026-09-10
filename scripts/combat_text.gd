extends RefCounted
## Bound the number of floating labels and combine rapid numeric events.
var game
var entries: Array[Dictionary] = []
var interrupts: Dictionary = {}
func setup(arena) -> void: game = arena
func clear() -> void:
	for entry in entries:
		if is_instance_valid(entry.node): entry.node.queue_free()
	entries.clear()
	interrupts.clear()
func emit(actor, text: String, color: Color) -> void:
	var now := Time.get_ticks_msec()
	if text == "INTERRUPTED": interrupts[actor.actor_id] = now + 1200
	for entry in entries:
		if entry.id == actor.actor_id and entry.kind == "event" and entry.node.text == text and now - int(entry.created) < 900:
			return
	var numeric := text.begins_with("−") or text.begins_with("+")
	var kind := text.left(1) if numeric else "event"
	var priority := 3 if text == "DEFEATED" else (2 if text in ["INTERRUPTED", "STUNNED", "IMMUNE", "DISPELLED", "CC BROKEN"] else 1)
	if numeric:
		for entry in entries:
			if entry.id == actor.actor_id and entry.kind == kind and now - int(entry.created) < 220:
				entry.amount += text.substr(1).to_int()
				entry.node.text = kind + str(entry.amount)
				return
	# Two numeric lanes and one priority-event lane per actor; events stay legible.
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].id == actor.actor_id and entries[i].kind == kind:
			if not numeric and entries[i].priority > priority and now - int(entries[i].created) < 800:
				return
			entries[i].node.queue_free()
			entries.remove_at(i)
	if entries.size() >= 36:
		entries[0].node.queue_free()
		entries.pop_front()
	var label := Label3D.new()
	label.text = text
	label.font_size = 30 if numeric else 40
	label.outline_size = 7
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	game.add_child(label)
	var lane := -0.45 if kind == "−" else (0.45 if kind == "+" else 0.0)
	var height := 3.1 if numeric else 4.05
	var entry := {"node": label, "id": actor.actor_id, "kind": kind, "created": now, "amount": text.substr(1).to_int() if numeric else 0, "origin": actor.position + Vector3(lane, height, 0)}
	label.position = entry.origin
	entry.priority = priority
	entries.append(entry)
func tick() -> void:
	var now := Time.get_ticks_msec()
	for id in interrupts.keys():
		if now >= interrupts[id]: interrupts.erase(id)
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		var t := float(now - int(entry.created)) / 1000.0
		var duration := 1.35 if entry.kind == "event" else 0.85
		if t >= duration:
			entry.node.queue_free()
			entries.remove_at(i)
			continue
		entry.node.position = entry.origin + Vector3.UP * t * 0.75
		entry.node.modulate.a = clampf((duration - t) / 0.35, 0, 1)
