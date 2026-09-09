extends SceneTree
## GPU-rendered comparison and integration verification. Run with a real display.

const Graphics = preload("res://scripts/sanctum_graphics.gd")
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		errors += 1

func count_bodies(node: Node) -> int:
	var count := int(node is PhysicsBody3D)
	for child in node.get_children():
		count += count_bodies(child)
	return count

func capture(path: String) -> void:
	for frame in range(90):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Corner review needs a real display.")
		quit(2)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	if OS.get_cmdline_user_args().has("--viewer"):
		await review_viewer()
		return
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.ui.hide()
	var art: Node3D = arena.get_node("CosmicSanctum")
	var architecture: Node3D = art.get_node("QualitySlice/SanctumQualitySlice")
	var corner = art.get_node("QualitySlice/CornerUpgrade")
	check(count_bodies(arena) == 19, "Original 19 world collision bodies must remain.")
	check(count_bodies(art) == 0, "Corner art cannot create physics bodies.")
	check(corner.modified_surface_count() == 99, "All 27 modules must be upgraded, preserving the 16 original inlay surfaces.")
	check(architecture.get_node("BakedSanctumLight").light_data.get_user_count() == 115,
		"All existing baked-light assignments must remain intact.")
	check(corner.get_child_count() == 5, "Both boundary shrines, their lights and the arena reflection probe must load.")
	for index in range(4):
		var pillar := architecture.get_node("Cover_%d" % index)
		var inlay := pillar.get_node("Inlay_geometry") as MeshInstance3D
		check(inlay.visible and inlay.get_active_material(0).resource_name == "Slice_Inlay",
			"Original glowing artwork must remain visible on pillar %d." % index)
	for shrine in corner.get_children():
		if shrine.name in ["WestShrine", "EastShrine"]:
			for mesh in shrine.find_children("*", "MeshInstance3D", true, false):
				check(mesh.get_aabb().end.x < -17.65, "Shrine overlay must contain no pillar-covering geometry.")
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(-0.1,5.8,13.6)
	camera.look_at(Vector3(-7,1.5,5.1))
	camera.fov = 58
	camera.current = true
	var method := RenderingServer.get_current_rendering_method()
	var prefix := "res://artifacts/corner-" + method
	corner.set_enabled(false)
	Graphics.apply(arena, false)
	await capture(prefix + "-before.png")
	corner.set_enabled(true)
	await capture(prefix + "-materials.png")
	Graphics.apply(arena, true)
	await capture(prefix + "-after.png")
	camera.position = Vector3(-2.8,3.1,9.8)
	camera.look_at(Vector3(-6,2.0,5.8))
	await capture(prefix + "-stonework.png")
	camera.position = Vector3(-10,4.6,17)
	camera.look_at(Vector3(-17.7,2.5,12.5))
	await capture(prefix + "-shrine.png")
	camera.position = Vector3(27,23,31)
	camera.look_at(Vector3(-2,0,0))
	await capture(prefix + "-arena.png")
	print("CORNER_REVIEW renderer=", method, " errors=", errors,
		" modified_surfaces=", corner.modified_surface_count(), " world_bodies=", count_bodies(arena))
	quit(0 if errors == 0 else 1)

func review_viewer() -> void:
	var viewer = load("res://scenes/sanctum_corner_preview.tscn").instantiate()
	root.add_child(viewer)
	await capture("res://artifacts/corner-viewer.png")
	check(viewer.camera.current, "Preview camera must remain active after the arena initializes.")
	check(not viewer.arena.is_processing() and not viewer.arena.is_physics_processing(),
		"Preview must not simulate a match.")
	var camera_start: Vector3 = viewer.camera.position
	viewer._set_view(1)
	check(viewer.camera.position.distance_to(camera_start) > 1.0, "Detail view must reposition the camera.")
	viewer.corner.set_enabled(false)
	check(not viewer.corner.visible, "Before comparison must hide added art and local lights.")
	viewer.corner.set_enabled(true)
	viewer._high.button_pressed = false
	var world: WorldEnvironment = viewer.arena.find_child("CosmicEnvironment", true, false)
	check(not world.environment.ssao_enabled, "Base lighting comparison must turn High contact effects off.")
	print("CORNER_VIEWER errors=", errors)
	quit(0 if errors == 0 else 1)
