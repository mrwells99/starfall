extends SceneTree
const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
var checks := 0
var failures := 0
var maximum_error := 0.0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var manifests: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hitboxes/manifest.json"))
	for title in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw"]:
		var visible = load("res://scripts/combatant.gd").new(); root.add_child(visible); visible.setup(1,1,0,title)
		var server = load("res://scripts/combatant.gd").new(); root.add_child(server); server.setup(2,2,1,title,false)
		visible.setup_hitboxes(); server.setup_hitboxes()
		check(server.champion_model == null and server.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),title+" server rig has no render meshes")
		check(visible.body_hitboxes.radii.size() == 19,title+" has exactly 19 main-body volumes")
		check(FileAccess.get_sha256("res://assets/characters/"+title.to_lower()+".glb") == manifests.classes[title].source_sha256,title+" rig extraction matches the current model")
		check(FileAccess.get_sha256("res://assets/hitboxes/"+title.to_lower()+"_rig.scn") == manifests.classes[title].rig_sha256,title+" rig integrity is verified")
		var v_art = visible.champion_model.get(title.to_lower()+"_art")
		var s_art = server.hitbox_pose.art
		for state in ["idle","forward","left","backpedal","diagonal","jump","landing","cast","recover","slow_forward","slow_left","roll","roll_recovery","roll_run","backflip"]:
			if title != "Outlaw" and state in ["roll","roll_recovery","roll_run","backflip"]: continue
			var error := 0.0
			for frame in 48:
				var t := frame/60.0
				for actor in [visible,server]:
					var direction: Vector3 = {"forward":Vector3.FORWARD,"left":Vector3.LEFT,"backpedal":Vector3.BACK,"diagonal":Vector3(1,0,-1).normalized()}.get(state,Vector3.ZERO)
					actor.identity.severe_slow = 6.0 if state.begins_with("slow_") else 0.0
					if state == "slow_forward": direction = Vector3.FORWARD * .4
					if state == "slow_left": direction = Vector3.LEFT * .4
					if state=="roll_run" and t>=Outlaw.ROLL_SECONDS: direction=Vector3.FORWARD
					actor.position += direction*(3.8 if state == "backpedal" else 6.5)/60.0
					actor.presentation_grounded = state not in ["jump","backflip"]
					actor.velocity.y = 7-20*t if state == "jump" else (12-20*t if state == "backflip" else 0)
					actor.presentation_vertical_speed = actor.velocity.y
					actor.casting = 0 if state == "cast" else -1
					actor.cast_left = maxf(.01,1.5-t) if state == "cast" else 0
					if title == "Outlaw":
						actor.identity.roll_left = maxf(0,Outlaw.ROLL_SECONDS-t) if state in ["roll","roll_run"] else 0
						actor.identity.roll_animation_left = maxf(0,Outlaw.ROLL_PRESENTATION_SECONDS-t-(Outlaw.ROLL_SECONDS if state=="roll_recovery" else 0)) if state in ["roll","roll_recovery","roll_run"] else 0
						actor.identity.outlaw_action = "roll" if state in ["roll","roll_recovery","roll_run"] else ""
						actor.identity.roll_direction = Vector3.RIGHT
						actor.identity.backflip_active = state == "backflip"
						actor.identity.backflip_elapsed = t
				visible.champion_model.animate(1.0/60,visible); visible.body_hitboxes.update()
				server.update_hitboxes(1.0/60)
				for i in visible.body_hitboxes.points.size(): error = maxf(error,visible.body_hitboxes.points[i].distance_to(server.body_hitboxes.points[i]))
			maximum_error = maxf(maximum_error,error)
			check(error < .0005,title+" "+state+" server/visible hitbox error under 0.5 mm; measured "+str(error))
			if state.begins_with("slow_"):
				check(v_art.clip.begins_with("Walk") or v_art.clip.begins_with("Strafe"),title+" uses a walking gait during Severe's slow")
		if title == "Vanguard":
			v_art.strike(); s_art.strike()
			for frame in 30:
				visible.champion_model.animate(1.0/60,visible); visible.body_hitboxes.update(); server.update_hitboxes(1.0/60)
				check(visible.body_hitboxes.points[12].distance_to(server.body_hitboxes.points[12]) < .0005,"Vanguard striking arm matches the shared weapon grip solve")
		visible.free(); server.free()
	print("Maximum body endpoint difference: ",maximum_error," meters")
	print("Hitbox pose checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
