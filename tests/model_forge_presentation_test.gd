extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func class_names() -> Array:
	return ["Ember", "Luminary", "Vanguard"]
func run() -> void:
	for title in class_names(): await run_class(title)
	print("Model Forge presentation: %d passed / %d total" % [checks-failures, checks])
	quit(1 if failures else 0)
func run_class(title: String) -> void:
	var actor = load("res://scripts/combatant.gd").new()
	root.add_child(actor); actor.setup(1, 1, 0, title)
	var visual = actor.champion_model
	var art = visual.get(title.to_lower()+"_art")
	check(art.skeleton.get_bone_count() == {"Ember":73,"Luminary":80,"Vanguard":66}[title], title+" preset and costume controls")
	for bone in ["DEF-hips","DEF-spine.001","DEF-spine.002","DEF-spine.003","DEF-head","DEF-hand.L","DEF-f_index.03.L","DEF-thigh.R","DEF-toe.R"]:
		check(art.skeleton.find_bone(bone)>=0,title+" preset bone "+bone)
	check(visual.torso.name==title+"_SkinnedModel" and visual.torso.skin!=null,title+" preserves costume")
	var undersuit=art.model.find_child(title+"_UAL_Undersuit",true,false)
	check(undersuit is MeshInstance3D and undersuit.skin!=null,title+" uses actual mannequin")
	for material in art.materials:
		check(not "hair" in material.resource_name.to_lower() and not "eyewhite" in material.resource_name.to_lower(),title+" sealed head and no hair")
	var singles := ["Strike","CastEnter", "CastRelease", "CastExit", "JumpStart", "JumpLand"]
	check(art.clip_names.size() == (34 if title=="Vanguard" else 33), "All selected/derived presets plus Mend hand-work are available")
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
	if title == "Vanguard":
		actor.charge = {"target": 2}
		actor.presentation_grounded = false
		actor.presentation_vertical_speed = 4.0
		actor.position += Vector3.FORWARD * 32.0 / 30.0
		visual.animate(1.0 / 30.0, actor)
		check(art.clip == "Sprint", "Charge uses locomotion even above the teleport filter and on a rising ramp")
		actor.charge.clear()
		actor.presentation_grounded = null
		actor.presentation_vertical_speed = 0.0
		visual.animate(.016, actor)
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
	root.add_child(other); other.setup(2,2,1,title)
	actor.flash = .2; visual.animate(.016,actor)
	check(art.materials[0].albedo_color == Color.WHITE, "Hit flash preserved")
	check(art.materials[0] != other.champion_model.get(title.to_lower()+"_art").materials[0], "Material state isolated per actor")
	actor.flash = 0; visual.animate(.016,actor)
	check(art.materials[0].albedo_color == art.base_colors[0], "Hit flash restores appearance")
	for node in visual.find_children("*", "Node", true, false): check(not node is CollisionObject3D, "No costume collision introduced")

	# End the remote fixture; remaining grip/jump probes supply local poses directly.
	actor.presentation_snapshot_serial=0
	actor.flash=0; actor.stunned=0; actor.hp=100; actor.casting=-1
	actor.presentation_grounded=true
	art.was_airborne=false; art.transient_left=0
	# The first tiny input frame must preserve the displayed pose, including
	# equipment. New-clip grip offsets must not bypass the final pose blend.
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.BACK,Vector3.FORWARD,Vector3.ZERO]:
		var previous:Array[Transform3D]=[]
		for index in art.skeleton.get_bone_count():previous.append(art.skeleton.get_bone_global_pose(index))
		actor.position+=direction*6.5*.001
		visual.animate(.001,actor)
		var maximum:=0.0
		for index in previous.size():
			maximum=maxf(maximum,previous[index].origin.distance_to(art.skeleton.get_bone_global_pose(index).origin))
		check(maximum<.02,title+" equipment and joints do not snap on direction changes: "+str(maximum))
	for direction in [Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT,Vector3.BACK]:
		for frame in 15:
			actor.position+=direction*6.5/60
			visual.animate(1.0/60,actor)
			check_grip(art,title)
	actor.presentation_grounded=false
	for velocity in [7.0,5.0,3.0,0.0,-3.0,-5.0,-7.0]:
		actor.presentation_vertical_speed=velocity
		visual.animate(.06,actor)
		check_grip(art,title)
		check(is_equal_approx(art.jump_pose.lift,clampf(1.0-velocity*velocity/49.0,0,1)),title+" accepted jump velocity arc")
	if title=="Vanguard":
		actor.presentation_grounded=true; art.was_airborne=false; art.transient_left=0
		actor.shield=20; visual.animate(.016,actor)
		check(art.ward.visible and art.pulse.visible,"Vanguard shield presentation retained")
		art.strike(); visual.animate(.016,actor)
		check(art.clip=="Strike" and art.player.get_animation(art.clip_names["Strike"]).loop_mode==Animation.LOOP_NONE,"Vanguard confirmed-hit strike retained")
		for frame in 50:
			visual.animate(1.0/60,actor); check_grip(art,title)
		check(art.clip!="Strike","Vanguard strike recovers")
	if title=="Luminary":
		art.player.play("Idle");art.player.seek(.1,true)
		var grip:Dictionary={}
		for index in art.skeleton.get_bone_count():
			var name:String=art.skeleton.get_bone_name(index)
			if name.ends_with(".R") and (name.begins_with("DEF-f_") or name.begins_with("DEF-thumb")):
				grip[index]=art.skeleton.get_bone_pose_rotation(index)
		for name in ["CastEnter","Cast","CastRelease","JumpStart","JumpLoop"]:
			art.player.play(name);art.player.seek(.2,true)
			for index in grip:
				check(art.skeleton.get_bone_pose_rotation(index).angle_to(grip[index])<.002,"Luminary keeps the preset staff grip during "+name)
	actor.queue_free(); other.queue_free(); await process_frame
	print("CLASS_PRESENTATION_CHECKED ",title)
func check_grip(art, title: String) -> void:
	if title=="Ember": return
	var rig: Skeleton3D=art.skeleton
	var gear=art.equipment
	var pose:=rig.get_bone_global_pose(gear.weapon)
	if title=="Luminary":
		check(pose.origin.distance_to(rig.get_bone_global_pose(gear.hands[1])*Vector3(0,.055,.012))<.0001,"Luminary staff follows the final hand pose")
	else:
		for side in 2:
			check((pose*gear.wrist_offsets[side]).distance_to(rig.get_bone_global_pose(gear.hands[side]).origin)<.0001,"Vanguard keeps both wrists on the rigid hammer through transitions")
