extends Node3D
## Reused wrist tether and loop. Entirely cosmetic and absent on the server.
var line: MeshInstance3D
var loop: MeshInstance3D

func _init() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("f6ca7c")
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .018; cylinder.bottom_radius = .018
	cylinder.height = 1; cylinder.radial_segments = 6
	line = MeshInstance3D.new(); line.mesh = cylinder; line.material_override = material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	var torus := TorusMesh.new()
	torus.inner_radius = .48; torus.outer_radius = .515
	torus.rings = 24; torus.ring_segments = 6
	loop = MeshInstance3D.new(); loop.mesh = torus; loop.material_override = material
	loop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(loop)
	hide()

func update(game, a) -> void:
	var s: Dictionary = game.Outlaw.Lasso.state(a)
	visible = a.hp > 0 and s.get("phase", "") in ["cast", "rope", "pull"]
	if not visible: return
	var from: Vector3 = a.position + Vector3.UP * 1.5
	if a.champion_model != null:
		var rig: Skeleton3D = a.champion_model.outlaw_art.skeleton
		from = rig.global_transform * rig.get_bone_global_pose(rig.find_bone("DEF-hand.R")).origin
	var to: Vector3 = from
	if s.phase == "cast":
		var angle: float = (game.Outlaw.Lasso.CAST-a.cast_left)*TAU*3
		to += Vector3(.35*cos(angle),.18,.35*sin(angle))
	elif s.phase == "rope": to = s.rope
	elif game.actors.has(s.target): to = game.actors[s.target].position + Vector3.UP * 1.05
	loop.position = to
	loop.rotation = Vector3(.15,0,.1)
	line.visible = from.distance_squared_to(to) > .0001
	if line.visible:
		line.position = (from+to)*.5
		line.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
		line.scale = Vector3(1,from.distance_to(to),1)
