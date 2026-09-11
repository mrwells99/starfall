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
	ck(b.hp == 80 and b.identity.severe_bleeds.has(1), "Severe hits for integer 20 percent current health and attaches its bleed")
	for i in 5:
		game.Outlaw.tick(game, b, 1)
		ck(b.hp == 80 - (i+1)*2, "Severe bleed tick %d is exactly two damage" % (i+1))
	ck(b.identity.severe_bleeds.is_empty(), "Severe ends after exactly five ticks")
	a.gcd = 0; a.cooldowns[1] = 0; b.hp = 73
	game.try_spell(1, 1, 2); tick(a, .65)
	ck(b.hp == 58, "20 percent of current 73 HP rounds to 15 damage")
	a.gcd = 0; a.cooldowns[1] = 0; a.identity.instant_severe = 1
	b.move_input = Vector2.ZERO; b.gcd = 0
	game.try_spell(2, 5, -1); tick(b, 2.01)
	ck(b.identity.severe_bleeds.is_empty(), "DPS Mend removes Severe")
	var clear_floor := wall(Vector3(0,39.5,0), Vector3(30,1,30))
	await physics_frame
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1,-1), Vector2(-1,-1), Vector2(1,1), Vector2(-1,1), Vector2.ZERO]:
		await reset()
		a.position = Vector3(0,40.025,0); a.velocity = Vector3.ZERO
		for i in 10: game.simulate_movement(a,.016)
		a.move_input = direction.normalized()
		var before: Vector3 = a.position
		ck(game.try_spell(1, 6, -1, PI/2), "Roll accepts direction " + str(direction))
		ck(a.identity.instant_severe == 0 and a.gcd == 0, "Roll is off GCD; its follow-up buff begins after travel")
		var expected: Vector3 = Vector3.LEFT if direction == Vector2.ZERO else Vector3(direction.x, 0, direction.y).normalized()
		tick(a, .1)
		var early: Vector3 = a.position - before; early.y = 0
		ck(early.distance_to(expected*(6.0/.55)*1.5*.1) < .02 and a.identity.roll_left > 0, "Roll travels 50 percent faster during the motion in every direction")
		tick(a, game.Outlaw.ROLL_SECONDS-.1)
		var displacement: Vector3 = a.position - before; displacement.y = 0
		ck(displacement.distance_to(expected*7.8) < .08, "Roll travel %s: actual %s, expected %s" % [direction, displacement, expected*7.8])
		ck(a.identity.instant_severe > 1.48 and a.identity.instant_severe<=1.5 and a.identity.roll_left <= .00001, "Roll completion grants a 1.5-second instant Severe window")
		ck(absf(a.identity.roll_animation_left-(game.Outlaw.ROLL_PRESENTATION_SECONDS-game.Outlaw.ROLL_SECONDS))<.001,"Half-speed Roll keeps only the trimmed cosmetic recovery after unchanged travel and buff timing")
	clear_floor.queue_free(); await physics_frame
	await reset()
	a.move_input = Vector2.RIGHT
	game.try_spell(1, 6, -1); tick(a, game.Outlaw.ROLL_SECONDS)
	b.position = a.position + Vector3.FORWARD * 2
	ck(game.proc_ready(a, a.kit[1]), "Instant Severe highlights its hotbar slot")
	ck(game.try_spell(1, 1, 2) and a.casting == -1 and b.hp == 80, "Roll follow-up Severe fires instantly while moving")
	ck(a.identity.instant_severe == 0 and a.cooldowns[1] == 4 and a.gcd == game.GCD_DURATION, "Successful Severe consumes the buff while retaining its cooldown and GCD")
	game.Outlaw.tick(game,a,.01)
	ck(a.identity.roll_animation_left==0,"Instant Severe immediately cancels Roll's cosmetic recovery")
	await reset()
	a.identity.instant_severe = 1.5; b.position.z = -8
	ck(not game.try_spell(1, 1, 2) and a.identity.instant_severe == 1.5, "Out-of-range Severe preserves the current buff window")
	game.Outlaw.tick(game, a, .6)
	ck(is_equal_approx(a.identity.instant_severe, .9), "Failed attempts do not refresh the 1.5-second timer")
	game.Outlaw.tick(game, a, .5)
	ck(is_equal_approx(a.identity.instant_severe,.4) and game.proc_ready(a,a.kit[1]),"Instant Severe remains available beyond the old one-second expiry")
	game.Outlaw.tick(game, a, .4)
	ck(a.identity.instant_severe <= .000001 and not game.proc_ready(a, a.kit[1]), "Instant Severe expires at 1.5 seconds")
	await reset()
	var obstacle := wall(Vector3(2,1,0), Vector3(.3,2,4)); await physics_frame
	a.move_input = Vector2.RIGHT; game.try_spell(1,6,-1); tick(a,game.Outlaw.ROLL_SECONDS)
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
		ck(a.casting==-1 and b.hp==80 and b.identity.severe_bleeds.has(1), "Moving Severe finishes with its normal damage and bleed")
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
	ck(not game.try_spell(1,5,1), "Ordinary Mend still requires standing still")
	a.move_input=Vector2.ZERO;game.try_spell(1,5,1)
	ck(game.try_spell(2,2,1) and a.casting==-1 and a.locked>0, "Ordinary casts remain kickable")

