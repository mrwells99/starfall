extends SceneTree
## Real visible/compact rigs: continuous Vantage phases, not isolated still poses.
const Fighter = preload("res://scripts/combatant.gd")
const STEP := 1.0 / 60.0
var checks := 0
var failures := 0
var maximum_parity_error := 0.0
var animation_preserved_gameplay := true

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func pair(yaw: float = 0.0) -> Array:
	var visible = Fighter.new()
	var server = Fighter.new()
	root.add_child(visible)
	root.add_child(server)
	visible.setup(1, 1, 0, "Null")
	server.setup(2, 2, 1, "Null", false)
	for actor in [visible, server]:
		actor.rotation.y = yaw
		actor.position = Vector3(1.5, 2.0, -3.0)
		actor.setup_hitboxes()
		actor.presentation_grounded = true
	return [visible, server]

func gameplay(actor) -> Dictionary:
	var shape: CapsuleShape3D = actor.get_child(0).shape
	return {
		"transform": actor.transform, "velocity": actor.velocity,
		"identity": actor.identity.duplicate(true), "charge": actor.charge.duplicate(true),
		"cooldowns": actor.cooldowns.duplicate(), "hp": actor.hp, "gcd": actor.gcd,
		"casting": actor.casting, "cast_left": actor.cast_left, "cast_target": actor.cast_target,
		"jump_queued": actor.jump_queued, "jump_buffer": actor.jump_buffer,
		"move_input": actor.move_input, "motion_revision": actor.motion_revision,
		"stunned": actor.stunned, "locked": actor.locked,
		"capsule_radius": shape.radius, "capsule_height": shape.height,
		"collision_layer": actor.collision_layer, "collision_mask": actor.collision_mask,
		"presentation_grounded": actor.presentation_grounded,
		"presentation_vertical_speed": actor.presentation_vertical_speed,
		"presentation_velocity": actor.presentation_velocity,
		"presentation_snapshot_serial": actor.presentation_snapshot_serial,
	}

func animate(actors: Array, delta: float) -> void:
	for actor in actors:
		var before := gameplay(actor)
		if actor.champion_model != null:
			actor.champion_model.animate(delta, actor)
			actor.body_hitboxes.update()
		else:
			actor.update_hitboxes(delta)
		animation_preserved_gameplay = animation_preserved_gameplay and before == gameplay(actor)
	var a: PackedVector3Array = actors[0].body_hitboxes.points
	var b: PackedVector3Array = actors[1].body_hitboxes.points
	maximum_parity_error = maxf(maximum_parity_error, endpoint_change(a, b))

func endpoint_change(a: PackedVector3Array, b: PackedVector3Array, indices: Array = []) -> float:
	var maximum := 0.0
	for i in (range(a.size()) if indices.is_empty() else indices):
		maximum = maxf(maximum, a[i].distance_to(b[i]))
	return maximum

func endpoints(actors: Array) -> PackedVector3Array:
	return actors[0].body_hitboxes.points.duplicate()

func host_endpoints(actors: Array) -> PackedVector3Array:
	var points := endpoints(actors)
	var inverse: Transform3D = actors[0].champion_model.global_transform.affine_inverse()
	for i in points.size():
		points[i] = inverse * points[i]
	return points

func phase(actors: Array, name: String, elapsed: float, direction: Vector3) -> void:
	for actor in actors:
		actor.identity.null_vantage = {"phase": name, "elapsed": elapsed, "direction": direction, "target": 99, "power": 100.0} if not name.is_empty() else {}
		actor.presentation_grounded = name in ["", "recover"]
		actor.velocity = Vector3.UP * (16.0 - 24.0 * minf(elapsed, .5)) if name == "lift" else (direction * 25.0 if name == "dive" else Vector3.ZERO)
		actor.presentation_vertical_speed = actor.velocity.y
		actor.presentation_velocity = actor.velocity

func boundary(actors: Array, next: String, direction: Vector3, label: String) -> void:
	var previous := endpoints(actors)
	phase(actors, next, .001, direction)
	animate(actors, .001)
	var change := endpoint_change(previous, endpoints(actors))
	check(change < .02, "%s phase entry does not snap in 1 ms (%.6f m)" % [label, change])

func warmup(actors: Array, entry: String) -> void:
	for frame in 30:
		for actor in actors:
			actor.presentation_grounded = entry != "jump"
			actor.velocity = Vector3(0, 3.5, -4.0) if entry == "jump" else Vector3(0, 0, -6.5)
			actor.presentation_vertical_speed = actor.velocity.y
			actor.position += actor.velocity * STEP
		animate(actors, STEP)

func hands_ordered(points: PackedVector3Array) -> bool:
	# Shoulder axis is body-relative and remains valid when the actor faces any yaw.
	var axis := (points[10] - points[24]).normalized()
	var center := (points[10] + points[24]) * .5
	return (points[16] - points[30]).dot(axis) > .14 and (points[16] - center).dot(axis) > .04 and (points[30] - center).dot(axis) < -.04

