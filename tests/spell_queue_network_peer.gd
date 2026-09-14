extends SceneTree
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var applied := false
var sent := false
var queued := false
var fired := false
var tracked_id := -1
func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args()
	call_deferred("setup")
func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps = 60; arena.current_port = 53209; arena.latency_ms = 75
	if host: arena.host_session(true); print("SPELL QUEUE NETWORK READY")
	else: arena.champion_choice.select(0); arena.address.text = "127.0.0.1"; arena.join_session()
func _process(delta: float) -> bool:
	if arena == null: return false
	elapsed += delta
	if elapsed > 20: push_error("Spell queue network timed out"); quit(1); return false
	if host and arena.phase == "lobby" and arena.roster.size() == 1:
		arena.roster[777] = {"champion": "Ember", "team": 1}; arena.begin_round()
	if arena.phase != "match": return false
	match_time += delta
	var actor = arena.actors.get(tracked_id)
	for candidate in arena.actors.values():
		if candidate.owner_peer > 1 and candidate.owner_peer != 777:
			actor = candidate; tracked_id = candidate.actor_id
	if actor == null: return false
	if host and match_time > .4 and not applied:
		applied = true
		for a in arena.actors.values():
			a.position = Vector3(0, .01, 3 if a.team == actor.team else -3)
		actor.rotation.y = 0; actor.gcd = 1.0
	if not host and actor.gcd > .20 and actor.gcd <= .4 and not sent:
		sent = true; arena.local_yaw = 0; arena.pivot.rotation.y = 0; arena.send_action(arena.assignment.find(0))
	if not actor.queued_spell.is_empty(): queued = true
	if actor.casting == 0: fired = true
	if match_time > (4.0 if host else 3.5):
		var passed := queued and fired
		if passed: print("SPELL QUEUE NETWORK %s PASS: 75ms delayed action queues and casts on authority" % ["HOST" if host else "CLIENT"])
		else:
			push_error("Spell queue failed: queued=%s fired=%s sent=%s" % [queued, fired, sent])
		arena.leave_session(""); quit(0 if passed else 1)
	return false
