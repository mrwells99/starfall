extends SceneTree

var arena
var a
var b
var checks := 0
var failures := 0
var obstacles: Array[Node] = []
var positions := PackedVector3Array()
var peak_tick_ms := 0.0

func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func reset(from := Vector3(0, .025, 6), to := Vector3(0, .025, -6)) -> void:
	for obstacle in obstacles:
		obstacle.queue_free()
	obstacles.clear()
	await physics_frame
	arena.world_mode = false
	arena.mode = 1
	arena.roster = {1: {"champion": "Vanguard", "team": 0}, 2: {"champion": "Fulcrum", "team": 1}}
	arena.begin_round()
	arena.phase = "match"
	a = arena.actors[1]
	b = arena.actors[2]
	a.position = from
	b.position = to
	a.look_at(Vector3(to.x, from.y, to.z))
	for actor in [a, b]:
		actor.owner_peer = actor.actor_id
	positions.clear()
	await physics_frame

func box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	arena.add_child(body)
	body.position = at
	obstacles.append(body)

func capsule_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = a.get_child(0).shape
	query.transform = a.transform * a.get_child(0).transform
	query.collision_mask = 1
	return arena.get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func step(delta := 1.0 / 60.0) -> void:
	var stamp := Time.get_ticks_usec()
	arena.tick_actor(a, delta)
	peak_tick_ms = maxf(peak_tick_ms, (Time.get_ticks_usec() - stamp) / 1000.0)
	positions.append(a.position)
	ck(capsule_clear(), "Charge capsule never penetrates map or test obstacles at %s; target %s" % [a.position, b.position])
	await physics_frame

