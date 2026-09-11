extends Node3D
## Small, reused presentation pool. No per-shot meshes, lights or combat logic.
const CAPACITY := 24
const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
const VisualClock = preload("res://scripts/snapshot_animation_clock.gd")
var arena
var lines: Array[MeshInstance3D] = []
var life: Array[float] = []
var coins: Dictionary = {}
var coin_tracks: Dictionary = {}
var marks: Dictionary = {}
var lassos: Dictionary = {}
var cursor := 0
var flashes: Array[MeshInstance3D] = []
var flash_life: Array[float] = []
var coin_mesh := CylinderMesh.new()
var gold := StandardMaterial3D.new()
var blue := StandardMaterial3D.new()
var red := StandardMaterial3D.new()

func install(game) -> void:
	arena = game
	name = "OutlawEffects"
	for pair in [[gold, Color("f2c676")], [blue, Color("94d6ff")], [red, Color("e86478")]]:
		pair[0].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pair[0].albedo_color = pair[1]
	coin_mesh.top_radius = .095; coin_mesh.bottom_radius = .095; coin_mesh.height = .025
	coin_mesh.radial_segments = 16; coin_mesh.material = gold
	var mesh := CylinderMesh.new()
	mesh.top_radius = .012; mesh.bottom_radius = .012; mesh.height = 1; mesh.radial_segments = 6
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = .065; flash_mesh.height = .13; flash_mesh.radial_segments = 8; flash_mesh.rings = 4
	for i in CAPACITY:
		var beam := MeshInstance3D.new()
		beam.mesh = mesh; beam.material_override = blue; beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam); beam.hide(); lines.append(beam); life.append(0)
		var flash := MeshInstance3D.new()
		flash.mesh = flash_mesh; flash.material_override = gold; flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flash); flash.hide(); flashes.append(flash); flash_life.append(0)

func shot(from: Vector3, to: Vector3, tag: String) -> void:
	if from.distance_squared_to(to) < .0001: return
	var beam := lines[cursor]
	life[cursor] = .12
	beam.position = (from + to) * .5
	beam.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	beam.scale = Vector3(2.0 if tag == "knife" else 1.0, from.distance_to(to), 1)
	beam.material_override = red if tag == "knife" else (gold if tag == "ricochet" else blue)
	beam.show()
	if tag == "detonation":
		var flash := flashes[cursor]
		flash.position = from
		flash.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
		flash.scale = Vector3(.7,2.4,.7)
		flash_life[cursor] = .055; flash.show()
	cursor = (cursor + 1) % CAPACITY

func _process(delta: float) -> void:
	for i in CAPACITY:
		if flash_life[i] > 0:
			flash_life[i] = maxf(0,flash_life[i]-delta)
			if flash_life[i] <= 0: flashes[i].hide()
		if life[i] > 0:
			life[i] = maxf(0, life[i] - delta)
			if life[i] <= 0: lines[i].hide()
	if arena == null: return
	for id in coins.keys():
		if not arena.actors.has(id) or arena.actors[id].champion != "Outlaw":
			coins[id].queue_free(); coins.erase(id); coin_tracks.erase(id)
	for id in marks.keys():
		if not arena.actors.has(id): marks[id].queue_free(); marks.erase(id)
	var marked: Dictionary = {}
	for id in lassos.keys():
		if not arena.actors.has(id): lassos[id].queue_free(); lassos.erase(id)
	for a in arena.actors.values():
		if a.champion != "Outlaw": continue
		if not lassos.has(a.actor_id):
			var rope = preload("res://scripts/lasso_effect.gd").new()
			add_child(rope); lassos[a.actor_id] = rope
		lassos[a.actor_id].update(arena,a)
		if not coins.has(a.actor_id):
			var node := MeshInstance3D.new()
			node.mesh = coin_mesh; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node); coins[a.actor_id] = node
			coin_tracks[a.actor_id] = {"clock": VisualClock.new(), "origin": Vector3.INF, "direction": Vector3.ZERO, "reported": 0.0}
		var coin: MeshInstance3D = coins[a.actor_id]
		coin.visible = a.hp > 0 and a.identity.coin_left > 0
		if coin.visible:
			coin.position = coin_position(a, delta)
			coin.rotation.x += delta * 15
		else:
			coin_tracks[a.actor_id].clock.reset()
		if a.hp > 0 and arena.Outlaw.deadeye_cast(a):
			for id in a.identity.outlaw_channel.get("marked", []): marked[id] = true
	for a in arena.actors.values():
		if not marks.has(a.actor_id):
			var label := Label3D.new()
			label.text = "DEADEYE"; label.font_size = 34; label.modulate = Color("ffc47b")
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = false
			add_child(label); marks[a.actor_id] = label
		marks[a.actor_id].visible = marked.has(a.actor_id) and a.hp > 0
		marks[a.actor_id].position = a.position + Vector3.UP * 2.5

func coin_position(actor, delta: float) -> Vector3:
	var state: Dictionary = actor.identity
	var track: Dictionary = coin_tracks[actor.actor_id]
	var reported: float = Outlaw.COIN_SECONDS - state.coin_left
	if track.origin != state.coin_origin or track.direction != state.coin_direction or reported < track.reported - .1:
		track.clock.reset()
	track.origin = state.coin_origin
	track.direction = state.coin_direction
	track.reported = reported
	if actor.presentation_snapshot_serial == 0:
		return state.coin_position
	var time: float = track.clock.advance(reported, delta, actor.presentation_snapshot_serial, 0, Outlaw.COIN_SECONDS)
	var displayed: Vector3 = state.coin_origin + state.coin_direction * Outlaw.COIN_SPEED * time + Vector3.UP * (5.4 * time - 3.0 * time * time)
	# Cosmetic travel can advance between packets, but must not pass through
	# visible terrain. Ricochet validation still uses the server coin_position.
	if displayed.distance_squared_to(state.coin_position) > .000001:
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(state.coin_position, displayed, 1))
		if not hit.is_empty(): displayed = hit.position
	return displayed
