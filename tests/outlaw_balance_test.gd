extends "res://tests/outlaw_abilities_test.gd"

func balance() -> void:
	await reset()
	var obstacle := wall(Vector3(.572,1,0),Vector3(.3,2,4)); await physics_frame
	a.move_input = Vector2.RIGHT
	var start: Vector3 = a.position
	ck(game.try_spell(1,6,-1),"Roll can be activated flush against a wall")
	tick(a,.02)
	ck(a.position.distance_to(start)<.01 and a.identity.roll_left==0,"Wall stops Roll without requiring displacement")
	ck(a.identity.instant_severe>1.49 and a.identity.roll_haste>4.99,"Zero-distance Roll grants instant Severe and 5s haste")
	var haste: float=a.identity.roll_haste
	game.simulate_movement(a,.1)
	ck(a.identity.roll_haste==haste,"Completed Roll cannot repeatedly refresh buffs")
	obstacle.free(); await physics_frame
	a.move_input=Vector2.UP; tick(a,.1)
	ck(is_equal_approx(-a.velocity.z,6.5*1.25),"Roll haste increases running speed by exactly 25 percent")
	a.walking=true; tick(a,.1)
	ck(is_equal_approx(-a.velocity.z,6.5*.5*1.25),"Roll haste increases voluntary walking speed by 25 percent")
	game.Outlaw.tick(game,a,5)
	ck(a.identity.roll_haste==0,"Roll haste expires after its five-second window")
	await reset()
	a.identity.instant_severe=1.5; b.hp=73
	ck(game.try_spell(1,1,2) and b.hp==58,"Severe deals rounded 20 percent current health")
	ck(b.identity.severe_slow==6 and b.identity.severe_bleeds[1].left==5,"Severe slow and bleed have independent six/five-second durations")
	b.move_input=Vector2.UP; tick(b,.1)
	ck(is_equal_approx(Vector2(b.velocity.x,b.velocity.z).length(),6.5*.4),"Severe reduces running speed by exactly 60 percent without double-applying walking")
	b.identity.slow=2; tick(b,.1)
	ck(is_equal_approx(Vector2(b.velocity.x,b.velocity.z).length(),6.5*.4),"The strongest slow applies instead of multiplying two slows")
	b.identity.immune=1; tick(b,.1)
	ck(is_equal_approx(Vector2(b.velocity.x,b.velocity.z).length(),6.5),"Root/slow immunity suppresses Severe's slow")
	b.identity.immune=0; game.Outlaw.tick(game,b,6)
	ck(b.identity.severe_slow==0,"Severe's movement slow expires")
	await reset()
	game.try_spell(1,3,-1)
	game.damage(b,a,20)
	ck(a.hp==90,"Airborne Backflip reduces incoming damage by 50 percent from launch")
	a.shield=1; game.damage(b,a,20)
	ck(a.hp==82,"A stronger shield remains stronger without multiplying defenses")
	a.shield=0; a.identity.backflip_active=false; game.damage(b,a,20)
	ck(a.hp==62,"Backflip damage reduction ends with Backflip")
	await reset()
	b.casting=0; b.cast_left=1.5; a.gcd=1
	ck(game.try_spell(1,12,2) and b.casting==-1 and b.locked==4,"Boot Kick interrupts in melee range, off GCD, with a four-second lockout")
	ck(a.cooldowns[12]==12 and a.gcd==1,"Boot Kick uses its own twelve-second cooldown")
	await reset(); b.position.z=-3.2; b.casting=0
	ck(not game.try_spell(1,12,2) and b.casting==0 and a.cooldowns[12]==0,"Boot Kick cannot reach outside three metres")
	await reset(); b.kit[0]=a.kit[0].duplicate(); b.champion="Outlaw"; b.casting=0
	ck(game.try_spell(1,12,2) and b.casting==0 and b.locked==0,"Boot Kick respects unkickable casts")

