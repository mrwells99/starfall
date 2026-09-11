extends "res://scripts/model_forge_art.gd"
## Outlaw equipment/action layers leave the accepted 32-clip base intact.
const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
const BACKFLIP_ROLL_START := .60 # Skip the forward Roll's recovery when playing it backwards.
var active_actor
var shot_left := 0.0
var knife_left := 0.0
var action_serial := -1
var step_motion := Vector3.ZERO
var special_kind := ""
var backflip_clock = preload("res://scripts/outlaw_backflip_clock.gd").new()
var roll_clock = preload("res://scripts/snapshot_animation_clock.gd").new()
var special_blend = preload("res://scripts/model_forge_pose_blend.gd").new()
var test_aim_weight := 0.0
var test_aim_direction := Vector3.FORWARD

func _init() -> void:
	asset_path = "res://assets/characters/outlaw.glb"
	class_title = "Outlaw"
	equipment = preload("res://scripts/outlaw_equipment.gd").new()

func build(host: Node3D, team_color: Color) -> void:
	super.build(host, team_color)
	player.play(clip_names.GunAim); player.seek(.15, true)
	for suffix in ["shoulder", "upper_arm", "forearm", "hand"]:
		var i: int = skeleton.find_bone("DEF-" + suffix + ".R")
		equipment.aim[i] = skeleton.get_bone_pose_rotation(i)
	var shot: Animation = player.get_animation(clip_names.GunShoot)
	player.play(clip_names.GunShoot)
	for frame in ceili(shot.length * 30) + 1:
		player.seek(minf(shot.length, frame / 30.0), true)
		var sample := {}
		for i in equipment.aim: sample[i] = skeleton.get_bone_pose_rotation(i)
		equipment.gun_frames.append(sample)
	var strike: Animation = player.get_animation(clip_names.KnifeStrike)
	player.play(clip_names.KnifeStrike)
	for frame in ceili(strike.length * 30) + 1:
		player.seek(minf(strike.length, frame / 30.0), true)
		var sample := {}
		for suffix in ["shoulder", "upper_arm", "forearm", "hand"]:
			var i: int = skeleton.find_bone("DEF-" + suffix + ".L")
			sample[i] = skeleton.get_bone_pose_rotation(i)
		equipment.knife_frames.append(sample)
	player.play(clip_names.Idle); player.advance(0); equipment.apply()
	pose_blend.build(skeleton)
	special_blend.build(skeleton)

func fire(tag: String) -> void:
	if tag == "knife": knife_left = .65
	else: shot_left = .32

