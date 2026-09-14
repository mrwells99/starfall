extends RefCounted
## Reuse owner-approved Null r015 movement with target-specific baked carrying arms.
## Presentation only; no stealth, ability, actor-travel or networking ownership.
const Locomotion = preload("res://scripts/null_locomotion.gd")
const Blend = preload("res://scripts/null_living_blend.gd")
const FocusBlend = preload("res://scripts/shared_focus_blend.gd")
const LIBRARIES := {
	"Ember":preload("res://assets/animations/ember_locomotion.res"),
	"Luminary":preload("res://assets/animations/luminary_locomotion.res"),
	"Fulcrum":preload("res://assets/animations/fulcrum_locomotion.res"),
	"Vanguard":preload("res://assets/animations/vanguard_locomotion.res")
}
static var remapped_libraries := {}
var locomotion := Locomotion.new()
var jump=preload("res://scripts/shared_jump.gd").new()
var phase_data: Dictionary
var pending_target := ""
var sample_delta := 1.0/60.0
var incoming_travel := Vector3.ZERO
var target_travel := Vector3.ZERO
var motion_revision_seen := -999
var last_transition := {}

static func movement_state(name:String) -> bool:
	return name=="Ready" or Locomotion.is_locomotion(name)

static func native_movement(name:String) -> bool:
	return name=="Idle" or name.begins_with("Walk") or name.begins_with("Run") or name.begins_with("Sprint") or name.begins_with("Strafe")

func build(art, title:String) -> void:
	var player:AnimationPlayer=art.player
	var rig:Skeleton3D=art.skeleton
	var active_name:=String(player.assigned_animation)
	var active_time:=player.current_animation_position if not active_name.is_empty() else 0.0
	var was_playing:=player.is_playing()
	var path:=String(player.get_node(player.root_node).get_path_to(rig))
	var cache_key:=title+":"+path
	var source:AnimationLibrary=LIBRARIES[title]
	if not remapped_libraries.has(cache_key):
		var library:=AnimationLibrary.new()
		for name in source.get_animation_list():
			var original:Animation=source.get_animation(name)
			Locomotion.nominal_speeds[name]=float(original.get_meta("nominal_speed_m_s"))
			var animation:Animation=original.duplicate(false)
			for track in animation.get_track_count():
				var bone:=String(animation.track_get_path(track).get_subname(0))
				assert(rig.find_bone(bone)>=0,"Shared movement cannot bind "+title+" / "+bone)
				animation.track_set_path(track,NodePath(path+":"+bone))
			var added:=library.add_animation(name,animation)
			assert(added==OK)
		remapped_libraries[cache_key]=library
	var installed:=player.add_animation_library("shared_movement",remapped_libraries[cache_key])
	assert(installed==OK)
	# Refresh paused/playing state explicitly for the actual Godot 4.5 server.
	if not active_name.is_empty():
		player.play(active_name,0.0);player.seek(active_time,true);player.advance(0.0)
		if not was_playing:player.pause()
	for name in source.get_animation_list():art.clip_names[name]="shared_movement/"+name
	art.pose_blend=FocusBlend.new() if title=="Fulcrum" else Blend.new()
	art.pose_blend.build(rig)
	art.pose_blend.load_life(load("res://assets/animations/null_idle_life.res"))
	phase_data=load("res://assets/animations/null_transition_features.res").get_meta("data")
	phase_data=preload("res://scripts/shared_ready.gd").apply(art,title,phase_data)
	jump.build(art,title)

func begin_frame(art,actor,delta:float) -> void:
	jump.begin_frame(art,actor,delta)
	sample_delta=delta
	if delta<=0.0 or delta>.10 or actor.motion_revision!=motion_revision_seen or actor.hp<=0 or actor.stunned>0:
		art.pose_blend.clear_velocity_history()
	motion_revision_seen=actor.motion_revision
	var displacement:Vector3=actor.global_position-art.last_position if art.initialized else Vector3.ZERO
	if displacement.length()>1.0:displacement=Vector3.ZERO
	displacement.y=0.0
	target_travel=art.model.global_basis.inverse()*art.network_motion.displacement(actor,displacement,delta)/maxf(delta,.0001)
	locomotion.observe_motion(actor,art.last_position,art.initialized,delta)

func finish_frame(art,delta:float) -> void:
	art.pose_blend.finish_frame(delta)
	incoming_travel=target_travel
	jump.finish_frame(art,jump.active_actor,delta)

func choose(art,desired:String,actor,alive:bool,stunned:bool) -> String:
	if not alive or stunned:return desired
	if (desired.begins_with("Jump") and jump.omni_jump.allowed) or native_movement(desired) or movement_state(desired):
		desired=locomotion.choose(art.filtered_speed,actor.walking,preload("res://scripts/outlaw_mechanics.gd").severe_slowed(actor),false)
	if art.pose_blend is FocusBlend:
		art.pose_blend.movement_target=movement_state(desired)
	return desired

func transition_duration(art,previous:String,next:String,fallback:float) -> float:
	art.pose_blend.inertial_enabled=movement_state(previous) and movement_state(next)
	if not art.pose_blend.inertial_enabled:
		pending_target=""
		return fallback
	pending_target=next
	if next=="Ready":return .38*1.06
	if previous=="Ready":return .28*1.06
	var first:=Locomotion.SUFFIXES.find(previous.trim_prefix("Travel").trim_prefix("Measured"))
	var second:=Locomotion.SUFFIXES.find(next.trim_prefix("Travel").trim_prefix("Measured"))
	var turns:=mini(absi(first-second),8-absi(first-second))
	return (.23+turns*.02)*1.06

func playback_rate(art,desired:String,default_rate:float) -> float:
	var rate:=Locomotion.playback_rate(desired,art.filtered_speed,default_rate)
	if desired=="TravelForward":rate=clampf(art.filtered_speed/4.4,.55,2.5)*.90
	if pending_target!=desired:return rate
	pending_target=""
	var effective_rate:float=lerpf(art.player.speed_scale,rate,1.0-exp(-sample_delta*18.0)) if Locomotion.is_locomotion(desired) else 1.0
	var best_time:=0.0
	var best_score:=INF
	var feet:PackedVector3Array=art.pose_blend.current_feet
	var previous:PackedVector3Array=art.pose_blend.previous_feet
	for row in phase_data.clips[desired].samples:
		var score:=0.0
		for side in feet.size():
			var velocity:=incoming_travel
			if previous.size()==2 and art.pose_blend.frame_delta>.00001:velocity+=(feet[side]-previous[side])/art.pose_blend.frame_delta
			score+=feet[side].distance_squared_to(row.feet[side])*4.0
			score+=velocity.distance_squared_to(row.foot_velocity[side]*effective_rate+target_travel)*.004
			if feet[side].y<.13 and row.feet[side].y>.21:score+=.2
		if score<best_score:best_score=score;best_time=row.time
	var animation:Animation=art.player.get_animation(art.clip_names[desired])
	art.pose_blend.prepare(animation,best_time,effective_rate)
	art.player.seek(best_time,true);art.player.advance(0.0)
	last_transition={"to":desired,"phase":best_time,"score":best_score,"duration":art.pose_blend.duration}
	return rate