func sequence(entry: String, direction: Vector3, yaw: float, label: String) -> void:
	var actors := pair(yaw)
	warmup(actors, entry)
	boundary(actors, "lift", direction, label + " " + entry + " to lift")
	var late_lift := PackedVector3Array()
	for frame in range(1, 31):
		phase(actors, "lift", frame * STEP, direction)
		animate(actors, STEP)
		if frame == 19:
			late_lift = endpoints(actors)
	var lift_end := endpoints(actors)
	check(endpoint_change(late_lift, lift_end, [4, 5, 6, 7, 8, 9]) > .005, label + " late lift has torso/head movement")
	check(endpoint_change(late_lift, lift_end, [14, 15, 16, 17, 28, 29, 30, 31]) > .01, label + " late lift has living arm movement")
	boundary(actors, "dive", direction, label + " lift to dive")
	var late_dive := PackedVector3Array()
	var ordered := true
	for frame in range(1, 25):
		phase(actors, "dive", frame * STEP, direction)
		animate(actors, STEP)
		ordered = ordered and hands_ordered(endpoints(actors))
		if frame == 15:
			late_dive = endpoints(actors)
	check(ordered, label + " hands remain separate and on their own shoulder side throughout the dive")
	check(endpoint_change(late_dive, endpoints(actors), [4, 5, 6, 7, 8, 9]) > .003, label + " settled dive still has torso/head movement")
	check(endpoint_change(late_dive, endpoints(actors), [14, 15, 16, 17, 28, 29, 30, 31]) > .003, label + " settled dive still has limb movement")
	boundary(actors, "recover", direction, label + " dive to recovery")
	for frame in range(1, 12):
		phase(actors, "recover", minf(frame * STEP, .18), direction)
		animate(actors, STEP)
	boundary(actors, "", direction, label + " recovery to idle")
	for frame in 30:
		animate(actors, STEP)
	check(actors[0].champion_model.null_art.special_phase.is_empty() and actors[0].champion_model.null_art.clip == "Ready", label + " completes back in the approved hybrid idle")
	for actor in actors:
		actor.free()

func snapshot_sequence() -> void:
	var actors := pair(.7)
	warmup(actors, "jump")
	for actor in actors:
		actor.presentation_snapshot_serial = 1
	for name in ["lift", "dive"]:
		var progressing := true
		var changing := true
		var between_packet_frames := 0
		for frame in (30 if name == "lift" else 36):
			if frame % 3 == 0:
				phase(actors, name, frame * STEP, Vector3(0, -1, -1).normalized())
				for actor in actors:
					actor.presentation_snapshot_serial += 1
			var before := endpoints(actors)
			var previous_clock: float = actors[0].champion_model.null_art.dive_clock.elapsed
			animate(actors, STEP)
			if frame > 15 and frame % 3 != 0:
				between_packet_frames += 1
				progressing = progressing and actors[0].champion_model.null_art.dive_clock.elapsed > previous_clock
				changing = changing and endpoint_change(before, endpoints(actors)) > .00001
		check(between_packet_frames > 0 and progressing, name + " visual clock advances at 60 Hz between 20 Hz snapshots")
		check(between_packet_frames > 0 and changing, name + " bones do not freeze between 20 Hz snapshots")
	for actor in actors:
		actor.free()

func interruption(reason: String) -> void:
	var actors := pair()
	warmup(actors, "run")
	for frame in 25:
		phase(actors, "dive", frame * STEP, Vector3(0, -1, -1).normalized())
		animate(actors, STEP)
	# Shared stun sway deliberately rolls the entire presentation host according
	# to wall-clock time. Check Vantage's bone blend separately from that effect.
	var before := host_endpoints(actors) if reason == "stun" else endpoints(actors)
	for actor in actors:
		if reason == "stun":
			actor.stunned = .5
		else:
			actor.identity.null_vantage = {}
	animate(actors, .001)
	check(actors[0].champion_model.null_art.special_phase.is_empty(), reason + " immediately exits the Vantage-specific pose state")
	var after := host_endpoints(actors) if reason == "stun" else endpoints(actors)
	var change := endpoint_change(before, after)
	check(change < .02, "%s interruption blends the displayed bone pose without snapping (%.6f m)" % [reason, change])
	for actor in actors:
		actor.stunned = 0.0
	phase(actors, "", 0, Vector3.FORWARD)
	for frame in 45:
		animate(actors, STEP)
	check(actors[0].champion_model.null_art.clip == "Ready", reason + " interruption recovers the approved hybrid idle animation")
	for actor in actors:
		actor.free()

func run() -> void:
	sequence("run", Vector3(0, -.8, -1).normalized(), 0, "Forward")
	sequence("jump", Vector3(0, -4, -1).normalized(), 0, "Steep")
	sequence("jump", Vector3(0, -.1, -1).normalized(), 0, "Shallow")
	sequence("run", Vector3(-1, -.6, .5).normalized(), 2.1, "Yaw-rotated")
	snapshot_sequence()
	interruption("stun")
	interruption("target cancellation")
	check(maximum_parity_error < .0005, "Visible and compact-server body endpoints agree within 0.5 mm for the full sequences (%.6f m)" % maximum_parity_error)
	check(animation_preserved_gameplay, "Animator never changes actor root transform, velocity, movement/collision data, or gameplay state")
	print("Null Vantage presentation checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
