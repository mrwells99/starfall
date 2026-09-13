extends "res://tests/null_locomotion_test.gd"
## Live Null rapid-reversal regression; ordinary poses must match guard-disabled B.
var baseline
var baseline_art
var normal_pose_differences := 0
var normal_guard_uses := 0
var guard_uses := 0
var cases := []
var measured_frames := 0
var bounded_burst_frames := 0

func step_pair(sector:int,low:bool,delta:float,compare_normal:bool=false) -> void:
	var speed:=0.0 if sector<0 else (3.591 if sector in [3,4,5] else 6.1425)
	if low:speed*=.8
	set_motion(maxi(0,sector),speed,low,false,false,false,0.0,false,delta)
	baseline.transform=actors[1].transform
	baseline.velocity=actors[1].velocity
	baseline.presentation_velocity=actors[1].presentation_velocity
	baseline.presentation_grounded=true;baseline.presentation_vertical_speed=0
	baseline.identity.stealth=low;baseline.casting=-1;baseline.stunned=0;baseline.hp=baseline.MAX_HEALTH
	for i in 2:
		var before:=gameplay(actors[i])
		if i==0:
			actors[i].champion_model.animate(delta,actors[i]);actors[i].body_hitboxes.update()
		else:actors[i].update_hitboxes(delta)
		gameplay_unchanged=gameplay_unchanged and before==gameplay(actors[i])
	baseline.update_hitboxes(delta)
	for point in actors[0].body_hitboxes.points.size():
		var a:Vector3=actors[0].body_hitboxes.points[point]
		var b:Vector3=actors[1].body_hitboxes.points[point]
		check(a.is_finite() and b.is_finite(),"Rapid reversal endpoints stay finite")
		max_endpoint_error=maxf(max_endpoint_error,a.distance_to(b))
	if compare_normal:
		for bone in arts[1].skeleton.get_bone_count():
			if arts[1].skeleton.get_bone_pose(bone)!=baseline_art.skeleton.get_bone_pose(bone):normal_pose_differences+=1
	for art in [arts[0],arts[1],baseline_art]:
		for side in ["L","R"]:
			var solver=art.pose_blend.leg_solver
			var leg:Dictionary=solver.legs[side]
			var hip:Vector3=art.skeleton.get_bone_global_pose(leg.thigh).origin
			var knee:Vector3=art.skeleton.get_bone_global_pose(leg.shin).origin
			var ankle:Vector3=art.skeleton.get_bone_global_pose(leg.foot).origin
			check(absf(hip.distance_to(knee)-leg.upper_length)<.00001 and absf(knee.distance_to(ankle)-leg.lower_length)<.00001,"Spam preserves accepted leg lengths")
	measured_frames+=1

func seed_motion_live(sector:int,low:bool,phase:float,delta:float) -> void:
	step_pair(sector,low,delta)
	for art in [arts[0],arts[1],baseline_art]:
		art.player.seek(phase*art.player.current_animation_length,true);art.player.advance(0)
		art.equipment.apply();art.pose_blend.duration=0;art.pose_blend.elapsed=1
		art.special_blend.duration=0;art.special_blend.elapsed=1
		art.pending_target="";art.pose_blend.ready=false;art.pose_blend.pending=false;art.pose_blend.inertial_enabled=false
		art.pose_blend.clear_velocity_history();art.pose_blend.leg_solver.reset()
		art.pose_blend.finish_frame(delta)
		art.filtered_speed=actors[1].velocity.length()
		art.player.speed_scale=art.override_playback_rate(art.clip,1)
	step_pair(sector,low,delta);step_pair(sector,low,delta)

func leg_rotations(art) -> Array:
	var result:=[]
	for name in ["DEF-thigh.L","DEF-shin.L","DEF-thigh.R","DEF-shin.R"]:
		result.append(art.skeleton.get_bone_pose_rotation(art.skeleton.find_bone(name)))
	return result

