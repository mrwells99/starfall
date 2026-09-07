extends Node3D

const BLUE = Color("62cfeb")
const GOLD = Color("e8be78")
const RED = Color("e77f78")

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func box(pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = pos
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collider.shape = bounds
		body.position = pos
		body.add_child(collider)
		add_child(body)

func build_arena() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("101d2c")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a6bfd8")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("ffdfaf")
	sun.shadow_enabled = true
	add_child(sun)
	box(Vector3(0, -0.4, 0), Vector3(36, 0.8, 36), Color("344452"))
	for i in range(-8, 9):
		box(Vector3(i * 2, 0.008, 0), Vector3(0.025, 0.01, 36), Color("425562"), false)
		box(Vector3(0, 0.008, i * 2), Vector3(36, 0.01, 0.025), Color("425562"), false)
	for x in [-6, 6]:
		for z in [-5, 5]:
			box(Vector3(x, 2.5, z), Vector3(2.8, 5, 2.8), Color("596571"))
			box(Vector3(x, 0.2, z), Vector3(3.3, 0.4, 3.3), Color("889198"))
			box(Vector3(x, 5, z), Vector3(3.3, 0.35, 3.3), GOLD)
	for edge in [-18, 18]:
		box(Vector3(edge, 1.5, 0), Vector3(0.7, 3, 36), Color("253340"))
		box(Vector3(0, 1.5, edge), Vector3(36, 3, 0.7), Color("253340"))
	for z in [-12, 12]:
		box(Vector3(0, 0.015, z), Vector3(6, 0.02, 0.12), BLUE if z > 0 else RED, false)

