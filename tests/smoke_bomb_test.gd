extends "res://tests/aimed_combat_test.gd"
const Smoke = preload("res://scripts/smoke_bomb.gd")
var owner

func reset_smoke() -> void:
	await reset()
	owner=load("res://scripts/combatant.gd").new();game.add_child(owner)
	owner.setup(3,3,1,"Null",false);owner.position=Vector3(0,20,0);game.actors[3]=owner
	Smoke.cast(owner)
	owner.position.x=20 # Cloud remains fixed; keep its owner's body out of test rays.
	a.kit[0]=game.Kits.spell("Smoke test","damage",10,24,0,7,true)

func membership_and_casts() -> void:
	await reset_smoke()
	check(owner.kit[10].kind=="smoke_bomb" and owner.kit[10].cd==30 and owner.kit[14].kind=="trinket","New slot10 preserves Chronoshift and Trinket indices")
	check(Smoke.RADIUS<6 and Smoke.DURATION==6,"Smoke is smaller than Collapse")
	for test in [[0,-2,false],[0,-6,true],[6,0,true],[6,-6,false],[Smoke.RADIUS,-Smoke.RADIUS,false],[Smoke.RADIUS+.001,0,true]]:
		a.position=Vector3(test[0],20,0);b.position=Vector3(test[1],20,0)
		check(Smoke.separates(game,a,b)==test[2] and not Smoke.separates(game,b,a),"Hostile membership blocks only enemy casters "+str(test))
	a.position=Vector3(0,20,0);b.position=Vector3(0,20,-6)
	a.target_id=2;game.selected_id=2
	check(not game.try_spell(1,0,2) and a.cooldowns[0]==0 and a.gcd==0 and b.hp==b.MAX_HEALTH,"Cross-boundary cast rejected without cost")
	check(a.target_id==2 and game.selected_id==2 and game.spell_target(a,0,2)==2,"Smoke leaves selection intact")
	check(game.has_los(a,b),"No terrain collider or ray LOS change")
	check(game.validate_spell(a,0,2)=="Smoke Bomb blocks this target","Clear smoke-specific rejection")
	a.position.z=6
	check(game.try_spell(1,0,2) and b.hp==b.MAX_HEALTH-100,"Both outside can cast through the entire cloud")
	a.cooldowns[0]=0;a.position.z=0;b.position.z=-2
	check(game.try_spell(1,0,2) and b.hp==b.MAX_HEALTH-200,"Both inside can attack")
	b.position.z=-6;b.team=a.team
	a.kit[0]=game.Kits.spell("Heal test","heal",10,24,0,7)
	check(game.validate_spell(a,0,2)=="Smoke Bomb blocks this target","Friendly healing cannot cross boundary")
	var hp:float=b.hp;game.ClassMechanics.heal(game,a,b,10)
	check(b.hp==hp,"Secondary healing uses same boundary")
	check(not Smoke.separates(game,a,a),"Self effects remain legal")
	a.position=Vector3(0,26,0);b.position=Vector3(0,20,0)
	check(Smoke.separates(game,a,b),"Cloud is finite-height, not an infinite pillar")
	var second=load("res://scripts/combatant.gd").new();game.add_child(second);second.setup(4,4,1,"Null",false);game.actors[4]=second
	second.position=Vector3(Smoke.RADIUS,20,0);Smoke.cast(second)
	a.position=Vector3(-2,20,0);b.position=Vector3(2,20,0)
	check(Smoke.separates(game,a,b),"Overlaps require matching membership in each individual cloud")
	second.identity.smoke_bomb={}
	check(not Smoke.separates(game,a,b),"Removing only separating cloud restores interaction")

