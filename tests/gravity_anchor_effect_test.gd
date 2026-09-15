extends SceneTree
const FX=preload("res://scripts/fulcrum_effects.gd")
var checks:=0
var failures:=0
func ck(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var stage:=Node3D.new();root.add_child(stage)
 var a:=FX.new();var b:=FX.new();stage.add_child(a);stage.add_child(b)
 a.set_process(false);b.set_process(false)
 var state:={"anchor_left":3.0,"anchor_pos":Vector3(1,0,2),"anchor_age":.2,"anchor_serial":1,"anchor_kind":"anchor_compression","gravity_field":{},"fulcrum_slashes":[],"gravity_rifts":[]}
 var before:=state.duplicate(true);a.paint_state(state,0)
 ck(state==before,"Effects never mutate replicated combat state")
 ck(a.core.visible and a.spike.visible and not a.blast.visible,"Compression displays a black hole and spike")
 ck(a.core.position.is_equal_approx(state.anchor_pos+Vector3.UP*.7),"Anchor effects retain their ground location")
 var other:=state.duplicate(true);other.anchor_kind="anchor_expansion";other.anchor_pos=Vector3(4,0,-2)
 b.paint_state(other,0)
 ck(b.blast.visible and b.blast.mesh is SphereMesh,"Expansion is a three-dimensional spherical blast")
 ck(is_equal_approx(b.blast.scale.x,3.6),"Blast size matches damage radius")
 ck(a.core.position!=b.core.position,"Concurrent effects retain independent positions")
 state.anchor_left=0;state.gravity_field={"position":Vector3.ZERO,"age":1.1,"left":5.0}
 a.reduced=true;a.paint_state(state,0)
 ck(not a.spike.visible and a.grass.visible,"Dark Growth consumes the anchor presentation")
 ck(a.grass.multimesh.visible_instance_count==480 and a.field_boundary.scale.x==6,"Reduced effects still show the full six-meter grass radius")
 for kind in ["ruin_right","ruin_left","divide"]:
  for progress in [.05,.3,.7,.95]:
   var orientation:=Basis.from_euler(FX.sword_rotation(kind,progress))
   var next:=Basis.from_euler(FX.sword_rotation(kind,progress+.001))
   var travel:=(-next.z+orientation.z).normalized()
   ck(absf(travel.dot(orientation.x))>.999,"Blade edge leads "+kind+" at "+str(progress))
 ck(FX.sword_opacity(0,false)==0 and FX.sword_opacity(.018,false)==1,"Ruin appears within eighteen milliseconds")
 ck(FX.sword_opacity(.2851,false)==0,"Ruin vanishes within twenty-five milliseconds after the slash")
 ck(FX.sword_opacity(.5,true)>0 and FX.sword_opacity(.96,true)==0,"Divide retains gradual disappearance")
 state.gravity_field={};state.fulcrum_slashes=[{"serial":8,"kind":"ruin_right","position":Vector3.ZERO,"yaw":0.0,"age":.08}]
 a.paint_state(state,0,1,0)
 var prior:Vector3=a.slashes[8].pivot.rotation
 a.paint_state(state,1.0/60,1,0)
 ck(a.slashes[8].pivot.rotation!=prior,"Sword animation advances between held 20Hz snapshots")
 ck(a.find_children("*","CollisionObject3D",true,false).is_empty(),"Presentation adds no gameplay collision objects")
 state.fulcrum_slashes=[];a.paint_state(state,0)
 ck(a.slashes.is_empty(),"Consumed slash state cleans up visuals")
 stage.queue_free();await process_frame
 print("Gravity Anchor checks: %d passed / %d total"%[checks-failures,checks]);quit(1 if failures else 0)