func moving_starshot() -> void:
	for walking in [false,true]:
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
			await reset()
			a.walking=walking; a.move_input=direction
			ck(game.try_spell(1,0,2) and a.casting==0 and is_equal_approx(a.cast_left,.7), "Starshot starts while running/walking in every direction and keeps its 0.7s cast")
			tick(a,.1)
			var normal_speed: float=(3.8 if direction.y>0 else 6.5)*(.5 if walking else 1.0)
			ck(a.casting==0 and is_equal_approx(Vector2(a.velocity.x,a.velocity.z).length(),normal_speed*.7), "Starshot reduces running, walking and diagonal/backpedal speed by exactly 30 percent")
			b.position=a.position+Vector3.FORWARD*2
			var remaining: float=a.cast_left
			ck(game.try_spell(2,2,1) and a.casting==0 and a.locked==0 and is_equal_approx(a.cast_left,remaining), "An enemy kick cannot cancel Starshot or apply a school lockout")
			for frame in 37:
				b.position=a.position+Vector3.FORWARD*2
				tick(a,1.0/60)
			ck(a.casting==-1 and b.hp==92 and a.identity.outlaw_channel.is_empty(), "Moving Starshot completes eight damage without a channel: %s walking=%s" % [direction,walking])
			tick(a,.02)
			ck(is_equal_approx(Vector2(a.velocity.x,a.velocity.z).length(),normal_speed), "Normal movement speed returns after Starshot completes")
	await reset()
	game.try_spell(1,0,2); a.move_input=Vector2.RIGHT; tick(a,.1)
	ck(a.casting==0 and is_equal_approx(a.velocity.x,4.55), "Starting movement after Starshot begins keeps the cast and applies its speed cost")
	game.cancel_own_cast(a,"Test"); tick(a,.02)
	ck(a.casting==-1 and is_equal_approx(a.velocity.x,6.5), "Cancelling Starshot immediately restores running speed")
	await reset()
	game.try_spell(1,0,2); game.CC.apply(a,"stun",1,"Test"); tick(a,.8)
	ck(a.casting==-1 and b.hp==100, "Hard crowd control still cancels Starshot")
	await reset()
	game.try_spell(1,0,2); b.position.z=-25; tick(a,.71)
	ck(a.casting==-1 and b.hp==100, "Starshot rechecks its unchanged 18m range at completion")
	await reset()
	game.try_spell(1,0,2)
	var obstacle:=wall(Vector3(0,1.5,-1),Vector3(2,3,.3)); await physics_frame
	tick(a,.71)
	ck(a.casting==-1 and b.hp==100, "Starshot still checks terrain when it finishes")
	obstacle.queue_free(); await physics_frame
	await reset()
	a.move_input=Vector2.UP; game.try_spell(1,0,2); a.jump_queued=true; tick(a,.1)
	ck(a.casting==0 and not a.is_on_floor() and is_equal_approx(a.velocity.z,-4.55), "Jumping during Starshot keeps the cast and the slowed takeoff momentum")
	a.move_input=Vector2.RIGHT; tick(a,.1)
	ck(a.casting==0 and is_equal_approx(a.velocity.z,-4.55) and absf(a.velocity.x)<.001, "Casting still preserves world-space jump direction while airborne")
	await reset()
	a.move_input=Vector2.UP; a.walking=true; a.sprint=2; a.identity.slow=2
	game.try_spell(1,0,2); tick(a,.1)
	ck(is_equal_approx(absf(a.velocity.z),6.5*.5*1.65*.55*.7), "Starshot's self speed cost composes with existing walk, sprint and slow modifiers")

