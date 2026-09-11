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
	step(.3)
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

func run() -> void:
	game = load("res://arena.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	await basic()
	await air()
	await controls_and_terrain()
	print("Outlaw lasso checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
