extends SceneTree
var checks := 0
var failures := 0
func ck(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var actor = load("res://scripts/combatant.gd").new(); root.add_child(actor); actor.setup(1,1,0,"Outlaw")
	var art = actor.champion_model.outlaw_art
	var rig: Skeleton3D = art.skeleton
	ck(rig.get_bone_count()==85 and art.clip_names.size()==36, "Outlaw imports 85 bones and 36 native/derived clips")
	for item in [["outlaw.gun","DEF-hand.R"],["outlaw.knife","DEF-hand.L"]]:
		ck(rig.get_bone_parent(rig.find_bone(item[0]))==rig.find_bone(item[1]), "Equipment remains attached to its actual carrying hand: "+item[0])
	actor.presentation_grounded = true
	for label in art.clip_names:
		art.player.play(art.clip_names[label]); art.player.seek(art.player.current_animation_length*.35,true)
		art.equipment.apply()
		var finite := true
		for i in rig.get_bone_count(): finite = finite and rig.get_bone_global_pose(i).is_finite()
		ck(finite,"Every sampled pose stays finite: "+label)
		for i in art.equipment.grip:
			ck(rig.get_bone_pose_rotation(i).angle_to(art.equipment.grip[i])<.001,"Closed equipment grip persists in "+label)
	for item in [[Vector3.BACK,"WalkBackward"],[Vector3(1,0,1).normalized(),"WalkBackwardRight"],[Vector3(-1,0,1).normalized(),"WalkBackwardLeft"],[Vector3.RIGHT,"SprintRight"],[Vector3.FORWARD,"Sprint"]]:
		actor.casting=-1; art.transient_left=0; art.was_casting=false; art.was_airborne=false
		for i in 20:
			art.last_position = actor.position - item[0]*6.5/60
			actor.champion_model.animate(1.0/60,actor)
		ck(art.clip==item[1],"Accepted directional movement: "+item[1])
	actor.casting=-1; art.test_aim_weight=1; art.test_aim_direction=-actor.basis.z
	for i in 20:
		art.last_position=actor.position+Vector3.BACK*6.5/60
		actor.champion_model.animate(1.0/60,actor)
	ck(art.is_locomotion(art.clip) and art.equipment.aim_weight > .99,"Moving Detonation keeps locomotion legs while aiming the revolver")
	art.test_aim_weight=0; actor.casting=9
	for i in 20:
		art.last_position=actor.position+Vector3.BACK*3.25/60
		actor.champion_model.animate(1.0/60,actor)
	ck(art.clip=="Walk", "Deadeye uses the library's walking gait")
	await directional_actions(actor, art)
	actor.casting=-1; actor.identity.roll_left=art.Outlaw.ROLL_SECONDS*.5; actor.identity.roll_direction=Vector3.LEFT
	actor.champion_model.animate(.016,actor)
	ck(art.clip=="Roll" and absf(wrapf(art.model.rotation.y-PI,-PI,PI))>1,"Directional Roll turns and uses the actual library clip")
	ck(is_equal_approx(art.player.current_animation_position,art.player.get_animation(art.clip_names.Roll).length*.25),"Roll plays at half its previous speed while travel is unchanged")
	actor.identity.roll_left=.001; actor.champion_model.animate(.016,actor)
	ck(absf(art.player.current_animation_position/art.player.get_animation(art.clip_names.Roll).length-.5)<.002,"Roll reaches the animation midpoint as physical travel ends")
	actor.identity.roll_left=0; actor.identity.outlaw_action="roll"
	actor.identity.roll_animation_left=art.Outlaw.ROLL_PRESENTATION_SECONDS-art.Outlaw.ROLL_ANIMATION_SECONDS*.6
	actor.champion_model.animate(.016,actor)
	ck(art.clip=="Roll" and is_equal_approx(art.player.current_animation_position/art.player.get_animation(art.clip_names.Roll).length,.6),"Slower Roll retains its cadence through the crouched recovery")
	actor.casting=1; actor.champion_model.animate(.016,actor)
	ck(art.clip!="Roll","Severe can immediately take over the cosmetic recovery")
	actor.casting=-1; actor.identity.roll_animation_left=0
	roll_to_running(actor,art)
	actor.identity.roll_left=0;actor.identity.backflip_active=true;actor.identity.backflip_elapsed=.5
	actor.presentation_grounded=false;actor.velocity.y=2
	actor.champion_model.animate(.016,actor)
	ck(art.clip=="Roll" and rig.get_bone_global_pose(rig.find_bone("DEF-head")).is_finite(),"Backflip plays the adapted native roll without invalid transforms")
	ck(is_equal_approx(art.model.rotation.y,PI),"Backflip does not inherit a preceding side-roll heading")
	actor.identity.backflip_elapsed=art.Outlaw.BACKFLIP_AIRTIME*.5
	actor.champion_model.animate(.016,actor)
	var roll_length: float=art.player.get_animation(art.clip_names.Roll).length
	ck(art.player.current_animation_position<roll_length*.4,"Backflip has progressed through the actual rotation by the airborne midpoint")
	actor.identity.backflip_elapsed=art.Outlaw.BACKFLIP_AIRTIME
	actor.champion_model.animate(.016,actor)
	ck(art.player.current_animation_position<.001,"Backflip completes its existing native rotation by the shortened landing time")
	early_backflip(actor,art)
	actor.identity.backflip_active=false;actor.casting=-1;actor.presentation_grounded=true
	art.fire("knife")
	actor.champion_model.animate(.2,actor)
	ck(art.equipment.knife_weight>.9 and art.equipment.knife_frames.size()>10,"Severe plays the mirrored native knife-hand attack")
	ck(art.RUN_CADENCE_SCALE==.90 and art.BACKPEDAL_CADENCE_SCALE==1.15 and art.JUMP_BODY_BLEND_SECONDS==.16,"Approved shared cadence and jump smoothing constants remain unchanged")
	actor.queue_free();await process_frame
	print("Outlaw presentation checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)

func roll_to_running(actor,art) -> void:
	var hips: int=art.skeleton.find_bone("DEF-hips")
	var directions := [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3(1,0,-1).normalized(),Vector3(1,0,1).normalized(),Vector3(-1,0,1).normalized(),Vector3(-1,0,-1).normalized()]
	for direction in directions:
		actor.casting=-1; actor.presentation_grounded=true; actor.identity.backflip_active=false
		actor.identity.roll_left=0; actor.identity.outlaw_action="roll"; actor.identity.roll_direction=direction
		actor.identity.roll_animation_left=.005
		art.last_position=actor.position-direction*6.5/60
		actor.champion_model.animate(1.0/60,actor)
		ck(art.player.current_animation_position/art.player.current_animation_length<.63,"Roll never samples the removed standing tail")
		var before: Quaternion=art.skeleton.get_bone_pose_rotation(hips)
		actor.identity.roll_animation_left=0
		for frame in 8:
			art.last_position=actor.position-direction*6.5/60
			actor.champion_model.animate(1.0/60,actor)
			ck(art.is_locomotion(art.clip),"Roll exits directly into directional locomotion without idle/cast frames")
			if frame==0:
				ck(art.pose_blend.elapsed<art.pose_blend.duration and before.angle_to(art.skeleton.get_bone_pose_rotation(hips))<.35,"Running begins with a short blend from the displayed crouch")
	actor.identity.outlaw_action=""

func early_backflip(actor,art) -> void:
	var hips: int=art.skeleton.find_bone("DEF-hips")
	for rate in [30,60,144]:
		actor.identity.backflip_active=false; actor.identity.roll_left=0; actor.casting=-1
		actor.presentation_grounded=true; actor.velocity=Vector3.ZERO
		art.shot_left=0; art.knife_left=0
		for frame in 30: actor.champion_model.animate(1.0/60,actor)
		var before: Quaternion=art.skeleton.get_bone_global_pose(hips).basis.get_rotation_quaternion()
		actor.identity.backflip_active=true; actor.presentation_grounded=false
		for frame in ceili(rate*.1):
			actor.identity.backflip_elapsed=(frame+1)/float(rate)
			actor.velocity.y=art.Outlaw.BACKFLIP_SPEED-20*actor.identity.backflip_elapsed
			actor.champion_model.animate(1.0/rate,actor)
			if frame==0:
				var first: float=rad_to_deg(before.angle_to(art.skeleton.get_bone_global_pose(hips).basis.get_rotation_quaternion()))
				ck(first>0 and first<20,"Backflip begins rotating immediately with a short smooth blend at %d FPS" % rate)
		var early: float=rad_to_deg(before.angle_to(art.skeleton.get_bone_global_pose(hips).basis.get_rotation_quaternion()))
		ck(early>25,"Body is already visibly flipping within roughly 100ms of takeoff at %d FPS" % rate)
		print("BACKFLIP_EARLY_ROTATION %d FPS: %.2f degrees by %.3fs" % [rate,early,actor.identity.backflip_elapsed])

func directional_actions(actor, art) -> void:
	var directions := [Vector3.FORWARD, Vector3(1,0,-1).normalized(), Vector3.RIGHT, Vector3(1,0,1).normalized(), Vector3.BACK, Vector3(-1,0,1).normalized(), Vector3.LEFT, Vector3(-1,0,-1).normalized()]
	var walks := ["Walk", "WalkForwardRight", "StrafeRight", "WalkBackwardRight", "WalkBackward", "WalkBackwardLeft", "StrafeLeft", "WalkForwardLeft"]
	var runs := ["Run", "RunForwardRight", "RunRight", "WalkBackwardRight", "WalkBackward", "WalkBackwardLeft", "RunLeft", "RunForwardLeft"]
	for yaw in [0.0, PI/2]:
		actor.rotation.y = yaw
		for action in [["Deadeye",9,false,3.25], ["Detonation",-1,false,6.5], ["Severe",1,false,6.5], ["Walking Severe",1,true,1.6], ["Walking Detonation",-1,true,3.25], ["Starshot",0,false,4.55], ["Walking Starshot",0,true,2.275], ["Walking shot recovery",-1,true,1.6], ["Walking knife strike",-1,true,1.6]]:
			actor.casting=action[1]; actor.cast_left=3; actor.walking=action[2]
			art.test_aim_weight = 1.0 if "Detonation" in action[0] else 0.0
			art.test_aim_direction = -actor.basis.z
			for sector in 8:
				art.shot_left=0;art.knife_left=0
				var motion_speed: float=action[3]
				if action[1]==0 and sector in [3,4,5]: motion_speed=3.8*.7*(.5 if action[2] else 1.0)
				var natural_clip := ""
				if "Detonation" in action[0]:
					art.test_aim_weight=0
					for frame in 12:
						art.last_position=actor.position-actor.basis*directions[sector]*action[3]/60.0
						actor.champion_model.animate(1.0/60,actor)
					natural_clip=art.clip
					art.test_aim_weight=1
				if action[0]=="Walking shot recovery": art.fire("gun")
				if action[0]=="Walking knife strike": art.fire("knife")
				for frame in 12:
					art.last_position=actor.position-actor.basis*directions[sector]*motion_speed/60.0
					actor.champion_model.animate(1.0/60,actor)
				var expected: String = runs[sector] if action[0] in ["Detonation","Severe","Starshot"] else walks[sector]
				if not natural_clip.is_empty(): expected=natural_clip
				ck(art.clip==expected and art.player.current_animation==art.clip_names[expected], "%s sector %d at yaw %.2f plays the actual imported clip" % [action[0],sector,yaw])
				ck(art.skeleton.get_bone_global_pose(art.skeleton.find_bone("DEF-hand.R")).is_finite(), "%s sector %d keeps the carrying arm finite" % [action[0],sector])
				if action[1]==0:
					var rate: float=clampf(motion_speed/3.8*1.15,.55,2.5) if sector in [3,4,5] else (clampf(motion_speed/1.35,.55,2.5) if action[2] else clampf(motion_speed/2.8,.55,2.5)*.9)
					ck(absf(art.player.speed_scale-rate)<.08,"Starshot running/walking cadence follows the slowed travel speed")
	actor.rotation.y=0;actor.walking=false;actor.casting=-1
	art.shot_left=0;art.knife_left=0;art.test_aim_weight=0
