extends "res://tests/outlaw_abilities_test.gd"

func step(seconds: float) -> void:
	for i in ceili(seconds * 60):
		for actor in [a,b]:
			actor.input_age = 0
			game.tick_actor(actor,1.0/60)

func reach_phase(phase: String, limit := 120) -> bool:
	for i in limit:
		if game.Outlaw.Lasso.state(a).get("phase", "") == phase: return true
		step(1.0/60)
	return false

func basic() -> void:
	await reset()
	b.position.z = -12
	ck(a.kit[11].name == "Lasso" and game.assignment.find(11) >= 0, "Lasso occupies a usable hotbar slot without shifting existing abilities")
	ck(game.try_spell(1,11,2) and a.casting == 11, "Lasso starts its 0.7-second cast")
	ck(game.kick_immune(a), "Lasso is unkickable and uses the gray cast-bar rule")
	a.move_input = Vector2.RIGHT
	step(.2)
	ck(a.casting == 11 and a.position.x > .5, "Ground Lasso can cast while moving")
	a.move_input = Vector2.ZERO
	ck(reach_phase("rope"), "Successful cast launches a traveling rope")
	ck(b.stunned == 0 and a.identity.defense_detonation == 0, "Launch alone does not stun or reward a stack")
	ck(reach_phase("pull"), "Rope catches the target before pulling Outlaw")
	ck(b.stunned > 0 and b.dr_states.stun.count == 1, "Pull starts one diminishing-return stun")
	var start: Vector3 = a.position
	step(1.0/60)
	ck(a.position.distance_to(start) > .3 and a.position.distance_to(start) < 1, "Pull has fast visible travel rather than teleporting")
	ck(not game.try_spell(1,6,-1), "Other mobility cannot corrupt a committed pull")
	ck(reach_phase("rebound"), "Contact transitions directly into short rebound")
	ck(a.identity.defense_detonation == 1 and b.hp == 100, "Dropkick completion grants exactly one stack without unsolicited damage")
	ck(b.stunned > 1.4 and b.stunned <= 1.5 and b.dr_states.stun.count == 1, "Impact sets a 1.5-second knockdown without a second DR application")
	var impact: Vector3 = a.position
	var target_impact: Vector3 = b.position
	step(game.Outlaw.Lasso.REBOUND_TIME + 1.0/60)
	ck(not game.Outlaw.Lasso.busy(a) and b.stunned > 1.0, "Outlaw recovers much earlier than the target")
	ck(a.position.distance_to(impact) > 1.9 and b.position.distance_to(target_impact) > 2.5, "Short rebound and knockback create separation")
	ck(game.try_spell(1,6,-1), "Outlaw can immediately roll after the brief recovery")
	step(1.3)
	ck(b.stunned == 0 and not game.Outlaw.Lasso.knockdown_active(b), "Enemy recovers from knockdown")
	ck(a.identity.defense_detonation == 1, "Later ticks never grant extra stacks")

func air() -> void:
	await reset()
	ck(game.try_spell(1,3,-1), "Backflip launches before airborne Lasso")
	step(.25)
	ck(game.try_spell(1,11,2), "Lasso begins during Backflip")
	ck(game.Outlaw.Lasso.state(a).air, "Airborne Lasso remembers its landing cancellation rule")
	step(.5)
	ck(a.casting == 11 and a.velocity.y >= -1.5, "Airborne windup slows descent and retains the cast")
	ck(game.CC.apply(a,"stun",3,"enemy") == 0, "Existing Backflip airborne CC immunity is retained during windup")
	ck(reach_phase("rebound"), "Airborne Lasso reaches the target and finishes the dropkick")
	ck(a.identity.defense_detonation == 1 and not a.identity.backflip_active, "Air combo rewards one stack and closes the old Backflip window")
	await reset()
	game.try_spell(1,3,-1)
	a.position.y = .035; a.velocity.y = -5
	ck(game.try_spell(1,11,2), "Near-ground airborne Lasso can be attempted")
	step(.12)
	ck(a.casting == -1 and a.cooldowns[11] == 0 and a.identity.defense_detonation == 0, "Landing before cast completion cancels without cooldown or stack")
	ck(b.stunned == 0 and not game.Outlaw.Lasso.busy(a), "Cancelled airborne cast cannot launch or stun later")

