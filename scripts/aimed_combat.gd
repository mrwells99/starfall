extends RefCounted
## Opt-in, button/cooldown hitscan foundation. No shipped kit opts in yet.
const Bodies = preload("res://scripts/body_hitboxes.gd")
const MAX_REWIND := .25
const INTERPOLATION_ALLOWANCE := .05
const CLOCK_TOLERANCE := .05
const MAX_SAMPLES := 20
const MAX_PENDING := 32
var clock := 0.0
var history := {}
var pending: Array[Dictionary] = []
var local_slot := -1
var observed_stamp := -1.0
var observed_at := 0
var sample_usec := 0
var reticle: Control

static func enabled(spell: Dictionary) -> bool:
	return spell.get("aim_mode","") == "hitscan"

func reset() -> void:
	clock = 0; history.clear(); pending.clear(); local_slot = -1; observed_stamp = -1
	if is_instance_valid(reticle): reticle.hide()

func observe(stamp: float) -> void:
	if is_finite(stamp) and stamp >= observed_stamp:
		observed_stamp = stamp; observed_at = Time.get_ticks_msec()

func tick(game, delta: float) -> void:
	sync_reticle(game)
	clock += delta
	var started := Time.get_ticks_usec()
	for id in history.keys():
		if not game.actors.has(id): history.erase(id)
	for actor in game.actors.values():
		actor.update_hitboxes(delta)
		if not game.authoritative(): continue
		actor.aim_stamp = clock
		var samples: Array = history.get(actor.actor_id,[])
		# Never interpolate/rewind through teleports, deaths, or a new life.
		if not samples.is_empty() and (samples.back().revision != actor.motion_revision or samples.back().alive != (actor.hp > 0)):
			samples.clear()
		samples.append({"time":clock,"revision":actor.motion_revision,"alive":actor.hp > 0,"root":actor.position,"points":actor.body_hitboxes.points.duplicate()})
		while samples.size() > MAX_SAMPLES or (samples.size() > 1 and clock-samples[0].time > MAX_REWIND+.05): samples.pop_front()
		history[actor.actor_id] = samples
	sample_usec = Time.get_ticks_usec()-started
	if local_slot >= 0:
		var slot := local_slot; local_slot = -1
		fire_from_camera(game,slot)
	if game.authoritative():
		var requests := pending; pending = []
		for request in requests:
			if request.epoch == game.epoch: resolve(game,request)

func sync_reticle(game) -> void:
	if game.dedicated: return
	var show := false
	if game.phase == "match" and game.actors.has(game.local_id) and not game.panel.visible and not game.edit_mode:
		var actor = game.actors[game.local_id]
		if actor.hp > 0:
			for spell in actor.kit:
				if enabled(spell): show = true; break
	if show and not is_instance_valid(reticle):
		reticle = preload("res://scripts/aim_reticle.gd").new(); game.ui.add_child(reticle)
	if is_instance_valid(reticle): reticle.visible = show

func sample(actor, stamp: float) -> Dictionary:
	var frames: Array = history.get(actor.actor_id,[])
	if frames.is_empty() or stamp < float(frames[0].time)-.0001: return {}
	for i in range(1,frames.size()):
		if frames[i].time >= stamp:
			var previous: Dictionary = frames[i-1]; var next: Dictionary = frames[i]
			var alpha := clampf((stamp-float(previous.time))/maxf(.000001,float(next.time)-float(previous.time)),0,1)
			var points: PackedVector3Array = previous.points.duplicate()
			for j in points.size(): points[j] = points[j].lerp(next.points[j],alpha)
			return {"points":points,"root":Vector3(previous.root).lerp(next.root,alpha)}
	return frames.back()

static func firing_origin(points: PackedVector3Array) -> Vector3:
	# Main chest volume, independent of cosmetic gun/staff size. Follows rolls/flips.
	return (points[4]+points[5])*.5

func allowed_age(game, peer: int) -> float:
	if peer <= 0 or not game.network: return MAX_REWIND
	var transport = game.multiplayer.multiplayer_peer
	var rtt := 0.0
	if transport is ENetMultiplayerPeer:
		var packet_peer: ENetPacketPeer = transport.get_peer(peer)
		if packet_peer != null: rtt = packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)*.001
	# Client aim is based on a received server snapshot, without adding transit
	# time back into its stamp. Its age on arrival includes snapshot outbound AND
	# shot inbound travel: one full measured RTT, plus interpolation and jitter.
	# latency_ms adds simulated delay each way; retain the 250ms rewind ceiling.
	return minf(MAX_REWIND,rtt+float(game.latency_ms)*.002+INTERPOLATION_ALLOWANCE+CLOCK_TOLERANCE)

func enqueue(game, id: int, peer: int, seq: int, slot: int, direction: Vector3, stamp: float, revision: int) -> bool:
	if not game.authoritative() or game.phase != "match" or not game.actors.has(id): return false
	var actor = game.actors[id]
	if slot < 0 or slot >= actor.kit.size() or not enabled(actor.kit[slot]): return false
	if peer > 0 and actor.owner_peer != peer: return false
	if not direction.is_finite() or absf(direction.length_squared()-1.0) > .01 or not is_finite(stamp): return false
	if stamp < 0 or clock-stamp > allowed_age(game,peer) or stamp-clock > CLOCK_TOLERANCE: return false
	if revision != actor.motion_revision or seq <= actor.last_action_seq or seq > 2147483647: return false
	if actor.action_budget > 0 or pending.size() >= MAX_PENDING: return false
	for request in pending:
		if request.id == id: return false
	actor.last_action_seq = seq; actor.action_budget = .05
	pending.append({"id":id,"peer":peer,"seq":seq,"slot":slot,"direction":direction.normalized(),"stamp":minf(clock,stamp),"revision":revision,"epoch":game.epoch})
	return true

