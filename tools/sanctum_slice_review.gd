extends SceneTree
## Rendered verification of the authored slice, with a controlled lightmap A/B.

func _initialize() -> void:
	call_deferred("run")

func count_bodies(node: Node) -> int:
	var result := 1 if node is PhysicsBody3D else 0
	for child in node.get_children():
		result += count_bodies(child)
	return result

func capture(path: String) -> void:
	for frame in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Slice review requires a rendering display.")
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
	var art: Node = arena.get_node("CosmicSanctum")
	var slice: Node = art.get_node("QualitySlice/SanctumQualitySlice")
	var gi: LightmapGI = slice.get_node("BakedSanctumLight")
	var bodies := count_bodies(arena)
	var art_bodies := count_bodies(art)
	var architecture := {"Cover":0,"Floor":0,"Perimeter":0,"Terrace":0}
	for child in slice.get_children():
		for kind in architecture:
			if str(child.name).begins_with(kind + "_"):
				architecture[kind] += 1
	print("Authored arena sections: ",architecture)
	if architecture != {"Cover":4,"Floor":9,"Perimeter":12,"Terrace":2}:
		push_error("The full arena is missing an authored section.")
		quit(1)
		return
	print("Slice verification: world physics bodies=", bodies, " art bodies=",art_bodies)
	if bodies != 19 or art_bodies != 0 or slice.has_node("BakeLights"):
		push_error("Slice changed physics or retained duplicate baking lights.")
		quit(1)
		return
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(-0.1,5.8,13.6)
	camera.fov = 58
	camera.look_at(Vector3(-7.0,1.5,5.1))
	camera.current = true
	await capture("res://artifacts/sanctum-slice.png")
	var data := gi.light_data
	if data != null:
		print("Lightmap assignments=", data.get_user_count(), " atlases=",data.lightmap_textures.size())
		gi.light_data = null
		await capture("res://artifacts/sanctum-slice-unbaked.png")
		gi.light_data = data
	else:
		push_warning("Production lightmap is not assigned yet.")
	arena.mode = 3
	arena.roster = {1:{"champion":"Luminary","team":0}}
	arena.begin_round()
	arena.phase = "match"
	arena.camera.current = true
	arena.ui.hide()
	arena.update_visuals(0.0)
	await capture("res://artifacts/sanctum-slice-gameplay.png")
	print("Slice review complete; full-match draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