func burst(fps:int,interval:float,low:bool,phase:float) -> void:
	var delta:=1.0/fps
	seed_motion_live(6,low,phase,delta)
	var previous:=[leg_rotations(arts[1]),leg_rotations(baseline_art)]
	var peaks:=[0.0,0.0]
	var settled_peaks:=[0.0,0.0]
	var foot_ceiling:=-INF
	for suffix in ["Left","Right"]:
		for row in arts[1].phase_data.clips[("Low" if low else "Travel")+suffix].samples:
			for foot in row.feet:foot_ceiling=maxf(foot_ceiling,foot.y)
	var last_burst_frames:int=arts[1].pose_blend.burst_leg_frames
	var every:=maxi(1,roundi(interval*fps))
	for frame in fps*6:
		var sector:int=(6 if (frame/every)%2==0 else 2) if frame<fps*5 else -1
		step_pair(sector,low,delta)
		for variant in 2:
			var current:=leg_rotations(arts[1] if variant==0 else baseline_art)
			for joint in 4:peaks[variant]=maxf(peaks[variant],rad_to_deg(qangle(previous[variant][joint],current[joint])))
			previous[variant]=current
			if frame>=fps and frame<fps*5:
				var rig:Skeleton3D=(arts[1] if variant==0 else baseline_art).skeleton
				var lower_foot:=minf(rig.get_bone_global_pose(rig.find_bone("DEF-foot.L")).origin.y,rig.get_bone_global_pose(rig.find_bone("DEF-foot.R")).origin.y)
				settled_peaks[variant]=maxf(settled_peaks[variant],lower_foot)
				if variant==0:
					check(lower_foot<=foot_ceiling+.03,"Sustained spam cannot pump both feet above the authored foot-height envelope")
					bounded_burst_frames+=1
	var used:int=arts[1].pose_blend.leg_solver.continuity_limited_solves
	guard_uses+=used
	check(not arts[1].pose_blend.burst_guard_active and arts[1].pose_blend.leg_solver.continuity_max_angle==0,"Guard releases after spam settles to idle")
	check(arts[1].pose_blend.burst_leg_frames>last_burst_frames,"Rapid input exercises the non-extrapolating burst blend")
	cases.append({"fps":fps,"interval_s":interval,"low":low,"phase":phase,"guard_uses":used,"guarded_max_leg_step_deg":peaks[0],"baseline_max_leg_step_deg":peaks[1],"settled_lower_foot_m":settled_peaks[0],"baseline_settled_lower_foot_m":settled_peaks[1],"authored_foot_ceiling_m":foot_ceiling})

func run() -> void:
	setup_pair()
	baseline=Fighter.new();root.add_child(baseline);baseline.setup(3,3,0,"Null",false);baseline.setup_hitboxes()
	baseline_art=baseline.hitbox_pose.art;baseline_art.pose_blend.burst_guard_enabled=false
	baseline.transform=actors[1].transform;baseline.presentation_grounded=true
	for low in [false,true]:
		for sector in 8:
			for phase in [0.0,.333,.667]:
				for pair in [[-1,sector],[sector,-1],[sector,(sector+1)%8],[sector,(sector+4)%8]]:
					seed_motion_live(pair[0],low,phase,STEP)
					for frame in 42:step_pair(pair[1],low,STEP,true)
					normal_guard_uses+=arts[1].pose_blend.leg_solver.continuity_limited_solves
	check(normal_guard_uses==0,"No safeguard activation in 192 ordinary transition controls")
	check(normal_pose_differences==0,"All ordinary control poses remain exactly equal to guard-disabled refined B")
	for fps in [30,60,144]:
		for low in [false,true]:
			for interval in [.0333333333,.05,.1]:
				for phase in [.0,.667]:burst(fps,interval,low,phase)
	check(guard_uses>0,"Repeated reversals actually exercise knee continuity protection")
	check(max_endpoint_error<.0005,"Rapid reversals preserve visible/server hitbox agreement")
	check(gameplay_unchanged,"Guard does not write gameplay state")
	for art in arts:
		art.pose_blend.rapid_interruptions=2;art.pose_blend.burst_guard_active=true
		art.pose_blend.clear_velocity_history()
		check(art.pose_blend.rapid_interruptions==0 and not art.pose_blend.burst_guard_active and art.pose_blend.leg_solver.continuity_max_angle==0,"Teleport/death/invalid-frame history clear also clears burst guard")
	var data:={"engine":Engine.get_version_info().string,"frames":measured_frames,"bounded_burst_frames":bounded_burst_frames,"normal_controls":192,"normal_pose_differences":normal_pose_differences,"normal_guard_uses":normal_guard_uses,"guard_uses":guard_uses,"maximum_endpoint_error_m":max_endpoint_error,"cases":cases}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			var file:=FileAccess.open(arg.trim_prefix("--qa-output="),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	print("NULL_RAPID_SUMMARY ",JSON.stringify({"frames":measured_frames,"normal_pose_differences":normal_pose_differences,"normal_guard_uses":normal_guard_uses,"guard_uses":guard_uses,"max_endpoint_error_m":max_endpoint_error}))
	for message in messages:push_error(message)
	print("Null rapid transition checks: %d passed / %d total" % [checks-failures,checks])
	for actor in actors:actor.free()
	baseline.free();quit(1 if failures else 0)
