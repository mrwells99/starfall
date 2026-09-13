extends SceneTree
## Actual Outlaw visible/server paths, compared with the original Null B body.
var checks:=0
var failures:=0
var max_error:=0.0
var max_shared_body_error:=0.0
var frames:=0
const STEP:=1.0/60.0
const SUFFIXES=["Forward","ForwardRight","Right","BackwardRight","Backward","BackwardLeft","Left","ForwardLeft"]
class Host extends Node3D:
	var torso:MeshInstance3D
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var actors:=[];var arts:=[];var hosts:=[];var rest:=[]
	for index in 3:
		var actor=load("res://scripts/combatant.gd").new();root.add_child(actor)
		actor.setup(index+1,index+1,0,"Outlaw" if index<2 else "Null",index==1)
		actor.presentation_grounded=true
		var art;var host
		if index==0:
			actor.setup_hitboxes();art=actor.hitbox_pose.art;host=actor.hitbox_pose
			check(not ResourceLoader.has_cached("res://assets/characters/outlaw.glb"),"Server Outlaw does not load its visual model")
			check(host.find_children("*","MeshInstance3D",true,false).is_empty(),"Server Outlaw has no render meshes")
		elif index==1:art=actor.champion_model.outlaw_art;host=actor.champion_model
		else:
			host=Host.new();actor.add_child(host)
			art=load("res://scripts/null_movement_art.gd").new()
			art.asset=load("res://assets/hitboxes/null_rig.scn");art.pose_only=true;art.build(host,Color.WHITE)
		actors.append(actor);arts.append(art);hosts.append(host)
		var rows:=[]
		for bone in art.skeleton.get_bone_count():rows.append(art.skeleton.get_bone_rest(bone))
		rest.append(rows)
	for art in arts:check(art.transition_style==2,"All comparison actors use original B settings")
	for walking in [false,true]:
		for sector in 8:
			for action in [-1,sector,posmod(sector+1,8),posmod(sector+4,8),-1]:
				for frame in 42:
					var speed:=0.0 if action<0 else (preload("res://scripts/movement_tuning.gd").BACKWARD_SPEED if action in [3,4,5] else preload("res://scripts/movement_tuning.gd").FORWARD_SPEED)
					if walking:speed*=.5
					var direction:=Vector3.ZERO if action<0 else Vector3(sin(action*PI/4.0),0,-cos(action*PI/4.0))
					for index in 3:
						var actor=actors[index];actor.walking=walking;actor.velocity=direction*speed;actor.position+=actor.velocity*STEP
						var before:Transform3D=actor.transform;var hp:float=actor.hp;var identity:Dictionary=actor.identity.duplicate(true)
						arts[index].animate(hosts[index],STEP,actor)
						check(actor.transform==before and actor.hp==hp and actor.identity==identity,"Presentation leaves gameplay unchanged")
						arts[index].skeleton.force_update_all_bone_transforms()
						check(arts[index].clip==arts[0].clip,"Visible/server and original B select the same gait")
					for bone in arts[0].skeleton.get_bone_count():
						var a:Transform3D=arts[0].skeleton.get_bone_global_pose(bone)
						var b:Transform3D=arts[1].skeleton.get_bone_global_pose(bone)
						check(a.is_finite() and b.is_finite(),"Finite Outlaw poses")
						for point in [Vector3.ZERO,Vector3(0,.14,0)]:max_error=maxf(max_error,(a*point).distance_to(b*point))
						var name:String=arts[0].skeleton.get_bone_name(bone)
						if not (name.begins_with("DEF-") or name=="root"):continue
						if name in ["DEF-shoulder.R","DEF-upper_arm.R","DEF-forearm.R","DEF-hand.R"] or name.begins_with("DEF-f_") or name.begins_with("DEF-thumb"):continue
						var mapped:int=arts[2].skeleton.find_bone(name)
						var donor:Transform3D=arts[2].skeleton.get_bone_global_pose(mapped)
						# After the initial setup blend, only the gun-arm/grip should differ.
						if frames>60:
							for point in [Vector3.ZERO,Vector3(0,.14,0)]:max_shared_body_error=maxf(max_shared_body_error,(a*point).distance_to(donor*point))
					frames+=1
	for index in 3:
		for bone in arts[index].skeleton.get_bone_count():check(rest[index][bone]==arts[index].skeleton.get_bone_rest(bone),"Rest anatomy unchanged")
	check(max_error<.0005,"Outlaw visible/server pose agreement")
	check(max_shared_body_error<.00005,"Shared B body motion matches Null except gun arm and grip")
	print("OUTLAW_MOVEMENT_PARITY frames=",frames," visible_server_m=",max_error," shared_body_m=",max_shared_body_error)
	for actor in actors:actor.free()
	print("Outlaw locomotion checks: %d passed / %d total" % [checks-failures,checks]);quit(0 if failures==0 else 1)
