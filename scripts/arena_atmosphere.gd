extends Node3D
## Decorative layer: no bodies, areas, collision shapes, navigation or lights.
## Everything moving is shader-driven; static architecture batches by material.

const Geometry = preload("res://scripts/arena_geometry.gd")
const BannerShader = preload("res://shaders/sanctum_banner.gdshader")
const MoteShader = preload("res://shaders/sanctum_motes.gdshader")
const DebrisShader = preload("res://shaders/sanctum_debris.gdshader")
const StoneShader = preload("res://shaders/arena_stone.gdshader")

var _built := false
var _geo: RefCounted
var _stone: ShaderMaterial
var _dark: StandardMaterial3D
var _bronze: StandardMaterial3D
var _violet: StandardMaterial3D
var _gold: StandardMaterial3D

func build() -> void:
	if _built or DisplayServer.get_name() == "headless":
		return
	_built = true
	name = "SanctumAtmosphere"
	_geo = Geometry.new()
	_stone = ShaderMaterial.new()
	_stone.shader = StoneShader
	_stone.set_shader_parameter("stone_color", Color("3c354e"))
	_stone.set_shader_parameter("grain_scale", 0.75)
	_stone.set_shader_parameter("slate_texture", load("res://assets/environment/sanctum_slate.png"))
	_dark = _material("272034")
	_bronze = _material("675761", 0.55)
	_bronze.metallic = 0.55
	_violet = _material("9560e8", 0.75, 3.0)
	_gold = _material("d1b389", 0.75, 2.7)
	_build_banners()
	_build_watcher(Vector3(-47, -6, -59), 0.57, false)
	_build_watcher(Vector3(47, -6, -59), -0.57, true)
	_build_suspension_chains()
	_geo.finish(self)
	_geo = null
	_build_motes()
	_build_floating_debris()
	# These silhouettes should not cost extra shadow passes across the arena.
	for child in get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _material(html: String, roughness := 0.9, emission := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(html)
	result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.vertex_color_use_as_albedo = true
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = Color(html)
		result.emission_energy_multiplier = emission
	return result

func _line(material: Material, points: Array, width: float) -> void:
	# Geometry is a RefCounted instance, so literal arrays need explicit typing.
	var typed_points: Array[Vector3] = []
	typed_points.assign(points)
	_geo.line_3d(material, typed_points, width)

func _build_banners() -> void:
	var fabric := SurfaceTool.new()
	fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
	for direction in range(2):
		for side in [-1.0, 1.0]:
			for along in [-11.5, 11.5]:
				var center := Vector3(along, 7.0, side * 20.4) if direction == 0 else Vector3(side * 20.4, 7.0, along)
				var yaw := 0.0 if direction == 0 else PI * 0.5
				var basis := Basis(Vector3.UP, yaw)
				_geo.block(_bronze, center, Vector3(2.0, 0.11, 0.11), yaw)
				for end in [-1.0, 1.0]:
					var hook: Vector3 = center + basis * Vector3(end * 0.77, 0, 0)
					_line(_bronze, [hook, hook + Vector3(0, 0.8, 0)], 0.07)
					_geo.rock(_dark, hook + Vector3(0, -4.8, 0), Vector3(0.35, 6.0, 0.42), yaw, Color.WHITE, 5)
				# A subdivided mesh lets wind bend the fabric, with its top fixed.
				for row in range(16):
					for column in range(6):
						var uv_a := Vector2(float(column) / 6.0, float(row) / 16.0)
						var uv_b := Vector2(float(column + 1) / 6.0, float(row) / 16.0)
						var uv_c := Vector2(float(column + 1) / 6.0, float(row + 1) / 16.0)
						var uv_d := Vector2(float(column) / 6.0, float(row + 1) / 16.0)
						for uv in [uv_a, uv_c, uv_b, uv_a, uv_d, uv_c]:
							# The cut hem forms two long ceremonial points.
							var hem: float = (0.17 + 0.30 * absf(sin(uv.x * TAU))) * pow(uv.y, 10.0)
							fabric.set_uv(uv)
							fabric.set_normal(basis * Vector3.FORWARD)
							fabric.add_vertex(center + basis * Vector3((uv.x - 0.5) * 1.42, -0.12 - uv.y * 3.8 + hem, 0))
	var banner := MeshInstance3D.new()
	banner.name = "WindwovenCeremonialStandards"
	banner.mesh = fabric.commit()
	var banner_material := ShaderMaterial.new()
	banner_material.shader = BannerShader
	banner.material_override = banner_material
	banner.extra_cull_margin = 0.3
	add_child(banner)

func _build_watcher(origin: Vector3, yaw: float, gold: bool) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var glow := _gold if gold else _violet
	# Floating carved foundation and an ascending ceremonial stair.
	_geo.rock(_dark, origin + Vector3(0, -12, 0), Vector3(24, 14, 22), yaw, Color.WHITE, 9)
	_geo.rock(_stone, origin + Vector3(0, -3, 0), Vector3(23, 4, 21), yaw, Color.WHITE, 9)
	for step in range(5):
		_geo.block(_stone, origin + basis * Vector3(0, 0.45 + step * 0.48, 7.2 - step * 1.7), Vector3(17.5 - step * 1.1, 0.9, 2.1), yaw)
	_geo.block(_dark, origin + basis * Vector3(0, 3.4, -1.5), Vector3(11, 3.4, 9), yaw)
	_geo.block(_bronze, origin + basis * Vector3(0, 5.1, -1.5), Vector3(11.3, 0.3, 9.3), yaw)
	# A high throne frames the unmistakable seated shoulders/head/knees.
	_geo.block(_dark, origin + basis * Vector3(0, 10.6, -4.5), Vector3(11.5, 12.2, 1.5), yaw)
	for side in [-1.0, 1.0]:
		_geo.rock(_stone, origin + basis * Vector3(side * 5.7, 4.2, -3.8), Vector3(2.1, 15.6, 2.2), yaw, Color.WHITE, 6)
		_geo.block(_bronze, origin + basis * Vector3(side * 5.7, 15.8, -2.63), Vector3(0.11, 6.1, 0.11), yaw)
		_geo.rock(_stone, origin + basis * Vector3(side * 2.45, 2.5, 4.4), Vector3(3.2, 5.1, 3.2), yaw, Color.WHITE, 6)
		_geo.block(_stone, origin + basis * Vector3(side * 2.4, 2.75, 5.5), Vector3(3.3, 1.4, 3.3), yaw)
		_geo.rock(_stone, origin + basis * Vector3(side * 3.7, 8.3, -0.9), Vector3(3.0, 5.5, 4.0), yaw, Color.WHITE, 6)
		_geo.block(_stone, origin + basis * Vector3(side * 3.8, 8.5, 1.1), Vector3(2.3, 1.6, 5.3), yaw)
		_geo.rock(_bronze, origin + basis * Vector3(side * 3.8, 8.35, 3.4), Vector3(2.5, 1.1, 2.1), yaw, Color.WHITE, 6)
		# Narrow flanking obelisks make the silhouette a shrine, not a giant NPC.
		_geo.rock(_dark, origin + basis * Vector3(side * 10.0, 0, -3.0), Vector3(1.8, 13.0, 2.0), yaw, Color.WHITE, 5)
		_line(glow, [origin + basis * Vector3(side * 10.0, 5, -1.97), origin + basis * Vector3(side * 10.0, 10.0, -1.97)], 0.08)
	_geo.rock(_stone, origin + basis * Vector3(0, 5.1, 0.1), Vector3(7.8, 7.5, 6.0), yaw, Color.WHITE, 7)
	_geo.rock(_stone, origin + basis * Vector3(0, 12.4, -0.4), Vector3(5.0, 6.4, 4.8), yaw, Color.WHITE, 7)
	# A recessed mask and a single eye slit stay simple at distant scale.
	_geo.block(_dark, origin + basis * Vector3(0, 15.3, 2.15), Vector3(2.65, 2.9, 0.24), yaw)
	_line(glow, [origin + basis * Vector3(-0.86, 15.5, 2.29), origin + basis * Vector3(0.86, 15.5, 2.29)], 0.105)
	_geo.block(_bronze, origin + basis * Vector3(0, 13.55, 2.10), Vector3(3.5, 0.25, 0.7), yaw)
	for side in [-1.0, 1.0]:
		_line(_bronze, [origin + basis * Vector3(side * 2.7, 11.5, 2.45), origin + basis * Vector3(0, 9.0, 3.0), origin + basis * Vector3(side * 1.3, 6.3, 2.7)], 0.22)
	var gem: Array[Vector3] = [Vector3(0, 9.55, 3.0), Vector3(0.46, 8.75, 3.0), Vector3(0, 7.95, 3.0), Vector3(-0.46, 8.75, 3.0), Vector3(0, 9.55, 3.0)]
	var transformed: Array[Vector3] = []
	for point in gem:
		transformed.append(origin + basis * point)
	_line(glow, transformed, 0.065)
	# Broken aureole: original faceted stone wedges, warm/violet etched cores.
	for segment in range(24):
		if segment == 5 or segment == 17:
			continue
		var angle_a := TAU * float(segment) / 24.0 + 0.025
		var angle_b := TAU * float(segment + 1) / 24.0 - 0.025
		var a := Vector3(cos(angle_a) * 5.3, 16.0 + sin(angle_a) * 5.3, -3.0)
		var b := Vector3(cos(angle_b) * 5.3, 16.0 + sin(angle_b) * 5.3, -3.0)
		_line(_bronze, [origin + basis * a, origin + basis * b], 0.35)
		a.z += 0.23
		b.z += 0.23
		_line(glow, [origin + basis * a, origin + basis * b], 0.065)

func _chain_link(center: Vector3, forward: Vector3, up: Vector3, radius: float) -> void:
	# Twelve-sided physical-looking links, all committed to the bronze batch.
	var axis := forward.cross(up).normalized()
	for section in range(12):
		var a := TAU * float(section) / 12.0
		var b := TAU * float(section + 1) / 12.0
		var p := center + forward * cos(a) * radius + up * sin(a) * radius * 1.5
		var q := center + forward * cos(b) * radius + up * sin(b) * radius * 1.5
		var radial_a := (forward * cos(a) + up * sin(a)).normalized() * 0.065
		var radial_b := (forward * cos(b) + up * sin(b)).normalized() * 0.065
		var depth := axis * 0.065
		_geo.quad(_bronze, p + radial_a + depth, q + radial_b + depth, q - radial_b + depth, p - radial_a + depth)
		_geo.quad(_bronze, p - radial_a - depth, q - radial_b - depth, q + radial_b - depth, p + radial_a - depth)
		_geo.quad(_bronze, p + radial_a - depth, q + radial_b - depth, q + radial_b + depth, p + radial_a + depth)
		_geo.quad(_bronze, p - radial_a + depth, q - radial_b + depth, q - radial_b - depth, p - radial_a - depth)

func _build_suspension_chains() -> void:
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			for link in range(26):
				var t := float(link) / 25.0
				var position := Vector3(side * (20.7 + t * 8.4), -0.5 - sin(t * PI * 0.5) * 8.5, end * (14.0 + t * 3.0))
				var plane := Vector3(1, 0, 0) if link % 2 == 0 else Vector3(0, 0, 1)
				_chain_link(position, plane, Vector3.UP, 0.29)

func _build_motes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12964
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.45)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = quad
	instances.instance_count = 96
	for i in range(instances.instance_count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var along := rng.randf_range(-18, 18)
		var outside := side * rng.randf_range(19.1, 22.3)
		var position := Vector3(outside, rng.randf_range(-1.7, 0.3), along) if i % 4 < 2 else Vector3(along, rng.randf_range(-1.7, 0.3), outside)
		var size := rng.randf_range(0.055, 0.105)
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), position))
		instances.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 1.0 if i % 3 == 0 else 0.0, 1.0))
	var motes := MultiMeshInstance3D.new()
	motes.name = "DriftingPerimeterEmbers"
	motes.multimesh = instances
	var material := ShaderMaterial.new()
	material.shader = MoteShader
	motes.material_override = material
	motes.custom_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 12, 48))
	add_child(motes)

