extends SceneTree
## Reproducible map review at a hero angle and the actual player camera.

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Arena review needs a rendering window.")
		quit(1)
		return
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	root.size = Vector2i(1600, 1000)
	arena.set_physics_process(false)
	arena.set_process(false)
	arena.ui.hide()
	var overview := Camera3D.new()
	arena.add_child(overview)
	overview.position = Vector3(39, 29, 44)
	overview.fov = 62
	overview.look_at(Vector3(0, 1.5, -2))
	overview.current = true
	await capture("res://artifacts/sanctum-overview.png")
	overview.position = Vector3(23, 13, 27)
	overview.look_at(Vector3(-2, 2, -9))
	await capture("res://artifacts/sanctum-detail.png")
	arena.mode = 3
	arena.roster = {1: {"champion": "Luminary", "team": 0}}
	arena.begin_round()
	arena.phase = "match"
	arena.camera.current = true
	arena.ui.show()
	arena.update_visuals(0.0)
	await capture("res://artifacts/sanctum-gameplay.png")
	print("Arena review captured: overview, detail, gameplay")
	quit()
