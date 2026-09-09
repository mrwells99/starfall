extends Node3D
## Arena-wide material and shrine upgrade. Collision stays in arena_layout.

const TEXTURES := "res://assets/environment/corner/textures/"
const DETAILS := "res://assets/environment/corner/corner_details.glb"
const STONE_SHADER := preload("res://shaders/sanctum_corner_stone.gdshader")
var _originals: Array[Dictionary] = []
var _materials: Dictionary = {}
var enabled := true

func build(architecture: Node3D) -> void:
	name = "CornerUpgrade"
	_replace_materials(architecture)
	if ResourceLoader.exists(DETAILS):
		for side in [1.0, -1.0]:
			var shrine := (load(DETAILS) as PackedScene).instantiate() as Node3D
			shrine.name = "WestShrine" if side > 0 else "EastShrine"
			shrine.rotation.y = 0.0 if side > 0 else PI
			add_child(shrine)
			_style_details(shrine)
			var lamp := OmniLight3D.new()
			lamp.name = "ShrineVotives"
			lamp.position = Vector3(-17.1 * side, 3.58, 13.5 * side)
			lamp.light_color = Color("ffbd79")
			lamp.light_energy = 2.0
			lamp.omni_range = 5.5
			lamp.omni_attenuation = 1.6
			lamp.shadow_enabled = true
			lamp.shadow_bias = 0.03
			lamp.light_bake_mode = Light3D.BAKE_DISABLED
			add_child(lamp)
	# A local reflection capture lets bronze reflect nearby architecture, rather
	# than only the purple sky. It does not replace or double the indirect bake.
	var reflection := ReflectionProbe.new()
	reflection.name = "CornerReflection"
	reflection.position = Vector3(0, 3.4, 0)
	reflection.size = Vector3(40, 9, 40)
	reflection.origin_offset = Vector3(0, 0.5, 0)
	reflection.box_projection = true
	reflection.intensity = 0.65
	reflection.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	reflection.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection.enable_shadows = true
	add_child(reflection)
	if OS.get_cmdline_user_args().has("--sanctum-original"):
		set_enabled(false)

func _material(kind: String) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	if kind in ["Basalt", "Recess", "EdgeStone", "Floor", "Terrace"]:
		var stone := ShaderMaterial.new()
		stone.resource_name = "Corner_" + kind
		stone.shader = STONE_SHADER
		var prefix := "basalt" if kind in ["Basalt", "Recess"] else "floor"
		for map_name in ["albedo", "normal", "roughness"]:
			stone.set_shader_parameter(map_name + "_map", load(TEXTURES + prefix + "_" + map_name + ".png"))
		stone.set_shader_parameter("tint_color", Color("62676e") if kind == "Recess" \
			else (Color("919797") if kind in ["Floor", "Terrace"] else Color.WHITE))
		stone.set_shader_parameter("wear_amount", 0.6 if kind == "Basalt" else 0.35)
		_materials[kind] = stone
		return stone
	var material := StandardMaterial3D.new()
	material.resource_name = "Corner_" + kind
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# The source meshes encode subtle block variation in vertex color.
	material.vertex_color_use_as_albedo = true
	if kind == "Inlay" or kind == "Ember":
		material.albedo_color = Color("879c9a") if kind == "Inlay" else Color("ad7538")
		material.emission_enabled = true
		material.emission = Color("68bbc6") if kind == "Inlay" else Color("ffbd68")
		material.emission_energy_multiplier = 1.4 if kind == "Inlay" else 2.5
		material.roughness = 0.38
	else:
		var prefix := "basalt"
		if kind in ["EdgeStone", "Limestone", "Floor", "Terrace"]:
			prefix = "floor"
		elif kind == "Bronze":
			prefix = "bronze"
		material.albedo_texture = load(TEXTURES + prefix + "_albedo.png")
		material.normal_texture = load(TEXTURES + prefix + "_normal.png")
		material.roughness_texture = load(TEXTURES + prefix + "_roughness.png")
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.normal_enabled = true
		material.normal_scale = 1.0
		if kind == "Bronze":
			# A small cool tint softens the copper cast without turning trim silver.
			material.albedo_color = Color("e8efff")
			material.metallic = 0.9
			material.metallic_texture = load(TEXTURES + "bronze_metallic.png")
			material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		elif kind == "Recess":
			material.albedo_color = Color("62676e")
		elif kind in ["Floor", "Terrace"]:
			material.albedo_color = Color("919797")
	_materials[kind] = material
	return material

func _replace_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(surface)
			if original == null:
				continue
			var kind := original.resource_name.trim_prefix("Slice_")
			# Preserve the original glowing armillary artwork on every pillar.
			if kind == "Inlay":
				continue
			var replacement := _material(kind)
			_originals.append({"mesh":node, "surface":surface,
				"original":node.get_surface_override_material(surface), "new":replacement})
			node.set_surface_override_material(surface, replacement)
	for child in node.get_children():
		_replace_materials(child)

func _style_details(node: Node) -> void:
	if node is MeshInstance3D:
		# New relief is lit dynamically; existing geometry retains all 115 bake assignments.
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for surface in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(surface)
			if original != null:
				var detail := _material(original.resource_name.trim_prefix("Corner_")).duplicate() as Material
				# Detail GLB UVs repeat at 2m; match the architecture's 4m mineral scale.
				if detail is ShaderMaterial:
					detail.set_shader_parameter("material_uv_scale", 0.5)
				elif detail is StandardMaterial3D:
					detail.uv1_scale = Vector3(0.5, 0.5, 1)
				node.set_surface_override_material(surface, detail)
	for child in node.get_children():
		_style_details(child)

func set_enabled(value: bool) -> void:
	enabled = value
	for item in _originals:
		item.mesh.set_surface_override_material(item.surface, item.new if value else item.original)
	visible = value

func modified_surface_count() -> int:
	return _originals.size()
