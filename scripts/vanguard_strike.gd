extends RefCounted

# Short visual response to confirmed damage, never a projectile or a collider.
# The existing reliable event carries this to clients without protocol changes.
static var _material_template: StandardMaterial3D
static var _arc_mesh: ArrayMesh
static var _spark_mesh: PrismMesh

static func prepare_resources() -> void:
	if _material_template != null:
		return
	# Retain the material/shader across impacts and rounds. Letting the last
	# instance disappear caused fresh synchronous compilation on every attack.
	_material_template = StandardMaterial3D.new()
	_material_template.emission_enabled = true
	_material_template.emission_energy_multiplier = 3.0
	_material_template.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_template.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var a := lerpf(-1.15, 1.15, i / 24.0)
		var b := lerpf(-1.15, 1.15, (i + 1) / 24.0)
		var wa := sin(PI * i / 24.0) * 0.09
		var wb := sin(PI * (i + 1) / 24.0) * 0.09
		var p := Vector3(sin(a), sin(a) * 0.2, -cos(a)) * 0.95
		var q := Vector3(sin(b), sin(b) * 0.2, -cos(b)) * 0.95
		for vertex in [p, p * (1.0 + wa), q, q, p * (1.0 + wa), q * (1.0 + wb)]:
			st.add_vertex(vertex)
	st.generate_normals()
	_arc_mesh = st.commit()
	_spark_mesh = PrismMesh.new()
	_spark_mesh.size = Vector3(0.025, 0.22, 0.018)

static func prewarm(parent: Node3D) -> void:
	prepare_resources()
	if parent.has_node("VanguardStrikeWarmup"):
		return
	# Hidden instances make both mesh/material combinations available during
	# character loading, before the first confirmed hit. They never animate.
	var warmup := Node3D.new()
	warmup.name = "VanguardStrikeWarmup"
	warmup.visible = false
	for mesh in [_arc_mesh, _spark_mesh]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _material_template
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warmup.add_child(instance)
	parent.add_child(warmup)

static func spawn(parent: Node3D, source: Vector3, target: Vector3, team: Color) -> void:
	var offset := target - source
	offset.y = 0
	if offset.length_squared() < 0.0001:
		return
	prepare_resources()
	var root := Node3D.new()
	root.name = "VanguardStrike"
	parent.add_child(root)
	root.position = source + Vector3.UP * 1.0
	root.rotation.y = atan2(-offset.x, -offset.z)
	# Each effect owns its fade/tint; meshes and the retained shader are shared.
	var mat := _material_template.duplicate() as StandardMaterial3D
	mat.albedo_color = team.lightened(0.55)
	mat.emission = team.lightened(0.4)
	var arc := MeshInstance3D.new()
	arc.name = "Arc"
	arc.mesh = _arc_mesh
	arc.material_override = mat
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arc)
	# Impact sparks stay small, at the actual victim, even at max melee range.
	var impact := Node3D.new()
	impact.name = "Impact"
	root.add_child(impact)
	impact.global_position = target + Vector3.UP * 1.1
	for i in 5:
		var spark := MeshInstance3D.new()
		spark.mesh = _spark_mesh
		spark.material_override = mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact.add_child(spark)
		var a := i * TAU / 5.0
		spark.position = Vector3(sin(a), cos(a), 0) * 0.13
		spark.rotation.z = -a
	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_property(arc, "rotation:y", 0.55, 0.2)
	tween.tween_property(impact, "scale", Vector3.ONE * 1.8, 0.2)
	tween.chain().tween_callback(root.queue_free)
