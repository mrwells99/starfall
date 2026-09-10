extends MeshInstance3D
## A reusable outline only. Hit detection is authoritative in class_mechanics.
const Kits = preload("res://scripts/kits.gd")
const SEGMENTS := 40
const WIDTH := .045
const VISIBLE_SECONDS := 1.0
static var shared_mesh: ArrayMesh
static var shared_material: StandardMaterial3D

func _init() -> void:
	name = "SolarFlareOutline"
	visible = false
	if shared_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var first := edge(-Kits.SOLAR_FLARE_HALF_ANGLE)
		strip(surface, Vector3.ZERO, first)
		var previous := first
		for i in range(1, SEGMENTS + 1):
			var point := edge(lerpf(-Kits.SOLAR_FLARE_HALF_ANGLE, Kits.SOLAR_FLARE_HALF_ANGLE, float(i) / SEGMENTS))
			strip(surface, previous, point)
			previous = point
		strip(surface, previous, Vector3.ZERO)
		surface.generate_normals()
		shared_mesh = surface.commit()
		shared_material = StandardMaterial3D.new()
		shared_material.albedo_color = Color("ffbf68")
		shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh = shared_mesh
	material_override = shared_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = .065

static func edge(angle: float) -> Vector3:
	return Vector3(sin(angle), 0, -cos(angle)) * Kits.SOLAR_FLARE_RANGE

static func strip(surface: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var side := (to - from).normalized().cross(Vector3.UP) * WIDTH * .5
	for vertex in [from - side, to - side, to + side, from - side, to + side, from + side]:
		surface.add_vertex(vertex)
