extends SceneTree
## All five destinations against the actual approved Null body, including rapid input.
const Fighter=preload("res://scripts/combatant.gd")
const Tuning=preload("res://scripts/movement_tuning.gd")
const SUFFIXES=["Forward","ForwardRight","Right","BackwardRight","Backward","BackwardLeft","Left","ForwardLeft"]
var checks:=0
var failures:=0
var actors:=[]
var arts:=[]
var title:=""
var frames:=0
var class_frames:=0
var maximum_pose_error:=0.0
var maximum_body_error:=0.0
var maximum_grip_error:=0.0
var reports:=[]
var rests:=[]
var shared_bones:=[]

func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(title+": "+message)

func carrying(name:String) -> bool:
	if name.begins_with("DEF-f_") or name.begins_with("DEF-thumb"):return true
	var sides:Array=["L","R"] if title=="Vanguard" else (["R"] if title in ["Luminary","Outlaw"] else (["L"] if title=="Fulcrum" else []))
	for side in sides:
		if name in ["DEF-shoulder."+side,"DEF-upper_arm."+side,"DEF-forearm."+side,"DEF-hand."+side]:return true
	return false

func step(sector:int,walking:bool,delta:float) -> void:
	var speed:=0.0 if sector<0 else (Tuning.BACKWARD_SPEED if sector in [3,4,5] else Tuning.FORWARD_SPEED)
	if walking:speed*=.5
	var direction:=Vector3.ZERO if sector<0 else Vector3(sin(sector*PI/4.0),0,-cos(sector*PI/4.0))
	for index in 3:
		var actor=actors[index]
		actor.walking=walking;actor.velocity=direction*speed;actor.position+=actor.velocity*delta
		actor.presentation_velocity=actor.velocity
		var before:={"transform":actor.transform,"velocity":actor.velocity,"hp":actor.hp,"identity":actor.identity.duplicate(true),"cooldowns":actor.cooldowns.duplicate(),"casting":actor.casting}
		if index==0:
			actor.champion_model.animate(delta,actor);actor.body_hitboxes.update()
		else:actor.update_hitboxes(delta)
		check(before=={"transform":actor.transform,"velocity":actor.velocity,"hp":actor.hp,"identity":actor.identity,"cooldowns":actor.cooldowns,"casting":actor.casting},"Movement presentation does not write gameplay")
		check(arts[index].clip==("Ready" if sector<0 else ("Measured" if walking else "Travel")+SUFFIXES[sector]),"Same approved movement selection")
	for point in actors[0].body_hitboxes.points.size():
		var a:Vector3=actors[0].body_hitboxes.points[point]
		var b:Vector3=actors[1].body_hitboxes.points[point]
		check(a.is_finite() and b.is_finite(),"Finite visible/server body endpoints")
		maximum_pose_error=maxf(maximum_pose_error,a.distance_to(b))
	if class_frames>90:
		for pair in shared_bones:
			var a:Transform3D=arts[1].skeleton.get_bone_global_pose(pair.x)
			var b:Transform3D=arts[2].skeleton.get_bone_global_pose(pair.y)
			for point in [Vector3.ZERO,Vector3(0,.14,0)]:maximum_body_error=maxf(maximum_body_error,(a*point).distance_to(b*point))
	var art=arts[1]
	for side in ["L","R"]:
		var leg:Dictionary=art.pose_blend.leg_solver.legs[side]
		var hip:Vector3=art.skeleton.get_bone_global_pose(leg.thigh).origin
		var knee:Vector3=art.skeleton.get_bone_global_pose(leg.shin).origin
		var ankle:Vector3=art.skeleton.get_bone_global_pose(leg.foot).origin
		check(absf(hip.distance_to(knee)-leg.upper_length)<.00001 and absf(knee.distance_to(ankle)-leg.lower_length)<.00001,"Fixed leg lengths")
	if title in ["Luminary","Vanguard"]:
		var gear=art.equipment
		var weapon:Transform3D=art.skeleton.get_bone_global_pose(gear.weapon)
		if title=="Luminary":maximum_grip_error=maxf(maximum_grip_error,weapon.origin.distance_to(art.skeleton.get_bone_global_pose(gear.hands[1])*Vector3(0,.055,.012)))
		else:
			for side in 2:maximum_grip_error=maxf(maximum_grip_error,(weapon*gear.wrist_offsets[side]).distance_to(art.skeleton.get_bone_global_pose(gear.hands[side]).origin))
	if title=="Fulcrum" and class_frames>90:
		var offset:Vector3=art.skeleton.get_bone_global_pose(art.pose_blend.focus).origin-art.skeleton.get_bone_global_pose(art.pose_blend.hand).origin
		maximum_grip_error=maxf(maximum_grip_error,offset.distance_to(art.pose_blend.carry_offset))
	class_frames+=1;frames+=1

