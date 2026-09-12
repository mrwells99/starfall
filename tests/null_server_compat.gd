extends SceneTree
## Run in an isolated project/cache under each supported engine version.
var failures := 0
func _initialize() -> void: call_deferred("run")
func require_true(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var actor=load("res://scripts/combatant.gd").new();stage.add_child(actor);actor.setup(1,1,0,"Null",false)
	actor.setup_hitboxes()
	var art=actor.hitbox_pose.art
	require_true(actor.champion_model==null and actor.hitbox_pose.find_children("*","MeshInstance3D",true,false).is_empty(),"No rendering resources")
	require_true(not ResourceLoader.has_cached("res://assets/characters/null.glb"),"No visual GLB loaded")
	require_true(art.player.get_animation_list().size()>=35,"Portable libraries restored")
	var samples:=[]
	var first:=Vector3.ZERO
	var motion:=0.0
	for state in ["idle","forward","side","backpedal","stealth","lift","dive","recover","stab"]:
		for frame in 48:
			var moving: bool=state in ["forward","side","backpedal","stealth"]
			var direction: Vector3=Vector3.RIGHT if state=="side" else (Vector3.BACK if state=="backpedal" else Vector3.FORWARD)
			if moving:actor.position+=direction*(2.5 if state=="stealth" else 4.0)/60
			actor.identity.stealth=state=="stealth"
			actor.identity.null_vantage={"phase":state,"elapsed":frame/60.0,"direction":Vector3(0,-1,-1).normalized()} if state in ["lift","dive","recover"] else {}
			actor.presentation_grounded=state not in ["lift","dive"]
			actor.presentation_vertical_speed=10 if state=="lift" else (-12 if state=="dive" else 0)
			if state=="stab" and frame==1:actor.identity.null_action="stab";actor.identity.null_action_serial+=1
			actor.update_hitboxes(1.0/60)
			require_true(actor.body_hitboxes.points.size()==38,"38 body endpoints")
			var row:=[]
			for point in actor.body_hitboxes.points:
				require_true(point.is_finite(),"Finite actual pose")
				var relative: Vector3=point-actor.position;row.append([relative.x,relative.y,relative.z])
			samples.append(row)
			var foot: Vector3=actor.body_hitboxes.points[20]-actor.position
			if state=="forward":
				if frame==0:first=foot
				motion=maxf(motion,first.distance_to(foot))
	require_true(motion>.05,"Animation moves body landmarks, not just loaded libraries")
	var output: String="res://pose-"+Engine.get_version_info().string+".json"
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(samples));file.close()
	print("NULL_SERVER_COMPAT engine=",Engine.get_version_info().string," clips=",art.player.get_animation_list().size()," samples=",samples.size()," foot_travel=",motion," failures=",failures)
	stage.free();quit(1 if failures else 0)
