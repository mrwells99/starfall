extends SceneTree
var checks:=0
var failures:=0
func ck(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
	var visible=load("res://scripts/combatant.gd").new();root.add_child(visible);visible.setup(1,1,0,"Fulcrum")
	var server=load("res://scripts/combatant.gd").new();root.add_child(server);server.setup(2,2,0,"Fulcrum",false)
	visible.setup_hitboxes();server.setup_hitboxes()
	var art=visible.champion_model.fulcrum_art
	ck(server.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),"Compact gesture playback adds no render meshes")
	var maximum:=0.0;var microseconds:=0;var samples:=0;var smooth_frames:=0
	var previous:Quaternion=Quaternion.IDENTITY
	for state in ["right","left","divide","charge_cancel","moving","airborne","instant","stunned"]:
		for actor in [visible,server]:actor.reset_identity();actor.casting=-1;actor.stunned=0
		for frame in 60:
			var t:=frame/60.0;var reported:=floorf(t*20)/20
			for actor in [visible,server]:
				actor.presentation_snapshot_serial=1+int(t*20)
				actor.presentation_grounded=state!="airborne";actor.velocity.y=7-20*t if state=="airborne" else 0
				actor.presentation_vertical_speed=actor.velocity.y
				if state=="moving":actor.position+=Vector3.LEFT*.05
				var charging:bool=state in ["divide","charge_cancel"] and t<(.15 if state=="charge_cancel" else .3)
				actor.casting=12 if charging else -1;actor.cast_duration=.3;actor.cast_left=.3-reported if charging else 0
				var kind:="ruin_left" if state=="left" else ("divide" if state in ["divide","instant"] else "ruin_right")
				var start:=.3 if state=="divide" else 0.0
				var age:=reported-start
				actor.identity.fulcrum_slashes=[] if charging or state=="charge_cancel" or age>.6 else [{"serial":checks+1,"kind":kind,"age":age}]
				actor.identity.fulcrum_action_left=maxf(0,.3-age)
				actor.stunned=1.0 if state=="stunned" and t>.1 else 0
			visible.champion_model.animate(1.0/60,visible);visible.body_hitboxes.update()
			var begin:=Time.get_ticks_usec();server.update_hitboxes(1.0/60);microseconds+=Time.get_ticks_usec()-begin;samples+=1
			for i in visible.body_hitboxes.points.size():maximum=maxf(maximum,visible.body_hitboxes.points[i].distance_to(server.body_hitboxes.points[i]))
			var pose:Quaternion=art.skeleton.get_bone_pose_rotation(art.skeleton.find_bone("DEF-forearm.R"))
			if state=="right" and frame>3 and frame<14 and frame%3!=0 and pose.angle_to(previous)>.0001:smooth_frames+=1
			previous=pose
		ck(maximum<.0005,"Visible and server body agree within 0.5mm: "+state)
	ck(smooth_frames>=4,"Command poses interpolate between held 20Hz updates")
	ck(art.command_pose.key.is_empty(),"Stun cancels the command layer")
	print("Fulcrum pose maximum endpoint error: ",maximum," m; complete compact pose update mean: ",float(microseconds)/samples," us")
	visible.queue_free();server.queue_free();await process_frame
	print("Fulcrum command pose checks: %d passed / %d total"%[checks-failures,checks]);quit(1 if failures else 0)
