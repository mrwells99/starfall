extends "res://tests/network_fixture_arena.gd"
## Isolated experiment. No production scene loads this script.
signal probe_result(result: Dictionary)
var probe_aimers: Dictionary = {}
var probe_trial := 0
var probe_prepared := 0
var probe_diagnostics: Dictionary = {}
var probe_gated := false
var probe_production := false
var probe_skipped := 0
var probe_recorded := 0
var probe_client_ray_hit := false
var probe_sent_at := 0
var probe_motion := "slow"
var probe_next_jump := 0.0
var probe_finished := false

func deliver_detonation(round_epoch: int, seq: int, burst_id: int, index: int, origin: Vector3, direction: Vector3, stamp: float, revision: int) -> void:
	probe_sent_at = Time.get_ticks_msec()
	probe_client_ray_hit = false
	for actor in actors.values():
		if actor.actor_id == local_id or actor.body_hitboxes == null: continue
		var hit: Dictionary = aimed_combat.Bodies.trace_aim(origin,direction,outlaw_detonation.RANGE,actor.body_hitboxes.points,actor.body_hitboxes.radii,actor.position)
		if not hit.is_empty(): probe_client_ray_hit = true
	super.deliver_detonation(round_epoch,seq,burst_id,index,origin,direction,stamp,revision)

class GatedHistory extends "res://scripts/aimed_combat.gd":
	func tracking_required(game) -> bool:
		return super.tracking_required(game) if game.probe_production else true
	func tick(game, delta: float) -> void:
		if game.authoritative() and not game.probe_production and game.probe_gated and game.probe_aimers.is_empty():
			# Keep the network clock advancing; stop only pose/shape/history work.
			clock += delta
			for actor in game.actors.values(): actor.aim_stamp = clock
			history.clear()
			sample_usec = 0
			game.probe_skipped += 1
			return
		super.tick(game,delta)
		if game.authoritative():
			if sample_usec > 0: game.probe_recorded += 1
			else: game.probe_skipped += 1

class ObservedDetonation extends "res://scripts/outlaw_detonation.gd":
	func enqueue(game, id: int, peer: int, seq: int, burst_id: int, index: int, origin: Vector3, direction: Vector3, stamp: float, revision: int) -> bool:
		var frames: Array = game.aimed_combat.history.get(id,[])
		game.probe_diagnostics = {
			"trial":game.probe_trial, "aim_on":game.probe_aimers.has(id),
			"samples":frames.size(), "shot_age_ms":(game.aimed_combat.clock-stamp)*1000,
			"missing_history":game.aimed_combat.sample(game.actors[id],stamp).is_empty(),
			"history_gap_ms":(float(frames[0].time)-stamp)*1000 if not frames.is_empty() else -1.0,
			"server_aim_age_ms":(game.aimed_combat.clock-float(game.probe_aimers.get(id,game.aimed_combat.clock)))*1000,
			"measured_rtt_ms":game.multiplayer.multiplayer_peer.get_peer(peer).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		}
		game.probe_diagnostics["constant_tracking"] = game.aimed_combat.tracking.high_ping()
		game.probe_diagnostics["server_charge_ms"] = (game.aimed_combat.clock-float(game.aimed_combat.tracking.modes.get(id,{}).get("charge_since",-1)))*1000
		for actor in game.actors.values():
			if actor.actor_id != id:
				game.probe_diagnostics["target_speed_mps"] = Vector2(actor.velocity.x,actor.velocity.z).length()
				game.probe_diagnostics["target_x"] = actor.position.x
				game.probe_diagnostics["target_y"] = actor.position.y
		return super.enqueue(game,id,peer,seq,burst_id,index,origin,direction,stamp,revision)
	func emit(game, result: Dictionary, only_peer: int = -1) -> void:
		super.emit(game,result,only_peer)
		var report: Dictionary = game.probe_diagnostics.duplicate()
		report.merge({"fired":result.get("fired",false),"damage":result.get("damage",0),"reason":result.get("reason","")})
		game.probe_receive_result.rpc(report)

func _ready() -> void:
	super._ready()
	probe_gated = "--probe-gated" in OS.get_cmdline_user_args()
	probe_production = "--probe-production" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-motion="): probe_motion = arg.get_slice("=",1)
	aimed_combat = GatedHistory.new()
	outlaw_detonation = ObservedDetonation.new()

func bot_think(actor, _delta: float) -> void:
	actor.move_input = Vector2(sin(elapsed*2)*(.3 if probe_motion == "slow" else 1.0),0)
	actor.walking = probe_motion == "slow"
	if probe_motion == "jump":
		# Separate vertical evasive motion from the running-strafe cases.
		actor.move_input = Vector2.ZERO
		if actor.is_on_floor() and elapsed >= probe_next_jump:
			actor.jump_queued = true
			probe_next_jump = elapsed+1.1

@rpc("any_peer", "call_remote", "reliable", 1)
func probe_set_aim(round_epoch: int, on: bool) -> void:
	if not authoritative() or round_epoch != epoch: return
	var id: int = peer_actor(multiplayer.get_remote_sender_id())
	if not actors.has(id): return
	if on: probe_aimers[id] = aimed_combat.clock
	else: probe_aimers.erase(id)

@rpc("any_peer", "call_remote", "reliable", 1)
func probe_prepare(trial: int) -> void:
	if not authoritative(): return
	var peer: int = multiplayer.get_remote_sender_id()
	var id: int = peer_actor(peer)
	if not actors.has(id): return
	probe_trial = trial
	probe_aimers.clear()
	outlaw_detonation.reset()
	var shooter = actors[id]
	shooter.identity.defense_detonation = 1
	shooter.gcd = 0; shooter.action_budget = 0
	for actor in actors.values(): actor.hp = actor.MAX_HEALTH
	probe_prepare_ack.rpc_id(peer,trial)

@rpc("authority", "call_remote", "reliable", 1)
func probe_prepare_ack(trial: int) -> void:
	probe_prepared = trial

@rpc("authority", "call_remote", "reliable")
func probe_receive_result(result: Dictionary) -> void:
	probe_result.emit(result)

@rpc("any_peer", "call_remote", "reliable", 1)
func probe_finish() -> void:
	if not authoritative(): return
	print("PROBE HOST PASS recorded_ticks=",probe_recorded," skipped_ticks=",probe_skipped)
	probe_finish_ack.rpc_id(multiplayer.get_remote_sender_id())
	get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit())

@rpc("authority", "call_remote", "reliable", 1)
func probe_finish_ack() -> void:
	probe_finished = true
