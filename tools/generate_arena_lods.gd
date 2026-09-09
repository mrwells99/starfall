extends SceneTree
## Add LODs to existing runtime meshes without regenerating the map or light bake.
const LOD = preload("res://tools/arena_mesh_lods.gd")
const PREFIX := "res://assets/environment/slice/meshes/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/sanctum_quality_slice.tscn").instantiate()
	var seen := {}
	var manifest := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var source: ArrayMesh = node.mesh
		var path := source.resource_path
		if seen.has(path) or not path.begins_with(PREFIX): continue
		seen[path] = true
		var relative := path.trim_prefix(PREFIX)
		var backup := "res://artifacts/arena_lod_before/" + relative
		DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
		# Never overwrite the first baseline on subsequent regeneration.
		if not FileAccess.file_exists(backup):
			assert(DirAccess.copy_absolute(path, backup) == OK)
		var optimized := LOD.with_lods(source)
		var output := "res://artifacts/arena_lod_trial/" + relative
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		assert(ResourceSaver.save(optimized, output, ResourceSaver.FLAG_COMPRESS) == OK)
		var reloaded = ResourceLoader.load(output, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE)
		assert(LOD.base_digest(reloaded) == LOD.base_digest(source), "Save/reload changed the packed base mesh")
		assert(reloaded.lightmap_size_hint == source.lightmap_size_hint)
		var lod_count := 0
		for i in range(reloaded.get_surface_count()):
			lod_count += RenderingServer.mesh_get_surface(reloaded.get_rid(), i).get("lods", []).size()
		manifest[relative] = {"base_sha256": LOD.base_digest(source), "lod_count": lod_count, "lightmap_hint": [source.lightmap_size_hint.x, source.lightmap_size_hint.y]}
		print("ARENA LOD ", relative," levels=",lod_count," base_preserved=true")
	# An explicit apply flag is for committing the already inspected trial output.
	if OS.get_cmdline_user_args().has("--apply"):
		for relative in manifest:
			assert(DirAccess.copy_absolute("res://artifacts/arena_lod_trial/" + relative, PREFIX + relative) == OK)
		var file := FileAccess.open(PREFIX + "lod_manifest.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, "\t") + "\n")
	scene.free()
	quit()
