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
	game.mode = 1
	game.roster = {1:{"champion":"Ember","team":0},2:{"champion":"Vanguard","team":1}}
	game.begin_round(); game.phase="match"
	a=game.actors[1];b=game.actors[2]
	a.owner_peer=1;b.owner_peer=2
	a.position=Vector3(0,.025,0);b.position=Vector3(0,.025,-4)
	a.rotation.y=0
	for i in 3:
		a.velocity=Vector3.DOWN;a.move_and_slide();await physics_frame

func run() -> void:
	game=load("res://arena.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false);game.set_process(false)
	await reset()
	ck(a.kit[4].name=="Fire Barrier" and a.kit[12].kind=="ash" and a.kit[14].kind=="trinket","Stable slots: Fire Barrier 4, Ash 12, Trinket 14")
	ck(game.try_spell(1,11,-1),"Burning Wake casts")
	var center:Vector3=a.identity.wake_pos
	b.position=center
	game.ClassMechanics.tick(game,a,.01)
	ck(b.hp==b.MAX_HEALTH and b.identity.slow==0,"Ring center is safe from both damage and slow")
	for sample in [[2.99,false],[3.0,true],[4.0,true],[5.0,true],[5.01,false]]:
		b.hp=b.MAX_HEALTH;b.identity.slow=0;b.position=center+Vector3.RIGHT*sample[0];a.identity.wake_tick=0
		game.ClassMechanics.tick(game,a,.01)
		ck((b.hp==b.MAX_HEALTH-60)==sample[1],"Ring damage boundary "+str(sample[0]))
		ck((b.identity.slow>0)==sample[1],"Ring slow boundary "+str(sample[0]))
	await reset()
	a.identity.heat=40
	var start:Vector3=a.position
	ck(game.try_spell(1,9,-1),"Cinderstep casts with Heat")
	ck(a.position.is_equal_approx(start) and a.identity.heat==20,"Cinderstep spends Heat without teleporting")
	a.move_input=Vector2.UP
	game.simulate_movement(a,1.0/60.0,true)
	ck(is_equal_approx(Vector2(a.velocity.x,a.velocity.z).length(),game.MovementTuning.FORWARD_SPEED*1.8),"Cinderstep gives exactly +80% forward speed")
	a.move_input=Vector2.RIGHT
	game.simulate_movement(a,1.0/60.0,true)
	ck(a.velocity.x>0 and absf(a.velocity.z)<.01,"Cinderstep remains steerable")
	a.position=start+Vector3.RIGHT*2
	game.ClassMechanics.tick(game,a,.1)
	b.position=start+Vector3.RIGHT
	game.ClassMechanics.tick(game,a,1.0)
	ck(b.hp==b.MAX_HEALTH-40 and b.identity.slow>0,"Trail deals original 40 damage and slows along traversed path")
	ck(game.Ember.in_trail(start+Vector3.RIGHT+Vector3.FORWARD*1.49,a.identity.cinder_trail),"Trail retains 1.5m half-width")
	ck(not game.Ember.in_trail(start+Vector3.RIGHT+Vector3.FORWARD*1.51,a.identity.cinder_trail),"Trail does not damage outside its width")
	game.ClassMechanics.tick(game,a,3.0)
	ck(a.identity.cinder_left==0 and not a.identity.cinder_trail.is_empty(),"Skating ends while recent trail remains")
	game.ClassMechanics.tick(game,a,6.0)
	ck(a.identity.cinder_trail.is_empty(),"Expired trail cleans up")
	await reset()
	ck(game.try_spell(1,4,-1),"Fire Barrier casts")
	game.damage(b,a,10)
	ck(a.hp==a.MAX_HEALTH-40 and a.shield==5 and a.cooldowns[4]==22,"Fire Barrier preserves Ward's 60% reduction, 5s duration, 22s cooldown")
	await reset()
	ck(game.try_spell(1,12,-1),"Ash casts")
	ck(game.Ember.spirit(a) and a.identity.ash_left==6 and a.cooldowns[12]==90,"Ash starts six-second invulnerability")
	game.damage(b,a,100);game.damage(b,a,100,true)
	ck(a.hp==a.MAX_HEALTH,"Ash blocks direct and periodic damage")
	ck(game.CC.apply(a,"stun",3,"test")==0 and game.CC.apply(a,"root",3,"test")==0,"Ash blocks control")
	ck(not game.Null.targetable(game,b,a) and game.Null.targetable(game,a,a),"Enemy cannot target spirit; owner can")
	ck(not game.try_spell(1,1,b.actor_id) and not game.try_spell(1,6,-1),"Ash blocks attacks and other movement abilities")
	a.move_input=Vector2.UP
	game.simulate_movement(a,1.0/60.0,true)
	ck(is_equal_approx(-a.velocity.z,game.MovementTuning.FORWARD_SPEED*1.5),"Ash gives exactly +50% movement speed")
	var original:Vector3=a.identity.ash_origin
	a.position=original+Vector3.RIGHT*2;game.Ember.tick(game,a,.1)
	a.position+=Vector3.FORWARD*3;game.Ember.tick(game,a,.1)
	var state:Dictionary=a.snapshot()
	var hidden:Array=game.Ember.snapshot_for([state,b.snapshot()],b.actor_id)
	ck(hidden[0].pos==original and hidden[0].velocity==Vector3.ZERO,"Enemy snapshot masks real spirit position and velocity")
	ck(not hidden[0].identity.has("ash_return") and not state.identity.has("ember_route"),"Live route stays authority-only")
	ck(game.Ember.snapshot_for([state,b.snapshot()],a.actor_id)[0].pos==a.position,"Owner receives real authoritative movement")
	ck(game.request_spell(1,12,-1),"Pressing Ash again ends it despite cooldown")
	ck(a.identity.ash_phase==2 and a.identity.ash_return.size()>=3,"Recall retains actual cornered path")
	var destination:Vector3=a.position
	game.simulate_movement(a,.1,true)
	ck(a.position==destination and a.velocity==Vector3.ZERO,"Reconstruction freezes at chosen destination")
	game.damage(b,a,10)
	ck(a.hp==a.MAX_HEALTH-100,"Invulnerability ends when spirit ends")
	game.Ember.tick(game,a,.66)
	ck(not game.Ember.busy(a) and not a.identity.has("ash_return"),"Reformation finishes and clears route")
	ck(game.Null.targetable(game,b,a),"Reformed Ember is targetable again")
	await reset()
	game.try_spell(1,12,-1);game.Ember.tick(game,a,6.0)
	ck(a.identity.ash_phase==2,"Ash recalls automatically at six seconds")
	a.hp=0;game.ClassMechanics.tick(game,a,.01)
	ck(not game.Ember.busy(a) and a.ember_route.is_empty(),"Death clears Ash and route")
	await reset()
	var fx=a.get_node("EmberEffects")
	a.identity.wake=2;a.identity.wake_pos=a.position;a.identity.wake_serial=1
	fx._process(.08)
	ck(fx.ring.intensity>0 and fx.ring.intensity<1,"Flames fade in locally")
	a.identity.wake=0;fx._process(.04)
	ck(fx.ring.intensity>0,"Flames fade out instead of popping")
	fx.event("kindle",a.position,b.position);fx._process(.05)
	var first: float=fx.transients[0].age
	fx._process(.05)
	ck(fx.transients[0].age>first and fx.transients[0].batch.material.get_shader_parameter("effect_time")>0,"Fireball advances between snapshots")
	game.try_spell(1,12,-1);fx._process(.05)
	game.local_id=2;fx._process(.05)
	ck(not a.champion_model.ember_art.model.visible and not fx.spirit_aura.visible,"Enemy sees no spirit model or aura")
	game.local_id=1;fx._process(.05)
	ck(a.champion_model.ember_art.model.visible,"Owner can see translucent spirit")
	a.reset_identity();fx._process(.4)
	ck(not fx.statue.visible and a.champion_model.ember_art.model.visible,"Reset restores body and clears statue")
	# Wire round-trip keeps zero yaw and bounded, quantized gameplay history.
	a.reset_identity()
	a.identity.cinder_trail=[]
	for i in 96: a.identity.cinder_trail.append({"position":Vector3(i*.3,.025,sin(i*.1)*3),"left":4.99-i*.035})
	var encoded:Dictionary=a.snapshot()
	var restored=load("res://scripts/combatant.gd").new()
	root.add_child(restored);restored.setup(9,9,0,"Ember",false)
	restored.receive(encoded,true)
	ck(restored.identity.cinder_trail.size()==96,"Compact snapshot retains the entire trail")
	ck(Vector3(restored.identity.cinder_trail[10].position).distance_to(a.identity.cinder_trail[10].position)<.01,"Trail wire quantization is under one centimeter")
	var large:Array=[]
	for i in 6:
		var item:Dictionary=encoded.duplicate(true);item.id=i+1;item.team=i%2;large.append(item)
	var raw:=var_to_bytes(large)
	ck(raw.size()<65536,"Six maximum trails fit the snapshot decoder limit")
	print("Six maximum-trail snapshot: ",raw.size()," bytes raw / ",raw.compress(FileAccess.COMPRESSION_DEFLATE).size()," bytes compressed (identical-path stress fixture)")
	restored.free()
	ck(fx.trail.capacity>=96*3,"Flame pool covers the complete trail at full quality")
	ck(fx.ring.global_transform==Transform3D.IDENTITY,"World-space effects do not inherit the actor spawn offset")
	print("Ember particle abilities: %d passed / %d total" % [checks-failures,checks])
	game.queue_free();await process_frame
	quit(1 if failures else 0)
