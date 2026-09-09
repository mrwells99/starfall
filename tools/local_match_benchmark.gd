extends SceneTree
## Rendered frame-pacing check; default six-player local match, --bench-duel for two.
## godot --path . --script tools/local_match_benchmark.gd
## Keeps HP full to retain all fighters; short sample, not a capacity guarantee.
## --bench-high / --bench-performance select effects; otherwise Balanced.
## Verify host idleness before interpreting results. Reports actual resolution/cap.
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
	if OS.get_cmdline_user_args().has("--bench-no-arena-lods"):
		var seen := {}
		for node in game.find_children("*", "MeshInstance3D", true, false):
			if node.mesh == null or not node.mesh.resource_path.begins_with("res://assets/environment/slice/meshes/"): continue
			if not seen.has(node.mesh):
				seen[node.mesh] = true
				var surfaces: Array = node.mesh.get("_surfaces").duplicate(true)
				for surface in surfaces: surface.erase("lods")
				node.mesh.set("_surfaces", surfaces)
	for flag in OS.get_cmdline_user_args():
		if flag.begins_with("--bench-shader-before="):
			assert(FileAccess.file_exists(flag.trim_prefix("--bench-shader-before=")), "Baseline shader must exist")
			var shader := load("res://shaders/sanctum_corner_stone.gdshader") as Shader
			shader.code = FileAccess.get_file_as_string(flag.trim_prefix("--bench-shader-before="))
	game.local_match()
	game.phase = "match"
	# Let deferred player preferences settle, then choose the explicit test profile.
	await process_frame
	await process_frame
	var flags := OS.get_cmdline_user_args()
	var preset := "High" if flags.has("--bench-high") else ("Performance" if flags.has("--bench-performance") else "Balanced")
	game.config.set_value("graphics", "frame_limit", 60)
	preload("res://scripts/sanctum_graphics.gd").apply_profile(game, preset)
	root.scaling_3d_scale = 1.0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for tick in range(420):
		for actor in game.actors.values():
			actor.hp = 100
		await physics_frame
		if tick == 60:
			measuring = true
	measuring = false
	print("LOCAL BENCH actors=%d renderer=%s preset=%s resolution=%s scale=%.2f effective_cap=%d focused=%s" % [game.actors.size(), RenderingServer.get_current_rendering_method(), preset, root.size, root.scaling_3d_scale, Engine.max_fps, game.application_focused])
	report("frame", frame_times)
	report("gpu", gpu_times)
	game.queue_free()
	await process_frame
	await process_frame
	quit()

func report(label: String, values: Array[float]) -> void:
	if values.is_empty():
		return
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print("LOCAL BENCH %s mean_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [label, total / values.size(), values[int(values.size() * 0.95)], values[-1]])
