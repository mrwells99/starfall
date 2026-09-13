extends "res://tests/null_rapid_transition_test.gd"
## Compare follow-through to the same 0.31s base, not the old runaway blending.
var base_history_errors := 0
var max_follow_m := 0.0
var max_follow_angle := 0.0
var follow_samples := 0

func step_pair(sector:int,low:bool,delta:float,compare_normal:bool=false) -> void:
	baseline_art.pose_blend.burst_guard_enabled=true
	baseline_art.pose_blend.follow_enabled=false
	super.step_pair(sector,low,delta,compare_normal)
	var blend=arts[1].pose_blend
	var control=baseline_art.pose_blend
	# Tests the anti-feedback boundary directly: cosmetic carry cannot change the
	# next frame's pose, velocity/foot history, phase selection or base knee solver.
	if blend.burst_guard_active:
		if blend.displayed_pose!=control.displayed_pose or blend.current_feet!=control.current_feet or blend.previous_feet!=control.previous_feet:
			base_history_errors+=1
		check(arts[1].last_transition==baseline_art.last_transition,"Carry never changes selected base phase/transition")
	for side in 2:
		check(blend.follow_velocity[side].length()<=blend.FOLLOW_MAX_SPEED+.00001,"Captured carry velocity stays below its speed limit")
		var label:="L" if side==0 else "R"
		var leg:Dictionary=blend.leg_solver.legs[label]
		var actual:Vector3=arts[1].skeleton.get_bone_global_pose(leg.foot).origin
		var base:Vector3=baseline_art.skeleton.get_bone_global_pose(leg.foot).origin
		var displacement:=actual-base
		max_follow_m=maxf(max_follow_m,displacement.length())
		check(displacement.length()<=blend.FOLLOW_MAX_DISTANCE+.00001,"Actual foot deviation stays inside the carry distance cap")
		check(displacement.y>=-.00201,"Follow-through cannot push the foot down through its base support")
		for bone in [leg.thigh,leg.shin]:
			var angle:=qangle(arts[1].skeleton.get_bone_pose_rotation(bone),baseline_art.skeleton.get_bone_pose_rotation(bone))
			max_follow_angle=maxf(max_follow_angle,angle)
			check(angle<=blend.FOLLOW_MAX_ANGLE+.00001,"Final knee/thigh correction respects its angle cap")
		if displacement.length()>.00001:follow_samples+=1
	check(base_history_errors==0,"Displayed follow-through never feeds the base pose/velocity history")

func run() -> void:
	await super.run()
	print("NULL_FOLLOW_SUMMARY ",JSON.stringify({"base_history_errors":base_history_errors,"maximum_actual_foot_carry_m":max_follow_m,"maximum_leg_carry_degrees":rad_to_deg(max_follow_angle),"nonzero_follow_samples":follow_samples}))
	# Parent schedules quit; final failures replace its exit code before returning.
	check(follow_samples>0,"The bounded follow-through is actually visible, not a no-op")
	check(base_history_errors==0,"Sustained reversals leave the base history exactly equal")
	for art in arts:
		check(art.pose_blend.follow_elapsed>=art.pose_blend.FOLLOW_SECONDS and art.pose_blend.follow_base_pose.is_empty() and art.pose_blend.follow_offset==PackedVector3Array([Vector3.ZERO,Vector3.ZERO]),"History invalidation removes all follow-through state")
	print("Null follow-through checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