func controls_and_terrain() -> void:
	await reset()
	a.identity.root = 1
	ck(not game.try_spell(1,11,2), "Root prevents Lasso mobility")
	a.identity.root = 0
	b.position.z = -19
	ck(not game.try_spell(1,11,2), "Lasso respects its 18-meter initial range")
	b.position.z = -8
	var cover := wall(Vector3(0,1.5,-4),Vector3(3,3,.4))
	await physics_frame
	ck(not game.try_spell(1,11,2), "Initial cover prevents Lasso")
	cover.queue_free(); await physics_frame
	game.try_spell(1,11,2)
	game.CC.apply(a,"stun",2,"test")
	step(.8)
	ck(a.casting == -1 and not game.Outlaw.Lasso.busy(a) and b.stunned == 0, "Hard CC cancels the ground windup despite kick immunity")
	await reset()
	b.position.z = -10
	game.try_spell(1,11,2); reach_phase("pull")
	cover = wall(Vector3(0,1.5,-4),Vector3(3,3,.4))
	await physics_frame
	step(.6)
	ck(not game.Outlaw.Lasso.busy(a) and a.position.z > -3.5, "A new wall safely stops the capsule during pull")
	ck(b.stunned == 0 and a.identity.defense_detonation == 0, "Blocked pull releases its own stun and grants no stack")
	cover.queue_free(); await physics_frame
	await reset()
	b.position.z = -10
	game.try_spell(1,11,2); reach_phase("pull")
	game.CC.apply(b,"stun",4,"Other stun")
	game.CC.apply(a,"stun",1,"Stop pull")
	step(1.0/60)
	ck(b.cc_effects.stun.source == "Other stun", "Cancelled pull never clears another ability's stun")
	await reset()
	b.position.z = -10
	game.CC.apply(b,"stun",1,"DR setup"); game.CC.clear(b,["stun"])
	game.try_spell(1,11,2); reach_phase("rebound")
	ck(b.stunned > .7 and b.stunned <= .75 and b.dr_states.stun.count == 2, "Second stun DR halves the entire combo's knockdown")
	await reset()
	b.position.z = -10
	game.try_spell(1,11,2); reach_phase("pull")
	game.CC.clear(b,["stun"])
	reach_phase("rebound")
	ck(b.stunned == 0 and not game.Outlaw.Lasso.knockdown_active(b), "Cleansing the travel stun prevents it being reapplied on impact")
	await reset()
	b.position.z = -10
	game.try_spell(1,11,2); reach_phase("pull")
	a.motion_revision += 1
	step(1.0/60)
	ck(not game.Outlaw.Lasso.busy(a) and b.stunned == 0, "External forced movement cancels pull and releases its travel stun")
	await reset()
	var packet: Dictionary = a.snapshot(); packet.cd.resize(11)
	a.receive(packet,true)
	ck(a.cooldowns.size() == a.kit.size() and a.cooldowns[11] > 0 and packet.cd.size() == 11, "An older server missing Lasso cannot crash the hotbar or imply a ready ability")
	await reset()
	game.world_mode = true
	ck(not game.try_spell(1,11,2), "World bystanders cannot be lassoed")

