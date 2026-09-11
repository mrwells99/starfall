extends SceneTree
var game
var a
var b
var checks:=0
var failures:=0
var seq:=0
var results:Array=[]
class TestConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass
func _initialize() -> void: call_deferred("run")
func ck(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func reset(count:=3) -> void:
	game.world_mode=false; game.mode=1
	game.roster={1:{"champion":"Outlaw","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round(); game.phase="match"; game.application_focused=true
	a=game.actors[1]; b=game.actors[2]; a.owner_peer=1; b.owner_peer=2
	a.position=Vector3(0,20,0); b.position=Vector3(0,20,-6)
	a.rotation.y=0; b.rotation.y=PI; a.identity.defense_detonation=count
	seq=0; results.clear()
	for i in 18: step(1.0/60)
	await physics_frame
func step(delta: float) -> void:
	for actor in game.actors.values():
		actor.presentation_grounded=true
		actor.action_budget=maxf(0,actor.action_budget-delta)
		actor.gcd=maxf(0,actor.gcd-delta)
		actor.champion_model.animate(delta,actor)
	game.aimed_combat.tick(game,delta)
	game.outlaw_detonation.tick(game)
func origin() -> Vector3: return a.position+Vector3(.55,1.6,1.65)
func aim() -> Vector3: return (game.aimed_combat.firing_origin(b.body_hitboxes.points)-origin()).normalized()
func shot(index: int, direction: Vector3, burst:=1, at: Variant=null, revision: Variant=null, from: Variant=null, peer:=0) -> bool:
	seq+=1
	return game.outlaw_detonation.enqueue(game,1,peer,seq,burst,index,origin() if from==null else from,direction,game.aimed_combat.clock if at==null else at,a.motion_revision if revision==null else revision)
func obstacle(at: Vector3, size:=Vector3(3,4,.1)) -> StaticBody3D:
	var wall:=StaticBody3D.new(); var collider:=CollisionShape3D.new(); var box:=BoxShape3D.new()
	box.size=size; collider.shape=box; wall.add_child(collider); game.add_child(wall); wall.position=at
	return wall
func bursts() -> void:
	for count in [1,2,3]:
		await reset(count)
		var captured_origin:=origin()
		ck(shot(0,aim()),"Start aimed burst with %d stack(s)" % count)
		ck(a.identity.defense_detonation==0 and a.casting==-1 and a.gcd==game.GCD_DURATION,"Commit all stacks atomically without a cast/channel")
		game.outlaw_detonation.tick(game)
		for index in range(1,count):
			step(.13)
			ck(shot(index,aim()),"Next burst shot accepts fresh aim")
			game.outlaw_detonation.tick(game)
		ck(results.size()==count and b.hp==100-count*10,"Each aimed body hit deals ten percent maximum health")
		ck(results[0].from==captured_origin,"Damage ray originates at the submitted camera, not the gun or chest")
		ck(results.back().done and not game.outlaw_detonation.bursts.has(1),"Final shot finishes and cleans up the burst")
		for index in range(1,count): ck(absf(results[index].time-results[index-1].time-.13)<.00001,"Shots retain exactly 130ms separation at their scheduled deadlines")
		ck(not shot(count-1,aim()) and b.hp==100-count*10,"Replayed or excess shots cannot reuse consumed stacks")
	await reset()
	a.target_id=b.actor_id
	ck(shot(0,aim()),"Selected-target burst accepts its first aimed shot")
	game.outlaw_detonation.tick(game)
	a.identity.defense_detonation=1
	step(.13)
	# A level shoulder ray can clip an animated arm. Aim above the whole body
	# while staying within the valid shoulder-camera envelope.
	var miss_direction:=Vector3(0,.3,-1).normalized()
	var target_pose: Dictionary=game.aimed_combat.sample(b,game.aimed_combat.clock)
	var target_bounds: AABB=game.aimed_combat.Bodies.bounds_for(target_pose.points,b.body_hitboxes.radii)
	ck(target_bounds.intersects_segment(origin(),origin()+miss_direction*game.outlaw_detonation.RANGE)==null,"Miss fixture clears the target's entire sampled body bounds")
	ck(shot(1,miss_direction),"Burst accepts a fresh aim direction away from the selected target")
	game.outlaw_detonation.tick(game)
	step(.13)
	ck(shot(2,aim()),"Burst accepts aiming back at the selected target")
	game.outlaw_detonation.tick(game)
	ck(b.hp==80 and results[1].victim==-1,"Each shot uses its own aim; a crosshair miss is not redirected to the selected target")
	ck(a.identity.defense_detonation==1,"A new combo stack earned during the committed burst is preserved")
	await reset()
	shot(0,aim()); game.outlaw_detonation.tick(game)
	step(.11); ck(shot(1,aim()),"An early-arriving next shot can wait in a bounded queue")
	game.outlaw_detonation.tick(game); ck(results.size()==1,"Arrival jitter cannot shorten the 130ms interval")
	step(.02); ck(results.size()==2,"Queued shot resolves at its proper deadline")
	step(.13); shot(2,aim()); game.outlaw_detonation.tick(game)
	ck(results.size()==3,"The queued burst still completes")
func protections() -> void:
	await reset(1)
	b.position.x=.55; step(.016)
	var cover:=obstacle(Vector3(.2,21,-3),Vector3(.4,4,.1)); await physics_frame
	var chest: Vector3=game.aimed_combat.firing_origin(a.body_hitboxes.points)
	var target: Vector3=game.aimed_combat.firing_origin(b.body_hitboxes.points)
	ck(not game.Outlaw.raw_los(game,chest,target),"Fixture blocks a chest-to-target shot while the camera can see around it")
	shot(0,aim()); game.outlaw_detonation.tick(game)
	ck(b.hp==90,"The camera ray hits accurately instead of retargeting damage from the chest or gun")
	var pool_index: int=posmod(game.outlaw_fx.cursor-1,game.outlaw_fx.CAPACITY)
	ck(game.outlaw_fx.flashes[pool_index].position.distance_to(a.champion_model.outlaw_art.muzzle_position())<.001,"Cosmetic muzzle flash comes from the actual gun")
	ck(game.outlaw_fx.flashes[pool_index].position.distance_to(results[0].from)>.5,"Cosmetic muzzle position is separate from the damage-ray origin")
	cover.free(); await physics_frame
	await reset(0)
	ck(not shot(0,aim()) and b.hp==100,"Zero stacks cannot create a free shot")
	for state in ["cast","stun","roll","backflip","gcd","dead"]:
		await reset()
		if state=="cast": a.casting=0
		if state=="stun": a.stunned=1
		if state=="roll": a.identity.roll_left=.2
		if state=="backflip": a.identity.backflip_active=true
		if state=="gcd": a.gcd=.5
		if state=="dead": a.hp=0
		ck(not shot(0,aim()) and a.identity.defense_detonation==3,"Invalid start preserves stacks during "+state)
	await reset()
	var wall:=obstacle(Vector3(0,21,-3)); await physics_frame
	shot(0,aim()); game.outlaw_detonation.tick(game)
	ck(b.hp==100 and results[0].blocked and a.identity.defense_detonation==0,"Terrain blocks a camera-ray shot; misses still spend the committed burst")
	wall.free(); await physics_frame
	for mode in ["friendly","bystander","range"]:
		await reset(1)
		if mode=="friendly": b.team=a.team
		if mode=="bystander": game.world_mode=true
		if mode=="range": b.position.z=-25; step(.016)
		shot(0,aim()); game.outlaw_detonation.tick(game)
		ck(b.hp==100,"Burst respects "+mode+" protection")
	await reset(1)
	game.world_mode=true; game.actors.erase(b.actor_id)
	b.actor_id=-101; b.training_dummy=true; game.actors[b.actor_id]=b
	step(.016)
	ck(shot(0,aim()),"World training-dummy shot is accepted")
	game.outlaw_detonation.tick(game)
	ck(b.hp==90 and results.back().damage==10 and results.back().victim==-101 and a.identity.defense_detonation==0,"Negative world dummy IDs receive damage and consume the shot stack")
	await reset()
	shot(0,aim()); game.outlaw_detonation.tick(game); a.stunned=1; step(.13)
	ck(b.hp==90 and not game.outlaw_detonation.bursts.has(1),"Hard CC cancels unfinished shots without duplicating or refunding spent stacks")
	await reset()
	shot(0,aim()); game.outlaw_detonation.tick(game); step(1.26)
	ck(not game.outlaw_detonation.bursts.has(1),"Missing follow-up packets cannot retain an unbounded reservation")
func invalid_requests() -> void:
	await reset()
	for direction in [Vector3.ZERO,Vector3(INF,0,0),Vector3(NAN,0,0),Vector3.FORWARD*2]: ck(not shot(0,direction,seq+1),"Reject invalid direction before spending")
	ck(not shot(0,aim(),seq+1,null,null,origin()+Vector3.RIGHT*20),"Cannot forge a remote camera origin")
	ck(not shot(0,aim(),seq+1,game.aimed_combat.clock-.4),"Reject excessively stale aim")
	ck(not shot(0,aim(),seq+1,game.aimed_combat.clock+1),"Reject future aim")
	ck(not shot(0,aim(),seq+1,null,a.motion_revision+1),"Reject motion-revision mismatch")
	ck(not shot(0,aim(),seq+1,null,null,null,2),"Cannot fire on behalf of another player")
	ck(a.identity.defense_detonation==3 and a.last_action_seq==-1,"Invalid packets preserve resources and sequence")
	var wall:=obstacle(origin(),Vector3(1,2,1)); await physics_frame
	ck(not shot(0,aim(),seq+1),"Camera inside terrain cannot shoot out of it")
	wall.free(); await physics_frame
	await reset(1)
	var direction:=aim(); var stamp: float=game.aimed_combat.clock
	b.position.x+=2
	for i in 6: step(1.0/60)
	ck(shot(0,direction,1,stamp),"Valid bounded rewind accepts the displayed target's old pose")
	game.outlaw_detonation.tick(game)
	ck(b.hp==90 and b.position.x==2,"Rewind hits the historical hitbox without moving the live body")
	await reset()
	shot(0,aim()); game.clear_actors()
	ck(game.outlaw_detonation.bursts.is_empty(),"Round teardown discards queued bursts")
func run() -> void:
	game=load("res://arena.tscn").instantiate(); game.config=TestConfig.new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.aimed_shot_resolved.connect(func(result): results.append(result))
	await bursts(); await protections(); await invalid_requests()
	game.queue_free(); await process_frame
	print("Outlaw detonation checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
