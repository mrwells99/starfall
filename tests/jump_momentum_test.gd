extends SceneTree

const STEP := 1.0 / 60.0
var arena
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func reset_body(actor, x: float = 0.0) -> void:
	actor.hp = 100
	actor.stunned = 0
	actor.sprint = 0
	for status in ["root", "hold", "slow"]:
		actor.identity[status] = 0
	actor.position = Vector3(x, 0.02, 4)
	actor.rotation.y = 0
	actor.move_input = Vector2.ZERO
	actor.jump_queued = false
	actor.velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
		arena.simulate_movement(actor, STEP)
	check(actor.is_on_floor(), "Movement fixture starts on the arena floor")

func launch(actor, movement: Vector2 = Vector2(0, -1)) -> void:
	actor.move_input = movement
	actor.jump_queued = true
	arena.simulate_movement(actor, STEP)

func horizontal(actor) -> Vector2:
	return Vector2(actor.velocity.x, actor.velocity.z)

func command(seq: int, movement: Vector2, yaw: float = 0.0, jump: bool = false) -> Dictionary:
	return {"seq": seq, "move": movement, "yaw": yaw, "jump": jump, "delta": STEP}

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.local_match()
	arena.phase = "match"
	var actor = arena.actors[arena.local_id]
	actor.owner_peer = 1
	var remote = arena.actors[2]
	remote.owner_peer = 9
	remote.position = Vector3(8, 0, 0)
	await reset_body(actor)
	check(actor.snapshot().grounded, "Snapshots include authoritative floor contact")
	launch(actor)
	check(not actor.is_on_floor() and is_equal_approx(actor.velocity.z, -6.5) and actor.velocity.y > 0, "Running jump launches at the full horizontal movement speed")
	var launch_y: float = actor.velocity.y
	var start: Vector3 = actor.position
	var preserved := true
	for step in range(12):
		await physics_frame
		# Release, reverse, strafe, and turn while already airborne.
		var inputs := [Vector2.ZERO, Vector2(0, 1), Vector2(1, 0)]
		arena.apply_input(actor.actor_id, inputs[step % 3], step * 0.45, step == 3, -1)
		arena.simulate_movement(actor, STEP)
		preserved = preserved and horizontal(actor).is_equal_approx(Vector2(0, -6.5))
	check(preserved and actor.position.z < start.z - 1.0, "Airborne release, reversal, strafe, yaw changes, and repeated jump input preserve world-space takeoff momentum")
	check(actor.velocity.y < launch_y, "Jump input in the air cannot reset gravity or double jump")
	actor.rotation.y = 0
	actor.move_input = Vector2(1, 0)
	for frame in range(80):
		if actor.is_on_floor():
			break
		await physics_frame
		arena.simulate_movement(actor, STEP)
	check(actor.is_on_floor(), "Momentum jump lands normally")
	arena.simulate_movement(actor, STEP)
	check(horizontal(actor).is_equal_approx(Vector2(6.5, 0)), "Ground contact restores immediate directional input")
	actor.move_input = Vector2.ZERO
	arena.simulate_movement(actor, STEP)
	check(horizontal(actor) == Vector2.ZERO, "Releasing input after landing stops immediately")
	await reset_body(actor)
	launch(actor, Vector2.ZERO)
	actor.move_input = Vector2(0, -1)
	await physics_frame
	arena.simulate_movement(actor, STEP)
	check(horizontal(actor) == Vector2.ZERO, "A stationary jump stays stationary when movement is pressed in the air")
	for status in ["stunned", "root", "hold"]:
		await reset_body(actor)
		launch(actor)
		if status == "stunned":
			actor.stunned = 2
		else:
			actor.identity[status] = 2
		await physics_frame
		arena.simulate_movement(actor, STEP)
		check(horizontal(actor) == Vector2.ZERO and actor.velocity.y > 0, "%s cancels airborne horizontal momentum without bypassing gravity" % status)
		actor.stunned = 0
		actor.identity.root = 0
		actor.identity.hold = 0
		await physics_frame
		arena.simulate_movement(actor, STEP)
		check(horizontal(actor) == Vector2.ZERO, "%s ending in midair does not restore cancelled momentum" % status)
	await reset_body(actor)
	actor.sprint = 2
	launch(actor)
	actor.sprint = 0
	actor.identity.slow = 2
	actor.move_input = Vector2.ZERO
	await physics_frame
	arena.simulate_movement(actor, STEP)
	check(is_equal_approx(actor.velocity.z, -6.5 * 1.65), "Speed effects changing after takeoff preserve the velocity established at launch")
	actor.hp = 0
	actor.jump_queued = true
	arena.simulate_movement(actor, STEP)
	check(actor.velocity == Vector3.ZERO and not actor.jump_queued, "Death clears momentum and queued jump")
	# Feed identical commands through the authoritative and predicted paths.
	await reset_body(actor, -2)
	await reset_body(remote, 2)
	arena.prediction.reset()
	var initial_offset: Vector3 = remote.position - actor.position
	var parity := true
	var descending: Dictionary
	for seq in range(1, 49):
		await physics_frame
		var input: Vector2 = Vector2(0, -1) if seq == 1 else Vector2.ZERO if seq < 9 else Vector2(1, 0)
		var next := command(seq, input, seq * 0.07 if seq > 1 else 0.0, seq == 1)
		arena.apply_input(actor.actor_id, next.move, next.yaw, next.jump, -1)
		arena.simulate_movement(actor, STEP)
		arena.prediction.predict(arena, remote, next)
		var offset: Vector3 = remote.position - actor.position - initial_offset
		# Different floor triangles can settle a few millimeters apart; compare
		# velocity and horizontal travel exactly, with floor-recovery tolerance in Y.
		var step_matches: bool = actor.velocity.is_equal_approx(remote.velocity) and Vector2(offset.x, offset.z).length() < 0.001 and absf(offset.y) < 0.01
		parity = parity and step_matches
		if seq == 28:
			descending = actor.snapshot()
			descending.pos += Vector3(4, 0, 0)
	check(parity, "Authority and client prediction match through takeoff, airborne input changes, and landing")
	check(not descending.grounded and descending.velocity.y < 0, "Reconciliation fixture captures an airborne descending server state")
	await reset_body(remote, 2)
	arena.prediction.revision = descending.motion_revision
	arena.prediction.history = [command(50, Vector2(1, 0), PI)]
	arena.prediction.pending = descending
	arena.prediction.reconcile(arena, remote)
	check(horizontal(remote).is_equal_approx(Vector2(descending.velocity.x, descending.velocity.z)), "Replaying an airborne snapshot ignores stale local floor contact and keeps server momentum")
	# A forced rewind can skip replay entirely; its next prediction still needs
	# the restored floor state, including when the local player had already landed.
	await reset_body(remote, 2)
	descending.motion_revision += 1
	arena.prediction.history = [command(51, Vector2(1, 0))]
	arena.prediction.pending = descending.duplicate(true)
	arena.prediction.reconcile(arena, remote)
	check(arena.prediction.history.is_empty(), "Forced displacement still discards stale prediction history")
	arena.prediction.predict(arena, remote, command(52, Vector2(1, 0), PI))
	check(horizontal(remote).is_equal_approx(Vector2(descending.velocity.x, descending.velocity.z)), "The first predicted input after a forced airborne correction preserves server momentum")
	await reset_body(actor, -2)
	var grounded: Dictionary = actor.snapshot()
	grounded.pos += Vector3(4, 0, 0)
	await reset_body(remote, 2)
	launch(remote)
	arena.prediction.revision = grounded.motion_revision
	arena.prediction.history = [command(53, Vector2(0, -1), 0, true)]
	arena.prediction.pending = grounded
	arena.prediction.reconcile(arena, remote)
	check(remote.velocity.y > 6 and horizontal(remote).is_equal_approx(Vector2(0, -6.5)), "Replaying a grounded server snapshot allows a queued jump despite stale local airborne contact")
	arena.prediction.reset()
	check(arena.prediction.grounded_override == null, "Round reset clears the prediction contact override")
	print("Jump momentum checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
