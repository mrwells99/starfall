extends SceneTree
## Real ENet coverage for Roll's proc, airborne Trickshot and authoritative damage.
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var step := 0
var roll_seen := false
var proc_seen := false
var severe_seen := false
var backflip_seen := false
var combo_seen := false
var consumed_seen := false
var aim_seen := false
var aim_exited := false
var aim_seq := -1
var old_detonation_rejected := false
func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args(); call_deferred("setup")
func setup() -> void:
	arena=load("res://arena.tscn").instantiate(); arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps=60;arena.current_port=53194
	arena.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host:
		arena.champion_choice.select(1);arena.host_session();print("OUTLAW NETWORK READY")
	else:
		arena.champion_choice.select(4);arena.address.text="127.0.0.1";arena.join_session()
func _process(delta: float) -> bool:
	if arena==null:return false
	elapsed+=delta
	if elapsed>20:push_error("Outlaw network timeout: "+arena.phase);quit(1);return false
	if host and arena.phase=="lobby" and arena.roster.size()==2:arena.host_start()
	if arena.phase!="match":return false
	match_time+=delta
	var outlaw;var target
	for actor in arena.actors.values():
		if actor.champion=="Outlaw":outlaw=actor
		else:target=actor
	if outlaw==null or target==null:return false
	if host and not placed:
		placed=true;outlaw.position=Vector3(6,.025,0);target.position=Vector3(0,.025,-2)
		outlaw.rotation.y=0;outlaw.motion_revision+=1;target.motion_revision+=1
	roll_seen=roll_seen or (outlaw.identity.roll_left>0 and outlaw.position.x<5.5)
	proc_seen=proc_seen or outlaw.identity.instant_severe>0
	severe_seen=severe_seen or target.identity.severe_bleeds.has(outlaw.actor_id)
	backflip_seen=backflip_seen or (outlaw.identity.backflip_active and outlaw.position.y>.5)
	combo_seen=combo_seen or outlaw.identity.defense_detonation==1
	consumed_seen=consumed_seen or (combo_seen and not outlaw.identity.backflip_combo)
	if host and combo_seen and not old_detonation_rejected:
		old_detonation_rejected=not arena.try_spell(outlaw.actor_id,8,target.actor_id) and outlaw.identity.defense_detonation==1 and outlaw.casting==-1
	if not host:
		if step==0 and match_time>.7:
			step=1;arena.local_yaw=0;arena.pivot.rotation.y=PI/2;arena.selected_id=target.actor_id;arena.send_action(6)
		elif step==1 and proc_seen:
			step=2;arena.send_action(1)
		elif step==2 and severe_seen and match_time>2.0:
			step=3;arena.send_action(3)
		elif step==3 and backflip_seen:
			step=4;arena.send_action(2)
		elif step==4 and combo_seen and not outlaw.identity.backflip_active:
			step=5;aim_seq=arena.action_seq;arena.application_focused=true;arena.send_action(arena.assignment.find(8))
			aim_seen=arena.outlaw_aim_test.enabled and outlaw.identity.defense_detonation==1 and arena.action_seq==aim_seq
		elif step==5 and match_time>4:
			step=6;arena.send_action(arena.assignment.find(8))
			aim_exited=not arena.outlaw_aim_test.enabled and outlaw.identity.defense_detonation==1 and arena.action_seq==aim_seq
	if match_time>(6.0 if host else 5.0):
		var passed: bool=roll_seen and proc_seen and severe_seen and backflip_seen and combo_seen and consumed_seen and outlaw.identity.instant_severe==0 and target.hp<73
		passed=passed and outlaw.identity.defense_detonation==1 and (old_detonation_rejected if host else (aim_seen and aim_exited))
		if passed:print("OUTLAW NETWORK %s PASS: Roll, Severe, combo resource, Detonation aim toggles without spending or RPC, legacy channel rejected" % ["HOST" if host else "CLIENT"])
		else:push_error("Outlaw network failed: roll=%s proc=%s severe=%s flip=%s combo=%s consumed=%s hp=%s pos=%s" % [roll_seen,proc_seen,severe_seen,backflip_seen,combo_seen,consumed_seen,target.hp,outlaw.position])
		arena.leave_session("");quit(0 if passed else 1)
	return false
