extends SceneTree
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game); game.set_physics_process(false); game.set_process(false)
	game.roster={1:{"champion":"Null","team":0},2:{"champion":"Vanguard","team":1},3:{"champion":"Luminary","team":0}}
	game.begin_round();game.phase="match"
	var a=game.actors[1];var b=game.actors[2];var ally=game.actors[3]
	a.position=Vector3.ZERO;b.position=Vector3(0,0,-4);ally.position=Vector3(0,0,-5)
	game.Null.Smoke.cast(a)
	ck(not game.Null.Smoke.separates(game,ally,a),"Allied healing crosses friendly smoke")
	ck(game.Null.Smoke.separates(game,b,a),"Enemy cast into smoke blocked")
	ck(not game.Null.Smoke.separates(game,a,b),"Owner casts out freely")
	a.identity.smoke_bomb={}
	b.position=Vector3(0,0,-3);b.rotation.y=PI
	ck(game.try_spell(2,12,1),"New Vanguard slow casts")
	ck(a.identity.crippling_verdict==6 and a.hp==1500,"Slow duration with no damage")
	a.move_input=Vector2(0,-1)
	game.simulate_movement(a,1.0/60,true)
	ck(is_equal_approx(Vector2(a.velocity.x,a.velocity.z).length(),game.MovementTuning.FORWARD_SPEED*.4),"Slow reduces movement by 60 percent")
	for category in game.CC.CATEGORIES:game.CC.apply(a,category,4,"test")
	a.locked=4;a.identity.slow=3;a.identity.severe_slow=3
	ck(game.try_spell(1,14,1),"Trinket works through all control")
	ck(a.cc_effects.is_empty() and a.locked==0 and a.identity.crippling_verdict==0 and a.identity.slow==0 and a.identity.severe_slow==0,"Trinket clears effects")
	var ember=game.Fighter.new();root.add_child(ember);ember.setup(8,8,1,"Ember",false)
	ember.position=Vector3.ZERO; a.position=Vector3(0,0,-4.3)
	ck(game.ClassMechanics.flare_overlaps(ember,a),"Cone edge includes overlapping body")
	a.position=Vector3(0,0,-4.5);ck(not game.ClassMechanics.flare_overlaps(ember,a),"Cone rejects body outside range")
	a.position=Vector3(0,0,2);ck(not game.ClassMechanics.flare_overlaps(ember,a),"Cone rejects rear target")
	var wall=StaticBody3D.new();var collider=CollisionShape3D.new();var shape=BoxShape3D.new()
	shape.size=Vector3(4,4,2);collider.shape=shape;wall.add_child(collider);game.add_child(wall)
	ck(is_equal_approx(game.ClassMechanics.collapse_cover_thickness(game,Vector3(0,0,3),Vector3(0,0,-3)),2),"Collapse measures 2m pillar depth")
	shape.size.z=2.1
	ck(game.ClassMechanics.collapse_cover_thickness(game,Vector3(0,0,3),Vector3(0,0,-3))>2,"Thicker cover blocks control")
	wall.free()
	var bodies=preload("res://scripts/body_hitboxes.gd")
	var points=PackedVector3Array([Vector3(-.4,.1,0),Vector3(-.4,1,0),Vector3(.4,.1,0),Vector3(.4,1,0)])
	var radii=PackedFloat32Array([.1,.1])
	ck(not bodies.trace_aim(Vector3(0,.5,3),Vector3.FORWARD,6,points,radii,Vector3.ZERO).is_empty(),"Filled hitbox blocks the gap between legs")
	ck(not bodies.trace_aim(Vector3(1.2,.5,3),Vector3.FORWARD,6,points,radii,Vector3.ZERO).is_empty(),"Horizontal envelope is 25 percent wider")
	ck(bodies.trace_aim(Vector3(1.3,.5,3),Vector3.FORWARD,6,points,radii,Vector3.ZERO).is_empty(),"Shots outside expanded envelope still miss")
	a.casting=0;a.kit[0].cast=1.5;a.cast_left=1.5;a.presentation_snapshot_serial=1
	a.advance_cast_visual(1.0/60);var previous:float=a.presentation_cast_left()
	a.advance_cast_visual(1.0/60)
	ck(a.presentation_cast_left()<previous and a.cast_left==1.5,"Cast display advances without changing server timer")
	var art=b.champion_model.vanguard_art
	var maximum:=0.0
	for frame in 600:
		b.presentation_grounded=frame%90>45;b.presentation_vertical_speed=7-20*(frame%90)/60.0
		b.presentation_velocity=Vector3(3 if frame%20<10 else -3,b.presentation_vertical_speed,0)
		b.presentation_snapshot_serial+=1 if frame%3==0 else 0
		b.casting=5 if frame%120<35 else -1;b.cast_left=1
		b.champion_model.animate(1.0/60,b)
		for bone in art.skeleton.get_bone_count():
			var pose:Transform3D=art.skeleton.get_bone_global_pose(bone)
			maximum=maxf(maximum,pose.origin.length())
			if not pose.is_finite():failures+=1;break
	ck(maximum<5,"Vanguard bones remain attached during jump/Mend/direction stress")
	var jump=art.shared_movement.jump.omni_jump
	b.casting=-1;b.presentation_grounded=false;b.presentation_velocity=Vector3(0,5,0)
	b.presentation_vertical_speed=5;b.presentation_snapshot_serial+=1
	for i in 10:b.champion_model.animate(1.0/60,b)
	var sample:float=jump.sampled_time
	b.champion_model.animate(1.0/60,b)
	ck(jump.sampled_time>sample,"Approved jump pose advances between snapshots")
	b.position=Vector3(30,-10,30);game.confine_to_arena(b)
	ck(absf(b.position.x)<17.3 and absf(b.position.z)<17.3 and b.position.y>=0,"Arena escape safety restores a legal position")
	game.world_mode=true;b.position=Vector3(30,10,30);game.confine_to_arena(b)
	ck(b.position==Vector3(30,10,30),"World Starwalk remains available")
	print("Vanguard maximum bone distance: ",maximum)
	ember.free();game.free()
	print("September balance checks: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures==0 else 1)
