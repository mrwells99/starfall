extends RefCounted
## Editor/build-time only. Preserve the original packed vertex/UV/lightmap data
## and add index-only detail levels. Never simplify meshes during game startup.

static func base_digest(mesh: ArrayMesh) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for surface in mesh.get("_surfaces"):
		for key in ["format", "primitive", "vertex_count", "vertex_data", "attribute_data", "skin_data", "index_count", "index_data", "aabb", "uv_scale", "name"]:
			hash.update(var_to_bytes(surface.get(key)))
	return hash.finish().hex_encode()

static func with_lods(mesh: ArrayMesh) -> ArrayMesh:
	assert(mesh.get_blend_shape_count() == 0, "This build helper is for static arena meshes only")
	var importer := ImporterMesh.new()
	for i in range(mesh.get_surface_count()):
		importer.add_surface(mesh.surface_get_primitive_type(i), mesh.surface_get_arrays(i), [], {}, mesh.surface_get_material(i), mesh.surface_get_name(i), mesh.surface_get_format(i))
	# Zero normal-merge angle avoids altering the base vertices or seams.
	importer.generate_lods(0, 0, [])
	for i in range(mesh.get_surface_count()):
		assert(var_to_bytes(mesh.surface_get_arrays(i)) == var_to_bytes(importer.get_surface_arrays(i)), "LOD generation changed base arrays")
	var generated := importer.get_mesh()
	var packed: Array = mesh.get("_surfaces").duplicate(true)
	var generated_packed: Array = generated.get("_surfaces")
	for i in range(packed.size()):
		assert(packed[i].vertex_count == generated_packed[i].vertex_count)
		packed[i].erase("lods")
		if generated_packed[i].has("lods"):
			packed[i]["lods"] = generated_packed[i].lods
	var result := mesh.duplicate() as ArrayMesh
	# _surfaces is ArrayMesh's serialized storage property. Using it only in
	# this offline builder avoids repacking/quantizing existing normals and UVs.
	# A digest and save/reload checks guard that engine-storage dependency.
	result.set("_surfaces", packed)
	result.shadow_mesh = null
	assert(base_digest(result) == base_digest(mesh), "Packed base geometry must stay identical")
	return result

