extends RefCounted
## Diagnostic copy of vanguard_strike.gd, with timing checkpoints.
static var retained_material: StandardMaterial3D

# Short visual response to confirmed damage, never a projectile or a collider.
# The existing reliable event carries this to clients without protocol changes.
static func spawn(parent: Node3D, source: Vector3, target: Vector3, team: Color) -> void:
	var measured := Time.get_ticks_usec()
	var offset := target - source
	offset.y = 0
	if offset.length_squared() < 0.0001:
		return
	var root := Node3D.new()
	root.name = "VanguardStrike"
	parent.add_child(root)
	root.position = source + Vector3.UP * 1.0
	root.rotation.y = atan2(-offset.x, -offset.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = team.lightened(0.55)
	mat.emission_enabled = true
	mat.emission = team.lightened(0.4)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if parent.bench_retain_strike_material and retained_material == null:
		retained_material = mat # Preserve shader lifetime; no extra visible geometry.
	measured = checkpoint(parent, "material_and_root", measured)
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
	measured = checkpoint(parent, "emit_vertices", measured)
	st.generate_normals()
	measured = checkpoint(parent, "generate_normals", measured)
	var arc := MeshInstance3D.new()
	measured = checkpoint(parent, "create_arc_instance", measured)
	arc.mesh = st.commit()
	measured = checkpoint(parent, "surface_commit", measured)
	arc.material_override = mat
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	measured = checkpoint(parent, "assign_arc_material", measured)
	root.add_child(arc)
	measured = checkpoint(parent, "attach_arc", measured)
	# Impact sparks stay small, at the actual victim, even at max melee range.
	var impact := Node3D.new()
	root.add_child(impact)
	impact.global_position = target + Vector3.UP * 1.1
	for i in 5:
		var spark := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.025, 0.22, 0.018)
		spark.mesh = mesh
		spark.material_override = mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact.add_child(spark)
		var a := i * TAU / 5.0
		spark.position = Vector3(sin(a), cos(a), 0) * 0.13
		spark.rotation.z = -a
	measured = checkpoint(parent, "create_sparks", measured)
	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_property(arc, "rotation:y", 0.55, 0.2)
	tween.tween_property(impact, "scale", Vector3.ONE * 1.8, 0.2)
	tween.chain().tween_callback(root.queue_free)

	checkpoint(parent, "tween_setup", measured)

static func checkpoint(parent, label: String, started: int) -> int:
	parent.trace_event("vanguard_stage", label, -1, -1, started)
	return Time.get_ticks_usec()