func trace(game, shooter, origin: Vector3, direction: Vector3, distance: float, stamp: float) -> Dictionary:
	var end := origin+direction*distance
	var query := PhysicsRayQueryParameters3D.create(origin,end,1)
	query.hit_from_inside = true
	var wall: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	var closest := origin.distance_to(wall.position) if not wall.is_empty() else distance
	var result := {"victim":-1,"part":"","position":origin+direction*closest,"blocked":not wall.is_empty()}
	for actor in game.actors.values():
		if actor == shooter or actor.hp <= 0: continue
		var state := sample(actor,stamp)
		if state.is_empty(): continue
		var hit := Bodies.trace(origin,direction,closest,state.points,actor.body_hitboxes.radii)
		if hit.is_empty(): continue
		closest = hit.distance
		# Allies and protected world bystanders stop a shot without receiving damage.
		result = {"victim":actor.actor_id,"part":hit.part,"position":hit.position,"blocked":false}
	return result

func resolve(game, request: Dictionary) -> Dictionary:
	if not game.actors.has(request.id) or not game.authoritative(): return {}
	var actor = game.actors[request.id]
	if request.epoch != game.epoch or request.revision != actor.motion_revision: return {}
	if request.peer > 0 and actor.owner_peer != request.peer: return {}
	var slot: int = request.slot
	if slot < 0 or slot >= actor.kit.size(): return {}
	var spell: Dictionary = actor.kit[slot]
	# Initial extension contract is an instant cooldown ability. Cast-time aiming
	# needs a separately defined release/retarget policy before it can be enabled.
	if not enabled(spell) or spell.cast != 0 or spell.cd <= 0 or spell.range <= 0 or spell.range > game.Kits.MAX_CAST_RANGE: return {}
	var reason: String = game.ability_block_reason(actor,slot,-1)
	if not reason.is_empty(): game.feedback(actor,reason); return {}
	var stamp: float = request.stamp
	if clock-stamp > allowed_age(game,request.peer)+.02: return {}
	var shooter_state := sample(actor,stamp)
	if shooter_state.is_empty(): return {}
	# Clients never supply origins, victims, damage, or cooldowns.
	var origin: Vector3 = firing_origin(shooter_state.points)
	var direction: Vector3 = request.direction
	var result := trace(game,actor,origin,direction,spell.range,stamp)
	actor.cooldowns[slot] = spell.cd
	if not spell.off: actor.gcd = game.GCD_DURATION
	result.merge({"source":actor.actor_id,"seq":request.seq,"from":origin,"damage":0,"rewind_ms":roundi((clock-stamp)*1000)})
	if game.actors.has(result.victim):
		var victim = game.actors[result.victim]
		if victim.team != actor.team and game.may_harm(actor,victim):
			var before: float = victim.hp
			game.damage(actor,victim,roundi(spell.power))
			result.damage = roundi(before-victim.hp)
	game.report_aimed_shot(game.epoch,result)
	if game.network: game.report_aimed_shot.rpc(game.epoch,result)
	return result

func fire_from_camera(game, slot: int) -> void:
	if not game.actors.has(game.local_id) or game.phase != "match" or game.edit_mode: return
	var actor = game.actors[game.local_id]
	if slot < 0 or slot >= actor.kit.size() or not enabled(actor.kit[slot]): return
	var spell: Dictionary = actor.kit[slot]
	var center: Vector2 = game.get_viewport().get_visible_rect().size*.5
	var camera_origin: Vector3 = game.camera.project_ray_origin(center)
	var camera_direction: Vector3 = game.camera.project_ray_normal(center).normalized()
	var far_point: Vector3 = camera_origin+camera_direction*(float(spell.range)+game.camera.global_position.distance_to(actor.position))
	var wall: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera_origin,far_point,1))
	if not wall.is_empty(): far_point = wall.position
	var distance := camera_origin.distance_to(far_point)
	for other in game.actors.values():
		if other == actor or other.hp <= 0 or other.body_hitboxes == null: continue
		var hit := Bodies.trace(camera_origin,camera_direction,distance,other.body_hitboxes.points,other.body_hitboxes.radii)
		if not hit.is_empty(): far_point = hit.position; distance = hit.distance
	var origin: Vector3 = firing_origin(actor.body_hitboxes.points)
	var direction: Vector3 = (far_point-origin).normalized()
	game.action_seq += 1
	if game.authoritative():
		enqueue(game,actor.actor_id,0,game.action_seq,slot,direction,clock,actor.motion_revision)
	elif observed_stamp >= 0:
		# Target the displayed, interpolated scene. The host bounds every timestamp
		# using its own measured transport delay; a client cannot request arbitrary history.
		var stamp := observed_stamp+(Time.get_ticks_msec()-observed_at)*.001-INTERPOLATION_ALLOWANCE
		game.deliver_aimed_action(game.epoch,game.action_seq,slot,direction,maxf(0,stamp),actor.motion_revision)
