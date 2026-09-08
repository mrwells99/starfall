extends RefCounted

static var cloth_weave: ImageTexture
static var forged_roughness: ImageTexture

# Tiny deterministic, shared surface maps. These contain material variation
# only, not illumination, and add no imported environment assets.
static func prepare_surfaces() -> void:
	if cloth_weave != null:
		return
	var cloth := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var metal := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var thread := 0.9 + 0.065 * sin(TAU * x / 4.0) * sin(TAU * y / 4.0)
			cloth.set_pixel(x, y, Color(thread, thread, thread))
			var grain := 0.84 + 0.1 * sin(TAU * x / 8.0 + 0.5 * sin(TAU * y / 32.0)) + 0.035 * sin(TAU * y / 4.0)
			metal.set_pixel(x, y, Color(grain, grain, grain))
	cloth.generate_mipmaps()
	metal.generate_mipmaps()
	cloth_weave = ImageTexture.create_from_image(cloth)
	forged_roughness = ImageTexture.create_from_image(metal)

# Geometry stays procedural, but armor uses outlined, bevelled plates instead
# of stacked diamonds. Each joint batches its rigid pieces by material.
static func surface(model, color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = model.paint(color.to_html(false), false, metal)
	mat.roughness = rough
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

# Convex XY outline, facing -Z. The inset face and sloping rim catch actual
# lighting; there are no baked highlights or texture dependencies.
static func plate(model, parent: Node3D, at: Vector3, outline: PackedVector2Array, depth: float, mat: Material, bevel: float = 0.09) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var p := Vector3(a.x, a.y, 0)
		var q := Vector3(b.x, b.y, 0)
		var r := Vector3(a.x * (1.0 - bevel), a.y * (1.0 - bevel), -depth)
		var s := Vector3(b.x * (1.0 - bevel), b.y * (1.0 - bevel), -depth)
		for v in [p, q, r, q, s, r, Vector3(0, 0, -depth * 1.25), r, s, Vector3.ZERO, q, p]:
			st.set_uv(Vector2(v.x, v.y) * 3.0)
			st.add_vertex(v)
	st.generate_normals()
	return model.piece(parent, st.commit(), at, mat)

static func armor(model, parent: Node3D, at: Vector3, size: Vector2, depth: float, mat: Material) -> MeshInstance3D:
	var w := size.x * 0.5
	var h := size.y * 0.5
	return plate(model, parent, at, PackedVector2Array([
		Vector2(-w * 0.65, -h), Vector2(w * 0.65, -h), Vector2(w, -h * 0.6),
		Vector2(w, h * 0.55), Vector2(w * 0.6, h), Vector2(-w * 0.6, h),
		Vector2(-w, h * 0.55), Vector2(-w, -h * 0.6)]), depth, mat)

static func jewel(model, parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return plate(model, parent, at + Vector3(0, 0, size.z * 0.5), PackedVector2Array([
		Vector2(0, -size.y * 0.5), Vector2(size.x * 0.5, 0), Vector2(0, size.y * 0.5), Vector2(-size.x * 0.5, 0)]), size.z, mat, 0.6)

static func shell(model, parent: Node3D, at: Vector3, rings: Array, mat: Material, sides: int = 12) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		for j in sides:
			var a := TAU * j / sides
			var b := TAU * (j + 1) / sides
			var lo: Vector3 = rings[i]
			var hi: Vector3 = rings[i + 1]
			var p := Vector3(cos(a) * lo.y, lo.x, sin(a) * lo.z)
			var q := Vector3(cos(a) * hi.y, hi.x, sin(a) * hi.z)
			var r := Vector3(cos(b) * lo.y, lo.x, sin(b) * lo.z)
			var s := Vector3(cos(b) * hi.y, hi.x, sin(b) * hi.z)
			for v in [p, r, q, r, s, q]:
				st.add_vertex(v)
	st.set_smooth_group(-1)
	for index in [0, rings.size() - 1]:
		var ring: Vector3 = rings[index]
		for j in sides:
			var a := TAU * j / sides
			var b := TAU * (j + 1) / sides
			var p := Vector3(cos(a) * ring.y, ring.x, sin(a) * ring.z)
			var q := Vector3(cos(b) * ring.y, ring.x, sin(b) * ring.z)
			for v in [Vector3(0, ring.x, 0), q if index == 0 else p, p if index == 0 else q]:
				st.add_vertex(v)
	st.generate_normals()
	return model.piece(parent, st.commit(), at, mat)

static func build(m, team: Color) -> void:
	prepare_surfaces()
	var steel := surface(m, Color("748b9d"), 0.65, 0.43)
	var edge := surface(m, Color("c1ced4"), 0.72, 0.34)
	var bronze := surface(m, Color("b69259"), 0.7, 0.46)
	var leather := surface(m, Color("202936"), 0.0, 0.87)
	var enamel := surface(m, team.darkened(0.18), 0.25, 0.43)
	var cloth := surface(m, team.darkened(0.32), 0.0, 0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.albedo_texture = cloth_weave
	cloth.uv1_scale = Vector3(3, 3, 3)
	steel.roughness_texture = forged_roughness
	steel.roughness = 0.52
	var light := surface(m, Color("ffe7b1"), 0.15, 0.32)
	light.emission_enabled = true
	light.emission = Color("ffd990")
	light.emission_energy_multiplier = 2.6
	var ward := surface(m, team.lightened(0.35), 0.0, 0.4)
	ward.emission_enabled = true
	ward.emission = team.lightened(0.25)
	ward.emission_energy_multiplier = 3.2
	var chest: Node3D = m.joint(m, Vector3.ZERO, "ArmoredUpperBody")
	m.torso = shell(m, chest, Vector3.ZERO, [Vector3(0.82, 0.23, 0.16), Vector3(1.18, 0.3, 0.19), Vector3(1.44, 0.28, 0.16)], leather, 12)
	# Overlapping cuirass, collar, and articulated belly lames.
	armor(m, chest, Vector3(0, 1.25, -0.17), Vector2(0.65, 0.43), 0.115, steel)
	for side in [-1.0, 1.0]:
		var outline := PackedVector2Array([Vector2(-0.11, -0.045), Vector2(0.1, -0.01), Vector2(0.135, 0.04), Vector2(0.075, 0.075), Vector2(-0.115, 0.015)])
		for i in outline.size():
			outline[i].x *= side
		if side < 0:
			outline.reverse()
		plate(m, chest, Vector3(side * 0.15, 1.32, -0.28), outline, 0.018, edge)
		armor(m, chest, Vector3(side * 0.265, 1.2, -0.14), Vector2(0.12, 0.27), 0.08, enamel)
	for i in 3:
		armor(m, chest, Vector3(0, 0.95 + i * 0.085, -0.19), Vector2(0.46 + i * 0.025, 0.095), 0.065, steel)
	shell(m, chest, Vector3.ZERO, [Vector3(1.43, 0.18, 0.15), Vector3(1.5, 0.185, 0.155)], bronze, 12)
	armor(m, chest, Vector3(0, 0.88, -0.18), Vector2(0.5, 0.1), 0.04, leather)
	armor(m, chest, Vector3(0, 0.88, -0.23), Vector2(0.12, 0.12), 0.028, bronze)
	# One small chest star; team cloth and enamel remain the larger color areas.
	jewel(m, chest, Vector3(0, 1.26, -0.32), Vector3(0.1, 0.19, 0.04), bronze)
	jewel(m, chest, Vector3(0, 1.26, -0.348), Vector3(0.045, 0.09, 0.02), light)
	m.left_leg = m.joint(m, Vector3(-0.17, 0.78, 0), "LeftLeg")
	m.right_leg = m.joint(m, Vector3(0.17, 0.78, 0), "RightLeg")
	var knees: Array[Node3D] = []
	for leg in [m.left_leg, m.right_leg]:
		shell(m, leg, Vector3.ZERO, [Vector3(-0.31, 0.1, 0.11), Vector3(-0.02, 0.135, 0.135)], leather, 12)
		armor(m, leg, Vector3(0, -0.13, -0.11), Vector2(0.23, 0.28), 0.055, steel)
		var knee: Node3D = m.joint(leg, Vector3(0, -0.31, 0), "Knee")
		knees.append(knee)
		shell(m, knee, Vector3.ZERO, [Vector3(-0.34, 0.095, 0.1), Vector3(0, 0.105, 0.1)], leather, 12)
		armor(m, knee, Vector3(0, -0.16, -0.09), Vector2(0.205, 0.32), 0.07, steel)
		armor(m, knee, Vector3(0, 0, -0.115), Vector2(0.235, 0.18), 0.06, bronze)
		var boot: MeshInstance3D = armor(m, knee, Vector3(0, -0.39, -0.065), Vector2(0.245, 0.16), 0.21, steel)
		boot.name = "ArmoredBoot"
		for j in 2:
			armor(m, knee, Vector3(0, -0.36 + j * 0.045, -0.16), Vector2(0.22, 0.035), 0.06, edge)
	m.left_arm = m.joint(chest, Vector3(-0.37, 1.4, 0), "LeftArm")
	m.right_arm = m.joint(chest, Vector3(0.37, 1.4, 0), "RightArm")
	for arm in [m.left_arm, m.right_arm]:
		shell(m, arm, Vector3.ZERO, [Vector3(-0.5, 0.085, 0.09), Vector3(-0.25, 0.105, 0.11), Vector3(0, 0.13, 0.13)], leather, 12)
		armor(m, arm, Vector3(0, -0.37, -0.075), Vector2(0.22, 0.26), 0.075, steel)
		armor(m, arm, Vector3(0, -0.24, -0.09), Vector2(0.22, 0.1), 0.08, bronze)
		armor(m, arm, Vector3(0, -0.53, -0.03), Vector2(0.17, 0.16), 0.09, steel)
		# Shoulder shells are stepped in depth and width, rather than diamonds.
		for i in 3:
			shell(m, arm, Vector3(0, -i * 0.073, 0), [Vector3(-0.07, 0.205 - i * 0.014, 0.19), Vector3(0.03, 0.22 - i * 0.014, 0.205), Vector3(0.09, 0.145, 0.135)], bronze if i == 0 else steel, 12)
		armor(m, arm, Vector3(0, 0.015, -0.193), Vector2(0.27, 0.17), 0.02, enamel)
	# Enclosed sallet: eye slit sits between an actual brow and cheek guards.
	shell(m, chest, Vector3(0, 1.63, 0), [Vector3(-0.14, 0.135, 0.12), Vector3(0.1, 0.18, 0.16), Vector3(0.2, 0.115, 0.11), Vector3(0.22, 0.025, 0.03)], steel, 16)
	armor(m, chest, Vector3(0, 1.665, -0.155), Vector2(0.29, 0.06), 0.021, leather)
	armor(m, chest, Vector3(0, 1.707, -0.16), Vector2(0.32, 0.057), 0.035, edge)
	for side in [-1.0, 1.0]:
		var cheek := armor(m, chest, Vector3(side * 0.105, 1.57, -0.135), Vector2(0.12, 0.17), 0.057, steel)
		cheek.rotation.z = side * -0.2
		m.block(chest, Vector3(side * 0.07, 1.666, -0.181), Vector3(0.076, 0.015, 0.012), light)
	armor(m, chest, Vector3(0, 1.60, -0.19), Vector2(0.045, 0.14), 0.025, bronze)
	var crest: MeshInstance3D = armor(m, chest, Vector3(0, 1.845, 0.03), Vector2(0.045, 0.24), 0.14, bronze)
	crest.rotation.x = -0.3
	m.mantle = m.joint(chest, Vector3(0, 1.44, 0.175), "Mantle")
	# Open folded cloth sheet; no thick diamond cross section.
	var cape_st := SurfaceTool.new()
	cape_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 8:
		for x in 8:
			for uv in [Vector2(x, y), Vector2(x + 1, y), Vector2(x, y + 1), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]:
				var t: float = uv.y / 8.0
				var u: float = uv.x / 8.0
				cape_st.set_uv(Vector2(u, t))
				cape_st.add_vertex(Vector3((u - 0.5) * lerpf(0.57, 0.76, t), -t * 0.94 + sin(u * PI * 3.0) * 0.018 * t, t * 0.13 + sin(u * TAU * 3.0) * 0.025))
	cape_st.generate_normals()
	var cape_mat := ShaderMaterial.new()
	cape_mat.shader = preload("res://shaders/vanguard_cloth.gdshader")
	cape_mat.set_shader_parameter("cloth_color", team.darkened(0.32))
	m.piece(m.mantle, cape_st.commit(), Vector3.ZERO, cape_mat)
	for side in [-1.0, 1.0]:
		armor(m, chest, Vector3(side * 0.16, 0.69, -0.18), Vector2(0.22, 0.32), 0.018, cloth)
		armor(m, chest, Vector3(side * 0.29, 0.79, 0), Vector2(0.15, 0.25), 0.12, steel)
	# Fullered, tapered sword with a broad physical cutting edge.
	var sword: Node3D = m.joint(m.right_arm, Vector3(0, -0.53, -0.06), "AstralSword")
	shell(m, sword, Vector3.ZERO, [Vector3(-0.13, 0.043, 0.043), Vector3(0.12, 0.043, 0.043)], leather, 10)
	for i in 5:
		shell(m, sword, Vector3(0, -0.09 + i * 0.043, 0), [Vector3(0, 0.046, 0.046), Vector3(0.012, 0.046, 0.046)], bronze, 8)
	armor(m, sword, Vector3(0, 0.14, 0.035), Vector2(0.35, 0.075), 0.065, bronze)
	plate(m, sword, Vector3(0, 0.17, 0.027), PackedVector2Array([Vector2(-0.085, 0), Vector2(0.085, 0), Vector2(0.064, 0.75), Vector2(0, 0.98), Vector2(-0.064, 0.75)]), 0.057, edge, 0.42)
	armor(m, sword, Vector3(0, 0.56, -0.034), Vector2(0.028, 0.64), 0.008, steel)
	for i in 3:
		jewel(m, sword, Vector3(0, 0.35 + i * 0.17, -0.045), Vector3(0.019, 0.065, 0.012), light)
	# Shield's border, recessed face and boss have different actual relief.
	var shield: Node3D = m.joint(m.left_arm, Vector3(-0.055, -0.24, -0.2), "KiteShield")
	var shape := PackedVector2Array([Vector2(0, -0.53), Vector2(0.31, -0.18), Vector2(0.34, 0.29), Vector2(0.21, 0.41), Vector2(-0.21, 0.41), Vector2(-0.34, 0.29), Vector2(-0.31, -0.18)])
	plate(m, shield, Vector3.ZERO, shape, 0.075, bronze)
	var inner := PackedVector2Array()
	for p in shape:
		inner.append(p * 0.87)
	plate(m, shield, Vector3(0, 0, -0.077), inner, 0.035, enamel)
	armor(m, shield, Vector3(0, 0, -0.115), Vector2(0.055, 0.73), 0.025, edge)
	armor(m, shield, Vector3(0, 0.095, -0.12), Vector2(0.42, 0.055), 0.025, edge)
	jewel(m, shield, Vector3(0, 0.08, -0.155), Vector3(0.16, 0.24, 0.06), bronze)
	jewel(m, shield, Vector3(0, 0.08, -0.19), Vector3(0.058, 0.12, 0.025), light)
	var ward_root: Node3D = m.joint(shield, Vector3(0, 0, -0.16), "IronSkinSigil")
	for side in [-1.0, 1.0]:
		for i in 3:
			var rune: MeshInstance3D = armor(m, ward_root, Vector3(side * (0.19 - i * 0.035), 0.12 - i * 0.17, 0), Vector2(0.018, 0.085), 0.007, ward)
			rune.rotation.z = side * -0.55
	var ward_ring: MeshInstance3D = m.ring(ward_root, Vector3(0, 0.08, -0.01), 0.145, 0.009, ward)
	ward_ring.rotation.x = PI * 0.5
	ward_root.hide()
	var pulse_mat := StandardMaterial3D.new()
	pulse_mat.albedo_color = team.lightened(0.3)
	pulse_mat.emission_enabled = true
	pulse_mat.emission = team.lightened(0.3)
	pulse_mat.emission_energy_multiplier = 3.2
	pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var pulse: Node3D = m.joint(m, Vector3(0, 0.065, 0), "IronSkinActivation")
	m.ring(pulse, Vector3.ZERO, 0.52, 0.012, pulse_mat)
	for i in 8:
		var a := i * TAU / 8.0
		var mark: MeshInstance3D = m.block(pulse, Vector3(sin(a), 0, cos(a)) * 0.62, Vector3(0.025, 0.009, 0.08), pulse_mat)
		mark.rotation.y = a
	pulse.hide()
	m.vanguard = {"chest": chest, "knees": knees, "sword": sword, "ward": ward_root, "ward_mat": ward, "attack": 0.0,
		"pulse": pulse, "pulse_mat": pulse_mat, "pulse_left": 0.0, "previous_shield": 0.0,
		"cape_mat": cape_mat, "cloth_color": team.darkened(0.32), "previous_hp": 100.0, "hit_left": 0.0}
	batch(m, m.torso)
	for mesh in pulse.get_children():
		if mesh is MeshInstance3D:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh in ward_root.get_children():
		if mesh is MeshInstance3D:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func batch(node: Node3D, preserved: MeshInstance3D) -> void:
	var groups := {}
	for child in node.get_children():
		if child is MeshInstance3D and child != preserved:
			var mat: Material = child.material_override
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = st
			groups[mat].append_from(child.mesh, 0, child.transform)
			node.remove_child(child)
			child.free()
		elif child is Node3D and not child is MeshInstance3D:
			batch(child, preserved)
	for mat in groups:
		var mesh := MeshInstance3D.new()
		mesh.mesh = groups[mat].commit()
		mesh.material_override = mat
		node.add_child(mesh)

static func animate(m, delta: float, actor, swing: float) -> void:
	var rig: Dictionary = m.vanguard
	var alive: bool = actor.hp > 0
	var active: bool = alive and actor.stunned <= 0
	rig.attack = maxf(0, rig.attack - delta) if active else 0.0
	if actor.hp < rig.previous_hp:
		rig.hit_left = 0.18
	rig.previous_hp = actor.hp
	rig.hit_left = maxf(0, rig.hit_left - delta) if active else 0.0
	var hit: float = rig.hit_left / 0.18
	var chest: Node3D = rig.chest
	rig.cape_mat.set_shader_parameter("movement", m.motion if active else 0.0)
	rig.cape_mat.set_shader_parameter("cloth_color", Color.WHITE if actor.flash > 0 else (rig.cloth_color if alive else Color("333744")))
	# Travel-driven stride; bent knee on recovery keeps the feet closer to the
	# ground than swinging two rigid rods through the floor.
	for i in 2:
		var leg: Node3D = m.left_leg if i == 0 else m.right_leg
		var phase: float = swing if i == 0 else -swing
		leg.rotation.x = phase * 0.75
		rig.knees[i].rotation.x = maxf(0, -phase) * 0.9
	chest.rotation.y = -swing * 0.12
	chest.rotation.x = -m.motion * 0.035 - hit * 0.07 if active else 0.0
	chest.position.y = sin(m.clock * 2.0) * 0.005 if alive else 0.0
	m.position.y = -absf(swing) * 0.015 if alive else 0.0
	m.left_arm.rotation.x = -0.25 - swing * 0.15 if active else 0.0
	m.right_arm.rotation.x = -0.08 + swing * 0.25 if active else 0.0
	m.right_arm.rotation.z = -0.15
	m.left_arm.rotation.z = 0.1
	if actor.casting >= 0 and active:
		m.left_arm.rotation.x = -0.85
		m.right_arm.rotation.x = -0.65
	elif rig.attack > 0:
		# Hit is immediate. This is the follow-through and return to guard,
		# never a windup that would claim the instant ability has a cast time.
		var strength: float = pow(rig.attack / 0.34, 0.65)
		m.right_arm.rotation.x -= strength * 1.35
		m.right_arm.rotation.z -= strength * 0.5
		chest.rotation.y -= strength * 0.2
	m.mantle.rotation.x = -0.08 - m.motion * 0.16 + sin(m.clock * 2.2) * 0.018
	rig.ward.visible = alive and actor.shield > 0
	rig.ward_mat.emission_energy_multiplier = 2.8 + sin(m.clock * 3.0) * 0.35
	if alive and actor.shield > rig.previous_shield + 0.1:
		rig.pulse_left = 0.55
	rig.previous_shield = actor.shield
	rig.pulse_left = maxf(0, rig.pulse_left - delta) if alive and actor.shield > 0 else 0.0
	rig.pulse.visible = rig.pulse_left > 0
	var pulse_fraction: float = rig.pulse_left / 0.55
	rig.pulse.scale = Vector3.ONE * lerpf(1.6, 0.8, pulse_fraction)
	rig.pulse_mat.albedo_color.a = pulse_fraction * 0.75
	if active and actor.shield > 0 and actor.casting < 0:
		m.left_arm.rotation.x -= 0.2
