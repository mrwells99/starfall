extends RefCounted
## Animation inputs independent of network correction offsets. No physics writes.
const GRAVITY := 20.0
const MAX_VERTICAL_PROJECTION := 0.25
var in_flight := false
var vertical_speed := 0.0
var last_snapshot := -1
var revision := -1
var sample_age := 0.0

static func displacement(actor, observed: Vector3, delta: float) -> Vector3:
	if actor.presentation_snapshot_serial == 0 or delta <= 0:
		return observed
	# Prediction updates velocity through real local physics; remote actors use
	# the received velocity. Neither includes lerp/rewind position corrections.
	var movement = actor.velocity if actor.presentation_grounded == null else actor.presentation_velocity
	if movement == null: return observed
	return Vector3(movement.x, 0, movement.z) * delta

func vertical(actor, delta: float) -> float:
	var reported: float = actor.velocity.y if actor.presentation_grounded == null else actor.presentation_vertical_speed
	if actor.presentation_snapshot_serial == 0 or actor.presentation_grounded == null or bool(actor.presentation_grounded):
		in_flight = false
		return reported
	if not in_flight or revision != actor.motion_revision:
		vertical_speed = reported
		sample_age = 0.0
		in_flight = true
		revision = actor.motion_revision
	else:
		var step := minf(maxf(delta, 0.0), maxf(0.0, MAX_VERTICAL_PROJECTION - sample_age))
		vertical_speed -= GRAVITY * step
		sample_age += maxf(delta, 0.0)
		if last_snapshot != actor.presentation_snapshot_serial:
			if sample_age > MAX_VERTICAL_PROJECTION:
				# After an outage prefer the actual flight state to an old estimate.
				vertical_speed = reported
			else:
				var correction := GRAVITY * maxf(delta, 0.0) * .2
				vertical_speed += clampf(reported - vertical_speed, -correction, correction)
			sample_age = 0.0
	last_snapshot = actor.presentation_snapshot_serial
	return vertical_speed
