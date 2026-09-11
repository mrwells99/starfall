extends SceneTree
## Hold network snapshots between 20Hz updates while real animators run at 60Hz.
var checks := 0
var failures := 0
const DT := 1.0 / 60.0
class FxArena extends Node3D:
	const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
	var actors := {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func fighter(title: String):
	var a = load("res://scripts/combatant.gd").new()
	root.add_child(a)
	a.setup(1, 1, 0, title)
	return a

func run() -> void:
	for title in ["Ember", "Luminary", "Vanguard", "Fulcrum", "Outlaw"]:
		var a = fighter(title)
		var art = a.champion_model.get(title.to_lower() + "_art")
		var state: Dictionary = a.snapshot()
		state.grounded = true
		state.velocity = Vector3(0, 0, -6.5)
		var modes := {}
		var min_speed := INF
		var max_speed := 0.0
		for frame in 120:
			if frame % 3 == 0:
				state.pos = Vector3(0, 0, -6.5 * frame * DT)
				a.receive(state)
			a.position = a.position.lerp(a.net_position, DT * 22.0)
			a.champion_model.animate(DT, a)
			if frame > 30:
				modes[art.clip] = true
				min_speed = minf(min_speed, art.filtered_speed)
				max_speed = maxf(max_speed, art.filtered_speed)
		print("AUDIT %s remote run: clips=%s speed=%.3f..%.3f" % [title, modes.keys(), min_speed, max_speed])
		check(modes.size() == 1 and modes.has("Sprint"), title + " steady remote movement cannot alternate run/sprint each packet")
		check(max_speed - min_speed < .05, title + " network smoothing cannot pump animation cadence")
		# Predicted movement can include reconciliation offsets unrelated to gait.
		modes.clear()
		for frame in 60:
			a.presentation_grounded = null
			a.velocity = Vector3(0, 0, -6.5)
			a.position += a.velocity * DT + Vector3(0, 0, .15 if frame % 3 == 0 else 0.0)
			a.champion_model.animate(DT, a)
			modes[art.clip] = true
		check(modes.size() == 1 and modes.has("Sprint"), title + " local reconciliation offsets cannot change the gait")
		state.velocity = Vector3.ZERO
		a.receive(state)
		a.position += Vector3.FORWARD * .1
		a.champion_model.animate(DT, a)
		check(art.clip == "Idle", title + " stopping is not delayed by residual position smoothing")
		a.queue_free()
		await process_frame
		a = fighter(title)
		art = a.champion_model.get(title.to_lower() + "_art")
		state = a.snapshot()
		state.grounded = false
		var held := 0
		var previous_lift := -1.0
		for frame in 20:
			if frame % 3 == 0:
				state.velocity = Vector3(0, 7.0 - 20.0 * frame * DT, 0)
				a.receive(state)
			a.champion_model.animate(DT, a)
			if frame > 8 and is_equal_approx(art.jump_pose.lift, previous_lift): held += 1
			previous_lift = art.jump_pose.lift
		print("AUDIT %s remote jump arm layer: held=%d" % [title, held])
		check(held == 0, title + " jump arm pose advances between packets")
		a.queue_free()
		await process_frame
		a = fighter(title)
		art = a.champion_model.get(title.to_lower() + "_art")
		state = a.snapshot()
		state.grounded = true
		state.casting = 0
		state.left = 2.0
		held = 0
		var previous_time := -1.0
		for frame in 70:
			if frame % 3 == 0: a.receive(state)
			a.champion_model.animate(DT, a)
			if frame > 30 and is_equal_approx(art.player.current_animation_position, previous_time): held += 1
			previous_time = art.player.current_animation_position
		check(held == 0, title + " regular cast/aim base animation advances independently of packets")
		a.queue_free()
		await process_frame
	await roll_and_coin()
	motion_edge_cases()
	print("Network animation audit: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)

func roll_and_coin() -> void:
	var a = fighter("Outlaw")
	var art = a.champion_model.outlaw_art
	var state: Dictionary = a.snapshot()
	state.grounded = true
	state.identity.roll_direction = Vector3.RIGHT
	var held := 0
	var previous := -1.0
	for frame in 29:
		if frame % 3 == 0:
			state.identity.roll_left = art.Outlaw.ROLL_SECONDS - frame * DT
			a.receive(state)
		a.champion_model.animate(DT, a)
		if frame > 6 and is_equal_approx(art.player.current_animation_position, previous): held += 1
		previous = art.player.current_animation_position
	print("AUDIT remote Roll: held=%d" % held)
	check(held == 0, "Roll advances its skeletal pose between packets")
	state.identity.roll_left = 0.0
	a.receive(state)
	a.champion_model.animate(DT, a)
	check(not art.roll_clock.playing, "Authoritative Roll cancellation stops its local pose clock")
	# The lasso branch extends cosmetic Roll beyond the end of physical travel.
	# Both phases must advance smoothly without restarting at that boundary.
	state.identity.outlaw_action = "roll"
	previous = -1.0
	var reversed := 0
	held = 0
	for frame in 36:
		if frame % 3 == 0:
			state.identity.roll_left = maxf(0, art.Outlaw.ROLL_SECONDS - frame * DT)
			state.identity.roll_animation_left = art.Outlaw.ROLL_PRESENTATION_SECONDS - frame * DT
			a.receive(state)
		a.champion_model.animate(DT, a)
		var phase: float = art.player.current_animation_position / art.player.current_animation_length
		if frame > 6:
			if is_equal_approx(phase, previous): held += 1
			if phase < previous: reversed += 1
		previous = phase
	check(held == 0 and reversed == 0, "Slower Roll and post-travel recovery share one smooth network clock")
	check(previous > .5 and previous <= art.Outlaw.ROLL_END_PHASE, "Recovery continues past travel without sampling the standing tail")
	state.identity.roll_animation_left = 0.0
	a.receive(state)
	a.champion_model.animate(DT, a)
	check(not art.roll_clock.playing, "Finished recovery stops the local Roll clock")
	var scene := FxArena.new()
	root.add_child(scene)
	scene.actors = {1: a}
	var fx = load("res://scripts/outlaw_effects.gd").new()
	scene.add_child(fx)
	fx.install(scene)
	fx.set_process(false)
	state.identity.roll_left = 0.0
	state.identity.coin_origin = Vector3(0, 1, 0)
	state.identity.coin_direction = Vector3.FORWARD
	held = 0
	var old_position := Vector3.ZERO
	for frame in 50:
		if frame % 3 == 0:
			var t := frame * DT
			state.identity.coin_left = fx.arena.Outlaw.COIN_SECONDS - t
			state.identity.coin_position = state.identity.coin_origin + Vector3.FORWARD * fx.arena.Outlaw.COIN_SPEED * t + Vector3.UP * (5.4 * t - 3.0 * t * t)
			a.receive(state)
		var before: Dictionary = a.identity.duplicate(true)
		fx._process(DT)
		if frame > 8 and fx.coins[1].position.is_equal_approx(old_position): held += 1
		old_position = fx.coins[1].position
		check(before == a.identity, "Coin presentation does not alter the server's hit/ricochet position")
	print("AUDIT Coin Toss: held=%d" % held)
	check(held == 0, "Coin Toss travels between packets")
	state.identity.coin_left = 0.0
	a.receive(state)
	fx._process(DT)
	check(not fx.coins[1].visible and not fx.coin_tracks[1].clock.playing, "Consumed/expired coin hides and stops immediately")
	# The next coin can use the same seed and still starts a fresh local clock.
	state.identity.coin_left = fx.arena.Outlaw.COIN_SECONDS
	state.identity.coin_position = state.identity.coin_origin
	a.receive(state)
	fx._process(DT)
	check(fx.coins[1].position.is_equal_approx(state.identity.coin_origin), "Repeated coin toss resets at the same origin")
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 1, -.15)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 4, .1)
	collider.shape = box
	wall.add_child(collider)
	scene.add_child(wall)
	await physics_frame
	await physics_frame
	for frame in 12: fx._process(DT)
	check(fx.coins[1].position.z >= -.101, "Between-packet visual coin travel cannot cross a wall")
	a.hp = 0
	fx._process(DT)
	check(not fx.coins[1].visible, "Caster death clears the coin")
	scene.actors.clear()
	fx._process(DT)
	check(fx.coins.is_empty() and fx.coin_tracks.is_empty(), "Actor removal clears visual nodes and clocks")
	scene.queue_free()
	a.queue_free()
	await process_frame

