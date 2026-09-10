extends SceneTree
## Real ENet regression: camera aim, action-local movement, cone and charges.
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var step := 0
var camera_blink_seen := false
var flare_seen := false
var movement_blink_seen := false
var recharge_seen := false

func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args()
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.set_script(load("res://tests/network_fixture_arena.gd"))
	root.add_child(arena)
	Engine.max_fps = 60
	arena.current_port = 53193
	arena.latency_ms = 75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host:
		arena.champion_choice.select(1)
		arena.host_session()
		print("EMBER NETWORK READY")
	else:
		arena.champion_choice.select(0)
		arena.address.text = "127.0.0.1"
		arena.join_session()

func _process(delta: float) -> bool:
	if arena == null: return false
	elapsed += delta
	if elapsed > 15:
		push_error("Ember network timeout: " + arena.phase)
		quit(1)
		return false
	if host and arena.phase == "lobby" and arena.roster.size() == 2:
		arena.host_start()
	if arena.phase != "match": return false
	match_time += delta
	var ember
	var target
	for actor in arena.actors.values():
		if actor.champion == "Ember": ember = actor
		else: target = actor
	if ember == null or target == null: return false
	if host and not placed:
		placed = true
		ember.position = Vector3(8, .025, 0)
		target.position = Vector3(0, .025, -3)
		ember.rotation.y = 0
		ember.motion_revision += 1
		target.motion_revision += 1
	if not host:
		if step == 0 and match_time > .7:
			step = 1
			arena.local_yaw = 0
			arena.pivot.rotation.y = PI / 2
			arena.selected_id = -1
			arena.send_action(6)
		elif step == 1 and camera_blink_seen and match_time > 1.1:
			step = 2
			arena.selected_id = -1
			arena.send_action(8)
		elif step == 2 and flare_seen and match_time > 1.5:
			step = 3
			# Deliberately differs from both camera and subsequent zero input.
			arena.input_seq += 1
			arena.action_seq += 1
			arena.deliver_action(arena.epoch, arena.action_seq, 6, -1, arena.input_seq, Vector2.DOWN, 0, false, PI / 2)
	camera_blink_seen = camera_blink_seen or (ember.identity.blink_charges == 1 and Vector2(ember.position.x, ember.position.z).length() < .4)
	flare_seen = flare_seen or target.stunned > 0
	movement_blink_seen = movement_blink_seen or (ember.identity.blink_charges == 0 and absf(ember.position.x) < .4 and ember.position.z > 7.6)
	recharge_seen = recharge_seen or (ember.identity.blink_charges == 0 and ember.cooldowns[6] > 10 and ember.cooldowns[6] < 14)
	if match_time > (5.0 if host else 4.0):
		var passed: bool = camera_blink_seen and flare_seen and movement_blink_seen and recharge_seen and target.hp == 100
		if passed:
			print("EMBER NETWORK %s PASS: camera fallback, untargeted cone, action-local movement, two charges and recharge" % ["HOST" if host else "CLIENT"])
		else:
			push_error("Ember network failed: camera=%s flare=%s movement=%s recharge=%s position=%s charges=%s hp=%s" % [camera_blink_seen, flare_seen, movement_blink_seen, recharge_seen, ember.position, ember.identity.blink_charges, target.hp])
		arena.leave_session("")
		quit(0 if passed else 1)
	return false
