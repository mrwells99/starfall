extends Node3D
## Retained, tapered ankle-height wind ribbons. No particles or cast-time loads.
const STREAKS := 6
static var ribbon_mesh: ArrayMesh
var streaks: Array[MeshInstance3D] = []
var intensity := 0.0
var clock := 0.0
var previous_position := Vector3.ZERO
var positioned := false
var flow_yaw := 0.0
var observer_visible := true

func _init() -> void:
	name = "NullHasteWind"
	visible = false
	if ribbon_mesh == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in 28:
			var a := segment / 28.0
			var b := (segment + 1) / 28.0
			for point in [Vector2(a, -1), Vector2(b, -1), Vector2(b, 1), Vector2(a, -1), Vector2(b, 1), Vector2(a, 1)]:
				var t: float = point.x
				var width := sin(t * PI) * .026
				# Curve around the ankle, then sweep backwards into a fine tail.
				var x := .24 + sin(t * PI * .85) * .27
				surface.add_vertex(Vector3(x + point.y * width, sin(t * PI) * .055, -.4 + t * 1.25))
		ribbon_mesh = surface.commit()
	for i in STREAKS:
		var streak := MeshInstance3D.new()
		streak.mesh = ribbon_mesh
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(.73, .87, .94, 0)
		streak.material_override = material
		add_child(streak)
		streaks.append(streak)

func update(actor: CharacterBody3D, delta: float, speed: float, conceal_alpha: float) -> void:
	var displacement := actor.global_position - previous_position if positioned else Vector3.ZERO
	previous_position = actor.global_position
	positioned = true
	displacement.y = 0
	var grounded: bool = actor.is_on_floor() if actor.presentation_grounded == null else bool(actor.presentation_grounded)
	var active: bool = actor.hp > 0 and grounded and float(actor.identity.get("null_haste", 0)) > 0
	intensity = move_toward(intensity, 1.0 if active else 0.0, delta * (5.0 if active else 4.0))
	# Share observer-local Stealth opacity: never reveal a hidden enemy's feet.
	visible = observer_visible and intensity > .001 and conceal_alpha > .01 and actor.hp > 0
	if not visible: return
	var motion := clampf(speed / 7.5, 0, 1)
	if displacement.length_squared() > .00001 and displacement.length_squared() < 1.0:
		flow_yaw = lerp_angle(flow_yaw, atan2(-displacement.x, -displacement.z), 1.0 - exp(-delta * 14.0))
	rotation.y = flow_yaw - actor.global_rotation.y
	clock += delta * lerpf(.65, 1.8, motion)
	for i in STREAKS:
		var phase := fposmod(clock + i / float(STREAKS), 1.0)
		var streak := streaks[i]
		var side := -1.0 if i % 2 == 0 else 1.0
		streak.scale = Vector3(side * (1.0 + phase * .16), 1, lerpf(.6, 1.3, motion))
		streak.position = Vector3(0, .055 + (i % 3) * .055, phase * lerpf(.16, .6, motion))
		streak.rotation.y = side * (.1 - phase * .15)
		streak.material_override.albedo_color.a = sin(phase * PI) * intensity * conceal_alpha * lerpf(.18, .42, motion)

func set_observer_visible(value: bool) -> void:
	observer_visible = value
	if not value:
		visible = false
