extends CharacterBody3D

var actor_id := 0
var owner_peer := 0
var team := 0
var champion := "Ember"
var hp := 100.0
var kit: Array = []
const Auras = preload("res://scripts/auras.gd")
const Kits = preload("res://scripts/kits.gd")
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var identity: Dictionary = {}
var gcd := 0.0
var casting := -1
var cast_left := 0.0
var cast_target := -1
var stunned := 0.0
var locked := 0.0
var shield := 0.0
var sprint := 0.0
var stun_from := ""
var lock_from := ""
var shield_from := ""
var sprint_from := ""
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
var champion_model: Node3D
var nameplate: Label3D
var health_mesh: MeshInstance3D
var health_pivot: Node3D
var cast_mesh: MeshInstance3D
var cast_pivot: Node3D
var cast_label: Label3D
var aura_icons: Array = []
var health_back_mat: StandardMaterial3D
const NAMEPLATE_AURAS := 3
var base_color := Color.WHITE
var flash := 0.0
var net_position := Vector3.ZERO
var net_yaw := 0.0
var last_motion_seq := -1
var motion_revision := 0
var last_input_seq := -1
var last_action_seq := -1
var action_budget := 0.0

func setup(id: int, peer: int, side: int, choice: String) -> void:
	actor_id = id
	owner_peer = peer
	team = side
	champion = choice
	reset_identity()
	kit = preload("res://scripts/kits.gd").get_kit(choice)
	cooldowns.resize(kit.size())
	cooldowns.fill(0.0)
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
	champion_model = preload("res://scripts/champion_model.gd").new()
	add_child(champion_model)
	champion_model.build(champion, base_color)
	body_mesh = champion_model.torso
	nameplate = Label3D.new()
	nameplate.font_size = 24
	nameplate.modulate = base_color
	nameplate.position.y = 2.95
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(nameplate)
	health_pivot = Node3D.new()
	health_pivot.position.y = 2.48
	add_child(health_pivot)
	var back := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.6, 0.16)
	back.mesh = plane
	health_back_mat = StandardMaterial3D.new()
	health_back_mat.albedo_color = Color("17202b")
	health_back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back.material_override = health_back_mat
	health_pivot.add_child(back)
	health_mesh = MeshInstance3D.new()
	var fill := QuadMesh.new()
	fill.size = Vector2(1.54, 0.11)
	health_mesh.mesh = fill
	health_mesh.position.z = 0.01
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Kits.color(champion)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	health_mesh.material_override = fill_mat
	health_pivot.add_child(health_mesh)
	cast_pivot = Node3D.new()
	cast_pivot.position.y = 2.3
	cast_pivot.visible = false
	add_child(cast_pivot)
	var cast_back := MeshInstance3D.new()
	var cast_plane := QuadMesh.new()
	cast_plane.size = Vector2(1.6, 0.11)
	cast_back.mesh = cast_plane
	var cast_back_mat := StandardMaterial3D.new()
	cast_back_mat.albedo_color = Color("17202b")
	cast_back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cast_back.material_override = cast_back_mat
	cast_pivot.add_child(cast_back)
	cast_mesh = MeshInstance3D.new()
	var cast_fill := QuadMesh.new()
	cast_fill.size = Vector2(1.54, 0.07)
	cast_mesh.mesh = cast_fill
	cast_mesh.position.z = 0.01
	var cast_fill_mat := StandardMaterial3D.new()
	cast_fill_mat.albedo_color = Color("e8be78")
	cast_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cast_mesh.material_override = cast_fill_mat
	cast_pivot.add_child(cast_mesh)
	cast_label = Label3D.new()
	cast_label.font_size = 18
	cast_label.outline_size = 6
	cast_label.position.y = 0.14
	cast_label.modulate = Color("ffe6a8")
	cast_pivot.add_child(cast_label)
	for i in range(NAMEPLATE_AURAS):
		var holder := Node3D.new()
		holder.position = Vector3(-0.62 + i * 0.62, 2.94, 0)
		holder.visible = false
		add_child(holder)
		var icon := Sprite3D.new()
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.pixel_size = 0.0022
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		holder.add_child(icon)
		var timer := Label3D.new()
		timer.font_size = 26
		timer.outline_size = 8
		timer.position.y = -0.34
		timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(timer)
		aura_icons.append(holder)

# Painted from the arena, which is the only thing that knows who the local
# player is and therefore who counts as hostile.
func mark_hostile(hostile: bool) -> void:
	if health_back_mat != null:
		health_back_mat.albedo_color = Color("ff2d4e") if hostile else Color("17202b")

