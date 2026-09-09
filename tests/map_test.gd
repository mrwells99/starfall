extends SceneTree

const Layout = preload("res://scripts/arena_layout.gd")
const Navigation = preload("res://scripts/arena_navigation.gd")

var failures := 0
var checks := 0
var arena

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error(description)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

func settle(actor, position: Vector3) -> void:
	actor.position = position + Vector3.UP * 0.03
	actor.velocity = Vector3.ZERO
	for frame in range(8):
		actor.velocity = Vector3(0, -2, 0)
		actor.move_and_slide()
		await physics_frame

func test_navigation() -> void:
	var nav := Navigation.new()
	# Flood every free grid cell: disconnected pockets would strand bots even
	# if a handful of hand-picked routes happened to pass.
	var visited := {Vector2i.ZERO: true}
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if nav.grid.is_in_boundsv(next) and not nav.grid.is_point_solid(next) and not visited.has(next):
				visited[next] = true
				pending.append(next)
	var free_count := 0
	for x in range(Layout.GRID_MIN, Layout.GRID_MAX + 1):
		for z in range(Layout.GRID_MIN, Layout.GRID_MAX + 1):
			if not nav.grid.is_point_solid(Vector2i(x, z)):
				free_count += 1
	check(visited.size() == free_count, "Every walkable navigation cell belongs to one connected arena")
	for side in [-1, 1]:
		var route := nav.route(Vector3(10 * side, 0, 0), Vector3(15 * side, Layout.TERRACE_HEIGHT, 0))
		var uses_ramp_mouth := false
		for point in route:
			if absf(point.y) >= Layout.RAMP_END:
				uses_ramp_mouth = true
		check(not route.is_empty() and uses_ramp_mouth, "Bot route enters terrace %d through a ramp mouth" % side)
		check(not nav.route(Vector3(15 * side, 0, 12), Vector3(15 * side, Layout.TERRACE_HEIGHT, 0)).is_empty(), "Terrace %d is reachable from its staircase" % side)
	check(nav.nearest(Vector3(100, 0, -100)) == Vector2i(17, -17), "Navigation clamps destinations inside arena bounds")

func test_world() -> void:
	var player = arena.actors[1]
	var enemy = arena.actors[2]
	for center in Layout.cover_centers():
		player.position = center + Vector3(0, 0, 4)
		enemy.position = center - Vector3(0, 0, 4)
		await physics_frame
		check(not arena.has_los(player, enemy), "Ruined cover at %s blocks spell line of sight" % center)
		await settle(player, center + Vector3(0, 0, 4))
		arena.move_ability(player, Vector3(0, 0, -8))
		check(player.position.z > center.z + 1.8, "Capsule sweep cannot cross ruined cover at %s" % center)
		# Probe near each widened end: a narrower leftover collider could pass
		# the centerline checks while spells and characters cross visible stone.
		for side in [-1, 1]:
			var end_x: float = center.x + side * (Layout.COVER_BODY_SIZE.x * 0.5 - 0.2)
			player.position = Vector3(end_x, 0, center.z + 4)
			enemy.position = Vector3(end_x, 0, center.z - 4)
			await physics_frame
			check(not arena.has_los(player, enemy), "Wide ruin end at x=%s blocks line of sight" % end_x)
			await settle(player, Vector3(end_x, 0, center.z + 4))
			arena.move_ability(player, Vector3(0, 0, -8))
			check(player.position.z > center.z + 1.8, "Capsule cannot cross the wide ruin end at x=%s" % end_x)
	var spawn_points: Array[Vector3] = [Vector3.ZERO]
	arena.mode = 3
	for side in [0, 1]:
		for index in range(3):
			spawn_points.append(arena.spawn_position(side, index))
	arena.mode = 1
	for position in spawn_points:
		var hit := ray(position + Vector3.UP * 5, position - Vector3.UP)
		check(not hit.is_empty() and absf(hit.position.y) < 0.06, "Center and team spawn floor is open at %s" % position)
	player.position = Vector3(0, 0, 9)
	enemy.position = Vector3(0, 0, -9)
	await physics_frame
	check(arena.has_los(player, enemy), "The central engagement lane has open line of sight")
	for side in [-1, 1]:
		for z in [-8, 0, 8]:
			var position := Vector3(15 * side, 0, z)
			var hit := ray(position + Vector3.UP * 5, position - Vector3.UP)
			check(not hit.is_empty() and absf(hit.position.y - Layout.surface_height(position)) < 0.04, "Terrace/ramp collision surface matches its height at %s" % position)
	for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var position: Vector3 = direction * 15
		position.y = Layout.surface_height(position)
		await settle(player, position)
		# Exercise Ember's actual Blink resolution against all four walls.
		player.look_at(player.position + direction, Vector3.UP)
		arena.resolve_spell(player, 6, player)
		check(absf(player.position.x) < 17.3 and absf(player.position.z) < 17.3, "Blink is contained by arena boundary %s" % direction)

func test_bot_terrace(side: int, start: Vector3) -> void:
	var target = arena.actors[1]
	var bot = arena.actors[2]
	bot.champion = "Vanguard"
	# Navigation approaches to the primary ability's actual range. Changing only
	# the class name leaves Ember's ranged kit and never exercises the ramp.
	bot.kit = arena.Kits.get_kit(bot.champion)
	bot.cooldowns.resize(bot.kit.size())
	bot.cooldowns.fill(0.0)
	bot.reset_identity()
	bot.owner_peer = 0
	# Keep this a movement integration test: no Charge, damage, or stun can
	# substitute for walking up the physical ramp using the actual bot logic.
	bot.ai_timer = 1000.0
	bot.path_timer = 0
	bot.casting = -1
	bot.path.clear()
	await settle(target, Vector3(15 * side, Layout.TERRACE_HEIGHT, 0))
	await settle(bot, start)
	for frame in range(420):
		arena.tick_actor(bot, 1.0 / 60.0)
		await physics_frame
		if Vector2(bot.position.x - target.position.x, bot.position.z - target.position.z).length() <= 2.9:
			break
	check(absf(bot.position.y - Layout.TERRACE_HEIGHT) < 0.08, "Bot physically climbs terrace %d from %s" % [side, start])
	check(Vector2(bot.position.x - target.position.x, bot.position.z - target.position.z).length() <= 2.9, "Bot reaches its opponent on terrace %d from %s" % [side, start])
	check(bot.is_on_floor(), "Bot remains grounded on terrace %d" % side)

func run() -> void:
	# Fullscreen is the project default now; pin the window so screenshot framing
	# does not depend on the monitor running the suite.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 800))
	test_navigation()
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.mode = 1
	arena.roster = {1: {"champion": "Ember", "team": 0}}
	arena.begin_round()
	arena.phase = "match"
	await physics_frame
	await test_world()
	await test_bot_terrace(-1, Vector3(-15, 0, -12))
	await test_bot_terrace(1, Vector3(15, 0, 12))
	await test_bot_terrace(1, Vector3(10, 0, 0))
	print("Map checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
