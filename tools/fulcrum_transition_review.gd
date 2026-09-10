extends "res://tools/fulcrum_jump_review.gd"
## Exercise real presentation selection and layers in place, without gameplay.
var sequence = [
 ["Idle",.6,Vector3.ZERO,0.0],
 ["Walking",.8,Vector3.FORWARD,1.2],
 ["Jogging",.8,Vector3.FORWARD,4.0],
 ["Running",.8,Vector3.FORWARD,6.5],
 ["Forward diagonal",.7,Vector3(-1,0,-1).normalized(),6.5],
 ["Running left",.8,Vector3.LEFT,6.5],
 ["Running right",.8,Vector3.RIGHT,6.5],
 ["Backward right",.7,Vector3(1,0,1).normalized(),3.8],
 ["Backward",.7,Vector3.BACK,3.8],
 ["Backward left",.7,Vector3(-1,0,1).normalized(),3.8],
 ["Idle",.4,Vector3.ZERO,0.0],
 ["Jump",.7,Vector3.ZERO,0.0],
 ["Landing",.35,Vector3.ZERO,0.0],
 ["Casting",1.0,Vector3.ZERO,0.0],
 ["Cast recovery",1.4,Vector3.ZERO,0.0],
 ["Quick left",.08,Vector3.LEFT,6.5],
 ["Quick right",.08,Vector3.RIGHT,6.5],
 ["Quick left",.08,Vector3.LEFT,6.5],
 ["Quick right",.08,Vector3.RIGHT,6.5],
 ["Idle",.6,Vector3.ZERO,0.0]]
var sequence_index := 0
var sequence_elapsed := 0.0
var captured: Dictionary = {}
func run() -> void:
 await super.run()
 DisplayServer.window_set_title("Fulcrum — smooth transition review")
 if "--transition-capture" in OS.get_cmdline_user_args():DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 for node in stage.find_children("*","Label",true,false):
  if node.text=="FULCRUM · JUMP ARC":node.text="FULCRUM · TRANSITIONS"
  if node.text.begins_with("Bent elbows"):node.text="Automatic movement / jump / cast sequence"
 print("FULCRUM_TRANSITION_REVIEW_READY screen=",DisplayServer.window_get_current_screen())
func tick() -> void:
 var now:=Time.get_ticks_usec(); var delta:=minf((now-last_tick)/1000000.0,.1)*speed; last_tick=now
 if not ready or playback_paused:return
 sequence_elapsed+=delta
 while sequence_elapsed>=float(sequence[sequence_index][1]):
  sequence_elapsed-=float(sequence[sequence_index][1])
  sequence_index=(sequence_index+1)%sequence.size()
 pose_at(sequence_elapsed,delta)
 if "--transition-capture" in OS.get_cmdline_user_args() and sequence_index==6:
  for sample in [[0.0,"direction-start"],[.055,"direction-middle"],[.13,"direction-settled"]]:
   if sequence_elapsed>=sample[0] and not captured.has(sample[1]):
    captured[sample[1]]=true
    capture_transition(sample[1])
    break
func pose_at(t:float,delta:float) -> void:
 var entry: Array = sequence[sequence_index]
 var jumping: bool=entry[0]=="Jump"
 actor.presentation_grounded=not jumping
 actor.presentation_vertical_speed=7.0-20.0*t if jumping else 0.0
 actor.position=Vector3(0,maxf(0,7*t-10*t*t) if jumping else 0.0,0)
 # Feed the real selector a measured displacement while keeping this
 # inspection model centered. The production actor movement is untouched.
 var art=actor.champion_model.fulcrum_art
 art.last_position=actor.position-Vector3(entry[2])*float(entry[3])*delta
 actor.casting=0 if entry[0]=="Casting" else -1
 actor.cast_left=maxf(0,float(entry[1])-t) if actor.casting>=0 else 0.0
 actor.champion_model.animate(delta,actor)
 status.text="%s · %.0f%% playback" % [entry[0],speed*100]
func capture_transition(label:String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/fulcrum-blend-r005/"+label+".png")
 if label=="direction-settled":
  ready=false
  print("FULCRUM_TRANSITION_REVIEW_CAPTURED");stage.queue_free();await process_frame;quit()
