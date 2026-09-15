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
	ck(is_equal_approx(b.hp,1112) and a.cooldowns[1]==30,"Backstab deals transferred damage and keeps its 30s cooldown")
	ck(a.identity.combat_left==8 and b.identity.combat_left==8,"Direct attacks flag both combatants")
	a.gcd=1
	var before_blindside:Vector3=a.position
	ck(game.try_spell(1,6,2) and a.gcd==1,"Blindside is off GCD")
	ck(a.casting==6 and is_equal_approx(a.cast_left,.28) and a.position==before_blindside,"Blindside starts its 0.28s wind-up without teleporting")
	ck(game.kick_immune(a) and game.cast_bar_color(a,false,Color.WHITE)==game.UNKICKABLE_CAST_COLOR,"Blindside is unkickable and uses the gray castbar")
	tick(a,.27)
	ck(a.position==before_blindside and a.casting==6 and a.cooldowns[6]==0,"Blindside does not fire or spend cooldown early")
	tick(a,.011)
	ck(game.Null.behind(a,b) and a.position.distance_to(b.position)<1.4,"Blindside lands behind target")
	ck(a.motion_revision>0,"Teleport invalidates rewind history")
	a.gcd=0
	ck(game.try_spell(1,0,2) and is_equal_approx(b.hp,992),"Temporal Strike filler")
	a.gcd=0;b.casting=0;b.cast_left=1.0
	ck(game.try_spell(1,2,2) and b.casting==-1 and b.locked==4,"Kick interrupts and locks")
	a.gcd=0
	ck(game.try_spell(1,3,2) and is_equal_approx(b.stunned,4),"Four-second Nerve Lock")
	await reset()
	a.hp=500
	a.identity.dots[2]={"left":3.0,"tick":.1,"stacks":1}
	a.identity.entropy_dots[2]={"left":3.0,"tick":.1}
	a.identity.severe_bleeds[2]={"left":3.0,"tick":.1}
	ck(game.try_spell(1,8,-1) and a.hp==350 and a.cooldowns[8]==40,"Regen Pot starts instantly and pays Entropy's 10-percent-health cleanse backlash")
	ck(a.cc_effects.has("silence"),"Regen Pot's self-cleanse triggers Entropy silence")
	ck(a.identity.dots.is_empty() and a.identity.entropy_dots.is_empty() and a.identity.severe_bleeds.is_empty(),"Regen Pot immediately removes attached damage-over-time effects")
	ck(a.identity.null_regen.left==6.0,"Regen Pot lasts six seconds")
	game.Null.tick(game,a,1.0);ck(is_equal_approx(a.hp,394.8),"Regen Pot restores 44.8 health after its first second")
	game.Null.tick(game,a,5.0);ck(is_equal_approx(a.hp,618.8) and a.identity.null_regen.is_empty(),"Regen Pot restores 268.8 health over six seconds")
	await reset()
	a.identity.essence=120
	a.cooldowns[1]=20
	ck(game.try_spell(1,9,-1) and a.identity.chronoshift_select,"Chronoshift arms a normal-keybind cooldown choice without a cooldown")
	ck(game.try_spell(1,5,-1) and not a.identity.chronoshift_select and a.identity.null_haste==6,"A ready ability cancels Chronoshift selection and casts normally")
	ck(game.try_spell(1,9,-1) and a.identity.chronoshift_select,"Chronoshift can be armed again after a normal cast")
	a.gcd=1
	ck(not game.try_spell(1,1,2) and a.cooldowns[1]==20 and a.identity.essence==120,"Invalid automatic cast preserves cooldown and Essence")
	a.gcd=0
	b.rotation.y=0
	ck(game.try_spell(1,1,2) and a.cooldowns[1]==30 and a.identity.essence==20,"Chosen cooldown refreshes and casts immediately for 100 Essence")
	ck(a.identity.chronoshift_locks[1]==60,"Chronoshift places a separate double-cooldown reset lock")
	b.rotation.y=0
	ck(not game.try_spell(1,1,2) and a.identity.essence==20,"Automatic recast grants no Essence and starts normal cooldown")
	a.gcd=0
	ck(game.try_spell(1,0,2) and a.identity.essence==50,"Temporal Strike grants 30 Essence when normally cast")
	await reset()
	a.identity.essence=120;a.identity.combat_left=8
	ck(not game.try_spell(1,4,-1),"Normal Stealth remains blocked in combat")
	ck(game.try_spell(1,9,-1) and game.try_spell(1,4,-1) and game.Null.stealthed(a),"Chronoshift immediately re-stealths in combat")
	ck(a.identity.essence==20 and a.identity.chronoshift_locks[4]==120 and a.cooldowns[4]==0,"Stealth has only a two-minute reset lock")
	ck(game.try_spell(1,4,-1) and not game.Null.stealthed(a),"Manual unstealth still works")
	a.identity.essence=120
	ck(game.try_spell(1,9,-1) and not game.try_spell(1,4,-1) and a.identity.essence==120,"Locked Stealth reset spends nothing")
	a.cooldowns[2]=10
	ck(not game.try_spell(1,2,2) and a.cooldowns[2]==10 and a.identity.essence==120,"Chronoshift cannot reset Kick")
	ck(not game.Null.chronoshift_candidate(a,2),"Kick never receives a gold selection frame")
	a.identity.chronoshift_select=false;a.identity.combat_left=0
	ck(game.try_spell(1,4,-1),"Normal out-of-combat Stealth ignores reset lock")
	game.Null.break_stealth(game,a);a.identity.combat_left=8
	game.Null.tick(game,a,120);a.identity.combat_left=8
	ck(game.try_spell(1,9,-1) and game.try_spell(1,4,-1),"Stealth reset becomes available after two minutes")
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
	tick(a,.281)
	ck(is_equal_approx(a.rotation.y,b.rotation.y),"Late Blindside action retains server teleport facing")
	await reset();a.move_input=Vector2.RIGHT
	a.identity.stealth=true
	ck(game.try_spell(1,6,2),"Blindside wind-up can start while moving")
	ck(game.Null.stealthed(a),"Blindside wind-up preserves existing stealth")
	tick(a,.281)
	ck(game.Null.behind(a,b) and a.cooldowns[6]==15,"Movement does not cancel the Blindside wind-up")
	ck(game.Null.stealthed(a),"Blindside teleport preserves existing stealth")
	await reset();var cancelled_from:Vector3=a.position
	ck(game.try_spell(1,6,2),"Blindside cancellation fixture starts")
	game.cancel_own_cast(a,"Cancelled");tick(a,.4)
	ck(a.position==cancelled_from and a.cooldowns[6]==0,"Cancelled wind-up never teleports or consumes cooldown")
