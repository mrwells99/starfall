extends RefCounted
## Ephemeral bearer tickets: one server process, one active round, 90-second grace.
var game
var peer_tickets: Dictionary = {}
var reservations: Dictionary = {}
var token := ""
var endpoint := ""
var port := 0
var last_attempt: Dictionary = {}
var actions: HBoxContainer
var retry_button: Button
var reconnect_button: Button
var copy_button: Button
func setup(arena) -> void: game = arena
func install_ui() -> void:
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	game.result_text.get_parent().add_child(actions)
	retry_button = game.add_button(actions, "Try again", retry)
	reconnect_button = game.add_button(actions, "Reconnect to match", reconnect)
	copy_button = game.add_button(actions, "Copy lobby code", func(): DisplayServer.clipboard_set(game.lobby_code); copy_button.text = "Code copied")
func remember_attempt() -> void:
	if game.intent == "reconnect": return
	last_attempt = {"address": game.address.text.strip_edges(), "port": game.current_port, "intent": game.intent, "code": game.pending_code, "world": game.world_mode, "mode": game.mode}
	if copy_button != null: copy_button.text = "Copy lobby code"
func refresh() -> void:
	if actions == null: return
	retry_button.visible = game.phase == "menu" and game.menu_state == "main" and not last_attempt.is_empty() and not game.status.is_empty()
	reconnect_button.visible = game.phase == "menu" and game.menu_state == "main" and not token.is_empty()
	copy_button.visible = game.phase in ["lobby", "match", "countdown", "results"] and not game.lobby_code.is_empty()
	actions.visible = retry_button.visible or reconnect_button.visible or copy_button.visible
func retry() -> void:
	if last_attempt.is_empty(): return
	var request := last_attempt.duplicate()
	game.leave_session("")
	game.address.text = request.address
	game.mode_choice.select(1 if request.mode == 3 else 0)
	game.mode = request.mode
	if request.world: game.enter_world()
	elif request.intent == "host": game.host_lobby()
	elif request.intent == "join": game.join_lobby(request.code)
	elif request.intent == "queue": game.matchmake()
	else:
		game.current_port = request.port
		game.join_session()
func reconnect() -> void:
	if token.is_empty(): return
	game.address.text = endpoint
	game.intent = "reconnect"
	game.status = "Reconnecting to your character…"
	if not game.connect_to(port):
		game.leave_session("Could not reconnect. Try again while the match is still active.")
	else: game.refresh_lobby()
func issue(peer: int) -> void:
	if game.world_mode: return
	var ticket := Crypto.new().generate_random_bytes(32).hex_encode()
	peer_tickets[peer] = ticket
	game.session_ticket.rpc_id(peer, ticket)
func reserve(peer: int) -> void:
	var ticket: String = peer_tickets.get(peer, "")
	peer_tickets.erase(peer)
	if ticket.is_empty() or game.world_mode or game.phase not in ["match", "countdown"]: return
	var id: int = game.actor_for_peer(peer)
	if id < 0 or not game.roster.has(peer): return
	reservations[ticket] = {"id": id, "epoch": game.epoch, "expires": Time.get_ticks_msec() + 90000, "roster": game.roster[peer].duplicate(true)}
func prune() -> void:
	for ticket in reservations.keys():
		var item: Dictionary = reservations[ticket]
		if item.epoch != game.epoch or item.expires <= Time.get_ticks_msec() or game.phase not in ["match", "countdown"]:
			reservations.erase(ticket)
func reserved_count() -> int:
	prune()
	return reservations.size()
func reclaim(peer: int, ticket: String) -> bool:
	prune()
	if ticket.length() != 64 or not reservations.has(ticket) or game.roster.has(peer): return false
	var item: Dictionary = reservations[ticket]
	var actor = game.actors.get(item.id)
	if actor == null or actor.owner_peer != 0: return false
	reservations.erase(ticket)
	game.roster[peer] = item.roster
	actor.owner_peer = peer
	actor.last_jump_id = 0
	actor.jump_queued = false
	actor.jump_buffer = 0
	actor.walking = false
	actor.last_input_seq = -1
	actor.last_action_seq = -1
	actor.last_motion_seq = -1
	actor.move_input = Vector2.ZERO
	actor.input_age = 0
	actor.motion_revision += 1
	issue(peer) # Rotate the ticket after each successful use.
	return true
