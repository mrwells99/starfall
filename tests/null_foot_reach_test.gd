extends "res://tests/null_follow_through_test.gd"
## Inherits full ordinary/burst, visible/server and independent-carry regressions.
var bounded_plant_samples := 0
var max_plant_excess := 0.0

func step_pair(sector:int,low:bool,delta:float,compare_normal:bool=false) -> void:
	super.step_pair(sector,low,delta,compare_normal)
	for art in arts:
		var blend=art.pose_blend
		for side in 2:
			var limit:float=blend.plant_limits[side]
			if not is_finite(limit):continue
			var leg:Dictionary=blend.leg_solver.legs["L" if side==0 else "R"]
			var reach:Vector3=art.skeleton.get_bone_global_pose(leg.foot).origin-art.skeleton.get_bone_global_pose(leg.thigh).origin
			reach.y=0.0
			max_plant_excess=maxf(max_plant_excess,reach.length()-limit)
			check(reach.length()<=limit+.00002,"Final foot, including follow-through, respects the horizontal planting envelope")
			bounded_plant_samples+=1

func run() -> void:
	await super.run()
	check(bounded_plant_samples>0,"Rapid reversals exercise the planting envelope")
	check(arts[1].pose_blend.plant_limit_frames>0,"The new reach limit actually trims outer-edge poses")
	for art in arts:
		check(not is_finite(art.pose_blend.plant_limits[0]) and not is_finite(art.pose_blend.plant_limits[1]),"History reset clears the planting envelope")
	print("NULL_PLANT_SUMMARY ",JSON.stringify({"bounded_foot_samples":bounded_plant_samples,"maximum_excess_m":max_plant_excess,"limit_uses":arts[1].pose_blend.plant_limit_frames}))
	print("Null foot reach checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
