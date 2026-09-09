extends SceneTree
var game
var host := false
var leaver := false
var clock := 0.0
var results_seen := 0
var last_result := -1
var waiting_seen := false
func _initialize() -> void:
	host = OS.get_cmdline_user_args().has("--results-host")
	leaver = OS.get_cmdline_user_args().has("--leaver")
	call_deferred("setup")
func setup() -> void:
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	if host:
		game.current_port = 27918
		game.rematch_delay = 1.5
		game.min_players = 2
		game.host_session(true)
	else:
		game.address.text = "127.0.0.1"
		game.searching = true
		game.intent = "queue"
		game.connect_to(27918)
func _process(delta: float) -> bool:
	if game == null: return false
	clock += delta
	if clock > 20:
		push_error("Results flow timed out: %s rounds=%d" % [game.phase, results_seen])
		quit(1)
		return false
	if host:
		if game.phase == "match" and game.elapsed > 0.2:
			for actor in game.actors.values():
				if actor.team == 0: actor.hp = 0
			game.check_winner()
		if game.phase == "lobby" and game.epoch >= 2 and game.roster.size() < 2:
			waiting_seen = true
		if waiting_seen and game.roster.is_empty():
			print("RESULTS HOST PASS")
			game.leave_session("")
			quit()
		return false
	if game.phase == "results" and game.epoch != last_result:
		last_result = game.epoch
		results_seen += 1
		if not game.result_info.get("automatic", false) or not is_equal_approx(float(game.result_info.get("delay", 0)), 1.5):
			push_error("Client missed authoritative rematch metadata")
			quit(1)
		if not game.round_summary.text.contains("Survivors") or game.resume_button.visible:
			push_error("Incorrect results controls/summary")
			quit(1)
		if results_seen == 1 and not game.lobby_text.text.contains("Next round in"):
			push_error("Client did not show automatic rematch countdown")
			quit(1)
		if results_seen == 2 and leaver:
			print("RESULTS LEAVER PASS")
			game.leave_session("")
			quit()
	if results_seen == 2 and game.phase == "results" and game.roster.size() < 2:
		waiting_seen = game.lobby_text.text.contains("Waiting for players")
	if results_seen == 2 and game.phase == "lobby":
		if not waiting_seen or not game.lobby_text.text.contains("1 of 2"):
			push_error("Missing live waiting status after opponent leaves")
			quit(1)
		else:
			print("RESULTS CLIENT PASS")
			game.leave_session("")
			quit()
	return false
