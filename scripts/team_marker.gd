extends Node3D
## Lightweight local presentation; never changes class health colors or team state.
const Badge = preload("res://scripts/team_badge.gd")
var actor
var ground: MeshInstance3D
var brackets: Node3D
var last_hostile := -1
func flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
func install(owner_actor) -> void:
	actor = owner_actor
	ground = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.71
	torus.outer_radius = 0.77
	torus.rings = 32
	torus.ring_segments = 4
	ground.mesh = torus
	ground.position.y = 0.055
	ground.material_override = flat(Badge.ALLY)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.add_child(ground)
	brackets = Node3D.new()
	actor.health_pivot.add_child(brackets)
	var white := flat(Color.WHITE)
	for side in [-1, 1]:
		for part in [Vector3(side * 0.88, -0.05, 0.04), Vector3(side * 0.84, 0.13, 0.04), Vector3(side * 0.84, -0.23, 0.04)]:
			var segment := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.035, 0.39) if absf(part.x) > 0.85 else Vector2(0.11, 0.035)
			segment.mesh = quad
			segment.position = part
			segment.material_override = white
			segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			brackets.add_child(segment)
	ground.hide()
	brackets.hide()
func sync(hostile: bool, personal: bool, selected: bool) -> void:
	var concealed: bool=actor.identity.get("stealth",false)
	ground.visible = not personal and actor.hp > 0 and not concealed
	brackets.visible = selected and not personal and actor.hp > 0 and not concealed
	if last_hostile != int(hostile):
		last_hostile = int(hostile)
		var tint: Color = Badge.ENEMY if hostile else Badge.ALLY
		ground.material_override.albedo_color = tint
