extends CharacterBody3D

var actor_id := 0
signal owner_peer_changed(previous: int, current: int)
var owner_peer := 0:
	set(value):
		if owner_peer == value: return
		var previous := owner_peer
		owner_peer = value
		owner_peer_changed.emit(previous,value)
var team := 0
var champion := "Ember"
const BASE_MAX_HEALTH := 100.0
const HEALTH_SCALE := 15.0
const DAMAGE_SCALE := 10.0
const MAX_HEALTH := BASE_MAX_HEALTH * HEALTH_SCALE
var hp := MAX_HEALTH
var kit: Array = []
const Auras = preload("res://scripts/auras.gd")
const Kits = preload("res://scripts/kits.gd")
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var identity: Dictionary = {}
# Local lifecycle bookkeeping, never part of the replicated ability state.
var death_identity_cleaned := false
var charge: Dictionary = {}
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
var dr_states: Dictionary = {}
var cc_effects: Dictionary = {}
# Legacy accessors refer only to the stun track, not shared diminishing returns.
var dr_count: int:
	get: return int(dr_states.get("stun", {}).get("count", 0))
	set(value):
		if not dr_states.has("stun"): dr_states.stun = {"count": 0, "remaining": 0.0}
		dr_states.stun.count = value
var dr_timer: float:
	get: return float(dr_states.get("stun", {}).get("remaining", 0.0))
	set(value):
		if not dr_states.has("stun"): dr_states.stun = {"count": 0, "remaining": 0.0}
		dr_states.stun.remaining = value
var move_input := Vector2.ZERO
var jump_queued := false
var jump_buffer := 0.0
var last_jump_id := 0
var walking := false
var input_age := 0.0
var target_id := -1
var ai_timer := 0.0
var path_timer := 0.0
var path: PackedVector2Array = []
var body_mesh: MeshInstance3D
var training_dummy := false
var champion_model: Node3D
var body_hitboxes: RefCounted
var hitbox_pose: Node3D
var aim_stamp := 0.0
var nameplate: Label3D
var team_marker
var health_mesh: MeshInstance3D
var health_pivot: Node3D
var nameplate_cast: Node3D
var chronoshift_nameplate: Node3D
var aura_icons: Array = []
var health_back_mat: StandardMaterial3D
const NAMEPLATE_AURAS := 3
var base_color := Color.WHITE
var flash := 0.0
var net_position := Vector3.ZERO
var net_yaw := 0.0
# Remote bodies interpolate positions without updating physics floor contact.
# Locally simulated bodies clear this cosmetic snapshot override each step.
var presentation_grounded: Variant = null
var presentation_vertical_speed := 0.0
var presentation_velocity: Variant = null
# Local receipt counter for cosmetic clocks; never serialized or used by combat.
var presentation_snapshot_serial := 0
var last_motion_seq := -1
var motion_revision := 0
var last_input_seq := -1
var last_action_seq := -1
var action_budget := 0.0

func setup(id: int, peer: int, side: int, choice: String, presentation: bool = true) -> void:
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
	# Dedicated actors retain the same capsule and simulation state. Loading the
	# model script lazily also keeps its authored GLB resources out of servers.
	if not presentation:
		return
	champion_model = load("res://scripts/champion_model.gd").new()
	add_child(champion_model)
	champion_model.build(champion, base_color)
	body_mesh = champion_model.torso
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
	nameplate_cast = load("res://scripts/nameplate_cast.gd").new()
	health_pivot.add_child(nameplate_cast)
	nameplate_cast.install()
	chronoshift_nameplate = load("res://scripts/chronoshift_nameplate.gd").new()
	health_pivot.add_child(chronoshift_nameplate)
	chronoshift_nameplate.install()
	for i in range(NAMEPLATE_AURAS):
		var holder := Node3D.new()
		holder.visible = false
		health_pivot.add_child(holder)
		holder.position = Vector3(-0.76 + i * 0.76, 0.48, 0.02)
		var icon := Sprite3D.new()
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.pixel_size = 0.0022
		icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		holder.add_child(icon)
		aura_icons.append(holder)
	team_marker = preload("res://scripts/team_marker.gd").new()
	add_child(team_marker)
	team_marker.install(self)

func setup_hitboxes() -> void:
	if body_hitboxes != null: return
	var art
	if champion_model == null:
		hitbox_pose = load("res://scripts/hitbox_pose.gd").new()
		add_child(hitbox_pose); hitbox_pose.build(champion)
		art = hitbox_pose.art
	else:
		art = champion_model.get(champion.to_lower()+"_art")
	body_hitboxes = preload("res://scripts/body_hitboxes.gd").new()
	body_hitboxes.setup(art.skeleton,champion)

