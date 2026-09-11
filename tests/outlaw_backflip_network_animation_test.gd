extends SceneTree
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/combatant.gd").new()
	root.add_child(actor)
	actor.setup(1, 1, 0, "Outlaw")
	var art = actor.champion_model.outlaw_art
	var state: Dictionary = actor.snapshot()
	state.identity.backflip_active = true
	state.identity.backflip_combo = true
	state.grounded = false
	state.velocity = Vector3(0, 3, 8)
	state.motion_revision += 1
	var unchanged := 0
	var backwards := 0
	var previous := 100.0
	for frame in 54:
		if frame % 3 == 0:
			state.identity.backflip_elapsed = frame / 60.0
			actor.receive(state)
		var before: Dictionary = actor.identity.duplicate(true)
		actor.champion_model.animate(1.0 / 60.0, actor)
		var current: float = art.player.current_animation_position
		if frame > 9:
			if is_equal_approx(current, previous): unchanged += 1
			if current > previous + .0001: backwards += 1
		check(actor.identity == before, "Animation does not advance gameplay timers or combo permission")
		previous = current
	print("20 Hz snapshots / 60 Hz animation: %d held poses, %d reversed steps over 44 measured steps" % [unchanged, backwards])
	check(unchanged == 0, "Backflip advances its pose between snapshots")
	check(backwards == 0, "Backflip never scrubs backward on a fresh snapshot")
	state.identity.backflip_active = false
	state.identity.backflip_combo = false
	state.grounded = true
	actor.receive(state)
	actor.champion_model.animate(1.0 / 60.0, actor)
	check(not art.backflip_clock.playing and art.special_kind != "backflip", "Authoritative early landing immediately ends the visual clock")
	clock_edge_cases()
	actor.queue_free()
	await process_frame
	print("Online backflip checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)

func clock_edge_cases() -> void:
	var clock = preload("res://scripts/outlaw_backflip_clock.gd").new()
	for rate in [30, 60, 144]:
		clock.reset()
		var serial := 1
		var report := 0.0
		var previous := clock.advance(report, 1.0 / rate, serial, 1, 1.1)
		var frozen := false
		var jumped := false
		for frame in range(1, int(rate * .85)):
			var time := frame / float(rate)
			# Uneven packet spacing, one 200ms gap, and changing packet delay.
			if frame % maxi(1, roundi(rate / 20.0)) == 0 and not (time > .25 and time < .45):
				serial += 1
				report = maxf(report, time - (.03 if serial % 2 == 0 else 0.0))
			var current: float = clock.advance(report, 1.0 / rate, serial, 1, 1.1)
			frozen = frozen or current <= previous
			jumped = jumped or current - previous > 1.21 / rate
			previous = current
		check(not frozen and not jumped, "Jitter and packet gaps preserve continuous forward pose time at %d Hz" % rate)
	clock.reset()
	check(is_equal_approx(clock.advance(.6, .016, 1, 2, 1.1), .6), "Late visibility starts at the reported airborne phase")
	check(is_equal_approx(clock.advance(.05, .016, 2, 3, 1.1), .05), "A new movement revision starts a fresh flip instead of inheriting old pose time")
	for i in 100: clock.advance(.05, .016, 2, 3, 1.1)
	check(is_equal_approx(clock.elapsed, 1.1), "A long packet outage cannot run past the final pose or loop the animation")
	clock.reset()
	check(clock.advance(.25, .016, 0, 0, 1.1) == .25 and clock.advance(.4, .016, 0, 0, 1.1) == .4,
		"Offline and authoritative animation retain their exact existing timer")
