extends SceneTree
## Actual runtime review on the secondary monitor, capped while the owner games.
var stage: Node3D
var actor
var art
var camera: Camera3D
var camera_home := Vector3.ZERO
var status: Label
var picker: OptionButton
var title := "Null"
var ready := false
var playback_paused := false
var step := 0
var elapsed := 0.0
var sequence := [
 ["Idle",.7,Vector3.ZERO,0.0], ["Walk",1.4,Vector3.FORWARD,1.2],
 ["Run",1.1,Vector3.FORWARD,4.0], ["Sprint",1.0,Vector3.FORWARD,6.5],
 ["Left",.8,Vector3.LEFT,6.5], ["Right",.8,Vector3.RIGHT,6.5],
 ["Forward diagonal",.8,Vector3(-1,0,-1).normalized(),4.0],
 ["Backpedal",1.2,Vector3.BACK,3.8], ["Backward diagonal",.8,Vector3(1,0,1).normalized(),3.8],
 ["Idle",.35,Vector3.ZERO,0.0], ["Jump",.7,Vector3.ZERO,0.0],
 ["Landing",.35,Vector3.ZERO,0.0], ["Casting",1.5,Vector3.ZERO,0.0],
 ["Recovery",1.2,Vector3.ZERO,0.0], ["Quick left",.08,Vector3.LEFT,6.5],
 ["Quick right",.08,Vector3.RIGHT,6.5], ["Stealth",1.5,Vector3.FORWARD,2.5], ["Lift",.5,Vector3.ZERO,0.0],
 ["Dive",.45,Vector3.ZERO,0.0], ["Recover",.3,Vector3.ZERO,0.0], ["Stab",.7,Vector3.ZERO,0.0], ["Idle",.6,Vector3.ZERO,0.0]]

func _initialize() -> void: call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://artifacts/null-forge-v2/model-review/")
 Engine.max_fps=30
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_current_screen(0)
 DisplayServer.window_set_size(Vector2i(1000,900))
 DisplayServer.window_set_position(DisplayServer.screen_get_position(0)+Vector2i(50,60))
 DisplayServer.window_set_title("Starfall · Null model review")
 stage=Node3D.new();stage.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;root.add_child(stage)
 var env:=WorldEnvironment.new(); env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("161a25")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("bdc9ec"); env.environment.ambient_light_energy=.65; stage.add_child(env)
 for i in 2:
  var light:=DirectionalLight3D.new();stage.add_child(light)
  light.rotation_degrees=Vector3(-35,-25 if i==0 else 135,0);light.light_energy=1.3 if i==0 else .65
 var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(12,12)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("303547");floor_mesh.material_override=mat;stage.add_child(floor_mesh)
 camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=34
 set_view("Front")
 var layer:=CanvasLayer.new();stage.add_child(layer)
 var column:=VBoxContainer.new();column.position=Vector2(20,15);layer.add_child(column)
 var label:=Label.new();label.text="STARFALL · MODEL FORGE V2";label.add_theme_font_size_override("font_size",23);column.add_child(label)
 picker=OptionButton.new()
 for name in ["Null"]:picker.add_item(name)
 picker.item_selected.connect(func(index):select_class(picker.get_item_text(index)))
 column.add_child(picker)
 var buttons:=HBoxContainer.new();column.add_child(buttons)
 for view in ["Front","Back","Side","Three-quarter"]:
  var b:=Button.new();b.text=view;b.pressed.connect(func():set_view(view));buttons.add_child(b)
 var poses:=OptionButton.new();column.add_child(poses)
 for entry in sequence:poses.add_item(entry[0])
 poses.item_selected.connect(func(index):step=index;elapsed=0;playback_paused=false)
 var pause_button:=Button.new();pause_button.text="Pause / resume";pause_button.pressed.connect(func():playback_paused=not playback_paused);column.add_child(pause_button)
 status=Label.new();column.add_child(status)
 select_class("Null")
 if "--capture" in OS.get_cmdline_user_args():
  for name in ["Null"]:
   select_class(name)
   for view in ["Front","Back","Side"]:
    set_view(view);simulate("Idle",.45,Vector3.ZERO,0)
    await capture(view.to_lower())
   set_view("Three-quarter")
   for item in [["walk-a","Walk",.25,Vector3.FORWARD,1.2],["walk-b","Walk",.85,Vector3.FORWARD,1.2],
                ["run-a","Run",.20,Vector3.FORWARD,4.0],["run-b","Run",.65,Vector3.FORWARD,4.0],
                ["backpedal","Backpedal",.45,Vector3.BACK,3.8],["side-run","Left",.35,Vector3.LEFT,6.5],
                ["stealth","Stealth",.8,Vector3.FORWARD,2.5],["lift","Lift",.45,Vector3.ZERO,0],
                ["dive","Dive",.25,Vector3.ZERO,0],["recover","Recover",.10,Vector3.ZERO,0],
                ["stab","Stab",.25,Vector3.ZERO,0],["jump-apex","Jump",.35,Vector3.ZERO,0]]:
    simulate(item[1],item[2],item[3],item[4]);await capture(item[0])
  print("MODEL_FORGE_REVIEW_CAPTURED")
  stage.queue_free();await process_frame;quit();return
 ready=true;process_frame.connect(tick)
 print("MODEL_FORGE_REVIEW_READY screen=",DisplayServer.window_get_current_screen())

