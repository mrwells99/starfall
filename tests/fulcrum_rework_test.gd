extends SceneTree
const Rules = preload("res://scripts/fulcrum_mechanics.gd")
var game
var a
var b
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func clean() -> void:
	a.position=Vector3(0,.001,7);b.position=Vector3(0,.001,4);a.rotation.y=0
	for actor in [a,b]:
		actor.hp=actor.MAX_HEALTH;actor.reset_identity();actor.casting=-1;actor.gcd=0;actor.cooldowns.fill(0);actor.stunned=0;actor.locked=0;actor.shield=0;actor.dr_states.clear();actor.cc_effects.clear();actor.move_input=Vector2.ZERO
		actor.velocity=Vector3.DOWN*4;actor.move_and_slide()
func step(seconds: float) -> void:
	for i in ceili(seconds/.01): game.ClassMechanics.tick(game,a,.01)
func run() -> void:
	game=load("res://scripts/arena.gd").new();root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false);game.mode=1;game.local_id=1
	game.roster={1:{"champion":"Fulcrum","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round();game.phase="match";a=game.actors[1];b=game.actors[2];a.owner_peer=1;b.owner_peer=2
	await physics_frame
	clean()
	for actor in [a,b]: actor.velocity=Vector3.DOWN;actor.move_and_slide()
	ck(a.kit.size()==16 and a.kit[14].kind=="trinket" and a.kit[15].kind=="gravity_flow","New kit retains Trinket and adds accessible Gravity Flow")
	for old in ["graviton","collapse","gravity_starfall","anchor","inward","outward"]:
		ck(a.kit.filter(func(spell): return spell.kind==old).is_empty(),"Retired ability removed: "+old)
	for i in [1,2,3,7,8,9]:
		ck(game.AbilityArt.texture_for(a.kit[i].name,"Fulcrum")!=null,"Anchor range variant has distinct art")
	ck(a.kit[1].range==3 and a.kit[2].range==8 and a.kit[3].range==15,"Both anchor families use exact selected distances")
	ck(a.kit[7].range==3 and a.kit[8].range==8 and a.kit[9].range==15,"Expansion range variants match Compression")
	ck(game.try_spell(1,1,2),"Compression casts without requiring an enemy selection")
	ck(is_equal_approx(b.hp,1368),"Compression deals 60% of 220 damage")
	ck(is_equal_approx(b.stunned,1.2) and b.identity.root==0,"Compression stuns for 60% of two-second root")
	ck(a.identity.meditation==20 and a.identity.anchor_left==3,"Compression grants resource and a three-second follow-up")
	ck(a.cooldowns[1]==12 and a.cooldowns[2]==12 and a.cooldowns[3]==12 and a.cooldowns[7]==0,"Range variants share only their polarity cooldown")
	ck(b.identity.gravity_motion.kind=="pull","Compression moves its victim into the anchor")
	var before: Vector3=b.position
	for i in 25: game.simulate_movement(b,.01)
	ck(b.position.distance_to(a.identity.anchor_pos)<.65 and b.identity.gravity_motion.is_empty(),"Compression pull finishes at the spike")
	ck(game.try_spell(1,11,1) and a.identity.anchor_left==0 and not a.identity.gravity_field.is_empty(),"Dark Growth consumes the lingering follow-up off GCD")
	ck(not game.try_spell(1,10,1),"A single anchor cannot also exchange after growing a field")
	step(.5);ck(a.identity.gravity_field.age>.49,"Black grass grows over time")
	step(6);ck(a.identity.gravity_field.is_empty(),"The slow field expires independently of anchor")
	clean();b.position.z=3.3
	ck(game.try_spell(1,7,2),"Expansion casts")
	ck(b.hp==1400 and b.velocity.z<0 and b.velocity.y>0,"Expansion launches outward with horizontal and upward momentum")
	before=b.position
	for i in 8: game.simulate_movement(b,1.0/60)
	ck(b.position.z<before.z-.8 and b.position.y>before.y,"Expansion uses physical travel instead of a position jump")
	clean();b.position.z=.3
	game.try_spell(1,7,2);ck(b.hp==1500,"Expansion rejects targets outside 3.6m")
	clean();game.try_spell(1,1,1);a.identity.anchor_left=.001;step(.02)
	ck(not game.try_spell(1,11,1) and not game.try_spell(1,10,1),"Both follow-ups reject expired anchors")
	clean();b.position=Vector3(10,.025,0);game.try_spell(1,1,1)
	var anchor: Vector3=a.identity.anchor_pos
	ck(game.try_spell(1,10,1) and a.position.distance_to(anchor)<.1,"Anchor Exchange uses anchor position without an ally")
	clean();a.move_input=Vector2.RIGHT
	ck(game.try_spell(1,13,2) and a.casting==-1,"First Entropy is instant while moving")
	game.ClassMechanics.tick(game,b,1)
	ck(a.identity.meditation==10 and b.hp==1480,"Entropy generation doubled to 10 per tick")
	a.gcd=0;ck(not game.try_spell(1,13,2),"Existing Entropy forces stationary casting")
	a.move_input=Vector2.ZERO;a.velocity=Vector3.DOWN;a.move_and_slide()
	ck(game.try_spell(1,13,2) and a.casting==13 and is_equal_approx(a.cast_left,.8),"Refreshing active Entropy hardcasts for 0.8s")
	var c=game.Fighter.new();c.setup(3,3,1,"Ember",false);game.add_child(c);c.position=Vector3(1,.025,4);game.actors[3]=c
	ck(Rules.cast_seconds(game,a,a.kit[13])==.8,"Entropy on another target also uses hardcast while one is active")
	a.casting=-1;game.resolve_spell(a,13,c);ck(c.identity.entropy_dots.has(1),"Hardcast Entropy can spread to a second target")
	var health: float=b.hp;Rules.cleanse_entropy(game,b,b)
	ck(b.identity.entropy_dots.is_empty() and is_equal_approx(health,b.hp),"Cleanse backlash no longer deals damage")
	ck(game.CC.remaining(b,"silence")==3,"Cleanser is silenced for three seconds")
	Rules.cleanse_entropy(game,b,b);ck(is_equal_approx(health,b.hp),"An empty cleanse cannot retrigger backlash")
	c.identity.entropy_dots.clear();game.actors.erase(3);c.queue_free()
	clean();game.resolve_spell(a,13,b);game.ClassMechanics.tick(game,b,20)
	ck(b.identity.entropy_dots.is_empty() and game.CC.remaining(b,"silence")==0,"Natural Entropy expiry never triggers cleanse punishment")
	clean();a.identity.meditation=32
	ck(not game.try_spell(1,0,1),"Ruin refuses less than 33 resource")
	a.identity.meditation=100;b.position=Vector3(0,.025,-2)
	ck(game.try_spell(1,0,1) and a.identity.meditation==67 and a.identity.ruin_combo==1,"Ruin right spends 33 and primes left")
	step(.3);ck(b.hp==1392,"Right slash damages its locked tab target once")
	a.gcd=0;ck(game.try_spell(1,0,1) and a.identity.meditation==34 and a.identity.divide_ready>0,"Left requires more than 66 and spends another 33")
	step(.3);ck(b.hp==1284 and a.cooldowns[0]==Rules.RUIN_COOLDOWN,"Left deals one separate hit and locks Ruin out for 8s")
	a.gcd=0;a.velocity=Vector3.DOWN;a.move_and_slide()
	ck(game.try_spell(1,0,1)==false,"Ruin cannot fire a third time during its lockout")
	ck(game.try_spell(1,12,2) and a.casting==12 and is_equal_approx(a.cast_left,.3),"Divide requires combo and has a 0.3s charge")
	a.casting=-1;game.resolve_spell(a,12,b);step(.31)
	ck(b.hp==1122 and a.identity.divide_ready==0 and a.identity.meditation==34,"Divide deals one hit, consumes unlock and costs no extra resource")
	ck(is_equal_approx(a.cooldowns[12],a.cooldowns[0]),"Divide clones Ruin's remaining lockout onto its own cooldown")
	step(.3);ck(b.hp==1122,"Lingering Divide does not hit the same target twice")
	ck(b.identity.gravity_slow>0 and not a.identity.gravity_rifts.is_empty(),"Divide leaves a 50% slowing rift")
	clean();a.identity.meditation=99;game.try_spell(1,0,1);step(.3);a.gcd=0
	ck(a.identity.meditation==66 and not game.try_spell(1,0,1),"Exactly 66 remaining cannot trigger left")
	step(6.1);ck(a.identity.ruin_combo==0,"Ruin combo resets when its window expires")
	clean();a.identity.meditation=100;a.gcd=1
	ck(game.try_spell(1,15,1) and a.identity.gravity_flow==8,"Gravity Flow is an off-GCD eight-second buff")
	ck(game.try_spell(1,0,1),"Flow permits Ruin during an existing GCD")
	step(.3);ck(game.try_spell(1,0,1),"Flow permits left without waiting for GCD")
	step(.3);b.hp=400
	ck(a.cooldowns[0]==Rules.RUIN_COOLDOWN,"Second flow slash still locks Ruin for 8s")
	var splash_target=game.Fighter.new();splash_target.setup(4,4,1,"Ember",false);game.add_child(splash_target);game.actors[4]=splash_target
	splash_target.position=b.position+Vector3(2,0,0)
	ck(game.try_spell(1,12,2) and a.casting==-1,"Flow removes Divide charge entirely")
	ck(is_equal_approx(a.cooldowns[12],a.cooldowns[0]),"Flow-charged Divide still clones Ruin's cooldown")
	step(.31)
	ck(is_equal_approx(b.hp,238),"Flow no longer executes below 30% health")
	ck(is_equal_approx(splash_target.hp,1419),"Flow-charged Divide instead splashes nearby enemies")
	game.actors.erase(4);splash_target.queue_free()
	clean();a.identity.gravity_flow=8;a.identity.meditation=100;a.casting=5;a.cast_left=1
	ck(not game.try_spell(1,0,1),"Off-GCD slashes still cannot bypass another cast")
	clean();a.identity.divide_ready=6;a.identity.gravity_flow=8;b.position=Vector3(0,.025,-6)
	game.try_spell(1,12,2);b.position=Vector3(8,.025,0);step(.35);b.position=Vector3(0,.025,-6);step(.05)
	ck(b.hp==1338,"An enemy entering the lingering Divide is hit once")
	step(.4);ck(b.hp==1338,"Later rift ticks only slow")
	clean();a.identity.meditation=100
	var bystander=game.Fighter.new();bystander.setup(5,5,1,"Ember",false);game.add_child(bystander);game.actors[5]=bystander
	bystander.position=Vector3(3,.025,3) # sits inside Ruin's old 150-degree, 10m cone
	ck(game.try_spell(1,0,1),"Ruin still fires with a bystander nearby")
	step(.3)
	ck(bystander.hp==bystander.MAX_HEALTH,"Ruin no longer strikes bystanders caught in its old cone")
	ck(b.hp<b.MAX_HEALTH,"Ruin still damages its locked tab target")
	game.actors.erase(5);bystander.queue_free()
	ck(Rules.in_divide(Vector3(1.5,0,-15),Vector3.ZERO,0),"Divide uses full 15m length and 3m width")
	ck(not Rules.in_divide(Vector3(0,0,-16),Vector3.ZERO,0),"Divide cannot exceed its range")
	ck(Rules.swing_progress(.25)<.1 and Rules.swing_progress(.75)-Rules.swing_progress(.5)>Rules.swing_progress(.25),"Sword timing accelerates from a slow start")
	a.casting=13;a.cast_duration=.8;a.cast_left=.6
	var serialized: Dictionary=a.snapshot();var replica=game.Fighter.new();replica.setup(9,9,0,"Fulcrum",false);game.add_child(replica);replica.receive(serialized)
	ck(replica.identity.gravity_rifts.size()==a.identity.gravity_rifts.size() and replica.identity.fulcrum_serial==a.identity.fulcrum_serial,"Slash and rift state replicate without client authority")
	ck(replica.cast_duration==a.cast_duration,"Dynamic cast duration replicates")
	await cover_cases()
	clean();a.identity.divide_ready=6
	ck(not game.validate_spell(a,12,-1).is_empty(),"Divide requires a selected enemy")
	b.position=Vector3(4,.025,0);game.selected_id=2;game.local_yaw=0;game.pivot.rotation.y=1.5
	game.send_action(12)
	ck(a.casting==12 and a.cast_target==2 and not game.fulcrum_aim.enabled,"Hotbar Divide charges directly on its tab target without aim mode")
	b.position.x=2;a.casting=-1;game.resolve_spell(a,12,b)
	ck(is_equal_approx(a.identity.divide_yaw,atan2(-2.0,-(b.position.z-a.position.z))),"Divide follows the selected target at release instead of camera aim")
	clean();game.resolve_spell(a,13,b);a.identity.meditation=98
	game.ClassMechanics.tick(game,b,30)
	ck(b.hp==1200 and a.identity.meditation==100 and b.identity.entropy_dots.is_empty(),"Entropy caps resource and only ticks fifteen times on a long frame")
	await mend_cases()
	replica.queue_free();game.queue_free();await process_frame
	report_results()
	quit(1 if failures else 0)

func report_results() -> void:
	print("Fulcrum rework checks: %d passed / %d total" % [checks-failures, checks])

func cover_cases() -> void:
	var body:=StaticBody3D.new();game.add_child(body);body.position=Vector3(50,2,50)
	var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(4.4,4,2.8);body.add_child(shape)
	await physics_frame
	ck(not Rules.cover_allows(game,Vector3(50,0,54),Vector3(50,0,46)),"Divide cannot traverse the full 2.8m face of a pillar")
	ck(Rules.cover_allows(game,Vector3(50,0,54),Vector3(56,0,48)),"Divide can cut a thin adjacent-face pillar corner")
	ck(not Rules.cover_allows(game,Vector3(50,0,50),Vector3(56,0,48)),"Divide cannot originate inside a pillar")
	shape.shape.size=Vector3(10,4,3.1)
	await physics_frame
	ck(not Rules.cover_allows(game,Vector3(50,0,54),Vector3(50,0,46)),"Cover over three meters stays blocked")
	shape.shape.size=Vector3(10,4,2)
	await physics_frame
	ck(Rules.cover_allows(game,Vector3(50,0,54),Vector3(50,0,46)),"A two-meter wall is within the penetration allowance")
	body.queue_free();await physics_frame

func mend_cases() -> void:
	for champion in game.Kits.NAMES:
		var actor=game.Fighter.new();actor.setup(40,40,0,champion,false);game.add_child(actor);game.actors[40]=actor
		game.elapsed=600;actor.hp=300
		actor.identity.dots[99]={"left":8.0,"tick":1.0};actor.identity.entropy_dots[99]={"left":15.0,"tick":1.0}
		var slot:=-1
		for i in actor.kit.size():
			if actor.kit[i].name=="Mend":slot=i
		if champion=="Null":ck(slot==-1,"Null retains its existing healing kit")
		else:
			game.resolve_spell(actor,slot,actor)
			ck(actor.hp==636,"Mend retains 336 late-match healing: "+champion)
			ck(actor.identity.entropy_dots.has(99)==(champion=="Luminary"),"Existing DPS cleanse eligibility: "+champion)
		game.actors.erase(40);actor.queue_free()
	await process_frame
