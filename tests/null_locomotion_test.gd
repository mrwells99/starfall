extends SceneTree
## Actual visible/compact playback of the approved Null locomotion library.
## Optional --qa-output=<absolute path> retains exact endpoint samples for an
## independently staged supported-engine comparison; no cache paths are required.
const Fighter = preload("res://scripts/combatant.gd")
const STEP := 1.0 / 60.0
const SUFFIX := ["Forward", "ForwardRight", "Right", "BackwardRight", "Backward", "BackwardLeft", "Left", "ForwardLeft"]
const MOTION := "res://assets/animations/null_locomotion.res"
const VISUAL := "res://assets/characters/null.glb"
var checks := 0
var failures := 0
var messages: Array = []
var actors: Array = []
var arts: Array = []
var rests: Array = []
var anchors: Array = []
var samples: Array = []
var covered: Dictionary = {}
var max_endpoint_error := 0.0
var max_blade_position_error := 0.0
var max_blade_angle_error := 0.0
var max_finger_angle_error := 0.0
var largest_boundary_delta := 0.0
var gameplay_unchanged := true
var frame_number := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if messages.size() < 48: messages.append(message)

func qangle(a: Quaternion, b: Quaternion) -> float:
	var q := (a * b.inverse()).normalized()
	return 2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w))

func gameplay(actor) -> Dictionary:
	var shape: CapsuleShape3D = actor.get_child(0).shape
	return {"transform": actor.transform, "velocity": actor.velocity, "identity": actor.identity.duplicate(true), "charge": actor.charge.duplicate(true), "cooldowns": actor.cooldowns.duplicate(), "hp": actor.hp, "gcd": actor.gcd, "casting": actor.casting, "cast_left": actor.cast_left, "cast_target": actor.cast_target, "jump_queued": actor.jump_queued, "jump_buffer": actor.jump_buffer, "walking": actor.walking, "move_input": actor.move_input, "motion_revision": actor.motion_revision, "stunned": actor.stunned, "locked": actor.locked, "capsule_radius": shape.radius, "capsule_height": shape.height, "collision_layer": actor.collision_layer, "collision_mask": actor.collision_mask, "grounded": actor.presentation_grounded, "vertical": actor.presentation_vertical_speed, "presentation_velocity": actor.presentation_velocity, "snapshot_serial": actor.presentation_snapshot_serial}

func capture_rest(art) -> Array:
	var rows: Array = []
	for b in art.skeleton.get_bone_count():
		rows.append([art.skeleton.get_bone_name(b), art.skeleton.get_bone_parent(b), art.skeleton.get_bone_rest(b)])
	return rows

func blade_offset(art, side: String) -> Transform3D:
	var hand: int = art.skeleton.find_bone("DEF-hand." + side)
	var blade: int = art.skeleton.find_bone("null.blade." + side)
	return art.skeleton.get_bone_global_pose(hand).affine_inverse() * art.skeleton.get_bone_global_pose(blade)