func airborne_momentum() -> void:
	for hz in [30,60]:
		await reset()
		game.try_spell(1,3,-1); step(.4)
		var normal: Vector3 = a.velocity
		ck(game.try_spell(1,11,2), "Airborne Lasso begins at %d Hz" % hz)
		ck(is_equal_approx(a.velocity.z,normal.z*.25) and a.velocity.y == normal.y, "Lasso slows backward momentum once and preserves upward velocity")
		var max_drift := 0.0
		for i in int(hz*.2):
			game.tick_actor(a,1.0/hz)
			max_drift=maxf(max_drift,absf(a.velocity.z))
		ck(is_equal_approx(max_drift,absf(normal.z)*.25), "Air drift stays slowed without compounding over time")
		game.cancel_own_cast(a,"")
		ck(is_equal_approx(a.velocity.z,normal.z) and is_equal_approx(a.velocity.y,normal.y-4), "Cancelled windup restores both axes with elapsed normal gravity at %d Hz" % hz)
		ck(a.identity.lasso.is_empty() and a.cooldowns[11]==0, "Cancelled momentum state clears without spending cooldown")
	await reset()
	game.try_spell(1,3,-1); step(.4)
	var original: Vector3 = a.velocity
	game.try_spell(1,11,2)
	b.position.z=-10
	ck(reach_phase("rope"), "Airborne cast launches the rope while suspended")
	var slow: Vector3 = a.velocity
	var position: Vector3 = a.position
	step(1.0/60)
	ck(game.Outlaw.Lasso.state(a).phase=="rope" and a.position.z>position.z and a.position.y<position.y, "Airborne caster continues backward drift and descent during rope flight")
	ck(is_equal_approx(a.velocity.z,original.z*.25) and a.velocity.y>=-1.5 and a.velocity.y<=slow.y, "Rope flight retains the same horizontal slowdown and fall cap")
	var saved: Vector3 = a.identity.lasso.resume_velocity
	b.hp=0
	step(1.0/60)
	ck(a.identity.lasso.is_empty() and a.velocity.is_equal_approx(saved), "Failed rope restores both stored momentum axes")
	ck(a.identity.defense_detonation==0, "Failed rope never awards a combo stack")
	await reset()
	game.try_spell(1,3,-1); step(.4)
	original=a.velocity
	game.try_spell(1,11,2)
	b.position=Vector3(100,0,0)
	step(.7)
	ck(a.identity.lasso.is_empty() and a.casting<0 and is_equal_approx(a.velocity.z,original.z), "Completion range failure immediately restores normal backward momentum")
	ck(a.velocity.y < -10 and a.cooldowns[11]==0, "Completion failure restores gravity without relaunching upward")
	await reset()
	game.try_spell(1,3,-1); step(.4)
	game.try_spell(1,11,2); step(.1)
	var packet: Dictionary=a.snapshot()
	var normal_saved: Vector3=a.identity.lasso.resume_velocity
	a.receive(bytes_to_var(var_to_bytes(packet)),true)
	game.cancel_own_cast(a,"")
	ck(a.velocity.is_equal_approx(normal_saved), "Momentum survives authoritative snapshot serialization")
	await reset()
	game.try_spell(1,3,-1); step(.4)
	game.try_spell(1,11,2)
	a.motion_revision+=1; a.velocity=Vector3(2,-3,1)
	game.cancel_own_cast(a,"")
	ck(a.velocity==Vector3(2,-3,1), "Cancellation preserves a newer forced movement instead of restoring stale momentum")
	await reset()
	game.try_spell(1,3,-1); step(.4)
	game.try_spell(1,11,2)
	var rear_wall := wall(a.position+Vector3(0,0,.5),Vector3(4,8,.1))
	await physics_frame
	step(.3)
	ck(absf(a.velocity.z)<.01, "Terrain stops the slowed backward drift")
	game.cancel_own_cast(a,"")
	ck(absf(a.velocity.z)<.01, "Cancelling does not restore momentum through a wall already hit")
	rear_wall.queue_free(); await physics_frame

func assert_air_immunity(label: String) -> void:
	ck(game.CC.airborne_immune(a), label+" retains airborne immunity")
	for category in game.CC.CATEGORIES:
		ck(game.CC.apply(a,category,3,"Enemy CC") == 0, label+" rejects "+category)
	ck(a.cc_effects.is_empty() and a.dr_states.is_empty(), label+" immune attempts add neither CC nor diminishing returns")
	var before: Vector3=a.position
	game.move_ability(a,Vector3.RIGHT*3)
	ck(a.position==before, label+" rejects forced displacement")
	ck(game.kick_immune(a), label+" cannot be kicked or school-locked")

