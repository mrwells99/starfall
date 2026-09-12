extends SceneTree

var game
var a
var b
var checks := 0
var failures := 0

class TestConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass

func _initialize() -> void: call_deferred("run")

func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func slot(actor, kind: String) -> int:
	for i in actor.kit.size():
		if actor.kit[i].kind == kind: return i
	return -1

func fresh() -> void:
	for actor in game.actors.values():
		actor.hp = actor.MAX_HEALTH
		actor.reset_identity()
		actor.cooldowns.fill(0.0)
		actor.gcd = 0.0
		actor.casting = -1
		actor.shield = 0.0
		actor.stunned = 0.0
		actor.locked = 0.0
	game.elapsed = 0.0

func run() -> void:
	game = load("res://arena.tscn").instantiate()
	game.config = TestConfig.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.mode = 1
	game.world_mode = false
	game.roster = {1: {"champion":"Ember", "team":0}, 2: {"champion":"Outlaw", "team":1}}
	game.begin_round()
	game.phase = "match"
	a = game.actors[1]
	b = game.actors[2]
	a.position = Vector3(0, 20, 0)
	b.position = Vector3(0, 20, -6)
	await physics_frame
	for champion in game.Kits.NAMES:
		var actor = game.Fighter.new()
		actor.setup(90, 0, 0, champion, false)
		ck(actor.hp == 1500 and actor.MAX_HEALTH == 1500, "%s starts with fifteen times its old maximum health" % champion)
		actor.free()
	game.damage(a, b, 20)
	ck(b.hp == 1300, "Direct damage is multiplied by ten exactly once")
	fresh()
	b.shield = 5.0
	game.damage(a, b, 20)
	ck(b.hp == 1420, "Ward still reduces the scaled hit by sixty percent")
	fresh()
	b.identity.dots[a.actor_id] = {"left": 2.0, "tick": .1, "stacks": 1}
	game.ClassMechanics.tick_dots(game, b, b.identity.dots, .1, 2, 0)
	ck(b.hp == 1480, "A periodic damage tick is multiplied by ten once")
	ck(b.identity.combat_left == 0, "Periodic damage does not refresh the direct-combat timer")
	fresh()
	a.hp = 500
	game.resolve_spell(a, slot(a, "self_heal"), a)
	ck(a.hp == 836, "Mend restores 336 health after proportional scaling and the twenty percent reduction")
	a.hp = 1450
	game.resolve_spell(a, slot(a, "self_heal"), a)
	ck(a.hp == 1500, "Mend caps at the larger maximum rather than the old 100 HP")
	a.hp = 500
	game.ClassMechanics.heal(game, a, a, 18)
	ck(a.hp == 770, "Other class healing preserves its original share of maximum health")
	a.hp = 500
	game.elapsed = 240
	game.ClassMechanics.heal(game, a, a, 18)
	ck(is_equal_approx(a.hp, 581), "Match dampening still applies after healer scaling")
	a.hp = 500
	game.resolve_spell(a, slot(a, "self_heal"), a)
	ck(a.hp == 836, "Mend remains exempt from match dampening")
	fresh()
	game.spawn_actor(3, 3, 1, "Vanguard", Vector3(1,20,-6))
	var guard = game.actors[3]
	guard.identity.guard = b.actor_id
	guard.identity.guard_left = 5.0
	guard.identity.guard_budget = 25.0
	game.damage(a, b, 100)
	ck(b.hp == 750 and guard.hp == 1250, "Intercede splits a 1000-health hit without duplicate scaling")
	ck(guard.identity.guard_budget == 0 and guard.identity.resolve == 25, "Intercede keeps its original resource and budget units")
	fresh()
	game.Outlaw.resolve(game, b, b.kit[slot(b, "severe")], a)
	ck(a.hp == 1300, "Severe's health-derived hit receives damage scaling without a second health multiplier")
	fresh()
	b.casting = slot(b, "deadeye")
	b.cast_left = .01
	b.identity.outlaw_channel = {"kind":"deadeye", "slot":b.casting, "completed":false, "marked":[a.actor_id]}
	game.Outlaw.tick_channel(game, b, .02)
	ck(a.hp == 1100, "Deadeye's old forty-health hit is now four hundred health")
	fresh()
	b.identity.last = 4.0
	game.damage(a, b, 1000)
	ck(b.hp == 1 and b.identity.last == 0, "Last Light still prevents lethal scaled damage")
	fresh()
	a.hp = 750
	a.visual_tick(0, null)
	ck(is_equal_approx(a.health_mesh.scale.x, .5), "A nameplate at half health draws half of its fill")
	var replica = game.Fighter.new()
	replica.setup(91, 0, 0, "Ember", false)
	replica.receive(a.snapshot(), true)
	ck(replica.hp == 750, "Network snapshots carry the full scaled health value")
	replica.free()
	game.world_mode = true
	game.duel_offers[2] = 1
	for actor in [a,b]:
		actor.cooldowns.fill(99.0)
		actor.gcd = 1.5
		actor.casting = 0
		actor.cast_left = 1.0
		actor.cast_target = 3
		actor.identity.blink_charges = 0
	game.confirm_duel(2)
	ck(a.hp == 1500 and b.hp == 1500, "Accepting a duel restores both fighters to their new maximum")
	ck(a.cooldowns.all(func(cd): return cd == 0) and b.cooldowns.all(func(cd): return cd == 0), "Accepting a duel refreshes every cooldown for both participants")
	ck(a.gcd == 0 and b.gcd == 0 and a.casting == -1 and b.casting == -1 and a.cast_target == -1, "Duel start also clears active casts and the global cooldown")
	ck(a.identity.blink_charges == game.Kits.BLINK_MAX_CHARGES, "Duel start restores every Blink charge")
	var original_health: float = guard.hp
	game.damage(a, guard, 100)
	ck(guard.hp == original_health, "A third party remains protected from duel damage")
	game.damage(a, b, 1000)
	game.tick_world(3.01)
	ck(b.hp == 1500 and not game.respawn_timers.has(b.actor_id), "The defeated duelist recovers at the new full health")
	print("Combat scaling: %d passed / %d total" % [checks - failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