func run() -> void:
	for character in ["Ember","Luminary","Fulcrum","Vanguard","Outlaw"]:
		title=character;actors=[];arts=[];rests=[];shared_bones=[];class_frames=0
		maximum_pose_error=0.0;maximum_body_error=0.0;maximum_grip_error=0.0
		for index in 3:
			var actor=Fighter.new();root.add_child(actor)
			actor.setup(index+1,index+1,0,title if index<2 else "Null",index==0)
			actor.setup_hitboxes();actor.presentation_grounded=true
			actors.append(actor)
			arts.append(actor.champion_model.get(title.to_lower()+"_art") if index==0 else actor.hitbox_pose.art)
			var rest:=[]
			for bone in arts[index].skeleton.get_bone_count():rest.append(arts[index].skeleton.get_bone_rest(bone))
			rests.append(rest)
		check(actors[1].hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),"Server rig remains mesh free")
		for bone in arts[1].skeleton.get_bone_count():
			var name:String=arts[1].skeleton.get_bone_name(bone)
			if (name.begins_with("DEF-") or name=="root") and not carrying(name):shared_bones.append(Vector2i(bone,arts[2].skeleton.find_bone(name)))
		var idle_frames:=1320 if "--long-idle" in OS.get_cmdline_user_args() else 96
		for frame in idle_frames:step(-1,false,1.0/60)
		for art in arts:
			check(is_equal_approx(art.player.get_animation(art.clip_names.Ready).length,preload("res://scripts/null_ready.gd").LIBRARY.get_animation("Ready").length/preload("res://scripts/null_ready.gd").PLAYBACK_SCALE),"Selected shared idle has exactly Null's current timing")
		for sector in [0,6,2,4,-1]:step(sector,false,.001)
		for walking in [false,true]:
			for sector in 8:
				for action in [sector,(sector+4)%8,-1]:
					for frame in 30:step(action,walking,1.0/60)
		for fps in [30,60,144]:
			for frame in fps*3:step(6 if (frame/maxi(1,roundi(fps*.05)))%2==0 else 2,false,1.0/fps)
			for frame in fps:step(-1,false,1.0/fps)
		check(maximum_pose_error<.0005,"Visible/server endpoints match")
		check(maximum_body_error<.00005,"Shared body matches approved Null, excluding carrying chains/grip")
		check(maximum_grip_error<.0001,"Weapon/orb retains required contact")
		check(arts[1].pose_blend.burst_leg_frames>0,"Rapid-input protection and smoothing actually execute")
		for index in 3:
			for bone in rests[index].size():check(rests[index][bone]==arts[index].skeleton.get_bone_rest(bone),"Rest anatomy untouched")
		var row:={"character":title,"frames":class_frames,"pose_error_m":maximum_pose_error,"shared_body_error_m":maximum_body_error,"grip_error_m":maximum_grip_error}
		reports.append(row);print("SHARED_MOVEMENT_CLASS ",JSON.stringify(row))
		for actor in actors:actor.free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):FileAccess.open(arg.trim_prefix("--qa-output="),FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"classes":reports,"frames":frames},"  "))
	print("Shared movement checks: %d passed / %d total"%[checks-failures,checks])
	quit(1 if failures else 0)
