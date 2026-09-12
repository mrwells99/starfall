extends SceneTree
var checks := 0
var failures := 0
var comparisons := 0

class AuditArena extends "res://tests/ui_test_arena.gd":
	var legacy_targets := false
	func original_targets(actor, level: int) -> Array:
		var enemies: Array = []
		var friends: Array = []
		for other in actors.values():
			if other.hp <= 0: continue
			if other.team == actor.team: friends.append(other)
			elif Null.targetable(self,actor,other): enemies.append(other)
		if enemies.is_empty(): return [null,null]
		enemies.sort_custom(func(a,b): return actor.position.distance_squared_to(a.position) < actor.position.distance_squared_to(b.position))
		friends.sort_custom(func(a,b): return a.hp < b.hp)
		if level == 2: enemies.sort_custom(func(a,b): return a.hp < b.hp)
		return [enemies[0],friends[0]]
	func bot_targets(actor, level: int) -> Array:
		return original_targets(actor,level) if legacy_targets else super.bot_targets(actor,level)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func lookup_reference(game, peer: int) -> int:
	for actor in game.actors.values():
		if actor.owner_peer == peer: return actor.actor_id
	return -1
func movement_result(game, actor, legacy: bool, pose: Transform3D) -> Dictionary:
	actor.transform = pose
	actor.ai_timer = 1; actor.path_timer = 1
	actor.path = PackedVector2Array([Vector2(2,2),Vector2(4,4)])
	actor.casting = -1; actor.stunned = 0
	game.legacy_targets = legacy
	game.bot_think(actor,1.0/60)
	return {"target":actor.target_id,"move":actor.move_input,"transform":actor.transform,"path":actor.path.duplicate(),"ai":actor.ai_timer,"path_timer":actor.path_timer}
func run() -> void:
	var game := AuditArena.new()
	game.dedicated = true; game.hitboxes_enabled = false
	root.add_child(game); game.set_physics_process(false); game.set_process(false)
	game.spawn_actor(1,101,0,"Ember",Vector3.ZERO)
	game.spawn_actor(2,102,1,"Null",Vector3(0,0,-4))
	game.spawn_actor(3,0,1,"Vanguard",Vector3(2,0,-4))
	check(game.peer_actor(101)==1 and game.actor_for_peer(102)==2,"Spawn registers direct peer lookups")
	var actor = game.actors[2]
	var before: Transform3D = actor.transform
	actor.owner_peer = 0
	check(game.peer_actor(102)==-1 and game.peer_actor(0)==2,"Disconnect removes the old peer and preserves first-bot lookup")
	actor.owner_peer = 202
	check(game.peer_actor(202)==2 and game.actor_for_peer(102)==-1,"Reconnect transfers the lookup without retaining the old peer")
	check(actor.transform==before,"Ownership changes do not change position or rotation")
	var packet: Dictionary = actor.snapshot(); packet.peer = 302
	actor.receive(packet)
	check(game.peer_actor(202)==-1 and game.peer_actor(302)==2,"Replicated ownership changes update client lookups too")
	game.actors[1].owner_peer = 302
	check(game.peer_actor(302)==lookup_reference(game,302),"Duplicate owner IDs preserve original first-match ordering")
	game.actors[1].owner_peer = 101
	check(game.peer_actor(302)==2,"Removing the first duplicate restores the remaining owner")
	game.remove_world_actor(2)
	check(game.peer_actor(302)==-1 and not game.actors_by_peer.has(302),"World departure clears the lookup")
	game.clear_actors()
	check(game.actors_by_peer.is_empty() and game.peer_actor(101)==-1,"Round teardown clears all peer mappings")
	game.spawn_actor(1,401,0,"Null",Vector3.ZERO)
	check(game.peer_actor(401)==1 and game.peer_actor(101)==-1,"Reused actor IDs never retain ownership from an old round")
	var rng := RandomNumberGenerator.new(); rng.seed = 935207
	for count in [2,6,13,24]:
		game.clear_actors()
		for i in count: game.spawn_actor(i+1,100+i,0 if i<count/2 else 1,game.Kits.NAMES[i%game.Kits.NAMES.size()],Vector3.ZERO)
		var bot = game.actors[1]
		var same := [true,true,true]
		for sample in 240:
			for other in game.actors.values():
				# Small integer coordinates/health deliberately produce many ties.
				other.position = Vector3(rng.randi_range(-3,3),0,rng.randi_range(-3,3))
				other.hp = [0,750,1500][rng.randi_range(0,2)]
				other.identity.stealth = rng.randi_range(0,3)==0
				other.identity.stealth_detection = {bot.actor_id:.7} if rng.randi_range(0,1)==0 else {}
			bot.hp = bot.MAX_HEALTH
			for level in 3:
				var expected: Array = game.original_targets(bot,level)
				var actual: Array = game.bot_targets(bot,level)
				same[level] = same[level] and expected[0]==actual[0] and (expected[0]==null or expected[1]==actual[1])
				comparisons += 1
		for level in 3: check(same[level],"%d actors, difficulty %d: old/new choices match across ties, deaths and stealth" % [count,level])
		# Compare the resulting movement instructions using the unchanged bot loop.
		for other in game.actors.values():
			other.hp = 750 if other.actor_id==2 else 1500
			other.identity.stealth = false
			other.position = Vector3(other.actor_id*1.3,0,-other.actor_id*.6)
		for title in game.Kits.NAMES:
			bot.champion = title; bot.kit = game.Kits.get_kit(title)
			var pose: Transform3D = bot.transform
			var expected := movement_result(game,bot,true,pose)
			var actual := movement_result(game,bot,false,pose)
			check(expected==actual and bot.position==pose.origin,title+": identical target, movement intent, facing, path and reaction timers")
			game.legacy_targets = false
	# Compare repeated hot lookups and the usual six-actor selection workload.
	game.clear_actors()
	for i in 6: game.spawn_actor(i+1,100+i,0 if i<3 else 1,"Ember",Vector3(i*1.3,0,-i*.6))
	var bot = game.actors[1]
	for other in game.actors.values(): other.hp = other.MAX_HEALTH
	var durations := [0,0,0,0]
	for batch in 12:
		for version in ([0,1,2,3] if batch%2==0 else [3,2,1,0]):
			var start := Time.get_ticks_usec()
			for repeat in 1000:
				match version:
					0: lookup_reference(game,105)
					1: game.peer_actor(105)
					2: game.original_targets(bot,1)
					3: game.bot_targets(bot,1)
			if batch>=2: durations[version] += Time.get_ticks_usec()-start
	print("Lookup/bot comparisons=",comparisons," benchmark total_us old_lookup/new_lookup/old_targets/new_targets=",durations)
	game.queue_free(); await process_frame
	print("Lookup bot optimization checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
