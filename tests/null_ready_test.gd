extends "res://tests/null_locomotion_test.gd"
## Full selected idle cycle on real visible/compact presenters, with original equipment.
func run()->void:
	setup_pair()
	var resource:AnimationLibrary=load("res://assets/animations/null_ready.res")
	check(resource.get_animation_list().size()==1 and resource.has_animation("Ready"),"Only the selected Ready clip ships")
	check(resource.get_meta("approved_option")=="K+","Owner selected K+")
	var source=load("res://assets/animations/null_locomotion.res")
	var common:Dictionary=load("res://assets/animations/null_transition_features.res").get_meta("data")
	for art in arts:
		check(art.clip_names.Ready=="null_ready/Ready","Actual presenter selects new idle")
		var idle_length:float=resource.get_animation("Ready").length/preload("res://scripts/null_ready.gd").PLAYBACK_SCALE
		check(is_equal_approx(art.player.get_animation(art.clip_names.Ready).length,idle_length),"K+ playback includes current speed tuning")
		check(art.phase_data.clips.Ready.samples.size()==48,"Updated baked idle phase features")
		check(is_equal_approx(art.phase_data.clips.Ready.samples[47].time,idle_length*47.0/48.0),"Phase features follow idle speed tuning")
		for name in common.clips:
			if name!="Ready":check(art.phase_data.clips[name]==common.clips[name],"Other state phase features unchanged")
	check(common.clips.Ready.samples[47].time<2.0,"Shared old idle metadata not mutated")
	settle("idle-entry",0,0,"Ready",false,false,false,90)
	var feet:=[]
	for side in ["L","R"]:feet.append(arts[1].skeleton.get_bone_global_pose(arts[1].skeleton.find_bone("DEF-foot."+side)).origin)
	var drift:=0.0
	for frame in 1320:
		set_motion(0,0);animate("K+ long idle")
		for side in 2:
			var p:Vector3=arts[1].skeleton.get_bone_global_pose(arts[1].skeleton.find_bone("DEF-foot."+("L" if side==0 else "R"))).origin
			drift=maxf(drift,p.distance_to(feet[side]))
	check(drift<.00002,"Planted idle feet remain steady through two loops")
	check(gameplay_unchanged,"Idle presentation never changes gameplay fields")
	check(max_endpoint_error<.0005,"Visible/server idle endpoints match")
	for index in 2:
		check(capture_rest(arts[index])==rests[index],"All original rest anatomy retained")
	print("Maximum body endpoint difference: ",max_endpoint_error," meters")
	print("Idle foot drift: ",drift," meters; blade offset: ",max_blade_position_error," meters")
	for actor in actors:actor.free()
	for title in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw"]:
		var actor=Fighter.new();root.add_child(actor);actor.setup(3,2,0,title,false);actor.setup_hitboxes()
		var art=actor.hitbox_pose.art
		check(art.player.has_animation_library("shared_ready"),title+" uses its carrying variant of the approved idle")
		check(is_equal_approx(art.player.get_animation(art.clip_names.Ready).length,resource.get_animation("Ready").length/preload("res://scripts/null_ready.gd").PLAYBACK_SCALE),title+" shares Null's latest idle timing")
		actor.free()
	for message in messages:push_error(message)
	print("Null ready checks: %d passed / %d total"%[checks-failures,checks])
	quit(1 if failures else 0)
