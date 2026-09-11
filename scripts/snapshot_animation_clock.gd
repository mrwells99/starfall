extends RefCounted
## Local visual time between replicated samples; never writes gameplay state.
var elapsed := 0.0
var playing := false
var last_snapshot := -1
var revision := -1

func reset() -> void:
	playing = false
	elapsed = 0.0
	last_snapshot = -1
	revision = -1

func advance(reported: float, delta: float, snapshot_serial: int, motion_revision: int, duration: float) -> float:
	if not playing or motion_revision != revision or snapshot_serial == 0:
		# Authority/offline already advances the gameplay timer every physics tick.
		# A client joins the effect at its received phase, including late visibility.
		elapsed = clampf(reported, 0.0, duration)
		playing = true
		revision = motion_revision
	else:
		var previous := elapsed
		elapsed += maxf(delta, 0.0)
		if snapshot_serial != last_snapshot:
			# Gently converge on fresh reports; packet jitter must not scrub the
			# pose backwards or skip directly to a later body rotation.
			var correction := maxf(delta, 0.0) * 0.2
			elapsed += clampf(reported - elapsed, -correction, correction)
		elapsed = clampf(elapsed, previous, duration)
	last_snapshot = snapshot_serial
	return elapsed