func setup_pair() -> void:
	# Exercise the dedicated construction path before anything loads visual GLBs.
	var server = Fighter.new()
	root.add_child(server)
	server.setup(2, 2, 1, "Null", false)
	server.setup_hitboxes()
	check(server.champion_model == null, "Compact actor never constructs a champion model")
	check(server.hitbox_pose.find_children("*", "MeshInstance3D", true, false).is_empty(), "Compact pose has no render meshes")
	for title in ["ember", "luminary", "fulcrum", "vanguard", "outlaw", "null"]:
		check(not ResourceLoader.has_cached("res://assets/characters/" + title + ".glb"), "Dedicated Null construction loads no visual GLB: " + title)
	var server_art = server.hitbox_pose.art
	check(server_art.pose_only and server_art.materials.is_empty(), "Compact presenter stays pose-only without material allocation")
	check(server_art.haste_wind == null and server_art.vantage_wind == null and server_art.regen_effect == null and server_art.shadow_casters.is_empty(), "No visual effect/shadow allocation on compact rig")
	var visible = Fighter.new()
	root.add_child(visible)
	visible.setup(1, 1, 0, "Null")
	visible.setup_hitboxes()
	actors = [visible, server]
	arts = [visible.champion_model.null_art, server_art]
	for art in arts:
		check(art.transition_style == 2, "Owner-selected softer B transitions are live")
		check(art.get_script().resource_path == "res://scripts/null_living_art.gd", "Actual visible/server actor uses approved refined B presenter")
	for i in 2:
		actors[i].position = Vector3(1.5, 2.0, -3.0)
		actors[i].rotation.y = .71
		actors[i].presentation_grounded = true
		rests.append(capture_rest(arts[i]))
		var offset: Dictionary = {}
		for side in ["L", "R"]:
			var blade: int = arts[i].skeleton.find_bone("null.blade." + side)
			var hand: int = arts[i].skeleton.find_bone("DEF-hand." + side)
			check(blade >= 0 and hand >= 0 and arts[i].skeleton.get_bone_parent(blade) == hand, "Both original blade anchors remain hand-parented")
			offset[side] = blade_offset(arts[i], side)
		anchors.append(offset)
		check(arts[i].equipment.grip.size() == 30, "All thirty existing finger grip bones are captured")
		check(actors[i].body_hitboxes.radii.size() == 19 and actors[i].body_hitboxes.points.size() == 38, "Original nineteen body volumes and thirty-eight endpoints")
		check(arts[i].clip_names.has("Ready") and arts[i].clip_names.has("LowIdle"), "Approved idle clips installed in actual presenter")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hitboxes/manifest.json"))
	check(FileAccess.get_sha256(VISUAL) == manifest.classes.Null.source_sha256, "Source model is still the compact rig's recorded source")
	check(FileAccess.get_sha256("res://assets/hitboxes/null_rig.scn") == manifest.classes.Null.rig_sha256, "Compact rig file matches its manifest")

func set_motion(sector: int, speed: float, low: bool = false, walking: bool = false, severe: bool = false, airborne: bool = false, vertical: float = 0.0, snapshot: bool = false, delta: float = STEP) -> void:
	for actor in actors:
		var local_direction := Vector3(sin(sector * PI / 4.0), 0, -cos(sector * PI / 4.0))
		var motion: Vector3 = actor.global_basis * local_direction * speed
		motion.y = vertical
		actor.position += motion * delta
		actor.velocity = motion
		actor.presentation_velocity = motion
		actor.presentation_vertical_speed = vertical
		actor.presentation_grounded = not airborne
		actor.walking = walking
		actor.identity.stealth = low
		actor.identity.severe_slow = 6.0 if severe else 0.0
		actor.identity.null_vantage = {}
		actor.casting = -1
		actor.cast_left = 0.0
		actor.stunned = 0.0
		actor.hp = actor.MAX_HEALTH
		if snapshot:
			if frame_number % 3 == 0: actor.presentation_snapshot_serial += 1
		else:
			actor.presentation_snapshot_serial = 0

