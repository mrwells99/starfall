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
func _initialize() -> void:
	host="--test-host" in OS.get_cmdline_user_args(); call_deferred("setup")
func setup() -> void:
	arena=load("res://arena.tscn").instantiate(); arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps=60; arena.current_port=53196
	arena.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	arena.aimed_shot_resolved.connect(func(result): results.append(result); print("BURST_CONFIRMED ",result))
	if host: arena.host_session(true); print("DETONATION NETWORK READY")
	else: arena.champion_choice.select(4); arena.address.text="127.0.0.1"; arena.join_session()
func _process(delta: float) -> bool:
	if arena==null: return false
	elapsed+=delta
	if elapsed>20: push_error("Detonation network timeout: "+arena.phase); quit(1); return false
	if host and arena.phase=="lobby" and arena.roster.size()==1:
		for entry in arena.roster.values(): entry.team=0
		arena.roster[777]={"champion":"Ember","team":1}; arena.begin_round()
	if arena.phase!="match": return false
	match_time+=delta
	var shooter
	var target
	for actor in arena.actors.values():
		if actor.champion=="Outlaw": shooter=actor
		else: target=actor
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
		if step==1 and match_time>1.4 and arena.outlaw_aim_test.reticle.visible:
			step=2
			var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
			arena._input(click)
		elif step==2 and results.size()==3:
			step=3; auto_exited=not arena.outlaw_aim_test.enabled
			held_after=arena.movement_controls.right and arena.has_capture_origin
			var last: Dictionary=results.back()
			arena.submit_detonation.rpc_id(1,arena.epoch,last.seq,last.burst,last.index,last.from,Vector3.FORWARD,arena.aimed_combat.observed_stamp,shooter.motion_revision)
	if match_time>(5.5 if host else 4.5):
		var damage:=0
		var timing:=true
		for i in results.size():
			damage+=int(results[i].damage)
			if i>0: timing=timing and results[i].time-results[i-1].time>=.13-.0001
		var okay: bool=results.size()==3 and damage==30 and target.hp==70 and shooter.identity.defense_detonation==0 and timing
		if host:
			okay=okay and shooter.champion_model==null and target.champion_model==null and not ResourceLoader.has_cached("res://assets/characters/outlaw.glb")
		else: okay=okay and auto_exited and held_after
		if okay: print("DETONATION NETWORK %s PASS: three camera-ray hits, fresh moving-target aim, 130ms cadence, atomic stacks, duplicate rejection, auto-exit and held right-click" % ["HOST" if host else "CLIENT"])
		else: push_error("Detonation network failed host=%s count=%s damage=%s hp=%s stacks=%s exit=%s held=%s" % [host,results.size(),damage,target.hp,shooter.identity.defense_detonation,auto_exited,held_after])
		arena.leave_session(""); quit(0 if okay else 1)
	return false
