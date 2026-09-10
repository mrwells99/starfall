extends SceneTree
const Bodies = preload("res://scripts/body_hitboxes.gd")
var game
var a
var b
var checks := 0
var failures := 0
var seq := 0
var results := []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")

func profile() -> Dictionary:
	var spell: Dictionary = game.Kits.spell("Test aimed cooldown", "aimed_test", 12, 18, 0, 4)
	spell.aim_mode = "hitscan"
	return spell

func reset() -> void:
	game.world_mode = false; game.mode = 1
	game.roster = {1:{"champion":"Outlaw","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round(); game.phase = "match"
	a = game.actors[1]; b = game.actors[2]
	a.owner_peer = 1; b.owner_peer = 2
	a.position = Vector3(0,20,0); b.position = Vector3(0,20,-6)
	a.rotation.y = 0; b.rotation.y = PI
	a.presentation_grounded = true; b.presentation_grounded = true
	a.kit[0] = profile()
	results.clear(); seq = 0
	for i in 18: step()
	await physics_frame

func step() -> void:
	for actor in game.actors.values():
		if actor.champion_model != null: actor.champion_model.animate(1.0/60,actor)
	game.aimed_combat.tick(game,1.0/60)

func direction() -> Vector3:
	var source: Vector3 = game.aimed_combat.firing_origin(a.body_hitboxes.points)
	var target: Vector3 = game.aimed_combat.firing_origin(b.body_hitboxes.points)
	return (target-source).normalized()

func shoot(aim: Vector3, stamp: float = -1) -> bool:
	seq += 1
	var accepted: bool = game.aimed_combat.enqueue(game,1,0,seq,0,aim,game.aimed_combat.clock if stamp < 0 else stamp,a.motion_revision)
	step()
	return accepted

func wall(at: Vector3) -> Node3D:
	var body := StaticBody3D.new(); var collider := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size = Vector3(3,4,.3); collider.shape = shape; body.add_child(collider); game.add_child(body); body.position = at
	return body

func geometry() -> void:
	check(is_equal_approx(Bodies.capsule_distance(Vector3(0,1,-3),Vector3.BACK,Vector3.ZERO,Vector3.UP*2,.3),2.7),"Body capsule cylinder intersects at its padded surface")
	check(is_equal_approx(Bodies.capsule_distance(Vector3(0,4,0),Vector3.DOWN,Vector3.ZERO,Vector3.UP*2,.3),1.7),"Parallel ray intersects capsule endcap")
	check(Bodies.capsule_distance(Vector3(0,1,0),Vector3.RIGHT,Vector3.ZERO,Vector3.UP*2,.3) == 0,"Starting inside a capsule returns immediate contact")
	check(is_inf(Bodies.capsule_distance(Vector3(2,1,-3),Vector3.BACK,Vector3.ZERO,Vector3.UP*2,.3)),"Ray through empty space misses")
	check(is_equal_approx(Bodies.capsule_distance(Vector3(0,0,-3),Vector3.BACK,Vector3.ZERO,Vector3.ZERO,.3),2.7),"Degenerate capsule safely acts as sphere")

func combat() -> void:
	await reset()
	check(is_instance_valid(game.aimed_combat.reticle) and game.aimed_combat.reticle.visible,"An opted-in local ability enables the centered crosshair")
	game.panel.show(); step()
	check(not game.aimed_combat.reticle.visible,"Menus hide the crosshair")
	game.panel.hide(); step()
	check(not game.try_spell(1,0,2),"Aimed ability cannot fall back to tab-target resolution")
	check(shoot(direction()) and b.hp == 88,"Validated aimed cooldown hits the body for integer damage")
	check(game.aimed_combat.reticle.confirmed_left > 0,"Only an authoritative damage result confirms the hit marker")
	check(a.cooldowns[0] == 4 and a.gcd == game.GCD_DURATION and results.size() == 1,"Successful shot spends one cooldown/GCD and emits one result")
	check(not shoot(direction()) and b.hp == 88,"Immediate duplicate cannot shoot again")
	a.action_budget = 0
	check(shoot(direction()) and b.hp == 88 and results.size() == 1,"Server cooldown rejects a new request after the packet budget clears")
	await reset()
	check(shoot(Vector3.UP) and b.hp == 100 and a.cooldowns[0] == 4,"A miss still spends the cooldown")
	await reset()
	var obstacle := wall(Vector3(0,21,-3)); await physics_frame
	check(shoot(direction()) and b.hp == 100 and results.back().blocked,"Terrain stops the shot before the target")
	obstacle.free(); await physics_frame
	await reset()
	obstacle = wall(game.aimed_combat.firing_origin(a.body_hitboxes.points)); await physics_frame
	check(shoot(direction()) and b.hp == 100 and results.back().blocked,"Origin inside cover cannot shoot out through it")
	obstacle.free(); await physics_frame
	await reset()
	b.team = a.team
	check(shoot(direction()) and b.hp == 100,"Friendly bodies stop bullets without friendly fire")
	await reset()
	game.world_mode = true
	check(shoot(direction()) and b.hp == 100,"World bystanders cannot be damaged without duel permission")
	await reset()
	b.position.z = -25; step()
	check(shoot(direction()) and b.hp == 100,"Server range cap prevents distant hits")
	await reset()
	a.casting = 1; a.cast_left = .6
	check(shoot(direction()) and b.hp == 100 and a.cooldowns[0] == 0,"A shot cannot bypass an existing cast")
	await reset()
	game.CC.apply(a,"stun",1,"Test")
	check(shoot(direction()) and b.hp == 100 and a.cooldowns[0] == 0,"Crowd control is rechecked at shot execution")
	await reset()
	var source: Vector3 = game.aimed_combat.firing_origin(a.body_hitboxes.points)
	var head: Vector3 = (b.body_hitboxes.points[8]+b.body_hitboxes.points[9])*.5
	check(shoot((head-source).normalized()) and b.hp == 88 and results.back().part == "head","Head geometry is accurate without a bonus damage multiplier")

func security_and_history() -> void:
	await reset()
	for invalid in [Vector3.ZERO,Vector3(INF,0,0),Vector3(NAN,0,0),Vector3.FORWARD*2]:
		check(not shoot(invalid) and a.last_action_seq == -1,"Invalid aim is rejected before advancing action sequence")
	var aim := direction(); var stamp: float = game.aimed_combat.clock
	check(not shoot(aim,stamp-.30),"Excessively old shot timestamp is rejected")
	check(not shoot(aim,stamp+1),"Future shot timestamp is rejected")
	check(not game.aimed_combat.enqueue(game,1,2,500,0,aim,game.aimed_combat.clock,a.motion_revision),"Sender cannot fire another player's ability")
	check(not game.aimed_combat.enqueue(game,1,0,501,0,aim,game.aimed_combat.clock,a.motion_revision+1),"Wrong motion revision is rejected")
	check(not game.aimed_combat.enqueue(game,1,0,502,1,aim,game.aimed_combat.clock,a.motion_revision),"Ordinary abilities cannot use the hitscan endpoint")
	check(a.cooldowns[0] == 0 and b.hp == 100,"Rejected network inputs spend no cooldown and cause no damage")
	await reset()
	aim = direction(); stamp = game.aimed_combat.clock
	b.position.x += 2
	for i in 6: step()
	check(shoot(aim,stamp) and b.hp == 88,"Bounded rewind hits the body as it was at shot time")
	check(b.position.x == 2,"Lag compensation never moves the live physics body")
	await reset()
	aim = direction(); stamp = game.aimed_combat.clock
	b.position.x += 2; b.motion_revision += 1
	for i in 6: step()
	check(shoot(aim,stamp) and b.hp == 100,"History cannot hit across a teleport revision")
	await reset()
	aim = direction(); stamp = game.aimed_combat.clock
	b.hp = 0; step(); b.hp = 100; step()
	check(shoot(aim,stamp) and b.hp == 100,"A new life cannot be hit using pre-death history")
	await reset()
	for i in 100: step()
	check(game.aimed_combat.history[1].size() <= game.aimed_combat.MAX_SAMPLES,"History has a hard sample/memory bound")
	check(game.aimed_combat.enqueue(game,1,0,900,0,direction(),game.aimed_combat.clock,a.motion_revision),"Valid request enters the bounded physics queue")
	game.clear_actors()
	check(game.aimed_combat.pending.is_empty() and game.aimed_combat.history.is_empty(),"Round teardown discards pending shots and history")
	check(not game.aimed_combat.reticle.visible,"Round teardown hides the opt-in crosshair")

func run() -> void:
	game = load("res://arena.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	game.aimed_shot_resolved.connect(func(result): results.append(result))
	geometry(); await combat(); await security_and_history()
	print("Aimed combat checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