func animate(label: String, delta: float = STEP) -> void:
	for i in 2:
		var actor = actors[i]
		var before := gameplay(actor)
		if i == 0:
			actor.champion_model.animate(delta, actor)
			actor.body_hitboxes.update()
		else:
			actor.update_hitboxes(delta)
		gameplay_unchanged = gameplay_unchanged and before == gameplay(actor)
		var art = arts[i]
		art.skeleton.force_update_all_bone_transforms()
		for b in art.skeleton.get_bone_count():
			check(art.skeleton.get_bone_pose(b).is_finite() and art.skeleton.get_bone_global_pose(b).is_finite(), label + " finite final bone pose")
		for b in art.equipment.grip:
			var error := qangle(art.skeleton.get_bone_pose_rotation(b), art.equipment.grip[b])
			max_finger_angle_error = maxf(max_finger_angle_error, error)
			check(error < .00001, label + " preserves captured finger grip")
		for side in ["L", "R"]:
			var offset := blade_offset(art, side)
			var initial: Transform3D = anchors[i][side]
			var position_error := offset.origin.distance_to(initial.origin)
			var angle_error := qangle(offset.basis.get_rotation_quaternion(), initial.basis.get_rotation_quaternion())
			max_blade_position_error = maxf(max_blade_position_error, position_error)
			max_blade_angle_error = maxf(max_blade_angle_error, angle_error)
			check(position_error < .00001 and angle_error < .00001, label + " preserves blade-to-hand attachment")
	var first: PackedVector3Array = actors[0].body_hitboxes.points
	var second: PackedVector3Array = actors[1].body_hitboxes.points
	check(first.size() == 38 and second.size() == 38, label + " complete body endpoint set")
	var row: Array = []
	for b in first.size():
		check(first[b].is_finite() and second[b].is_finite(), label + " finite capsule endpoint")
		var error := first[b].distance_to(second[b])
		max_endpoint_error = maxf(max_endpoint_error, error)
		check(error < .0005, label + " visible/compact endpoint mismatch")
		var relative: Vector3 = second[b] - actors[1].global_position
		row.append([relative.x, relative.y, relative.z])
	check(arts[0].clip == arts[1].clip, label + " identical visible/server clip selection")
	covered[arts[0].clip] = true
	samples.append({"frame": frame_number, "label": label, "clip": arts[1].clip, "endpoints": row})
	frame_number += 1

func settle(label: String, sector: int, speed: float, expected: String, low: bool = false, walking: bool = false, severe: bool = false, frames: int = 48, snapshot: bool = false) -> void:
	var first_foot := Vector3.ZERO
	var foot_motion := 0.0
	for frame in frames:
		set_motion(sector, speed, low, walking, severe, false, 0, snapshot)
		animate(label)
		var foot: Vector3 = arts[1].skeleton.get_bone_global_pose(arts[1].skeleton.find_bone("DEF-foot.L")).origin
		if frame == 12: first_foot = foot
		if frame > 12: foot_motion = maxf(foot_motion, first_foot.distance_to(foot))
	check(arts[0].clip == expected and arts[1].clip == expected, label + " selects " + expected + ", got " + arts[0].clip)
	check(arts[1].player.current_animation == arts[1].clip_names[expected], label + " actually plays selected installed animation")
	if speed > .12: check(foot_motion > .02, label + " actual limb movement, not just present library names")
	var animation: Animation = arts[1].player.get_animation(arts[1].clip_names[expected])
	check(animation.has_meta("nominal_speed_m_s") or expected in ["TravelForward", "LowForward"], label + " portable metadata or restored original forward motion")
	var nominal := float(animation.get_meta("nominal_speed_m_s", 0.0))
	var expected_rate := speed / nominal if nominal > 0.0 else 1.0
	if nominal > 0.0 and sector == 0: expected_rate /= .945
	if nominal > 0.0 and sector in [1, 7]: expected_rate *= .85 * 1.05
	if nominal > 0.0 and expected in ["LowBackwardLeft", "LowBackward", "LowBackwardRight"]: expected_rate *= 1.2
	if expected == "TravelForward":
		expected_rate = clampf(speed / 4.4, .55, 2.5) * .9
		check(arts[1].clip_names[expected] == arts[1].clip_names["Sprint"], label + " uses original forward run")
	if expected == "LowForward":
		expected_rate = clampf(speed / 2.8, .55, 2.5) * 1.6848
		check(animation.get_meta("approved_source_clip", "") == "StealthWalk" and is_equal_approx(float(animation.get_meta("stealth_height_raise_m", 0.0)), .2), label + " uses height-adjusted original forward stealth walk")
		for art in arts:
			for bone in ["root", "DEF-spine.001"]:
				var index: int = art.skeleton.find_bone(bone)
				check(art.skeleton.get_bone_pose(index).is_equal_approx(art.skeleton.get_bone_rest(index)), label + " clears previous-direction twist in " + bone)
	check(absf(arts[1].player.speed_scale - expected_rate) < .005, label + " settled cadence preserves forward and slows other directions exactly once")

