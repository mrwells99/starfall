extends "res://scripts/model_forge_art.gd"
## Outlaw equipment/action layers leave the accepted 32-clip base intact.
const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
var active_actor
var shot_left := 0.0
var knife_left := 0.0
var action_serial := -1
var step_motion := Vector3.ZERO
var special_kind := ""
var special_blend = preload("res://scripts/model_forge_pose_blend.gd").new()

func _init() -> void:
	asset = preload("res://assets/characters/outlaw.glb")
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
	if action_serial != actor.identity.outlaw_action_serial:
		if action_serial >= 0:
			if actor.identity.outlaw_action == "knife": knife_left = .65
			elif actor.identity.outlaw_action == "gun": shot_left = .32
		action_serial = actor.identity.outlaw_action_serial
	shot_left = maxf(0, shot_left - delta); knife_left = maxf(0, knife_left - delta)
	var gun_cast: bool = actor.casting >= 0 and actor.kit[actor.casting].kind in ["starshot", "defense_detonation", "deadeye"]
	var special: bool = actor.identity.roll_left > 0 or actor.identity.backflip_active
	var next_special: String = "roll" if actor.identity.roll_left > 0 else ("backflip" if actor.identity.backflip_active else "")
	if special and next_special != special_kind: special_blend.begin(.08,.16)
	special_kind = next_special
	equipment.aim_weight = move_toward(equipment.aim_weight, 1.0 if (gun_cast or shot_left > 0) and not special else 0.0, delta * 12)
	equipment.knife_weight = move_toward(equipment.knife_weight, 1.0 if knife_left > 0 else 0.0, delta * 15)
	equipment.knife_time = .65 - knife_left
	equipment.shot_time = .32 - shot_left if shot_left > 0 else -1.0
	super.animate(host, delta, actor)
	if special and actor.hp > 0 and actor.stunned <= 0:
		var rolling: bool = actor.identity.roll_left > 0
		var progress: float = 1.0 - actor.identity.roll_left / Outlaw.ROLL_SECONDS if rolling else clampf(actor.identity.backflip_elapsed / 1.2, 0, 1)
		var animation: Animation = player.get_animation(clip_names.Roll)
		player.seek(animation.length * (progress if rolling else 1.0 - progress), true)
		special_blend.apply(delta)
		equipment.apply()
		if rolling:
			var direction: Vector3 = actor.global_basis.inverse() * actor.identity.roll_direction
			model.rotation.y = PI + atan2(-direction.x, -direction.z)
		else:
			model.rotation.y = PI
	else:
		model.rotation.y = lerp_angle(model.rotation.y, PI, minf(1, delta * 25))

func override_clip(desired: String, alive: bool, stunned: bool, _delta: float) -> String:
	if not alive or stunned or active_actor == null: return desired
	if active_actor.identity.roll_left > 0 or active_actor.identity.backflip_active: return "Roll"
	var spell_kind: String = active_actor.kit[active_actor.casting].kind if active_actor.casting >= 0 else ""
	if spell_kind in ["starshot", "defense_detonation", "deadeye", "severe"] or shot_left > 0 or knife_left > 0:
		if was_airborne: return desired if desired.begins_with("Jump") else "JumpLoop"
		if filtered_speed <= .12: return "Idle"
		var sector := posmod(roundi(atan2(step_motion.x, -step_motion.z) / (PI / 4)), 8)
		var suffixes := ["", "ForwardRight", "Right", "BackwardRight", "Backward", "BackwardLeft", "Left", "ForwardLeft"]
		var prefix := "Walk" if sector in [3, 4, 5] or spell_kind == "deadeye" or active_actor.walking else "Run"
		# Forge v2 names the two sideways walking clips StrafeLeft/StrafeRight.
		if prefix == "Walk" and sector in [2, 6]: return "StrafeRight" if sector == 2 else "StrafeLeft"
		return prefix + suffixes[sector]
	return desired
