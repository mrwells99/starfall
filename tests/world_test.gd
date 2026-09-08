extends SceneTree

# World mode: a persistent hangout on the arena map. No rounds, no timer, no
# victory, and no damage between people who have not agreed to fight.
var arena
var checks := 0
var fails := 0
func ck(c: bool, d: String) -> void:
	checks += 1
	if not c: fails += 1; push_error(d)
func _initialize() -> void: call_deferred("go")
func go() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.world_mode = true
	arena.mode = 1
	arena.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Vanguard", "team": 1}}
	arena.begin_round()
	ck(arena.phase == "match", "World starts immediately with no countdown")
	ck(arena.countdown == 0.0, "No countdown in the world")
	ck(arena.actors.size() == 2, "Only real players spawn; no bots fill the world")
	var a = arena.actors[1]
	var b = arena.actors[2]
	# Damage is refused until both agree.
	arena.damage(a, b, 30.0)
	ck(b.hp == 100, "You cannot harm someone who has not agreed to duel")
	arena.offer_duel(1, 2)
	ck(arena.duel_offers.get(2, -1) == 1, "A challenge is recorded against the target")
	arena.confirm_duel(2)
	ck(arena.duels.get(1, -1) == 2 and arena.duels.get(2, -1) == 1, "Accepting pairs both fighters")
	arena.damage(a, b, 30.0)
	ck(b.hp == 70, "Damage lands once a duel is agreed")
	# A third party still cannot join in.
	arena.roster[3] = {"champion": "Luminary", "team": 0}
	arena.admit_to_world()
	ck(arena.actors.size() == 3, "A latecomer is admitted without restarting the world")
	var c = null
	for x in arena.actors.values():
		if x.actor_id == 3: c = x
	arena.damage(c, b, 40.0)
	ck(b.hp == 70, "A bystander cannot interfere in someone else's duel")
	# Losing ends the duel and schedules a return rather than a defeat.
	arena.damage(a, b, 100.0)
	ck(b.hp == 0 and not arena.duels.has(1) and not arena.duels.has(2), "Losing ends the duel")
	ck(arena.respawn_timers.has(2), "The loser is queued to come back")
	arena.check_winner()
	ck(arena.phase == "match", "The world has no victory condition")
	arena.tick_world(4.0)
	ck(b.hp == 100 and not arena.respawn_timers.has(2), "The loser returns at full health")
	print("World checks: %d passed / %d total" % [checks - fails, checks])
	quit(1 if fails else 0)
