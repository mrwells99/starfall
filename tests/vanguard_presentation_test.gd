extends SceneTree

const Fighter = preload("res://scripts/combatant.gd")
const Art = preload("res://scripts/vanguard_art.gd")
const Strike = preload("res://scripts/vanguard_strike.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func geometry_count(node: Node) -> Vector2i:
	var count := Vector2i.ZERO
	if node is MeshInstance3D:
		count.x += 1
		for i in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(i)
			var indices = arrays[Mesh.ARRAY_INDEX]
			count.y += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	for child in node.get_children():
		count += geometry_count(child)
	return count

func colliders(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		count += colliders(child)
	return count

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for side in 2:
		var fighter := Fighter.new()
		fighter.setup(side + 1, 0, side, "Vanguard")
		stage.add_child(fighter)
		var model = fighter.champion_model
		var rig: Dictionary = model.vanguard
		var geometry := geometry_count(model)
		print("Vanguard meshes/triangles: ", geometry)
		check(geometry.x <= 65 and geometry.y <= 12000, "Rigid art stays within a bounded geometry budget")
		check(colliders(model) == 0, "Art and signature effect add no colliders")
		var capsule: CapsuleShape3D = fighter.get_child(0).shape
		check(is_equal_approx(capsule.radius, 0.42) and is_equal_approx(capsule.height, 1.8), "Shared combat capsule remains intact")
		var transform_before := fighter.transform
		fighter.shield = 5
		model.animate(0.1, fighter)
		check(rig.ward.visible and rig.pulse.visible, "Actual shield activation shows its sigil and pulse")
		for i in 40:
			fighter.shield -= 0.02
			model.animate(0.02, fighter)
		check(rig.ward.visible and not rig.pulse.visible, "Activation ends while shield indicator persists")
		fighter.shield = 0
		model.animate(0.02, fighter)
		check(not rig.ward.visible and not rig.pulse.visible, "Expired or dispelled shield leaves no effect")
		model.present_strike()
		model.animate(0.01, fighter)
		check(model.right_arm.rotation.x < -1, "Confirmed strike poses the weapon immediately")
		model.animate(0.4, fighter)
		check(model.right_arm.rotation.x > -0.2, "Strike recovers to guard")
		fighter.hp = 80
		model.animate(0.01, fighter)
		check(rig.hit_left > 0, "Actual HP loss triggers recoil")
		model.animate(0.3, fighter)
		fighter.hp = 100
		fighter.flash = 0.16
		model.animate(0.01, fighter)
		check(is_zero_approx(rig.hit_left), "Healing flashes do not trigger damage recoil")
		fighter.flash = 0
		fighter.casting = 5
		model.animate(0.1, fighter)
		check(model.left_arm.rotation.x < -0.5, "Mend retains a readable casting pose")
		fighter.casting = -1
		fighter.shield = 5
		fighter.hp = 0
		model.animate(0.4, fighter)
		check(not rig.ward.visible and not rig.pulse.visible and model.rotation.x < -1, "Death clears shield art and preserves defeat pose")
		fighter.hp = 100
		fighter.shield = 0
		model.animate(0.4, fighter)
		check(is_zero_approx(model.rotation.x), "Respawn recovers upright")
		check(fighter.transform == transform_before, "Poses never change combat transform")
		# Walk a full range of motion and inspect actual transformed foot vertices.
		var min_foot := INF
		for i in 120:
			fighter.position.z -= 0.08
			var before := fighter.transform
			model.animate(1.0 / 60.0, fighter)
			for knee in rig.knees:
				for mesh in knee.get_children():
					if mesh is MeshInstance3D:
						for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
							min_foot = minf(min_foot, (mesh.global_transform * vertex).y - fighter.position.y)
			check(fighter.transform == before, "Walking pose preserves the body")
		check(min_foot > -0.035, "Walking feet do not sweep below the ground")
		print("Minimum walking foot height: ", min_foot)
		fighter.queue_free()
	# Guard against the inward normals that can make bevels appear flat.
	var model = preload("res://scripts/champion_model.gd").new()
	var panel := Art.armor(model, model, Vector3.ZERO, Vector2.ONE, 0.1, StandardMaterial3D.new())
	var arrays: Array = panel.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_NORMAL][6].z < -0.95, "Armor front normals face outward")
	model.free()
	Strike.spawn(stage, Vector3.ZERO, Vector3(0, 0, -3.5), Color.CYAN)
	check(stage.has_node("VanguardStrike"), "Strike appears at maximum melee reach")
	check(colliders(stage.get_node("VanguardStrike")) == 0, "Strike has no physics")
	await create_timer(0.3).timeout
	check(not stage.has_node("VanguardStrike"), "Strike cleans up after its fade")
	stage.queue_free()
	await process_frame
	# Matches the "<label>: N passed / M total" line every other suite prints, so
	# tests/check_suite.sh can gate on it in CI.
	print("Vanguard presentation: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
