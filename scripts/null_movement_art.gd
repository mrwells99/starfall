extends "res://scripts/null_art.gd"
## Owner-selected B movement transitions; base poses, speeds and special actions unchanged.
const Blend = preload("res://scripts/null_movement_blend.gd")
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
	pose_blend=Blend.new()
	pose_blend.build(skeleton)
	phase_data=load("res://assets/animations/null_transition_features.res").get_meta("data")

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
	super.animate(host,delta,actor)
	pose_blend.finish_frame(delta)
	incoming_travel=target_travel

func transition_duration(previous: String, next: String) -> float:
	var same_stance:=Locomotion.is_low(previous)==Locomotion.is_low(next)
	pose_blend.inertial_enabled=movement_state(previous) and movement_state(next) and same_stance and not Null.busy(active_actor)
	if not pose_blend.inertial_enabled:
		pending_target=""
		return super.transition_duration(previous,next)
	pending_target=next
	if next in ["Ready","LowIdle"]:return .28 if transition_style==1 else .38
	if previous in ["Ready","LowIdle"]:return .20 if transition_style==1 else .28
	var first:=Locomotion.SUFFIXES.find(previous.trim_prefix("Travel").trim_prefix("Measured").trim_prefix("Low"))
	var second:=Locomotion.SUFFIXES.find(next.trim_prefix("Travel").trim_prefix("Measured").trim_prefix("Low"))
	var turns:=mini(absi(first-second),8-absi(first-second))
	return (.17+turns*.015) if transition_style==1 else (.23+turns*.02)

func override_playback_rate(desired: String, default_rate: float) -> float:
	var rate:=super.override_playback_rate(desired,default_rate)
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
