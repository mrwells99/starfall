extends Node3D
var model: Node3D
var player: AnimationPlayer
var camera: Camera3D
var yaw := -0.35
var pitch := 0.10
var distance := 4.6
var paused := false
var capture_frames := 0
var capture_mode := false
var review_speed := 1.0
var skeleton: Skeleton3D
var pose_blend = preload("res://scripts/fulcrum_pose_blend.gd").new()
func _ready() -> void:
 Engine.max_fps = 30
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_current_screen(0)
 DisplayServer.window_set_size(Vector2i(800,850))
 DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(1080,70))
 DisplayServer.window_set_title("Fulcrum — Universal Animation Library review")
 model = load("res://assets/characters/fulcrum.glb").instantiate()
 add_child(model)
 model.rotation.y = PI
 for node in model.find_children("*","Node",true,false):
  if node is AnimationPlayer:player=node
  if node is Skeleton3D:skeleton=node
  if node is MeshInstance3D:
   for i in node.mesh.get_surface_count():
    var material: StandardMaterial3D = node.mesh.surface_get_material(i).duplicate()
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    node.set_surface_override_material(i,material)
 for clip in player.get_animation_list():
  player.get_animation(clip).loop_mode=Animation.LOOP_NONE if clip in ["CastEnter","CastRelease","CastExit","JumpStart","JumpLand"] else Animation.LOOP_LINEAR
 var initial_clip := "WalkBackward" if "--backpedal-review" in OS.get_cmdline_user_args() else "Walk"
 if "--side-turn-review" in OS.get_cmdline_user_args(): initial_clip = "RunLeft"
 player.play(initial_clip)
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 player.advance(0)
 pose_blend.build(skeleton)
 update_playback_speed()
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("111018")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("a4aab6")
 env.environment.ambient_light_energy=.28
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 add_child(env)
 add_light(Vector3(-2,4,-3),Color("e7eaf2"),.65)
 add_light(Vector3(3,2,-1),Color("aab9d1"),.28)
 add_light(Vector3(0,3,3),Color("bca2d8"),.22)
 var floor_mesh:=MeshInstance3D.new()
 var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_mesh.mesh=plane
 var floor_mat:=StandardMaterial3D.new();floor_mat.roughness=.94;floor_mat.albedo_color=Color(.010,.011,.016)
 floor_mesh.material_override=floor_mat;add_child(floor_mesh)
 # Floor markings make foot contact and scale easy to judge.
 for i in range(-5,6):
  var line:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(5,.002,.006);line.mesh=box;line.position=Vector3(0,.001,i*.5)
  var m:=StandardMaterial3D.new();m.albedo_color=Color("252b36");line.material_override=m;add_child(line)
 get_viewport().msaa_3d=Viewport.MSAA_4X
 camera=Camera3D.new();camera.fov=37;add_child(camera);camera.current=true;update_camera()
 var canvas:=CanvasLayer.new();add_child(canvas)
 var column:=VBoxContainer.new();column.position=Vector2(24,20);canvas.add_child(column)
 var title:=Label.new();title.text="FULCRUM  ·  UNIVERSAL RIG";title.add_theme_font_size_override("font_size",24);column.add_child(title)
 var hint:=Label.new();hint.text="Drag to orbit  ·  Scroll to zoom  ·  Space to pause";column.add_child(hint)
 var row:=HBoxContainer.new();column.add_child(row)
 var selector:=OptionButton.new();selector.custom_minimum_size=Vector2(280,34)
 for clip in player.get_animation_list():selector.add_item(clip)
 selector.item_selected.connect(func(index:int):select_clip(selector.get_item_text(index)))
 row.add_child(selector)
 for i in selector.item_count:
  if selector.get_item_text(i)==initial_clip:selector.select(i)
 var replay:=Button.new();replay.text="Replay"
 replay.pressed.connect(func():select_clip(selector.get_item_text(selector.selected),true));row.add_child(replay)
 var note:=Label.new();note.text="Backpedal: reversed walk +15% · Run −10% · Source jumps";column.add_child(note)
 var speed:=HSlider.new();speed.min_value=.25;speed.max_value=1.75;speed.step=.05;speed.value=1;speed.custom_minimum_size=Vector2(280,25)
 speed.value_changed.connect(func(value:float):review_speed=value;update_playback_speed());column.add_child(speed)
 capture_mode="--fulcrum-capture" in OS.get_cmdline_user_args()
 print("FULCRUM_PREVIEW_READY screen=",DisplayServer.window_get_current_screen()," position=",DisplayServer.window_get_position()," clips=",player.get_animation_list().size())
func add_light(at:Vector3,color:Color,energy:float)->void:
 var light:=DirectionalLight3D.new();add_child(light);light.position=at;light.look_at(Vector3(0,1,0));light.light_color=color;light.light_energy=energy;light.shadow_enabled=true
func update_playback_speed()->void:
 var running:=player.current_animation.begins_with("Run") or player.current_animation.begins_with("Sprint")
 var backpedaling:=player.current_animation.begins_with("WalkBackward")
 var cadence:float=preload("res://scripts/fulcrum_art.gd").BACKPEDAL_CADENCE_SCALE if backpedaling else (preload("res://scripts/fulcrum_art.gd").RUN_CADENCE_SCALE if running else 1.0)
 player.speed_scale=review_speed*cadence
func select_clip(next:String,replay:bool=false)->void:
 var previous:=String(player.current_animation)
 var phase:=player.current_animation_position/maxf(player.current_animation_length,.001)
 pose_blend.begin(pose_blend.duration_for(previous,next))
 paused=false;player.play(next,0.0)
 if not replay and pose_blend.is_locomotion(previous) and pose_blend.is_locomotion(next):
  player.seek(phase*player.get_animation(next).length,false)
 elif replay:player.seek(0,false)
 update_playback_speed()
func update_camera()->void:
 camera.position=Vector3(sin(yaw)*distance,1.22+sin(pitch)*distance,-cos(yaw)*distance)
 camera.look_at(Vector3(0,1.22,0))
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
func _process(delta:float)->void:
 if not paused:
  player.advance(delta)
  pose_blend.apply(delta)
 if capture_mode:
  capture_frames+=1
  if capture_frames==40:
   player.pause();player.seek(.3,true)
  if capture_frames==44:
   get_viewport().get_texture().get_image().save_png("res://artifacts/fulcrum/godot-walk.png")
   get_tree().quit()
