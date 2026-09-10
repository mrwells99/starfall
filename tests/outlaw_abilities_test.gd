extends SceneTree
var game
var a
var b
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func reset() -> void:
	game.world_mode = false
	game.mode = 1
	game.roster = {1: {"champion": "Outlaw", "team": 0}, 2: {"champion": "Ember", "team": 1}}
	game.begin_round(); game.phase = "match"
	a = game.actors[1]; b = game.actors[2]
	a.owner_peer = 1; b.owner_peer = 2
	a.position = Vector3(0, .025, 0); b.position = Vector3(0, .025, -2)
	a.rotation.y = 0; b.rotation.y = PI
	await physics_frame
	for i in 10:
		game.simulate_movement(a, .016); game.simulate_movement(b, .016)
func tick(a_actor, seconds: float) -> void:
	var left := seconds
	while left > .000001:
		var step := minf(left, 1.0/60)
		a_actor.input_age = 0
		game.tick_actor(a_actor, step)
		left -= step
func wall(at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); var shape := BoxShape3D.new(); shape.size = dimensions
	var collider := CollisionShape3D.new(); collider.shape = shape; body.add_child(collider)
	game.add_child(body); body.position = at
	return body

func severe_and_roll() -> void:
	await reset()
	ck(a.champion_model.outlaw_art != null, "Outlaw uses its actual authored model")
	ck(game.champion_choice.item_count == 5, "Outlaw is selectable as the fifth class")
	ck(game.try_spell(1, 1, 2) and a.casting == 1, "Ordinary Severe starts its short cast")
	tick(a, .65)
	ck(b.hp == 85 and b.identity.severe_bleeds.has(1), "Severe hits for integer 15 percent current health and attaches its bleed")
	for i in 5:
		game.Outlaw.tick(game, b, 1)
		ck(b.hp == 85 - (i+1)*2, "Severe bleed tick %d is exactly two damage" % (i+1))
	ck(b.identity.severe_bleeds.is_empty(), "Severe ends after exactly five ticks")
	a.gcd = 0; a.cooldowns[1] = 0; b.hp = 73
	game.try_spell(1, 1, 2); tick(a, .65)
	ck(b.hp == 62, "15 percent of current 73 HP rounds to 11 damage")
	a.gcd = 0; a.cooldowns[1] = 0; a.identity.instant_severe = 1
	b.move_input = Vector2.ZERO; b.gcd = 0
	game.try_spell(2, 5, -1); tick(b, 2.01)
	ck(b.identity.severe_bleeds.is_empty(), "DPS Mend removes Severe")
	var clear_floor := wall(Vector3(0,19.5,0), Vector3(30,1,30))
	await physics_frame
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1,-1), Vector2(-1,-1), Vector2(1,1), Vector2(-1,1), Vector2.ZERO]:
		await reset()
		a.position = Vector3(0,20.025,0); a.velocity = Vector3.ZERO
		for i in 10: game.simulate_movement(a,.016)
		a.move_input = direction.normalized()
		var before: Vector3 = a.position
		ck(game.try_spell(1, 6, -1, PI/2), "Roll accepts direction " + str(direction))
		ck(a.identity.instant_severe == 0 and a.gcd == 0, "Roll is off GCD; its follow-up buff begins after travel")
		tick(a, .55)
		var expected: Vector3 = Vector3.LEFT if direction == Vector2.ZERO else Vector3(direction.x, 0, direction.y).normalized()
		var displacement: Vector3 = a.position - before; displacement.y = 0
		ck(displacement.distance_to(expected*6) < .08, "Roll travel %s: actual %s, expected %s" % [direction, displacement, expected*6])
		ck(a.identity.instant_severe > .98 and a.identity.roll_left <= .00001, "Roll completion grants exactly a one-second instant Severe window")
	clear_floor.queue_free(); await physics_frame
	await reset()
	a.move_input = Vector2.RIGHT
	game.try_spell(1, 6, -1); tick(a, .55)
	b.position = a.position + Vector3.FORWARD * 2
	ck(game.proc_ready(a, a.kit[1]), "Instant Severe highlights its hotbar slot")
	ck(game.try_spell(1, 1, 2) and a.casting == -1 and b.hp == 85, "Roll follow-up Severe fires instantly while moving")
	ck(a.identity.instant_severe == 0 and a.cooldowns[1] == 4 and a.gcd == game.GCD_DURATION, "Successful Severe consumes the buff while retaining its cooldown and GCD")
	await reset()
	a.identity.instant_severe = 1; b.position.z = -8
	ck(not game.try_spell(1, 1, 2) and a.identity.instant_severe == 1, "Out-of-range Severe preserves the current buff window")
	game.Outlaw.tick(game, a, .6)
	ck(is_equal_approx(a.identity.instant_severe, .4), "Failed attempts do not refresh the one-second timer")
	game.Outlaw.tick(game, a, .4)
	ck(a.identity.instant_severe <= .000001 and not game.proc_ready(a, a.kit[1]), "Instant Severe expires at one second")
	await reset()
	var obstacle := wall(Vector3(2,1,0), Vector3(.3,2,4)); await physics_frame
	a.move_input = Vector2.RIGHT; game.try_spell(1,6,-1); tick(a,.55)
	ck(a.position.x < 1.5 and not a.test_move(a.transform, Vector3.ZERO), "Roll stops its capsule before solid terrain")
	obstacle.queue_free(); await physics_frame

