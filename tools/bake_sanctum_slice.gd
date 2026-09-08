@tool
extends EditorPlugin
## Editor-side helper for bake_sanctum_slice.py. Runs only in its temporary copy.
## Godot 4.5.1 does not expose LightmapGI.bake() to GDScript, so invoke the
## editor's native bake button after selecting the requested LightmapGI node.

var _scene_path: String
var _data_path: String
var _finished := false

func _enter_tree() -> void:
	_scene_path = OS.get_environment("SANCTUM_BAKE_SCENE")
	_data_path = OS.get_environment("SANCTUM_BAKE_DATA")
	if _scene_path.is_empty() or _data_path.is_empty():
		_fail("Missing SANCTUM_BAKE_SCENE or SANCTUM_BAKE_DATA.")
		return
	call_deferred("_run_bake")

func _run_bake() -> void:
	# Let the temporary project's initial resource imports and editor startup finish.
	await get_tree().create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	EditorInterface.open_scene_from_path(_scene_path)
	await get_tree().create_timer(2.0).timeout
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		_fail("Could not open bake scene: " + _scene_path)
		return
	var lightmap := _find_lightmap(scene)
	if lightmap == null:
		_fail("The bake scene needs a LightmapGI node.")
		return
	var meshes: Array[MeshInstance3D] = []
	_find_static_meshes(scene, meshes)
	if meshes.is_empty():
		_fail("No static meshes with UV2 were found.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_data_path.get_base_dir()))
	# The native baker reimports EXRs synchronously. Register a newly created
	# output directory first or the filesystem cannot see the generated atlas.
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	# A named data resource supplies the native bake destination without a dialog.
	# The temporary placeholder is overwritten by the actual bake below.
	var data := LightmapGIData.new()
	var placeholder := Texture2DArray.new()
	placeholder.create_from_images([Image.create(1, 1, false, Image.FORMAT_RGBH)])
	data.lightmap_textures = [placeholder]
	if ResourceSaver.save(data, _data_path) != OK:
		_fail("Could not create lightmap destination.")
		return
	lightmap.light_data = load(_data_path)
	EditorInterface.edit_node(lightmap)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lightmap)
	await get_tree().create_timer(1.0).timeout
	var button := _find_bake_button(EditorInterface.get_base_control())
	if button == null:
		_fail("Native Bake Lightmaps button not found; use an English Godot editor.")
		return
	print("SANCTUM_BAKE_START renderer=", RenderingServer.get_current_rendering_method(), " static_meshes=", meshes.size())
	var start := Time.get_ticks_msec()
	button.pressed.emit()
	# The native operation is synchronous. Imported resources finish after it returns.
	await get_tree().create_timer(2.0).timeout
	var result := lightmap.light_data
	if result == null or result.lightmap_textures.is_empty() or result.get_user_count() == 0:
		_fail("Native bake did not produce lightmaps and mesh assignments.")
		return
	var peak := 0.0
	var pixel_count := 0
	var total := 0.0
	for texture in result.lightmap_textures:
		for layer in texture.get_layers():
			var image := texture.get_layer_data(layer)
			if image == null:
				continue
			for y in image.get_height():
				for x in image.get_width():
					var color := image.get_pixel(x, y)
					var value := maxf(color.r, maxf(color.g, color.b))
					peak = maxf(peak, value)
					total += value
					pixel_count += 1
	if peak <= 0.0001 or pixel_count == 0:
		_fail("Native bake produced only black lightmap pixels.")
		return
	var save_error := EditorInterface.save_scene()
	if save_error != OK:
		_fail("Could not save the scene's lightmap assignment.")
		return
	var report := {
		"ok": true,
		"scene": _scene_path,
		"data": _data_path,
		"renderer": RenderingServer.get_current_rendering_method(),
		"mesh_assignments": result.get_user_count(),
		"texture_count": result.lightmap_textures.size(),
		"peak": peak,
		"mean_max_channel": total / pixel_count,
		"bake_seconds": (Time.get_ticks_msec() - start) / 1000.0,
	}
	_write_report(report)
	print("SANCTUM_BAKE_OK ", JSON.stringify(report))
	_finished = true
	get_tree().quit()

func _find_lightmap(node: Node) -> LightmapGI:
	if node is LightmapGI:
		return node
	for child in node.get_children():
		var found := _find_lightmap(child)
		if found != null:
			return found
	return null

func _find_static_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.gi_mode == GeometryInstance3D.GI_MODE_STATIC:
		var mesh: Mesh = node.mesh
		if mesh != null and mesh.get_surface_count() > 0:
			var valid := true
			for surface in mesh.get_surface_count():
				if not mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TEX_UV2:
					valid = false
			if valid:
				output.append(node)
	for child in node.get_children():
		_find_static_meshes(child, output)

func _find_bake_button(node: Node) -> Button:
	if node is Button and "Bake Lightmaps" in node.text:
		return node
	for child in node.get_children():
		var found := _find_bake_button(child)
		if found != null:
			return found
	return null

func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open("res://sanctum_bake_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))

func _fail(message: String) -> void:
	if _finished:
		return
	_finished = true
	push_error("SANCTUM_BAKE_FAILED: " + message)
	_write_report({"ok": false, "error": message})
	get_tree().quit(1)
