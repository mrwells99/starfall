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
	arena.mode = 1
	arena.world_mode = false
	arena.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Ember", "team": 1}}
	arena.begin_round()
	arena.phase = "match"
	a = arena.actors[1]
	b = arena.actors[2]
	a.position = Vector3(0, .025, 0)
	b.position = Vector3(0, .025, -3)
	a.rotation.y = 0
	await physics_frame

func test_flare() -> void:
	await reset()
	ck(arena.try_spell(1, 8, -1), "Solar Flare casts with no selected target")
	ck(b.stunned == 3 and b.hp == 100 and a.cooldowns[8] == 18, "Aimed Flare retains its incapacitate duration, no damage, and eighteen-second cooldown")
	ck(a.gcd == arena.GCD_DURATION, "Solar Flare retains its ordinary GCD")
	arena.damage(a, b, 1)
	ck(b.stunned == 0, "Damage still breaks Solar Flare")
	for sample in [
		[Vector3(0, 0, -4), true, "four-meter boundary"],
		[Vector3(0, 0, -4.01), false, "beyond four meters"],
		[Vector3(3, 0, 0), false, "beside caster"],
		[Vector3(0, 0, 3), false, "behind caster"],
		[Vector3(sin(deg_to_rad(54)), 0, -cos(deg_to_rad(54))) * 3.9, true, "narrowed cone edge"],
		[Vector3(sin(deg_to_rad(54)+.02), 0, -cos(deg_to_rad(54)+.02)) * 3.9, false, "outside narrowed cone angle"],
		[Vector3(sin(PI/3), 0, -cos(PI/3)) * 3.9, false, "old wider cone edge"],
	]:
		await reset()
		b.position = a.position + sample[0]
		ck(arena.try_spell(1, 8, b.actor_id), "Flare is not gated by selection at " + sample[2])
		ck((b.stunned > 0) == sample[1], "Flare hit matches " + sample[2])
	await reset()
	arena.spawn_actor(3, 3, 1, "Ember", Vector3(1, .025, -2))
	arena.spawn_actor(4, 4, 0, "Ember", Vector3(-1, .025, -2))
	ck(arena.try_spell(1, 8, 4) and b.stunned == 3 and arena.actors[3].stunned == 3, "A selected ally does not prevent the cone from hitting multiple enemies")
	ck(a.stunned == 0 and arena.actors[4].stunned == 0, "Solar Flare never incapacitates allies")
	await reset()
	a.rotation.y = PI / 2
	b.position = a.position + Vector3.LEFT * 3
	ck(arena.try_spell(1, 8, -1) and b.stunned == 3, "Solar Flare follows the character's actual aim after turning")
	await reset()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, .3)
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = Vector3(0, 1.5, -1.5)
	await physics_frame
	ck(arena.try_spell(1, 8, -1) and b.stunned == 0, "Flare can be aimed at a wall but cannot hit enemies through it")
	wall.queue_free()
	await reset()
	arena.world_mode = true
	ck(arena.try_spell(1, 8, -1) and b.stunned == 0, "Untargeted Flare still protects non-dueling world bystanders")
	await reset()
	arena.update_visuals(0)
	var outline = a.get_node("SolarFlareOutline")
	var mesh = outline.mesh
	ck(not outline.visible and not b.has_node("SolarFlareOutline"), "Solar Flare outline starts hidden and exists only for the local Ember")
	ck(arena.try_spell(1, 8, -1), "Solar Flare starts its outline window on use")
	arena.update_visuals(0)
	ck(outline.visible, "The outline appears after a successful Solar Flare")
	a.rotation.y = PI / 2
	arena.update_visuals(0)
	ck(outline.mesh == mesh and absf(outline.global_rotation.y - a.rotation.y) < .0001, "The cached outline turns with the character without rebuilding its mesh")
	var edge: Vector3 = arena.ClassMechanics.SolarFlareIndicator.edge(arena.Kits.SOLAR_FLARE_HALF_ANGLE)
	ck(is_equal_approx(edge.length(), 4.0) and is_equal_approx(edge.normalized().dot(Vector3.FORWARD), cos(deg_to_rad(54))), "Outline shares the exact four-meter, 108-degree cone dimensions")
	arena.tick_actor(a, .5)
	arena.update_visuals(0)
	ck(outline.visible, "Outline remains visible halfway through its one-second window")
	ck(not arena.try_spell(1, 8, -1), "Repeated button presses cannot recast while Solar Flare is unavailable")
	arena.tick_actor(a, .5)
	arena.update_visuals(0)
	ck(not outline.visible, "Outline disappears at one second; rejected casts do not extend it")
	a.cooldowns[8] = 0
	a.gcd = 0
	b.position = a.position + Vector3.BACK * 10
	ck(arena.try_spell(1, 8, -1), "Solar Flare can be used again after its cooldown, even with no enemy in the cone")
	arena.update_visuals(0)
	ck(outline.visible, "A successful missed cone still gets its one-second outline")
	a.hp = 0
	arena.update_visuals(0)
	ck(not outline.visible, "Defeated Ember has no targeting outline")