func moving_severe() -> void:
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
		await reset()
		a.move_input=direction
		ck(game.ability_block_reason(a,1,2).is_empty(), "Severe's hotbar allows moving direction " + str(direction))
		ck(game.try_spell(1,1,2) and a.casting==1 and is_equal_approx(a.cast_left,.6), "Moving Severe retains its 0.6-second cast")
		var before: Vector3=a.position
		tick(a,.1)
		var expected_speed: float=3.8 if direction.y>0 else 6.5
		ck(a.casting==1 and is_equal_approx(Vector2(a.velocity.x,a.velocity.z).length(),expected_speed) and a.position.distance_to(before)>.35, "Severe keeps normal movement and remains in progress")
		b.position=a.position+Vector3.FORWARD*2
		ck(game.try_spell(2,2,1) and a.casting==1 and a.locked==0, "Kick cannot cancel Severe or apply a school lockout")
		for frame in 31:
			b.position=a.position+Vector3.FORWARD*2
			tick(a,1.0/60)
		ck(a.casting==-1 and b.hp==85 and b.identity.severe_bleeds.has(1), "Moving Severe finishes with its normal damage and bleed")
		ck(a.cooldowns[1]>3.9 and a.cooldowns[1]<=4 and a.gcd>0 and a.identity.outlaw_channel.is_empty(), "Severe keeps its cooldown and GCD without entering the gun-channel system")
	await reset()
	game.try_spell(1,1,2);a.move_input=Vector2.RIGHT;tick(a,.1)
	ck(a.casting==1, "Starting movement after beginning Severe does not cancel it")
	game.CC.apply(a,"stun",1,"Test")
	ck(a.casting==-1, "Severe still responds to hard crowd control")
	await reset()
	game.try_spell(1,1,2);b.position.z=-10;tick(a,.65)
	ck(b.hp==100 and b.identity.severe_bleeds.is_empty(), "Severe still checks melee range when it finishes")
	await reset()
	game.try_spell(1,1,2)
	var obstacle:=wall(Vector3(0,1.5,-1),Vector3(2,3,.3));await physics_frame
	tick(a,.65)
	ck(b.hp==100 and b.identity.severe_bleeds.is_empty(), "Severe still checks terrain when it finishes")
	obstacle.queue_free();await physics_frame
	await reset()
	a.move_input=Vector2.RIGHT
	ck(not game.try_spell(1,0,2), "Starshot still requires standing still")
	a.move_input=Vector2.ZERO;game.try_spell(1,0,2)
	ck(game.try_spell(2,2,1) and a.casting==-1 and a.locked>0, "Ordinary casts remain kickable")

