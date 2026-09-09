extends Node3D
var model: Node3D
var player: AnimationPlayer
var camera: Camera3D
var yaw := -0.35
var pitch := 0.14
var distance := 5.2
var paused := false
var capture_frames := 0
var capture_mode := false
func _ready() -> void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_size(Vector2i(1100,900))
 var host = load("res://scripts/champion_model.gd").new()
 add_child(host)
 host.build("Vanguard", Color("4079bb"))
 model = host.vanguard_art.model
 for node in model.find_children("*","Node",true,false):
  if node is AnimationPlayer:player=node
 for clip in player.get_animation_list():player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
 player.play("Idle")
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("111522")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("8090b3")
 env.environment.ambient_light_energy=.30
 env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 env.environment.glow_enabled=true
 env.environment.glow_hdr_threshold=1.35
 add_child(env)
 add_light(Vector3(-2,4,-3),Color("efedf4"),.65)
 add_light(Vector3(3,2,-1),Color("bacbff"),.28)
 add_light(Vector3(0,3,3),Color("a685dc"),.22)
 var floor_mesh:=MeshInstance3D.new()
 var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
 var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("232a38");floor_mat.roughness=.9;floor_mat.albedo_color=Color(.035,.045,.06)
 floor_mesh.material_override=floor_mat;add_child(floor_mesh)
 # Floor markings make foot contact and scale easy to judge.
 for i in range(-5,6):
  var line:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(5,.002,.006);line.mesh=box;line.position=Vector3(0,.001,i*.5)
  var m:=StandardMaterial3D.new();m.albedo_color=Color("354052");line.material_override=m;add_child(line)
 get_viewport().msaa_3d=Viewport.MSAA_4X
 player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
 camera=Camera3D.new();camera.fov=37;add_child(camera);camera.current=true;update_camera()
 var canvas:=CanvasLayer.new();add_child(canvas)
 var column:=VBoxContainer.new();column.position=Vector2(24,20);canvas.add_child(column)
 var title:=Label.new();title.text="VANGUARD";title.add_theme_font_size_override("font_size",28);column.add_child(title)
 var hint:=Label.new();hint.text="Drag to orbit  ·  Scroll to zoom  ·  Space to pause";column.add_child(hint)
 var row:=HBoxContainer.new();column.add_child(row)
 for clip in ["Idle","Walk","Run","WalkBackward","StrafeLeft","StrafeRight","Cast","Strike"]:
  var button:=Button.new();button.text=clip.replace("WalkBackward","Backstep").replace("StrafeLeft","Left").replace("StrafeRight","Right")
  button.pressed.connect(func():player.play(clip,.2));row.add_child(button)
 var speed:=HSlider.new();speed.min_value=.25;speed.max_value=1.75;speed.step=.05;speed.value=1;speed.custom_minimum_size=Vector2(280,25)
 speed.value_changed.connect(func(value:float):player.speed_scale=value);column.add_child(speed)
 capture_mode="--vanguard-capture" in OS.get_cmdline_user_args()
func add_light(at:Vector3,color:Color,energy:float)->void:
 var light:=DirectionalLight3D.new();add_child(light);light.position=at;light.look_at(Vector3(0,1,0));light.light_color=color;light.light_energy=energy;light.shadow_enabled=true
func update_camera()->void:
 camera.position=Vector3(sin(yaw)*distance,1.2+sin(pitch)*distance,-cos(yaw)*distance)
 camera.look_at(Vector3(0,1.2,0))
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
  yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.006,-.12,.6);update_camera()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(2.4,distance-.2)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(6,distance+.2)
  update_camera()
 if event is InputEventKey and event.pressed and event.keycode==KEY_SPACE:
  paused=not paused
  if paused:player.pause()
  else:player.play()
func _process(_delta:float)->void:
 if capture_mode:
  capture_frames+=1
  if capture_frames==40:
   player.pause();player.seek(.3,true)
  if capture_frames==44:
   get_viewport().get_texture().get_image().save_png("res://artifacts/vanguard_rebuild_20260908/godot-idle.png")
   get_tree().quit()
