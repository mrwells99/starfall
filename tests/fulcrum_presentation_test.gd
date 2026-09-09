extends SceneTree

var failures := 0
var checks := 0
const CLIPS = ["Idle", "Walk", "Run", "WalkBackward", "StrafeLeft", "StrafeRight", "Cast"]
const MANTLE_BONES = ["mantle0", "mantle1", "mantle2", "mantle_tip0", "mantle_tip1", "mantle_tip2"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func move_actor(actor, visual, direction: Vector3, speed: float, frames: int) -> void:
	for i in frames:
		actor.position += direction * speed / 60.0
		visual.animate(1.0 / 60.0, actor)

func check_immediate_transition(art, reference_art, expected: String, message: String) -> void:
	check(art.clip == expected and art.player.current_animation == art.clip_names[expected], message + " selects the clip in one frame")
	# Independently sample the imported destination clip to detect a lingering blend.
	reference_art.player.stop()
	reference_art.player.play(reference_art.clip_names[expected], 0.0)
	reference_art.player.seek(art.player.current_animation_position, true)
	var pose_matches := true
	for bone_name in ["pelvis", "thigh.L", "thigh.R", "chest"]:
		var actual: Transform3D = art.skeleton.get_bone_pose(art.skeleton.find_bone(bone_name))
		var expected_pose: Transform3D = reference_art.skeleton.get_bone_pose(reference_art.skeleton.find_bone(bone_name))
		pose_matches = pose_matches and actual.origin.distance_to(expected_pose.origin) < 0.0001
		pose_matches = pose_matches and actual.basis.get_rotation_quaternion().angle_to(expected_pose.basis.get_rotation_quaternion()) < 0.001
	check(pose_matches, message + " applies the destination pose immediately")

func run() -> void:
	var actor = load("res://scripts/combatant.gd").new()
	root.add_child(actor)
	actor.setup(1, 1, 0, "Fulcrum")
	var visual = actor.champion_model
	var art = visual.fulcrum_art
	check(art != null, "Fulcrum uses the authored presentation")
	if art == null:
		quit(1)
		return
	check(art.skeleton.get_bone_count() == 62, "Full Fulcrum skeleton imported")
	var weapon = art.model.find_child("Fulcrum_GravityWeapon", true, false)
	check(weapon is MeshInstance3D and weapon.skin != null, "Gravity weapon is an imported skinned mesh")
	for bone_name in ["gravity.focus", "gravity.outer", "gravity.inner", "gravity.debris"]:
		check(art.skeleton.find_bone(bone_name) >= 0, "Weapon control imported: " + bone_name)
	for bone_name in MANTLE_BONES:
		check(art.skeleton.find_bone(bone_name) >= 0, "Mantle control imported: " + bone_name)
	for i in art.skeleton.get_bone_count():
		check(not "hair" in art.skeleton.get_bone_name(i).to_lower(), "No hair control remains")
	check(visual.torso != null and visual.torso.skin != null, "The model is skinned")
	var has_mask := false
	for surface in visual.torso.mesh.get_surface_count():
		var material: Material = visual.torso.mesh.surface_get_material(surface)
		var material_name := material.resource_name
		has_mask = has_mask or "Fulcrum_SealedObsidianMask" in material_name
		for forbidden in ["hair", "skin", "iris", "lip", "eyewhite", "lash"]:
			check(not forbidden in material_name.to_lower(), "No exposed facial material: " + material_name)
	check(has_mask, "Sealed obsidian mask is present")
	print("Imported clips: ", art.player.get_animation_list())
	for clip in CLIPS:
		check(art.clip_names.has(clip), "Clip imported: " + clip)
		if not art.clip_names.has(clip):
			continue
		var anim: Animation = art.player.get_animation(art.clip_names[clip])
		check(anim.length > 0.5 and anim.get_track_count() > 20, "Clip has skeletal motion: " + clip)
		check(anim.loop_mode == Animation.LOOP_LINEAR, "Clip loops: " + clip)
		art.player.play(art.clip_names[clip])
		art.player.seek(0, true)
		var poses: Array[Transform3D] = []
		for i in art.skeleton.get_bone_count():
			poses.append(art.skeleton.get_bone_pose(i))
		art.player.seek(anim.length - 0.0001, true)
		for i in art.skeleton.get_bone_count():
			var end_pose: Transform3D = art.skeleton.get_bone_pose(i)
			check(poses[i].origin.distance_to(end_pose.origin) < 0.003, "Loop translation closes: " + clip)
			check(poses[i].basis.get_rotation_quaternion().angle_to(end_pose.basis.get_rotation_quaternion()) < 0.012, "Loop rotation closes: " + clip)
	# Inspect actual imported secondary deformation, rather than only bone names.
	var walk: Animation = art.player.get_animation(art.clip_names["Walk"])
	art.player.play(art.clip_names["Walk"])
	for bone_name in ["gravity.outer", "gravity.inner", "gravity.debris"]:
		art.player.seek(0, true)
		var bone: int = art.skeleton.find_bone(bone_name)
		var start_rotation = art.skeleton.get_bone_pose_rotation(bone)
		art.player.seek(walk.length * 0.25, true)
		check(start_rotation.angle_to(art.skeleton.get_bone_pose_rotation(bone)) > 0.5, "Weapon orbit animates: " + bone_name)
	art.player.play(art.clip_names["Walk"])
	art.player.seek(0, true)
	for bone_name in MANTLE_BONES:
		var bone: int = art.skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		art.player.seek(0, true)
		var start_pose: Transform3D = art.skeleton.get_bone_pose(bone)
		var max_angle := 0.0
		for sample in range(1, 16):
			art.player.seek(walk.length * sample / 16.0, true)
			var pose: Transform3D = art.skeleton.get_bone_pose(bone)
			max_angle = maxf(max_angle, start_pose.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion()))
		check(max_angle > 0.002, "Mantle moves through Walk: " + bone_name)
	visual.animate(1.0 / 60.0, actor)
	move_actor(actor, visual, Vector3.FORWARD, 1.5, 25)
	check(art.clip == "Walk", "Forward movement plays Walk")
	move_actor(actor, visual, Vector3.FORWARD, 4.0, 35)
	check(art.clip == "Run", "Faster forward movement plays Run")
	move_actor(actor, visual, Vector3.LEFT, 1.5, 35)
	check(art.clip == "StrafeLeft", "Left movement plays StrafeLeft")
	move_actor(actor, visual, Vector3.RIGHT, 1.5, 35)
	check(art.clip == "StrafeRight", "Right movement plays StrafeRight")
	move_actor(actor, visual, Vector3.BACK, 1.5, 35)
	check(art.clip == "WalkBackward", "Backward movement plays WalkBackward")
	actor.casting = 0
	visual.animate(0.1, actor)
	check(art.clip == "Cast", "Casting transitions to authored Cast")
	actor.casting = -1
	for i in 90:
		visual.animate(1.0 / 60.0, actor)
	check(art.clip == "Idle", "Stationary actor reaches Idle")
	# Movement onset, release and direction changes must match current Ember response.
	var reference_actor = load("res://scripts/combatant.gd").new()
	root.add_child(reference_actor)
	reference_actor.setup(2, 1, 0, "Fulcrum")
	var reference_art = reference_actor.champion_model.fulcrum_art
	move_actor(actor, visual, Vector3.FORWARD, 0.4, 1)
	check_immediate_transition(art, reference_art, "Walk", "Starting a slow walk")
	visual.animate(1.0 / 60.0, actor)
	check_immediate_transition(art, reference_art, "Idle", "Releasing walk movement")
	move_actor(actor, visual, Vector3.FORWARD, 4.0, 1)
	check_immediate_transition(art, reference_art, "Run", "Starting a run")
	move_actor(actor, visual, Vector3.LEFT, 0.9, 1)
	check_immediate_transition(art, reference_art, "StrafeLeft", "Changing from run to left")
	move_actor(actor, visual, Vector3.RIGHT, 0.9, 1)
	check_immediate_transition(art, reference_art, "StrafeRight", "Reversing strafe direction")
	move_actor(actor, visual, Vector3.BACK, 0.9, 1)
	check_immediate_transition(art, reference_art, "WalkBackward", "Changing to backward movement")
	visual.animate(1.0 / 60.0, actor)
	check_immediate_transition(art, reference_art, "Idle", "Releasing backward movement")
	reference_actor.queue_free()
	actor.stunned = 1.0
	visual.animate(0.1, actor)
	var paused_at: float = art.player.current_animation_position
	visual.animate(0.2, actor)
	check(is_equal_approx(art.player.current_animation_position, paused_at), "Stun pauses skeletal animation")
	actor.stunned = 0.0
	visual.animate(0.1, actor)
	check(not is_equal_approx(art.player.current_animation_position, paused_at), "Animation resumes after stun")
	var transform_before: Transform3D = actor.transform
	actor.hp = 0
	visual.animate(0.4, actor)
	check(visual.rotation.x < -1, "Defeat presentation retained")
	check(actor.transform == transform_before, "Animation never alters combat transform")
	actor.hp = 100
	visual.animate(0.4, actor)
	check(is_zero_approx(visual.rotation.x), "Revive restores upright model")
	var collision: CollisionShape3D = actor.get_child(0)
	check(is_equal_approx(collision.shape.radius, 0.42) and is_equal_approx(collision.shape.height, 1.8), "Collision dimensions preserved")
	print("Fulcrum presentation: %d/%d checks passed" % [checks - failures, checks])
	actor.queue_free()
	await process_frame
	quit(1 if failures else 0)
