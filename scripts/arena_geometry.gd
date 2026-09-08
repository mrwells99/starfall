extends RefCounted
## Static arena art is batched by material. Collision is built separately from
## the shared layout, so rubble and light effects cannot snag a player/camera.

var rng := RandomNumberGenerator.new()
var batches: Dictionary = {}

func _init() -> void:
	rng.seed = 81372

func triangle(mat: Material, a: Vector3, b: Vector3, c: Vector3, tint := Color.WHITE) -> void:
	if not batches.has(mat):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[mat] = surface
	var surface: SurfaceTool = batches[mat]
	var normal := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(tint)
		surface.set_uv(Vector2(p.x, p.z))
		surface.add_vertex(p)

func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint := Color.WHITE) -> void:
	triangle(mat, a, b, c, tint)
	triangle(mat, a, c, d, tint)

func block(mat: Material, center: Vector3, size: Vector3, yaw := 0.0, tint := Color.WHITE) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var points: Array[Vector3] = []
	for y in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			for x in [-0.5, 0.5]:
				points.append(center + basis * (Vector3(x, y, z) * size))
	quad(mat, points[0], points[1], points[3], points[2], tint)
	quad(mat, points[4], points[6], points[7], points[5], tint)
	quad(mat, points[0], points[4], points[5], points[1], tint)
	quad(mat, points[2], points[3], points[7], points[6], tint)
	quad(mat, points[0], points[2], points[6], points[4], tint)
	quad(mat, points[1], points[5], points[7], points[3], tint)

func rock(mat: Material, center: Vector3, size: Vector3, yaw := 0.0, tint := Color.WHITE, sides := 7) -> void:
	var layers: Array = []
	var basis := Basis(Vector3.UP, yaw)
	var angles: Array[float] = []
	for i in sides:
		angles.append(TAU * i / sides + rng.randf_range(-0.12, 0.12))
	var lean := Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.12, 0.12))
	for layer in range(4):
		var ring: Array[Vector3] = []
		var height: float = [0.0, 0.17, 0.78, 1.0][layer]
		for i in sides:
			var radius: float = [0.91, 1.0, 0.82, 0.68][layer] * rng.randf_range(0.88, 1.08)
			var p := Vector3(cos(angles[i]) * 0.5 * radius + lean.x * height,
				height + (rng.randf_range(-0.045, 0.045) if layer > 0 else 0.0),
				sin(angles[i]) * 0.5 * radius + lean.y * height)
			ring.append(center + basis * (p * size))
		layers.append(ring)
	for layer in range(3):
		for i in sides:
			var next := (i + 1) % sides
			var shade := tint * rng.randf_range(0.87, 1.10)
			shade.a = 1.0
			quad(mat, layers[layer][i], layers[layer + 1][i], layers[layer + 1][next], layers[layer][next], shade)
	var top := center + basis * (Vector3(lean.x, 0.998, lean.y) * size)
	for i in sides:
		triangle(mat, top, layers[3][(i + 1) % sides], layers[3][i], tint.lightened(0.05))

func ribbon(mat: Material, points: Array[Vector3], width: float, tint := Color.WHITE) -> void:
	for i in range(points.size() - 1):
		var direction := (points[i + 1] - points[i]).normalized()
		var side := direction.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized() * width * 0.5
		quad(mat, points[i] - side, points[i + 1] - side, points[i + 1] + side, points[i] + side, tint)

func line_3d(mat: Material, points: Array[Vector3], width: float) -> void:
	# Two crossed ribbons remain visible from ground level and the overview.
	for i in range(points.size() - 1):
		var delta := (points[i + 1] - points[i]).normalized()
		var side := delta.cross(Vector3.FORWARD).normalized() * width * 0.5
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT * width * 0.5
		var other := delta.cross(side).normalized() * width * 0.5
		quad(mat, points[i] - side, points[i + 1] - side, points[i + 1] + side, points[i] + side)
		quad(mat, points[i] - other, points[i + 1] - other, points[i + 1] + other, points[i] + other)

func ring(mat: Material, center: Vector3, radius: float, width: float, start := 0.0, end := TAU, segments := 96) -> void:
	for i in segments:
		var a := lerpf(start, end, float(i) / segments)
		var b := lerpf(start, end, float(i + 1) / segments)
		quad(mat, center + Vector3(cos(a), 0, sin(a)) * (radius - width * 0.5),
			center + Vector3(cos(b), 0, sin(b)) * (radius - width * 0.5),
			center + Vector3(cos(b), 0, sin(b)) * (radius + width * 0.5),
			center + Vector3(cos(a), 0, sin(a)) * (radius + width * 0.5))

func finish(parent: Node3D) -> void:
	var index := 0
	for mat in batches:
		var mesh := MeshInstance3D.new()
		mesh.name = "Stonework_%02d" % index
		mesh.mesh = (batches[mat] as SurfaceTool).commit()
		mesh.material_override = mat
		parent.add_child(mesh)
		index += 1
	batches.clear()
