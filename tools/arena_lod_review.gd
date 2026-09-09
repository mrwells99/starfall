extends SceneTree
## Same-camera render-work/visual comparison. --timing adds warmed GPU samples
## in ABBA order; it is not a full-match benchmark. --trial reads generated trials.
## --shader-before=/absolute/path isolates shader changes with arena LODs disabled.
var reports := []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Arena LOD review requires a rendered window")
		quit(1)
		return
	var game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.mode = 3
	game.roster = {1:{"champion":"Ember", "team":0},2:{"champion":"Vanguard", "team":0},3:{"champion":"Luminary", "team":0},4:{"champion":"Fulcrum", "team":1},5:{"champion":"Vanguard", "team":1},6:{"champion":"Luminary", "team":1}}
	game.begin_round()
	game.set_physics_process(false)
	game.set_process(false)
	game.ui.hide()
	Engine.max_fps = 60
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	root.mesh_lod_threshold = 1.0
	root.scaling_3d_scale = 1.0
	preload("res://scripts/sanctum_graphics.gd").apply_profile(game, "Balanced")
	var replacements := []
	var cache := {}
	for node in game.find_children("*", "MeshInstance3D", true, false):
		var path: String = node.mesh.resource_path if node.mesh != null else ""
		if not path.begins_with("res://assets/environment/slice/meshes/"): continue
		if not cache.has(path):
			var optimized: ArrayMesh = node.mesh
			if OS.get_cmdline_user_args().has("--trial"):
				optimized = load(path.replace("res://assets/environment/slice/meshes/", "res://artifacts/arena_lod_trial/"))
			optimized.shadow_mesh = null
			var original := optimized.duplicate() as ArrayMesh
			var surfaces: Array = original.get("_surfaces").duplicate(true)
			for surface in surfaces: surface.erase("lods")
			original.set("_surfaces", surfaces)
			original.shadow_mesh = null
			cache[path] = [original, optimized]
		replacements.append([node, cache[path]])
	var stone := load("res://shaders/sanctum_corner_stone.gdshader") as Shader
	var optimized_code := stone.code
	var baseline_shader := ""
	for flag in OS.get_cmdline_user_args():
		if flag.begins_with("--shader-before="): baseline_shader = flag.trim_prefix("--shader-before=")
	assert(baseline_shader.is_empty() or FileAccess.file_exists(baseline_shader), "Baseline shader must exist")
	var original_code := FileAccess.get_file_as_string(baseline_shader) if not baseline_shader.is_empty() else optimized_code
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.make_current()
	for view in [["gameplay", Vector3(0, 5, 18), Vector3(0,1,0)], ["close", Vector3(-5,3,9), Vector3(-6,1,5)], ["overview", Vector3(24,23,30), Vector3.ZERO]]:
		camera.position = view[1]
		camera.look_at(view[2])
		for variant in ([0, 1, 1, 0] if OS.get_cmdline_user_args().has("--timing") else [0, 1]):
			if not baseline_shader.is_empty():
				stone.code = original_code if variant == 0 else optimized_code
			for item in replacements:
				item[0].mesh = item[1][0 if not baseline_shader.is_empty() else variant]
				item[0].lod_bias = 1.0 if variant == 0 else 0.5
			for i in range(90 if OS.get_cmdline_user_args().has("--timing") else 15): await process_frame
			var gpu_samples: Array[float] = []
			if OS.get_cmdline_user_args().has("--timing"):
				for i in range(120):
					await process_frame
					gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			await RenderingServer.frame_post_draw
			var title: String = view[0] + ("-before" if variant == 0 else "-after")
			root.get_texture().get_image().save_png("res://artifacts/arena-lod-" + title + ".png")
			var report := {"view":title,"resolution":[root.size.x,root.size.y],"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			if not gpu_samples.is_empty():
				gpu_samples.sort()
				var total := 0.0
				for value in gpu_samples: total += value
				report["gpu_mean_ms"] = total / gpu_samples.size()
				report["gpu_p95_ms"] = gpu_samples[int(gpu_samples.size() * 0.95)]
			reports.append(report)
			print("ARENA LOD REVIEW ", JSON.stringify(report))
	var file := FileAccess.open("res://artifacts/arena-lod-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports, "\t"))
	quit()