func airborne_immunity() -> void:
	await reset()
	game.try_spell(1,3,-1); step(.4)
	game.try_spell(1,11,2)
	assert_air_immunity("Airborne windup")
	ck(game.try_spell(2,2,1) and a.casting==11 and a.locked==0, "An actual enemy kick cannot interrupt airborne Lasso or lock its school")
	ck(reach_phase("rope"),"Airborne immunity fixture reaches rope flight")
	assert_air_immunity("Rope flight")
	ck(reach_phase("pull"),"Airborne immunity fixture reaches pull")
	assert_air_immunity("Airborne pull")
	ck(reach_phase("rebound"),"Airborne immunity fixture reaches rebound")
	assert_air_immunity("Airborne rebound")
	step(1)
	ck(not game.CC.airborne_immune(a) and game.CC.apply(a,"stun",1,"Enemy CC")>0, "Immunity ends after recovery and landing")
	await reset()
	game.try_spell(1,11,2)
	ck(not game.CC.airborne_immune(a) and game.CC.apply(a,"stun",1,"Enemy CC")>0, "Grounded Lasso retains ordinary hard-CC vulnerability")
	await reset()
	game.try_spell(1,3,-1); a.position.y=.035; a.velocity.y=-5
	game.try_spell(1,11,2); step(.12)
	ck(not game.CC.airborne_immune(a) and a.casting<0, "Landing cancels airborne windup and removes immunity")

func ledges() -> void:
	for side in [-1.0,1.0]:
		for uphill in [false,true]:
			await reset()
			var lower:=Vector3(10*side,.025,0)
			var upper:=Vector3(14*side,1.225,0)
			a.position=lower if uphill else upper; b.position=upper if uphill else lower
			a.velocity=Vector3.ZERO; b.velocity=Vector3.ZERO
			a.look_at(Vector3(b.position.x,a.position.y,b.position.z))
			for i in 10: game.simulate_movement(a,1.0/60); game.simulate_movement(b,1.0/60)
			var label:="%s terrace %s" % ["Right" if side>0 else "Left","uphill" if uphill else "downhill"]
			ck(game.try_spell(1,11,2),label+" accepts a visible target at another height")
			var reached:=reach_phase("rebound")
			ck(reached,label+" clears the ledge and completes the dropkick")
			ck(a.identity.defense_detonation==1,label+" awards exactly one successful combo stack")
			ck(not a.test_move(a.transform,Vector3.ZERO,null,.001,true),label+" never finishes inside terrain")
			step(game.Outlaw.Lasso.REBOUND_TIME+.05)
			ck(not game.Outlaw.Lasso.busy(a),label+" releases control after recovery")
			var before: Vector3=a.position
			a.move_input=Vector2(0,1); step(.2)
			ck(a.position.distance_to(before)>.2,label+" can move away after recovery instead of sticking")
	await reset()
	a.position=Vector3(0,3,0); b.position=Vector3(0,.025,-.5)
	a.velocity=Vector3.ZERO; game.simulate_movement(a,1.0/60)
	a.identity.backflip_active=true; a.identity.backflip_combo=true
	ck(game.try_spell(1,11,2),"Airborne Lasso can target almost straight down")
	ck(reach_phase("rebound") and a.identity.defense_detonation==1,"Almost vertical descent completes one dropkick")
	ck(not a.test_move(a.transform,Vector3.ZERO,null,.001,true),"Downward pull keeps the capsule above the floor")
	await reset()
	a.position=Vector3(10,.025,0); b.position=Vector3(14,1.225,0)
	a.rotation.y=-PI/2; a.velocity=Vector3.ZERO; b.velocity=Vector3.ZERO
	for i in 10: game.simulate_movement(a,1.0/60); game.simulate_movement(b,1.0/60)
	var ceiling:=wall(Vector3(11.1,2.55,0),Vector3(1.8,.2,3))
	await physics_frame
	var blocked_start: Vector3=a.position
	ck(game.try_spell(1,11,2) and reach_phase("rope"),"Rope can see beneath a ceiling that blocks full-body clearance")
	step(.4)
	ck(not game.Outlaw.Lasso.busy(a) and a.identity.defense_detonation==0 and b.stunned==0,"Insufficient headroom safely cancels without a free stack or stuck target")
	ck(a.position.distance_to(blocked_start)<.01,"Blocked route leaves Outlaw at the safe departure position")
	ceiling.queue_free(); await physics_frame

func run() -> void:
	game = load("res://arena.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await basic()
	await air()
	await controls_and_terrain()
	await airborne_momentum()
	await airborne_immunity()
	await ledges()
	print("Outlaw lasso checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
