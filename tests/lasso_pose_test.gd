extends SceneTree
var checks := 0
var failures := 0
var maximum_error := 0.0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for title in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw"]:
		var visible = load("res://scripts/combatant.gd").new(); root.add_child(visible); visible.setup(1,1,0,title)
		var server = load("res://scripts/combatant.gd").new(); root.add_child(server); server.setup(2,2,1,title,false)
		visible.setup_hitboxes(); server.setup_hitboxes()
		check(server.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),title+" keeps a mesh-free server rig")
		for phase in ["down","idle","cast","pull","rebound","idle"]:
			if title != "Outlaw" and phase in ["cast","pull","rebound"]: continue
			var error := 0.0
			var finite := true
			for frame in 90:
				var progress := frame / 89.0
				for actor in [visible,server]:
					if phase == "cast": actor.position.x += .05
					actor.casting = 11 if phase=="cast" else -1
					actor.cast_left = .7*(1-progress)
					actor.presentation_grounded = phase in ["idle","down","cast"]
					actor.presentation_vertical_speed = 0
					actor.identity.lasso = {"phase":phase,"elapsed":progress*(.28 if phase=="rebound" else .5)} if phase in ["cast","pull","rebound"] else {}
					actor.stunned = 1.5*(1-progress) if phase=="down" else 0
					actor.identity.lasso_knockdown = {"source":"Lasso test","left":actor.stunned,"total":1.5} if phase=="down" else {}
					actor.cc_effects = {"stun":{"source":"Lasso test","remaining":actor.stunned}} if phase=="down" else {}
				visible.champion_model.animate(1.0/60,visible); visible.body_hitboxes.update()
				server.update_hitboxes(1.0/60)
				for i in visible.body_hitboxes.points.size():
					finite = finite and visible.body_hitboxes.points[i].is_finite()
					error = maxf(error,visible.body_hitboxes.points[i].distance_to(server.body_hitboxes.points[i]))
			maximum_error=maxf(maximum_error,error)
			check(finite,title+" "+phase+" has finite body points throughout the motion")
			if phase == "cast":
				var art = visible.champion_model.outlaw_art
				check(art.is_locomotion(art.clip), "Moving Lasso preserves a leg gait under the rope-swing arms")
			check(error<.0005,title+" "+phase+" visible/server pose matches within 0.5mm")
		visible.free(); server.free()
	print("Maximum Lasso body endpoint difference: ",maximum_error," meters")
	print("Lasso pose checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
