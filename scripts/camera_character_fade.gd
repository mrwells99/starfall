extends RefCounted
## Camera-local costume fade, including native weapons and bone attachments.
## Pixel dither works in Compatibility as well as Forward+ and avoids treating
## an attachment's origin as its visible geometry's distance from the camera.
const INVISIBLE_DISTANCE := 0.8
const OPAQUE_DISTANCE := 2.4

var _actor_id := 0
var _model_id := 0
var _owned: Dictionary = {}
var _duplicates: Dictionary = {}
var _faded: Dictionary = {}
var _materials: Array[Dictionary] = []
var _bindings: Array[Dictionary] = []


func update(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		reset()
		return
	var presenter := actor.get("champion_model") as Node3D
	if not is_instance_valid(presenter):
		reset()
		return
	if _actor_id == actor.get_instance_id() and _model_id == presenter.get_instance_id():
		return
	reset()
	_actor_id = actor.get_instance_id()
	_model_id = presenter.get_instance_id()
	_remember_owned(presenter.get("materials"))
	var costume_roots: Array[Node3D] = []
	for property_name in ["ember_art", "vanguard_art", "luminary_art", "fulcrum_art", "outlaw_art", "null_art"]:
		var art: Variant = presenter.get(property_name)
		if not is_instance_valid(art):
			continue
		_remember_owned(art.get("materials"))
		if property_name == "null_art":
			# Null swaps retained solid/fading variants. Prepare and restore camera
			# distance fade on both so switching Stealth never loses ownership or
			# introduces a new shader configuration during the transition.
			for variants in [art.solid_materials, art.fade_materials]:
				_remember_owned(variants)
				for material in variants: _fade_material(material)
			# Queue the exact transparent, camera-faded variant during character
			# setup. This keeps its first renderer submission off the first Stealth.
			art.prewarm_stealth_pipeline(presenter)
		var costume := art.get("model") as Node3D
		if is_instance_valid(costume):
			costume_roots.append(costume)
	# Authored costume roots exclude gameplay visuals attached to the presenter,
	# including Vanguard's ward/pulse and strike effects. Procedural costumes
	# place their meshes directly under ChampionModel and have no authored root.
	if costume_roots.is_empty():
		costume_roots.append(presenter)
	for costume in costume_roots:
		_fade_subtree(costume)


func reset() -> void:
	for state in _materials:
		var material: BaseMaterial3D = state.material
		material.distance_fade_mode = state.mode
		material.distance_fade_min_distance = state.minimum
		material.distance_fade_max_distance = state.maximum
	for binding in _bindings:
		var mesh: MeshInstance3D = binding.mesh.get_ref()
		if not is_instance_valid(mesh):
			continue
		# Do not overwrite a material another presentation change installed later.
		if binding.surface >= 0:
			if mesh.mesh != null and binding.surface < mesh.mesh.get_surface_count() and mesh.get_surface_override_material(binding.surface) == binding.replacement:
				mesh.set_surface_override_material(binding.surface, binding.original)
		elif mesh.get(binding.property) == binding.replacement:
			mesh.set(binding.property, binding.original)
	_materials.clear()
	_bindings.clear()
	_owned.clear()
	_duplicates.clear()
	_faded.clear()
	_actor_id = 0
	_model_id = 0


func _remember_owned(materials: Variant) -> void:
	if not materials is Array:
		return
	# These presenter arrays are populated with fresh procedural materials or
	# imported-material duplicates in champion_model/model_forge_art/fulcrum_art.
	# Mutate only fade properties on those actor-owned instances so their live
	# animation, team tint and damage-flash references remain valid.
	for material in materials:
		if material is BaseMaterial3D:
			_owned[material] = true


func _fade_subtree(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		# A character's shadow remains visible when the follow camera hides its
		# costume. Null's separate shadow material is controlled only by Stealth.
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: return
		if mesh.material_override != null:
			_fade_property(mesh, "material_override")
		elif mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_surface_override_material(surface)
				var active := original if original != null else mesh.mesh.surface_get_material(surface)
				var replacement := _fade_material(active)
				if replacement != active:
					_bindings.append({"mesh": weakref(mesh), "surface": surface, "original": original, "replacement": replacement})
					mesh.set_surface_override_material(surface, replacement)
		_fade_property(mesh, "material_overlay")
	for child in node.get_children():
		_fade_subtree(child)


func _fade_property(mesh: MeshInstance3D, property_name: String) -> void:
	var original := mesh.get(property_name) as Material
	var replacement := _fade_material(original)
	if replacement != original:
		_bindings.append({"mesh": weakref(mesh), "surface": -1, "property": property_name, "original": original, "replacement": replacement})
		mesh.set(property_name, replacement)


func _fade_material(original: Material) -> Material:
	if not original is BaseMaterial3D:
		return original
	var material := original as BaseMaterial3D
	if not _owned.has(original):
		# Untracked overrides and imported mesh surface resources may be shared
		# with other actors. Duplicate the material, retaining its texture assets,
		# and restore the exact original override (including null) when unfollowed.
		if not _duplicates.has(original):
			_duplicates[original] = original.duplicate()
		material = _duplicates[original]
	if not _faded.has(material):
		_materials.append({"material": material, "mode": material.distance_fade_mode, "minimum": material.distance_fade_min_distance, "maximum": material.distance_fade_max_distance})
		_faded[material] = true
		material.distance_fade_min_distance = INVISIBLE_DISTANCE
		material.distance_fade_max_distance = OPAQUE_DISTANCE
		material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	return material