func measure_backflip(legacy: bool, rate: int, yaw := 0.0) -> Dictionary:
	var previous_rate := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = rate
	await physics_frame
	await reset()
	a.position = Vector3(0,20.025,0); a.velocity = Vector3.ZERO; a.rotation.y = yaw
	for frame in 10: game.simulate_movement(a,1.0/60)
	var start: Vector3 = a.position
	ck(game.try_spell(1,3,-1),"Backflip trajectory fixture launches from grounded terrain")
	if legacy:
		# Compare to the immediately preceding accepted trajectory.
		var backward: Vector3 = a.basis.z*(3.0*2.0/sqrt(.85))
		a.velocity = Vector3(backward.x,12.0*sqrt(.85),backward.z)
	var peak := 0.0
	var elapsed := 0.0
	for frame in rate*3:
		await physics_frame
		a.input_age = 0; game.tick_actor(a,1.0/rate); elapsed += 1.0/rate
		peak = maxf(peak,a.position.y-start.y)
		if a.is_on_floor() and a.velocity.y <= 0: break
	var travel: Vector3 = a.position-start; travel.y = 0
	Engine.physics_ticks_per_second = previous_rate
	return {"distance":travel.length(),"peak":peak,"elapsed":elapsed,"travel":travel,"landed":a.is_on_floor()}