func boundary(label: String, sector: int, speed: float, low: bool = false) -> void:
	var before: PackedVector3Array = actors[0].body_hitboxes.points.duplicate()
	set_motion(sector, speed, low, false, false, false, 0, false, .001)
	animate(label, .001)
	var distance := 0.0
	for b in before.size(): distance = maxf(distance, before[b].distance_to(actors[0].body_hitboxes.points[b]))
	largest_boundary_delta = maxf(largest_boundary_delta, distance)
	check(distance < .02, label + " retains displayed-pose entry at one millisecond")

func movement_matrix() -> void:
	settle("Ready", 0, 0, "Ready")
	for family in ["Travel", "Measured", "Low"]:
		for sector in 8:
			var speed := 3.591 if sector in [3, 4, 5] else 6.1425
			if family == "Measured": speed *= .5
			settle(family + SUFFIX[sector], sector, speed, family + SUFFIX[sector], family == "Low", family == "Measured")
	settle("LowIdle", 0, 0, "LowIdle", true)
	for incoming in [6, 1, 2]:
		settle("stealth-entry-source-" + SUFFIX[incoming], incoming, 4.914, "Low" + SUFFIX[incoming], true)
		settle("stealth-forward-clears-" + SUFFIX[incoming], 0, 4.914, "LowForward", true)
	check(is_equal_approx(arts[0].transition_duration("Ready", "LowIdle"), .38), "Stealth entry timing retained")
	check(is_equal_approx(arts[0].transition_duration("LowIdle", "Ready"), .52), "Stealth exit timing retained")
	for sector in 8:
		var speed := 3.591 if sector in [3, 4, 5] else 6.1425
		settle("severe-" + SUFFIX[sector], sector, speed * .4, "Measured" + SUFFIX[sector], false, false, true)
		settle("haste-" + SUFFIX[sector], sector, speed * 1.5, "Travel" + SUFFIX[sector])
	settle("snapshot-input", 6, 6.1425, "TravelLeft", false, false, false, 60, true)
	for frame in 48:
		set_motion(6, 6.1425, false, false, false, false, 0.0, true)
		# Cosmetic correction opposes/redirects observed displacement, but the
		# reported motion remains leftward in the actor's rotated local frame.
		for actor in actors: actor.position += actor.global_basis * Vector3(0, 0, .25 if frame % 2 == 0 else -.25)
		animate("snapshot-position-correction")
		check(arts[0].clip == "TravelLeft", "Cosmetic network corrections do not select the wrong travel direction")
	settle("before-cuts", 0, 6.1425, "TravelForward")
	for sector in [4, 2, 6, 1, 5, 0]:
		boundary("interrupted-cut-" + str(sector), sector, 3.591 if sector in [3, 4, 5] else 6.1425)
	boundary("moving-low-entry", 0, 6.1425, true)
	boundary("interrupted-low-exit", 0, 6.1425, false)
	boundary("abrupt-stop", 0, 0)
	settle("after-cuts", 0, 0, "Ready")

func special_reentry() -> void:
	settle("jump-entry", 0, 6.1425, "TravelForward")
	for frame in 36:
		set_motion(0, 6.1425, false, false, false, true, 7.0 - 20.0 * frame * STEP)
		animate("jump")
		check(arts[0].clip in ["JumpStart", "JumpLoop"], "Jump clips retain precedence over locomotion")
	settle("moving-land-reentry", 0, 6.1425, "TravelForward")
	for action in ["stab", "backstab"]:
		for frame in 50:
			set_motion(2, 6.1425)
			if frame == 0:
				for actor in actors:
					actor.identity.null_action = action
					actor.identity.null_action_serial += 1
			animate(action + "-moving")
			if frame == 0: check(arts[0].strike_left > 0 and arts[1].strike_left > 0, action + " layer actually starts")
		check(arts[0].clip == "TravelRight" and arts[0].strike_left == 0, action + " finishes into approved movement")
	for phase_name in ["lift", "dive", "recover"]:
		for frame in 24:
			set_motion(0, 6.1425, false, false, false, phase_name != "recover", 8.0 if phase_name == "lift" else (-12.0 if phase_name == "dive" else 0.0))
			for actor in actors: actor.identity.null_vantage = {"phase": phase_name, "elapsed": frame * STEP, "direction": Vector3(0, -1, -1).normalized()}
			animate("vantage-" + phase_name)
			check(arts[0].clip == {"lift": "JumpStart", "dive": "JumpLoop", "recover": "JumpLand"}[phase_name], "Vantage phase retains its special base clip")
	settle("vantage-reentry", 5, 3.591, "TravelBackwardLeft")
	check(arts[0].special_phase.is_empty(), "Vantage state releases normally")
	for frame in 20:
		set_motion(1, 6.1425)
		for actor in actors:
			actor.casting = 0
			actor.cast_left = 1.0 - frame * STEP
		animate("ordinary-cast-overlay")
		check(arts[0].clip == "TravelForwardRight", "Ordinary Null cast presentation retains approved moving base")
	settle("cast-reentry", 0, 0, "Ready")
	settle("stealth-after-abilities", 4, 3.591, "LowBackward", true)
	settle("final-ready", 0, 0, "Ready")

