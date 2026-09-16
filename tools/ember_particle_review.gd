extends SceneTree
## Reproducible native Ember review. -- --capture saves PNGs plus frame timings.
var game
var ember
var target
var label: Label
var time := 0.0
var stage := -1
var frame := 0
var capture := false
var benchmark := false
var effects_off := false
var cycle := 0
var measurements: Array = []
var last_us := 0
var output := "res://artifacts/ember-particles"
const NAMES := ["Burning Wake · safe center / 60 damage", "Kindle · downloaded fireball", "Flashpoint · brief ignition", "Supernova · heat then eruption", "Solar Flare · white flame", "Fire Barrier", "Cinderstep · steerable skate / +80%", "Ash · crumble / hidden spirit / return route"]

func _initialize() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	benchmark="--benchmark" in OS.get_cmdline_user_args()
	effects_off="--effects-off" in OS.get_cmdline_user_args()
	if benchmark: output += "/benchmark-off" if effects_off else "/benchmark-on"
	call_deferred("run")

func run() -> void:
	Engine.max_fps=60
	game=load("res://arena.tscn").instantiate();root.add_child(game)
	game.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.set_physics_process(false);game.set_process(false)
	game.mode=3;game.roster={1:{"champion":"Ember","team":0},2:{"champion":"Vanguard","team":1}}
	game.begin_round();game.phase="match"
	ember=game.actors[1]
	for a in game.actors.values():
		a.owner_peer=a.actor_id
		a.position=Vector3(10+a.actor_id,.025,8)
	target=game.actors[2]
	game.local_id=1;game.selected_id=2
	var review_camera:=Camera3D.new()
	root.add_child(review_camera)
	review_camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.camera=review_camera
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=55
	game.camera.global_position=Vector3(10,9,13)
	game.camera.look_at(Vector3(0,1,-2));game.camera.make_current()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,800))
	DisplayServer.window_set_title("Starfall · Ember particle workflow r001")
	game.ui.hide()
	var layer:=CanvasLayer.new();root.add_child(layer)
	label=Label.new();label.position=Vector2(28,64);label.add_theme_font_size_override("font_size",24);layer.add_child(label)
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.frame_post_draw.connect(record_frame)

func _process(delta: float) -> bool:
	if ember==null:return false
	time+=delta
	var next_cycle:=int(time/36.0)
	var next:=mini(7,int(fmod(time,36.0)/4.0))
	if time>(72 if benchmark else 36):
		var file:=FileAccess.open(output+"/frame-times.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"frames":measurements,"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_method(),"resolution":[1280,800],"vsync":DisplayServer.window_get_vsync_mode(),"capture":capture,"effects_off":effects_off,"frame_cap":Engine.max_fps,"actor_count":game.actors.size()},"\t"));file.close()
		print("EMBER PARTICLE REVIEW COMPLETE");quit();return false
	if next_cycle!=cycle:
		cycle=next_cycle
		game.begin_round();game.phase="match"
		ember=game.actors[1];target=game.actors[2]
		for a in game.actors.values():a.owner_peer=a.actor_id;a.position=Vector3(10+a.actor_id,.025,8)
	if next!=stage:
		stage=next
		ember.reset_identity();ember.cooldowns.fill(0.0);ember.gcd=0;ember.casting=-1;ember.shield=0;ember.hp=ember.MAX_HEALTH
		ember.position=Vector3(0,.025,1);ember.rotation.y=0;ember.move_input=Vector2.ZERO;ember.velocity=Vector3.ZERO
		target.position=Vector3(0,.025,-3);target.hp=target.MAX_HEALTH
		ember.identity.heat=80
		label.text=NAMES[stage]
		match stage:
			0:game.resolve_spell(ember,11,ember)
			1:game.resolve_spell(ember,0,target)
			2:game.resolve_spell(ember,1,target)
			3:
				ember.casting=7;ember.cast_left=2.2;ember.cast_duration=2.2;ember.cast_target=2
			4:game.resolve_spell(ember,8,ember)
			5:game.resolve_spell(ember,4,ember)
			6:game.resolve_spell(ember,9,ember)
			7:game.resolve_spell(ember,12,ember)
	var local:=time-float(cycle)*36-float(stage)*4
	if stage==1 and local>1 and local<3.6 and ember.cooldowns[1]<=0:
		game.resolve_spell(ember,0,target);ember.cooldowns[1]=.9
	if stage==2 and local>1.5 and local<1.6:game.ember_effect(ember,"flashpoint",ember.position,target.position)
	if stage==6:
		ember.move_input=Vector2.UP if local<.7 else (Vector2.RIGHT if local<1.25 else Vector2.ZERO)
	if stage==7:
		ember.move_input=Vector2.RIGHT if local<.5 else (Vector2.UP if local<1.0 else Vector2.ZERO)
	for a in game.actors.values():
		a.input_age=0;game.tick_actor(a,delta)
	game.update_visuals(delta)
	if effects_off:
		for a in game.actors.values():
			var fx=a.get_node_or_null("EmberEffects")
			if fx!=null:fx.set_process(false);fx.visible=false
	game.camera.global_position=Vector3(0,10,12)
	game.camera.look_at(Vector3(0,1,-2))
	game.camera_character_fade.reset()
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,800)
	root.content_scale_size=Vector2i(1280,800)
	return false

func record_frame() -> void:
	var now:=Time.get_ticks_usec()
	if last_us>0:measurements.append([time,stage,(now-last_us)/1000.0,int(game.application_focused),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),cycle+1])
	last_us=now
	if capture and frame%4==0:root.get_texture().get_image().save_png(output+"/frame-%05d.png"%(frame/4))
	frame+=1