func backflip_trajectory() -> void:
	var floor_body := wall(Vector3(0,19.5,0),Vector3(40,1,40))
	await physics_frame
	for rate in [30,60]:
		var before: Dictionary = await measure_backflip(true,rate)
		var after: Dictionary = await measure_backflip(false,rate)
		ck(before.landed and after.landed,"Both Backflip trajectories land safely on level ground")
		ck(absf(after.distance/before.distance-1.2) < .02,"Backflip adds 20 percent actual backward displacement at %d FPS" % rate)
		ck(absf(after.peak/before.peak-.93) < .012,"Backflip lowers measured apex another 7 percent at %d FPS" % rate)
		ck(after.elapsed < before.elapsed,"Lower Backflip completes its airborne combo window sooner")
		print("BACKFLIP_TRAJECTORY %d FPS: old %.3fm / %.3fm peak; new %.3fm / %.3fm peak / %.3fs" % [rate,before.distance,before.peak,after.distance,after.peak,after.elapsed])
	var sideways: Dictionary = await measure_backflip(false,60,PI/2)
	ck(sideways.travel.x > 8.5 and absf(sideways.travel.z) < .05,"Backflip still travels backwards relative to character facing")
	var obstacle := wall(Vector3(0,24,3),Vector3(10,8,.3)); await physics_frame
	var blocked: Dictionary = await measure_backflip(false,60)
	ck(blocked.landed and a.position.z < 2.5 and not a.test_move(a.transform,Vector3.ZERO),"Faster Backflip stops before a rear wall without entering terrain")
	obstacle.queue_free(); floor_body.queue_free(); await physics_frame

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
	ck(game.try_spell(1,2,2) and b.hp == 82, "Separate Trickshot fires during Backflip despite global cooldown")
	ck(a.identity.defense_detonation == 1 and not a.identity.backflip_combo, "One successful airborne Trickshot earns one stack and consumes its opportunity")
	ck(not game.try_spell(1,2,2), "A Backflip opportunity cannot be spent twice")
	tick(a, 1.5)
	ck(not a.identity.backflip_active and not game.CC.airborne_immune(a), "Immunity and unused combo opportunity end on landing")
	ck(game.CC.apply(a,"root",3,"Test") == 3, "Crowd control works normally after landing")
	await reset()
	a.position.y = 2; a.velocity.y = 0
	game.simulate_movement(a,.001)
	var airborne_origin: Vector3=a.position
	ck(game.try_spell(1,3,-1), "Backflip can begin at an ordinary airborne apex")
	ck(a.identity.backflip_active and a.identity.backflip_combo and is_equal_approx(a.velocity.y,game.Outlaw.BACKFLIP_SPEED) and a.position.y>=airborne_origin.y,"Airborne Backflip launches from the current position with its normal combo and upward impulse")
	ck(not game.try_spell(1,3,-1) and a.cooldowns[3]>0,"The existing cooldown prevents repeatedly chaining airborne Backflips")
	ck(game.CC.airborne_immune(a),"A jump-to-Backflip transition gains the usual airborne immunity")
	await reset()
	a.jump_queued=true; game.simulate_movement(a,1.0/60)
	ck(not a.is_on_floor() and a.velocity.y>0,"Fixture starts an actual normal jump")
	ck(game.try_spell(1,3,-1) and a.identity.backflip_active,"Backflip can take over while a normal jump is ascending")
	await reset()
	a.position.y=2; a.velocity.y=-2; game.simulate_movement(a,1.0/60)
	ck(game.try_spell(1,3,-1) and is_equal_approx(a.velocity.y,game.Outlaw.BACKFLIP_SPEED),"Backflip can also launch during jump descent")
	await reset()
	ck(game.try_spell(1,7,-1), "Coin Toss is usable without a selected enemy")
	game.Outlaw.tick(game,a,.5)
	ck(a.identity.coin_left > 1.2 and a.identity.coin_position.y > 2, "Coin travels in a visible physical arc")
	ck(game.try_spell(1,2,2) and b.hp == 82 and a.identity.coin_left == 0, "Coin Trickshot fires off GCD and consumes the flying coin")
	ck(a.identity.defense_detonation == 1, "A successful coin combo awards one stack")
	await reset()
	var obstacle := wall(Vector3(0,1.5,-1),Vector3(1,3,.3)); await physics_frame
	# A real two-segment path around the right edge of a pillar.
	a.identity.coin_left = 1; a.identity.coin_position = Vector3(2,2,-1)
	ck(not game.has_los(a,b), "Coin fixture blocks direct player-to-target sight")
	ck(game.try_spell(1,2,2) and b.hp == 82, "Trickshot can ricochet around cover when both bullet legs are clear")
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

class ClientOnly extends RefCounted:
	func authoritative() -> bool: return false