func _build_floating_debris() -> void:
	var geometry := Geometry.new()
	geometry.rock(_dark, Vector3(0, -0.5, 0), Vector3(1.5, 1.1, 1.3), 0.0, Color.WHITE, 6)
	var stone_mesh: ArrayMesh = (geometry.batches[_dark] as SurfaceTool).commit()
	var material := ShaderMaterial.new()
	material.shader = DebrisShader
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = stone_mesh
	instances.instance_count = 18
	var rng := RandomNumberGenerator.new()
	rng.seed = 829734
	for i in range(instances.instance_count):
		var angle := TAU * float(i) / float(instances.instance_count)
		var distance := rng.randf_range(34.0, 46.0)
		var position := Vector3(cos(angle) * distance, rng.randf_range(-5.5, 6.5), sin(angle) * distance)
		var size := rng.randf_range(0.5, 1.8)
		var orientation := Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), angle, rng.randf_range(-0.2, 0.2))).scaled(Vector3.ONE * size)
		instances.set_instance_transform(i, Transform3D(orientation, position))
		instances.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 1))
	var debris := MultiMeshInstance3D.new()
	debris.name = "LevitatingSanctumFragments"
	debris.multimesh = instances
	debris.material_override = material
	debris.custom_aabb = AABB(Vector3(-49, -9, -49), Vector3(98, 20, 98))
	add_child(debris)
