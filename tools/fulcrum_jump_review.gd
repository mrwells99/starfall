extends SceneTree
## Preview the actual runtime arm layer, not only the unmodified source clip.
var stage: Node3D
var actor
var status: Label
var phase := -.5
var speed := .65
var playback_paused := false
var last_tick := 0
var ready := false
func _initialize() -> void: call_deferred("run")
func run() -> void:
 Engine.max_fps=30
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_current_screen(0)
 DisplayServer.window_set_size(Vector2i(800,850))
 DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(1080,70))
 DisplayServer.window_set_title("Fulcrum — jump arc review")
 if "--capture" in OS.get_cmdline_user_args(): DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 stage=Node3D.new(); root.add_child(stage)
 actor=load("res://scripts/combatant.gd").new(); stage.add_child(actor); actor.setup(1,1,0,"Fulcrum")
 for node in [actor.nameplate,actor.health_pivot,actor.cast_pivot]: node.visible=false
 var env:=WorldEnvironment.new(); env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("171923")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("bdc9ec"); env.environment.ambient_light_energy=.65; stage.add_child(env)
 for i in 2:
  var light:=DirectionalLight3D.new(); stage.add_child(light)
  light.rotation_degrees=Vector3(-35,-25 if i==0 else 135,0); light.light_energy=1.3 if i==0 else .65
 var floor_mesh:=MeshInstance3D.new(); floor_mesh.mesh=PlaneMesh.new(); floor_mesh.mesh.size=Vector2(12,12)
 var material:=StandardMaterial3D.new(); material.albedo_color=Color("343849"); floor_mesh.material_override=material; stage.add_child(floor_mesh)
 var camera:=Camera3D.new(); stage.add_child(camera); camera.position=Vector3(2.3,2.1,-6.4); camera.look_at(Vector3(0,1.6,0)); camera.fov=37; camera.current=true
 var layer:=CanvasLayer.new(); stage.add_child(layer)
 var column:=VBoxContainer.new(); column.position=Vector2(24,20); layer.add_child(column)
 var label:=Label.new(); label.text="FULCRUM · JUMP ARC"; label.add_theme_font_size_override("font_size",24); column.add_child(label)
 status=Label.new(); column.add_child(status)
 var hint:=Label.new(); hint.text="Bent elbows · Arms follow ascent and descent"; column.add_child(hint)
 var slider:=HSlider.new(); slider.min_value=.25; slider.max_value=1.0; slider.step=.05; slider.value=speed; slider.custom_minimum_size=Vector2(300,25)
 slider.value_changed.connect(func(value:float):speed=value); column.add_child(slider)
 var button:=Button.new(); button.text="Pause / resume"; button.pressed.connect(func():playback_paused=not playback_paused); column.add_child(button)
 pose_at(-.1,.016)
 if "--capture" in OS.get_cmdline_user_args():
  for item in [[0.0,"takeoff"],[.12,"rising"],[.35,"apex"],[.53,"falling"],[.69,"return"],[.85,"landed"]]:
   var target: float=item[0]
   while phase < target:
    phase=minf(phase+1.0/60.0,target); pose_at(phase,1.0/60.0)
   await process_frame; await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/fulcrum-jump-r002/"+item[1]+".png")
  print("FULCRUM_JUMP_REVIEW_CAPTURED"); stage.queue_free(); await process_frame; quit(); return
 last_tick=Time.get_ticks_usec(); ready=true
 process_frame.connect(tick)
 print("FULCRUM_JUMP_REVIEW_READY screen=",DisplayServer.window_get_current_screen())
func tick() -> void:
 var now:=Time.get_ticks_usec(); var delta:=minf((now-last_tick)/1000000.0,.1)*speed; last_tick=now
 if not ready or playback_paused:return
 phase+=delta
 if phase>1.35:phase=-.35
 pose_at(phase,delta)
func pose_at(t:float,delta:float) -> void:
 var airborne:= t>=0 and t<.7
 actor.presentation_grounded=not airborne
 actor.presentation_vertical_speed=7.0-20.0*t if airborne else 0.0
 actor.position.y=maxf(0,7*t-10*t*t) if airborne else 0.0
 actor.champion_model.animate(delta,actor)
 status.text=("Rising" if t<.35 else "Falling") if airborne else "Grounded"
 if airborne and absf(t-.35)<.035:status.text="Apex"
 status.text+="  ·  %.0f%% playback" % (speed*100)
