extends SceneTree
## Native rendered 3v3: record bot inputs, then replay the same calls and movement.
## -- --capture=res://artifacts/frame-capture/run-name --seconds=40
## Optional diagnostic controls: --no-combat-events --no-hit-flash --preset=High
var game
var output := "res://artifacts/frame-capture/default"
var seconds := 40
var frames: Array = []
var previous_us := 0
var previous_round := -1
var ready_to_capture := false
var metadata: Dictionary = {}

func _initialize() -> void:
	for flag in OS.get_cmdline_user_args():
		if flag.begins_with("--capture="): output = flag.trim_prefix("--capture=")
		if flag.begins_with("--seconds="): seconds = int(flag.trim_prefix("--seconds="))
	call_deferred("run")

func frame_complete() -> void:
	var now := Time.get_ticks_usec()
	if ready_to_capture and previous_us > 0:
		var viewport := root.get_viewport_rid()
		frames.append([Engine.get_process_frames(), now, now - previous_us, game.bench_round, game.bench_tick,
			game.bench_physics_us, game.bench_visual_us, game.bench_tick_count,
			RenderingServer.viewport_get_measured_render_time_cpu(viewport), RenderingServer.viewport_get_measured_render_time_gpu(viewport),
			RenderingServer.get_frame_setup_time_cpu(), Engine.max_fps, int(game.application_focused),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			int(previous_round != game.bench_round), Engine.get_frames_per_second()])
	if game != null:
		game.bench_physics_us = 0
		game.bench_visual_us = 0
		game.bench_tick_count = 0
		previous_round = game.bench_round
	previous_us = now

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Frame capture requires a real rendering window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	seed(20260909)
	var loaded := Time.get_ticks_usec()
	game = load("res://arena.tscn").instantiate()
	game.set_script(load("res://tools/frame_time_arena.gd"))
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(frame_complete)
	await process_frame
	await process_frame
	var flags := OS.get_cmdline_user_args()
	var preset: String = game.config.graphics_preset()
	for flag in flags:
		if flag.begins_with("--preset="): preset = flag.trim_prefix("--preset=")
	game.config.set_value("graphics", "frame_limit", 60)
	preload("res://scripts/sanctum_graphics.gd").apply_profile(game, preset)
	root.scaling_3d_scale = 1.0
	game.bench_suppress_events = flags.has("--no-combat-events")
	game.bench_suppress_flash = flags.has("--no-hit-flash")
	game.bench_suppress_beams = flags.has("--no-beams")
	game.bench_suppress_strikes = flags.has("--no-strike-vfx")
	game.bench_profile_strikes = flags.has("--profile-strike-vfx")
	game.bench_retain_strike_material = flags.has("--retain-strike-material")
	game.bench_pause_unfocused = flags.has("--pause-unfocused")
	game.fps_toggle.button_pressed = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	DisplayServer.window_move_to_foreground()
	await create_timer(2).timeout
	metadata = {"game_version": game.Config.VERSION, "godot": Engine.get_version_info(), "cpu": OS.get_processor_name(),
		"logical_processors": OS.get_processor_count(), "renderer": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(), "window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"viewport_size": [root.size.x, root.size.y], "window_mode": DisplayServer.window_get_mode(), "refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"scale_3d": root.scaling_3d_scale, "preset": preset, "requested_cap": 60, "vsync": DisplayServer.window_get_vsync_mode(),
		"seconds_per_round": seconds, "seed": 20260909, "startup_us": Time.get_ticks_usec() - loaded,
		"timestamp": Time.get_datetime_string_from_system(), "arguments": flags, "measurement": "monotonic frame_post_draw CPU wall intervals; not display-present latency",
		"limits": "GPU timings are asynchronous; input replay skips second-round AI decision work; existing driver and project shader caches retained; lethal damage clamped to leave six actors alive"}
	ready_to_capture = true
	for round_index in [1, 2]:
		game.bench_round = 0
		game.bench_active = false
		seed(20260909)
		game.mode = 3
		game.roster = {1: {"champion": "Fulcrum", "team": 0}, 2: {"champion": "Ember", "team": 0},
			3: {"champion": "Luminary", "team": 0}, 4: {"champion": "Vanguard", "team": 1},
			5: {"champion": "Ember", "team": 1}, 6: {"champion": "Luminary", "team": 1}}
		var start := Time.get_ticks_usec()
		game.begin_round()
		if flags.has("--stable-vanguard-emission"):
			for fighter in game.actors.values():
				if fighter.champion != "Vanguard": continue
				var art = fighter.champion_model.vanguard_art
				for index in art.materials.size():
					if not art.base_emission_enabled[index]:
						art.base_emission_enabled[index] = true
						art.base_emission_energy[index] = 0.0
						art.materials[index].emission_enabled = true
						art.materials[index].emission_energy_multiplier = 0.0
		game.trace_event("round_load", "Round %d actor instantiation" % round_index, -1, -1, start)
		game.countdown = 10000.0
		for fighter in game.actors.values(): fighter.owner_peer = 0
		game.local_id = 1
		game.selected_id = 4
		for i in 6: await physics_frame
		game.phase = "match"
		game.bench_tick = 0
		game.bench_round = round_index
		game.bench_replay = round_index == 2
		game.bench_active = true
		game.trace_event("round_start", "3v3 %s" % ("record" if round_index == 1 else "input replay"), -1, -1, Time.get_ticks_usec())
		print("CAPTURE round=%d renderer=%s resolution=%s preset=%s" % [round_index, metadata.renderer, root.size, preset])
		while game.bench_tick < seconds * Engine.physics_ticks_per_second:
			if game.bench_tick % 60 == 0:
				DisplayServer.window_set_title("Starfall benchmark — round %d/2 — %d/%d seconds" % [round_index, game.bench_tick / 60, seconds])
			await physics_frame
		game.bench_active = false
		game.phase = "countdown"
		game.countdown = 10000.0
		await RenderingServer.frame_post_draw
		game.trace_event("round_end", "Round %d" % round_index, -1, -1, Time.get_ticks_usec())
		game.bench_round = 0
		await create_timer(1.3).timeout
	ready_to_capture = false
	var screen := root.get_texture().get_image()
	if screen.get_width() > 1280: screen.resize(1280, roundi(screen.get_height() * 1280.0 / screen.get_width()))
	screen.save_png(output + "/capture.png")
	var file := FileAccess.open(output + "/frames.csv", FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["frame", "end_us", "wall_us", "round", "physics_tick", "physics_cpu_us", "visual_cpu_us", "physics_steps", "render_cpu_ms", "gpu_ms", "render_setup_ms", "effective_cap", "focused", "pipeline_canvas", "pipeline_mesh", "pipeline_surface", "pipeline_draw", "pipeline_specialization", "draw_calls", "primitives", "round_boundary", "fps_display"]))
	for row in frames:
		var cells := PackedStringArray()
		for value in row: cells.append(str(value))
		file.store_csv_line(cells)
	file.close()
	FileAccess.open(output + "/events.json", FileAccess.WRITE).store_string(JSON.stringify(game.bench_events))
	FileAccess.open(output + "/metadata.json", FileAccess.WRITE).store_string(JSON.stringify(metadata, "\t"))
	FileAccess.open(output + "/inputs.bin", FileAccess.WRITE).store_var(game.bench_tape)
	print("CAPTURE COMPLETE frames=%d events=%d output=%s" % [frames.size(), game.bench_events.size(), output])
	quit()
