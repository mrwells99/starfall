extends SceneTree
## Rebuild the editor-ready visual scene before running the native light bake.

const ASSETS := "res://assets/environment/slice/"
var materials: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func surface(name: String) -> StandardMaterial3D:
	if materials.has(name):
		return materials[name]
	var mat := StandardMaterial3D.new()
	mat.resource_name = name
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var profile := "basalt"
	match name:
		"Slice_Floor":
			profile = "floor"
			mat.albedo_color = Color(0.40, 0.41, 0.45)
		"Slice_EdgeStone":
			profile = "floor"
			mat.albedo_color = Color(0.82, 0.84, 0.88)
		"Slice_Bronze":
			profile = "bronze"
			mat.metallic = 0.68
		"Slice_Recess":
			mat.albedo_color = Color(0.36, 0.40, 0.49)
		"Slice_Inlay":
			mat.albedo_color = Color("366978")
			mat.emission_enabled = true
			mat.emission = Color("53b9e6")
			mat.emission_energy_multiplier = 3.2
			mat.roughness = 0.42
			materials[name] = mat
			return mat
	mat.albedo_texture = load(ASSETS + "textures/" + profile + "_albedo.png")
	mat.normal_enabled = true
	mat.normal_texture = load(ASSETS + "textures/" + profile + "_normal.png")
	mat.normal_scale = 0.65
	mat.roughness = 1.0
	mat.roughness_texture = load(ASSETS + "textures/" + profile + "_roughness.png")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	materials[name] = mat
	return mat

func copy_meshes(source: Node, parent: Node3D, owner_node: Node3D, hint: int) -> void:
	for child in source.get_children():
		if child is MeshInstance3D:
			var instance := MeshInstance3D.new()
			instance.name = child.name
			instance.mesh = child.mesh.duplicate()
			var size := hint
			if "Recess" in str(child.name) or "Inlay" in str(child.name):
				size = 64
			elif "Bronze" in str(child.name):
				size = 128
			instance.mesh.lightmap_size_hint = Vector2i(size, size)
			var mesh_dir := ASSETS + "meshes/" + str(parent.name)
			DirAccess.make_dir_recursive_absolute(mesh_dir)
			ResourceSaver.save(instance.mesh, mesh_dir + "/" + str(child.name) + ".res", ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH)
			instance.mesh = ResourceLoader.load(mesh_dir + "/" + str(child.name) + ".res", "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE)
			instance.mesh.take_over_path(mesh_dir + "/" + str(child.name) + ".res")
			instance.transform = child.transform
			instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			for index in range(instance.mesh.get_surface_count()):
				var original: Material = instance.mesh.surface_get_material(index)
				instance.set_surface_override_material(index, surface(original.resource_name))
			parent.add_child(instance)
			instance.owner = owner_node
		else:
			var branch := Node3D.new()
			branch.name = child.name
			if child is Node3D:
				branch.transform = child.transform
			parent.add_child(branch)
			branch.owner = owner_node
			copy_meshes(child, branch, owner_node, hint)

func build() -> void:
	var scene := Node3D.new()
	scene.name = "SanctumQualitySlice"
	root.add_child(scene)
	for item in [["Cover", "sanctum_cover", Vector3(-6,0,5), 256],
		["Floor", "sanctum_floor", Vector3(-6,0,7), 512],
		["Perimeter", "sanctum_perimeter", Vector3(-18.3,0,6.5), 256]]:
		var branch := Node3D.new()
		branch.name = item[0]
		branch.position = item[2]
		scene.add_child(branch)
		branch.owner = scene
		# Read ignored authoring GLBs explicitly. Only the compressed runtime
		# meshes ship, avoiding duplicate GLB + imported + .res geometry.
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var read_error := document.append_from_file("res://assets-source/sanctum_slice/" + item[1] + ".glb", state)
		if read_error != OK:
			push_error("Cannot read source GLB: " + str(item[1]))
			quit(read_error)
			return
		var imported := document.generate_scene(state)
		copy_meshes(imported, branch, scene, item[3])
		imported.free()
	# Bake bounced light only. Matching real-time lights remain in arena_sky.gd;
	# removing these after loading prevents duplicate direct illumination.
	var bake_lights := Node3D.new()
	bake_lights.name = "BakeLights"
	scene.add_child(bake_lights)
	bake_lights.owner = scene
	for info in [[Vector3(-48,-30,0), Color("e6d7ce"),1.4],
		[Vector3(-20,140,0),Color("9f83ee"),.28],
		[Vector3(-12,168,0),Color("7fd4ff"),.20]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = info[0]
		light.light_color = info[1]
		light.light_energy = info[2]
		light.light_bake_mode = Light3D.BAKE_DYNAMIC
		light.shadow_enabled = true
		bake_lights.add_child(light)
		light.owner = scene
	var gi := LightmapGI.new()
	gi.name = "BakedSanctumLight"
	gi.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	gi.bounces = 3
	gi.use_denoiser = false
	gi.max_texture_size = 2048 # Godot's minimum atlas cap; inputs stay 512 or smaller.
	gi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_DISABLED
	gi.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	gi.environment_custom_color = Color("9699c5")
	gi.environment_custom_energy = 0.43
	scene.add_child(gi)
	gi.owner = scene
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed,"res://scenes/sanctum_quality_slice.tscn")
	print("Prepared quality slice, result: ",error)
	quit(error)