func stealth() -> void:
	await reset()
	var solid_at_spawn:=true
	for material in a.champion_model.null_art.materials:
		solid_at_spawn=solid_at_spawn and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
	ck(solid_at_spawn,"Null spawns using solid depth-rendered materials before Stealth")
	game.local_id=2;game.selected_id=1;b.target_id=1
	ck(game.try_spell(1,4,-1),"Stealth available outside combat")
	ck(a.identity.stealth and a.cooldowns[4]==0,"Stealth no cooldown")
	var stealth_serial: int=a.identity.stealth_serial
	for press in 10:
		ck(game.try_spell(1,4,-1) and a.identity.stealth,"Repeated Stealth presses keep Null concealed")
	ck(a.identity.stealth_serial==stealth_serial,"Repeated Stealth presses do not restart stealth")
	a.move_input=Vector2.UP;game.simulate_movement(a,.016)
	ck(a.identity.stealth,"Movement steps do not break Null's Stealth")
	a.move_input=Vector2.ZERO;a.position=Vector3(0,.025,0)
	ck(game.selected_id==-1 and b.target_id==-1 and game.locked_target_for(2)==-1,"Stealth clears target lock")
	ck(not game.try_spell(2,0,1),"Forged target cannot attack concealed Null")
	game.cycle_target();ck(game.selected_id==-1,"Tab cannot acquire undetected Null")
	game.Null.tick(game,a,.69);ck(not game.Null.detected(a,b),"Dwell not complete at 0.69s")
	ck(game.try_spell(1,4,-1) and is_equal_approx(float(a.identity.stealth_detection[b.actor_id]),.69),"Repeated Stealth preserves detection progress")
	game.Null.tick(game,a,.011);ck(game.Null.detected(a,b),"Detection at 0.7s")
	game.sync_target_lock();ck(game.selected_id==-1,"Detection does not auto-retarget")
	game.cycle_target();ck(game.selected_id==1,"Tab acquires detected Null")
	var art=a.champion_model.null_art
	ck(is_equal_approx(art.transition_duration("Idle","StealthIdle"),.38),"Stealth crouch-in has a slightly slower smooth transition")
	ck(is_equal_approx(art.transition_duration("StealthIdle","Idle"),.52),"Leaving Stealth uses a longer uncrouch transition")
	art.visibility_for(a,a);art.animate(a.champion_model, .5, a);ck(art.model.visible and is_equal_approx(art.last_alpha,.5) and art.alert.visible,"Own Stealth fades to half-opacity and shows the detection alert")
	ck(is_zero_approx(art.shadow_material.albedo_color.a),"Owner's shadow fully disappears despite half-opacity Stealth body")
	var stable_transparency:=true
	for material in art.materials:stable_transparency=stable_transparency and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA
	ck(stable_transparency,"Stealth fade keeps its render pipeline stable")
	art.visibility_for(a,b);art.animate(a.champion_model, .2, a);ck(art.model.visible and is_equal_approx(art.last_alpha,.5),"Detected enemy sees Null at half-opacity")
	ck(is_zero_approx(art.shadow_material.albedo_color.a),"Detection does not restore the stealthed shadow")
	a.identity.null_haste=6.0
	art.visibility_for(a,a);art.animate(a.champion_model,.2,a)
	ck(art.haste_wind.visible,"Stealthed owner can see their own Haste wind")
	art.visibility_for(a,b)
	ck(not art.haste_wind.visible,"Opposing player cannot see Haste wind while Null is stealthed")
	a.identity.null_haste=0.0
	game.update_visuals(0)
	ck(not a.health_pivot.visible and (a.nameplate==null or not a.nameplate.visible),"Detected stealth hides overhead health and nameplate")
	ck(not game.target_frame.visible,"Detected stealth hides selected-target health")
	game.mode=3;game.update_visuals(0)
	ck(not game.enemy_buttons[0].visible,"Detected stealth hides roster health")
	game.mode=1
	game.camera_character_fade.update(a)
	var owned:=true
	for mesh in art.model.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			owned=owned and mesh.material_override==art.shadow_material and is_zero_approx(art.shadow_material.albedo_color.a) and art.shadow_material.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED
			continue
		for surface in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(surface)
			owned=owned and art.materials.has(material) and is_equal_approx(material.albedo_color.a,.5)
	ck(owned,"Camera fade preserves live half-opacity materials")
	game.camera_character_fade.reset()
	var third=load("res://scripts/combatant.gd").new();game.add_child(third);third.setup(3,3,1,"Ember",false);third.position=Vector3(10,0,0);game.actors[3]=third
	ck(not game.Null.targetable(game,third,a),"Detection per enemy")
	art.visibility_for(a,third);art.animate(a.champion_model,.5,a);ck(not art.model.visible and not art.alert.visible,"Distant enemy sees neither model nor alert after the smooth fade")
	b.position.z=-3.6;game.Null.tick(game,a,.1)
	ck(not game.Null.detected(a,b) and b.target_id==-1,"Leaving radius hides immediately")
	b.position.z=-2;game.Null.tick(game,a,.69);ck(not game.Null.detected(a,b),"Re-entry restarts dwell")
	game.actors.erase(3);third.free()
	game.local_id=1;b.rotation.y=PI;a.gcd=0
	ck(game.try_spell(1,0,2) and not a.identity.stealth,"Opening attack reveals Null")
	art.visibility_for(a,a);art.animate(a.champion_model,.2,a)
	ck(art.last_alpha<1.0,"Leaving Stealth remains visibly mid-fade after 0.2 seconds")
	ck(is_equal_approx(art.shadow_material.albedo_color.a,art.last_alpha),"Animated shadow uses the reveal fade progress")
	art.animate(a.champion_model,.35,a)
	var fully_opaque:=true
	for material in art.materials:fully_opaque=fully_opaque and is_equal_approx(material.albedo_color.a,1.0) and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED
	ck(fully_opaque,"Leaving Stealth restores every Null material to full opacity")
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
	ck(not a.identity.stealth and a.identity.combat_left==8,"Aimed use reveals even on miss")
	var snap: Dictionary=a.snapshot();b.receive(snap)
	ck(b.identity.combat_left==8 and b.identity.has("stealth_detection"),"Snapshot round trip")
	await reset();game.try_spell(1,4,-1)
	game.ClassMechanics.control(game,b,a,1,"Area stun")
	ck(not a.identity.stealth and a.identity.combat_left==8,"Area control breaks stealth and flags direct combat")
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
	ck(b.hp==1500 and b.stunned==0,"No hit before contact")
	tick(a,.02);ck(a.identity.null_vantage.get("phase","")=="dive","Dive begins at 0.5s")
	for i in 100:
		tick(a,1.0/60)
		if b.hp<b.MAX_HEALTH:break
	ck(is_equal_approx(b.hp,1423) and is_equal_approx(b.stunned,4),"Contact deals reduced damage and four-second stun")
	ck(game.Outlaw.Lasso.knockdown_active(b),"Victim knockdown active")
	var impact: Vector3=a.position;tick(a,.2)
	ck(a.position.distance_to(impact)<.15 and not game.Null.busy(a),"Brief recovery without rebound")
	ck(is_equal_approx(b.hp,1423),"Only one damage application")
	await reset();b.position.z=-6
	var ceiling:=wall(Vector3(0,2.7,0),Vector3(4,.2,4));await physics_frame
	game.try_spell(1,7,2);tick(a,.7)
	ck(not game.Null.busy(a) and b.hp==1500,"Ceiling cancels ascent without hit")
	ceiling.free();await physics_frame
	await reset();b.position.z=-6
	game.try_spell(1,7,2);tick(a,.51);game.CC.apply(a,"stun",1,"Test");tick(a,.016)
	ck(not game.Null.busy(a) and b.hp==1500,"Stun cancels dive")

