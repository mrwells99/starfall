extends SceneTree
var game
var host := false
var clock := 0.0
var stage := 0
var stage_time := 0.0
var old_ticket := ""
var old_peer := 0
func _initialize() -> void:
	host = "--host" in OS.get_cmdline_user_args()
	call_deferred("start")
func start() -> void:
	game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.current_port = 27849
	if host:
		game.host_session()
		print("RECONNECT HOST READY")
	else:
		game.address.text = "127.0.0.1"
		game.join_session()
func fail(message: String) -> void:
	push_error(message)
	quit(1)
func _process(delta: float) -> bool:
	if game == null: return false
	clock += delta
	stage_time += delta
	if clock > 18: fail("Reconnect timeout stage %d: %s" % [stage, game.phase]); return false
	if host:
		if stage == 0 and game.roster.size() == 2:
			game.begin_round()
			game.phase = "match"
			game.actors[2].hp = 63
			game.actors[2].cooldowns[0] = 9
			game.actors[2].dr_states.stun = {"count": 2, "remaining": 12.0}
			old_peer = game.actors[2].owner_peer
			game.broadcast_round()
			stage = 1
		elif stage == 1 and game.actors[2].owner_peer == 0:
			if game.recovery.reserved_count() != 1: fail("Disconnected player did not reserve their actor")
			stage = 2
		elif stage == 2 and game.actors[2].owner_peer != 0:
			if game.actors[2].owner_peer == old_peer: fail("Test did not use a new network identity")
			if not game.recovery.reservations.is_empty(): fail("Ticket was not consumed")
			stage = 3
			stage_time = 0
		elif stage == 3 and stage_time > 1:
			print("RECONNECT HOST PASS")
			quit()
	else:
		if stage == 0 and game.actors.has(game.local_id) and game.actors[game.local_id].hp == 63 and not game.recovery.token.is_empty():
			old_ticket = game.recovery.token
			game.leave_session("Connection interrupted.")
			stage = 1
			stage_time = 0
		elif stage == 1 and stage_time > 0.5:
			game.recovery.token = "x".repeat(64)
			game.recovery.reconnect()
			stage = 2
		elif stage == 2 and game.phase == "menu" and game.status.contains("no longer available"):
			game.recovery.token = old_ticket
			game.recovery.reconnect()
			stage = 3
		elif stage == 3 and game.phase == "match" and game.actors.has(game.local_id):
			var actor = game.actors[game.local_id]
			if actor.actor_id != 2 or actor.hp != 63 or actor.cooldowns[0] != 9 or actor.dr_states.stun.count != 2:
				fail("Rejoin changed actor state"); return false
			if game.recovery.token == old_ticket: fail("Rejoin failed to rotate the secret"); return false
			print("RECONNECT CLIENT PASS")
			quit()
	return false
