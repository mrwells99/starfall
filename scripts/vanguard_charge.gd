extends RefCounted

# Committed, server-owned movement. The replicated route is also safe to replay
# locally: advance() moves the capsule but never roots, damages or chooses targets.
const SPEED := 32.0
const STOP_DISTANCE := 1.8
const ROOT_DURATION := 3.0
const REPATH_INTERVAL := .15
const Layout = preload("res://scripts/arena_layout.gd")

static func start(game, actor, victim, route: PackedVector3Array, damage: float) -> void:
	actor.charge = {"target": victim.actor_id, "path": route, "destination": victim.position, "repath": REPATH_INTERVAL, "damage": damage}
	actor.jump_queued = false
	actor.jump_buffer = 0.0
	actor.velocity = Vector3.ZERO
	actor.motion_revision += 1
	game.ClassMechanics.control(game, actor, victim, ROOT_DURATION, "Charge", true)
	game.combat_event(actor.actor_id, victim.actor_id, "CHARGE", game.GOLD)

static func tick(game, actor, delta: float) -> void:
	var target = game.actors.get(int(actor.charge.target))
	if target == null or target.hp <= 0 or actor.hp <= 0 or not game.may_harm(actor, target):
		actor.charge.clear()
		actor.velocity = Vector3.ZERO
		return
	# Do not recheck cast range, facing or LOS after acceptance. A displacement,
	# a ramp or a newly blocked route can require a different way to the target.
	actor.charge.repath -= delta
	if actor.charge.repath <= 0:
		if target.position.distance_to(actor.charge.destination) > .35 or actor.charge.path.is_empty():
			actor.charge.path = route_to(game, actor, target.position)
			actor.charge.destination = target.position
		actor.charge.repath = REPATH_INTERVAL
	advance(actor, delta)
	if actor.position.distance_to(target.position) <= STOP_DISTANCE + .08 and not ground_route(actor, actor.position, target.position).is_empty():
		var power: float = actor.charge.damage
		actor.charge.clear()
		actor.velocity = Vector3.ZERO
		game.damage(actor, target, power)

static func advance(actor, delta: float) -> void:
	actor.jump_queued = false
	actor.jump_buffer = 0.0
	var before: Vector3 = actor.position
	var budget := SPEED * delta
	var route: PackedVector3Array = actor.charge.path
	while budget > .0001 and not route.is_empty():
		var offset: Vector3 = route[0] - actor.position
		var distance := offset.length()
		if distance < .025:
			route.remove_at(0)
			continue
		var travel := minf(distance, budget)
		var target_distance: float = actor.position.distance_to(actor.charge.destination)
		if target_distance <= STOP_DISTANCE + SPEED * delta and not ground_route(actor, actor.position, actor.charge.destination).is_empty():
			travel = minf(travel, maxf(0, target_distance - STOP_DISTANCE))
			if travel <= .0001:
				break
		var direction := offset / distance
		if Vector2(direction.x, direction.z).length_squared() > .0001:
			actor.rotation.y = atan2(-direction.x, -direction.z)
		var collision = actor.move_and_collide(direction * travel, false, .01)
		budget -= travel
		if collision != null:
			# Physics contact can finish a fraction of a millimetre inside a
			# surface. Leave explicit clearance before searching a new route.
			actor.move_and_collide(collision.get_normal() * .005)
			# Remain at the collision-safe position and request a fresh route.
			route.clear()
			actor.charge.repath = 0.0
			break
	actor.charge.path = route
	actor.velocity = (actor.position - before) / maxf(delta, .0001)

static func ground_point(point: Vector3) -> Vector3:
	return Vector3(point.x, Layout.surface_height(point) + .025, point.z)

# Sample surface changes so shortcuts cannot cut through a terrace ledge or
# through a ramp. Every segment tests the actual character capsule, not a ray.
static func ground_route(actor, from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var previous := from
	var departure := ground_point(from)
	if from.y - departure.y > .55:
		# An airborne caster can descend onto the route, with a capsule sweep.
		# Standing on an unsupported solid obstacle does not permit phasing down.
		var landing_pose: Transform3D = actor.transform
		landing_pose.origin = from + Vector3.UP * .01
		if actor.test_move(landing_pose, departure - from):
			return PackedVector3Array()
		result.append(departure)
		previous = departure
	var steps := maxi(1, ceili(Vector2(to.x - from.x, to.z - from.z).length() / .5))
	for i in range(1, steps + 1):
		var point := ground_point(from.lerp(to, float(i) / steps))
		# Approach the ground beneath a jumping target. Actual 3D melee distance
		# is still required on arrival; do not generate a flying route to them.
		if absf(point.y - previous.y) > .55:
			return PackedVector3Array()
		var pose: Transform3D = actor.transform
		pose.origin = previous + Vector3.UP * .01
		if actor.test_move(pose, point - previous):
			return PackedVector3Array()
		result.append(point)
		previous = point
	return result

static func route_to(game, actor, destination: Vector3) -> PackedVector3Array:
	var direct := ground_route(actor, actor.position, destination)
	if not direct.is_empty():
		return direct
	# Reuse the arena's walkable grid (including ramp entrances), then lazily
	# reject blocked edges against real collision. This avoids a physics query
	# for every map cell on every cast while allowing detours around new blockers.
	var graph := AStar3D.new()
	var points := {}
	var width: int = Layout.GRID_MAX - Layout.GRID_MIN + 1
	for x in range(Layout.GRID_MIN, Layout.GRID_MAX + 1):
		for z in range(Layout.GRID_MIN, Layout.GRID_MAX + 1):
			var cell := Vector2i(x, z)
			if game.nav.grid.is_point_solid(cell):
				continue
			var id: int = (x - Layout.GRID_MIN) * width + z - Layout.GRID_MIN
			points[cell] = id
			graph.add_point(id, ground_point(Vector3(x, 0, z)))
	for cell in points:
		for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var next: Vector2i = cell + step
			if not points.has(next):
				continue
			if step.x != 0 and step.y != 0 and (not points.has(cell + Vector2i(step.x, 0)) or not points.has(cell + Vector2i(0, step.y))):
				continue
			graph.connect_points(points[cell], points[next])
	var start := width * width
	var finish := start + 1
	graph.add_point(start, actor.position)
	graph.add_point(finish, destination)
	for id in points.values():
		var point := graph.get_point_position(id)
		if point.distance_to(actor.position) <= 3.0 and not ground_route(actor, actor.position, point).is_empty():
			graph.connect_points(start, id)
		if point.distance_to(destination) <= 3.0 and not ground_route(actor, point, destination).is_empty():
			graph.connect_points(id, finish)
	if graph.get_point_connections(start).is_empty() or graph.get_point_connections(finish).is_empty():
		return PackedVector3Array()
	while true:
		var ids := graph.get_id_path(start, finish)
		if ids.is_empty():
			return PackedVector3Array()
		var result := PackedVector3Array()
		var valid := true
		for i in range(1, ids.size()):
			var segment := ground_route(actor, graph.get_point_position(ids[i - 1]), graph.get_point_position(ids[i]))
			if segment.is_empty():
				graph.disconnect_points(ids[i - 1], ids[i])
				valid = false
				break
			result.append_array(segment)
		if valid:
			return result
	return PackedVector3Array()
