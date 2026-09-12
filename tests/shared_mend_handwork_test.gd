extends SceneTree
var checks := 0
var failures := 0
var maximum_error := 0.0
var samples := []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var server_only := "--compat" in OS.get_cmdline_user_args()
	for title in ["Ember","Luminary","Vanguard","Fulcrum"]:
		var server = load("res://scripts/combatant.gd").new(); root.add_child(server)
		server.setup(1,1,0,title,false); server.setup_hitboxes()
		var visible = null
		if not server_only:
			visible = load("res://scripts/combatant.gd").new(); root.add_child(visible)
			visible.setup(1,1,0,title); visible.setup_hitboxes()
		var art = server.hitbox_pose.art
		var slot := -1
		for i in server.kit.size():
			if server.kit[i].kind == "self_heal": slot = i
		check(slot >= 0,title+" has Mend")
		check(server.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),title+" server stays mesh-free")
		if server_only: check(not ResourceLoader.has_cached("res://assets/characters/"+title.to_lower()+".glb"),title+" server loads no visual GLB")
		for state in ["idle","mend","complete","recast","move_cancel","stun","revive"]:
			for frame in 48:
				var actors: Array = [server] if server_only else [server,visible]
				for actor in actors:
					actor.presentation_grounded = true; actor.hp = actor.MAX_HEALTH
					actor.stunned = 1.0 if state == "stun" and frame > 20 else 0.0
					actor.casting = slot if state in ["mend","recast","stun"] else -1
					if actor.stunned > 0: actor.casting = -1
					actor.cast_left = 2.0-frame/60.0 if actor.casting >= 0 else 0.0
					if state == "complete" and frame == 0: actor.cooldowns[slot] = 16.0
					if state == "move_cancel": actor.position += Vector3.FORWARD*3.0/60.0
				server.update_hitboxes(1.0/60)
				if visible != null:
					visible.champion_model.animate(1.0/60,visible); visible.body_hitboxes.update()
					# Compare in presenter space: wall-clock cosmetic stun wobble is
					# evaluated at different wall times in these sequential calls.
					for i in server.body_hitboxes.points.size():
						var a: Vector3 = server.hitbox_pose.global_transform.affine_inverse()*server.body_hitboxes.points[i]
						var b: Vector3 = visible.champion_model.global_transform.affine_inverse()*visible.body_hitboxes.points[i]
						maximum_error = maxf(maximum_error,a.distance_to(b))
				var row := []
				for point in server.body_hitboxes.points:
					var local: Vector3 = server.hitbox_pose.global_transform.affine_inverse()*point
					row.append([local.x,local.y,local.z])
				samples.append(row)
				if state == "mend" and frame == 35:
					check(art.clip == "Mend",title+" selects shared hand-work")
					var clip: Animation = art.player.get_animation(art.clip_names.Mend)
					for bone_name in ["DEF-upper_arm.L","DEF-forearm.L","DEF-upper_arm.R","DEF-forearm.R","DEF-head"]:
						var bone: int = art.skeleton.find_bone(bone_name)
						for track in clip.get_track_count():
							if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and String(clip.track_get_path(track).get_subname(0)) == bone_name:
								var target := clip.rotation_track_interpolate(track,art.player.current_animation_position)
								check(Basis(target).is_equal_approx(Basis(art.skeleton.get_bone_pose_rotation(bone))),title+" retains approved "+bone_name+" motion")
					if title == "Vanguard": check(art.skeleton.get_bone_pose_scale(art.equipment.weapon).length() < .01,"Vanguard weapon concealed and two-handed solve fully released")
					if title == "Luminary":
						var gear = art.equipment
						check(art.skeleton.get_bone_global_pose(gear.weapon).origin.distance_to(art.skeleton.get_bone_global_pose(gear.hands[1])*Vector3(0,.055,.012)) < .0001,"Luminary staff remains in the moving right hand")
					if title == "Fulcrum": check((art.skeleton.get_bone_global_pose(art.jump_pose.focus).origin-art.skeleton.get_bone_global_pose(art.jump_pose.hand).origin).distance_to(art.mend_focus_offset) < .0001,"Fulcrum orb follows the working hand")
			if state in ["complete","move_cancel","revive"]:
				check(art.clip != "Mend",title+" exits Mend on "+state)
				if title == "Vanguard":
					var gear = art.equipment
					check(art.skeleton.get_bone_pose_scale(gear.weapon).is_equal_approx(gear.weapon_scale),"Vanguard weapon size restored")
					var weapon: Transform3D = art.skeleton.get_bone_global_pose(gear.weapon)
					for side in 2: check(art.skeleton.get_bone_global_pose(gear.hands[side]).origin.distance_to(weapon*gear.wrist_offsets[side]) < .0001,"Vanguard regrips with both hands after "+state)
		if visible != null: visible.free()
		server.free()
	check(maximum_error < .0005,"All Mend/cancel/stun poses agree between visible and server rigs")
	var output: String = "res://pose-"+Engine.get_version_info().string+".json" if server_only else "res://artifacts/shared-mend-handwork/poses.json"
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(samples)); file.close()
	print("Shared Mend maximum pose error: ",maximum_error," meters; samples=",samples.size())
	print("Shared Mend handwork checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
