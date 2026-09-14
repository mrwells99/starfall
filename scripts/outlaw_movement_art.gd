extends "res://scripts/outlaw_art.gd"
## Owner-approved Null refined B movement, with native Outlaw gun/equipment layers.
const Locomotion = preload("res://scripts/null_locomotion.gd")
const MovementLibrary = preload("res://assets/animations/outlaw_locomotion.res")
var locomotion = Locomotion.new()
static var remapped_libraries := {}
const Blend = preload("res://scripts/null_living_blend.gd")
## Keep A available: 1 = balanced; 2 = owner-selected softer B.
var transition_style := 2
var phase_data: Dictionary
var pending_target := ""
var sample_delta := 1.0/60.0
var incoming_travel:=Vector3.ZERO
var target_travel:=Vector3.ZERO
var motion_revision_seen:=-999
var last_transition: Dictionary = {}

func build(host: Node3D, team_color: Color) -> void:
	super.build(host,team_color)
	install_movement()
	pose_blend=Blend.new()
	pose_blend.build(skeleton)
	pose_blend.load_life(load("res://assets/animations/null_idle_life.res"))
	phase_data=load("res://assets/animations/null_transition_features.res").get_meta("data")
	phase_data=preload("res://scripts/shared_ready.gd").apply(self,"Outlaw",phase_data)

static func movement_state(name: String) -> bool:
	return name in ["Ready","LowIdle"] or Locomotion.is_locomotion(name)

func animate(host: Node3D, delta: float, actor: CharacterBody3D) -> void:
	sample_delta=delta
	if delta<=0.0 or delta>.10 or actor.motion_revision!=motion_revision_seen or actor.hp<=0 or actor.stunned>0:
		pose_blend.clear_velocity_history()
	motion_revision_seen=actor.motion_revision
	var displacement:=actor.global_position-last_position if initialized else Vector3.ZERO
	if displacement.length()>1.0:displacement=Vector3.ZERO
	displacement.y=0
	target_travel=model.global_basis.inverse()*network_motion.displacement(actor,displacement,delta)/maxf(delta,.0001)
	locomotion.observe_motion(actor,last_position,initialized,delta)
	super.animate(host,delta,actor)
	pose_blend.finish_frame(delta)
	incoming_travel=target_travel

func transition_duration(previous: String, next: String) -> float:
	var same_stance:=Locomotion.is_low(previous)==Locomotion.is_low(next)
	pose_blend.inertial_enabled=movement_state(previous) and movement_state(next) and same_stance and not showing_roll(active_actor) and not active_actor.identity.backflip_active
	if not pose_blend.inertial_enabled:
		pending_target=""
		# The shared ready stance leans farther than old Outlaw Idle. Give its
		# captured Backflip entry 10 ms more to settle; flight/events stay unchanged.
		if next=="Roll" and active_actor.identity.backflip_active:
			special_blend.duration=.09
			special_blend.body_duration=.09
		return super.transition_duration(previous,next)
	pending_target=next
	if next in ["Ready","LowIdle"]:return .28 if transition_style==1 else .38*1.06
	if previous in ["Ready","LowIdle"]:return .20 if transition_style==1 else .28*1.06
	var first:=Locomotion.SUFFIXES.find(previous.trim_prefix("Travel").trim_prefix("Measured").trim_prefix("Low"))
	var second:=Locomotion.SUFFIXES.find(next.trim_prefix("Travel").trim_prefix("Measured").trim_prefix("Low"))
	var turns:=mini(absi(first-second),8-absi(first-second))
	return (.17+turns*.015) if transition_style==1 else (.23+turns*.02)*1.06

