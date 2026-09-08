extends SceneTree
## Verify non-playable landscape bounds, render both teams and low island view.

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	root.size = Vector2i(1600,1000)
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.ui.hide()
	var sky: Node3D = arena.get_node("CosmicSanctum/CelestialBackdrop")
	var landscape: Node3D = sky.get_node("SanctumLandscape")
	var vertices := 0
	var triangles := 0
	for child in landscape.get_children():
		if not child is MeshInstance3D:
			push_error("Landscape must contain only non-colliding mesh batches.")
			quit(1)
			return
		if child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			push_error("Distant landscape must not add shadow passes.")
			quit(1)
			return
		for surface in range(child.mesh.get_surface_count()):
			var arrays: Array = child.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			vertices += points.size()
			triangles += points.size()/3
			for point in points:
				var p: Vector3 = child.global_transform*point
				if absf(p.x)<18.0 and absf(p.z)<18.0 and p.y>-.5:
					push_error("Landscape enters playable airspace.")
					quit(1)
					return
	var env: Environment = sky.get_node("CosmicEnvironment").environment
	if not env.glow_enabled or not is_equal_approx(env.glow_hdr_threshold,1.35):
		push_error("Emissive bloom settings changed unexpectedly.")
		quit(1)
		return
	print("Landscape verified: ",landscape.get_child_count()," batches, ",triangles," triangles, ",vertices," vertices; no playable airspace intrusion.")
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	camera.fov = 64
	camera.position = Vector3(45,8,53)
	camera.look_at(Vector3(0,-6,-5))
	await capture("res://artifacts/sanctum-landscape.png")
	for side in [-1.0,1.0]:
		camera.position = Vector3(0,5.8,side*16)
		camera.look_at(Vector3(0,2,-side*5))
		await capture("res://artifacts/sanctum-lanes-%s.png" % ("north" if side<0 else "south"))
	print("Landscape review complete.")
	quit()