func vantage_lift() -> void:
	for frame_time in [1.0/240,1.0/60,.037,.125,.5]:
		await reset();b.position.z=-6
		# Start clear of the floor's collision safe margin so this measures only
		# the integrated rise, not the physics engine's tiny recovery displacement.
		a.position.y=.025
		var start: Vector3=a.position
		ck(game.try_spell(1,7,2),"Vantage starts for lift step "+str(frame_time))
		ck(is_equal_approx(a.velocity.y,16.0),"Vantage starts with a stronger 16 m/s takeoff")
		var elapsed:=0.0
		var monotonic:=true
		var previous_speed: float=a.velocity.y
		while elapsed<.5-.000001:
			var step:=minf(frame_time,.5-elapsed)
			game.Null.motion(game,a,step);elapsed+=step
			if elapsed<.5-.000001:
				monotonic=monotonic and a.velocity.y<previous_speed
				previous_speed=a.velocity.y
		ck(monotonic,"Lift slows smoothly without a flat-speed section")
		print("VANTAGE_LIFT step=",frame_time," rise=",a.position.y-start.y," start=",start," end=",a.position)
		ck(absf(a.position.y-start.y-5.0)<.00001,"Integrated lift rises exactly five meters at step "+str(frame_time))
		ck(Vector2(a.position.x-start.x,a.position.z-start.z).length()<.00001,"Lift remains strictly vertical")
		ck(a.identity.null_vantage.phase=="dive" and b.hp==1500,"All frame sizes begin the dive at 0.5 seconds without an early hit")
	ck(is_equal_approx(game.Null.lift_height(.25),3.25) and is_equal_approx(game.Null.lift_velocity(.5),4.0),"Lift covers 3.25 meters in its first half and settles to 4 m/s")

