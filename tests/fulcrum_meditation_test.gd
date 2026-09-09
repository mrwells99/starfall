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
func test_periodics() -> void:
	await reset()
	arena.resolve_spell(a, 0, b)
	ck(b.hp == 94 and b.identity.dots[1].stacks == 1 and b.identity.dots[1].left == 11, "Graviton applies six initial damage and one eleven-second stack")
	arena.ClassMechanics.tick(arena, b, .5)
	arena.resolve_spell(a, 0, b)
	ck(b.identity.dots[1].left == 11 and b.identity.dots[1].stacks == 2, "Second Graviton adds a stack and refreshes its full duration")
	arena.ClassMechanics.tick(arena, b, .5)
	ck(b.hp == 82 and a.identity.meditation == 0, "Two Graviton stacks tick for six damage without postponement or Meditation")
	arena.resolve_spell(a, 0, b)
	ck(b.identity.dots.size() == 1 and b.identity.dots[1].stacks == 2 and b.identity.dots[1].left == 11, "Third Graviton refreshes two stacks without adding a third")
	arena.ClassMechanics.tick(arena, b, 1)
	ck(b.hp == 70 and a.identity.meditation == 0, "Capped Graviton stacks keep dealing six damage per tick and generate no Meditation")
	await reset()
	arena.resolve_spell(a, 0, b)
	arena.ClassMechanics.tick(arena, b, 11)
	ck(b.hp == 61 and a.identity.meditation == 0 and b.identity.dots.is_empty(), "One Graviton stack delivers exactly eleven three-damage ticks and expires")
	await reset()
	arena.resolve_spell(a, 0, b)
	arena.resolve_spell(a, 0, b)
	arena.ClassMechanics.tick(arena, b, 30)
	ck(b.hp == 22 and a.identity.meditation == 0 and b.identity.dots.is_empty(), "Two Graviton stacks expire after eleven ticks even with an oversized simulation step")
	await reset()
	a.move_input = Vector2(1, 0)
	ck(arena.try_spell(1, 13, 2) and a.casting == -1 and b.hp == 100, "Entropy applies instantly while moving without initial damage")
	ck(a.gcd == arena.GCD_DURATION and a.cooldowns[13] == 0, "Entropy uses the normal global cooldown and no individual cooldown")
	ck(not arena.try_spell(1, 13, 2), "Entropy cannot bypass its global cooldown")
	arena.ClassMechanics.tick(arena, b, .5)
	a.gcd = 0
	ck(arena.try_spell(1, 13, 2) and b.identity.entropy_dots[1].left == 15, "Entropy refreshes its full fifteen-second duration")
	arena.ClassMechanics.tick(arena, b, .5)
	ck(b.hp == 98 and a.identity.meditation == 5 and b.identity.entropy_dots.size() == 1, "Refreshing Entropy neither stacks nor postpones its two-damage, five-Meditation tick")
	a.identity.meditation = 98
	arena.ClassMechanics.tick(arena, b, 1)
	ck(a.identity.meditation == 100, "Entropy Meditation caps at one hundred")
	await reset()
	arena.resolve_spell(a, 13, b)
	arena.ClassMechanics.tick(arena, b, 30)
	ck(b.hp == 70 and a.identity.meditation == 75 and b.identity.entropy_dots.is_empty(), "Entropy delivers exactly fifteen two-damage ticks and seventy-five Meditation before expiring")
	arena.ClassMechanics.tick(arena, b, 10)
	ck(b.hp == 70 and a.identity.meditation == 75, "Expired Entropy cannot tick or generate additional Meditation")
	await reset()
	arena.resolve_spell(a, 0, b)
	arena.resolve_spell(a, 0, b)
	arena.resolve_spell(a, 13, b)
	arena.ClassMechanics.tick(arena, b, 1)
	ck(b.hp == 80 and a.identity.meditation == 5 and b.identity.dots.has(1) and b.identity.entropy_dots.has(1), "Two Graviton stacks and Entropy coexist; only Entropy generates Meditation")
	arena.spawn_actor(3, 3, 0, "Fulcrum", Vector3(2, 0, 3))
	var other = arena.actors[3]
	arena.resolve_spell(other, 0, b)
	arena.resolve_spell(other, 13, b)
	arena.ClassMechanics.tick(arena, b, 1)
	ck(b.identity.dots.size() == 2 and b.identity.entropy_dots.size() == 2 and b.identity.dots[1].stacks == 2 and b.identity.dots[3].stacks == 1, "Both DoT families maintain independent caster entries and stack limits")
	ck(b.hp == 61 and a.identity.meditation == 10 and other.identity.meditation == 5, "Independent casters receive only their own Entropy Meditation")
	var state: Dictionary = b.snapshot()
	b.reset_identity()
	b.receive(bytes_to_var(var_to_bytes(state)), true)
	ck(b.identity.dots[1].stacks == 2 and b.identity.entropy_dots.size() == 2 and b.identity.entropy_dots[1].left == 13, "Graviton stacks and both casters' Entropy durations survive snapshot serialization")
	await reset()
	arena.resolve_spell(a, 0, b)
	arena.resolve_spell(a, 13, b)
	arena.world_mode = true
	arena.ClassMechanics.tick(arena, b, 1)
	ck(b.hp == 94 and b.identity.dots.is_empty() and b.identity.entropy_dots.is_empty() and a.identity.meditation == 0, "Both DoTs stop without damage or Meditation when their target is no longer legal")

