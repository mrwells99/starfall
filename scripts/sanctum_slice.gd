extends Node3D
## First authored quality target. Visuals only; arena_layout owns all collision.
## Its editor-ready scene carries authored meshes, shared PBR and baked light.

const COVER_PATH := "res://assets/environment/slice/sanctum_cover.glb"
const COVER_POSITION := Vector3(-6, 0, 5)
const SCENE_PATH := "res://scenes/sanctum_quality_slice.tscn"
var has_surround := false

func build() -> bool:
	if ResourceLoader.exists(SCENE_PATH):
		var scene := load(SCENE_PATH) as PackedScene
		if scene != null:
			var visuals := scene.instantiate()
			var lights := visuals.get_node_or_null("BakeLights")
			if lights != null:
				lights.free()
			add_child(visuals)
			has_surround = true
			return true
	if not ResourceLoader.exists(COVER_PATH):
		return false
	var packed := load(COVER_PATH) as PackedScene
	if packed == null:
		return false
	var cover := packed.instantiate() as Node3D
	cover.name = "CarvedCelestialBulwark"
	cover.position = COVER_POSITION
	add_child(cover)
	_prepare_meshes(cover)
	return true

func _prepare_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var mat := source.duplicate() as StandardMaterial3D
			# Keep real lighting on the glTF materials, including emissive inlay.
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			if source.resource_name == "Slice_Inlay":
				mat.emission_enabled = true
				mat.emission_energy_multiplier = 3.4
			mesh_instance.set_surface_override_material(surface, mat)
	for child in node.get_children():
		_prepare_meshes(child)