func vantage_range_and_air() -> void:
	var speeds: Array[float]=[]
	var times: Array[float]=[]
	for distance in [6.0,18.0]:
		await reset();a.position.z=12;b.position.z=12-distance
		ck(game.try_spell(1,7,2),"Vantage accepts a target at "+str(distance)+" meters")
		game.Null.motion(game,a,.5)
		var initial_speed: float=a.identity.null_vantage.dive_speed
		var dive_snapshot: Dictionary=a.snapshot().identity.null_vantage
		ck(is_equal_approx(dive_snapshot.dive_speed,initial_speed) and is_equal_approx(dive_snapshot.dive_current_speed,4.0) and is_zero_approx(dive_snapshot.dive_progress),"Snapshot carries the fixed range scale and current dive acceleration state")
		speeds.append(initial_speed)
		var elapsed:=0.0
		while b.hp==b.MAX_HEALTH and elapsed<1.0 and game.Null.busy(a):
			game.Null.motion(game,a,1.0/240);elapsed+=1.0/240
		times.append(elapsed)
		ck(is_equal_approx(b.hp,1423) and is_equal_approx(b.stunned,4.0),"Short and long dives resolve reduced damage and unchanged stun")
		ck(a.identity.null_vantage.phase=="recover","Both distances enter recovery immediately at contact")
		game.Null.motion(game,a,.179)
		ck(game.Null.busy(a),"Contact recovery lasts at least 0.179 seconds")
		game.Null.motion(game,a,.002)
		ck(not game.Null.busy(a) and is_equal_approx(b.hp,1423),"Recovery ends after 0.18 seconds without applying damage again")
	ck(is_equal_approx(speeds[0],25.0) and speeds[1]>46.0 and speeds[1]<=65.0,"Near dives retain the 25 m/s base profile and long dives use the larger range scale")
	ck(times[0]<.6 and times[1]<.6,"Near and far dives both connect promptly despite the eased start")
	print("VANTAGE_RANGE short_speed=",speeds[0]," far_speed=",speeds[1]," short_dive_seconds=",times[0]," far_dive_seconds=",times[1])
	await reset();b.position.z=-6;game.try_spell(1,7,2);game.Null.motion(game,a,.5)
	var fixed_speed: float=a.identity.null_vantage.dive_speed
	b.position.z=-16
	game.Null.motion(game,a,.01)
	ck(is_equal_approx(a.identity.null_vantage.dive_speed,fixed_speed) and a.velocity.length()>4.0 and a.velocity.length()<fixed_speed and is_zero_approx(a.identity.null_vantage.dive_progress),"Target retreat keeps the original range profile while speed eases up from the 4 m/s entry")
	await reset();b.position.z=-6;game.try_spell(1,7,2);b.position.z=-50;game.Null.motion(game,a,.5)
	ck(is_equal_approx(a.identity.null_vantage.dive_speed,65.0),"Large target movement before dive cannot exceed the speed cap")
	for jump_frames in [8,26]:
		await reset();b.position.z=-6;a.jump_queued=true
		for frame in jump_frames:game.simulate_movement(a,1.0/60)
		ck(not a.is_on_floor() and (a.velocity.y>0 if jump_frames==8 else a.velocity.y<0),"Airborne fixture is actually rising or falling under normal jump physics")
		var start: Vector3=a.position
		a.jump_queued=true;a.jump_buffer=.12
		ck(game.try_spell(1,7,2),"Vantage can be cast during either half of a jump")
		ck(not a.jump_queued and is_zero_approx(a.jump_buffer) and is_equal_approx(a.velocity.y,16.0),"Airborne cast clears pending jump input and replaces previous vertical momentum")
		ck(a.cooldowns[7]==25 and a.identity.essence==30,"Airborne casting keeps the original cooldown and Essence grant")
		game.Null.motion(game,a,.5)
		ck(absf(a.position.y-start.y-5.0)<.00001,"Airborne cast rises five meters from its actual cast height")
		for frame in 120:
			game.Null.motion(game,a,1.0/120)
			if b.hp<b.MAX_HEALTH:break
		ck(is_equal_approx(b.hp,1423),"Airborne Vantage reaches the target with reduced damage")

