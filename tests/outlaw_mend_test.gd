extends SceneTree
## Runs unchanged on desktop and on the isolated 4.5 dedicated project.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var actor = load("res://scripts/combatant.gd").new()
	root.add_child(actor); actor.setup(1,1,0,"Outlaw",false); actor.setup_hitboxes()
	var art = actor.hitbox_pose.art
	var mend := -1
	for i in actor.kit.size():
		if actor.kit[i].kind == "self_heal": mend = i
	check(mend >= 0,"Outlaw has Mend")
	check(actor.kit[mend].cast == 2.0 and actor.kit[mend].cd == 30.0,"Mend cast and cooldown is 30 seconds")
	check(actor.champion_model == null and actor.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),"No server render meshes")
	check(not ResourceLoader.has_cached("res://assets/characters/outlaw.glb"),"No server visual GLB loaded")
	check(art.player.has_animation(art.clip_names.Mend),"Portable Mend library installed")
	var samples := []
	var first_spine := Quaternion.IDENTITY
	var body_motion := 0.0
	var finger_motion := 0.0
	var first_finger := Quaternion.IDENTITY
	for state in ["idle","mend","finish","recover","cancel","starshot","death","revive"]:
		for frame in 60:
			actor.hp = 0 if state == "death" else actor.MAX_HEALTH
			actor.presentation_grounded = true
			actor.stunned = 0
			actor.casting = mend if state in ["mend","finish","cancel"] else (0 if state == "starshot" else -1)
			actor.cast_left = 2.0-frame/60.0 if actor.casting >= 0 else 0.0
			if state in ["finish","cancel"] and frame >= 30:
				actor.casting = -1; actor.cast_left = 0.0
				if state == "finish" and frame == 30: actor.cooldowns[mend] = 16.0
			actor.update_hitboxes(1.0/60)
			var row := []
			for point in actor.body_hitboxes.points: row.append([point.x,point.y,point.z])
			samples.append(row)
			if state == "mend":
				check(art.clip == "Mend","Mend selects hand-work instead of generic casting")
				var spine: Quaternion = art.skeleton.get_bone_pose_rotation(art.skeleton.find_bone("DEF-spine.003"))
				var finger: Quaternion = art.skeleton.get_bone_pose_rotation(art.skeleton.find_bone("DEF-f_index.01.R"))
				if frame == 20: first_spine = spine; first_finger = finger
				if frame > 20:
					body_motion = maxf(body_motion,first_spine.angle_to(spine))
					finger_motion = maxf(finger_motion,first_finger.angle_to(finger))
		if state == "mend": check(art.equipment.handwork_weight > .999,"Hands freed during Mend")
		if state in ["finish","recover","cancel","starshot","revive"]:
			check(art.clip != "Mend","Mend exits cleanly: "+state)
			check(art.equipment.handwork_weight == 0.0,"Weapon presentation restored: "+state)
			for bone in art.equipment.weapon_scales:
				check(art.skeleton.get_bone_pose_scale(bone).is_equal_approx(art.equipment.weapon_scales[bone]),"Weapon scale restored")
	check(body_motion > .001,"Idle torso continues moving during Mend")
	check(finger_motion > .001,"Hand-work retains articulated fingers")
	var output: String = "res://artifacts/outlaw-mend-handwork/pose-"+Engine.get_version_info().string+".json"
	if "--compat" in OS.get_cmdline_user_args(): output = "res://pose-"+Engine.get_version_info().string+".json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(samples)); file.close()
	print("Outlaw Mend motion: body=",body_motion," finger=",finger_motion," samples=",samples.size())
	print("Outlaw Mend checks: %d passed / %d total" % [checks-failures,checks])
	actor.free(); quit(1 if failures else 0)
