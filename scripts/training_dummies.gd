extends RefCounted
## Reserved actor IDs identify world fixtures on both server and clients.
const IDS := [-100, -101, -102]
const POSITIONS := [Vector3(-6, 0.1, -13), Vector3(0, 0.1, -13), Vector3(6, 0.1, -13)]
static func spawn(game) -> void:
	if not game.world_mode or not game.authoritative(): return
	for i in range(IDS.size()):
		if not game.actors.has(IDS[i]): game.spawn_actor(IDS[i], 0, 1, "Vanguard", POSITIONS[i])
static func decorate(actor) -> void:
	actor.champion_model.hide()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("79543a")
	wood.roughness = 0.95
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color("d5b378")
	straw.roughness = 1.0
	for part in [[Vector3(0, 1.1, 0), Vector3(0.18, 2.2, 0.18), wood], [Vector3(0, 1.55, 0), Vector3(1.7, 0.18, 0.18), wood], [Vector3(0, 1.55, 0), Vector3(0.7, 0.85, 0.45), straw], [Vector3(0, 2.2, 0), Vector3(0.45, 0.45, 0.45), straw], [Vector3(0, 0.08, 0), Vector3(1.2, 0.16, 1.2), wood]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[1]
		mesh.mesh = box
		mesh.position = part[0]
		mesh.material_override = part[2]
		actor.add_child(mesh)
