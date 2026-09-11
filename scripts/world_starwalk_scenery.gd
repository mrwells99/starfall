extends Node3D
## World-only scenery for the vertical Starwalk. Every mesh is decorative:
## the full jump corridor stays clear, and this node creates no physics objects.
const Geometry = preload("res://scripts/arena_geometry.gd")
const CENTER := Vector3(60, 0, 0)
const ECLIPSE := Vector3(102, 68, -38)

var _options
var _orbits: Array[Node3D] = []
var _orbit_speeds: Array[float] = []
var _energy_materials: Array[ShaderMaterial] = []
var _reduced := false

func build(course) -> void:
	name = "StarwalkCosmos"
	_options = course.game.player_options
	var stone: Material = course.game._rock_material("252038", 0.8, 4)
	var pale: Material = course.game._rock_material("666278", 0.7, 2)
	var bronze: Material = course.game._rock_material("a28759", 0.85, 3)
	var cyan: Material = _light("65eaff", 1.5)
	var violet: Material = _light("a377ff", 1.15)
	var magenta: Material = _light("ff6cde", 1.2)
	var gold: Material = _light("ffce79", 1.55)
	var white: Material = _light("d8f8ff", 1.7)
	var dim: Material = _light("51457e", 0.35)
	var geo = Geometry.new()
	_build_spine(geo, stone, bronze, cyan, violet, gold)
	_build_ruins(geo, stone, pale, bronze, cyan, violet, gold)
	_build_constellations(geo, cyan, violet, magenta, gold, white, dim)
	geo.finish(self)
	_build_eclipse(stone, cyan, magenta, gold, white, dim)
	_build_orbit(34.0, 30.0, Vector3(0.42, 0.0, 0.18), cyan, bronze, 0.014)
	_build_orbit(38.0, 51.0, Vector3(-0.48, 0.45, 0.22), violet, bronze, -0.010)
	_build_orbit(31.0, 80.0, Vector3(0.30, -0.3, -0.18), gold, bronze, 0.018)
	_build_shards(stone, cyan, violet, gold)
	_set_reduced(bool(_options.reduced_effects) if _options != null else false)

func _light(hex_color: String, strength: float) -> ShaderMaterial:
	# An opaque emissive surface has no transparent sorting/overdraw stack.
	# Unlike the shared energy shader, all motion freezes in reduced effects.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 hue : source_color;
