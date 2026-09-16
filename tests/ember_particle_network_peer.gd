extends SceneTree
var game
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var step := 0
var seen := {"trail":false,"spirit":false,"recall":false,"normal":false,"hidden":false,"moving":false,"immune":false}
var failures := 0
var remote_id := -1
var finishing := false
func require(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void:
	host="--test-host" in OS.get_cmdline_user_args()
	call_deferred("setup")
func setup() -> void:
	game=load("res://arena.tscn").instantiate()
	game.set_script(load("res://tests/ember_particle_network_arena.gd"));root.add_child(game)
	game.current_port=53217
	game.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	game.champion_choice.select(0)
	if host:game.host_session();print("EMBER PARTICLE NETWORK READY")
	else:game.address.text="127.0.0.1";game.join_session()
func _process(delta: float) -> bool:
	if game==null or finishing:return false
	elapsed+=delta
	if elapsed>22:push_error("Ember particle network timeout");quit(1);return false
	if host and game.phase=="lobby" and game.roster.size()==2:game.host_start()
	if game.phase!="match":return false
	match_time+=delta
	var first=game.actors.get(1)
	var remote=null
	for a in game.actors.values():
		if a.owner_peer!=0 and a.owner_peer!=1:remote_id=a.actor_id;break
	remote=game.actors.get(remote_id)
	if first==null or remote==null:return false
	if host and not placed:
		placed=true
		first.position=Vector3(-2,.025,2);remote.position=Vector3(2,.025,2)
		for a in [first,remote]:a.identity.heat=100;a.motion_revision+=1
	if host:
		if step==0 and match_time>1:
			step=1;game.try_spell(1,12,-1)
		game.scripted_move=Vector2.UP if match_time>1.2 and match_time<1.8 else Vector2.ZERO
	else:
		game.scripted_move=Vector2.UP if match_time>.8 and match_time<1.3 else (Vector2.RIGHT if match_time>2.2 and match_time<2.5 else Vector2.ZERO)
		if step==0 and match_time>.6:step=1;game.send_action(9)
		elif step==1 and match_time>2:step=2;game.send_action(12)
		elif step==2 and match_time>3:step=3;game.send_action(12)
	if remote.identity.get("cinder_trail",[]).size()>2:seen.trail=true
	if game.Ember.spirit(remote):
		seen.spirit=true
		if host:
			var before:float=remote.hp;game.damage(first,remote,10)
			seen.immune=remote.hp==before
			if remote.position.distance_to(remote.identity.ash_origin)>.8:seen.moving=true
		else:
			if remote.position.distance_to(remote.identity.ash_origin)>.8:seen.moving=true
			seen.immune=remote.hp==remote.MAX_HEALTH
			if not remote.get_node("EmberEffects").spirit_aura.visible and match_time>2.5:require(false,"Owner spirit aura must render")
	if int(remote.identity.get("ash_phase",0))==2:
		seen.recall=true
		require(remote.identity.ash_return.size()>=3,"Return route reaches peer with actual movement")
	if seen.recall and int(remote.identity.get("ash_phase",0))==0:seen.normal=true
	if game.Ember.spirit(first) and match_time>2:
		if host:
			seen.hidden=first.position.distance_to(first.identity.ash_origin)>.8
		else:
			seen.hidden=first.net_position.distance_to(first.identity.ash_origin)<.01 and not first.champion_model.ember_art.model.visible
	if match_time>(8.0 if host else 7.3):
		for key in seen:require(seen[key],"Missing replicated behavior: "+key)
		print("EMBER PARTICLE NETWORK %s %s: %s"%["HOST" if host else "CLIENT","PASS" if failures==0 else "FAIL",seen])
		if host: print("Peak compressed snapshot payload: ",game.peak_packet," bytes")
		finishing=true
		finish()
	return false

func finish() -> void:
	game.leave_session("")
	# Drain the fixture's artificial-delay timers before freeing its arena.
	await create_timer(.25).timeout
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
