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
	root.add_child(actor); actor.setup(1, 1, 0, "Fulcrum")
	var visual = actor.champion_model
	var art = visual.fulcrum_art
	check(art.skeleton.get_bone_count() == 83, "UAL anatomy plus costume/weapon controls imported")
	for bone in ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-head", "DEF-hand.L", "DEF-f_index.03.L", "DEF-thigh.R", "DEF-toe.R"]:
		check(art.skeleton.find_bone(bone) >= 0, "Preset anatomical bone: " + bone)
	for bone in ["mantle0", "mantle_tip0", "mantle1", "mantle_tip1", "mantle2", "mantle_tip2", "gravity.focus", "gravity.outer", "gravity.inner", "gravity.debris"]:
		check(art.skeleton.find_bone(bone) >= 0, "Class control retained: " + bone)
	var weapon = art.model.find_child("Fulcrum_GravityWeapon", true, false)
	var undersuit = art.model.find_child("Fulcrum_UAL_Undersuit", true, false)
	check(weapon is MeshInstance3D and weapon.skin != null, "Approved weapon is skinned")
	check(undersuit is MeshInstance3D and undersuit.skin != null, "Actual preset supplies the fitted undersuit")
	check(visual.torso.name == "Fulcrum_SkinnedModel" and visual.torso.skin != null, "Costume remains the body presentation mesh")
	var has_mask := false
	for material in art.materials:
		has_mask = has_mask or "SealedObsidianMask" in material.resource_name
		check(not "hair" in material.resource_name.to_lower() and not "eyewhite" in material.resource_name.to_lower(), "No exposed face or hair")
	check(has_mask, "Original sealed mask material remains")
	var singles := ["CastEnter", "CastRelease", "CastExit", "JumpStart", "JumpLand"]
	check(art.clip_names.size() == 33, "All selected/derived presets plus Mend hand-work are available")
	for name in art.clip_names:
		var animation: Animation = art.player.get_animation(art.clip_names[name])
		check(animation.length > .3 and animation.get_track_count() > 20, "Complete skeletal clip: " + name)
		check(animation.loop_mode == (Animation.LOOP_NONE if name in singles else Animation.LOOP_LINEAR), "Correct loop policy: " + name)
		art.player.play(art.clip_names[name]); art.player.seek(animation.length*.25, true)
		var finite := true
		for i in art.skeleton.get_bone_count(): finite = finite and art.skeleton.get_bone_pose(i).origin.is_finite()
		check(finite, "Finite imported pose: " + name)
	art.player.play(art.clip_names["Idle"]); art.clip = "Idle"
	visual.animate(.016, actor)
	var directions := [Vector3.FORWARD, Vector3(1,0,-1).normalized(), Vector3.RIGHT, Vector3(1,0,1).normalized(), Vector3.BACK, Vector3(-1,0,1).normalized(), Vector3.LEFT, Vector3(-1,0,-1).normalized()]
	var walks := ["Walk", "WalkForwardRight", "StrafeRight", "WalkBackwardRight", "WalkBackward", "WalkBackwardLeft", "StrafeLeft", "WalkForwardLeft"]
	var runs := ["Run", "RunForwardRight", "RunRight", "WalkBackwardRight", "WalkBackward", "WalkBackwardLeft", "RunLeft", "RunForwardLeft"]
	for running in [false, true]:
		for i in 8:
			actor.position += directions[i] * (4.0 if running else 1.2) / 60.0
			visual.animate(1.0/60.0, actor)
			check(art.clip == (runs[i] if running else walks[i]), "Eight-way motion reacts immediately: " + str(i))
	visual.animate(.016, actor)
	check(art.clip == "Idle", "Releasing movement selects idle immediately")
	for i in 8:
		actor.position += directions[i] * 6.5 / 60.0
		visual.animate(1.0/60.0,actor)
		check(art.clip == runs[i].replace("Run","Sprint"), "Full game speed selects directional sprint: " + str(i))
	# Backward intent is actor-local, including when the character has turned.
	actor.rotation.y = PI/2
	for direction_index in [3,4,5]:
		var original_velocity: Vector3 = actor.velocity
		for i in 60:
			actor.position += actor.basis * directions[direction_index] * 3.8 / 60.0
			visual.animate(1.0/60.0,actor)
		check(art.clip == walks[direction_index], "Turned character backpedals with the reversed walk in all three directions")
		check(absf(art.player.speed_scale-1.15)<.005, "Normal backpedaling plays the walking clip 15 percent faster")
		check(actor.velocity == original_velocity, "Backpedal animation never changes physical velocity")
	actor.rotation.y = 0
	visual.animate(.016,actor)
	actor.casting = 0; visual.animate(.016, actor)
	check(art.clip == "CastEnter", "Casting uses preset anticipation")
	for i in 45: visual.animate(1.0/60.0, actor)
	check(art.clip == "Cast", "Sustained cast uses the dedicated spell loop")
	actor.casting = -1; visual.animate(.016, actor)
	check(art.clip == "CastRelease", "Completed cast uses preset release")
	for i in 65: visual.animate(1.0/60.0, actor)
	check(art.clip == "Idle", "Cast recovery returns to idle")
	actor.casting = 0; actor.cast_left = 1.2; visual.animate(.016,actor)
	actor.casting = -1; actor.cast_left = 0; visual.animate(.016,actor)
	check(art.clip == "CastExit", "Interrupted cast exits without a release gesture")
	for i in 35: visual.animate(1.0/60.0,actor)
	actor.gcd = 1.0; visual.animate(.016, actor)
	check(art.clip == "CastRelease", "Instant cast GCD event also produces a release")
	actor.position += Vector3.LEFT/60.0; visual.animate(1.0/60.0, actor)
	check(art.clip == "StrafeLeft", "Movement is not held up by cosmetic recovery")
	art.transient_left = 0
	actor.velocity.y = 4; visual.animate(.016, actor)
	check(art.clip == "JumpStart", "Jump begins with source takeoff")
	for i in 16: visual.animate(1.0/60.0, actor)
	actor.velocity.y = 0; visual.animate(.016, actor)
	check(art.clip == "JumpLoop", "Apex remains airborne rather than landing at zero vertical speed")
	actor.velocity.y = -3; visual.animate(.016, actor)
	check(art.clip == "JumpLoop", "Descending uses airborne loop")
	# Remote bodies never move_and_slide; snapshots must drive takeoff/landing.
	var remote_state: Dictionary = actor.snapshot()
	actor.velocity = Vector3.ZERO
	remote_state.grounded = true; actor.receive(remote_state); visual.animate(.016,actor)
	check(art.clip == "JumpLand", "Remote grounded snapshot exits the airborne loop")
	for i in 12: visual.animate(1.0/60.0,actor)
	check(art.clip == "Idle", "Remote landing recovers to idle")
	remote_state.grounded = false; actor.receive(remote_state); visual.animate(.016,actor)
	check(art.clip == "JumpStart", "Remote snapshot starts a jump without local physics velocity")
	for i in 16: visual.animate(1.0/60.0,actor)
	check(art.clip == "JumpLoop", "Remote airborne snapshot holds the jump through its apex")
	remote_state.grounded = true; actor.receive(remote_state)
	actor.presentation_grounded = null
	actor.velocity = Vector3.ZERO; art.was_airborne = false; art.transient_left = 0
	visual.animate(.037, actor)
	actor.stunned = 1; visual.animate(.016, actor)
	var paused_at: float = art.player.current_animation_position
	visual.animate(.2, actor)
	check(is_equal_approx(paused_at, art.player.current_animation_position), "Stun freezes skeletal playback")
	actor.stunned = 0; visual.animate(.1, actor)
	check(not is_equal_approx(paused_at, art.player.current_animation_position), "Playback resumes")
	var before: Transform3D = actor.transform
	actor.hp = 0; visual.animate(.4, actor)
	check(visual.rotation.x < -1 and actor.transform == before, "Defeat affects presentation only")
	actor.hp = 100; visual.animate(.4, actor)
	check(is_zero_approx(visual.rotation.x), "Revive restores model")
	var capsule: CapsuleShape3D = actor.get_child(0).shape
	check(is_equal_approx(capsule.radius,.42) and is_equal_approx(capsule.height,1.8), "Gameplay capsule unchanged")
	var other = load("res://scripts/combatant.gd").new()
	root.add_child(other); other.setup(2,2,1,"Fulcrum")
	actor.flash = .2; visual.animate(.016,actor)
	check(art.materials[0].albedo_color == Color.WHITE, "Hit flash preserved")
	check(art.materials[0] != other.champion_model.fulcrum_art.materials[0], "Material state isolated per actor")
	actor.flash = 0; visual.animate(.016,actor)
	check(art.materials[0].albedo_color == art.base_colors[0], "Hit flash restores appearance")
	for node in visual.find_children("*", "Node", true, false): check(not node is CollisionObject3D, "No costume collision introduced")
	actor.queue_free(); other.queue_free(); await process_frame
	print("Fulcrum presentation: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
