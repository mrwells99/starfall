extends SceneTree
## Rendered frame-pacing check; default six-player local match, --bench-duel for two.
## godot --path . --script tools/local_match_benchmark.gd
## Keeps HP full to retain all fighters; short sample, not a capacity guarantee.
var measuring := false
var frame_times: Array[float] = []
var gpu_times: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func _process(delta: float) -> bool:
	if measuring:
		frame_times.append(delta * 1000.0)
		gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	return false

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Local match benchmark requires a rendering window")
		quit(1)
		return
	seed(12345)
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	game.mode_choice.select(0 if OS.get_cmdline_user_args().has("--bench-duel") else 1)
	game.local_match()
	game.phase = "match"
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for tick in range(420):
		for actor in game.actors.values():
			actor.hp = 100
		await physics_frame
		if tick == 60:
			measuring = true
	measuring = false
	print("LOCAL BENCH actors=%d renderer=%s target_fps=60" % [game.actors.size(), RenderingServer.get_current_rendering_method()])
	report("frame", frame_times)
	report("gpu", gpu_times)
	quit()

func report(label: String, values: Array[float]) -> void:
	if values.is_empty():
		return
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print("LOCAL BENCH %s mean_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [label, total / values.size(), values[int(values.size() * 0.95)], values[-1]])
