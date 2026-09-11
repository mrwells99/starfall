extends SceneTree
const Course = preload("res://scripts/world_starwalk.gd")
var game
var checks := 0
var failures := 0
func ck(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")

func landing_supports(actor, index: int) -> bool:
	var destination: Vector3 = Course.platform_position(index)
	var size: Vector3 = Course.platform_size(index)
	if not actor.is_on_floor() or absf(actor.position.y - destination.y) > 0.1:
		return false
	# Require the actor's feet inside the actual rectangle, rather than a broad
	# radius that could count the edge of an adjacent island as a successful jump.
	if absf(actor.position.x - destination.x) > size.x / 2 - 0.05 or absf(actor.position.z - destination.z) > size.z / 2 - 0.05:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.position + Vector3.UP * 0.15, actor.position - Vector3.UP * 0.25, 1)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider.name == "Landing%d" % index

func jump_to_next(actor, index: int) -> bool:
	var origin: Vector3 = Course.platform_position(index)
	var target: Vector3 = Course.platform_position(index + 1)
	var size: Vector3 = Course.platform_size(index)
	var direction := Vector3(target.x - origin.x, 0, target.z - origin.z).normalized()
	var distance := Vector2(target.x - origin.x, target.z - origin.z).length()
	# Full capsule support at takeoff, even for the narrowest ledges. Movement
	# already reaches normal running speed on its first grounded step.
	var takeoff_limit := minf((size.x / 2 - 0.52) / maxf(absf(direction.x), 0.001), (size.z / 2 - 0.52) / maxf(absf(direction.z), 0.001))
	# Estimate a useful takeoff point, then validate it through the real physics.
	# This includes the gravity applied on the initial jump frame (60Hz).
	var launch_speed := 7.0 - 10.0 / 60.0
	var discriminant := launch_speed * launch_speed - 40.0 * (target.y - origin.y)
	if discriminant <= 0: return false
	var flight_time := (launch_speed + sqrt(discriminant)) / 20.0
	var centered_offset := clampf(distance - 6.5 * flight_time, -takeoff_limit, takeoff_limit)
	for adjustment in [0.0, 0.15, -0.15, 0.3, -0.3]:
		var offset := clampf(centered_offset + adjustment, -takeoff_limit, takeoff_limit)
		actor.position = origin + direction * offset + Vector3.UP * 0.05
		actor.velocity = Vector3.ZERO
		actor.move_input = Vector2.ZERO
		actor.jump_queued = false
		actor.jump_buffer = 0
		for frame in range(8):
			await physics_frame
			game.simulate_movement(actor, 1.0 / 60)
		if not landing_supports(actor, index): continue
		actor.rotation.y = atan2(-direction.x, -direction.z)
		actor.move_input = Vector2(0, -1)
		actor.jump_queued = true
		var airborne := false
		for frame in range(48):
			await physics_frame
			game.simulate_movement(actor, 1.0 / 60)
			airborne = airborne or not actor.is_on_floor()
			if airborne and actor.is_on_floor():
				if landing_supports(actor, index + 1): return true
				break
			if actor.position.y < origin.y - 0.25: break
	return false

