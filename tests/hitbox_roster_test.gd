extends SceneTree
const Aimed = preload("res://scripts/aimed_combat.gd")
const Kits = preload("res://scripts/kits.gd")
var checks := 0
var failures := 0

class Points extends RefCounted:
	var points := PackedVector3Array([Vector3.ZERO])
class Actor extends RefCounted:
	var actor_id := 0
	var owner_peer := 0
	var champion := ""
	var stunned := 0.0
	var casting := -1
	var identity := {"roll_left":0.0,"backflip_active":false}
	var kit: Array = []
	var hp := 1500
	var team := 0
	var motion_revision := 0
	var position := Vector3.ZERO
	var aim_stamp := 0.0
	var updates := 0
	var body_hitboxes := Points.new()
	func update_hitboxes(_delta: float) -> void:
		updates += 1
		body_hitboxes.points[0] = position
class Game extends RefCounted:
	const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
	var dedicated := true
	var network := false
	var phase := "match"
	var aimed_combat
	var outlaw_detonation = preload("res://scripts/outlaw_detonation.gd").new()
	var world_mode := false
	var server := true
	var actors: Dictionary = {}
	func authoritative() -> bool: return server

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func actor(game, id: int, champion: String, team: int = 0):
	var result := Actor.new()
	result.actor_id = id; result.team = team; result.kit = Kits.get_kit(champion); result.champion = champion
	game.actors[id] = result
	return result

func _initialize() -> void:
	var game := Game.new()
	var aimed := Aimed.new()
	game.aimed_combat = aimed
	check(not aimed.tracking_required(game),"Empty team match needs no shot tracking")
	for champion in Kits.NAMES:
		game.actors.clear(); aimed.reset()
		var fighter = actor(game,1,champion)
		if champion == "Outlaw": aimed.tracking.set_mode(game,1,0,1,true)
		for i in 30: aimed.tick(game,1.0/60)
		var required: bool = champion == "Outlaw"
		check(aimed.tracking_required(game) == required,champion+": detect actual aiming capability")
		check(fighter.updates == (30 if required else 0),champion+": skip pose/geometry only when unused")
		check(aimed.history.has(1) == required,champion+": record history only when needed")
		check(is_equal_approx(fighter.aim_stamp,.5),champion+": simulation timestamp keeps advancing")
	# Check all class pairings, in both team/iteration orders.
	for left in Kits.NAMES:
		for right in Kits.NAMES:
			game.actors.clear(); aimed.reset()
			var a = actor(game,1,left,0); var b = actor(game,2,right,1)
			if left == "Outlaw": aimed.tracking.set_mode(game,1,0,1,true)
			if right == "Outlaw": aimed.tracking.set_mode(game,2,0,1,true)
			a.position = Vector3(3,0,-5); b.position = Vector3(-2,0,4)
			aimed.tick(game,1.0/60)
			var required: bool = left == "Outlaw" or right == "Outlaw"
			check(a.updates == int(required) and b.updates == int(required),left+"/"+right+": either team activates tracking for every body")
			check(a.position == Vector3(3,0,-5) and b.position == Vector3(-2,0,4),left+"/"+right+": tracking policy never changes position")
	game.actors.clear(); aimed.reset()
	var shooter = actor(game,1,"Outlaw")
	var target = actor(game,2,"Null",1)
	check(not aimed.tracking_required(game),"An idle Outlaw no longer forces continuous server tracking")
	aimed.tracking.set_mode(game,1,0,1,true)
	for i in 40: aimed.tick(game,1.0/60)
	check(shooter.updates == 40 and target.updates == 40,"Active aim keeps every body warm")
	check(aimed.history[2].size() <= Aimed.MAX_SAMPLES,"Active tracking keeps the existing bounded history")
	check(not aimed.sample(target,aimed.clock-.2).is_empty(),"History remains available before trigger pull")
	shooter.hp = 0; aimed.tracking.tick(game,1.0/60)
	check(not aimed.tracking.active(1),"Death cancels server aim ownership")
	game.actors.erase(1)
	aimed.pending.append({"unused_test_request":true}); aimed.local_slot = 0
	aimed.tick(game,1.0/60)
	check(target.updates == 40 and aimed.history.is_empty(),"No remaining aiming class stops tracking and drops stale history")
	check(aimed.pending.is_empty() and aimed.local_slot == -1 and aimed.sample_usec == 0,"Disabled tracking clears queued work and stale profiling time")
	# Future generic aimed abilities must work without a class-name allowlist.
	target.kit[0]["aim_mode"] = "hitscan"
	aimed.tick(game,1.0/60)
	check(target.updates == 41 and aimed.history.has(2),"An opted-in hitscan ability on another class enables tracking")
	target.kit = Kits.get_kit("Null"); aimed.reset()
	game.world_mode = true
	aimed.tick(game,1.0/60)
	check(target.updates == 42 and aimed.history.has(2),"World keeps continuous tracking for late arrivals")
	game.world_mode = false; game.server = false; aimed.reset()
	aimed.tick(game,1.0/60)
	check(target.updates == 42,"Client skips unused shot geometry too")
	actor(game,1,"Outlaw")
	aimed.tick(game,1.0/60)
	check(target.updates == 43 and aimed.history.is_empty(),"Client updates all shot bodies when an aiming class is present, without server history")
	game.aimed_combat = null
	print("Hitbox roster checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