func backflip_and_coin() -> void:
	await reset()
	ck(not game.try_spell(1,2,2), "Trickshot requires its own combo window")
	ck(game.try_spell(1,3,-1) and b.hp == 100, "Backflip is purely movement and deals no damage")
	var launch: Vector3 = a.velocity
	for category in game.CC.CATEGORIES:
		ck(game.CC.apply(a, category, 3, "Test") == 0 and not a.dr_states.has(category), "Airborne Backflip blocks " + category + " without gaining DR")
	var before: Vector3 = a.position; game.move_ability(a,Vector3.RIGHT*8)
	ck(a.position == before and a.velocity == launch, "Backflip also blocks forced displacement")
	a.gcd = 1.5
	ck(game.try_spell(1,2,2) and b.hp == 88, "Separate Trickshot fires during Backflip despite global cooldown")
	ck(a.identity.defense_detonation == 1 and not a.identity.backflip_combo, "One successful airborne Trickshot earns one stack and consumes its opportunity")
	ck(not game.try_spell(1,2,2), "A Backflip opportunity cannot be spent twice")
	tick(a, 1.5)
	ck(not a.identity.backflip_active and not game.CC.airborne_immune(a), "Immunity and unused combo opportunity end on landing")
	ck(game.CC.apply(a,"root",3,"Test") == 3, "Crowd control works normally after landing")
	await reset()
	a.position.y = 2; a.velocity.y = 0
	game.simulate_movement(a,.001)
	ck(not game.try_spell(1,3,-1), "Cannot restart Backflip at an airborne apex")
	await reset()
	ck(game.try_spell(1,7,-1), "Coin Toss is usable without a selected enemy")
	game.Outlaw.tick(game,a,.5)
	ck(a.identity.coin_left > 1.2 and a.identity.coin_position.y > 2, "Coin travels in a visible physical arc")
	ck(game.try_spell(1,2,2) and b.hp == 88 and a.identity.coin_left == 0, "Coin Trickshot fires off GCD and consumes the flying coin")
	ck(a.identity.defense_detonation == 1, "A successful coin combo awards one stack")
	await reset()
	var obstacle := wall(Vector3(0,1.5,-1),Vector3(1,3,.3)); await physics_frame
	# A real two-segment path around the right edge of a pillar.
	a.identity.coin_left = 1; a.identity.coin_position = Vector3(2,2,-1)
	ck(not game.has_los(a,b), "Coin fixture blocks direct player-to-target sight")
	ck(game.try_spell(1,2,2) and b.hp == 88, "Trickshot can ricochet around cover when both bullet legs are clear")
	a.identity.coin_left = 1; a.identity.coin_position = Vector3(0,1,-.5)
	ck(not game.try_spell(1,2,2) and a.identity.coin_left == 1, "A blocked coin-to-target leg neither hits nor consumes the coin")
	a.gcd = 0; a.cooldowns[7] = 0; game.try_spell(1,7,-1)
	game.Outlaw.tick(game,a,.3)
	ck(a.identity.coin_left == 0, "A thrown coin cannot pass through a wall")
	obstacle.queue_free(); await physics_frame
	await reset()
	a.identity.coin_left = .01; game.Outlaw.tick(game,a,.02)
	ck(not game.try_spell(1,2,2), "Expired coin grants no lingering Trickshot charge")
	game.world_mode = true; a.identity.coin_left = 1; a.identity.coin_position = a.position + Vector3.UP*2
	ck(not game.try_spell(1,2,2) and b.hp == 100 and a.identity.defense_detonation == 0, "Combos cannot damage or gain stacks from world bystanders")

