extends RefCounted
## High-only, reversible map detail treatment. Never visits actor materials.
const STONE_SHADERS := ["res://shaders/arena_stone.gdshader", "res://shaders/sanctum_corner_stone.gdshader"]
const ORIGINAL_LOD := &"map_quality_original_lod"
const ORIGINAL_NORMAL := &"map_quality_original_normal"

static func apply(root: Node, high: bool) -> void:
	var art := root if root.name == "CosmicSanctum" else root.find_child("CosmicSanctum", true, false)
	if art == null: return
	var seen := {}
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		if mesh.mesh.resource_path.begins_with("res://assets/environment/slice/meshes/"):
			if not mesh.has_meta(ORIGINAL_LOD): mesh.set_meta(ORIGINAL_LOD, mesh.lod_bias)
			mesh.lod_bias = maxf(1.0, float(mesh.get_meta(ORIGINAL_LOD))) if high else float(mesh.get_meta(ORIGINAL_LOD))
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			if material == null or seen.has(material): continue
			seen[material] = true
			if material is ShaderMaterial and material.shader != null and material.shader.resource_path in STONE_SHADERS:
				material.set_shader_parameter("stable_detail", high)
			elif material is StandardMaterial3D and material.normal_enabled and material.normal_texture != null:
				if not material.normal_texture.resource_path.begins_with("res://assets/environment/"): continue
				if not material.has_meta(ORIGINAL_NORMAL): material.set_meta(ORIGINAL_NORMAL, material.normal_scale)
				# Map bronze/detail has no custom roughness filter. Slightly soften
				# its tiny normal-map glints; leave color, metalness and emission intact.
				material.normal_scale = float(material.get_meta(ORIGINAL_NORMAL)) * (0.8 if high else 1.0)

static func supersample_scale(base_scale: float, output_size: Vector2i, high: bool) -> float:
	if not high or base_scale < 0.999 or output_size.x <= 0 or output_size.y <= 0: return base_scale
	# 10% more samples per axis (21% more pixels), capped at a 4K pixel budget.
	# Respect explicit lower-resolution settings instead of undoing them.
	var pixel_limit := sqrt(8294400.0 / (float(output_size.x) * output_size.y))
	return base_scale * clampf(pixel_limit, 1.0, 1.10)
