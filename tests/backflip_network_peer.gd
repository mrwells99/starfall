extends SceneTree
## Client-owned and remote-player backflips over actual ENet, with 75ms delay.
var arena
var host := false
var remote := false
var action := "backflip"
var elapsed := 0.0
var match_time := 0.0
var placed := false
var sent := false
var seen := false
var samples := 0
var held := 0
var reversed := 0
var between_packets := 0
var last_tick := -1
var last_serial := -1
var last_pose := 0.0
var has_pose := false

func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args()
	remote = "--remote" in OS.get_cmdline_user_args()
	if "--roll" in OS.get_cmdline_user_args(): action = "roll"
	if "--coin" in OS.get_cmdline_user_args(): action = "coin"
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.set_script(load("res://tests/network_fixture_arena.gd"))
	root.add_child(arena)
	arena.current_port = 53195
	arena.latency_ms = 75
	arena.champion_choice.select(4 if host == remote else 1)
	if host:
		arena.host_session()
		print("BACKFLIP NETWORK READY")
	else:
		arena.address.text = "127.0.0.1"
		arena.join_session()

func _process(delta: float) -> bool:
	if arena == null: return false
	elapsed += delta
	arena.application_focused = true
	if elapsed > 18:
		push_error("Backflip network fixture timed out")
		quit(1)
		return false
	if host and arena.phase == "lobby" and arena.roster.size() == 2: arena.host_start()
	if arena.phase != "match": return false
	match_time += delta
	var outlaw
	for actor in arena.actors.values():
		if actor.champion == "Outlaw": outlaw = actor
	if outlaw == null: return false
	if host and not placed:
		placed = true
		outlaw.position = Vector3(0, .05, 0)
		outlaw.rotation.y = 0
		outlaw.motion_revision += 1
	if host == remote and match_time > .6 and not sent:
		sent = true
		arena.send_action({"backflip": 3, "roll": 6, "coin": 7}[action])
	var active: bool = outlaw.identity.backflip_active if action == "backflip" else (outlaw.identity.roll_left > 0 if action == "roll" else outlaw.identity.coin_left > 0)
	seen = seen or active
	if not host and active:
		var art = outlaw.champion_model.outlaw_art
		var tick := Engine.get_physics_frames()
		var pose: float = -art.player.current_animation_position if action == "backflip" else art.player.current_animation_position
		var age: float = art.backflip_clock.elapsed if action == "backflip" else art.roll_clock.elapsed
		var duration: float = art.Outlaw.BACKFLIP_AIRTIME if action == "backflip" else art.Outlaw.ROLL_SECONDS
		if action == "coin":
			if not arena.outlaw_fx.coins.has(outlaw.actor_id): return false
			pose = arena.outlaw_fx.coins[outlaw.actor_id].position.dot(outlaw.identity.coin_direction)
			age = arena.outlaw_fx.coin_tracks[outlaw.actor_id].clock.elapsed
			duration = art.Outlaw.COIN_SECONDS
		if tick != last_tick and age > .1 and age < duration - .1:
			if has_pose:
				samples += 1
				if is_equal_approx(pose, last_pose): held += 1
				if pose < last_pose - .0001: reversed += 1
				if outlaw.presentation_snapshot_serial == last_serial and pose > last_pose: between_packets += 1
			last_pose = pose
			has_pose = true
			last_serial = outlaw.presentation_snapshot_serial
		last_tick = tick
	if match_time > (3.4 if host else 3.0):
		var passed: bool = seen and not active and not outlaw.identity.backflip_combo
		if not host: passed = passed and samples > 12 and held == 0 and reversed == 0 and between_packets > 5
		print("BACKFLIP NETWORK %s %s: action=%s view=%s samples=%d held=%d reversed=%d advanced_without_packet=%d" % [
			"HOST" if host else "CLIENT", "PASS" if passed else "FAIL", action, "remote" if remote else "own", samples, held, reversed, between_packets])
		if not passed: push_error("Online backflip animation/landing check failed")
		arena.leave_session("")
		quit(0 if passed else 1)
	return false
