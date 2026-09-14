extends RefCounted
## Owner-approved hybrid loops; animation-only selection shared by both presenters.
## Uses portable tracks, never the preview's mesh-assisted contact/transition solver.
const LIBRARY = preload("res://assets/animations/null_locomotion.res")
const LIBRARY_NAME := "null_locomotion"
const Motion = preload("res://scripts/network_animation_motion.gd")
const MovementTuning = preload("res://scripts/movement_tuning.gd")
const SUFFIXES := ["Forward", "ForwardRight", "Right", "BackwardRight", "Backward", "BackwardLeft", "Left", "ForwardLeft"]
const FAMILIES := ["Travel", "Measured", "Low"]
const MOVEMENT_THRESHOLD := .12
const MEASURED_SPEED_FRACTION := .75
static var remapped_libraries: Dictionary = {}
static var nominal_speeds: Dictionary = {}
var sector := 0

static func install(player: AnimationPlayer, skeleton: Skeleton3D) -> Dictionary:
	# Godot 4.5 can retain invalid active-animation data when a library is added
	# after initial playback. Capture before mutation; refresh the same pose/clock
	# afterward, before the inherited presenter reads current_animation_length.
	# current_animation is empty while paused; assigned_animation retains its clip.
	var active_name := String(player.assigned_animation)
	var active_time := player.current_animation_position if not active_name.is_empty() else 0.0
	var was_playing := player.is_playing()
	var path := String(player.get_node(player.root_node).get_path_to(skeleton))
	if not remapped_libraries.has(path):
		var library := AnimationLibrary.new()
		var expected: Array[String] = ["Ready", "LowIdle"]
		for family in FAMILIES:
			for suffix in SUFFIXES: expected.append(family + suffix)
		assert(LIBRARY.get_animation_list().size() == expected.size(), "Null movement requires exactly 26 approved clips")
		for name in expected:
			assert(LIBRARY.has_animation(name), "Missing approved Null movement: " + name)
			var source: Animation = LIBRARY.get_animation(name)
			var nominal := float(source.get_meta("nominal_speed_m_s", -1.0))
			assert(nominal == 0.0 if name in ["Ready", "LowIdle"] else nominal > 0.0, "Missing Null movement cadence metadata")
			nominal_speeds[name] = nominal
			# Duplicate only once per distinct rig path, not once per combatant.
			# Animation key arrays remain copy-on-write; only track paths change.
			var animation: Animation = source.duplicate(false)
			for track in animation.get_track_count():
				var source_path := animation.track_get_path(track)
				assert(source_path.get_subname_count() == 1, "Null movement expects bone-only tracks")
				var bone := String(source_path.get_subname(0))
				assert(skeleton.find_bone(bone) >= 0, "Null movement requires source bone " + bone)
				animation.track_set_path(track, NodePath(path + ":" + bone))
			animation.loop_mode = Animation.LOOP_LINEAR
			var add_result := library.add_animation(name, animation)
			assert(add_result == OK)
		remapped_libraries[path] = library
	if not player.has_animation_library(LIBRARY_NAME):
		player.stop()
		player.clear_caches()
		var install_result := player.add_animation_library(LIBRARY_NAME, remapped_libraries[path])
		assert(install_result == OK)
		if not active_name.is_empty():
			player.play(active_name, 0.0)
			player.seek(active_time, true)
			player.advance(0.0)
			if not was_playing: player.pause()
	var names := {}
	for name in LIBRARY.get_animation_list(): names[name] = LIBRARY_NAME + "/" + name
	return names

func observe_motion(actor, previous_position: Vector3, initialized: bool, delta: float) -> void:
	# Match the inherited presenter's displacement policy; position correction
	# offsets must not rotate a remote actor into a different directional gait.
	var displacement := Vector3.ZERO
	if initialized and delta > 0.0:
		displacement = actor.global_position - previous_position
		displacement.y = 0.0
		if displacement.length() > 1.0 and actor.charge.is_empty(): displacement = Vector3.ZERO
	displacement = Motion.displacement(actor, displacement, delta)
	if delta <= 0.0 or displacement.length() / delta <= MOVEMENT_THRESHOLD: return
	var local_motion: Vector3 = actor.global_basis.inverse() * displacement
	sector = posmod(roundi(atan2(local_motion.x, -local_motion.z) / (PI / 4.0)), 8)

func choose(speed: float, walking: bool, severely_slowed: bool, stealthed: bool) -> String:
	if speed <= MOVEMENT_THRESHOLD: return "LowIdle" if stealthed else "Ready"
	var normal_speed := MovementTuning.BACKWARD_SPEED if sector in [3, 4, 5] else MovementTuning.FORWARD_SPEED
	var measured := walking or severely_slowed or speed < normal_speed * MEASURED_SPEED_FRACTION
	var family := "Low" if stealthed else ("Measured" if measured else "Travel")
	return family + SUFFIXES[sector]

static func playback_rate(name: String, speed: float, default_rate: float) -> float:
	if not nominal_speeds.has(name): return default_rate
	var nominal: float = nominal_speeds[name]
	if nominal <= 0.0: return 1.0
	# Slower travel already reduces the other loops by 10%. Compensate only
	# straight forward so its prior cadence is retained, including walk/stealth.
	var forward := name in ["TravelForward", "MeasuredForward", "LowForward"]
	var compensation := 1.0 / MovementTuning.SPEED_SCALE if forward else 1.0
	# Additional owner-requested cadence reduction for both forward diagonals.
	if name.ends_with("ForwardLeft") or name.ends_with("ForwardRight"): compensation *= .85 * 1.05
	if name in ["LowBackwardLeft", "LowBackward", "LowBackwardRight"]: compensation *= 1.2
	return maxf(speed, 0.0) / nominal * compensation

static func is_locomotion(name: String) -> bool:
	for family in FAMILIES:
		if name.begins_with(family) and name.trim_prefix(family) in SUFFIXES: return true
	return false

static func is_low(name: String) -> bool:
	return name == "LowIdle" or (name.begins_with("Low") and name.trim_prefix("Low") in SUFFIXES)