func channels() -> void:
	await reset()
	ck(not game.try_spell(1,8,2), "Defense Detonation requires all three stacks")
	a.identity.defense_detonation = 3; a.move_input = Vector2.RIGHT
	ck(game.try_spell(1,8,2) and a.identity.defense_detonation == 0, "Detonation starts while moving and spends exactly three stacks")
	var before: Vector3 = a.position; tick(a,.1)
	ck(a.position.distance_to(before) > .6 and a.casting == 8, "Detonation preserves normal running speed")
	ck(game.try_spell(2,2,1) and a.casting == 8 and a.locked == 0, "Enemy kick neither cancels Detonation nor applies lockout")
	a.move_input = Vector2.ZERO
	tick(a,.9); ck(b.hp == 90, "Detonation first shot deals ten percent maximum HP")
	tick(a,1); ck(b.hp == 80, "Detonation second shot is separately timed")
	tick(a,1.01); ck(b.hp == 70 and a.casting == -1, "Detonation third shot ends its channel")
	await reset()
	a.identity.defense_detonation = 3; game.try_spell(1,8,2)
	game.CC.apply(a,"stun",1,"Test"); tick(a,.1)
	ck(a.casting == -1 and a.identity.outlaw_channel.is_empty() and b.hp == 100, "Detonation remains vulnerable to non-kick crowd control")
	await reset()
	ck(game.try_spell(1,9,-1), "Deadeye starts its kick-immune windup")
	tick(a,.2)
	var remaining: float = a.cast_left
	ck(game.try_spell(2,2,1) and a.casting == 9 and a.locked == 0 and is_equal_approx(a.cast_left,remaining), "Enemy kick neither cancels Deadeye, changes its timer nor applies lockout")
	tick(a,2.81)
	ck(a.casting == -1 and b.hp == 60, "Deadeye completes its full damage after an enemy kick")
	await reset()
	game.try_spell(1,9,-1)
	game.CC.apply(a,"stun",1,"Test"); tick(a,.1)
	ck(a.casting == -1 and a.identity.outlaw_channel.is_empty() and b.hp == 100, "Deadeye remains vulnerable to non-kick crowd control")
	await reset()
	game.spawn_actor(3,3,1,"Vanguard",Vector3(0,.025,8))
	game.spawn_actor(4,4,1,"Luminary",Vector3(0,.025,-22))
	var obstacle := wall(Vector3(0,1.5,-1),Vector3(1,3,.3)); await physics_frame
	a.move_input = Vector2.RIGHT
	ck(game.try_spell(1,9,-1) and a.cooldowns[9] == 90, "Deadeye starts without a tab target and spends its long cooldown")
	ck(a.identity.outlaw_channel.marked.size() == 3, "Deadeye initially marks every enemy, including behind cover, behind the caster and outside range")
	before = a.position; a.jump_queued = true; tick(a,.1)
	ck(a.position.distance_to(before) > .3 and a.position.distance_to(before) < .35 and a.velocity.y <= 0, "Deadeye forces walking speed and prevents jumping")
	a.move_input = Vector2.ZERO
	tick(a,2.91)
	ck(b.hp == 100, "Enemy still behind terrain at Deadeye completion takes no damage")
	ck(game.actors[3].hp == 60, "Final clarification: a visible enemy behind the caster is also hit")
	ck(game.actors[4].hp == 100 and a.casting == -1, "Deadeye respects final sight range and releases walking state")
	obstacle.queue_free(); await physics_frame
	await reset()
	obstacle = wall(Vector3(0,1.5,-1),Vector3(1,3,.3)); await physics_frame
	game.try_spell(1,9,-1); tick(a,1)
	obstacle.queue_free(); await physics_frame
	tick(a,2.01)
	ck(b.hp == 60, "Enemy acquired behind cover is hit if visible when Deadeye finishes")
	await reset()
	a.identity.defense_detonation = 2; a.identity.instant_severe = .7; a.identity.coin_left = .8
	var state: Dictionary = bytes_to_var(var_to_bytes(a.snapshot()))
	a.reset_identity(); a.receive(state,true)
	ck(a.identity.defense_detonation == 2 and is_equal_approx(a.identity.instant_severe,.7) and is_equal_approx(a.identity.coin_left,.8), "Resources and short combo buffs survive network snapshot serialization")
	a.reset_identity()
	ck(a.identity.defense_detonation == 0 and a.identity.instant_severe == 0 and a.identity.coin_left == 0, "Round and duel reset clears all Outlaw resources and opportunities")

func run() -> void:
	game = load("res://arena.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	await severe_and_roll()
	await moving_severe()
	await backflip_and_coin()
	await channels()
	print("Outlaw ability checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
