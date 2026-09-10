extends RefCounted
## Authoritative camera-ray bursts. Presentation never authorizes a hit.
const RANGE := 18.0
const TIMEOUT := 1.25
var bursts: Dictionary = {}

func reset() -> void:
	bursts.clear()

func blocked(game, actor) -> bool:
	return game.phase != "match" or actor.champion != "Outlaw" or actor.hp <= 0 or actor.stunned > 0 or actor.casting >= 0 or actor.locked > 0 or game.CC.spell_block(actor) > 0 or actor.identity.roll_left > 0 or actor.identity.backflip_active

func camera_valid(game, actor, origin: Vector3, direction: Vector3, stamp: float) -> bool:
	if not origin.is_finite() or not direction.is_finite() or absf(direction.length_squared()-1.0) > .01: return false
	if absf(direction.y) > .93: return false
	var history: Dictionary = game.aimed_combat.sample(actor,stamp)
	if history.is_empty(): return false
	var right := direction.cross(Vector3.UP).normalized()
	# Bound the submitted camera to the actual shoulder/zoom envelope. Check both
	# sampled and current roots to accommodate interpolation and local prediction.
	for root_position in [history.root,actor.position]:
		var pivot: Vector3 = root_position+Vector3.UP*1.6
		var offset := origin-pivot
		var rear := -offset.dot(direction)
		var lateral := offset+direction*rear
		var side := lateral.dot(right)
		if rear < -.15 or rear > 9.35 or side < -.35 or side > .95 or (lateral-right*side).length() > .65: continue
		var query := PhysicsRayQueryParameters3D.create(pivot,origin,1)
		query.hit_from_inside = true
		if game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false

func emit(game, result: Dictionary, only_peer: int = -1) -> void:
	game.report_detonation_shot(game.epoch,result)
	if game.network:
		if only_peer > 1: game.report_detonation_shot.rpc_id(only_peer,game.epoch,result)
		elif only_peer == -1: game.report_detonation_shot.rpc(game.epoch,result)

func reject(game, id: int, peer: int, burst_id: int, reason: String) -> bool:
	var committed: bool = bursts.has(id) and bursts[id].id == burst_id
	if committed: bursts.erase(id)
	emit(game,{"source":id,"burst":burst_id,"done":true,"fired":false,"committed":committed,"reason":reason},peer)
	return false

func enqueue(game, id: int, peer: int, seq: int, burst_id: int, index: int, origin: Vector3, direction: Vector3, stamp: float, revision: int) -> bool:
	if not game.authoritative() or not game.hitboxes_enabled or not game.actors.has(id): return false
	var actor = game.actors[id]
	if peer > 0 and actor.owner_peer != peer: return false
	if seq <= actor.last_action_seq or seq > 2147483647 or burst_id <= 0 or index < 0 or index >= game.Outlaw.MAX_STACKS: return false
	var clock: float = game.aimed_combat.clock
	if not is_finite(stamp) or stamp < 0 or clock-stamp > game.aimed_combat.allowed_age(game,peer) or stamp-clock > game.aimed_combat.CLOCK_TOLERANCE: return reject(game,id,peer,burst_id,"Shot timing expired")
	if revision != actor.motion_revision or blocked(game,actor): return reject(game,id,peer,burst_id,"Cannot fire right now")
	if not camera_valid(game,actor,origin,direction,stamp): return reject(game,id,peer,burst_id,"Camera shot is blocked")
	if index == 0:
		if burst_id != seq or bursts.has(id) or actor.action_budget > 0: return false
		var plan: Dictionary = game.Outlaw.reserve_detonation_burst(game,actor)
		if plan.is_empty(): return reject(game,id,peer,burst_id,"Requires a stack and an available global cooldown")
		bursts[id] = {"id":burst_id,"total":plan.shots,"next":0,"fired":0,"start":clock,"last_fire":clock-game.Outlaw.DETONATION_SHOT_INTERVAL,"stamp":stamp,"revision":revision,"epoch":game.epoch,"peer":peer,"pending":[]}
		actor.action_budget = .05
	if not bursts.has(id): return false
	var burst: Dictionary = bursts[id]
	if burst.id != burst_id or burst.peer != peer or index != burst.next or index >= burst.total: return false
	# Arrival jitter may queue a shot, but cannot accelerate its damage deadline
	# or reuse the first shot's old aim timestamp for the rest of the burst.
	if index > 0 and stamp < float(burst.stamp)+index*game.Outlaw.DETONATION_SHOT_INTERVAL-.025: return false
	actor.last_action_seq = seq
	burst.next += 1
	burst.pending.append({"index":index,"seq":seq,"origin":origin,"direction":direction.normalized(),"stamp":minf(stamp,clock)})
	return true

func cancel(game, id: int, peer: int, burst_id: int) -> void:
	if not game.authoritative() or not bursts.has(id): return
	var burst: Dictionary = bursts[id]
	if burst.id != burst_id or (peer > 0 and burst.peer != peer): return
	bursts.erase(id)
	emit(game,{"source":id,"burst":burst_id,"done":true,"fired":false,"committed":true,"reason":"Burst cancelled"},peer)

func tick(game) -> void:
	if not game.authoritative(): return
	var clock: float = game.aimed_combat.clock
	for id in bursts.keys():
		var burst: Dictionary = bursts[id]
		var actor = game.actors.get(id)
		if actor == null or burst.epoch != game.epoch:
			bursts.erase(id); continue
		if blocked(game,actor) or burst.revision != actor.motion_revision or clock-burst.start > TIMEOUT:
			cancel(game,id,burst.peer,burst.id); continue
		if burst.pending.is_empty(): continue
		var request: Dictionary = burst.pending[0]
		if clock+.000001 < float(burst.start)+request.index*game.Outlaw.DETONATION_SHOT_INTERVAL: continue
		if clock+.000001 < float(burst.last_fire)+game.Outlaw.DETONATION_SHOT_INTERVAL: continue
		burst.pending.pop_front()
		if clock-request.stamp > game.aimed_combat.allowed_age(game,burst.peer)+.03:
			cancel(game,id,burst.peer,burst.id); continue
		var result: Dictionary = game.aimed_combat.trace(game,actor,request.origin,request.direction,RANGE,request.stamp)
		result.merge({"source":id,"burst":burst.id,"index":request.index,"total":burst.total,"seq":request.seq,"from":request.origin,"damage":0,"fired":true,"done":request.index+1==burst.total,"time":clock})
		if result.victim >= 0:
			var victim = game.actors[result.victim]
			if victim.team != actor.team and game.may_harm(actor,victim):
				var before: float = victim.hp
				game.damage(actor,victim,roundi(victim.MAX_HEALTH*game.Outlaw.DETONATION_HEALTH_FRACTION))
				result.damage = roundi(before-victim.hp)
		game.Outlaw.action(actor,"gun")
		burst.last_fire = clock
		burst.fired += 1
		if result.done: bursts.erase(id)
		emit(game,result)

func visual_endpoint(game, shooter, origin: Vector3, direction: Vector3) -> Vector3:
	var end := origin+direction*RANGE
	var query := PhysicsRayQueryParameters3D.create(origin,end,1)
	query.hit_from_inside = true
	var wall: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty(): end = wall.position
	for actor in game.actors.values():
		if actor == shooter or actor.hp <= 0 or actor.body_hitboxes == null: continue
		var hit: Dictionary = game.aimed_combat.Bodies.trace(origin,direction,origin.distance_to(end),actor.body_hitboxes.points,actor.body_hitboxes.radii)
		if not hit.is_empty(): end = hit.position
	return end
