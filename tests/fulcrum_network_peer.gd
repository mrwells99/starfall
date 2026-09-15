extends SceneTree
var game
var host:=false
var elapsed:=0.0
var match_time:=0.0
var step:=0
var placed:=false
var anchor_seen:=false
var right_seen:=false
var left_seen:=false
var divide_seen:=false
var flow_seen:=false
var no_skeleton_history:=true
func _initialize():host="--test-host" in OS.get_cmdline_user_args();call_deferred("setup")
func setup():
	game=load("res://arena.tscn").instantiate();game.set_script(load("res://tests/network_fixture_arena.gd"));root.add_child(game)
	Engine.max_fps=60;game.current_port=53199
	game.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host:game.champion_choice.select(1);game.host_session();print("FULCRUM NETWORK READY")
	else:game.champion_choice.select(3);game.address.text="127.0.0.1";game.join_session()
func _process(delta:float)->bool:
	if game==null:return false
	elapsed+=delta
	if elapsed>18:push_error("Fulcrum network timed out");quit(1);return false
	if host and game.phase=="lobby" and game.roster.size()==2:game.host_start()
	if game.phase!="match":return false
	match_time+=delta
	var caster;var target
	for actor in game.actors.values():
		if actor.champion=="Fulcrum":caster=actor
		else:target=actor
	if caster==null or target==null:return false
	if host and not placed:
		placed=true;caster.position=Vector3(0,.025,7);target.position=Vector3(0,.025,3);caster.rotation.y=0
		caster.identity.meditation=80;caster.motion_revision+=1;target.motion_revision+=1
	anchor_seen=anchor_seen or caster.identity.anchor_left>0
	right_seen=right_seen or caster.identity.ruin_combo==1
	left_seen=left_seen or caster.identity.divide_ready>0
	divide_seen=divide_seen or not caster.identity.gravity_rifts.is_empty()
	flow_seen=flow_seen or caster.identity.gravity_flow>0
	# These attacks use body-root history; the fixture never asks for aimed bones.
	no_skeleton_history=no_skeleton_history and not game.aimed_combat.tracking_required(game) and game.aimed_combat.history.is_empty()
	if not host:
		game.local_yaw=0;game.pivot.rotation.y=0
		if step==0 and match_time>.7:step=1;game.send_action(1)
		elif step==1 and anchor_seen and match_time>1.2:step=2;game.send_action(15)
		elif step==2 and flow_seen and match_time>1.6:step=3;game.send_action(0)
		elif step==3 and right_seen and match_time>2.2:step=4;game.send_action(0)
		elif step==4 and left_seen and match_time>2.8:
			step=5;game.selected_id=target.actor_id;game.send_action(12)
	if match_time>(5.0 if host else 4.5):
		var passed:bool=anchor_seen and right_seen and left_seen and divide_seen and flow_seen and caster.identity.meditation==34 and target.hp==990 and no_skeleton_history
		if passed:print("FULCRUM NETWORK %s PASS: anchors, 33-resource combo, tab-targeted instant Divide, rift replication, root-only hit detection"%("HOST" if host else "CLIENT"))
		else:push_error("Fulcrum network failed: %s/%s/%s/%s/%s resource=%s hp=%s cheap=%s"%[anchor_seen,right_seen,left_seen,divide_seen,flow_seen,caster.identity.meditation,target.hp,no_skeleton_history])
		game.leave_session("");quit(0 if passed else 1)
	return false