func motion_edge_cases() -> void:
	var a = fighter("Fulcrum")
	var motion = preload("res://scripts/network_animation_motion.gd").new()
	a.velocity = Vector3(20, 7, 0)
	var observed := Vector3(.03, 0, -.04)
	check(motion.displacement(a, observed, DT) == observed, "Offline gait continues to use actual displacement")
	var state: Dictionary = a.snapshot()
	state.grounded = false
	state.velocity = Vector3(0, 7, 0)
	a.receive(state)
	check(motion.vertical(a, DT) == 7.0, "Remote takeoff starts at reported velocity")
	for frame in 6: motion.vertical(a, DT)
	check(absf(motion.vertical_speed - 5.0) < .001, "Jump arm trajectory follows gravity between packets")
	for frame in 60: motion.vertical(a, DT)
	check(absf(motion.vertical_speed - 2.0) < .001, "Vertical projection is bounded during a packet outage")
	state.grounded = true
	state.velocity = Vector3.ZERO
	a.receive(state)
	check(motion.vertical(a, DT) == 0 and not motion.in_flight, "Landing cancels projected jump motion immediately")
	state.grounded = false
	state.velocity = Vector3(0, 4, 0)
	state.motion_revision += 1
	a.receive(state)
	check(motion.vertical(a, DT) == 4, "New motion revision uses its actual vertical state")
	a.presentation_grounded = null
	a.velocity = Vector3(3, 6, -4)
	check(motion.vertical(a, DT) == 6 and motion.displacement(a, observed, DT).is_equal_approx(Vector3(3, 0, -4) * DT),
		"Predicted player animation follows current local physics, not received velocity")
	state.erase("velocity")
	a.receive(state)
	check(motion.displacement(a, observed, DT) == observed, "Missing velocity in older snapshots falls back to measured movement")
	a.queue_free()
