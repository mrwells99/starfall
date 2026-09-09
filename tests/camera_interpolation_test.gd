extends SceneTree
var arena
var actor
func _initialize() -> void: call_deferred("run")
func _physics_process(delta: float) -> bool:
	if actor != null:
		arena.simulate_movement(actor, delta)
	return false
func run() -> void:
	Engine.physics_ticks_per_second = 10
	Engine.max_fps = 120
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.local_match()
	actor = arena.actors[arena.local_id]
	actor.position = Vector3(0, .05, 0)
	actor.rotation.y = 0
	actor.move_input = Vector2(1, 0)
	actor.reset_physics_interpolation()
	var between_ticks := 0
	var previous_tick := -1
	var previous := Vector3.ZERO
	for i in 100:
		await process_frame
		arena._process(0)
		var current: Vector3 = arena.pivot.global_position
		var tick := Engine.get_physics_frames()
		if tick == previous_tick and current.distance_to(previous) > .0001:
			between_ticks += 1
		previous_tick = tick
		previous = current
	if between_ticks < 10:
		push_error("Camera still steps only on physics ticks: %d intermediate frames" % between_ticks)
		quit(1)
	else:
		print("Camera interpolation PASS: %d render updates between physics ticks" % between_ticks)
		quit(0)
