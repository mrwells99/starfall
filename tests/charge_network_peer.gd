extends SceneTree

var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var sent := false
var displaced := false
var charge_seen := false
var root_seen := false
var samples := PackedVector3Array()

func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args()
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.set_script(load("res://tests/network_fixture_arena.gd"))
	root.add_child(arena)
	Engine.max_fps = 60
	arena.current_port = 53192
	arena.latency_ms = 75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host:
		arena.champion_choice.select(0)
		arena.host_session()
		print("CHARGE NETWORK READY")
	else:
		arena.champion_choice.select(1)
		arena.address.text = "127.0.0.1"
		arena.join_session()

func _process(delta: float) -> bool:
	if arena == null: return false
	elapsed += delta
	if elapsed > 15:
		push_error("Charge network timeout: " + arena.phase)
		quit(1)
		return false
	if host and arena.phase == "lobby" and arena.roster.size() == 2:
		arena.host_start()
	if arena.phase != "match": return false
	match_time += delta
	var charger
	var target
	for actor in arena.actors.values():
		if actor.champion == "Vanguard": charger = actor
		else: target = actor
	if charger == null or target == null: return false
	if host and not placed:
		placed = true
		charger.position = Vector3(-6, .025, 10)
		target.position = Vector3(-1, .025, 6)
		charger.rotation.y = atan2(-5.0, 4.0)
		charger.motion_revision += 1
		target.motion_revision += 1
	if not host and not sent and match_time > .7:
		sent = true
		arena.local_yaw = atan2(-5.0, 4.0)
		arena.selected_id = target.actor_id
		arena.send_action(6)
	if not charger.charge.is_empty():
		charge_seen = true
		samples.append(charger.position)
		if host and not displaced:
			displaced = true
			target.position = Vector3(-6, .025, 0)
			target.motion_revision += 1
	root_seen = root_seen or target.identity.root > 0
	if match_time > (5.5 if host else 4.5):
		var passed: bool = charge_seen and root_seen and samples.size() >= 5 and charger.charge.is_empty() and target.hp == 94 and charger.position.distance_to(target.position) < 2.0
		if not passed:
			push_error("Charge network failed: seen=%s root=%s samples=%d active=%s hp=%s distance=%.3f" % [charge_seen, root_seen, samples.size(), not charger.charge.is_empty(), target.hp, charger.position.distance_to(target.position)])
		else:
			print("CHARGE NETWORK %s PASS: replicated root, moving route, detour, one impact; %d travel samples" % ["HOST" if host else "CLIENT", samples.size()])
		arena.leave_session("")
		quit(0 if passed else 1)
	return false