func set_view(view: String) -> void:
 camera.position={"Front":Vector3(0,1.55,-5.5),"Back":Vector3(0,1.55,5.5),"Side":Vector3(5.5,1.55,0),"Three-quarter":Vector3(2.7,1.8,-5.3)}[view]
 camera_home=camera.position
 camera.look_at(Vector3(0,1.08,0))

func select_class(name: String) -> void:
 if actor!=null:
  stage.remove_child(actor);actor.queue_free()
 title=name;actor=load("res://scripts/combatant.gd").new();stage.add_child(actor);actor.setup(1,1,0,name)
 picker.select(["Null"].find(name))
 actor.set_physics_process(false);actor.set_process(false)
 for node in [actor.nameplate,actor.health_pivot]:
  if is_instance_valid(node):node.visible=false
 art=actor.champion_model.get(name.to_lower()+"_art")
 actor.presentation_grounded=true
 step=0;elapsed=0
 pose("Idle",0,.016,Vector3.ZERO,0)

func pose(label: String,t: float,delta: float,direction: Vector3,velocity: float) -> void:
 var jumping:=label in ["Jump","Lift","Dive"]
 actor.identity.stealth=label=="Stealth"
 actor.identity.null_vantage={"phase":label.to_lower(),"elapsed":t,"direction":Vector3(0,-1,-1).normalized()} if label in ["Lift","Dive","Recover"] else {}
 if label=="Stab" and art.active_actor!=null and art.strike_left<=0 and t<.1:
  actor.identity.null_action="stab";actor.identity.null_action_serial+=1
 actor.presentation_grounded=not jumping
 actor.presentation_vertical_speed=7.0-20.0*t if jumping else 0.0
 actor.position=Vector3(0,maxf(0,7*t-10*t*t) if jumping else 0,0)
 art.last_position=actor.position-direction*velocity*delta
 actor.casting=0 if label=="Casting" else -1
 actor.cast_left=maxf(0,1.5-t) if actor.casting>=0 else 0
 actor.champion_model.animate(delta,actor)
 art.visibility_for(actor,actor)
 camera.position=camera_home+Vector3.UP*actor.position.y*.65
 camera.look_at(Vector3(0,1.08+actor.position.y*.65,0))
 status.text=title+" · "+label

func simulate(label: String,time: float,direction: Vector3,velocity: float) -> void:
 actor.casting=-1;art.was_casting=false;art.was_airborne=false;art.transient_left=0
 pose("Idle",0,.2,Vector3.ZERO,0)
 var at:=0.0
 while at<time-.000001:
  var delta:=minf(1.0/60,time-at);at+=delta
  pose(label,at,delta,direction,velocity)

func tick() -> void:
 if not ready or playback_paused:return
 var delta:=minf(root.get_process_delta_time(),.1)
 elapsed+=delta
 if elapsed>=sequence[step][1]:elapsed=0;step=(step+1)%sequence.size()
 var entry:Array=sequence[step]
 pose(entry[0],elapsed,delta,entry[2],entry[3])

func capture(label: String) -> void:
 art.skeleton.force_update_all_bone_transforms()
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/null-forge-v2/model-review/"+label+".png")
 for node in stage.get_children():
  if node.name.begins_with("ReviewJoint"):node.queue_free()