func test_inward_proc() -> void:
	await reset()
	ck(not arena.try_spell(1, 1, 2) and not a.identity.instant_collapse, "Invalid Inward without an anchor grants no Collapse charge")
	anchor(b.position)
	ck(arena.try_spell(1, 1, 2) and a.identity.instant_collapse, "Valid Inward grants an instant Collapse charge")
	var gcd: float = a.gcd
	a.cooldowns[11] = 4
	ck(not arena.try_spell(1, 11, 1) and a.identity.instant_collapse and a.gcd == gcd, "A Collapse charge cannot bypass its individual cooldown and is retained on failure")
	a.cooldowns[11] = 0
	a.identity.anchor_left = 0
	ck(not arena.try_spell(1, 11, 1) and a.identity.instant_collapse, "A charged Collapse without an anchor fails without consuming the charge")
	anchor(b.position)
	a.move_input = Vector2(1, 0)
	ck(arena.try_spell(1, 11, 1) and a.casting == -1 and not a.identity.instant_collapse, "Charged Collapse casts instantly while moving and consumes the charge")
	ck(a.gcd == gcd and a.cooldowns[11] == 18 and a.identity.anchor_left == 0, "Charged Collapse preserves the running GCD, starts its own eighteen-second cooldown, and consumes the anchor")
	ck(a.identity.instant_graviton and b.hp == 78, "Charged Collapse still grants instant Graviton on a successful hit")
	anchor(b.position)
	a.gcd = 0
	a.cooldowns[11] = 0
	a.move_input = Vector2.ZERO
	ck(arena.try_spell(1, 11, 1) and a.casting == 11 and a.gcd == arena.GCD_DURATION, "After consumption Collapse returns to its ordinary cast time and GCD")
	arena.cancel_own_cast(a, "")
	await reset()
	anchor(b.position)
	arena.resolve_spell(a, 1, b)
	arena.resolve_spell(a, 1, b)
	a.gcd = 0
	ck(arena.try_spell(1, 11, 1) and not a.identity.instant_collapse and a.gcd == 0, "Repeated Inward grants only one charge and a charged Collapse does not start a new GCD")
	anchor(b.position)
	a.cooldowns[11] = 0
	ck(arena.try_spell(1, 11, 1) and a.casting == 11, "Two Inwards cannot bank a second instant Collapse")
	arena.cancel_own_cast(a, "")
	await reset()
	anchor(b.position)
	arena.resolve_spell(a, 8, b)
	ck(not a.identity.instant_collapse, "Outward does not grant the Inward-only proc")
	anchor(b.position)
	arena.resolve_spell(a, 1, b)
	arena.ClassMechanics.tick(arena, a, 60)
	ck(a.identity.instant_collapse, "An unused instant Collapse charge has no expiry")
	a.identity.meditation = 81
	a.identity.instant_graviton = true
	var state: Dictionary = a.snapshot()
	a.reset_identity()
	a.receive(bytes_to_var(var_to_bytes(state)), true)
	ck(a.identity.meditation == 81 and a.identity.instant_graviton and a.identity.instant_collapse, "Meditation and both instant procs serialize together")