func update_hitboxes(delta: float) -> void:
	if body_hitboxes == null: setup_hitboxes()
	if hitbox_pose != null and not training_dummy: hitbox_pose.animate(delta,self)
	body_hitboxes.update()

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
		if texture == null: texture = art.texture_for(aura.name)
		if texture == null: texture = art.texture_for("Stasis" if aura.has("cc") else "Ward")
		holder.visible = texture != null
		if texture == null:
			continue
		(holder.get_child(0) as Sprite3D).texture = texture
		(holder.get_child(0) as Sprite3D).pixel_size = 0.70 / maxf(1, texture.get_width())
		var stacks: int = int(aura.get("stacks", 0))
		var stack_label := holder.get_node_or_null("Stacks") as Label3D
		if stacks > 0 and stack_label == null:
			stack_label = Label3D.new()
			stack_label.name = "Stacks"
			stack_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			stack_label.font_size = 40
			stack_label.outline_size = 10
			stack_label.pixel_size = 0.007
			stack_label.position = Vector3(0.18, -0.20, 0.03)
			holder.add_child(stack_label)
		if stack_label != null:
			stack_label.visible = stacks > 0
			stack_label.text = "×%d" % stacks if stacks > 0 else ""
		holder.position.x = (i - (mini(auras.size(), NAMEPLATE_AURAS) - 1) * 0.5) * 0.76

func visual_tick(delta: float, camera: Camera3D, show_nameplate: bool = true, cast_tint: Color = Color("c7a256")) -> void:
	flash = maxf(0, flash - delta)
	if not training_dummy: champion_model.animate(delta, self)
	health_mesh.scale.x = maxf(0.001, hp / MAX_HEALTH)
	health_mesh.position.x = -0.77 * (1.0 - hp / MAX_HEALTH)
	if camera and (camera.global_position - health_pivot.global_position).cross(Vector3.UP).length() > 0.01:
		health_pivot.look_at(camera.global_position, Vector3.UP, true)
	health_pivot.visible = show_nameplate and hp > 0
	nameplate_cast.sync(self, cast_tint)
	chronoshift_nameplate.sync(self)


func snapshot() -> Dictionary:
	return {"jump_ack": last_jump_id, "jump_buffer": jump_buffer, "walk": walking, "move_ack": last_motion_seq, "velocity": velocity, "grounded": is_on_floor(), "motion_revision": motion_revision, "id": actor_id, "peer": owner_peer, "team": team, "champion": champion, "pos": position, "yaw": rotation.y, "hp": hp, "cd": cooldowns.duplicate(), "gcd": gcd, "casting": casting, "left": cast_left, "stun": stunned, "lock": locked, "shield": shield, "sprint": sprint,
		"stun_src": stun_from, "lock_src": lock_from, "shield_src": shield_from, "sprint_src": sprint_from, "dr": dr_count, "dr_timer": dr_timer, "dr_states": dr_states.duplicate(true), "cc_effects": cc_effects.duplicate(true), "cast_target": cast_target, "target": target_id, "identity": identity.duplicate(true), "charge": charge.duplicate(true)}

func receive(data: Dictionary, instant: bool = false) -> void:
	presentation_snapshot_serial += 1
	identity = data.get("identity", {}).duplicate(true)
	charge = data.get("charge", {}).duplicate(true)
	net_position = data.pos
	net_yaw = data.yaw
	presentation_grounded = data.get("grounded", null)
	presentation_vertical_speed = Vector3(data.get("velocity", Vector3.ZERO)).y
	presentation_velocity = data.get("velocity", null)
	var teleported: bool = data.get("motion_revision", 0) != motion_revision
	motion_revision = data.get("motion_revision", 0)
	if instant or teleported:
		position = net_position
		rotation.y = net_yaw
		reset_physics_interpolation()
	owner_peer = data.peer
	hp = data.hp
	cooldowns = data.cd
	# Older servers may omit newly appended slots. Keep the UI safe, but mark
	# unsupported combat abilities unavailable until a server supplies their state.
	if cooldowns.size() < kit.size():
		cooldowns = cooldowns.duplicate()
	while cooldowns.size() < kit.size():
		var missing: Dictionary = kit[cooldowns.size()]
		cooldowns.append(0.0 if missing.get("local_only", false) else maxf(1.0,missing.cd))
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
	dr_states = data.get("dr_states", {}).duplicate(true)
	cc_effects = data.get("cc_effects", {}).duplicate(true)
	target_id = data.target

func reset_identity() -> void:
	death_identity_cleaned = hp <= 0
	charge.clear()
	jump_queued = false
	jump_buffer = 0
	dr_states.clear()
	cc_effects.clear()
	# Instant procs store remaining seconds, shared by casting, auras and snapshots.
	identity = {"meditation": 0.0, "instant_graviton": 0.0, "instant_collapse": 0.0, "entropy_dots": {}, "dots": {}, "heat": 0.0, "resolve": 0.0, "brands": {}, "stars": [], "anchor_left": 0.0, "anchor_pos": Vector3.ZERO, "orbit": 0.0, "root": 0.0, "slow": 0.0, "immune": 0.0, "last": 0.0, "hold": 0.0, "disorient": false, "guard": -1, "guard_left": 0.0, "guard_budget": 0.0, "challenge": -1, "challenge_left": 0.0, "challenge_tick": 0.0, "exposed": -1, "exposed_left": 0.0, "wake": 0.0, "wake_pos": Vector3.ZERO, "wake_end": Vector3.ZERO, "wake_tick": 0.0}
	identity.blink_charges = Kits.BLINK_MAX_CHARGES if champion == "Ember" else 0
	preload("res://scripts/outlaw_mechanics.gd").initialize(self)
	preload("res://scripts/null_mechanics.gd").initialize(self)
