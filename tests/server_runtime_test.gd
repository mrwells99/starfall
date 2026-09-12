extends SceneTree

var failures := 0
var checks := 0
class CountingFighter extends "res://scripts/combatant.gd":
	var resets := 0
	func reset_identity() -> void:
		resets += 1
		super.reset_identity()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var initial_cap := Engine.max_fps
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	check(arena.dedicated and arena.network, "Start with --dedicated and a free UDP port")
	check(Engine.max_fps == Engine.physics_ticks_per_second, "Server frame loop is bounded at physics frequency")
	check(Engine.physics_ticks_per_second == 60, "Combat remains at 60 Hz")
	arena.mode = 3
	arena.roster = {1:{"champion":"Null","team":0},2:{"champion":"Ember","team":1}}
	arena.begin_round()
	check(arena.actors[1].champion == "Null", "Null exercises the actual dedicated rig path")
	for actor in arena.actors.values():
		check(actor.champion_model == null, "Server actor has no presentation model")
		check(actor.get_child(0) is CollisionShape3D and actor.hitbox_pose != null and actor.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(), "Movement capsule and lightweight hitbox rig retained without visual children")
	for champion in ["ember", "vanguard", "luminary", "fulcrum", "outlaw", "null"]:
		check(not ResourceLoader.has_cached("res://assets/characters/%s.glb" % champion), "Server does not load authored model: " + champion)
	var before := get_node_count()
	arena.combat_event(-1, arena.actors.keys()[0], "TEST", Color.WHITE)
	arena.update_visuals(0.016)
	check(get_node_count() == before, "Server event and HUD refresh allocate no visual nodes")
	for i in range(120):
		await physics_frame
	for actor in arena.actors.values():
		check(actor.position.y > -1, "Simulated actor remains on arena collision")
	arena.set_physics_process(false)
	# A team round without aiming abilities must still simulate ordinary combat
	# and movement while doing no repeated shot-pose/history work.
	arena.mode = 1
	arena.roster = {1:{"champion":"Null","team":0},2:{"champion":"Ember","team":1}}
	arena.begin_round(); arena.phase = "match"
	var runner = arena.actors[1]; var healer = arena.actors[2]
	runner.position = Vector3(0,.025,0); healer.position = Vector3(0,.025,-1.5)
	for i in 5: arena._physics_process(1.0/60)
	check(not arena.aimed_combat.tracking_required(arena) and arena.aimed_combat.history.is_empty(), "No aiming class means no server shot history")
	healer.hp = healer.MAX_HEALTH - 500
	check(arena.try_spell(2,5,2), "Mend still starts without shot tracking")
	for i in 130: arena._physics_process(1.0/60)
	check(healer.casting == -1 and is_equal_approx(healer.hp,healer.MAX_HEALTH-500+336), "Mend still completes and heals 336 without shot tracking")
	var health_before: float = healer.hp
	check(arena.try_spell(1,0,2) and healer.hp < health_before, "Temporal Strike still damages without aimed hitboxes")
	var position_before: Vector3 = runner.position
	var points_before: PackedVector3Array = runner.body_hitboxes.points.duplicate()
	for i in 30:
		runner.move_input = Vector2.RIGHT; runner.input_age = 0
		arena._physics_process(1.0/60)
	check(runner.position.distance_to(position_before) > .5 and runner.position.y > -1, "Movement and arena collision continue with shot tracking off")
	check(runner.body_hitboxes.points == points_before and arena.aimed_combat.history.is_empty() and arena.aimed_combat.sample_usec == 0, "Moving actor does not update unused shot geometry or history")
	for champion in arena.Kits.NAMES:
		var actor := CountingFighter.new()
		arena.add_child(actor); actor.setup(99,99,0,champion,false)
		var initial_resets := actor.resets
		actor.identity.heat = 90
		actor.identity.root = 2
		actor.hp = 0
		for i in 60: arena.tick_actor(actor,1.0/60)
		check(actor.resets == initial_resets+1 and actor.identity.heat == 0 and actor.identity.root == 0, champion+": one cleanup across sixty dead ticks")
		actor.hp = actor.MAX_HEALTH
		arena.ClassMechanics.tick(arena,actor,1.0/60)
		actor.hp = 0
		arena.tick_actor(actor,1.0/60)
		check(actor.resets == initial_resets+2, champion+": a later death gets its own cleanup")
		actor.hp = actor.MAX_HEALTH; actor.reset_identity()
		actor.hp = 0; arena.tick_actor(actor,1.0/60)
		check(actor.resets == initial_resets+4, champion+": death immediately after respawn also cleans up")
		actor.reset_identity()
		arena.tick_actor(actor,1.0/60)
		check(actor.resets == initial_resets+5, champion+": explicit duel death cleanup is not repeated")
		actor.free()
	arena.world_mode = true
	arena.roster = {}
	arena.begin_round()
	var dummy = arena.actors[-100]
	dummy.cooldowns[0] = 7.0
	var stamp: float = arena.aimed_combat.clock
	var sequence: int = arena.snapshot_seq
	var elapsed: float = arena.elapsed
	for i in 60: arena._physics_process(1.0/60)
	check(dummy.cooldowns[0] == 7.0 and arena.elapsed == elapsed, "Empty World skips dummy and world simulation")
	check(arena.aimed_combat.clock == stamp and arena.snapshot_seq == sequence, "Empty World skips hitbox history and snapshot production")
	check(arena.network and arena.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "Dormant World keeps its network listener connected")
	arena.roster = {1:{"champion":"Null","team":0}}
	arena.admit_to_world()
	arena._physics_process(1.0/60)
	check(arena.actors.size() == 4 and dummy.cooldowns[0] < 7.0 and arena.aimed_combat.clock > stamp, "Arrival immediately resumes dummy and hitbox updates")
	check(arena.snapshot_seq > sequence, "Arrival immediately resumes snapshots")
	var newcomer = arena.actors[arena.actor_for_peer(1)]
	newcomer.hp = 0
	arena.respawn_timers[newcomer.actor_id] = .05
	for i in 6: arena._physics_process(1.0/60)
	check(newcomer.hp == newcomer.MAX_HEALTH, "An occupied World still respawns its last player")
	arena.roster.clear()
	arena.remove_world_actor(newcomer.actor_id)
	stamp = arena.aimed_combat.clock; sequence = arena.snapshot_seq
	for i in 60: arena._physics_process(1.0/60)
	check(arena.aimed_combat.clock == stamp and arena.snapshot_seq == sequence, "World becomes dormant again after the last departure")
	arena.leave_session("")
	check(Engine.max_fps == initial_cap, "Leaving dedicated mode restores previous frame cap")
	print("Server runtime checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