func detonation_foundation() -> void:
	await reset()
	ck(a.kit[8].cast == 0 and a.kit[8].get("local_only",false), "Detonation has no cast/channel and currently only opens aiming")
	for count in range(4):
		a.identity.defense_detonation = count; a.gcd = 0
		ck(game.proc_ready(a,a.kit[8]) == (count>0), "Detonation signals each available stack count, including one")
		ck(not game.try_spell(1,8,2), "Old targeted Detonation commands are rejected at every stack count")
		tick(a,3.1)
		ck(a.identity.defense_detonation == count and a.casting == -1 and b.hp == 100, "Rejected legacy cast never spends stacks, channels or deals automatic damage")
		var plan: Dictionary = game.Outlaw.detonation_burst_plan(a)
		ck(plan.is_empty() == (count==0), "A future burst requires at least one stack, not three")
		ck(a.identity.defense_detonation == count, "Inspecting a burst plan leaves the resource unchanged")
		var reserved: Dictionary = game.Outlaw.reserve_detonation_burst(game,a)
		if count == 0:
			ck(reserved.is_empty() and a.gcd == 0, "An empty burst spends nothing")
			continue
		ck(reserved.shots == count and a.identity.defense_detonation == 0, "Future authoritative fire reserves every current stack atomically")
		ck(reserved.offsets.size() == count and reserved.offsets[0] == 0 and reserved.offsets.back() <= .26, "The first shot has no windup and up to three shots form a rapid burst")
		ck(is_equal_approx(reserved.health_fraction,.1) and a.casting == -1 and b.hp == 100, "Prepared burst keeps ten-percent shot damage without performing a channel or hit")
		if count > 1: ck(is_equal_approx(reserved.offsets[1],.13), "Prepared shots use 130ms spacing")
		ck(game.Outlaw.reserve_detonation_burst(game,a).is_empty(), "A repeated request cannot reuse spent stacks")
		a.identity.defense_detonation = 1
		ck(reserved.shots == count and game.Outlaw.reserve_detonation_burst(game,a).is_empty() and a.identity.defense_detonation == 1, "A new combo stack is preserved for the next burst and the original firing GCD applies")
	await reset()
	a.identity.defense_detonation = 2
	ck(game.Outlaw.reserve_detonation_burst(ClientOnly.new(),a).is_empty() and a.identity.defense_detonation == 2, "A client cannot authorize a stack spend")
	for state in ["stun","cast","roll","backflip","lock","dead","round"]:
		a.stunned = 1 if state=="stun" else 0; a.casting = 0 if state=="cast" else -1
		a.identity.roll_left = .1 if state=="roll" else 0; a.identity.backflip_active = state=="backflip"
		a.locked = 1 if state=="lock" else 0; a.hp = 0 if state=="dead" else 100
		game.phase = "countdown" if state=="round" else "match"
		ck(game.Outlaw.reserve_detonation_burst(game,a).is_empty() and a.identity.defense_detonation == 2, "Invalid future fire preserves stacks during "+state)
	await reset()

func channels() -> void:
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
	ck(a.cooldowns[9] == 0, "Interrupted Deadeye refunds its entire remaining cooldown")
	await reset()
	game.spawn_actor(3,3,1,"Vanguard",Vector3(0,.025,8))
	game.spawn_actor(4,4,1,"Luminary",Vector3(0,.025,-22))
	var obstacle := wall(Vector3(0,1.5,-1),Vector3(1,3,.3)); await physics_frame
	a.move_input = Vector2.RIGHT
	ck(game.try_spell(1,9,-1) and a.cooldowns[9] == 90, "Deadeye starts without a tab target and spends its long cooldown")
	ck(a.identity.outlaw_channel.marked.size() == 3, "Deadeye initially marks every enemy, including behind cover, behind the caster and outside range")
	var before: Vector3 = a.position; a.jump_queued = true; tick(a,.1)
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

func severe_reach() -> void:
	for instant in [false,true]:
		await reset()
		ck(is_equal_approx(a.kit[1].range,3.3),"Severe has exactly 10 percent more reach without half-metre rounding")
		a.identity.instant_severe = 1 if instant else 0
		b.position = a.position + Vector3.FORWARD*3.301
		ck(not game.try_spell(1,1,2) and a.cooldowns[1]==0,"Severe rejects targets just beyond 3.3m for both normal and Roll casts")
		b.position = a.position + Vector3.FORWARD*3.299
		ck(game.try_spell(1,1,2),"Severe can start just inside its expanded reach")
		tick(a,.61)
		ck(b.hp==80 and b.identity.severe_bleeds.has(1),"Severe lands full damage and bleed within the new reach")
	await reset()
	b.position = a.position + Vector3.FORWARD*3.2
	game.try_spell(1,1,2); b.position.z -= .2; tick(a,.61)
	ck(b.hp==100,"Moving beyond the expanded range before completion still avoids Severe")

