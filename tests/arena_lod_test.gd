extends SceneTree
## Guard baked UVs/base geometry and the index buffers shipped to the renderer.
const LOD = preload("res://tools/arena_mesh_lods.gd")
const PREFIX := "res://assets/environment/slice/meshes/"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREFIX + "lod_manifest.json"))
	var scene = load("res://scenes/sanctum_quality_slice.tscn").instantiate()
	var paths := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if node.mesh.resource_path.begins_with(PREFIX):
			paths[node.mesh.resource_path.trim_prefix(PREFIX)] = true
	check(paths.size() == manifest.size(), "Manifest covers every unique authored arena mesh")
	var total_levels := 0
	for path in paths:
		check(manifest.has(path), "Mesh has provenance: " + path)
		if not manifest.has(path): continue
		var record: Dictionary = manifest[path]
		var mesh := load(PREFIX + path) as ArrayMesh
		check(LOD.base_digest(mesh) == record.base_sha256, "Packed base geometry/UVs unchanged: " + path)
		check(mesh.lightmap_size_hint == Vector2i(record.lightmap_hint[0], record.lightmap_hint[1]), "Lightmap sizing unchanged: " + path)
		check(mesh.shadow_mesh == null, "No incompatible position-only shadow mesh: " + path)
		var levels := 0
		for surface in mesh.get("_surfaces"):
			var lods: Array = surface.get("lods", [])
			check(lods.size() % 2 == 0, "LOD storage has distance/index pairs")
			for offset in range(0, lods.size(), 2):
				var bytes: PackedByteArray = lods[offset + 1]
				var width := 2 if surface.vertex_count <= 65536 else 4
				check(bytes.size() % (3 * width) == 0 and bytes.size() > 0, "LOD stores complete triangles")
				check(bytes.size() < surface.index_data.size(), "LOD reduces original triangle count")
				var valid := true
				for i in range(0, bytes.size(), width):
					var index := bytes.decode_u16(i) if width == 2 else bytes.decode_u32(i)
					valid = valid and index < surface.vertex_count
				check(valid, "LOD references existing vertices only")
				levels += 1
		check(levels == int(record.lod_count), "LOD levels survive serialization: " + path)
		total_levels += levels
	check(total_levels > 0, "Arena ships distance detail levels")
	scene.free()
	print("Arena LOD checks: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
