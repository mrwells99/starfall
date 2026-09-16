extends MultiMeshInstance3D
## One retained, locally animated particle batch. Never creates physics objects.
const FLAME = preload("res://assets/effects/ember/flame_01.png")
const SHADER = preload("res://shaders/ability_flame.gdshader")
var material: ShaderMaterial
var clock := 0.0
var intensity := 0.0
var target_intensity := 0.0
var particle_size := Vector2(.8,1.45)
var capacity := 128
var flat := false

func configure(texture: Texture2D = FLAME, count: int = 128, size: Vector2 = Vector2(.8,1.45), ground: bool = false) -> void:
	capacity = count; particle_size = size; flat = ground
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("flame_texture",texture)
	material.set_shader_parameter("on_ground",flat)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-80,-20,-80),Vector3(160,80,160))
	visible = false
	for i in capacity:
		multimesh.set_instance_custom_data(i,Color(fmod(i*.61803398875,1.0),0,0,0))

func points(positions: PackedVector3Array, colors: PackedColorArray = PackedColorArray()) -> void:
	var count := mini(capacity,positions.size())
	multimesh.visible_instance_count = count
	for i in count:
		var seed := fmod(i*.61803398875,1.0)
		var size := Vector3(particle_size.x,particle_size.y,1.0) * lerpf(.82,1.15,seed)
		var basis := Basis(Vector3.RIGHT,-PI/2) if flat else Basis.IDENTITY
		multimesh.set_instance_transform(i,Transform3D(basis.scaled(size),positions[i]))
		multimesh.set_instance_color(i,colors[i] if i<colors.size() else Color.WHITE)

func ring(center: Vector3, inner: float, outer: float, count: int = 96) -> void:
	var positions := PackedVector3Array()
	for i in count:
		var angle := float(i)*2.39996322973
		var radius := sqrt(lerpf(inner*inner,outer*outer,(float(i)+.5)/count))
		positions.append(center+Vector3(cos(angle)*radius,0.0 if flat else particle_size.y*.40,sin(angle)*radius))
	points(positions)

func advance(delta: float) -> void:
	clock += delta
	intensity = move_toward(intensity,target_intensity,delta/(.16 if target_intensity>intensity else .30))
	visible = intensity > .001 and multimesh.visible_instance_count > 0
	if not visible: return
	material.set_shader_parameter("effect_time",clock)
	material.set_shader_parameter("opacity",smoothstep(0,1,intensity))