func coin_momentum() -> void:
	# Actual movement establishes launch velocity; a clear raised floor keeps
	# arena pillars from obscuring distance and directional inheritance checks.
	var floor_body := wall(Vector3(0,39.5,0),Vector3(80,1,80)); await physics_frame
	for yaw in [0.0,PI/2]:
		for direction in [Vector2.ZERO,Vector2.UP,Vector2.DOWN,Vector2.RIGHT,Vector2(1,-1).normalized()]:
			await reset()
			a.position = Vector3(0,40.025,0); a.velocity = Vector3.ZERO
			a.rotation.y=yaw; a.move_input=direction
			for frame in 10: game.simulate_movement(a,1.0/60)
			var velocity: Vector3=a.velocity
			var start: Vector3=a.position
			ck(game.try_spell(1,7,-1,yaw),"Coin Toss can launch during movement: %s at %s" % [direction,yaw])
			var origin: Vector3=a.identity.coin_origin
			tick(a,.5)
			var relative: Vector3=a.identity.coin_position-origin-(a.position-start); relative.y=0
			var heading: Vector3=Basis(Vector3.UP,yaw)*Vector3.FORWARD
			ck(relative.distance_to(heading*2.5)<.02,"Coin gains 2.5m over its moving caster in half a second, including diagonals/backpedal")
			if direction==Vector2.UP:
				var travel: Vector3=a.identity.coin_position-origin; travel.y=0
				ck(absf(travel.length()-5.75)<.02,"Forward-running coin travels at 11.5m/s instead of falling behind a 6.5m/s runner")
			var current: Vector3=a.identity.coin_position
			a.move_input=-direction; a.rotation.y += PI; a.velocity=Vector3.ZERO
			tick(a,.25)
			var remaining_travel: Vector3=a.identity.coin_position-current; remaining_travel.y=0
			var expected: Vector3=(heading*5+velocity)*.25; expected.y=0
			ck(remaining_travel.distance_to(expected)<.02,"Stopping or turning afterward does not steer a released coin")
	floor_body.queue_free(); await physics_frame
	await reset()
	a.position.y=10; a.velocity=Vector3(0,7,-6.5)
	game.try_spell(1,7,-1)
	var origin: Vector3=a.identity.coin_origin
	game.Outlaw.tick(game,a,.25)
	ck(absf((a.identity.coin_position-origin).y-2.9125)<.001,"An airborne toss inherits upward jump momentum too")
	var saved: Dictionary=bytes_to_var(var_to_bytes(a.snapshot()))
	var position: Vector3=a.identity.coin_position
	a.reset_identity(); a.receive(saved,true)
	ck(a.identity.coin_momentum==Vector3(0,7,-6.5) and a.identity.coin_position==position,"Coin launch momentum and position survive the network snapshot format")
	game.Outlaw.tick(game,a,1.56)
	ck(a.identity.coin_left==0,"Inherited momentum does not lengthen the 1.8s combo window")
	a.reset_identity()
	ck(a.identity.coin_momentum==Vector3.ZERO and a.identity.coin_left==0,"Round cleanup clears inherited coin momentum")
	await reset()
	a.velocity=Vector3(0,0,-20)
	var obstacle:=wall(Vector3(0,2,-4),Vector3(5,4,.1)); await physics_frame
	game.try_spell(1,7,-1); game.Outlaw.tick(game,a,.3)
	ck(a.identity.coin_left==0 and not game.try_spell(1,2,2),"A fast inherited throw sweeps into thin terrain and loses its combo instead of tunnelling through")
	obstacle.queue_free(); await physics_frame
	await reset()