func test_starfall_area() -> void:
	await reset()
	a.identity.meditation = 50
	ck(arena.try_spell(1, 12, 2), "Starfall starts a valid cast for its area warning")
	arena.update_visuals(0)
	var warning: Node3D = a.get_node("StarfallWarning")
	ck(warning.visible and warning.global_position.is_equal_approx(b.position + Vector3.UP * .1), "Starfall warning appears at the selected target")
	ck(warning.scale.is_equal_approx(Vector3(5, .15, 5)), "Starfall warning matches its five-meter damage radius")
	b.position.x += 1
	arena.update_visuals(0)
	ck(warning.global_position.is_equal_approx(b.position + Vector3.UP * .1), "Starfall warning follows target movement during the cast")
	arena.cancel_own_cast(a, "")
	arena.update_visuals(0)
	ck(not warning.visible and a.identity.meditation == 50, "Cancelling Starfall hides its warning and retains Meditation")
	await reset()
	b.position = Vector3(0, .01, -2)
	arena.spawn_actor(3, 3, 1, "Ember", Vector3(4, .01, -2))
	arena.spawn_actor(4, 4, 1, "Ember", Vector3(5.2, .01, -2))
	arena.spawn_actor(5, 5, 0, "Ember", Vector3(1, .01, -2))
	arena.spawn_actor(6, 6, 1, "Ember", Vector3(0, .01, 5))
	a.identity.meditation = 50
	arena.resolve_spell(a, 12, b)
	ck(b.hp == 60 and arena.actors[3].hp == 60, "Starfall damages its target and enemies within five meters of the target")
	ck(arena.actors[4].hp == 100 and arena.actors[6].hp == 100, "Starfall excludes enemies beyond its radius, including enemies close only to the caster")
	ck(a.hp == 100 and arena.actors[5].hp == 100 and a.identity.meditation == 0, "Starfall protects allies and spends Meditation once for its whole area")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.3, 4, 3)
	collider.shape = box
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = Vector3(2, 1, -2)
	await physics_frame
	b.hp = 100
	arena.actors[3].hp = 100
	a.identity.meditation = 50
	ck(not arena.ClassMechanics.point_los(arena, b.position, arena.actors[3].position), "Starfall splash fixture has a solid blocker from the target center")
	arena.resolve_spell(a, 12, b)
	ck(b.hp == 60 and arena.actors[3].hp == 100, "Starfall splash cannot damage an enemy through solid terrain")
	wall.queue_free()
	await physics_frame
	arena.world_mode = true
	arena.duels = {1: 2, 2: 1}
	b.hp = 100
	a.identity.meditation = 50
	arena.resolve_spell(a, 12, b)
	ck(b.hp == 60 and arena.actors[3].hp == 100, "Target-centered Starfall cannot damage non-dueling world bystanders")
	arena.world_mode = false
	a.identity.meditation = 50
	a.cooldowns[12] = 0
	b.position = a.position + Vector3(0, 0, -18.1)
	ck(not arena.try_spell(1, 12, 2) and a.identity.meditation == 50, "Starfall's area does not bypass target cast range or spend Meditation on failure")

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await test_periodics()
	await test_inward_proc()
	await test_starfall_area()
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
	arena.resolve_spell(a, 13, b)
	ck(arena.try_spell(2, 5, 2) and b.identity.dots.size() == 1 and b.identity.entropy_dots.size() == 1, "Starting Mend does not cleanse either DoT family")
	arena.cancel_own_cast(b, "")
	ck(b.identity.dots.size() == 1 and b.identity.entropy_dots.size() == 1, "Cancelled Mend leaves both DoT families")
	arena.spawn_actor(3, 3, 0, "Fulcrum", Vector3(2, 0, 3))
	arena.resolve_spell(arena.actors[3], 0, b)
	arena.resolve_spell(arena.actors[3], 13, b)
	ck(b.identity.dots.size() == 2 and b.identity.entropy_dots.size() == 2, "Independent casters have separate DoTs in both families")
	arena.try_spell(2, 5, 2)
	b.cast_left = .001
	arena.tick_actor(b, .02)
	ck(b.identity.dots.is_empty() and b.identity.entropy_dots.is_empty() and b.hp > 88, "Completed DPS Mend heals and clears every caster's Graviton and Entropy")
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
	ck(not arena.validate_spell(a, 0, 2).is_empty() and not arena.validate_spell(a, 6, 2).is_empty() and not arena.validate_spell(a, 13, 2).is_empty(), "Graviton, Entropy, and Tether retain LOS rules")
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
	arena.resolve_spell(a, 13, b)
	ck(b.identity.dots.is_empty() and b.identity.entropy_dots.is_empty() and b.hp == 100, "Graviton and Entropy cannot damage or apply DoTs to non-dueling world players")
	anchor(b.position)
	ck(not arena.try_spell(1, 13, 2) and not arena.try_spell(1, 1, 2) and not a.identity.instant_collapse, "Illegal world casts cannot apply Entropy or grant an Inward proc")
	a.identity.meditation = 81; a.identity.instant_graviton = true
	var state: Dictionary = a.snapshot()
	a.reset_identity(); a.receive(bytes_to_var(var_to_bytes(state)), true)
	ck(a.identity.meditation == 81 and a.identity.instant_graviton, "Meditation and instant proc replicate")
	arena.update_visuals(0)
	ck(arena.ability_buttons[12].visible and arena.ability_images[12].texture != null, "Fulcrum's thirteenth ability is visible and illustrated")
	ck(arena.ability_buttons[13].visible and arena.ability_images[13].texture != null, "Entropy is available as Fulcrum's fourteenth illustrated ability")
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
		a.identity.entropy_dots[99] = {"left": 15.0, "tick": 1.0}
		var mend_slot := 10 if champion == "Luminary" else 5
		arena.resolve_spell(a, mend_slot, a)
		ck(a.hp == 48, "Late-match Mend heals 28 for " + champion)
		ck(a.identity.dots.has(99) == (champion == "Luminary") and a.identity.entropy_dots.has(99) == (champion == "Luminary"), "Only DPS Mend cleanses both DoT families: " + champion)
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
