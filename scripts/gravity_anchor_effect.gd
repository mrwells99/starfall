extends Node3D
## Cosmetic projection of replicated anchor state. No combat or collision nodes.
const MODEL = preload("res://assets/effects/gravity_anchor.glb")
var body: Node3D
var outer: Node3D
var inner: Node3D
var core: Node3D
var crown: Node3D
var boundary: MeshInstance3D
var timer: Label3D
var age := 0.0
var previous_left := 0.0
var previous_position := Vector3.ZERO
var reduced := false
var active := false
var base_outer := Basis.IDENTITY
var base_inner := Basis.IDENTITY

func _ready() -> void:
	name = "GravityMarker"
	top_level = true
	boundary = MeshInstance3D.new()
	boundary.name = "Boundary"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.975
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 6
	boundary.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b98cff")
	mat.emission_enabled = true
	mat.emission = Color("9f60ff")
	mat.emission_energy_multiplier = 0.8
	boundary.material_override = mat
	boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(boundary)
	body = MODEL.instantiate()
	body.name = "Relic"
	add_child(body)
	outer = body.find_child("RotorOuter", true, false)
	inner = body.find_child("RotorInner", true, false)
	core = body.find_child("Core", true, false)
	crown = body.find_child("ShardCrown", true, false)
	base_outer = outer.basis
	base_inner = inner.basis
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	timer = Label3D.new()
	timer.name = "Timer"
	timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	timer.position.y = 2.05
	timer.font_size = 24
	timer.outline_size = 5
	add_child(timer)
	visible = false
	set_process(false)

func sync(left: float, point: Vector3, radius: float, ally: bool, alive: bool, reduced_effects: bool) -> void:
	var was_active := active
	active = alive and left > 0.0
	if active and (not was_active or left > previous_left + 0.1 or not point.is_equal_approx(previous_position)):
		age = 0.0
	previous_left = left
	previous_position = point
	reduced = reduced_effects
	visible = active
	set_process(active)
	if not active:
		return
	global_position = point + Vector3.UP * 0.08
	boundary.scale = Vector3(radius, 0.2, radius)
	timer.text = "%s ANCHOR %.1f" % ["ALLY" if ally else "ENEMY", left]
	timer.modulate = Color("c4b2ff") if ally else Color("ffb794")
	apply_pose()

func _process(delta: float) -> void:
	age += delta
	apply_pose()

func apply_pose() -> void:
	var arrive := 1.0 if reduced else smoothstep(0.0, 0.42, age)
	body.scale = Vector3.ONE * lerpf(0.2, 1.0, arrive)
	body.position.y = 0.0 if reduced else sin(age * 1.8) * 0.045
	var turn := 0.0 if reduced else age * TAU / 12.0
	outer.basis = base_outer * Basis(Vector3.UP, turn)
	inner.basis = base_inner * Basis(Vector3.UP, -turn)
	core.rotation.y = -turn * 0.5
	crown.rotation.y = turn * 0.25
