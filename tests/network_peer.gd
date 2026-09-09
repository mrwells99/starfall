extends SceneTree

var arena
var is_host := false
var team_mode := false
var clock := 0.0
var match_clock := 0.0
var started := false
var initial_position := Vector3.ZERO
var moved := false
var damaged := false
var cast_seen := false
var action_timer := 0.0
var failures := 0
var args: PackedStringArray
var phase_two := false
var initial_epoch := 0
var rematch_seen := false
var disconnected_bot := false
var peer_target := 2
var host_attacked := false
var identity_seen := false
var movement_stages := [false, false, false, false]
var extended_seen := false
var finishing := false

func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	is_host = "--test-host" in args
	team_mode = "--test-team" in args
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.set_script(load("res://tests/network_fixture_arena.gd"))
	root.add_child(arena)
	arena.latency_ms = (150 if "--test-movement" in args else 75) if "--test-latency" in args else 0
	if team_mode:
		arena.mode_choice.select(1)
	if is_host:
		arena.host_session()
		if arena.network and arena.phase == "lobby":
			print("NETWORK TEST HOST READY: UDP %d" % arena.current_port)
	else:
		arena.address.text = "127.0.0.1"
		arena.join_session()

func _process(delta: float) -> bool:
	if not is_instance_valid(arena) or finishing:
		return false
	clock += delta
	if clock > 24:
		push_error("Network test timeout: %s (%s)" % [arena.phase, arena.status])
		quit(1)
		return false
	if is_host and arena.phase == "lobby" and arena.roster.size() == 2:
		arena.host_start()
	if arena.phase == "match":
		if not started:
			started = true
			initial_epoch = arena.epoch
			initial_position = arena.actors[arena.local_id].position
			# Enemy side has peer 2 actor in these test sessions.
			for actor in arena.actors.values():
				if actor.team != arena.actors[arena.local_id].team and actor.owner_peer != 0:
					peer_target = actor.actor_id
		match_clock += delta
		if not is_host and not phase_two:
			if "--test-movement" in args:
				for binding in [KEY_W, KEY_S, KEY_D]:
					var event := InputEventKey.new()
					event.physical_keycode = binding
					# Preserve the original immediate-response windows, then approach
					# within the new spell range and jump before testing real combat.
					var forward := match_clock < 0.2 or (match_clock >= 0.9 and match_clock < 1.68)
					var backward := (match_clock >= 0.2 and match_clock < 0.4) or (match_clock >= 1.8 and match_clock < 2.0)
					event.pressed = (binding == KEY_W and forward) or (binding == KEY_S and backward) or (binding == KEY_D and match_clock >= 0.4 and match_clock < 0.6)
					Input.parse_input_event(event)
				var body = arena.actors[arena.local_id]
				var local_velocity: Vector3 = body.basis.inverse() * body.velocity
				if match_clock > 0.04 and match_clock < 0.15:
					movement_stages[0] = movement_stages[0] or local_velocity.z < -6
				if match_clock > 0.24 and match_clock < 0.35:
					movement_stages[1] = movement_stages[1] or local_velocity.z > 3
				if match_clock > 0.44 and match_clock < 0.55:
					movement_stages[2] = movement_stages[2] or local_velocity.x > 6
				if match_clock > 0.64 and match_clock < 0.75:
					movement_stages[3] = movement_stages[3] or Vector2(body.velocity.x, body.velocity.z).length() < 0.01
				if match_clock >= 1.6 and not jump_sent:
					takeoff_velocity = Vector2(body.velocity.x, body.velocity.z)
					var jump := InputEventKey.new()
					jump.physical_keycode = KEY_SPACE
					jump.pressed = true
					Input.parse_input_event(jump)
					jump_sent = true
				if jump_sent and match_clock > 1.68:
					var release_jump := InputEventKey.new()
					release_jump.physical_keycode = KEY_SPACE
					Input.parse_input_event(release_jump)
				var preserves_momentum: bool = not body.is_on_floor() and body.position.y > 0.3 and takeoff_velocity.length() > 6 and Vector2(body.velocity.x, body.velocity.z).distance_to(takeoff_velocity) < 0.05
				if match_clock > 1.72 and match_clock < 1.79:
					airborne_release_seen = airborne_release_seen or preserves_momentum
				if match_clock > 1.85 and match_clock < 1.98:
					airborne_reverse_seen = airborne_reverse_seen or preserves_momentum
				if match_clock > 2.5 and match_clock < 2.9:
					landed_stop_seen = landed_stop_seen or (body.is_on_floor() and Vector2(body.velocity.x, body.velocity.z).length() < 0.01)
			else:
				var key := InputEventKey.new()
				key.physical_keycode = KEY_W
				key.pressed = match_clock < 0.6
				Input.parse_input_event(key)
			arena.selected_id = peer_target
			action_timer -= delta
			var combat_start := 2.6 if "--test-movement" in args else 1.0
			if action_timer <= 0 and match_clock > combat_start:
				action_timer = 2.0
				if not extended_seen:
					arena.send_action(10) # Shift+4: Stoke, beyond the original seven slots.
				else:
					arena.send_action(0)
		var actor = arena.actors[arena.local_id]
		moved = moved or actor.position.distance_to(initial_position) > 1.0
		cast_seen = cast_seen or actor.casting >= 0
		if arena.actors.has(peer_target):
			damaged = damaged or arena.actors[peer_target].hp < 100
		if is_host:
			host_attacked = host_attacked or arena.actors[1].hp < 100 or arena.actors[peer_target].identity.brands.has(1)
			var remote_body = arena.actors[peer_target]
			host_airborne_reverse_seen = host_airborne_reverse_seen or (not remote_body.is_on_floor() and remote_body.position.y > 0.3 and remote_body.move_input.y > 0 and Vector2(remote_body.velocity.x, remote_body.velocity.z).length() > 6)
		else:
			identity_seen = identity_seen or actor.identity.heat > 0
			extended_seen = extended_seen or actor.cooldowns[10] > 0
		if is_host and not phase_two and ((match_clock > 7 and host_attacked) or match_clock > 12):
			var remote = arena.actors[peer_target]
			verify(remote.position.distance_to(arena.spawn_position(remote.team, 0)) > 1, "Host simulated client movement")
			verify(host_attacked, "Host applied client attack damage before healing")
			if "--test-movement" in args:
				verify(host_airborne_reverse_seen, "Host preserved takeoff speed despite airborne reverse input")
			verify(arena.actors.size() == (6 if team_mode else 2), "Expected match size")
			phase_two = true
			arena.hold_bot_decisions = false
			arena.begin_round()
		if arena.epoch > initial_epoch:
			rematch_seen = true
		if is_host and phase_two and arena.epoch > initial_epoch and arena.roster.size() == 1:
			disconnected_bot = arena.actors[peer_target].owner_peer == 0
			verify(disconnected_bot, "Disconnected player replaced by bot")
			if failures == 0:
				print("NETWORK HOST PASS: authoritative movement, damage, rematch, disconnect takeover")
			finish()
	if not is_host and started and arena.epoch > initial_epoch and not phase_two:
		phase_two = true
		verify(moved, "Client moved during the match")
		if "--test-movement" in args:
			verify(not movement_stages.has(false), "Start, reverse, strafe and stop respond before the 150ms input delay")
			verify(airborne_release_seen, "Predicted jump preserves takeoff velocity after releasing movement")
			verify(airborne_reverse_seen, "Predicted jump preserves takeoff velocity despite reverse input")
			verify(landed_stop_seen, "Predicted movement stops on landing with released input")
		verify(cast_seen, "Client received authoritative casting state")
		verify(damaged, "Client received damage state")
		verify(identity_seen, "Client received authoritative Heat state")
		verify(extended_seen, "Extended ability input and cooldown replicate")
		verify(arena.packets_received > 30, "Client received ordered snapshots")
		verify(arena.actors[arena.local_id].hp == 100, "Rematch reset local health")
		if failures == 0:
			print("NETWORK CLIENT PASS: movement, casting, damage, snapshots, rematch")
		arena.leave_session("Test complete")
		finish()
	return false

func verify(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func finish() -> void:
	finishing = true
	if failures > 0:
		print("NETWORK %s FAIL: %d assertions failed" % ["HOST" if is_host else "CLIENT", failures])
	arena.leave_session("Test complete")
	await create_timer(0.5).timeout
	quit(1 if failures else 0)