func run() -> void:
	var library: AnimationLibrary = load(MOTION)
	if library == null:
		check(false, "Portable runtime locomotion library exists")
		finish(); return
	check(library.get_animation_list().size() == 26, "Only the twenty-six approved hybrid clips are promoted")
	for dependency in ResourceLoader.get_dependencies(MOTION):
		check(not ("local_resources" in dependency or "art_source" in dependency or ".glb" in dependency), "Runtime library has no ignored/source/model dependency")
	for source in ["res://scripts/null_locomotion.gd", "res://scripts/null_art.gd"]:
		var code := FileAccess.get_file_as_string(source)
		check(not ("res://local_resources/" in code or "res://art_source/" in code), "Runtime presenter has no ignored research dependency")
		var side_effect_assert := RegEx.new()
		side_effect_assert.compile("assert\\s*\\([^\\n]*\\.add_animation(?:_library)?\\s*\\(")
		check(side_effect_assert.search(code) == null, "Required animation installation is not hidden inside release-stripped assertions")
	setup_pair()
	movement_matrix()
	special_reentry()
	for name_ in library.get_animation_list(): check(covered.has(String(name_)), "Actual presenter exercised approved clip " + String(name_))
	for i in 2:
		check(capture_rest(arts[i]) == rests[i], "All current core and equipment rest transforms/hierarchy exactly unchanged")
	check(gameplay_unchanged, "Animator never changes physics, collision, health, cooldowns, identity or controller inputs")
	check(max_endpoint_error < .0005, "Visible and compact-server endpoints agree within 0.5 mm")
	finish()

func finish() -> void:
	var output_file: FileAccess
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--qa-output="):
			output_file = FileAccess.open(String(arg).trim_prefix("--qa-output="), FileAccess.WRITE)
			check(output_file != null, "Can save requested QA output")
	var report := {"engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "errors": messages, "library_sha256": FileAccess.get_sha256(MOTION), "presenter_sha256": FileAccess.get_sha256("res://scripts/null_art.gd"), "helper_sha256": FileAccess.get_sha256("res://scripts/null_locomotion.gd"), "max_visible_compact_endpoint_error_m": max_endpoint_error, "max_blade_position_error_m": max_blade_position_error, "max_blade_rotation_error_rad": max_blade_angle_error, "max_finger_rotation_error_rad": max_finger_angle_error, "max_one_millisecond_boundary_endpoint_delta_m": largest_boundary_delta, "gameplay_unchanged": gameplay_unchanged, "covered_clips": covered.keys(), "samples": samples, "limits": "Local actual-rig numeric playback; not a production network latency, rendered skin clearance, or human playtest claim."}
	if output_file: output_file.store_string(JSON.stringify(report) + "\n")
	for actor in actors: actor.free()
	for message in messages: push_error(message)
	print("Null locomotion maximum endpoint difference: ", max_endpoint_error, " meters; samples: ", samples.size())
	print("Null locomotion checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