func run() -> void:
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	ck(game.world_starwalk == null, "Normal arena has no Starwalk")
	game.world_mode = true
	game.roster = {1: {"champion": "Ember", "team": 0}}
	game.begin_round()
	var actor = game.actors[1]
	await physics_frame
	ck(Course.COUNT >= 72, "Starwalk contains at least 72 jumps")
	ck(game.world_starwalk.get_child_count() >= Course.COUNT + 1, "World creates the full collision course")
	ck(Course.platform_position(Course.COUNT).y - Course.START.y >= 50, "The course climbs at least fifty meters")
	var narrow_platforms := 0
	for i in range(1, Course.COUNT):
		var size: Vector3 = Course.platform_size(i)
		if size.x <= 2.0 and size.z <= 2.0: narrow_platforms += 1
	ck(narrow_platforms >= Course.COUNT - 5, "Most landings are demanding ledges no wider than two meters")
	actor.position = Course.ENTRY
	var revision: int = actor.motion_revision
	game.tick_world(0)
	ck(actor.position == Course.ENTRY, "Entry does not teleport instantly")
	game.tick_world(7.9)
	ck(actor.position == Course.ENTRY, "Entry waits the full eight seconds")
	actor.position = Course.ENTRY + Vector3.RIGHT * 2
	game.tick_world(0.1)
	ck(not game.world_starwalk.entry_waits.has(1), "Stepping out cancels launch progress")
	actor.position = Course.ENTRY
	game.tick_world(0.2)
	ck(actor.position == Course.ENTRY, "Reentry starts a fresh wait")
	game.duels[1] = 2
	game.tick_world(8)
	ck(actor.position == Course.ENTRY and not game.world_starwalk.entry_waits.has(1), "A duel cancels and blocks launch")
	game.duels.clear()
	game.tick_world(7.75)
	ck(actor.position == Course.ENTRY, "Ending a duel requires a new full wait")
	game.tick_world(0.25)
	ck(actor.position.distance_to(Course.START) < 0.2, "Eight continuous seconds launch to the first island")
	ck(actor.motion_revision == revision + 1, "Gate invalidates stale predicted movement")
	game.spawn_actor(2, 2, 0, "Ember", Course.HOME)
	var other = game.actors[2]
	actor.position = Course.ENTRY
	game.tick_world(4)
	other.position = Course.ENTRY
	game.tick_world(3.9)
	ck(actor.position == Course.ENTRY and other.position == Course.ENTRY, "Overlapping players retain independent incomplete countdowns")
	game.tick_world(0.1)
	ck(actor.position.distance_to(Course.START) < 0.2 and other.position == Course.ENTRY, "The first player launches without advancing the second player's timer")
	other.hp = 0
	game.tick_world(4)
	ck(other.position == Course.ENTRY and not game.world_starwalk.entry_waits.has(2), "Death cancels the pending countdown and cannot launch a dead actor")
	other.hp = 100
	game.tick_world(7.9)
	ck(other.position == Course.ENTRY, "Returning alive starts a fresh eight-second wait")
	game.tick_world(0.1)
	ck(other.position.distance_to(Course.START) < 0.2, "A living player can launch after waiting again")
	other.position = Course.HOME
	# Exercise real capsule movement and the unchanged 7m/s jump / 20m/s² gravity.
	for i in range(Course.COUNT):
		actor.position = Course.platform_position(i) + Vector3.UP * 0.05
		actor.velocity = Vector3.ZERO
		actor.move_input = Vector2.ZERO
		for frame in range(8):
			await physics_frame
			game.simulate_movement(actor, 1.0 / 60)
		ck(landing_supports(actor, i), "Platform %d supports the capsule" % i)
		ck(await jump_to_next(actor, i), "Jump %d reaches its actual landing using normal movement" % (i + 1))
		if (i + 1) % 24 == 0: print("Starwalk movement: %d / %d jumps checked" % [i + 1, Course.COUNT])
	actor.position = Course.ENTRY
	game.tick_world(2)
	actor.hp = 61
	actor.cooldowns[0] = 7
	actor.position = Vector3(80, -7, 20)
	actor.velocity = Vector3(4, -20, 1)
	actor.jump_queued = true
	revision = actor.motion_revision
	game.tick_world(0)
	ck(actor.position.distance_to(Course.HOME) < 0.2, "Void fall returns to map center")
	ck(not game.world_starwalk.entry_waits.has(1), "A rescue also cancels any portal countdown")
	ck(actor.velocity == Vector3.ZERO and not actor.jump_queued, "Rescue clears falling momentum and queued jump")
	ck(actor.hp == 61 and actor.cooldowns[0] == 7, "Rescue preserves health and cooldowns")
	ck(actor.motion_revision == revision + 1, "Rescue reconciles as a teleport")
	actor.position = Course.platform_position(Course.COUNT)
	game.tick_world(0)
	ck(actor.position.distance_to(Course.HOME) < 0.2, "Finish gate returns to center")
	game.world_mode = false
	await physics_frame
	ck(game.world_starwalk == null, "Leaving World removes the extension")
	var query := PhysicsRayQueryParameters3D.create(Course.START + Vector3.UP * 2, Course.START - Vector3.UP * 2, 1)
	ck(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "World collision does not leak into arena modes")
	game.world_mode = true
	await physics_frame
	ck(game.world_starwalk != null, "Reentering World rebuilds the course")
	print("Starwalk checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