func fields_and_lifetime() -> void:
	await reset_smoke()
	a.position=Vector3(0,20,0);b.position=Vector3(0,20,-6)
	check(game.ClassMechanics.enemies(game,a,b.position,6,false).is_empty(),"No-LOS area spells still respect caster membership")
	game.ClassMechanics.control(game,a,b,4,"Smoke control")
	check(b.stunned==0 and b.identity.combat_left==0,"Blocked CC neither stuns nor flags combat")
	a.identity.wake=3;a.identity.wake_tick=0;a.identity.wake_pos=b.position;a.identity.wake_end=b.position
	game.ClassMechanics.tick(game,a,.1)
	check(b.hp==b.MAX_HEALTH and b.identity.slow==0,"Burning Wake applies neither ticks nor slows across smoke")
	b.identity.dots[1]={"left":3.0,"tick":.1,"stacks":1}
	game.ClassMechanics.tick_dots(game,b,b.identity.dots,.2,3.0,0.0)
	check(b.hp==b.MAX_HEALTH-30 and not b.identity.dots.is_empty(),"Already attached DoTs continue; smoke does not cleanse")
	a.kit[0]=game.Kits.spell("Cast test","starshot",10,24,.2,7)
	b.position.z=-2
	check(game.try_spell(1,0,2) and a.casting==0,"Valid cast can begin inside")
	b.position.z=-6
	var hp:float=b.hp
	game.tick_actor(a,.25)
	check(a.casting==-1 and b.hp==hp and a.cooldowns[0]==0,"Cast completion rechecks changed membership before applying effects")
	owner.identity.smoke_bomb={};owner.position=Vector3(1,20,1)
	var pos:Vector3=owner.position;var vel:Vector3=owner.velocity
	check(game.try_spell(3,10,-1),"Actual Smoke Bomb slot casts without a target")
	check(owner.cooldowns[10]==30 and owner.identity.smoke_bomb.left==6 and owner.identity.smoke_bomb.position==pos,"Actual cast starts cloud and cooldown")
	check(owner.position==pos and owner.velocity==vel and owner.gcd==0,"Smoke does not change movement or spend the GCD")
	var receiver=load("res://scripts/combatant.gd").new();game.add_child(receiver);receiver.setup(9,9,0,"Null",false)
	receiver.receive(owner.snapshot(),true)
	check(receiver.identity.smoke_bomb==owner.identity.smoke_bomb,"Cloud position and lifetime replicate through existing snapshots")
	receiver.identity.smoke_bomb.left=1
	check(owner.identity.smoke_bomb.left==6,"Replica owns a deep copy of smoke state")
	receiver.free()
	owner.position.x+=2
	check(owner.identity.smoke_bomb.position==pos,"Cloud stays at cast position when owner moves")
	owner.identity.essence=120;owner.identity.chronoshift_select=true
	check(game.Null.select_chronoshift(game,owner,10).is_empty() and owner.cooldowns[10]==0 and owner.identity.chronoshift_locks[10]==60,"Smoke is refreshable using normal Chronoshift rules")
	check(game.try_spell(3,10,-1) and owner.identity.smoke_bomb.position==owner.position,"Refreshed recast replaces old cloud at new position")
	Smoke.tick(owner,5.9);check(not owner.identity.smoke_bomb.is_empty(),"Cloud persists during duration")
	Smoke.tick(owner,.2);check(owner.identity.smoke_bomb.is_empty(),"Cloud expires without permanent barrier")
	Smoke.cast(owner);owner.hp=0
	check(not Smoke.separates(game,a,b),"Dead owner immediately stops blocking before cleanup tick")
	game.ClassMechanics.tick(game,owner,.1)
	check(owner.identity.smoke_bomb.is_empty(),"Death cleanup clears cloud")
	owner.hp=owner.MAX_HEALTH;Smoke.cast(owner);owner.reset_identity()
	check(owner.identity.smoke_bomb.is_empty(),"Round/duel identity reset removes smoke")