func vantage_cancellation() -> void:
	await reset();b.position.z=-6;game.try_spell(1,7,2);game.Null.motion(game,a,.5)
	var obstacle:=wall(Vector3(0,3,-3),Vector3(2,10,.2));await physics_frame
	game.Null.motion(game,a,.3)
	ck(not game.Null.busy(a) and b.hp==1500 and a.position.z>-3,"Dive uses swept collision and cannot pass through a wall")
	obstacle.free();await physics_frame
	for reason in ["root","death","target_death","target_concealed"]:
		await reset();b.position.z=-6;game.try_spell(1,7,2);game.Null.motion(game,a,.5)
		match reason:
			"root":a.identity.root=1.0
			"death":a.hp=0
			"target_death":b.hp=0
			"target_concealed":b.identity.stealth=true
		var health: float=b.hp
		game.Null.motion(game,a,.05)
		ck(not game.Null.busy(a) and b.hp==health and a.velocity==Vector3.ZERO,"Vantage still cancels cleanly on "+reason)
	await reset();b.position.z=-6;a.identity.root=1.0
	ck(not game.try_spell(1,7,2) and a.cooldowns[7]==0,"Removing the airborne gate does not allow rooted casting")
	await reset();b.position.z=-6;game.try_spell(1,7,2);game.Null.motion(game,a,.5)
	game.actors.erase(2);b.free();b=null
	game.Null.motion(game,a,.05)
	ck(not game.Null.busy(a) and a.velocity==Vector3.ZERO,"Target removal cancels the dive without invalid access")
func run() -> void:
	game=load("res://arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	if not "--vantage-only" in OS.get_cmdline_user_args():
		await basic();await stealth()
	await vantage();await vantage_lift();await vantage_range_and_air();await vantage_cancellation()
	print("Null ability checks: %d passed / %d total" % [checks-failures,checks]);quit(1 if failures else 0)