func finish(limit := 240) -> void:
	for i in range(limit):
		if a.charge.is_empty(): break
		await step()
	ck(a.charge.is_empty() and a.position.distance_to(b.position) <= 1.9, "Accepted Charge reaches melee range along its safe route")
	ck(b.hp == 94, "Charge deals six damage exactly once on arrival")

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await reset()
	var before: Vector3 = a.position
	a.gcd = 1.0
	ck(arena.try_spell(1, 6, 2), "Charge starts off the GCD")
	ck(b.identity.root == 1.5 and arena.CC.remaining(b, "root") == 1.5, "Successful cast immediately roots the enemy for 1.5 seconds")
	ck(a.position == before and b.hp == 100 and not a.charge.is_empty(), "Cast starts travel without teleporting or dealing early damage")
	ck(a.cooldowns[6] == 12 and a.gcd == 1, "Charge keeps its twelve-second cooldown and leaves the GCD alone")
	var charge_root := false
	for aura in arena.Auras.active(b):
		charge_root = charge_root or (aura.key == "root" and aura.source == "Charge" and aura.remaining == 1.5)
	ck(charge_root, "Root aura identifies Charge as its source")
	await step()
	ck(a.position.distance_to(before) > .4 and a.position.distance_to(before) < .6, "Travel is visibly spread over physics frames at 32 meters per second")
	arena.apply_input(1, Vector2(1, 1), PI, true, 2)
	ck(not a.jump_queued and not arena.try_spell(1, 6, 2), "Jumping and recasting cannot overwrite an active Charge")
	await finish()
	ck(positions.size() >= 15 and positions.size() <= 25, "An open twelve-meter approach takes roughly a third of a second")
	arena.CC.tick(b, 3)
	ck(b.identity.root == 0, "The root expires normally")
	await reset(Vector3(0, .925, 6), Vector3(0, .025, -6))
	ck(arena.try_spell(1, 6, 2), "An airborne caster can enter a safe ground route")
	await finish()
	await reset(Vector3(0, .025, 6), Vector3(0, .925, -6))
	ck(arena.try_spell(1, 6, 2) and b.identity.root == 1.5, "A jumping target can be rooted and approached safely")
	await finish()
	await reset(Vector3(-6, .025, 10), Vector3(-6, .025, 0))
	ck(not arena.try_spell(1, 6, 2) and a.cooldowns[6] == 0 and b.identity.root == 0, "Initial LOS failure spends nothing and does not root")
	await reset(Vector3(-6, .025, 10), Vector3(-1, .025, 6))
	ck(arena.try_spell(1, 6, 2), "Charge accepts an initially visible enemy beside cover")
	await step()
	b.position = Vector3(-6, .025, 0)
	ck(not arena.has_los(a, b), "Displaced target is now hidden behind a real pillar")
	await finish()
	var detoured := false
	for point in positions:
		detoured = detoured or absf(point.x + 6) > 3
	ck(detoured, "Committed Charge detours around the pillar after LOS is lost")
	await reset()
	ck(arena.try_spell(1, 6, 2), "Charge starts before a new blocker appears")
	box(Vector3(0, 1.5, 0), Vector3(4, 3, .3))
	await physics_frame
	await finish()
	# A long frame still sweeps every subsegment instead of tunneling.
	await reset()
	ck(arena.try_spell(1, 6, 2), "Long-frame Charge starts")
	box(Vector3(0, 1.5, 0), Vector3(4, 3, .1))
	await physics_frame
	await step(.5)
	ck(a.position.z > 0 and b.hp == 100, "A long physics frame cannot tunnel through a thin wall or damage through it")
	await finish()
	for side in [-1.0, 1.0]:
		await reset(Vector3(side * 10, .025, 0), Vector3(side * 15, 1.225, 0))
		ck(arena.try_spell(1, 6, 2), "Charge accepts a visible target on a terrace")
		await finish()
		var used_ramp := false
		for point in positions:
			used_ramp = used_ramp or absf(point.z) >= 9.5
		ck(used_ramp and a.position.y > 1.1, "Charge reaches the raised target through a ramp without climbing through the ledge")
		await reset(Vector3(side * 15, 1.225, 0), Vector3(side * 10, .025, 0))
		ck(arena.try_spell(1, 6, 2), "Charge accepts a target below the terrace")
		await finish()
	await reset(Vector3(0, .025, 6), Vector3(0, 1.225, 0))
	box(Vector3(0, .6, 0), Vector3(3, 1.2, 3))
	await physics_frame
	ck(arena.has_los(a, b), "Unreachable platform fixture is visible at cast height")
	ck(not arena.try_spell(1, 6, 2) and a.charge.is_empty() and b.identity.root == 0 and a.cooldowns[6] == 0, "A target with no safe path is rejected before any cast effects are spent")
	await reset()
	ck(arena.try_spell(1, 6, 2), "Death cleanup fixture starts Charge")
	b.hp = 0
	await step()
	ck(a.charge.is_empty() and a.velocity == Vector3.ZERO, "Target death releases the charger safely")
	await reset()
	arena.world_mode = true
	ck(not arena.try_spell(1, 6, 2) and b.identity.root == 0, "Charge cannot root a world bystander")
	arena.duels = {1: 2, 2: 1}
	ck(arena.try_spell(1, 6, 2), "Charge starts against a duel opponent")
	arena.duels.clear()
	await step()
	ck(a.charge.is_empty() and b.hp == 100, "Ending the duel cancels pending Charge damage")
	await reset()
	arena.try_spell(1, 6, 2)
	await step()
	var state: Dictionary = a.snapshot()
	var receiver = load("res://scripts/combatant.gd").new()
	arena.add_child(receiver)
	receiver.setup(3, 3, 0, "Vanguard", false)
	receiver.receive(bytes_to_var(var_to_bytes(state)), true)
	ck(receiver.charge.target == 2 and receiver.charge.path == a.charge.path, "Snapshot replicates Charge target and remaining route")
	var receiver_before: Vector3 = receiver.position
	arena.simulate_movement(receiver, 1.0 / 60.0)
	ck(receiver.position.distance_to(receiver_before) > .4 and b.hp == 100, "Client movement replay advances Charge without applying combat damage")
	ck(receiver.charge.path != a.charge.path, "Client route progress cannot mutate the authoritative path")
	receiver.reset_identity()
	ck(receiver.charge.is_empty(), "Round and duel identity resets clear Charge")
	receiver.queue_free()
	print("Vanguard Charge checks: %d passed / %d total" % [checks - failures, checks])
	print("Peak charge tick: %.2f ms" % peak_tick_ms)
	quit(1 if failures else 0)
