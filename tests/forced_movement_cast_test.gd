extends SceneTree
var game
var a
var b
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func reset() -> void:
	game.mode = 1
	game.roster = {1: {"champion": "Fulcrum", "team": 0}}
	game.begin_round()
	game.phase = "match"
	a = game.actors[1]
	b = game.actors[2]
	a.owner_peer = 1
	b.owner_peer = 2
	a.position = Vector3(0, 0.1, 4)
	b.position = Vector3(0, 0.1, 0)
	b.rotation.y = PI
	for i in range(8):
		for actor in [a, b]:
			actor.velocity = Vector3(0, -2, 0)
			actor.move_and_slide()
		await physics_frame
	a.identity.anchor_left = 20.0
	a.identity.anchor_pos = Vector3(0, 0, 2)
func slot(kind: String) -> int:
	for i in range(a.kit.size()):
		if a.kit[i].kind == kind: return i
	return -1
func run() -> void:
	game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	for kind in ["inward", "outward"]:
		await reset()
		check(game.try_spell(2, 0, 1) and b.gcd > 0, kind + ": victim starts cast")
		game.resolve_spell(a, slot(kind), b)
		check(b.casting == -1 and b.gcd == 0 and b.locked == 0, kind + ": displacement refunds GCD without lockout")
		check(game.try_spell(2, 0, 1), kind + ": victim can immediately recast")
		await reset()
		b.identity.hold = 2.0
		check(game.try_spell(2, 0, 1), kind + ": stationary fixture starts cast")
		game.resolve_spell(a, slot(kind), b)
		check(b.casting == 0 and b.gcd > 0, kind + ": prevented displacement preserves cast and GCD")
	await reset()
	check(game.try_spell(2, 0, 1), "Start cast before Collapse root")
	game.resolve_spell(a, slot("collapse"), a)
	check(b.identity.root > 0 and b.stunned == 0 and b.casting == 0, "Unempowered Collapse roots without interrupting")
	b.move_input = Vector2(1, 0)
	b.input_age = 0
	game.tick_actor(b, 0.1)
	check(b.casting == 0, "Holding movement while rooted does not cancel the active cast")
	game.cancel_own_cast(b, "")
	check(game.try_spell(2, 0, 1), "Rooted caster can start another cast while holding movement")
	b.cast_left = 0.05
	game.tick_actor(b, 0.1)
	check(b.casting == -1 and a.hp < a.MAX_HEALTH and b.identity.root > 0, "Cast completes normally while rooted")
	await reset()
	check(game.try_spell(2, 0, 1), "Start cast before generic root")
	game.ClassMechanics.control(game, a, b, 3, "Charge", true)
	check(b.casting == 0 and b.stunned == 0, "Generic roots preserve casting")
	await reset()
	game.try_spell(2, 0, 1)
	a.identity.meditation = 75
	game.resolve_spell(a, slot("collapse"), a)
	check(b.casting == -1 and b.stunned > 0, "Empowered Collapse remains a stun")
	print("Forced movement/casting checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