func trinkets() -> void:
	for title in game.Kits.NAMES:
		game.roster={1:{"champion":title,"team":0},2:{"champion":"Ember","team":1}}
		game.begin_round(); game.phase="match"; a=game.actors[1]; b=game.actors[2]
		a.owner_peer=1; b.owner_peer=2
		ck(a.kit.size()==15 and a.kit[14].kind=="trinket" and a.cooldowns.size()==15,title+" has a shared trinket without shifting old abilities")
		ck(not game.try_spell(1,14,-1) and a.cooldowns[14]==0,"Trinket cannot be wasted outside a stun")
		game.CC.apply(a,"stun",4,"Bash"); game.CC.apply(a,"root",3,"Root")
		a.locked=2; a.gcd=1; a.identity.severe_slow=4
		ck(game.cc_block_remaining(a,a.kit[14])==0 and game.ability_block_reason(a,14,-1).is_empty(),title+" trinket remains available during stun and lockout")
		ck(game.try_spell(1,14,-1) and a.stunned==0 and not a.cc_effects.has("stun"),title+" can break a stun instantly")
		ck(a.cooldowns[14]==120 and a.gcd==1 and a.locked==2 and a.identity.root>0 and a.identity.severe_slow==4,"Trinket changes only stun and its own cooldown")
		ck(a.dr_states.stun.count==1 and a.dr_states.stun.remaining==game.CC.RESET,"Trinket preserves stun diminishing returns")
		game.CC.apply(a,"stun",4,"Second stun")
		ck(not game.try_spell(1,14,-1) and a.stunned>0,"Trinket cannot break another stun before cooldown")
		a.cooldowns[14]=.5; a.input_age=0; game.tick_actor(a,.5)
		ck(game.try_spell(1,14,-1),"Trinket becomes usable when its cooldown expires")
	await reset(); game.CC.apply(a,"incapacitate",3,"Solar Flare")
	ck(not game.try_spell(1,14,-1),"Stun trinket does not silently become a break for other CC categories")
	game.CC.apply(a,"stun",2,"Bash"); game.try_spell(1,14,-1)
	ck(a.stunned>0 and a.cc_effects.has("incapacitate"),"Removing a stun preserves overlapping incapacitate")
	a.hp=0; a.cooldowns[14]=0; game.CC.apply(a,"stun",2,"Bash")
	ck(not game.try_spell(1,14,-1),"Defeated characters cannot use Trinket")

func pillars() -> void:
	await reset()
	for center in game.Layout.cover_centers():
		for normal in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			var extent: float = game.Layout.COVER_BASE_SIZE.x*.5 if normal.x!=0 else game.Layout.COVER_BASE_SIZE.z*.5
			for height in [.2,.5,1.5,3.7,6.0]:
				var from: Vector3 = center+normal*4+Vector3.UP*height
				var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,center+Vector3.UP*height,1))
				ck(not hit.is_empty() and is_equal_approx(from.distance_to(hit.position),4-extent),"Pillar has one flush face from its base to its invisible extension")
			var tangent: Vector3 = Vector3(normal.z,0,-normal.x)
			var along: float = game.Layout.COVER_BASE_SIZE.z*.5 if normal.x!=0 else game.Layout.COVER_BASE_SIZE.x*.5
			a.position=center+normal*(extent+.425)-tangent*(along+.8)+Vector3.UP*.025
			a.velocity=Vector3.ZERO; a.rotation.y=0
			var direction: Vector3 = (tangent-normal*.15).normalized()
			a.move_input=Vector2(direction.x,direction.z)
			var start: Vector3=a.position
			var speed := 3.8 if direction.z>0 else 6.5
			tick(a,(along*2+1.6)/speed+.2)
			ck((a.position-start).dot(tangent)>along*2+1.1,"Normal movement slides along each pillar face and clears its corners")
			a.move_input=Vector2(normal.x,normal.z); start=a.position; tick(a,.1)
			ck(a.position.distance_to(start)>.35,"Character can move away freely after passing a pillar base")

func run() -> void:
	game=load("res://tests/ui_test_arena.gd").new(); root.add_child(game)
	await process_frame; game.set_process(false); game.set_physics_process(false)
	await balance(); await trinkets(); await pillars()
	game.clear_actors(); game.queue_free(); await process_frame
	print("Outlaw balance checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