func paint_nameplate_auras(auras: Array, art) -> void:
	for i in range(NAMEPLATE_AURAS):
		var holder: Node3D = aura_icons[i]
		if i >= auras.size() or hp <= 0:
			holder.visible = false
			continue
		var aura: Dictionary = auras[i]
		var texture = art.texture_for(aura.get("source", ""))
		holder.visible = texture != null
		if texture == null:
			continue
		(holder.get_child(0) as Sprite3D).texture = texture
		var timer := holder.get_child(1) as Label3D
		timer.text = "%.0f" % ceil(aura.remaining) if aura.remaining >= 10.0 else "%.1f" % aura.remaining
		timer.modulate = aura.color

func visual_tick(delta: float, camera: Camera3D) -> void:
	flash = maxf(0, flash - delta)
	champion_model.animate(delta, self)
	health_mesh.scale.x = maxf(0.001, hp / 100.0)
	health_mesh.position.x = -0.77 * (1.0 - hp / 100.0)
	if camera and (camera.global_position - health_pivot.global_position).cross(Vector3.UP).length() > 0.01:
		health_pivot.look_at(camera.global_position, Vector3.UP, true)
	# Cast bar fills left to right as the cast completes, and is hidden the rest
	# of the time so a nameplate is not carrying an empty bar around.
	cast_pivot.visible = casting >= 0 and hp > 0
	if cast_pivot.visible:
		var total: float = maxf(0.01, kit[casting].cast)
		var done: float = clampf(1.0 - cast_left / total, 0.0, 1.0)
		cast_label.text = "%s  %.1fs" % [kit[casting].name, cast_left]
		cast_mesh.scale.x = maxf(0.001, done)
		cast_mesh.position.x = -0.77 * (1.0 - done)
		if camera and (camera.global_position - cast_pivot.global_position).cross(Vector3.UP).length() > 0.01:
			cast_pivot.look_at(camera.global_position, Vector3.UP, true)
	# The nameplate carries the cast on one line and every active aura on the
	# next, so you can read an enemy's crowd control from across the arena
	# without having to target them. Auras.active() is the same source the unit
	# frames use, so the two can never disagree.
	var state := ""
	if hp <= 0:
		state = "DEFEATED"
	var lines := "%s %s" % [champion, "[BOT]" if owner_peer == 0 else ""]
	if not state.is_empty():
		lines += "\n" + state
	nameplate.text = lines

func snapshot() -> Dictionary:
	return {"move_ack": last_motion_seq, "velocity": velocity, "motion_revision": motion_revision, "id": actor_id, "peer": owner_peer, "team": team, "champion": champion, "pos": position, "yaw": rotation.y, "hp": hp, "cd": cooldowns.duplicate(), "gcd": gcd, "casting": casting, "left": cast_left, "stun": stunned, "lock": locked, "shield": shield, "sprint": sprint,
		"stun_src": stun_from, "lock_src": lock_from, "shield_src": shield_from, "sprint_src": sprint_from, "dr": dr_count, "dr_timer": dr_timer, "cast_target": cast_target, "target": target_id, "identity": identity.duplicate(true)}

func receive(data: Dictionary, instant: bool = false) -> void:
	identity = data.get("identity", {}).duplicate(true)
	net_position = data.pos
	net_yaw = data.yaw
	var teleported: bool = data.get("motion_revision", 0) != motion_revision
	motion_revision = data.get("motion_revision", 0)
	if instant or teleported:
		position = net_position
		rotation.y = net_yaw
		reset_physics_interpolation()
	owner_peer = data.peer
	hp = data.hp
	cooldowns = data.cd
	gcd = data.gcd
	casting = data.casting
	cast_left = data.left
	cast_target = data.get("cast_target", -1)
	stunned = data.stun
	locked = data.lock
	shield = data.shield
	sprint = data.sprint
	# Older snapshots may predate the source fields; default rather than fail.
	stun_from = data.get("stun_src", "")
	lock_from = data.get("lock_src", "")
	shield_from = data.get("shield_src", "")
	sprint_from = data.get("sprint_src", "")
	dr_count = data.dr
	dr_timer = data.dr_timer
	target_id = data.target

func reset_identity() -> void:
	identity = {"meditation": 0.0, "instant_graviton": false, "dots": {}, "heat": 0.0, "resolve": 0.0, "brands": {}, "stars": [], "anchor_left": 0.0, "anchor_pos": Vector3.ZERO, "orbit": 0.0, "root": 0.0, "slow": 0.0, "immune": 0.0, "last": 0.0, "hold": 0.0, "disorient": false, "guard": -1, "guard_left": 0.0, "guard_budget": 0.0, "challenge": -1, "challenge_left": 0.0, "challenge_tick": 0.0, "exposed": -1, "exposed_left": 0.0, "wake": 0.0, "wake_pos": Vector3.ZERO, "wake_end": Vector3.ZERO, "wake_tick": 0.0}
