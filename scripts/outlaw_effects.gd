extends Node3D
## Small, reused presentation pool. No per-shot meshes, lights or combat logic.
const CAPACITY := 24
var arena
var lines: Array[MeshInstance3D] = []
var life: Array[float] = []
var coins: Dictionary = {}
var marks: Dictionary = {}
var cursor := 0
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
	for i in CAPACITY:
		var beam := MeshInstance3D.new()
		beam.mesh = mesh; beam.material_override = blue; beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam); beam.hide(); lines.append(beam); life.append(0)

func shot(from: Vector3, to: Vector3, tag: String) -> void:
	if from.distance_squared_to(to) < .0001: return
	var beam := lines[cursor]
	life[cursor] = .12
	beam.position = (from + to) * .5
	beam.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	beam.scale = Vector3(2.0 if tag == "knife" else 1.0, from.distance_to(to), 1)
	beam.material_override = red if tag == "knife" else (gold if tag == "ricochet" else blue)
	beam.show()
	cursor = (cursor + 1) % CAPACITY

func _process(delta: float) -> void:
	for i in CAPACITY:
		if life[i] > 0:
			life[i] = maxf(0, life[i] - delta)
			if life[i] <= 0: lines[i].hide()
	if arena == null: return
	for id in coins.keys():
		if not arena.actors.has(id): coins[id].queue_free(); coins.erase(id)
	for id in marks.keys():
		if not arena.actors.has(id): marks[id].queue_free(); marks.erase(id)
	var marked: Dictionary = {}
	for a in arena.actors.values():
		if a.champion != "Outlaw": continue
		if not coins.has(a.actor_id):
			var node := MeshInstance3D.new()
			node.mesh = coin_mesh; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node); coins[a.actor_id] = node
		var coin: MeshInstance3D = coins[a.actor_id]
		coin.visible = a.hp > 0 and a.identity.coin_left > 0
		if coin.visible:
			coin.position = a.identity.coin_position; coin.rotation.x += delta * 15
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
