extends SceneTree
## Real rendered benchmark; --headless is intentionally rejected (dummy renderer).
## Run with --rendering-method forward_plus -- --expect=forward_plus.
## --minimal uses a tiny built-in scene to isolate renderer startup from arena art.
## JSON and PNG are written under --output=/absolute/path (default /tmp/starfall-renderer-probe).
## This probe cannot establish host idleness. Record other processes/device load
## before performance use; concurrent editor/game activity invalidates rankings.

var expected := ""
var output := "/tmp/starfall-renderer-probe"
var minimal := false
var combat := false
var duration_seconds := 0.0
var warmup_frames := 12
var sample_frames := 36

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expect="):
			expected = arg.trim_prefix("--expect=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--minimal":
			minimal = true
		elif arg == "--combat":
			combat = true
		elif arg.begins_with("--duration="):
			duration_seconds = maxf(0.0, float(arg.trim_prefix("--duration=")))
		elif arg.begins_with("--warmup="):
			warmup_frames = maxi(1, int(arg.trim_prefix("--warmup=")))
		elif arg.begins_with("--samples="):
			sample_frames = maxi(2, int(arg.trim_prefix("--samples=")))
	call_deferred("run")

func run() -> void:
	seed(591037)
	if DisplayServer.get_name() == "headless":
		push_error("Renderer probe requires a real display; headless uses the dummy driver.")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 800)
	Engine.max_fps = 0
	var scene: Node3D
	if minimal:
		scene = Node3D.new()
		root.add_child(scene)
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		scene.add_child(mesh)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50, -25, 0)
		scene.add_child(light)
	else:
		scene = load("res://arena.tscn").instantiate()
		root.add_child(scene)
		scene.set_process(false)
		scene.set_physics_process(combat)
		if combat:
			scene.set("mode", 3)
			scene.set("roster", {
				1: {"champion": "Fulcrum", "team": 0},
				2: {"champion": "Vanguard", "team": 0},
				3: {"champion": "Luminary", "team": 0},
				4: {"champion": "Ember", "team": 1},
				5: {"champion": "Vanguard", "team": 1},
				6: {"champion": "Luminary", "team": 1},
			})
			scene.call("begin_round")
			for actor in scene.get("actors").values():
				actor.owner_peer = 0
			scene.set("phase", "match")
		else:
			scene.get("ui").hide()
	var camera := Camera3D.new()
	scene.add_child(camera)
	if minimal:
		camera.position = Vector3(3, 2, 4)
		camera.look_at(Vector3.ZERO)
	else:
		camera.position = Vector3(-0.1, 5.8, 13.6)
		camera.fov = 58
		camera.look_at(Vector3(-7, 1.5, 5.1))
	camera.current = not combat
	# Player preferences are loaded by a deferred callback. Let that settle,
	# then impose the probe resolution instead of reporting a requested size
	# that the compositor or saved fullscreen preference actually overrode.
	await process_frame
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 800)
	for frame in range(warmup_frames):
		await process_frame
		await RenderingServer.frame_post_draw
	var times: Array[float] = []
	var process_ms_sum := 0.0
	var physics_ms_sum := 0.0
	var pipeline_monitors := {
		"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
		"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
		"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
		"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
		"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
	}
	var pipelines_before := {}
	for kind in pipeline_monitors:
		pipelines_before[kind] = Performance.get_monitor(pipeline_monitors[kind])
	var previous := Time.get_ticks_usec()
	var start_usec := previous
	var phase_start: String = scene.get("phase") if combat else "static"
	var alive_start := _alive_count(scene) if combat else 0
	while times.size() < sample_frames or float(Time.get_ticks_usec() - start_usec) / 1000000.0 < duration_seconds:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		process_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		previous = now
	var elapsed_ms: float = times.reduce(func(sum, value): return sum + value, 0.0)
	times.sort()
	var actual_samples := times.size()
	var pipelines_during := {}
	for kind in pipeline_monitors:
		pipelines_during[kind] = Performance.get_monitor(pipeline_monitors[kind]) - pipelines_before[kind]
	var renderer := RenderingServer.get_current_rendering_method()
	var capture := root.get_texture().get_image()
	var report := {
		"godot_version": Engine.get_version_info().string,
		"display": DisplayServer.get_name(),
		"renderer": renderer,
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"expected_renderer": expected,
		"expected_renderer_matched": expected.is_empty() or renderer == expected,
		"high_requested": OS.get_cmdline_user_args().has("--sanctum-high"),
		"original_map_requested": OS.get_cmdline_user_args().has("--sanctum-original"),
		"scene": "minimal" if minimal else ("six_bot_match_with_hud" if combat else "arena_corner"),
		"viewport": "%dx%d" % [capture.get_width(), capture.get_height()],
		"requested_viewport": "1280x800",
		"phase_start": phase_start,
		"phase_end": scene.get("phase") if combat else "static",
		"actors_alive_start": alive_start,
		"actors_alive_end": _alive_count(scene) if combat else 0,
		"warmup_frames": warmup_frames,
		"sample_frames": actual_samples,
		"sample_duration_seconds": elapsed_ms / 1000.0,
		"mean_frame_ms": elapsed_ms / float(actual_samples),
		"median_frame_ms": times[actual_samples / 2],
		"p95_frame_ms": times[mini(actual_samples - 1, int(ceil(actual_samples * 0.95)) - 1)],
		"p99_frame_ms": times[mini(actual_samples - 1, int(ceil(actual_samples * 0.99)) - 1)],
		"worst_frame_ms": times.back(),
		"frames_over_16_67ms_percent": 100.0 * times.filter(func(value): return value > 16.667).size() / actual_samples,
		"monitor_mean_process_ms": process_ms_sum / actual_samples,
		"monitor_mean_physics_ms": physics_ms_sum / actual_samples,
		"pipelines_compiled_during_samples": pipelines_during,
		"observed_fps": float(actual_samples) * 1000.0 / elapsed_ms,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"caveat": "Short render-loop observation, not isolated GPU timing or hardware certification. Host idleness is not established by this probe. Record concurrent process/device load before interpreting timings; software GPU results do not predict physical GPU performance."
	}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	capture.save_png(output.path_join("capture.png"))
	print("RENDERER_PROBE ", JSON.stringify(report))
	quit(0 if report.expected_renderer_matched else 3)

func _alive_count(scene: Node) -> int:
	var result := 0
	for actor in scene.get("actors").values():
		if actor.hp > 0:
			result += 1
	return result
