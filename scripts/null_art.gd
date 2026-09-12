extends "res://scripts/model_forge_art.gd"
## Null-specific poses and observer visibility; server uses identical pose layers.
const Null = preload("res://scripts/null_mechanics.gd")
var active_actor
var strike_frames: Array[Dictionary]=[]
var strike_left:=0.0
var action_serial:=-1
var stealth_weight:=0.0
var alert: Label3D
var last_alpha:=-1.0
var last_stealth_serial:=-1
var special_blend=preload("res://scripts/model_forge_pose_blend.gd").new()
var special_phase:=""
var dive_clock=preload("res://scripts/snapshot_animation_clock.gd").new()

func _init() -> void:
	asset_path="res://assets/characters/null.glb"
	class_title="Null"
	equipment=preload("res://scripts/null_equipment.gd").new()

func build(host: Node3D, team_color: Color) -> void:
	super.build(host,team_color)
	var strike: Animation=player.get_animation(clip_names.KnifeStrike)
	player.play(clip_names.KnifeStrike)
	for frame in ceili(strike.length*30)+1:
		player.seek(minf(strike.length,frame/30.0),true)
		var sample: Dictionary={}
		for suffix in ["shoulder","upper_arm","forearm","hand"]:
			var i:=skeleton.find_bone("DEF-"+suffix+".R")
			sample[i]=skeleton.get_bone_pose_rotation(i)
		strike_frames.append(sample)
	player.play(clip_names.Idle);player.advance(0);equipment.apply()
	pose_blend.build(skeleton);special_blend.build(skeleton)
	if not pose_only:
		alert=Label3D.new();alert.text="!";alert.font_size=80;alert.outline_size=14
		alert.modulate=Color("f4e4bc");alert.pixel_size=.006
		alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED;alert.position.y=2.1
		alert.visible=false;host.add_child(alert)

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
	active_actor=actor
	if action_serial != int(actor.identity.get("null_action_serial",0)):
		if action_serial>=0 and actor.identity.get("null_action","") in ["stab","backstab"]:strike_left=.6
		action_serial=int(actor.identity.get("null_action_serial",0))
	strike_left=maxf(0,strike_left-delta)
	var state: Dictionary=actor.identity.get("null_vantage",{})
	var next: String=state.get("phase","") if actor.hp>0 and actor.stunned<=0 else ""
	if next!=special_phase:
		special_blend.begin(.10,.10);special_phase=next;dive_clock.reset()
		if next.is_empty():transient_left=0.0
	super.animate(host,delta,actor)
	if actor.hp>0 and actor.stunned<=0:
		if strike_left>0 and next.is_empty():
			var frame:=mini(strike_frames.size()-1,int((.6-strike_left)*30))
			var weight:=smoothstep(0,.06,.6-strike_left)*smoothstep(0,.10,strike_left)
			for i in strike_frames[frame]:
				skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(strike_frames[frame][i],weight))
		if not next.is_empty():
			var hips:=skeleton.find_bone("DEF-hips")
			var progress: float=dive_clock.advance(float(state.get("elapsed",0)),delta,actor.presentation_snapshot_serial,actor.motion_revision,2.0)
			var direction: Vector3=state.get("direction",Vector3(0,-1,-1).normalized())
			var dive_lean:=clampf(PI*.5+atan2(-direction.y,Vector2(direction.x,direction.z).length()),1.65,2.65)
			var lean:=dive_lean if next=="dive" else (.45*(1-clampf(progress/.18,0,1)) if next=="recover" else -.12)
			skeleton.set_bone_pose_rotation(hips,Quaternion(Vector3.RIGHT,lean)*skeleton.get_bone_pose_rotation(hips))
			for side in ["L","R"]:
				var x: float=-.2 if side=="L" else .2
				var upper: Vector3=Vector3(x,-.15,1) if next=="dive" else (Vector3(x,-.55,.7) if next=="recover" else Vector3(x,.6,.6))
				var lower: Vector3=Vector3(x,-.6,.8) if next=="dive" else (Vector3(x,-.3,.9) if next=="recover" else Vector3(x,1,.1))
				lasso_pose.aim_bone("DEF-upper_arm."+side,upper)
				lasso_pose.aim_bone("DEF-forearm."+side,lower)
			special_blend.apply(delta)
		equipment.apply()
	# Release special motion smoothly into the selected measured gait.
	if next.is_empty(): special_blend.apply(delta);equipment.apply()

func override_clip(desired: String, alive: bool, stunned: bool, _delta: float) -> String:
	if not alive or stunned or active_actor==null:return desired
	if Null.busy(active_actor):
		return {"lift":"JumpStart","dive":"JumpLoop","recover":"JumpLand"}[active_actor.identity.null_vantage.phase]
	if Null.stealthed(active_actor) and not was_airborne:
		return "StealthWalk" if filtered_speed>.12 else "StealthIdle"
	if desired.begins_with("Cast"):
		return "Run" if filtered_speed>1.8 else ("Walk" if filtered_speed>.12 else "Idle")
	return desired

func override_playback_rate(desired: String, default_rate: float) -> float:
	if desired=="StealthWalk":return clampf(filtered_speed/2.8,.55,2.5)
	return default_rate

func is_locomotion(name: String) -> bool:
	return name=="StealthWalk" or super.is_locomotion(name)

func visibility_for(actor, observer) -> void:
	if pose_only:return
	var hidden: bool=Null.stealthed(actor)
	var friendly: bool=observer==null or observer==actor or observer.team==actor.team
	var seen: bool=not hidden or friendly or Null.detected(actor,observer)
	model.visible=seen
	var alpha:=.5 if hidden else 1.0
	if alpha!=last_alpha:
		last_alpha=alpha
		for material in materials:
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if hidden else BaseMaterial3D.TRANSPARENCY_DISABLED
			material.albedo_color.a=alpha
	var detected_by_any:=false
	for value in actor.identity.get("stealth_detection",{}).values():
		if float(value)>=Null.DETECT_SECONDS:detected_by_any=true;break
	alert.visible=hidden and seen and (detected_by_any if friendly else Null.detected(actor,observer))
	# Ensure impact-flash color updates cannot accidentally restore full opacity.
	if hidden:
		for material in materials:material.albedo_color.a=.5
