extends SceneTree
var game
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func setup() -> void:
	game.mode = 3
	game.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Ember", "team": 1}}
	game.begin_round(); game.phase = "match"
	game.actors[1].position = Vector3(0, .01, 3)
	game.actors[2].position = Vector3(0, .01, -3)
	for frame in 12:
		for a in game.actors.values():
			a.velocity = Vector3(0, -2, 0); a.move_and_slide()
		await physics_frame
func run() -> void:
	game = load("res://arena.tscn").instantiate(); root.add_child(game)
	game.set_physics_process(false)
	await setup()
	var a = game.actors[1]; var b = game.actors[2]
	a.gcd = .401
	ck(not game.request_spell(1, 0, 2) and a.queued_spell.is_empty(), "Input before window is rejected")
	a.gcd = .4
	ck(game.request_spell(1, 0, 2) and a.casting == -1, "Boundary input queues without starting")
	game.tick_actor(a, .2)
	ck(a.casting == -1 and not a.queued_spell.is_empty(), "Queue waits for GCD")
	game.tick_actor(a, .2)
	ck(a.casting == 0 and a.queued_spell.is_empty(), "Queue starts on GCD completion")
	a.gcd = 0; a.cast_left = .3
	ck(game.request_spell(1, 0, 2), "Next cast queues in final cast window")
	game.tick_actor(a, .3)
	ck(a.casting == 0 and b.hp < b.MAX_HEALTH and a.cast_left > .3, "Cast completes and next cast starts in same tick")
	game.cancel_own_cast(a, "")
	a.gcd = .3
	ck(game.request_spell(1, 0, 2), "Queue first input")
	ck(game.request_spell(1, 1, 2) and a.queued_spell.slot == 1, "Latest valid input replaces queue")
	ck(not game.request_spell(1, 0, -1) and a.queued_spell.slot == 1, "Invalid input preserves queue")
	game.tick_actor(a, .3)
	ck(a.cooldowns[1] > 0 and a.queued_spell.is_empty(), "Replacement fires once")
	a.gcd = .2
	game.request_spell(1, 0, 2); game.cancel_own_cast(a, "")
	ck(a.queued_spell.is_empty(), "Cancel clears GCD-only queue")
	game.request_spell(1, 0, 2); b.position.z = -50
	game.tick_actor(a, .2)
	ck(a.casting == -1 and a.queued_spell.is_empty(), "Out-of-range target drops queued spell")
	b.position.z = -3; a.gcd = .2
	game.request_spell(1, 0, 2); a.stunned = .1
	game.tick_actor(a, .2)
	ck(a.casting == -1 and a.queued_spell.is_empty(), "Stun clears queue even if it expires this tick")
	a.gcd = .2; game.request_spell(1, 0, 2)
	a.hp = 0; game.tick_actor(a, .2)
	ck(a.queued_spell.is_empty(), "Death clears queue")
	a.hp = a.MAX_HEALTH; a.gcd = .2; game.request_spell(1, 0, 2)
	game.epoch += 1; game.tick_actor(a, .2)
	ck(a.queued_spell.is_empty() and a.casting == -1, "Old round queue never executes")
	a.gcd = .2; game.request_spell(1, 0, 2); a.reset_identity()
	ck(a.queued_spell.is_empty(), "Identity reset clears queue")
	a.gcd = .2
	game.apply_action_intent(1, 0, 2, 10, Vector2.ZERO, 0, false, 0)
	ck(not a.queued_spell.is_empty(), "Network action intent uses queue")
	game.tick_actor(a, .2)
	ck(a.casting == 0, "Server queued action executes")
	game.cancel_own_cast(a, ""); a.gcd = .2
	ck(game.request_spell(1, 2, 2) and a.queued_spell.is_empty(), "Ready off-GCD ability remains immediate")
	a.cooldowns[2] = 0; a.casting = 0; a.cast_left = .2
	ck(game.request_spell(1, 2, 2) and not a.queued_spell.is_empty(), "Off-GCD still waits for active cast")
	game.cancel_own_cast(a, ""); a.gcd = .2; a.cooldowns[1] = 2
	ck(not game.request_spell(1, 1, 2) and a.queued_spell.is_empty(), "Long own cooldown cannot queue")
	a.cooldowns[1] = 0; a.gcd = .6; a.casting = 0; a.cast_left = .2
	ck(not game.request_spell(1, 0, 2) and a.queued_spell.is_empty(), "Longer GCD still blocks short cast window")
	a.gcd = .2; a.cast_left = .6
	ck(not game.request_spell(1, 0, 2), "Longer cast still blocks short GCD window")
	a.cast_left = .2
	game.request_spell(1, 0, 2); a.move_input = Vector2.RIGHT; a.input_age = 0
	game.tick_actor(a, .1)
	ck(a.casting == -1 and a.queued_spell.is_empty(), "Movement cancelling current cast also clears queue")
	a.move_input = Vector2.ZERO; a.gcd = .2
	game.request_spell(1, 0, 2)
	var snapshot: Dictionary = a.snapshot()
	ck(snapshot.queued_spell.slot == 0, "Snapshot exposes pending input for cancellation")
	a.queued_spell.clear(); a.receive(snapshot, true)
	ck(a.queued_spell.slot == 0, "Client receives pending queue state")
	snapshot.erase("queued_spell"); a.receive(snapshot, true)
	ck(a.queued_spell.is_empty(), "Older snapshots default to no pending input")
	a.gcd = .2; a.casting = -1
	game.request_spell(1, 0, 2)
	game.panel.hide()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE; escape.pressed = true
	game._input(escape)
	ck(a.queued_spell.is_empty() and not game.panel.visible, "Escape cancels GCD-only queue without opening menu")
	print("Spell queue checks: %d passed / %d total" % [checks-failures, checks])
	game.queue_free(); await process_frame
	quit(1 if failures else 0)