func test_blink() -> void:
	await reset()
	a.gcd = 1.0
	a.move_input = Vector2.RIGHT
	ck(arena.try_spell(1, 6, -1, PI), "Blink casts off the GCD")
	ck(a.position.is_equal_approx(Vector3(8, .025, 0)) and a.gcd == 1.0, "Movement input overrides camera heading and leaves GCD unchanged")
	ck(a.identity.blink_charges == 1 and a.cooldowns[6] == 14, "First Blink spends one charge and starts the existing fourteen-second recharge")
	arena.update_visuals(0)
	ck(arena.cooldown_overlays[6].charge_label.text == "1" and arena.cooldown_overlays[6].is_recharge, "One available charge remains visible during its light recharge sweep")
	arena.BlinkCharges.tick(a, 6, 3)
	a.move_input = Vector2.LEFT
	ck(arena.try_spell(1, 6, -1) and a.identity.blink_charges == 0 and a.cooldowns[6] == 11, "Second Blink is immediately usable without restarting the first recharge")
	var before: Vector3 = a.position
	ck(not arena.try_spell(1, 6, -1) and a.position == before, "An empty Blink cannot cast a third time")
	arena.update_visuals(0)
	ck(arena.cooldown_overlays[6].charge_label.text == "0" and not arena.cooldown_overlays[6].is_recharge, "Zero charges show the ordinary blocked cooldown sweep")
	arena.BlinkCharges.tick(a, 6, 10.5)
	ck(a.identity.blink_charges == 0 and a.cooldowns[6] == .5, "No charge returns before the recharge boundary")
	arena.BlinkCharges.tick(a, 6, .5)
	ck(a.identity.blink_charges == 1 and a.cooldowns[6] == 14, "Exactly fourteen seconds restores one charge and starts the next recharge")
	arena.BlinkCharges.tick(a, 6, 14)
	ck(a.identity.blink_charges == 2 and a.cooldowns[6] == 0, "The second charge returns after its own fourteen seconds")
	a.move_input = Vector2.ZERO
	a.velocity = Vector3(6, 2, 0)
	ck(arena.try_spell(1, 6, -1, PI/2) and a.position.is_equal_approx(before + Vector3.LEFT * 8), "No directional input uses camera heading even while residual velocity is present")
	ck(a.rotation.y == 0 and a.velocity == Vector3(6, 2, 0), "Camera-directed Blink preserves facing and existing jump velocity")
	arena.BlinkCharges.tick(a, 6, 60)
	ck(a.identity.blink_charges == 2 and a.cooldowns[6] == 0, "A long tick restores charges without overfilling")
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		await reset()
		# Keep the direction fixture inside the open center; full distance and
		# real pillar collisions are checked separately.
		a.kit[6].power = 2.0
		a.move_input = direction.normalized()
		before = a.position
		ck(arena.try_spell(1, 6, -1, PI), "Blink accepts movement direction " + str(direction))
		var expected := Vector3(direction.x, 0, direction.y).normalized() * 2
		ck((a.position - before).is_equal_approx(expected), "Diagonal and cardinal input give normalized Blink displacement")
	await reset()
	a.rotation.y = PI/2
	a.move_input = Vector2.RIGHT
	ck(arena.try_spell(1, 6, -1, PI) and a.position.is_equal_approx(Vector3(0, .025, -8)), "Movement-directed Blink respects a turned character's movement basis")
	await reset()
	a.identity.root = 1.0
	ck(not arena.try_spell(1, 6, -1) and a.identity.blink_charges == 2 and a.cooldowns[6] == 0, "Failed rooted Blink spends neither charges nor recharge time")
	a.identity.root = 0
	ck(not arena.try_spell(1, 6, -1, NAN) and a.identity.blink_charges == 2, "Non-finite camera headings cannot spend a charge")
	a.position = Vector3(-6, .025, 9)
	ck(arena.try_spell(1, 6, -1, 0) and a.position.z > 7, "Directional Blink still stops its full capsule before a pillar")
	await reset()
	a.last_input_seq = 10
	a.move_input = Vector2.LEFT
	arena.apply_action_intent(1, 6, -1, 9, Vector2.RIGHT, 0, false, PI)
	ck(a.position.is_equal_approx(Vector3(8, .025, 0)) and a.move_input == Vector2.LEFT and a.last_input_seq == 10, "Delayed action uses its own movement input while preserving newer movement state")
	arena.BlinkCharges.tick(a, 6, 2.5)
	var snapshot: Dictionary = a.snapshot()
	a.reset_identity()
	a.receive(bytes_to_var(var_to_bytes(snapshot)), true)
	ck(a.identity.blink_charges == 1 and a.cooldowns[6] == 11.5, "Charge count and remaining recharge replicate together")
	a.reset_identity()
	ck(a.identity.blink_charges == 2, "Round and duel identity reset restores both Blink charges")

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await test_flare()
	await test_blink()
	print("Ember abilities checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
