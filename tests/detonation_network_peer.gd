extends SceneTree
var arena
var host:=false
var elapsed:=0.0
var match_time:=0.0
var placed:=false
var step:=0
var results:Array=[]
var held_after:=false
var auto_exited:=false
var world:=false
var miss:=false
var empty_click_blocked:=false
var timing_error:=""
var finished:=false
func _initialize() -> void:
	host="--test-host" in OS.get_cmdline_user_args()
	world="--test-world" in OS.get_cmdline_user_args()
	miss="--test-miss" in OS.get_cmdline_user_args()
	call_deferred("setup")
func setup() -> void:
	arena=load("res://arena.tscn").instantiate(); arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps=60; arena.current_port=53196
	for arg in OS.get_cmdline_user_args():
		if not host and arg.begins_with("--test-rtt-ms=") and int(arg.get_slice("=",1))>0: arena.current_port=53197
	arena.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	arena.aimed_shot_resolved.connect(func(result): results.append(result); print("BURST_CONFIRMED ",result))
	if host: arena.host_session(true,world); print("DETONATION NETWORK READY")
	else:
		arena.champion_choice.select(4); arena.address.text="127.0.0.1"
		if world:
			arena.world_mode=true; arena.intent="queue"; arena.connect_to(arena.current_port)
		else: arena.join_session()
func _process(delta: float) -> bool:
	if finished: return false
	if arena==null: return false
	elapsed+=delta
	if elapsed>20: push_error("Detonation network timeout: "+arena.phase); quit(1); return false
	if host and not world and arena.phase=="lobby" and arena.roster.size()==1:
		for entry in arena.roster.values(): entry.team=0
		arena.roster[777]={"champion":"Ember","team":1}; arena.begin_round()
	if arena.phase!="match": return false
	match_time+=delta
	var shooter
	var target
	for actor in arena.actors.values():
		if actor.champion=="Outlaw": shooter=actor
		elif (world and actor.actor_id==-101) or (not world and actor.champion=="Ember"): target=actor
	if shooter==null or target==null: return false
	if host:
		if not placed:
			placed=true; shooter.position=Vector3(0,.025,0); target.position=Vector3(0,.025,-6)
			shooter.rotation.y=0; target.rotation.y=PI
			shooter.motion_revision+=1; target.motion_revision+=1
			shooter.identity.defense_detonation=3
		target.input_age=0; target.move_input=Vector2(sin(match_time*2)*.3,0); target.walking=true
	else:
		arena.application_focused=true
		if arena.notice.text.contains("Shot timing expired"): timing_error=arena.notice.text
		if step==0 and match_time>.7 and shooter.identity.defense_detonation==3:
			step=1
			var right:=InputEventMouseButton.new(); right.button_index=MOUSE_BUTTON_RIGHT; right.pressed=true
			arena.movement_controls.begin(right); arena.send_action(arena.assignment.find(8))
		if arena.outlaw_aim_test.enabled and target.body_hitboxes!=null:
			# Steer the actual shoulder camera at the moving target, without a
			# top-level camera override or a selected-target combat request.
			var point: Vector3=arena.aimed_combat.firing_origin(target.body_hitboxes.points)
			var direction: Vector3=(point-arena.camera.global_position).normalized()
			arena.pivot.rotation.y=atan2(-direction.x,-direction.z)
			arena.outlaw_aim_test.aim_pitch=asin(direction.y)
			if miss:
				arena.pivot.rotation.y=PI*.5; arena.outlaw_aim_test.aim_pitch=0
		if step==1 and match_time>1.4 and arena.outlaw_aim_test.reticle.visible:
			step=2
			var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
			arena._input(click)
		elif step==2 and results.size()==3:
			step=3; auto_exited=not arena.outlaw_aim_test.enabled
			held_after=arena.movement_controls.right and arena.has_capture_origin
			var last: Dictionary=results.back()
			arena.submit_detonation.rpc_id(1,arena.epoch,last.seq,last.burst,last.index,last.from,Vector3.FORWARD,arena.aimed_combat.observed_stamp,shooter.motion_revision)
		elif step==3 and shooter.identity.defense_detonation==0:
			step=4; arena.send_action(arena.assignment.find(8))
		elif step==4 and arena.outlaw_aim_test.reticle.visible:
			var previous_seq: int=arena.action_seq
			arena.outlaw_aim_test.request_fire()
			empty_click_blocked=not arena.outlaw_aim_test.fire_requested and arena.action_seq==previous_seq
			step=5
	if match_time>4.5:
		var damage:=0
		var timing:=true
		for i in results.size():
			damage+=int(results[i].damage)
			if i>0: timing=timing and results[i].time-results[i-1].time>=.13-.0001
		var expected_damage:=0 if miss else 30
		var okay: bool=results.size()==3 and damage==expected_damage and target.hp==100-expected_damage and shooter.identity.defense_detonation==0 and timing
		if host:
			okay=okay and shooter.champion_model==null and target.champion_model==null and not ResourceLoader.has_cached("res://assets/characters/outlaw.glb")
			var transport: ENetMultiplayerPeer=arena.multiplayer.multiplayer_peer
			print("DETONATION TIMING measured_rtt_ms=",transport.get_peer(shooter.owner_peer).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)," allowed_age_ms=",arena.aimed_combat.allowed_age(arena,shooter.owner_peer)*1000)
		else: okay=okay and auto_exited and held_after and empty_click_blocked and timing_error.is_empty()
		if okay: print("DETONATION NETWORK %s PASS: world=%s miss=%s, three camera rays, 130ms cadence, consumed stacks, empty-click/duplicate rejection, auto-exit and held right-click" % ["HOST" if host else "CLIENT",world,miss])
		else: push_error("Detonation network failed host=%s count=%s damage=%s hp=%s stacks=%s exit=%s held=%s reason=%s" % [host,results.size(),damage,target.hp,shooter.identity.defense_detonation,auto_exited,held_after,timing_error])
		finished=true; finish.call_deferred(okay)
	return false

func finish(okay: bool) -> void:
	# Both world peers must record their assertions before disconnect despawns one.
	await create_timer(1.0).timeout
	arena.leave_session(""); quit(0 if okay else 1)
