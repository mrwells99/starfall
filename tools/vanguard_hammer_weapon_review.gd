extends SceneTree

# Stage 1 review: load the standalone hammer weapon inside the real arena so
# it inherits Sanctum lighting, freeze gameplay, and render several close and
# medium-distance angles for owner sign-off. No gameplay state is mutated; the
# arena runs a single frame to build its lighting environment then physics /
# process are paused.

var triangle_count := 0
var mesh_count := 0

func _initialize() -> void:
	call_deferred("run")

func style(node: Node) -> void:
	if node is CollisionObject3D:
		push_error("Static review asset must not contain collision")
		quit(1)
	if node is MeshInstance3D:
		mesh_count += 1
		for i in node.mesh.get_surface_count():
			var original: Material = node.mesh.surface_get_material(i)
			var arrays: Array = node.mesh.surface_get_arrays(i)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices != null:
				triangle_count += indices.size() / 3
			else:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangle_count += verts.size() / 3
			if original == null: continue
			var title := original.resource_name
			if "VioletCrystal" in title:
				var mat := ShaderMaterial.new()
				mat.shader = load("res://shaders/vanguard_crystal.gdshader")
				# Large internal facets, brighter emission to punch past the
				# 1.35 bloom threshold from inside the metal housing.
				mat.set_shader_parameter("cell_scale", 3.5)
				mat.set_shader_parameter("emission_boost", 2.6)
				mat.set_shader_parameter("fissure_softness", 0.11)
				node.set_surface_override_material(i, mat)
			elif "ForgedSteel" in title or "WornEdges" in title or "OldTitanium" in title:
				var mat := ShaderMaterial.new()
				mat.shader = load("res://shaders/vanguard_forged.gdshader")
				mat.set_shader_parameter("base_color", original.albedo_color)
				# Lower noise frequency so close-range renders don't
				# pixelate; keep authored bevels doing the reading work.
				mat.set_shader_parameter("pit_frequency", 42.0)
				mat.set_shader_parameter("mottle_frequency", 12.0)
				mat.set_shader_parameter("wear_strength", 0.6)
				node.set_surface_override_material(i, mat)
	for child in node.get_children(): style(child)

func capture(filename: String) -> void:
	for i in 14: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/vanguard/" + filename + ".png")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This review requires a real display (use xvfb-run).")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1400, 1000))
	root.size = Vector2i(1400, 1000)

	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	if arena.has_method("get") and arena.get("ui") != null:
		arena.ui.hide()

	# Give the arena a frame or two to build its environment/lighting before
	# the hammer is added; otherwise Compatibility renders a black scene.
	for _i in 4: await process_frame

	var packed: PackedScene = load("res://assets/characters/vanguard_hammer_weapon.glb")
	var hammer := packed.instantiate()
	arena.add_child(hammer)
	# Author-side Blender has the head at Z=0 and haft trailing down.  Present
	# the weapon in a "held" pose: rotated so the striking face reads towards
	# the camera, and lifted so the head sits near chest height.
	# Cameras stay at a fixed observing station; the hammer yaws so each face
	# of interest ends up pointing at the camera. This avoids fighting the
	# glTF Y-up axis remap.
	hammer.position = Vector3(0.0, 2.10, 0.0)
	style(hammer)
	print("Hammer weapon mesh_instances=", mesh_count, " triangles=", triangle_count)

	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.fov = 32
	camera.current = true

	var observe := Vector3(0.0, 2.10, -3.4)
	var target := Vector3(0.0, 1.35, 0.0)

	# Striking face straight on: rotate hammer so +X face (Blender) points to
	# Godot -Z (toward camera). Empirically that is yaw = -PI/2.
	hammer.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	camera.position = observe
	camera.look_at(target)
	await capture("hammer-weapon-close-face")

	# Three-quarter hero shot: 30 deg yaw off the straight-on rotation so
	# both a striking face and a side window read together.
	hammer.rotation = Vector3(0.0, -PI * 0.5 + deg_to_rad(30.0), 0.0)
	camera.position = Vector3(-1.6, 2.35, -3.0)
	camera.look_at(Vector3(0.0, 1.20, 0.0))
	await capture("hammer-weapon-three-quarter")

	# Side window straight on: +Y (Blender) face toward camera.
	hammer.rotation = Vector3(0.0, 0.0, 0.0)
	camera.position = observe
	camera.look_at(target)
	await capture("hammer-weapon-side")

	# Opposite striking face.
	hammer.rotation = Vector3(0.0, PI * 0.5, 0.0)
	camera.position = observe
	camera.look_at(target)
	await capture("hammer-weapon-back-face")

	# Wide gameplay-distance view within the arena at three-quarter.
	hammer.rotation = Vector3(0.0, -PI * 0.5 + deg_to_rad(30.0), 0.0)
	camera.position = Vector3(3.8, 2.6, -5.2)
	camera.fov = 50
	camera.look_at(Vector3(0.0, 1.10, 0.0))
	await capture("hammer-weapon-gameplay")

	# Top-down: crystal spike + capstone shaping visible.
	hammer.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	camera.position = Vector3(0.5, 4.1, -0.8)
	camera.fov = 38
	camera.look_at(Vector3(0.0, 2.0, 0.0))
	await capture("hammer-weapon-top")

	quit()
