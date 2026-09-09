extends SceneTree
var game
var remaining := 8.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	seed(12345)
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	if not game.dedicated or not game.network:
		push_error("Benchmark requires --dedicated and a free UDP port")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--bench-team"):
		game.mode = 3
		game.roster = {}
		game.begin_round()
		game.phase = "match"
	print("BENCH READY actors=%d nodes=%d" % [game.actors.size(), get_node_count()])
func _process(delta: float) -> bool:
	if game == null: return false
	remaining -= delta
	# Keep the same six bodies active for the whole sample.
	for actor in game.actors.values(): actor.hp = 100
	if remaining <= 0:
		print("BENCH DONE nodes=%d static_bytes=%d" % [get_node_count(), OS.get_static_memory_usage()])
		quit()
	return false