func aimed_hits() -> void:
	await reset_smoke()
	a.kit[0]=profile()
	for i in 18:step()
	b.identity.stealth=true
	check(shoot(direction()) and b.hp==b.MAX_HEALTH and results.back().damage==0,"Aimed body hit across boundary produces no damage")
	check(b.identity.stealth and b.identity.combat_left==0,"Blocked aimed hit cannot reveal victim or flag them in combat")
	check(a.cooldowns[0]==4,"A free-aim miss still spends its ordinary shot cooldown")
	a.cooldowns[0]=0;a.gcd=0;a.action_budget=0;a.position.z=6
	for i in 18:step()
	check(shoot(direction()) and b.hp==b.MAX_HEALTH-120,"Both outside aimed ray may cross cloud and hit normally")
	# Exercise the same final server burst path with a validated synthetic queued ray.
	a.position.z=0;b.identity.stealth=true;b.identity.combat_left=0
	for i in 18:step()
	var origin:Vector3=game.aimed_combat.firing_origin(a.body_hitboxes.points)
	var clock:float=game.aimed_combat.clock
	game.outlaw_detonation.bursts[1]={"id":99,"total":1,"next":1,"fired":0,"start":clock,"last_fire":clock-1,"revision":a.motion_revision,"epoch":game.epoch,"peer":0,"pending":[{"index":0,"seq":99,"origin":origin,"direction":direction(),"stamp":clock}]}
	var hp:float=b.hp
	game.outlaw_detonation.tick(game)
	check(b.hp==hp and b.identity.stealth and b.identity.combat_left==0,"Defense Detonation shares the boundary without revealing blocked targets")
	check(game.outlaw_detonation.bursts.is_empty(),"Blocked burst resolves as a miss, not a stuck shot")

func visuals() -> void:
	await reset_smoke()
	var effect=load("res://scripts/smoke_bomb_effect.gd").new();owner.add_child(effect)
	effect.sync(owner.identity.smoke_bomb,true,false);effect._process(.5)
	check(effect.visible and effect.puffs.visible and effect.puffs.multimesh.instance_count==36,"Retained client smoke batch renders")
	check(effect.find_children("*","CollisionObject3D",true,false).is_empty(),"Smoke visual has no physics collider")
	effect.sync(owner.identity.smoke_bomb,true,true)
	check(effect.visible and effect.ring.visible and not effect.puffs.visible,"Reduced effects retains exact boundary ring")
	effect.sync({},true,false);check(not effect.visible and not effect.is_processing(),"Expired effect hides and stops processing")
	effect.free()
	game.dedicated=true;game.ClassMechanics.paint(game)
	check(owner.get_node_or_null("SmokeBombEffect")==null,"Dedicated paint allocates no smoke visual")
	game.dedicated=false

func special_paths() -> void:
	await reset_smoke()
	for kind in ["trickshot","inward","outward","pull"]:
		a.kit[0]=game.Kits.spell("Boundary test",kind,0,24,0,1)
		check(game.validate_spell(a,0,2)=="Smoke Bomb blocks this target","Physical-LOS exception cannot bypass smoke: "+kind)
	game.Outlaw.Lasso.release(game,a,b)
	game.Outlaw.Lasso.motion(game,a,.25)
	check(game.Outlaw.Lasso.state(a).is_empty() and b.stunned==0,"Lasso cannot latch across boundary")
	a.casting=9;a.cast_left=.01
	a.identity.outlaw_channel={"marked":[2],"completed":false}
	game.Outlaw.tick_channel(game,a,.02)
	check(b.hp==b.MAX_HEALTH,"Deadeye completion filters smoke-separated targets")
	owner.identity.smoke_bomb.position=Vector3(-(Smoke.RADIUS-.2),20,0)
	a.position=Vector3(0,20,0);b.position=Vector3(1,20,0)
	a.identity.null_vantage={"phase":"dive","elapsed":0.0,"target":2,"power":22,"direction":Vector3.RIGHT}
	game.Null.motion(game,a,0)
	check(a.identity.null_vantage.phase=="recover" and b.hp==b.MAX_HEALTH and b.stunned==0,"Vantage contact recovers without damage or stun across boundary")

func run() -> void:
	game=load("res://arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.aimed_shot_resolved.connect(func(result):results.append(result))
	await membership_and_casts();await fields_and_lifetime();await aimed_hits();await special_paths();await visuals()
	print("Smoke Bomb checks: %d passed / %d total"%[checks-failures,checks]);quit(1 if failures else 0)