func override_playback_rate(desired: String, default_rate: float) -> float:
	var rate:=movement_rate(desired,default_rate)
	if pending_target!=desired:return rate
	pending_target=""
	var effective_rate:=lerpf(player.speed_scale,rate,1.0-exp(-sample_delta*18.0)) if is_locomotion(desired) else 1.0
	var rows:Array=phase_data.clips[desired].samples
	var best_time:=0.0
	var best_score:=INF
	var feet:PackedVector3Array=pose_blend.current_feet
	var previous:PackedVector3Array=pose_blend.previous_feet
	for row in rows:
		var score:=0.0
		for side in feet.size():
			var outgoing_velocity:=incoming_travel
			if previous.size()==2 and pose_blend.frame_delta>.00001:outgoing_velocity+=(feet[side]-previous[side])/pose_blend.frame_delta
			score+=feet[side].distance_squared_to(row.feet[side])*4.0
			score+=outgoing_velocity.distance_squared_to(row.foot_velocity[side]*effective_rate+target_travel)*.004
			if feet[side].y<.13 and row.feet[side].y>.21:score+=.2
		if score<best_score:best_score=score;best_time=row.time
	var animation:=player.get_animation(clip_names[desired])
	pose_blend.prepare(animation,best_time,effective_rate)
	player.seek(best_time,true)
	player.advance(0.0)
	last_transition={"to":desired,"phase":best_time,"score":best_score,"duration":pose_blend.duration}
	return rate


func install_movement() -> void:
	var active_name:=String(player.assigned_animation)
	var active_time:=player.current_animation_position if not active_name.is_empty() else 0.0
	var was_playing:=player.is_playing()
	# Stop playback before adding a library so Godot cannot reuse invalid
	# active-animation caches when restoring the current pose.
	player.stop()
	player.clear_caches()
	var path:=String(player.get_node(player.root_node).get_path_to(skeleton))
	if not remapped_libraries.has(path):
		var library:=AnimationLibrary.new()
		for name in MovementLibrary.get_animation_list():
			var original:Animation=MovementLibrary.get_animation(name)
			Locomotion.nominal_speeds[name]=float(original.get_meta("nominal_speed_m_s"))
			var animation:Animation=original.duplicate(false)
			for track in animation.get_track_count():
				var source_path:=animation.track_get_path(track)
				assert(source_path.get_subname_count()==1)
				var bone:=String(source_path.get_subname(0))
				assert(skeleton.find_bone(bone)>=0)
				animation.track_set_path(track,NodePath(path+":"+bone))
			var animation_error := library.add_animation(name,animation)
			assert(animation_error == OK)
		remapped_libraries[path]=library
	var library_error := player.add_animation_library("outlaw_locomotion",remapped_libraries[path])
	assert(library_error == OK)
	player.clear_caches()
	if not active_name.is_empty():
		player.play(active_name,0.0);player.seek(active_time,true);player.advance(0.0)
		if not was_playing:player.pause()
	for name in MovementLibrary.get_animation_list():clip_names[name]="outlaw_locomotion/"+name

func override_clip(desired:String,alive:bool,stunned:bool,delta:float) -> String:
	var original:=super.override_clip(desired,alive,stunned,delta)
	if not alive or stunned or active_actor==null:return original
	# Existing Roll, Backflip, Mend, jumping and other special clips keep priority.
	if original=="Idle" or original=="Ready" or is_locomotion(original):
		var deadeye:bool=active_actor.casting>=0 and active_actor.kit[active_actor.casting].kind=="deadeye"
		return locomotion.choose(filtered_speed,active_actor.walking or deadeye,Outlaw.severe_slowed(active_actor),false)
	return original

func is_locomotion(name:String) -> bool:
	return Locomotion.is_locomotion(name) or super.is_locomotion(name)

func movement_rate(desired:String,default_rate:float) -> float:
	if desired=="TravelForward":return clampf(filtered_speed/4.4,.55,2.5)*RUN_CADENCE_SCALE
	if Locomotion.is_locomotion(desired) or desired=="Ready":return Locomotion.playback_rate(desired,filtered_speed,default_rate)
	return super.override_playback_rate(desired,default_rate)
