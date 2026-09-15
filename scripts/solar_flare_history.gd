extends RefCounted
## Cheap root positions only: never enables skeletal/aimed hitbox tracking.
const MAX_AGE := .25
var clock := 0.0
var epoch := -1
var history: Dictionary = {}

func tick(game, delta: float) -> void:
	clock += maxf(0, delta)
	if epoch != game.epoch:
		history.clear()
		epoch = game.epoch
	var needed := false
	for actor in game.actors.values():
		if actor.champion == "Ember" and actor.hp > 0: needed = true; break
	if not needed:
		history.clear()
		return
	for id in history.keys():
		if not game.actors.has(id): history.erase(id)
	for actor in game.actors.values():
		var samples: Array = history.get(actor.actor_id, [])
		if not samples.is_empty() and (samples[-1].instance != actor.get_instance_id() or samples[-1].revision != actor.motion_revision or samples[-1].alive != (actor.hp > 0)):
			samples.clear()
		samples.append({"time": clock, "pos": actor.position, "instance": actor.get_instance_id(), "revision": actor.motion_revision, "alive": actor.hp > 0})
		while samples.size() > 2 and samples[1].time < clock - MAX_AGE:
			samples.pop_front()
		history[actor.actor_id] = samples

func position_at(actor, age: float) -> Variant:
	if age <= 0 or age > MAX_AGE or not history.has(actor.actor_id): return null
	var samples: Array = history[actor.actor_id]
	if samples.is_empty(): return null
	var last: Dictionary = samples[-1]
	if last.instance != actor.get_instance_id() or last.revision != actor.motion_revision or last.alive != (actor.hp > 0): return null
	var stamp := clock - age
	if stamp < samples[0].time - .000001: return null
	stamp = maxf(stamp, samples[0].time)
	for i in range(1, samples.size()):
		if samples[i].time >= stamp:
			var weight: float = inverse_lerp(samples[i-1].time, samples[i].time, stamp)
			return samples[i-1].pos.lerp(samples[i].pos, weight)
	return null

func rewind_age(game, caster) -> float:
	if not game.network or caster.owner_peer <= 1: return 0.0
	var transport = game.multiplayer.multiplayer_peer
	if not transport is ENetMultiplayerPeer: return 0.0
	var peer = transport.get_peer(caster.owner_peer)
	if peer == null: return 0.0
	# Enemy snapshot outbound + action inbound, plus one snapshot interval.
	var rtt: float = peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) * .001
	return clampf(rtt + game.latency_ms * .002 + .05, 0, MAX_AGE)

func overlaps(game, caster, target) -> bool:
	if game.ClassMechanics.flare_overlaps(caster, target): return true
	var old_position = position_at(target, rewind_age(game, caster))
	if old_position == null: return false
	# Current and historical cover must both be clear. Smoke/CC use live state.
	return game.ClassMechanics.flare_overlaps_position(caster, old_position) and game.ClassMechanics.point_los(game, caster.position, old_position)
