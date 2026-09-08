extends Node3D

# Original faceted character art, built in engine. Visual-only joints never
# move the CharacterBody or its shared 0.42 m collision capsule.
var torso: MeshInstance3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var mantle: Node3D
var halo: Node3D
var focus_gem: Node3D
var materials: Array[StandardMaterial3D] = []
var colors: Array[Color] = []
var clock := 0.0
var stride := 0.0
var motion := 0.0
var previous_position := Vector3.ZERO
var initialized := false
var archetype := ""
var vanguard: Dictionary = {}
const VanguardArt = preload("res://scripts/vanguard_art.gd")
const EmberArt = preload("res://scripts/ember_art.gd")
var ember_art: RefCounted

func paint(hex: String, luminous: bool = false, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.metallic = metal
	mat.roughness = 0.48 if metal > 0.0 else 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if luminous:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Unshaded is only ever as bright as its albedo, so it never crosses the
		# environment's glow threshold. Emission pushes it into HDR, which is what
		# makes trim and runes read as light rather than as pale paint.
		mat.emission_enabled = true
		mat.emission = Color(hex)
		mat.emission_energy_multiplier = 2.1
	materials.append(mat)
	colors.append(mat.albedo_color)
	return mat

func joint(parent: Node3D, at: Vector3, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node)
	return node

func piece(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func block(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent, mesh, at, mat)

# Each ring is (height, half-width, half-depth). Flat normals create broad
# deliberate planes rather than the smooth plastic capsule silhouette.
func form(parent: Node3D, at: Vector3, rings: Array[Vector3], mat: Material, sides: int = 8) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size() - 1):
		for side in range(sides):
			var a := TAU * float(side) / sides + PI / 8.0
			var b := TAU * float(side + 1) / sides + PI / 8.0
			var lo := rings[r]
			var hi := rings[r + 1]
			var p := Vector3(cos(a) * lo.y, lo.x, sin(a) * lo.z)
			var q := Vector3(cos(a) * hi.y, hi.x, sin(a) * hi.z)
			var s := Vector3(cos(b) * lo.y, lo.x, sin(b) * lo.z)
			var t := Vector3(cos(b) * hi.y, hi.x, sin(b) * hi.z)
			for vertex in [p, q, s, s, q, t]:
				surface.add_vertex(vertex)
	for ring_index in [0, rings.size() - 1]:
		var ring := rings[ring_index]
		for side in range(sides):
			var a := TAU * float(side) / sides + PI / 8.0
			var b := TAU * float(side + 1) / sides + PI / 8.0
			var p := Vector3(cos(a) * ring.y, ring.x, sin(a) * ring.z)
			var q := Vector3(cos(b) * ring.y, ring.x, sin(b) * ring.z)
			for vertex in [Vector3(0, ring.x, 0), p if ring_index == 0 else q, q if ring_index == 0 else p]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return piece(parent, surface.commit(), at, mat)

func gem(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return form(parent, at, [Vector3(-size.y * 0.5, 0, 0), Vector3(0, size.x * 0.5, size.z * 0.5), Vector3(size.y * 0.5, 0, 0)], mat, 4)

func ring(parent: Node3D, at: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 24
	mesh.ring_segments = 6
	return piece(parent, mesh, at, mat)

func build(champion: String, team_color: Color) -> void:
	archetype = champion
	name = "ChampionModel"
	if champion == "Ember":
		ember_art = EmberArt.new()
		ember_art.build(self, team_color)
		return
	if champion == "Vanguard":
		VanguardArt.build(self, team_color)
		return
	var identity := paint(team_color.to_html(false))
	var dark := paint("171a30")
	var cloth := paint("302647" if champion == "Ember" else "293749")
	var gold := paint("d5a957", false, 0.45)
	var steel := paint("9badc3", false, 0.65)
	var glow := paint("ffb343" if champion == "Ember" else ("a3ffe1" if champion == "Luminary" else "ffe2a0"), true)
	var ivory := paint("e4e5dc")
	# Broad colored cloth/armor on front, back and shoulders carries team identity.
	left_leg = joint(self, Vector3(-0.17, 0.78, 0), "LeftLeg")
	right_leg = joint(self, Vector3(0.17, 0.78, 0), "RightLeg")
	for leg in [left_leg, right_leg]:
		form(leg, Vector3.ZERO, [Vector3(-0.6, 0.12, 0.13), Vector3(-0.3, 0.1, 0.1), Vector3(0, 0.14, 0.14)], steel if champion == "Vanguard" else dark)
		block(leg, Vector3(0, -0.67, -0.065), Vector3(0.25, 0.19, 0.39), dark)
		if champion == "Vanguard":
			gem(leg, Vector3(0, -0.3, -0.13), Vector3(0.2, 0.27, 0.08), gold)
	torso = form(self, Vector3.ZERO, [Vector3(0.73, 0.24, 0.18), Vector3(1.02, 0.27, 0.19), Vector3(1.36, 0.37 if champion == "Vanguard" else 0.29, 0.22), Vector3(1.47, 0.25, 0.17)], identity)
	form(self, Vector3.ZERO, [Vector3(0.89, 0.275, 0.205), Vector3(0.96, 0.28, 0.205)], gold)
	gem(self, Vector3(0, 1.24, -0.222), Vector3(0.19, 0.29, 0.075), gold)
	gem(self, Vector3(0, 1.24, -0.265), Vector3(0.095, 0.15, 0.055), glow)
	left_arm = joint(self, Vector3(-0.36, 1.38, 0), "LeftArm")
	right_arm = joint(self, Vector3(0.36, 1.38, 0), "RightArm")
	for arm in [left_arm, right_arm]:
		form(arm, Vector3.ZERO, [Vector3(-0.54, 0.095, 0.095), Vector3(-0.29, 0.11, 0.11), Vector3(0, 0.16, 0.15)], steel if champion == "Vanguard" else cloth)
		form(arm, Vector3.ZERO, [Vector3(-0.5, 0.12, 0.12), Vector3(-0.35, 0.125, 0.125)], gold if champion == "Vanguard" else identity)
		gem(arm, Vector3(0, -0.57, -0.02), Vector3(0.2, 0.24, 0.2), dark if champion == "Vanguard" else ivory)
		form(arm, Vector3.ZERO, [Vector3(-0.13, 0.22, 0.21), Vector3(0.08, 0.24 if champion == "Vanguard" else 0.18, 0.2), Vector3(0.17, 0.07, 0.09)], gold)
		form(arm, Vector3(0, 0.03, 0), [Vector3(-0.12, 0.2, 0.2), Vector3(0.08, 0.2, 0.17), Vector3(0.15, 0.05, 0.07)], identity)
	# Head and luminous eyes point along local -Z, the combat facing direction.
	form(self, Vector3(0, 1.63, 0), [Vector3(-0.17, 0.13, 0.12), Vector3(0.05, 0.19, 0.17), Vector3(0.2, 0.12, 0.1)], steel if champion == "Vanguard" else dark)
	for x in [-0.065, 0.065]:
		block(self, Vector3(x, 1.65, -0.164), Vector3(0.067, 0.027, 0.025), glow)
	mantle = joint(self, Vector3(0, 1.4, 0.16), "Mantle")
	if champion != "Ember":
		# Floating vestments and six separated celestial feathers, not a cape.
		form(self, Vector3.ZERO, [Vector3(0.18, 0.33, 0.24), Vector3(0.45, 0.3, 0.22), Vector3(0.91, 0.22, 0.17)], ivory)
		for side in [-1.0, 1.0]:
			var sash := block(self, Vector3(side * 0.12, 0.6, -0.23), Vector3(0.11, 0.76, 0.03), identity)
			sash.rotation.z = side * -0.15
			for i in range(3):
				var feather := gem(mantle, Vector3(side * (0.37 + i * 0.13), 0.02 - i * 0.17, 0.04), Vector3(0.16, 0.68 - i * 0.07, 0.11), ivory)
				feather.rotation.z = side * (-0.6 - i * 0.15)
				gem(mantle, Vector3(side * (0.34 + i * 0.13), -0.2 - i * 0.17, -0.005), Vector3(0.085, 0.22, 0.075), glow)
		gem(self, Vector3(0, 1.8, -0.12), Vector3(0.11, 0.28, 0.08), gold)
		halo = joint(self, Vector3(0, 1.98, 0.06), "CelestialHalo")
		ring(halo, Vector3.ZERO, 0.28, 0.025, glow)
		halo.rotation.x = 0.2
		for i in range(4):
			var angle := i * PI * 0.5
			gem(halo, Vector3(cos(angle) * 0.28, 0, sin(angle) * 0.28), Vector3(0.085, 0.14, 0.085), gold)
		focus_gem = gem(left_arm, Vector3(-0.06, -0.4, -0.3), Vector3(0.23, 0.31, 0.23), glow)
		var scepter := joint(right_arm, Vector3(0.04, -0.5, -0.12), "DawnScepter")
		form(scepter, Vector3.ZERO, [Vector3(-0.25, 0.027, 0.027), Vector3(0.66, 0.027, 0.027)], gold, 6)
		var head := ring(scepter, Vector3(0, 0.75, 0), 0.13, 0.025, gold)
		head.rotation.x = PI * 0.5
		gem(scepter, Vector3(0, 0.75, 0), Vector3(0.12, 0.24, 0.12), glow)

func animate(delta: float, actor: CharacterBody3D) -> void:
	if ember_art != null:
		ember_art.animate(self, delta, actor)
		return
	clock += delta
	var travel := 0.0
	if initialized and delta > 0.0:
		var difference := actor.global_position - previous_position
		difference.y = 0
		# Ignore teleports and snapshot corrections when estimating a walk cycle.
		if difference.length() < 1.0:
			travel = difference.length() / delta
	previous_position = actor.global_position
	initialized = true
	motion = move_toward(motion, clampf(travel / 6.5, 0, 1), delta * 8)
	stride += delta * (3.0 + motion * 9.0)
	var alive: bool = actor.hp > 0
	var casting: bool = actor.casting >= 0 and alive
	var stunned: bool = actor.stunned > 0 and alive
	var swing := sin(stride) * motion * 0.55 if alive and not stunned else 0.0
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -1.0 if casting else -swing * 0.55
	right_arm.rotation.x = -0.65 if casting else swing * 0.4
	left_arm.rotation.z = 0.12
	right_arm.rotation.z = -0.12
	mantle.rotation.x = -0.13 - motion * 0.18 + sin(clock * 2.0) * 0.035
	position.y = (0.07 + sin(clock * 2.2) * 0.035 if archetype == "Luminary" else absf(sin(stride)) * motion * 0.035) if alive else 0.0
	rotation.z = sin(clock * 15.0) * 0.035 if stunned else 0.0
	rotation.x = move_toward(rotation.x, 0.0 if alive else -PI * 0.5, delta * 5)
	if halo:
		halo.rotation.y += delta * 0.45
	if focus_gem:
		focus_gem.rotation.y += delta * (2.5 if casting else 0.7)
	if archetype == "Vanguard":
		VanguardArt.animate(self, delta, actor, swing)
	for i in range(materials.size()):
		materials[i].albedo_color = Color.WHITE if actor.flash > 0 else (colors[i] if alive else colors[i].lerp(Color("333744"), 0.8))

# Called only by a confirmed damage event, including the same RPC on clients.
func present_strike() -> void:
	if archetype == "Vanguard" and not vanguard.is_empty():
		vanguard.attack = 0.34
