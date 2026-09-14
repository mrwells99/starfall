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
var falling_coins: Array[Dictionary] = []
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
	for i in range(falling_coins.size() - 1, -1, -1):
		var falling: Dictionary = falling_coins[i]
		advance_falling_coin(falling.node, falling.track, delta)
		if not falling.node.visible:
			falling.node.queue_free()
			falling_coins.remove_at(i)
	for id in coins.keys():
		if not arena.actors.has(id) or arena.actors[id].champion != "Outlaw":
			retire_coin(id)
			coins.erase(id); coin_tracks.erase(id)
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
		update_coin(a, delta)
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

# A spent combo is still a physical-looking coin. Only a ground impact hides
# it; wall/ceiling impacts make it fall, and a new toss gets a separate mesh.
func retire_coin(id: int) -> void:
	var node: MeshInstance3D = coins[id]
	if node.visible:
		falling_coins.append({"node": node, "track": coin_tracks[id]})
	else:
		node.queue_free()

func create_coin(id: int) -> void:
	var node := MeshInstance3D.new()
	node.mesh = coin_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node); node.hide(); coins[id] = node
	coin_tracks[id] = {"clock": VisualClock.new(), "origin": Vector3.INF,
		"direction": Vector3.ZERO, "reported": 0.0, "available": false,
		"velocity": Vector3.ZERO, "deflected": false}

func update_coin(actor, delta: float) -> void:
	var id: int = actor.actor_id
	if not coins.has(id): create_coin(id)
	var track: Dictionary = coin_tracks[id]
	var state: Dictionary = actor.identity
	var available: bool = state.coin_left > 0 and actor.hp > 0
	var reported: float = Outlaw.COIN_SECONDS - state.coin_left
	var launched: bool = available and (not track.available or track.origin != state.coin_origin or track.direction != state.coin_direction or reported < track.reported - .1)
	if launched:
		retire_coin(id)
		create_coin(id)
		track = coin_tracks[id]
		track.origin = state.coin_origin
		track.direction = state.coin_direction
		coins[id].position = state.coin_origin
		coins[id].show()
	track.available = available
	var coin: MeshInstance3D = coins[id]
	if not coin.visible: return
	if available and not track.deflected:
		move_coin(coin, track, coin_position(actor, delta))
	else:
		track.clock.reset()
		advance_falling_coin(coin, track, delta)
	coin.rotation.x += delta * 15

func advance_falling_coin(coin: MeshInstance3D, track: Dictionary, delta: float) -> void:
	# Sweep small ballistic steps so low frame rates do not skip thin terrain.
	var remaining := maxf(0, delta)
	while remaining > 0 and coin.visible:
		var step := minf(remaining, 1.0 / 60.0)
		var next: Vector3 = coin.position + track.velocity * step + Vector3.DOWN * 3.0 * step * step
		track.velocity += Vector3.DOWN * 6.0 * step
		move_coin(coin, track, next)
		remaining -= step

func move_coin(coin: MeshInstance3D, track: Dictionary, next: Vector3) -> void:
	if coin.position.distance_squared_to(next) < .0000001: return
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(coin.position, next, 1))
	if hit.is_empty():
		coin.position = next
		return
	var normal: Vector3 = hit.normal
	# An inside/degenerate contact has no usable surface. Let the visual
	# escape it; do not treat it as a landing or slide on a zero normal.
	if normal.is_zero_approx():
		coin.position = next
		return
	normal = normal.normalized()
	coin.position = hit.position + normal * .015
	if normal.y > .5 and track.velocity.y <= 0:
		coin.hide()
		track.clock.reset()
	else:
		track.deflected = true
		track.velocity = track.velocity.slide(normal)

func coin_position(actor, delta: float) -> Vector3:
	var state: Dictionary = actor.identity
	var track: Dictionary = coin_tracks[actor.actor_id]
	var reported: float = Outlaw.COIN_SECONDS - state.coin_left
	track.reported = reported
	var time: float = track.clock.advance(reported, delta, actor.presentation_snapshot_serial, 0, Outlaw.COIN_SECONDS)
	var launch_velocity: Vector3 = state.coin_direction * Outlaw.COIN_SPEED + state.get("coin_momentum", Vector3.ZERO)
	track.velocity = launch_velocity + Vector3.UP * (5.4 - 6.0 * time)
	if actor.presentation_snapshot_serial == 0: return state.coin_position
	return state.coin_origin + launch_velocity * time + Vector3.UP * (5.4 * time - 3.0 * time * time)
