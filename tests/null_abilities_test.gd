extends SceneTree
var game
var a
var b
var checks:=0
var failures:=0
func ck(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func reset() -> void:
	game.world_mode=false;game.mode=1;game.duels.clear()
	game.roster={1:{"champion":"Null","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round();game.phase="match"
	a=game.actors[1];b=game.actors[2];a.owner_peer=1;b.owner_peer=2
	a.position=Vector3(0,.025,0);b.position=Vector3(0,.025,-2)
	a.rotation.y=0;b.rotation.y=PI
	await physics_frame
	for i in 10:game.simulate_movement(a,.016);game.simulate_movement(b,.016)
func tick(actor, duration: float) -> void:
	var left:=duration
	while left>.000001:
		var step:=minf(left,1.0/60);actor.input_age=0
		game.tick_actor(actor,step);left-=step
func wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=size
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	game.add_child(body);body.position=at;return body
func basic() -> void:
	await reset()
	ck(a.champion_model.null_art!=null,"Authored Null model")
	ck(game.Kits.NAMES.has("Null") and game.champion_choice.item_count==game.Kits.NAMES.size(),"Null selectable in the actual class picker")
	ck(not game.try_spell(1,1,2) and a.cooldowns[1]==0,"Frontal Backstab rejected without cost")
	b.rotation.y=0
	ck(game.try_spell(1,1,2),"Backstab accepted from behind")
	ck(b.hp==65 and a.cooldowns[1]==30,"Backstab damage and 30s cooldown")
	ck(a.identity.combat_left==10 and b.identity.combat_left==10,"Direct attacks flag both combatants")
	a.gcd=1
	ck(game.try_spell(1,6,2) and a.gcd==1,"Blindside is off GCD")
	ck(game.Null.behind(a,b) and a.position.distance_to(b.position)<1.4,"Blindside lands behind target")
	ck(a.motion_revision>0,"Teleport invalidates rewind history")
	a.gcd=0
	ck(game.try_spell(1,0,2) and b.hp==53,"Stab filler")
	a.gcd=0;b.casting=0;b.cast_left=1.0
	ck(game.try_spell(1,2,2) and b.casting==-1 and b.locked==4,"Kick interrupts and locks")
	a.gcd=0
	ck(game.try_spell(1,3,2) and is_equal_approx(b.stunned,4),"Four-second Nerve Lock")
	await reset()
	a.move_input=Vector2.UP;game.simulate_movement(a,.016);var base: float=a.velocity.length()
	ck(game.try_spell(1,5,-1),"Haste needs no target")
	game.simulate_movement(a,.016)
	ck(is_equal_approx(a.velocity.length(),base*1.5),"50 percent faster travel")
	ck(a.identity.null_haste==6 and a.cooldowns[5]==25,"Haste duration and cooldown")
	a.move_input=Vector2.ZERO;tick(a,6.01)
	ck(a.identity.null_haste==0,"Haste expiration")
	await reset();b.rotation.y=.8;a.last_input_seq=100
	game.apply_action_intent(1,6,2,90,Vector2.ZERO,0,false)
	ck(is_equal_approx(a.rotation.y,b.rotation.y),"Late Blindside action retains server teleport facing")
func stealth() -> void:
	await reset()
	game.local_id=2;game.selected_id=1;b.target_id=1
	ck(game.try_spell(1,4,-1),"Stealth available outside combat")
	ck(a.identity.stealth and a.cooldowns[4]==0,"Stealth no cooldown")
	ck(game.selected_id==-1 and b.target_id==-1 and game.locked_target_for(2)==-1,"Stealth clears target lock")
	ck(not game.try_spell(2,0,1),"Forged target cannot attack concealed Null")
	game.cycle_target();ck(game.selected_id==-1,"Tab cannot acquire undetected Null")
	game.Null.tick(game,a,.69);ck(not game.Null.detected(a,b),"Dwell not complete at 0.69s")
	game.Null.tick(game,a,.011);ck(game.Null.detected(a,b),"Detection at 0.7s")
	game.sync_target_lock();ck(game.selected_id==-1,"Detection does not auto-retarget")
	game.cycle_target();ck(game.selected_id==1,"Tab acquires detected Null")
	var art=a.champion_model.null_art
	art.visibility_for(a,a);ck(art.model.visible and art.last_alpha==.5 and art.alert.visible,"Own half-opacity and detection alert")
	art.visibility_for(a,b);ck(art.model.visible and art.last_alpha==.5,"Enemy half-opacity when detected")
	game.update_visuals(0)
	ck(not a.health_pivot.visible and (a.nameplate==null or not a.nameplate.visible),"Detected stealth hides overhead health and nameplate")
	ck(not game.target_frame.visible,"Detected stealth hides selected-target health")
	game.mode=3;game.update_visuals(0)
	ck(not game.enemy_buttons[0].visible,"Detected stealth hides roster health")
	game.mode=1
	game.camera_character_fade.update(a)
	var owned:=true
	for mesh in art.model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(surface)
			owned=owned and art.materials.has(material) and is_equal_approx(material.albedo_color.a,.5)
	ck(owned,"Camera fade preserves live half-opacity materials")
	game.camera_character_fade.reset()
	var third=load("res://scripts/combatant.gd").new();game.add_child(third);third.setup(3,3,1,"Ember",false);third.position=Vector3(10,0,0);game.actors[3]=third
	ck(not game.Null.targetable(game,third,a),"Detection per enemy")
	art.visibility_for(a,third);ck(not art.model.visible and not art.alert.visible,"Distant enemy sees neither model nor alert")
	b.position.z=-3.6;game.Null.tick(game,a,.1)
	ck(not game.Null.detected(a,b) and b.target_id==-1,"Leaving radius hides immediately")
	b.position.z=-2;game.Null.tick(game,a,.69);ck(not game.Null.detected(a,b),"Re-entry restarts dwell")
	game.actors.erase(3);third.free()
	game.local_id=1;b.rotation.y=PI;a.gcd=0
	ck(game.try_spell(1,0,2) and not a.identity.stealth,"Opening attack reveals Null")
	ck(game.locked_target_for(2)==1 and b.target_id==1,"Opening restores opponent auto-target")
	ck(not game.try_spell(1,4,-1),"Outgoing combat prevents stealth")
	tick(a,10.01);a.gcd=0
	ck(game.try_spell(1,4,-1),"Restealth after ten seconds")
	game.damage(b,a,2,true)
	ck(not a.identity.stealth and a.identity.combat_left==0,"Periodic damage reveals without combat extension")
	ck(game.try_spell(1,4,-1),"Can restealth between periodic ticks")
	a.identity.dots[2]={"left":3.0,"tick":.1,"stacks":1}
	game.ClassMechanics.tick_dots(game,a,a.identity.dots,.11,3,0)
	ck(not a.identity.stealth and a.identity.combat_left==0,"Actual DoT follows stealth rule")
	a.identity.dots.clear();game.try_spell(1,4,-1)
	a.identity.severe_bleeds[2]={"left":2.0,"tick":.1};game.Outlaw.tick(game,a,.11)
	ck(not a.identity.stealth and a.identity.combat_left==0,"Actual bleed follows stealth rule")
	a.identity.severe_bleeds.clear();b.casting=0;b.cast_target=1;b.cast_left=12
	ck(game.try_spell(1,4,-1) and b.casting==-1,"Restealth cancels enemy cast")
	game.Null.begin_ability(game,a,{"kind":"damage","aim_mode":"hitscan"},null)
	ck(not a.identity.stealth and a.identity.combat_left==10,"Aimed use reveals even on miss")
	var snap: Dictionary=a.snapshot();b.receive(snap)
	ck(b.identity.combat_left==10 and b.identity.has("stealth_detection"),"Snapshot round trip")
	await reset();game.try_spell(1,4,-1)
	game.ClassMechanics.control(game,b,a,1,"Area stun")
	ck(not a.identity.stealth and a.identity.combat_left==10,"Area control breaks stealth and flags direct combat")
	await reset();game.world_mode=true;game.duels={1:2,2:1};game.local_id=2;game.selected_id=1
	game.try_spell(1,4,-1);game.Null.tick(game,a,.71);game.sync_target_lock()
	ck(game.selected_id==-1 and game.locked_target_for(2)==-1,"World duel stealth releases mandatory targeting")
	game.cycle_target();ck(game.selected_id==1,"World duel can Tab to detected Null")
	game.Null.break_stealth(game,a);ck(game.locked_target_for(2)==1,"World duel target lock returns on reveal")
func vantage() -> void:
	await reset()
	b.position.z=-6;var start: Vector3=a.position
	ck(game.try_spell(1,7,2),"Vantage starts from ground")
	tick(a,.49)
	ck(Vector2(a.position.x-start.x,a.position.z-start.z).length()<.001 and a.position.y>start.y+4.8,"Vertical first 0.5 seconds")
	ck(b.hp==100 and b.stunned==0,"No hit before contact")
	tick(a,.02);ck(a.identity.null_vantage.get("phase","")=="dive","Dive begins at 0.5s")
	for i in 100:
		tick(a,1.0/60)
		if b.hp<100:break
	ck(b.hp==78 and is_equal_approx(b.stunned,4),"Contact deals damage and four-second stun")
	ck(game.Outlaw.Lasso.knockdown_active(b),"Victim knockdown active")
	var impact: Vector3=a.position;tick(a,.2)
	ck(a.position.distance_to(impact)<.15 and not game.Null.busy(a),"Brief recovery without rebound")
	ck(b.hp==78,"Only one damage application")
	await reset();b.position.z=-6
	var ceiling:=wall(Vector3(0,2.7,0),Vector3(4,.2,4));await physics_frame
	game.try_spell(1,7,2);tick(a,.7)
	ck(not game.Null.busy(a) and b.hp==100,"Ceiling cancels ascent without hit")
	ceiling.free();await physics_frame
	await reset();b.position.z=-6
	game.try_spell(1,7,2);tick(a,.51);game.CC.apply(a,"stun",1,"Test");tick(a,.016)
	ck(not game.Null.busy(a) and b.hp==100,"Stun cancels dive")
func run() -> void:
	game=load("res://arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	await basic();await stealth();await vantage()
	print("Null ability checks: %d passed / %d total" % [checks-failures,checks]);quit(1 if failures else 0)
