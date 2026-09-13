extends "res://tests/null_abilities_test.gd"
## Focused actual-capsule checks for Vantage's proximity acceleration.
var results: Dictionary = {}

class PredictionWorld:
	extends RefCounted
	var actors: Dictionary = {}
	func authoritative() -> bool: return false
	func may_harm(source, target) -> bool: return source.team != target.team

func begin_dive(distance: float, air: bool = false) -> void:
	await reset()
	a.position = Vector3(0, 2.0 if air else .025, 12)
	b.position = Vector3(0, .025, 12 - distance)
	ck(game.try_spell(1, 7, 2), "Vantage accepts %.1f m%s fixture" % [distance, " airborne" if air else ""])
	game.Null.motion(game, a, .5)
	ck(a.identity.null_vantage.get("phase", "") == "dive" and is_equal_approx(a.velocity.length(), 4.0), "Dive begins at 4 m/s, not its final rush speed")

func profile(distance: float, step: float, air: bool = false) -> void:
	await begin_dive(distance, air)
	var state: Dictionary = a.identity.null_vantage
	var fixed_distance: float = state.dive_distance
	var base: float = state.dive_speed
	var total := 0.0
	var early_peak := 0.0
	var late_peak := 0.0
	var previous_speed := 4.0
	var previous_progress := 0.0
	var monotonic := true
	var bounded := true
	var fixed := true
	var first_position: Vector3 = a.position
	var early_distance := 0.0
	var halfway_position := Vector3.ZERO
	while total < 1.0 and state.phase == "dive":
		game.Null.motion(game, a, step)
		total += step
		var speed: float = state.dive_current_speed
		var progress: float = state.dive_progress
		monotonic = monotonic and speed + .00001 >= previous_speed and progress + .00001 >= previous_progress
		bounded = bounded and speed >= 4.0 and speed <= 65.00001 and progress >= 0.0 and progress <= 1.0
		fixed = fixed and is_equal_approx(state.dive_distance, fixed_distance) and is_equal_approx(state.dive_speed, base)
		if total <= .10 + .00001: early_peak = maxf(early_peak, speed)
		if total <= .05 + .00001: early_distance = first_position.distance_to(a.position)
		if absf(total - .20) < .00001: halfway_position = a.position
		if progress >= .7: late_peak = maxf(late_peak, speed)
		previous_speed = speed
		previous_progress = progress
	ck(monotonic, "Stationary-target progress and speed increase smoothly at %.0f Hz" % (1.0 / step))
	ck(bounded and fixed, "Profile stays fixed and speed/progress remain bounded at %.0f Hz" % (1.0 / step))
	ck(early_distance > 0 and early_distance < base * .05 * .70, "First 50 ms travels substantially less than an instant full-speed dive")
	ck(early_peak > 4.0 and late_peak > early_peak * 1.5, "Final approach is at least 50 percent faster than the early approach")
	ck(b.hp == 1280 and is_equal_approx(b.stunned, 4.0) and state.phase == "recover", "Every speed profile delivers one original-strength hit on contact")
	ck(a.position.distance_to(b.position) >= .98 and a.position.distance_to(b.position) <= 1.02, "Acceleration stops at the original one-meter contact envelope")
	ck(total < .6, "Eased dive still reaches this stationary target within 0.6 seconds")
	print("VANTAGE_SPEED range=", distance, " air=", air, " hz=", 1.0 / step, " dive_seconds=", total, " early_peak=", early_peak, " late_peak=", late_peak, " ratio=", late_peak / maxf(early_peak, .001))
	if not air:
		var rows: Array = results.get(distance, [])
		rows.append({"time": total, "position_at_point_two": halfway_position})
		results[distance] = rows
	game.Null.motion(game, a, .179)
	ck(game.Null.busy(a), "Recovery is not shortened by an accelerated impact")
	game.Null.motion(game, a, .002)
	ck(not game.Null.busy(a) and b.hp == 1280, "Recovery still ends at 0.18 seconds without duplicate damage")

func timestep_comparison() -> void:
	for distance in results:
		var rows: Array = results[distance]
		var fine: Dictionary = rows.back()
		var maximum_time_error := 0.0
		var maximum_position_error := 0.0
		for row in rows:
			maximum_time_error = maxf(maximum_time_error, absf(row.time - fine.time))
			maximum_position_error = maxf(maximum_position_error, row.position_at_point_two.distance_to(fine.position_at_point_two))
		ck(maximum_time_error <= .05, "30/60/120/240 Hz contact times stay within 50 ms at %.0f m" % distance)
		ck(maximum_position_error < .12, "30/60/120/240 Hz positions at 0.2 s stay within 12 cm at %.0f m" % distance)
		ck(rows[0].position_at_point_two.distance_to(rows[1].position_at_point_two) < .0001, "A 30 Hz call subdivides to the same trajectory as two 60 Hz steps")
		print("VANTAGE_DT range=", distance, " maximum_time_error=", maximum_time_error, " maximum_position_error=", maximum_position_error)

