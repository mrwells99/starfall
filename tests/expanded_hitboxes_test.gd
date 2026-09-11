extends SceneTree
const Bodies = preload("res://scripts/body_hitboxes.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	for title in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw"]:
		var actor = load("res://scripts/combatant.gd").new(); root.add_child(actor); actor.setup(1,1,0,title,false)
		actor.position = Vector3(8,5,-3); actor.presentation_grounded = true
		for i in 24: actor.update_hitboxes(1.0/60)
		var body = actor.body_hitboxes
		for yaw in [0.0,PI*.5,PI*.25]:
			actor.rotation.y = yaw; actor.update_hitboxes(1.0/60)
			var native_head: Vector3 = (body.points[8]+body.points[9])*.5
			var enlarged_head: Vector3 = actor.position+(native_head-actor.position)*Bodies.AIM_SCALE
			# The enlarged head has 2x horizontal and 1.25x vertical radius.
			var origin: Vector3 = enlarged_head + Vector3(body.radii[4]*1.8,0,-4)
			check(Bodies.trace(origin,Vector3.BACK,8,body.points,body.radii).is_empty(),title+" original body misses the outer aiming margin")
			var hit := Bodies.trace_aim(origin,Vector3.BACK,8,body.points,body.radii,actor.position)
			check(not hit.is_empty() and hit.part=="head",title+" expanded aiming volume hits its wider head at each heading")
			check(not hit.is_empty() and is_equal_approx(hit.distance,origin.distance_to(hit.position)),"Expanded hit distance remains in world metres")
			origin = enlarged_head+Vector3(0,body.radii[4]*1.15,-4)
			check(not Bodies.trace_aim(origin,Vector3.BACK,8,body.points,body.radii,actor.position).is_empty(),title+" includes the 25-percent-taller aiming margin")
			origin = enlarged_head+Vector3(0,body.radii[4]*1.6,-4)
			check(Bodies.trace_aim(origin,Vector3.BACK,8,body.points,body.radii,actor.position).is_empty(),title+" rays beyond the expanded top still miss")
			origin = enlarged_head+Vector3(0,0,-4)
			check(Bodies.trace_aim(origin,Vector3.BACK,2,body.points,body.radii,actor.position).is_empty(),"A nearer wall/range limit still stops expanded-body hits")
		check(is_equal_approx(actor.get_child(0).shape.radius,.42) and is_equal_approx(actor.get_child(0).shape.height,1.8),title+" movement capsule is unchanged")
		check(actor.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),title+" enlarged aiming hitboxes need no extra server meshes")
		actor.free()
	print("Expanded hitbox checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