func deadeye_refunds() -> void:
	for category in ["stun","incapacitate","disorient","silence","disarm"]:
		await reset()
		game.try_spell(1,9,-1); tick(a,.25)
		ck(a.cooldowns[9]>89 and a.casting==9,"Deadeye reserves its normal cooldown during the windup")
		game.CC.apply(a,category,1,"Test"); tick(a,1.0/60)
		ck(a.casting==-1 and a.cooldowns[9]==0 and b.hp==100 and a.identity.outlaw_channel.is_empty(),"Deadeye refunds on "+category+" without applying damage")
	for elapsed in [.05,1.5,2.99]:
		await reset()
		game.try_spell(1,9,-1); tick(a,elapsed)
		game.cancel_own_cast(a,""); tick(a,1.0/60)
		ck(a.cooldowns[9]==0 and b.hp==100,"Manual cancellation refunds Deadeye even immediately before completion")
		ck(game.try_spell(1,9,-1) and a.cooldowns[9]==90,"Refunded Deadeye can be cast again after cancellation")
	for slot in [1,8]:
		await reset()
		game.spawn_actor(3,3,1,"Fulcrum",Vector3(0,.025,4))
		var fulcrum=game.actors[3]; fulcrum.owner_peer=3
		fulcrum.rotation.y=0
		fulcrum.identity.anchor_left=20; fulcrum.identity.anchor_pos=Vector3(0,.025,-4)
		game.try_spell(1,9,-1)
		ck(game.try_spell(3,slot,1) and a.casting==-1,"Fulcrum displacement interrupts Deadeye")
		tick(a,1.0/60)
		ck(a.cooldowns[9]==0,"Inward/Outward interruption refunds Deadeye")
	await reset()
	game.try_spell(1,9,-1); a.hp=0; a.casting=-1; tick(a,1.0/60)
	ck(a.cooldowns[9]==0 and a.identity.outlaw_channel.is_empty(),"Death before completion also releases Deadeye's reserved cooldown")
	await reset()
	game.world_mode=true; game.duels={1:2,2:1}
	game.try_spell(1,9,-1); game.damage(b,a,200)
	ck(a.hp==0 and a.cooldowns[9]==0 and a.identity.outlaw_channel.is_empty(),"Lethal damage refunds Deadeye before world-duel cleanup erases channel state")
	await reset()
	game.world_mode=true; game.duels={1:2,2:1}
	game.try_spell(1,9,-1); game.end_duel(2,1); tick(a,1.0/60)
	ck(a.casting==-1 and a.cooldowns[9]==0,"A duel ending during the winner's windup refunds that unfinished Deadeye too")
	await reset()
	game.try_spell(1,9,-1); game.CC.apply(a,"root",1,"Test"); tick(a,.2)
	ck(a.casting==9 and a.cooldowns[9]>89,"Root alone does not interrupt Deadeye or refund it")
	game.try_spell(2,2,1); tick(a,.1)
	ck(a.casting==9 and a.cooldowns[9]>89,"An ineffective kick does not grant a cooldown refund")
	tick(a,2.71)
	ck(a.casting==-1 and b.hp==60 and a.cooldowns[9]>86,"Completed Deadeye keeps its cooldown and damage")
	a.gcd=0; game.try_spell(1,0,2); game.cancel_own_cast(a,""); tick(a,.1)
	ck(a.cooldowns[9]>86,"Cancelling a later spell cannot refund an already completed Deadeye")
	await reset()
	game.try_spell(1,9,-1); b.position.z=-25; tick(a,3.01)
	ck(a.casting==-1 and b.hp==100 and a.cooldowns[9]>86,"Finishing with nobody in range still spends Deadeye's cooldown")
	await reset()
	game.try_spell(1,9,-1)
	var obstacle:=wall(Vector3(0,1.5,-1),Vector3(2,3,.3)); await physics_frame
	tick(a,3.01)
	ck(a.casting==-1 and b.hp==100 and a.cooldowns[9]>86,"Finishing with everyone behind cover is a completed cast, not a refund")
	obstacle.queue_free(); await physics_frame
	await reset()

func run() -> void:
	game = load("res://arena.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	await severe_and_roll()
	await moving_severe()
	await severe_reach()
	await moving_starshot()
	await backflip_trajectory()
	await backflip_and_coin()
	await coin_momentum()
	await detonation_foundation()
	await channels()
	await deadeye_refunds()
	print("Outlaw ability checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
