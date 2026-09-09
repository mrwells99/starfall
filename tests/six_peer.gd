extends SceneTree

var arena
var hosting := false
var seconds := 0.0
var match_seconds := 0.0
var finishing := false
var sent := false
var moved := false
var initial := Vector3.ZERO
var started := false
var failures := 0
var moved_peers: Dictionary = {}

func _initialize() -> void:
	hosting = "--test-host" in OS.get_cmdline_user_args()
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.mode_choice.select(1)
	if hosting:
		arena.host_session()
	else:
		arena.address.text = "127.0.0.1"
		arena.join_session()

func _process(delta: float) -> bool:
	if not is_instance_valid(arena) or finishing:
		return false
	seconds += delta
	if seconds > 22:
		verify(false, "Six-peer test timed out in " + arena.phase)
		finish()
		return false
	if hosting and arena.phase == "lobby" and arena.roster.size() == 6:
		arena.host_start()
	if arena.phase == "match":
		if not started:
			started = true
			initial = arena.actors[arena.local_id].position
			var sides := [0, 0]
			for actor in arena.actors.values():
				sides[actor.team] += 1
				verify(actor.owner_peer != 0, "All six slots belong to human peers")
			verify(sides == [3, 3], "Three players assigned to each team")
			if hosting:
				arena.CC.apply(arena.actors[1], "stun", 0.1, "DR network check")
				arena.CC.apply(arena.actors[1], "root", 0.1, "DR network check")
				arena.CC.clear(arena.actors[1], ["stun", "root"])
		match_seconds += delta
		if not hosting:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_W
			key.pressed = match_seconds < 0.5
			Input.parse_input_event(key)
			moved = moved or arena.actors[arena.local_id].position.distance_to(initial) > 1
			if match_seconds > 1 and not sent:
				sent = true
				arena.send_action(1)
		else:
			for actor in arena.actors.values():
				if actor.owner_peer != 1 and absf(actor.position.z) < 9:
					moved_peers[actor.owner_peer] = true
			if match_seconds > 4:
				verify(moved_peers.size() == 5, "Server processed all five clients' movement")
				for actor in arena.actors.values():
					if actor.team == 1:
						arena.damage(arena.actors[1], actor, 1000)
				arena.check_winner()
	if arena.phase == "results":
		if hosting:
			if arena.roster.size() == 1:
				print("SIX-PEER HOST PASS: 3v3 roster, five clients moving, team victory")
				finish()
		else:
			verify(moved, "Client received own movement")
			verify(arena.winner == 0, "Client received reliable team result")
			verify(arena.packets_received > 20, "Client received six-actor snapshots")
			verify(arena.actors[1].dr_states.has("stun") and arena.actors[1].dr_states.has("root"), "Client receives independent DR categories over ENet")
			print("SIX-PEER CLIENT PASS")
			finish()
	return false

func verify(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func finish() -> void:
	finishing = true
	arena.leave_session("Test complete")
	await create_timer(0.4).timeout
	quit(1 if failures else 0)
