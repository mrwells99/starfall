extends SceneTree
var arena
var observer := false
var own_body
var sent := false
var accepted := false
var saw_chat := false
var saw_duel := false
var elapsed := 0.0
var departing := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	observer = OS.get_cmdline_user_args().has("--observer")
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.address.text = "127.0.0.1"
	arena.world_mode = true
	arena.intent = "queue"
	arena.connect_to(27942)
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 20:
		push_error("Social peer timed out: observer=%s phase=%s actors=%s chat=%s duels=%s" % [observer, arena.phase, arena.actors.size(), arena.social.lines, arena.duels])
		quit(1)
	if arena == null or arena.phase != "match" or departing: return false
	if own_body == null: own_body = arena.actors[arena.local_id]
	if arena.actors[arena.local_id] != own_body:
		push_error("Late join rebuilt existing character")
		quit(1)
	for line in arena.social.lines:
		if "hello from peer" in line: saw_chat = true
	if observer and arena.actors.size() == 5 and not sent:
		for id in arena.actors:
			if id != arena.local_id and not arena.actors[id].training_dummy: arena.selected_id = id
		arena.social.refresh()
		arena.social.challenge.pressed.emit()
		sent = true
	if not observer and arena.duel_offers.has(arena.local_id) and not accepted:
		arena.social.refresh()
		arena.social.accept.pressed.emit()
		arena.social.submit("hello from peer")
		accepted = true
	if arena.duels.has(arena.local_id): saw_duel = true
	if not observer and saw_duel and saw_chat:
		departing = true
		arena.leave_session("done")
		print("SOCIAL GUEST PASS")
		quit(0)
	if observer and saw_chat and saw_duel and arena.actors.size() == 4 and arena.duels.is_empty():
		print("SOCIAL OBSERVER PASS: duel, chat, despawn, stable body")
		arena.leave_session("")
		quit(0)
	return false
