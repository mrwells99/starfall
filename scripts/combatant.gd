extends CharacterBody3D

var actor_id := 0
var owner_peer := 0
var team := 0
var champion := "Ember"
var hp := 100.0
var kit: Array = []
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var gcd := 0.0
var casting := -1
var cast_left := 0.0
var cast_target := -1
var stunned := 0.0
var locked := 0.0
var shield := 0.0
var sprint := 0.0
var dr_count := 0
var dr_timer := 0.0
var move_input := Vector2.ZERO
var jump_queued := false
var input_age := 0.0
var target_id := -1
var ai_timer := 0.0
var path_timer := 0.0
var path: PackedVector2Array = []
var body_mesh: MeshInstance3D
var nameplate: Label3D
var health_mesh: MeshInstance3D
var health_pivot: Node3D
var base_color := Color.WHITE
var flash := 0.0
var net_position := Vector3.ZERO
var net_yaw := 0.0
var last_input_seq := -1
var last_action_seq := -1
var action_budget := 0.0

func setup(id: int, peer: int, side: int, choice: String) -> void:
	actor_id = id
	owner_peer = peer
	team = side
	champion = choice
	kit = preload("res://scripts/kits.gd").get_kit(choice)
	collision_layer = 2
	collision_mask = 1 # Characters may overlap, as in arena combat.
	base_color = Color("62cfeb") if team == 0 else Color("e77f78")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	body_mesh = MeshInstance3D.new()
	var model := CapsuleMesh.new()
	model.radius = 0.42
	model.height = 1.8
	body_mesh.mesh = model
	body_mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	body_mesh.material_override = mat
	add_child(body_mesh)
	var nose := MeshInstance3D.new()
	var marker := BoxMesh.new()
	marker.size = Vector3(0.24, 0.2, 0.5)
	nose.mesh = marker
	nose.position = Vector3(0, 1.35, -0.45)
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color("97edb1") if champion == "Luminary" else Color("e8be78")
	nose.material_override = accent
	add_child(nose)
	nameplate = Label3D.new()
	nameplate.font_size = 24
	nameplate.position.y = 2.6
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(nameplate)
	health_pivot = Node3D.new()
	health_pivot.position.y = 2.15
	add_child(health_pivot)
	var back := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.6, 0.16)
	back.mesh = plane
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color("17202b")
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back.material_override = back_mat
	health_pivot.add_child(back)
	health_mesh = MeshInstance3D.new()
	var fill := QuadMesh.new()
	fill.size = Vector2(1.54, 0.11)
	health_mesh.mesh = fill
	health_mesh.position.z = 0.01
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = base_color
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	health_mesh.material_override = fill_mat
	health_pivot.add_child(health_mesh)

func visual_tick(delta: float, camera: Camera3D) -> void:
	flash = maxf(0, flash - delta)
	(body_mesh.material_override as StandardMaterial3D).albedo_color = Color.WHITE if flash > 0 else (base_color if hp > 0 else Color("3d4148"))
	body_mesh.scale.y = 1.0 if hp > 0 else 0.25
	health_mesh.scale.x = maxf(0.001, hp / 100.0)
	health_mesh.position.x = -0.77 * (1.0 - hp / 100.0)
	if camera and (camera.global_position - health_pivot.global_position).cross(Vector3.UP).length() > 0.01:
		health_pivot.look_at(camera.global_position, Vector3.UP, true)
	var state := ""
	if hp <= 0:
		state = "DEAD"
	elif stunned > 0:
		state = "STUN %.1fs" % stunned
	elif locked > 0:
		state = "LOCKED %.1fs" % locked
	elif casting >= 0:
		state = "%s %.1fs" % [kit[casting].name, cast_left]
	elif shield > 0:
		state = "WARD %.1fs" % shield
	nameplate.text = "%s %s\n%s" % [champion, "[BOT]" if owner_peer == 0 else "", state]

func snapshot() -> Dictionary:
	return {"id": actor_id, "peer": owner_peer, "team": team, "champion": champion, "pos": position, "yaw": rotation.y, "hp": hp, "cd": cooldowns.duplicate(), "gcd": gcd, "casting": casting, "left": cast_left, "stun": stunned, "lock": locked, "shield": shield, "sprint": sprint, "dr": dr_count, "dr_timer": dr_timer, "target": target_id}

func receive(data: Dictionary, instant: bool = false) -> void:
	net_position = data.pos
	net_yaw = data.yaw
	if instant:
		position = net_position
		rotation.y = net_yaw
	owner_peer = data.peer
	hp = data.hp
	cooldowns = data.cd
	gcd = data.gcd
	casting = data.casting
	cast_left = data.left
	stunned = data.stun
	locked = data.lock
	shield = data.shield
	sprint = data.sprint
	dr_count = data.dr
	dr_timer = data.dr_timer
	target_id = data.target
