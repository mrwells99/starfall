extends SceneTree
## Real ENet, including optional 75 ms delay each way and a moving target.
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var prepared := false
var step := 0
var confirmed := 0
var received_damage := 0
var first_seq := -1
func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args(); call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate(); arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps = 60; arena.current_port = 53194
	arena.latency_ms = 75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	arena.aimed_shot_resolved.connect(func(result):
		confirmed += 1; received_damage += int(result.damage)
		print("AIM CONFIRMED ",result)
	)
	if host: arena.host_session(true); print("AIMED NETWORK READY")
	else: arena.champion_choice.select(4); arena.address.text = "127.0.0.1"; arena.join_session()

func _process(delta: float) -> bool:
	if arena == null: return false
	elapsed += delta
	if elapsed > 18: push_error("Aimed network timeout "+arena.phase); quit(1); return false
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
		else: target = actor
	if shooter == null or target == null: return false
	if not prepared:
		prepared = true
		shooter.kit[0] = arena.Kits.spell("Test cooldown shot","aimed_test",12,18,0,.8)
		shooter.kit[0].aim_mode = "hitscan"
	if host:
		if not placed:
			placed = true; shooter.position = Vector3(0,.025,0); target.position = Vector3(0,.025,-6)
			shooter.motion_revision += 1; target.motion_revision += 1
			shooter.rotation.y = 0; target.rotation.y = PI
		target.input_age = 0; target.move_input = Vector2(sin(match_time*2),0); target.walking = true
	else:
		arena.camera.top_level = true; arena.camera.global_position = shooter.position+Vector3(0,1.6,3)
		arena.camera.look_at(arena.aimed_combat.firing_origin(target.body_hitboxes.points))
		if step == 0 and match_time > 1.0:
			step = 1; arena.send_action(0)
		elif step == 1 and confirmed == 1:
			step = 2; first_seq = arena.action_seq
			# Replay the real accepted sequence and try a fresh press during cooldown.
			arena.submit_aimed_action.rpc_id(1,arena.epoch,first_seq,0,Vector3.FORWARD,arena.aimed_combat.observed_stamp,shooter.motion_revision)
			arena.send_action(0)
		elif step == 2 and match_time > 3.1:
			step = 3; arena.send_action(0)
	if match_time > (5.0 if host else 4.5):
		# Two 12-power shots at the approved x10 damage / 1500-health scale.
		var okay: bool = confirmed == 2 and received_damage == 240 and target.hp == 1260
		if host:
			okay = okay and shooter.champion_model == null and target.champion_model == null
			for title in ["outlaw","ember"]: okay = okay and not ResourceLoader.has_cached("res://assets/characters/"+title+".glb")
		if okay: print("AIMED NETWORK %s PASS: moving target, two cooldown shots, duplicate rejection, authoritative damage and confirmation" % ["HOST" if host else "CLIENT"])
		else: push_error("Aimed network failed: host=%s confirmed=%d damage=%d hp=%s" % [host,confirmed,received_damage,target.hp])
		arena.leave_session(""); quit(0 if okay else 1)
	return false
