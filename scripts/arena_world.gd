extends Node3D
## The Cosmic Sanctum. Collision is shared with navigation; chipped stone,
## rubble and light effects are decorative and cannot snag players or cameras.

const BLUE = Color("62cfeb")
const GOLD = Color("e8be78")
const RED = Color("e77f78")
const Layout = preload("res://scripts/arena_layout.gd")
const Geometry = preload("res://scripts/arena_geometry.gd")
const StoneShader = preload("res://shaders/arena_stone.gdshader")
const EnergyShader = preload("res://shaders/arena_energy.gdshader")

var _art: Node3D
var _geo: RefCounted
var _stone: ShaderMaterial
var _dark_stone: ShaderMaterial
var _floor_stone: ShaderMaterial
var _trim: ShaderMaterial
var _terrace_stone: ShaderMaterial
var _rune: ShaderMaterial
var _violet: ShaderMaterial
var _white_energy: ShaderMaterial
var _amber: ShaderMaterial
var _quality_surround := false

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# See champion_model.paint(): unshaded caps at the albedo value, so the
		# bloom pass never sees it. Emission is what makes it a light source.
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.4
	return mat

func _rock_material(color: String, scale_value := 1.0, surface_kind := 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = StoneShader
	mat.set_shader_parameter("stone_color", Color(color))
	mat.set_shader_parameter("grain_scale", scale_value)
	mat.set_shader_parameter("surface_kind", surface_kind)
	mat.set_shader_parameter("slate_texture", load("res://assets/environment/sanctum_slate.png"))
	return mat

func _energy(color: String, strength := 1.3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = EnergyShader
	mat.set_shader_parameter("energy_color", Color(color))
	mat.set_shader_parameter("strength", strength)
	return mat

func _box_collision(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ArenaCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.position = pos
	body.add_child(collider)
	add_child(body)

func _build_collision() -> void:
	_box_collision(Vector3(0, -0.4, 0), Vector3(36, 0.8, 36))
	for pos in Layout.cover_centers():
		_box_collision(pos + Vector3.UP * 0.2, Layout.COVER_BASE_SIZE)
		_box_collision(pos + Vector3.UP * Layout.COVER_BODY_SIZE.y * 0.5, Layout.COVER_BODY_SIZE)
	for edge in [-Layout.HALF_EXTENT, Layout.HALF_EXTENT]:
		_box_collision(Vector3(edge, 1.5, 0), Vector3(0.7, 3, 36.7))
		_box_collision(Vector3(0, 1.5, edge), Vector3(36.7, 3, 0.7))
	var width: float = Layout.TERRACE_OUTER - Layout.TERRACE_INNER
	for side in [-1.0, 1.0]:
		var x: float = side * (Layout.TERRACE_INNER + width * 0.5)
		_box_collision(Vector3(x, 0.6, 0), Vector3(width, 1.2, 12))
		for end in [-1.0, 1.0]:
			var body := StaticBody3D.new()
			body.name = "TerraceRamp"
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for xx in [-width * 0.5, width * 0.5]:
				points.append(Vector3(x + xx, -0.1, end * Layout.RAMP_END))
				points.append(Vector3(x + xx, -0.1, end * Layout.TERRACE_HALF_LENGTH))
				points.append(Vector3(x + xx, 0, end * Layout.RAMP_END))
				points.append(Vector3(x + xx, Layout.TERRACE_HEIGHT, end * Layout.TERRACE_HALF_LENGTH))
			shape.points = points
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			add_child(body)

func build_arena() -> void:
	_build_collision()
	# Dedicated servers need identical colliders, without generating art.
	if DisplayServer.get_name() == "headless":
		return
	_art = Node3D.new()
	_art.name = "CosmicSanctum"
	add_child(_art)
	_geo = Geometry.new()
	_stone = _rock_material("555062")
	_dark_stone = _rock_material("302c42", 0.8, 4)
	_floor_stone = _rock_material("77717e", 1.15, 1)
	_terrace_stone = _rock_material("546e88", 1.1, 2)
	_trim = _rock_material("91818a", 1.0, 3)
	_rune = _energy("8b4fdc", 0.95)
	_violet = _energy("8736ec", 1.1)
	_white_energy = _energy("d6b8ff", 1.4)
	_amber = _energy("ffd79a", 1.2)
	var slice = load("res://scripts/sanctum_slice.gd").new()
	slice.name = "QualitySlice"
	_art.add_child(slice)
	var has_authored_cover: bool = slice.build()
	_quality_surround = slice.has_surround
	_build_floor()
	if not _quality_surround:
		_build_terraces()
	for pos in Layout.cover_centers():
		if has_authored_cover:
			continue
		_build_cover(pos)
	_build_perimeter()
	_build_foundation()
	_build_gateway(-1.0)
	_build_gateway(1.0)
	_build_debris()
	_build_inscriptions()
	_geo.finish(_art)
	_geo = null
	var sky = load("res://scripts/arena_sky.gd").new()
	_art.add_child(sky)
	sky.build_sky()
	var atmosphere = load("res://scripts/arena_atmosphere.gd").new()
	_art.add_child(atmosphere)
	atmosphere.build()
	if not OS.get_cmdline_user_args().has("--sanctum-base") and not OS.get_cmdline_user_args().has("--sanctum-original"):
		load("res://scripts/sanctum_graphics.gd").apply(_art, true)

func _build_floor() -> void:
	_geo.block(_dark_stone, Vector3(0, -0.23, 0), Vector3(36, 0.4, 36))
	# Individual chipped slabs have real edges but level tops for movement.
	for row in range(18):
		for col in range(18):
			var x := -17.0 + col * 2.0
			var z := -17.0 + row * 2.0
			var shade: float = _geo.rng.randf_range(0.82, 1.13)
			var chamfer: float = _geo.rng.randf_range(0.06, 0.24)
			var ext := Vector2(_geo.rng.randf_range(0.945, 0.987), _geo.rng.randf_range(0.945, 0.985))
			if _quality_surround:
				# Consume the same crack randomness so the rest of the arena is stable.
				_geo.rng.randf()
				continue
			var outline: Array[Vector3] = [Vector3(-ext.x + chamfer, 0, -ext.y), Vector3(ext.x - chamfer, 0, -ext.y),
				Vector3(ext.x, 0, -ext.y + chamfer), Vector3(ext.x, 0, ext.y - chamfer),
				Vector3(ext.x - chamfer, 0, ext.y), Vector3(-ext.x + chamfer, 0, ext.y),
				Vector3(-ext.x, 0, ext.y - chamfer), Vector3(-ext.x, 0, -ext.y + chamfer)]
			var center := Vector3(x, 0.005, z)
			for i in range(8):
				var a := center + outline[i]
				var b := center + outline[(i + 1) % 8]
				_geo.triangle(_floor_stone, center, b, a, Color(shade, shade, shade))
				_geo.quad(_stone, a, b, b + Vector3.DOWN * 0.055, a + Vector3.DOWN * 0.055)
			if _geo.rng.randf() < 0.22:
				var crack: Array[Vector3] = [center + Vector3(-0.95, 0.007, -0.65), center + Vector3(-0.15, 0.007, -0.22),
					center + Vector3(0.22, 0.007, 0.27), center + Vector3(0.72, 0.007, 0.95)]
				_geo.ribbon(_dark_stone, crack, 0.024)
	# Worn celestial inlay stays quiet behind the combat effects.
	for radius in [3.5, 3.65, 4.15]:
		_geo.ring(_trim, Vector3(0, 0.021, 0), radius, 0.045)
	for i in range(12):
		var angle := TAU * i / 12.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		var center := direction * 3.88 + Vector3.UP * 0.023
		var mark: Array[Vector3] = [center - tangent * 0.09 - direction * 0.1, center + direction * 0.1, center + tangent * 0.09 - direction * 0.1]
		_geo.ribbon(_trim, mark, 0.033)
	for i in range(8):
		var angle := TAU * i / 8.0
		var a := Vector3(cos(angle), 0, sin(angle))
		var b := Vector3(-sin(angle), 0, cos(angle))
		var y := Vector3.UP * 0.022
		_geo.triangle(_trim, a * 2.7 + y, a * 0.65 + b * 0.25 + y, a * 0.8 + y)
		_geo.triangle(_stone, a * 2.7 + y, a * 0.8 + y, a * 0.65 - b * 0.25 + y)
	for side in [-1.0, 1.0]:
		var mat := _energy("65bdd1" if side > 0 else "d79ba5", 0.9)
		_geo.ring(_trim, Vector3(0, 0.025, side * 12), 2.5, 0.08, 0, TAU, 64)
		_geo.ring(mat, Vector3(0, 0.027, side * 12), 2.35, 0.022, 0, TAU, 64)
		for x in [-2.9, 2.9]:
			_geo.block(_trim, Vector3(x, 0.015, side * 12), Vector3(0.15, 0.025, 0.5))

func _build_terraces() -> void:
	var width: float = Layout.TERRACE_OUTER - Layout.TERRACE_INNER
	for side in [-1.0, 1.0]:
		var x: float = side * (Layout.TERRACE_INNER + width * 0.5)
		_geo.block(_stone, Vector3(x, 0.56, 0), Vector3(width, 1.12, 12))
		for z in range(-5, 6, 2):
			for dx in [-1.75, 0.0, 1.75]:
				_geo.block(_terrace_stone, Vector3(x + dx, 1.15, z), Vector3(1.72, 0.1, 1.96))
		_geo.block(_trim, Vector3(side * 12.4, 1.17, 0), Vector3(0.20, 0.08, 12))
		for end in [-1.0, 1.0]:
			for step in range(12):
				var height := (step + 1) * 0.1
				var z: float = end * (10.0 - (step + 0.5) / 3.0)
				_geo.block(_terrace_stone, Vector3(x, height * 0.5 - 0.018, z), Vector3(width, height - 0.036, 0.331))
				_geo.block(_trim, Vector3(x, height - 0.017, z + end * 0.14), Vector3(width, 0.027, 0.035))
			for i in range(4):
				var z: float = end * (9.5 - i)
				var base := (i + 0.5) * 0.3
				_geo.rock(_stone, Vector3(side * 17.8, base, z), Vector3(0.8, 0.7, 1.2))

func _build_cover(pos: Vector3) -> void:
	# Match the existing 4.4 x 3.8 x 2.8 collision all the way to its ends.
	# Broken upper crests are decorative; the continuous core makes LOS clear.
	_geo.block(_stone, pos + Vector3.UP * 0.2, Layout.COVER_BASE_SIZE)
	_geo.block(_stone, pos + Vector3.UP * 1.9, Layout.COVER_BODY_SIZE)
	for i in range(7):
		var x := -1.86 + i * 0.62
		var h: float = [0.52, 0.16, 0.34, 0.12, 0.21, 0.46, 0.18][i]
		_geo.rock(_stone, pos + Vector3(x, 3.72, 0.08), Vector3(0.74, h, 2.55), 0.025 * (i-3))
	# Bronze foot and shoulder straps distinguish constructed ruins from cliffs.
	for side in [-1.0, 1.0]:
		var z: float = pos.z + side * 1.408
		_geo.block(_trim, Vector3(pos.x, 0.44, z), Vector3(4.4, 0.075, 0.018))
		for x in [-1.85, 1.85]:
			_geo.block(_trim, Vector3(pos.x + x, 1.84, z), Vector3(0.052, 2.7, 0.022))
		_geo.block(_dark_stone, Vector3(pos.x, 1.95, z), Vector3(0.72, 1.55, 0.02))
		var front: float = z + side * 0.015
		var glyph: Array[Vector3] = [Vector3(pos.x, 2.53, front), Vector3(pos.x-0.24, 2.12, front),
			Vector3(pos.x, 1.81, front), Vector3(pos.x+0.24, 2.12, front), Vector3(pos.x, 2.53, front)]
		_geo.line_3d(_rune, glyph, 0.027)
		var stem: Array[Vector3] = [Vector3(pos.x, 2.15, front), Vector3(pos.x, 1.38, front)]
		_geo.line_3d(_rune, stem, 0.022)
		for x in [-0.16, 0.16]:
			var tick: Array[Vector3] = [Vector3(pos.x+x, 1.62, front), Vector3(pos.x, 1.46, front)]
			_geo.line_3d(_rune, tick, 0.018)

func _build_perimeter() -> void:
	for side in [-1.0, 1.0]:
		for along in range(-16, 18, 3):
			for direction in [0, 1]:
				if _quality_surround:
					continue
				var pos := Vector3(float(along), 0, side * 18.3) if direction == 0 else Vector3(side * 18.3, 0, float(along))
				var size := Vector3(3.08, 3.1, 1.25) if direction == 0 else Vector3(1.25, 3.1, 3.08)
				_geo.block(_stone, pos + Vector3.UP * 1.45, size)
				_geo.rock(_stone, pos + Vector3.UP * 2.3, Vector3(size.x, 1.1, size.z))
				_geo.block(_trim, pos + Vector3.UP * 0.18, Vector3(size.x + 0.08, 0.23, size.z + 0.08))
		for along in [-15.0, -9.0, 0.0, 9.0, 15.0]:
			for direction in [0, 1]:
				var pos := Vector3(along, 0, side * 18.8) if direction == 0 else Vector3(side * 18.8, 0, along)
				var height: float = 5.4 + _geo.rng.randf_range(-0.6, 1.3)
				_geo.rock(_dark_stone, pos, Vector3(1.9, height, 1.8), 0.15)
				_geo.rock(_stone, pos + Vector3(0.25, 0, -0.15), Vector3(1.0, height + 0.4, 1.1), -0.12)
				var inward := Vector3(0, 0, -side) if direction == 0 else Vector3(-side, 0, 0)
				var lamp_pos := pos + inward * 1.50
				lamp_pos.y = Layout.surface_height(lamp_pos)
				_build_votive(lamp_pos, direction == 0 and along == 0.0)

func _build_votive(pos: Vector3, casts_light: bool) -> void:
	_geo.block(_dark_stone, pos + Vector3.UP * 0.22, Vector3(0.95, 0.44, 0.8))
	_geo.block(_trim, pos + Vector3.UP * 0.44, Vector3(1.05, 0.12, 0.9))
	for i in range(3):
		var offset := Vector3((i - 1) * 0.22, 0.5, 0)
		_geo.rock(_amber, pos + offset, Vector3(0.14, 0.38 + i * 0.09, 0.14), 0, Color.WHITE, 5)
	if casts_light:
		var light := OmniLight3D.new()
		light.position = pos + Vector3.UP * 1.2
		light.light_color = Color("ffc987")
		light.light_energy = 2.0
		light.omni_range = 6.5
		_art.add_child(light)

func _build_foundation() -> void:
	_geo.block(_dark_stone, Vector3(0, -4.5, 0), Vector3(36.8, 8.5, 36.8))
	for side in [-1.0, 1.0]:
		for i in range(13):
			var along := -20.0 + i * 3.3
			for direction in [0, 1]:
				var depth: float = _geo.rng.randf_range(7.0, 13.0)
				var pos := Vector3(along, -depth, side * 19.0) if direction == 0 else Vector3(side * 19.0, -depth, along)
				_geo.rock(_dark_stone, pos, Vector3(4.3, depth + 0.2, 4.0), _geo.rng.randf_range(-0.25, 0.25))
				if i % 2 == 0:
					var crack: Array[Vector3] = []
					for j in range(7):
						var drift: float = _geo.rng.randf_range(-0.32, 0.32)
						var y := -float(j) * 1.65
						crack.append(Vector3(along + drift, y, side * 20.72) if direction == 0 else Vector3(side * 20.72, y, along + drift))
					_geo.line_3d(_violet, crack, 0.13)
					_geo.line_3d(_white_energy, crack, 0.034)
	# Leave breathing room for the large landscape shelves beyond the island.
	for i in range(12):
		var angle := i * TAU / 12.0
		var radius: float = _geo.rng.randf_range(29.0, 43.0)
		var pos := Vector3(cos(angle) * radius, _geo.rng.randf_range(-13.0, -8.0), sin(angle) * radius)
		var height: float = _geo.rng.randf_range(5.0, 14.0)
		_geo.rock(_dark_stone, pos, Vector3(_geo.rng.randf_range(3.0, 6.0), height, _geo.rng.randf_range(3.0, 6.0)), angle)
		if i % 3 == 0:
			_geo.rock(_stone, pos + Vector3(1.5, -0.4, 0), Vector3(1.7, height + 1.5, 2.6), angle + 0.2)
			var crack: Array[Vector3] = [pos + Vector3(0, height, 0), pos + Vector3(-0.3, height * 0.7, 1.5),
				pos + Vector3(0.4, height * 0.4, 2), pos + Vector3(0, -2, 2.0)]
			_geo.line_3d(_violet, crack, 0.1)

func _build_gateway(side: float) -> void:
	var z := side * 23.0
	_geo.rock(_dark_stone, Vector3(0, -5, z), Vector3(17, 6, 9), 0)
	_geo.block(_stone, Vector3(0, 0.7, z), Vector3(13.0, 1.0, 6.5))
	for i in range(8):
		_geo.block(_floor_stone, Vector3(0, i * 0.15, z - side * (4.0 - i * 0.4)), Vector3(7.0, 0.15, 0.4))
	# Fractured horseshoe arch, with its crown torn open around the rift.
	for arm_side in [-1.0, 1.0]:
		for i in range(12):
			var a := -0.86 + i * 0.178
			var b := a + 0.168
			var outer: float = 6.6 + _geo.rng.randf_range(-0.13, 0.18)
			var inner := 5.2
			var front := z - 0.9
			var back := z + 0.9
			var points: Array[Vector3] = []
			for zz in [front, back]:
				for radius in [inner, outer]:
					for angle in [a, b]:
						points.append(Vector3(arm_side * cos(angle) * radius, 6.0 + sin(angle) * radius, zz))
			_geo.quad(_stone, points[0], points[1], points[3], points[2])
			_geo.quad(_stone, points[4], points[6], points[7], points[5])
			_geo.quad(_dark_stone, points[0], points[4], points[5], points[1])
			_geo.quad(_stone, points[2], points[3], points[7], points[6])
			_geo.quad(_stone, points[1], points[5], points[7], points[3])
			_geo.quad(_stone, points[0], points[2], points[6], points[4])
			var rune: Array[Vector3] = []
			for angle in [a + 0.03, b - 0.03]:
				rune.append(Vector3(arm_side * cos(angle) * (inner + 0.3), 6.0 + sin(angle) * (inner + 0.3), z - side * 0.92))
			_geo.line_3d(_violet, rune, 0.048)
		_geo.rock(_dark_stone, Vector3(arm_side * 7.3, 0, z + 0.4), Vector3(2.3, 9.0, 2.8), arm_side * 0.15)
	for strand in range(3):
		var bolt: Array[Vector3] = []
		for i in range(13):
			bolt.append(Vector3(sin(i * 1.9 + strand * 3.0) * (0.3 + strand * 0.16), 1.2 + i * 1.25, z + strand * 0.18))
		_geo.line_3d(_violet, bolt, 0.15)
		_geo.line_3d(_white_energy, bolt, 0.034)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4, z)
	light.light_color = Color("994cff")
	light.light_energy = 3.0
	light.omni_range = 12
	_art.add_child(light)

func _build_debris() -> void:
	# Rubble hugs solid footprints, keeping open lanes visually unambiguous.
	for i in range(120):
		var side := -1.0 if i % 2 == 0 else 1.0
		var along: float = _geo.rng.randf_range(-17.0, 17.0)
		var inset: float = _geo.rng.randf_range(16.7, 17.55)
		var pos := Vector3(along, 0, side * inset) if i % 3 == 0 else Vector3(side * inset, 0, along)
		pos.y = Layout.surface_height(pos) + 0.01
		var scale_value: float = _geo.rng.randf_range(0.10, 0.36)
		_geo.rock(_stone, pos, Vector3(scale_value * 1.5, scale_value, scale_value), _geo.rng.randf() * TAU, Color.WHITE, 5)

func _build_inscriptions() -> void:
	# A restrained inlay circuit follows existing terraces; no new collision.
	# Marks are flush with the surface and never resemble extra cover objects.
	for side in [-1.0, 1.0]:
		var x: float = side * 12.40
		for z in [-4.5, -1.5, 1.5, 4.5]:
			var mark: Array[Vector3] = [Vector3(x, 1.222, z-0.21), Vector3(x+side*0.14, 1.222, z),
				Vector3(x, 1.222, z+0.21)]
			_geo.ribbon(_rune, mark, 0.022)
	# Broken arcs, rather than a solid glowing combat circle.
	for i in range(8):
		var start := TAU * i / 8.0 + 0.07
		_geo.ring(_rune, Vector3(0, 0.024, 0), 3.88, 0.018, start, start+0.12, 8)
	# Sparse energy leaking through the non-playable faces of the outer wall.
	for side in [-1.0, 1.0]:
		for x in [-12.0, 12.0]:
			var z: float = side * 17.662
			var vein: Array[Vector3] = [Vector3(x-0.3, 2.8, z), Vector3(x-0.17, 2.3, z),
				Vector3(x+0.12, 1.97, z), Vector3(x-0.05, 1.42, z), Vector3(x+0.28, 0.7, z)]
			_geo.line_3d(_violet, vein, 0.035)