func muzzle_position() -> Vector3:
	# Same hand-local point used to author the revolver's luminous bore in Blender.
	return skeleton.global_transform * (skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.R")) * Vector3(-.030,.413,.085))

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
	active_actor = actor
	step_motion = actor.global_basis.inverse() * (actor.global_position - last_position) if initialized else Vector3.ZERO
	if actor.presentation_snapshot_serial > 0:
		step_motion = actor.global_basis.inverse() * network_motion.displacement(actor, Vector3.ZERO, delta)
	if action_serial != actor.identity.outlaw_action_serial:
		if action_serial >= 0:
			if actor.identity.outlaw_action == "knife": knife_left = .65
			elif actor.identity.outlaw_action == "gun": shot_left = .32
		action_serial = actor.identity.outlaw_action_serial
	shot_left = maxf(0, shot_left - delta); knife_left = maxf(0, knife_left - delta)
	var gun_cast: bool = actor.casting >= 0 and actor.kit[actor.casting].kind in ["starshot", "deadeye"]
	var special: bool = actor.identity.roll_left > 0 or actor.identity.backflip_active
	var next_special: String = "roll" if actor.identity.roll_left > 0 else ("backflip" if actor.identity.backflip_active else "")
	if special and next_special != special_kind: special_blend.begin(.08,.08 if next_special == "backflip" else .16)
	special_kind = next_special
	if next_special != "backflip" or actor.hp <= 0 or actor.stunned > 0:
		backflip_clock.reset()
	if next_special != "roll" or actor.hp <= 0 or actor.stunned > 0:
		roll_clock.reset()
	equipment.aim_weight = move_toward(equipment.aim_weight, 1.0 if (gun_cast or shot_left > 0) and not special else 0.0, delta * 12)
	if not special and actor.hp > 0 and actor.stunned <= 0:
		equipment.aim_weight = maxf(equipment.aim_weight,test_aim_weight)
	equipment.knife_weight = move_toward(equipment.knife_weight, 1.0 if knife_left > 0 else 0.0, delta * 15)
	equipment.knife_time = .65 - knife_left
	equipment.shot_time = .32 - shot_left if shot_left > 0 else -1.0
	super.animate(host, delta, actor)
	if special and actor.hp > 0 and actor.stunned <= 0:
		var rolling: bool = actor.identity.roll_left > 0
		var progress: float = 1.0 - actor.identity.roll_left / Outlaw.ROLL_SECONDS
		if rolling:
			progress = roll_clock.advance(Outlaw.ROLL_SECONDS - actor.identity.roll_left, delta,
				actor.presentation_snapshot_serial, actor.motion_revision, Outlaw.ROLL_SECONDS) / Outlaw.ROLL_SECONDS
		else:
			progress = backflip_clock.advance(actor.identity.backflip_elapsed, delta,
				actor.presentation_snapshot_serial, actor.motion_revision, Outlaw.BACKFLIP_AIRTIME) / Outlaw.BACKFLIP_AIRTIME
		var animation: Animation = player.get_animation(clip_names.Roll)
		player.seek(animation.length * (progress if rolling else BACKFLIP_ROLL_START * (1.0 - progress)), true)
		special_blend.apply(delta)
		equipment.apply()
		if rolling:
			var direction: Vector3 = actor.global_basis.inverse() * actor.identity.roll_direction
			model.rotation.y = PI + atan2(-direction.x, -direction.z)
		else:
			model.rotation.y = PI
	else:
		model.rotation.y = lerp_angle(model.rotation.y, PI, minf(1, delta * 25))
		if actor.hp > 0 and actor.stunned <= 0 and actor.casting < 0: apply_test_aim()

func apply_test_aim() -> void:
	if test_aim_weight <= 0: return
	# Aim the existing articulated pistol pose as a unit; keep elbow/finger grip.
	var hand: int = skeleton.find_bone("DEF-hand.R")
	var upper: int = skeleton.find_bone("DEF-upper_arm.R")
	skeleton.force_update_all_bone_transforms()
	var forward: Vector3 = (skeleton.global_basis*skeleton.get_bone_global_pose(hand).basis*Vector3.UP).normalized()
	var correction := Quaternion(forward,test_aim_direction.normalized())
	var parent: int = skeleton.get_bone_parent(upper)
	var basis: Basis = (skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis).orthonormalized()
	var local_correction: Quaternion = basis.get_rotation_quaternion().inverse()*correction*basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(upper,Quaternion.IDENTITY.slerp(local_correction,test_aim_weight)*skeleton.get_bone_pose_rotation(upper))

func override_clip(desired: String, alive: bool, stunned: bool, _delta: float) -> String:
	if not alive or stunned or active_actor == null: return desired
	if active_actor.identity.roll_left > 0 or active_actor.identity.backflip_active: return "Roll"
	var spell_kind: String = active_actor.kit[active_actor.casting].kind if active_actor.casting >= 0 else ""
	if spell_kind in ["starshot", "deadeye", "severe"] or shot_left > 0 or knife_left > 0:
		if was_airborne: return desired if desired.begins_with("Jump") else "JumpLoop"
		if filtered_speed <= .12: return "Idle"
		var sector := posmod(roundi(atan2(step_motion.x, -step_motion.z) / (PI / 4)), 8)
		var suffixes := ["", "ForwardRight", "Right", "BackwardRight", "Backward", "BackwardLeft", "Left", "ForwardLeft"]
		var prefix := "Walk" if sector in [3, 4, 5] or spell_kind == "deadeye" or active_actor.walking else "Run"
		# Forge v2 names the two sideways walking clips StrafeLeft/StrafeRight.
		if prefix == "Walk" and sector in [2, 6]: return "StrafeRight" if sector == 2 else "StrafeLeft"
		return prefix + suffixes[sector]
	return desired