uniform float gain = 1.5;
uniform float motion = 1.0;
varying vec3 location;
void vertex() { location = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float breath = 0.96 + 0.04 * sin(TIME * 0.28 * motion + location.y * 0.09);
	ALBEDO = hue.rgb * 0.08;
	ROUGHNESS = 0.85;
	EMISSION = hue.rgb * gain * breath;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("hue", Color(hex_color))
	mat.set_shader_parameter("gain", strength)
	_energy_materials.append(mat)
	return mat

func _build_spine(geo, stone: Material, bronze: Material, cyan: Material, violet: Material, gold: Material) -> void:
	# A shattered nine-storey relic, strictly inside the spiral's central void.
	for section in range(3):
		var y: float = [2.0, 34.0, 63.0][section]
		var height: float = [29.0, 25.0, 23.0][section]
		var radius: float = [4.1, 3.5, 2.6][section]
		var glow: Material = [cyan, violet, gold][section]
		var twist := section * 0.20
		_prism(geo, stone, CENTER + Vector3.UP * y, radius, height, twist)
		# Three broad carved ribs leave the luminous central channel exposed.
		for side in range(6):
			var angle := side * TAU / 6.0 + twist
			var radial := Vector3(cos(angle), 0, sin(angle))
			var tangent := Vector3(-radial.z, 0, radial.x)
			var start := CENTER + radial * (radius + 0.04) + Vector3.UP * y
			var rib: Array[Vector3] = [start, start + Vector3.UP * height * 0.62 - radial * radius * 0.185, start + Vector3.UP * height * 0.86 - radial * radius * 0.26, CENTER + Vector3.UP * (y + height)]
			geo.line_3d(bronze, rib, 0.15)
			# Jagged fault lines light the faces without washing out the stone.
			var fissure: Array[Vector3] = [start + tangent * 0.5 + Vector3.UP * 2, start + tangent * 0.2 + Vector3.UP * height * 0.25, start + tangent * 0.8 + Vector3.UP * height * 0.43, start + tangent * 0.35 + Vector3.UP * height * 0.64]
			geo.line_3d(glow, fissure, 0.085)
			for level in range(3):
				var rune_height := 5.0 + level * 6.0
				var p := start + Vector3.UP * rune_height - radial * radius * (rune_height / height) * 0.3
				var rune: Array[Vector3] = [p - tangent * 0.38, p + Vector3.UP * 0.75, p + tangent * 0.38, p - Vector3.UP * 0.55, p - tangent * 0.38]
				geo.line_3d(glow, rune, 0.075)
		geo.ring(bronze, CENTER + Vector3.UP * (y + 1), radius * 0.96, 0.23, 0, TAU, 36)
		geo.ring(glow, CENTER + Vector3.UP * (y + 1.2), radius, 0.08, 0, TAU, 48)
		# A suspended crystal in each break gives the tower a continuous spine.
		_crystal(geo, glow, CENTER + Vector3.UP * (y + height + 1.3), Vector3(0.9, 5.3, 0.9), twist)
	# Needle at the summit and inverted broken foundation below the course.
	_crystal(geo, gold, CENTER + Vector3.UP * 91, Vector3(1.8, 10, 1.8), 0.3)
	_crystal(geo, stone, CENTER - Vector3.UP * 4, Vector3(5.6, 18, 5.6), 0.2)
	for i in range(9):
		var a := i * TAU / 9
		var p := CENTER + Vector3(cos(a) * 5.5, 5 + sin(a * 3) * 2, sin(a) * 5.5)
		_crystal(geo, stone, p, Vector3(0.6, 6.0, 0.6), a)

func _prism(geo, mat: Material, bottom: Vector3, radius: float, height: float, yaw: float) -> void:
	for i in range(6):
		var a := yaw + i * TAU / 6
		var b := yaw + (i + 1) * TAU / 6
		var pa := Vector3(cos(a), 0, sin(a)) * radius
		var pb := Vector3(cos(b), 0, sin(b)) * radius
		var top_a := bottom + pa * 0.74 + Vector3.UP * height * 0.86
		var top_b := bottom + pb * 0.74 + Vector3.UP * height * 0.86
		geo.quad(mat, bottom + pa, top_a, top_b, bottom + pb)
		geo.triangle(mat, top_a, bottom + Vector3.UP * height, top_b)
		geo.triangle(mat, bottom, bottom + pa, bottom + pb)

func _crystal(geo, mat: Material, center: Vector3, size: Vector3, yaw: float) -> void:
	for i in range(5):
		var a := yaw + i * TAU / 5
		var b := yaw + (i + 1) * TAU / 5
		var pa := center + Vector3(cos(a) * size.x * 0.5, -size.y * 0.1, sin(a) * size.z * 0.5)
		var pb := center + Vector3(cos(b) * size.x * 0.5, -size.y * 0.1, sin(b) * size.z * 0.5)
		geo.triangle(mat, pa, center + Vector3.UP * size.y * 0.5, pb)
		geo.triangle(mat, pb, center - Vector3.UP * size.y * 0.5, pa)

func _build_ruins(geo, stone: Material, pale: Material, bronze: Material, cyan: Material, violet: Material, gold: Material) -> void:
	# The silhouette opens toward the home map; distant, broken temple pieces
	# sit outside radius 35, never masquerading as the next jump landing.
	for i in range(9):
		var a := -1.15 + i * 0.64
		var radius := 40.0 + sin(i * 2.4) * 6.0
		var p := CENTER + Vector3(cos(a) * radius, 6 + i * 7.7, sin(a) * radius)
		var tangent := Vector3(-sin(a), 0, cos(a))
		var glow: Material = cyan if i < 3 else (violet if i < 6 else gold)
		geo.rock(stone, p - Vector3.UP * 5, Vector3(9, 5, 6), a, Color.WHITE, 7)
		geo.block(pale, p, Vector3(8.8, 0.9, 4.5), -a - PI / 2)
		geo.block(bronze, p + Vector3.UP * 0.55, Vector3(8.9, 0.16, 4.55), -a - PI / 2)
		for side in [-1.0, 1.0]:
			var base: Vector3 = p + tangent * side * 3.0
			var height := 8.0 + sin(i * 1.9 + side) * 3.0
			_prism(geo, pale, base, 0.66, height, a)
			geo.ring(bronze, base + Vector3.UP * 1.0, 0.78, 0.22, 0, TAU, 16)
			geo.ring(bronze, base + Vector3.UP * (height * 0.82), 0.69, 0.18, 0, TAU, 16)
			var column_light: Array[Vector3] = [base + Vector3.UP * 1.2, base + Vector3.UP * height * 0.72]
			geo.line_3d(glow, column_light, 0.11)
		# An incomplete arch and a separated keystone read as suspended ruins.
		var arch: Array[Vector3] = []
		for k in range(19):
			var angle := 0.18 + k * (PI - 0.85) / 18.0
			arch.append(p + tangent * cos(angle) * 3.6 + Vector3.UP * (8.3 + sin(angle) * 3.3))
		geo.line_3d(pale, arch, 0.85)
		geo.line_3d(bronze, arch, 0.20)
		_crystal(geo, glow, p + Vector3.UP * 12.8, Vector3(0.4, 1.8, 0.4), a)
		for piece in range(3):
			var chip := p + tangent * (4.7 + piece * 1.8) + Vector3.UP * (3.5 + piece * 2.2)
			_crystal(geo, stone, chip, Vector3(1.2, 2.4, 1.1), a + piece)

func _build_constellations(geo, cyan: Material, violet: Material, magenta: Material, gold: Material, white: Material, dim: Material) -> void:
	# Opaque narrow aurora threads sweep around the outside of the whole climb.
	# Their large separation from the course keeps route rims easy to read.
	for strand in range(7):
		var points: Array[Vector3] = []
		var glow: Material = [cyan, violet, magenta, dim, gold, violet, cyan][strand]
		for i in range(100):
			var t := i / 99.0
			var a := -2.0 + t * 5.0 + strand * 0.37
			var radius := 49.0 + strand * 2.3 + sin(t * TAU * 2 + strand) * 3
			points.append(CENTER + Vector3(cos(a) * radius, -5 + t * 118 + sin(a * 2.2) * 5 + strand * 2, sin(a) * radius))
		geo.line_3d(glow, points, 0.08 if strand % 2 == 0 else 0.15)
	# Comets point upward beyond the ruins. Star dust uses shared batches.
	var random := RandomNumberGenerator.new()
	random.seed = 9061172
	for i in range(140):
		var a := random.randf() * TAU
		var radius := random.randf_range(31, 69)
		var p := CENTER + Vector3(cos(a) * radius, random.randf_range(-8, 111), sin(a) * radius)
		var size := random.randf_range(0.06, 0.20)
		var mat: Material = [cyan, violet, gold, white][i % 4]
		_crystal(geo, mat, p, Vector3(size, size * 2.0, size), a)
		if i % 7 == 0:
			var trail: Array[Vector3] = [p - Vector3(1, 6.0, 0.6), p - Vector3(0.3, 2.0, 0.2), p]
			geo.line_3d(dim, trail, 0.05)
			var comet_head: Array[Vector3] = [p - Vector3(0.15, 1.0, 0.1), p]
			geo.line_3d(mat, comet_head, 0.05)

func _build_eclipse(stone: Material, cyan: Material, magenta: Material, gold: Material, white: Material, dim: Material) -> void:
	var root := Node3D.new()
	root.name = "TheUnblinkingEclipse"
	root.position = ECLIPSE
	# Its face looks toward the climb; this is a local astronomical sculpture,
	# not a sky/environment change that could leak into another game mode.
	var face := (CENTER + Vector3.UP * 40 - ECLIPSE).normalized()
	var side := Vector3.UP.cross(face).normalized()
	var up := face.cross(side).normalized()
	root.basis = Basis(side, up, face)
	add_child(root)
	var disk := Geometry.new()
	var void_material := StandardMaterial3D.new()
	void_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_material.albedo_color = Color("020108")
	void_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	void_material.disable_fog = true
	for i in range(128):
		var a := i * TAU / 128
		var b := (i + 1) * TAU / 128
		disk.triangle(void_material, Vector3.ZERO, Vector3(cos(a), sin(a), 0) * 11.9, Vector3(cos(b), sin(b), 0) * 11.9)
	# Curved light traces create a bright corona and gravitational lens arcs.
	for layer in range(10):
		var radius := 12.0 + layer * 0.32
		var mat: Material = white if layer < 2 else (gold if layer < 5 else magenta)
		var points: Array[Vector3] = []
		for i in range(145):
			var a := i * TAU / 144
			var rr := radius + sin(a * 5 + layer) * 0.05 * layer
			points.append(Vector3(cos(a) * rr, sin(a) * rr, 0.1 + layer * 0.025))
		disk.line_3d(mat, points, 0.15 if layer < 2 else 0.09)
	for band in range(5):
		var points: Array[Vector3] = []
		for i in range(121):
			var a := i * TAU / 120
			points.append(Vector3(cos(a) * (20 + band * 0.55), sin(a) * (2.5 + band * 0.28), 0.8 + sin(a) * 4))
		disk.line_3d(gold if band < 3 else dim, points, 0.10)
	# Polar jets extend above and below, away from the playable spiral.
	for sign_value in [-1.0, 1.0]:
		for strand in range(3):
			var jet: Array[Vector3] = []
			for i in range(26):
				var t := i / 25.0
				jet.append(Vector3(sin(t * 4 + strand) * (0.2 + t * 1.2), sign_value * (14.5 + t * 22.0), -1.5 + strand * 0.15))
			disk.line_3d(cyan if strand == 0 else dim, jet, 0.14 if strand == 0 else 0.08)
	# The broken stone dial makes the impossible object part of the ruins.
	for i in range(20):
		var a := i * TAU / 20.0
		var p := Vector3(cos(a), sin(a), 0) * 17.0
		_crystal(disk, stone, p, Vector3(0.9, 2.5, 0.9), a)
	disk.finish(root)

func _build_orbit(radius: float, height: float, tilt: Vector3, light: Material, metal: Material, speed: float) -> void:
	var frame := Node3D.new()
	frame.name = "CelestialOrbit%d" % _orbits.size()
	frame.position = CENTER + Vector3.UP * height
	frame.rotation = tilt
	add_child(frame)
	var rotor := Node3D.new()
	frame.add_child(rotor)
	var geo := Geometry.new()
	# Even at maximum tilt these rings remain outside the landing envelope.
	geo.ring(metal, Vector3.ZERO, radius, 0.24, 0, TAU, 180)
	geo.ring(light, Vector3.UP * 0.02, radius - 0.28, 0.065, 0, TAU, 180)
	for segment in range(12):
		var start := segment * TAU / 12.0
		geo.ring(light, Vector3.ZERO, radius + 0.55, 0.12, start, start + 0.26, 12)
		var p := Vector3(cos(start), 0, sin(start)) * radius
		_crystal(geo, light, p, Vector3(0.22, 0.85, 0.22), start)
	geo.finish(rotor)
	_orbits.append(rotor)
	_orbit_speeds.append(speed)

func _build_shards(stone: Material, cyan: Material, violet: Material, gold: Material) -> void:
	for tier in range(3):
		var rotor := Node3D.new()
		rotor.name = "OrbitingRelics%d" % tier
		rotor.position = CENTER + Vector3.UP * (24 + tier * 26)
		add_child(rotor)
		var geo := Geometry.new()
		var glow: Material = [cyan, violet, gold][tier]
		for i in range(11):
			var a := i * TAU / 11.0 + tier
			var radius := 25.0 + (i % 3) * 2.4
			var p := Vector3(cos(a) * radius, sin(i * 1.7) * 4.0, sin(a) * radius)
			_crystal(geo, stone, p, Vector3(0.8, 3.6, 0.8), a)
			_crystal(geo, glow, p + Vector3.UP * 0.8, Vector3(0.15, 1.5, 0.15), a)
		geo.finish(rotor)
		_orbits.append(rotor)
		_orbit_speeds.append(0.018 if tier % 2 == 0 else -0.013)

func _set_reduced(reduced: bool) -> void:
	_reduced = reduced
	for mat in _energy_materials:
		mat.set_shader_parameter("motion", 0.0 if reduced else 1.0)

func _process(delta: float) -> void:
	if _options == null:
		return
	if bool(_options.reduced_effects) != _reduced:
		_set_reduced(bool(_options.reduced_effects))
	if _reduced:
		return
	for i in range(_orbits.size()):
		_orbits[i].rotate_y(delta * _orbit_speeds[i])
