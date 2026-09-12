extends SceneTree
## Real ENet first-shot feasibility probe; only the server history policy differs.
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var stage := 0
var trial := 0
var trials := 10
var hold_ms := 0
var rtt_ms := 0
var prepared_at := 0
var aim_started_at := 0
var clicked_at := 0
var finished := false
var results: Array = []
var distance := 6.0
var cancel_entry := false
var cancelled := false
var cancelled_at := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--test-host": host = true
		if arg.begins_with("--probe-trials="): trials = int(arg.get_slice("=",1))
		if arg.begins_with("--probe-hold-ms="): hold_ms = int(arg.get_slice("=",1))
		if arg.begins_with("--test-rtt-ms="): rtt_ms = int(arg.get_slice("=",1))
		if arg.begins_with("--probe-distance="): distance = float(arg.get_slice("=",1))
		if arg == "--probe-cancel-entry": cancel_entry = true
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.set_script(load("res://tests/aim_mode_tracking_probe_arena.gd"))
	root.add_child(arena)
	Engine.max_fps = 60
	arena.current_port = 53207 if not host and "--probe-relay" in OS.get_cmdline_user_args() else 53206
	arena.probe_result.connect(receive_result)
	if host:
		arena.host_session(true,false)
		print("PROBE NETWORK READY")
	else:
		arena.champion_choice.select(4)
		arena.address.text = "127.0.0.1"
		arena.join_session()

func receive_result(result: Dictionary) -> void:
	if host or result.trial != trial or stage != 3: return
	result["click_after_aim_ms"] = clicked_at-aim_started_at
	result["shot_after_aim_ms"] = arena.probe_sent_at-aim_started_at
	result["trigger_charge_ms"] = arena.probe_sent_at-clicked_at
	result["client_ray_hit"] = arena.probe_client_ray_hit
	result["cancelled_entry"] = cancelled
	results.append(result)
	print("PROBE_RESULT ",JSON.stringify(result))
	arena.outlaw_aim_test.leave()
	arena.probe_set_aim.rpc_id(1,arena.epoch,false)
	stage = 0
	if trial >= trials:
		var summary := {"gated":arena.probe_gated,"production":arena.probe_production,"rtt_ms":rtt_ms,"hold_ms":hold_ms,"trials":trials,"hits":0,"fired":0,"missing_history":0,"results":results}
		for row in results:
			if row.fired: summary.fired += 1
			if row.damage > 0: summary.hits += 1
			if row.missing_history: summary.missing_history += 1
		print("PROBE_SUMMARY ",JSON.stringify(summary))
		print("PROBE CLIENT PASS")
		finished = true
		arena.probe_finish.rpc_id(1)

func _process(delta: float) -> bool:
	if arena == null: return false
	if finished:
		if arena.probe_finished: quit()
		return false
	elapsed += delta
	if elapsed > 60:
		push_error("Aim tracking probe timeout stage=%s trial=%s phase=%s" % [stage,trial,arena.phase])
		quit(1); return false
	if host and arena.phase == "lobby" and arena.roster.size() == 1:
		for entry in arena.roster.values(): entry.team = 0
		arena.roster[777] = {"champion":"Ember","team":1}
		arena.begin_round()
	if arena.phase != "match": return false
	match_time += delta
	var shooter
	var target
	for actor in arena.actors.values():
		if actor.champion == "Outlaw": shooter = actor
		elif actor.champion == "Ember": target = actor
	if shooter == null or target == null: return false
	if host:
		if not placed:
			placed = true
			# Synthetic roster id 777 initially looks like a human owner. Give the
			# target bot ownership so its scripted input is actually simulated.
			target.owner_peer = 0
			shooter.position = Vector3(0,.025,0); target.position = Vector3(0,.025,-distance)
			shooter.rotation.y = 0; target.rotation.y = PI
			shooter.motion_revision += 1; target.motion_revision += 1
		return false
	arena.application_focused = true
	var now := Time.get_ticks_msec()
	if stage == 0 and match_time > 1 and not arena.outlaw_aim_test.saved:
		trial += 1; stage = 1; prepared_at = now
		cancelled = false
		arena.probe_prepare.rpc_id(1,trial)
	if stage == 1 and arena.probe_prepared == trial and now-prepared_at > 400+rtt_ms and shooter.identity.defense_detonation == 1:
		# Start normal mouse look already aimed at chest height, so opening the
		# camera does not begin with an unrelated downward-looking crosshair.
		var preaim_point: Vector3 = arena.aimed_combat.firing_origin(target.body_hitboxes.points)
		var preaim_direction: Vector3 = (preaim_point-arena.pivot.global_position).normalized()
		arena.arm.rotation.x = asin(preaim_direction.y)
		arena.pivot.rotation.y = atan2(-preaim_direction.x,-preaim_direction.z)
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT; right.pressed = true
		arena.movement_controls.begin(right)
		arena.send_action(arena.assignment.find(8))
		if not arena.outlaw_aim_test.enabled:
			push_error("Probe could not open aim mode"); quit(1); return false
		aim_started_at = now; stage = 2
		arena.probe_set_aim.rpc_id(1,arena.epoch,true)
	if stage == 2 and cancel_entry and not cancelled and now-aim_started_at >= 100:
		arena.outlaw_aim_test.leave()
		arena.probe_set_aim.rpc_id(1,arena.epoch,false)
		cancelled = true; cancelled_at = now; stage = 4
	if stage == 4 and now-cancelled_at >= 100:
		arena.send_action(arena.assignment.find(8))
		if not arena.outlaw_aim_test.enabled:
			push_error("Could not reenter aim after cancellation"); quit(1); return false
		arena.probe_set_aim.rpc_id(1,arena.epoch,true)
		aim_started_at = now; stage = 2
	if arena.outlaw_aim_test.enabled and target.body_hitboxes != null:
		# Same ordinary moving shoulder camera and input steering as the shipped
		# network test. No fabricated origin, hit target or relaxed validation.
		var point: Vector3 = arena.aimed_combat.firing_origin(target.body_hitboxes.points)
		var direction: Vector3 = (point-arena.camera.global_position).normalized()
		arena.pivot.rotation.y = atan2(-direction.x,-direction.z)
		arena.outlaw_aim_test.aim_pitch = asin(direction.y)
	if stage == 2 and arena.outlaw_aim_test.reticle.visible and now-aim_started_at >= hold_ms:
		clicked_at = now; stage = 3
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
		arena._input(click)
	return false
