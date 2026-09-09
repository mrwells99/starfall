extends SceneTree
var arena
var a
var b
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func reset() -> void:
	arena.world_mode = false
	arena.mode = 1
	arena.roster = {1: {"champion": "Fulcrum", "team": 0}, 2: {"champion": "Ember", "team": 1}}
	arena.begin_round()
	arena.phase = "match"
	a = arena.actors[1]; b = arena.actors[2]
	a.position = Vector3(0, .01, 3); b.position = Vector3(0, .01, -3)
	a.rotation.y = 0
	for i in 4:
		await physics_frame
		for actor in [a, b]:
			actor.velocity = Vector3(0, -1, 0)
			actor.move_and_slide()
func anchor(point: Vector3) -> void:
	a.identity.anchor_pos = point
	a.identity.anchor_left = 20.0
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await reset()
	arena.resolve_spell(a, 0, b)
	ck(b.hp == 94 and b.identity.dots.has(1), "Graviton applies initial damage and a DoT")
	arena.ClassMechanics.tick(arena, b, .5)
	ck(a.identity.meditation == 0, "Meditation waits for the periodic tick")
	arena.resolve_spell(a, 0, b)
	arena.ClassMechanics.tick(arena, b, .5)
	ck(a.identity.meditation == 5 and b.identity.dots.size() == 1, "Refreshing does not stack or postpone the pending tick")
	a.identity.meditation = 95
	arena.ClassMechanics.tick(arena, b, 1)
	ck(a.identity.meditation == 100, "Meditation caps at 100")
	await reset()
	arena.resolve_spell(a, 0, b)
	arena.ClassMechanics.tick(arena, b, 8)
	ck(b.hp == 78 and a.identity.meditation == 40 and b.identity.dots.is_empty(), "Eight-second DoT delivers eight ticks and expires")
	for meditation in [0, 74, 75, 100]:
		await reset()
		a.identity.meditation = meditation
		anchor(b.position)
		arena.resolve_spell(a, 11, a)
		ck(a.identity.instant_graviton, "Collapse hit grants proc at %d Meditation" % meditation)
		ck(a.identity.meditation == meditation, "Collapse does not spend Meditation")
		ck((b.stunned == 3 and b.identity.root == 0) if meditation >= 75 else (b.stunned == 0 and b.identity.root == 2), "Collapse uses correct CC at %d" % meditation)
		a.move_input = Vector2(1, 0)
		ck(arena.try_spell(1, 0, 2) and a.casting == -1 and not a.identity.instant_graviton, "Proc casts Graviton instantly while moving and consumes once")
	await reset()
	anchor(Vector3(15, 0, 15))
	arena.resolve_spell(a, 11, a)
	ck(not a.identity.instant_graviton, "Missed Collapse grants no proc")
	await reset()
	a.identity.meditation = 75
	anchor(b.position)
	b.dr_count = 1
	arena.resolve_spell(a, 11, a)
	ck(b.stunned == 1.5, "Empowered Collapse respects diminishing returns")
	await reset()
	a.identity.meditation = 49
	ck(not arena.try_spell(1, 12, 2), "Starfall blocked below 50")
	for amount in [50, 100]:
		a.identity.meditation = amount; a.gcd = 0; a.cooldowns[12] = 0; b.hp = 100
		ck(arena.try_spell(1, 12, 2) and a.casting == 12, "Starfall begins cast at %d" % amount)
		arena.cancel_own_cast(a, "")
		ck(a.identity.meditation == amount, "Cancelled Starfall spends nothing")
		arena.resolve_spell(a, 12, b)
		ck(b.hp == 100 - (20 + amount * .4) and a.identity.meditation == 0, "Starfall damage scales and consumes Meditation")
	await reset()
	arena.resolve_spell(a, 0, b)
	ck(arena.try_spell(2, 5, 2) and b.identity.dots.size() == 1, "Starting Mend does not cleanse")
	arena.cancel_own_cast(b, "")
	ck(b.identity.dots.size() == 1, "Cancelled Mend leaves DoTs")
	arena.spawn_actor(3, 3, 0, "Fulcrum", Vector3(2, 0, 3))
	arena.resolve_spell(arena.actors[3], 0, b)
	ck(b.identity.dots.size() == 2, "Independent casters have separate DoTs")
	arena.try_spell(2, 5, 2)
	b.cast_left = .001
	arena.tick_actor(b, .02)
	ck(b.identity.dots.is_empty() and b.hp > 88, "Completed DPS Mend heals and clears every caster's DoT")
	var med: float = a.identity.meditation
	arena.ClassMechanics.tick(arena, b, 2)
	ck(a.identity.meditation == med, "Cleansed DoT cannot generate more Meditation")
	await reset()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 1)
	collider.shape = box
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = Vector3(0, 1, 0)
	await physics_frame
	ck(not arena.has_los(a, b), "LOS test actually has a solid blocker")
	anchor(Vector3(0, 0, -1))
	ck(arena.validate_spell(a, 1, 2) == "" and arena.validate_spell(a, 8, 2) == "", "Inward/Outward ignore caster-target and caster-anchor LOS")
	ck(not arena.validate_spell(a, 0, 2).is_empty() and not arena.validate_spell(a, 6, 2).is_empty(), "Graviton and Tether retain LOS rules")
	anchor(Vector3(0, 0, 1))
	ck(arena.validate_spell(a, 1, 2) == "", "Inward ignores anchor-target LOS too")
	arena.resolve_spell(a, 1, b)
	ck(b.position.z < 0, "Through-LOS pull cannot move through a solid wall")
	b.position = Vector3(0, .01, -3)
	a.identity.meditation = 75
	arena.resolve_spell(a, 9, a)
	arena.ClassMechanics.tick(arena, a, .1)
	ck(b.identity.slow > 0, "Heavy Orbit affects enemies across LOS blockers")
	arena.resolve_spell(a, 11, a)
	ck(b.hp == 78 and b.stunned == 3 and a.identity.instant_graviton, "Collapse damages, stuns and grants proc across a blocker")
	anchor(Vector3(100, 0, 0))
	ck(not arena.validate_spell(a, 11, 1).is_empty(), "Anchor range still enforced")
	wall.queue_free()
	await reset()
	arena.world_mode = true
	arena.resolve_spell(a, 0, b)
	ck(b.identity.dots.is_empty(), "Graviton cannot apply DoT to non-dueling world players")
	a.identity.meditation = 81; a.identity.instant_graviton = true
	var state: Dictionary = a.snapshot()
	a.reset_identity(); a.receive(bytes_to_var(var_to_bytes(state)), true)
	ck(a.identity.meditation == 81 and a.identity.instant_graviton, "Meditation and instant proc replicate")
	arena.update_visuals(0)
	ck(arena.ability_buttons[12].visible and arena.ability_images[12].texture != null, "Fulcrum's thirteenth ability is visible and illustrated")
	arena.update_proc_flash()
	ck(arena.ability_images[0].self_modulate != Color.WHITE, "Instant Graviton visibly pulses")
	var first_tint: Color = arena.ability_images[0].self_modulate
	await create_timer(.1).timeout
	arena.update_proc_flash()
	ck(arena.ability_images[0].self_modulate != first_tint, "Proc flash animates over time")
	arena.ClassMechanics.tick(arena, a, 60)
	ck(a.identity.instant_graviton, "Unused proc has no timer")
	a.identity.instant_graviton = false
	arena.update_proc_flash()
	ck(arena.ability_images[0].self_modulate == Color.WHITE, "Flash clears when proc is consumed")
	ck(arena.AbilityArt.texture_for("Starfall", "Fulcrum") != arena.AbilityArt.texture_for("Starfall", "Luminary"), "Both Starfalls retain distinct art")
	for champion in arena.Kits.NAMES:
		arena.world_mode = false
		arena.roster = {1: {"champion": champion, "team": 0}}
		arena.begin_round()
		a = arena.actors[1]
		arena.elapsed = 600
		a.hp = 20
		a.identity.dots[99] = {"left": 8.0, "tick": 1.0}
		var mend_slot := 10 if champion == "Luminary" else 5
		arena.resolve_spell(a, mend_slot, a)
		ck(a.hp == 48, "Late-match Mend heals 28 for " + champion)
		ck(a.identity.dots.has(99) == (champion == "Luminary"), "Only DPS Mend cleanses DoTs: " + champion)
		a.hp = 90
		arena.resolve_spell(a, mend_slot, a)
		ck(a.hp == 100, "Mend caps at missing health")
		arena.world_mode = true
		a.hp = 20
		arena.resolve_spell(a, mend_slot, a)
		ck(a.hp == 48, "Old-world Mend still heals 28")
	arena.world_mode = true
	a.hp = 20
	arena.ClassMechanics.heal(arena, a, a, 27)
	ck(a.hp == 47, "World healing never inherits arena dampening")
	arena.world_mode = false
	a.hp = 20
	arena.ClassMechanics.heal(arena, a, a, 27)
	ck(is_equal_approx(a.hp, 28.1), "Non-Mend arena healing retains dampening")
	print("Fulcrum Meditation checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
