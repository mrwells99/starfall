extends SceneTree

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var initial_cap := Engine.max_fps
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	check(arena.dedicated and arena.network, "Start with --dedicated and a free UDP port")
	check(Engine.max_fps == Engine.physics_ticks_per_second, "Server frame loop is bounded at physics frequency")
	check(Engine.physics_ticks_per_second == 60, "Combat remains at 60 Hz")
	arena.mode = 3
	arena.begin_round()
	for actor in arena.actors.values():
		check(actor.champion_model == null, "Server actor has no presentation model")
		check(actor.get_child_count() == 1 and actor.get_child(0) is CollisionShape3D, "Collision capsule retained without visual children")
	for champion in ["ember", "vanguard", "luminary", "fulcrum"]:
		check(not ResourceLoader.has_cached("res://assets/characters/%s.glb" % champion), "Server does not load authored model: " + champion)
	var before := get_node_count()
	arena.combat_event(-1, arena.actors.keys()[0], "TEST", Color.WHITE)
	arena.update_visuals(0.016)
	check(get_node_count() == before, "Server event and HUD refresh allocate no visual nodes")
	for i in range(120):
		await physics_frame
	for actor in arena.actors.values():
		check(actor.position.y > -1, "Simulated actor remains on arena collision")
	arena.leave_session("")
	check(Engine.max_fps == initial_cap, "Leaving dedicated mode restores previous frame cap")
	print("Server runtime checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