func retreat_and_timeout() -> void:
	await begin_dive(6.0)
	game.Null.motion(game, a, .2)
	var state: Dictionary = a.identity.null_vantage
	var base: float = state.dive_speed
	var distance: float = state.dive_distance
	var progress: float = state.dive_progress
	var speed: float = state.dive_current_speed
	b.position.z -= 30.0
	game.Null.motion(game, a, 1.0 / 60)
	ck(is_equal_approx(state.dive_speed, base) and is_equal_approx(state.dive_distance, distance), "Retreat never rebases the stored initial distance or range scale")
	ck(is_equal_approx(state.dive_progress, progress) and state.dive_current_speed >= speed and state.dive_current_speed <= 65.0, "Retreat neither reverses progress nor restarts acceleration")
	# Isolate the chase deadline from the arena boundary/cover. Swept wall
	# cancellation is checked separately below; this target retreats vertically.
	a.position = Vector3(0, 30, 0)
	var passed_two_seconds := false
	var bounded := true
	for frame in 180:
		if not game.Null.busy(a): break
		b.position = a.position + Vector3.UP * 12.0
		game.Null.motion(game, a, 1.0 / 60)
		bounded = bounded and a.velocity.length() <= 65.00001
		passed_two_seconds = float(state.elapsed) >= 1.98
	ck(bounded and not game.Null.busy(a) and passed_two_seconds and b.hp == 1500, "An endlessly retreating target keeps the speed cap and the two-second chase limit")

func snapshot_replay() -> void:
	await begin_dive(18.0)
	game.Null.motion(game, a, .15)
	var snapshot: Dictionary = a.snapshot()
	var copied = load("res://scripts/combatant.gd").new()
	game.add_child(copied)
	copied.setup(3, 3, 0, "Null", false)
	copied.receive(snapshot, true)
	copied.velocity = snapshot.velocity
	var world := PredictionWorld.new()
	world.actors = {2: b}
	var parity := true
	var maximum_error := 0.0
	for frame in 80:
		var step: float = [1.0 / 30, 1.0 / 60, 1.0 / 120, 1.0 / 240][frame % 4]
		game.Null.motion(world, a, step)
		game.Null.motion(world, copied, step)
		maximum_error = maxf(maximum_error, a.position.distance_to(copied.position))
		parity = parity and a.velocity.distance_to(copied.velocity) < .0001 and a.identity.null_vantage == copied.identity.null_vantage
	ck(parity and maximum_error < .0001, "A deep-copied in-flight snapshot replays the same acceleration and motion at mixed tick sizes")
	ck(b.hp == 1500 and b.stunned == 0, "Predictive contact cannot apply damage or crowd control")
	ck(a.identity.null_vantage.get("phase", "") == "dive", "Prediction leaves authoritative contact/recovery confirmation to the server")
	copied.free()

func interrupted_sweeps() -> void:
	await begin_dive(18.0)
	var obstacle := wall(Vector3(0, 3, 8), Vector3(2, 10, .2))
	await physics_frame
	game.Null.motion(game, a, .5)
	ck(not game.Null.busy(a) and a.position.z > 8 and b.hp == 1500, "A long accelerated step still sweeps the wall instead of tunneling or hitting through cover")
	obstacle.free()
	await physics_frame
	for reason in ["stun", "root", "death", "target_death", "target_concealed"]:
		await begin_dive(6.0)
		game.Null.motion(game, a, .2)
		match reason:
			"stun": a.stunned = 1.0
			"root": a.identity.root = 1.0
			"death": a.hp = 0.0
			"target_death": b.hp = 0.0
			"target_concealed": b.identity.stealth = true
		var health: float = b.hp
		game.Null.motion(game, a, .3)
		ck(not game.Null.busy(a) and a.velocity == Vector3.ZERO and b.hp == health, "Accelerating dive cancels cleanly on " + reason)

func run() -> void:
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for distance in [6.0, 18.0]:
		for step in [1.0 / 30, 1.0 / 60, 1.0 / 120, 1.0 / 240]:
			await profile(distance, step)
	await profile(6.0, 1.0 / 60, true)
	timestep_comparison()
	await retreat_and_timeout()
	await snapshot_replay()
	await interrupted_sweeps()
	print("Null Vantage speed checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
