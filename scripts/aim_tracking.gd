extends RefCounted
## Server-owned aim lifetime and sustained-latency fallback. Never moves actors.
const CHARGE_SECONDS := .6
const PING_SAMPLE_SECONDS := .25
const HIGH_PING_MS := 160.0
const LOW_PING_MS := 140.0
const HIGH_PING_SECONDS := 2.0
const LOW_PING_SECONDS := 5.0
var modes: Dictionary = {}
var peers: Dictionary = {}
var ping_timer := 0.0

func reset() -> void:
	modes.clear(); peers.clear(); ping_timer = 0.0

func mode_allowed(game, actor) -> bool:
	return actor.champion == "Outlaw" and actor.hp > 0 and actor.stunned <= 0 and actor.casting < 0 and actor.identity.roll_left <= 0 and not actor.identity.backflip_active and not game.Outlaw.Lasso.busy(actor)

func set_mode(game, id: int, peer: int, serial: int, on: bool) -> bool:
	if not game.authoritative() or game.phase != "match" or not game.actors.has(id) or serial <= 0 or serial > 2147483647: return false
	var actor = game.actors[id]
	if peer > 0 and actor.owner_peer != peer: return false
	var previous: Dictionary = modes.get(id,{})
	if previous.get("peer",-1) == actor.owner_peer and serial <= int(previous.get("serial",0)): return false
	if on and not mode_allowed(game,actor): return false
	modes[id] = {"serial":serial,"on":on,"since":game.aimed_combat.clock,"charge_since":-1.0,"peer":actor.owner_peer,"revision":actor.motion_revision}
	if not on: cancel_burst(game,id)
	return true

func cancel_burst(game, id: int) -> void:
	if game.outlaw_detonation.bursts.has(id):
		game.outlaw_detonation.cancel(game,id,0,int(game.outlaw_detonation.bursts[id].id))

func begin_charge(game, id: int, peer: int, serial: int) -> bool:
	if not game.authoritative() or game.phase != "match" or not game.actors.has(id) or not active(id): return false
	var actor = game.actors[id]
	if peer > 0 and actor.owner_peer != peer: return false
	if modes[id].peer != actor.owner_peer or modes[id].revision != actor.motion_revision or int(modes[id].serial) != serial or not mode_allowed(game,actor): return false
	# Reliable retransmission/duplicate intent must not restart the charge.
	if float(modes[id].charge_since) < 0: modes[id].charge_since = game.aimed_combat.clock
	return true

func consume_charge(id: int) -> void:
	if modes.has(id): modes[id].charge_since = -1.0

func active(id: int) -> bool:
	return bool(modes.get(id,{}).get("on",false))

func ready(game, id: int) -> bool:
	if not active(id): return false
	var actor = game.actors.get(id)
	if actor == null or modes[id].peer != actor.owner_peer or modes[id].revision != actor.motion_revision: return false
	if float(modes[id].charge_since) < 0: return false
	# Client charges the full .6s after trigger pull. A transport/frame allowance prevents
	# ordinary arrival jitter from turning that completed wind-up into a reject.
	return game.aimed_combat.clock-float(modes[id].charge_since) >= CHARGE_SECONDS-.05

func observe_ping(peer: int, milliseconds: float, delta: float = PING_SAMPLE_SECONDS) -> void:
	if not is_finite(milliseconds) or milliseconds < 0 or delta <= 0: return
	var state: Dictionary = peers.get(peer,{"average":milliseconds,"high":0.0,"low":0.0,"constant":false})
	state.average = lerpf(float(state.average),milliseconds,1.0-exp(-delta))
	# Require sustained measurements, not just an average raised by one spike.
	state.high = float(state.high)+delta if milliseconds > HIGH_PING_MS and float(state.average) > HIGH_PING_MS else 0.0
	state.low = float(state.low)+delta if milliseconds < LOW_PING_MS and float(state.average) < LOW_PING_MS else 0.0
	if state.high >= HIGH_PING_SECONDS: state.constant = true
	if state.low >= LOW_PING_SECONDS: state.constant = false
	peers[peer] = state

func high_ping() -> bool:
	for state in peers.values():
		if state.constant: return true
	return false

func tick(game, delta: float) -> void:
	if not game.authoritative(): return
	for id in modes.keys():
		var actor = game.actors.get(id)
		var state: Dictionary = modes[id]
		if actor == null or actor.owner_peer != state.peer:
			cancel_burst(game,id)
			modes.erase(id)
		elif state.on and (game.phase != "match" or actor.motion_revision != state.revision or not mode_allowed(game,actor)):
			cancel_burst(game,id)
			state.on = false
			if not game.dedicated and game.local_id == id:
				game.outlaw_aim_test.receive_mode(state.serial,false,0.0)
			elif game.network and state.peer > 1 and game.multiplayer.get_peers().has(state.peer):
				game.report_aim_mode.rpc_id(state.peer,game.epoch,state.serial,false,0.0)
	if not game.network:
		peers.clear(); return
	ping_timer -= delta
	if ping_timer > 0: return
	ping_timer = PING_SAMPLE_SECONDS
	var present: Dictionary = {}
	var transport = game.multiplayer.multiplayer_peer
	if transport is ENetMultiplayerPeer:
		var connected: PackedInt32Array = game.multiplayer.get_peers()
		for actor in game.actors.values():
			var peer: int = actor.owner_peer
			if peer <= 1 or present.has(peer) or not connected.has(peer): continue
			present[peer] = true
			var packet_peer: ENetPacketPeer = transport.get_peer(peer)
			if packet_peer != null:
				observe_ping(peer,packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	for peer in peers.keys():
		if not present.has(peer): peers.erase(peer)

func required(game) -> bool:
	# Keep World's existing behavior: classes can join at any time there.
	if game.world_mode: return true
	var has_detonation := false
	for actor in game.actors.values():
		for spell in actor.kit:
			# Generic instant aimed abilities have no aim-entry wind-up protocol.
			if spell.get("aim_mode","") == "hitscan": return true
			if spell.kind == "defense_detonation": has_detonation = true
	if not has_detonation: return false
	# Client geometry remains available for camera previews and effects.
	if not game.authoritative() or high_ping(): return true
	if not game.outlaw_detonation.bursts.is_empty(): return true
	for state in modes.values():
		if state.on: return true
	return false
