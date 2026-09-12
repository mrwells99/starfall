extends SceneTree
var arena
var host:=false
var observer:=false
var elapsed:=0.0
var match_time:=0.0
var placed:=false
var step:=0
var saw_stealth:=false
var saw_detection:=false
var saw_backstab:=false
var saw_dive:=false
var saw_knockdown:=false
func _initialize() -> void:
	host="--test-host" in OS.get_cmdline_user_args()
	observer="--test-observer" in OS.get_cmdline_user_args();call_deferred("setup")
func setup() -> void:
	arena=load("res://arena.tscn").instantiate();arena.set_script(load("res://tests/network_fixture_arena.gd"));root.add_child(arena)
	Engine.max_fps=60;arena.current_port=53194
	arena.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host:arena.host_session(true);print("NULL NETWORK READY")
	else:
		arena.champion_choice.select(arena.Kits.NAMES.find("Ember" if observer else "Null"))
		arena.address.text="127.0.0.1";arena.join_session()
func _process(delta: float) -> bool:
	if arena==null:return false
	elapsed+=delta
	if elapsed>22:push_error("Null network timeout "+arena.phase);quit(1);return false
	if host and arena.phase=="lobby" and arena.roster.size()==1:
		for entry in arena.roster.values():entry.team=0
		arena.roster[777]={"champion":"Null" if observer else "Ember","team":1};arena.begin_round()
	if arena.phase!="match":return false
	match_time+=delta
	var a
	var b
	for actor in arena.actors.values():
		if actor.champion=="Null":a=actor
		else:b=actor
	if a==null or b==null:return false
	if host and not placed:
		placed=true;a.position=Vector3(0,.025,0);b.position=Vector3(0,.025,-2);a.rotation.y=0;b.rotation.y=PI*.4
		a.motion_revision+=1;b.motion_revision+=1
	if arena.Null.stealthed(a):
		saw_stealth=true
		if arena.locked_target_for(b.actor_id)!=-1:push_error("Stealth did not release network target lock");quit(1)
		if arena.Null.detected(a,b):saw_detection=true
		if not host:
			var art=a.champion_model.null_art
			art.visibility_for(a,arena.actors[arena.local_id])
			if art.last_alpha!=.5:push_error("Network stealth alpha");quit(1)
	if b.hp<=65:saw_backstab=true
	if arena.Null.busy(a):saw_dive=true
	if b.cc_effects.get("stun",{}).get("source","")=="Vantage Point":saw_knockdown=true
	var controller: bool=(host and observer) or (not host and not observer)
	if controller:
		var slot:=-1
		if step==0 and match_time>1:step=1;slot=4
		elif step==1 and match_time>2.2 and saw_detection:step=2;slot=6
		elif step==2 and match_time>2.7:step=3;slot=1
		elif step==3 and match_time>4.5:step=4;slot=7
		if slot>=0:
			if host:arena.try_spell(a.actor_id,slot,b.actor_id)
			else:
				arena.selected_id=b.actor_id
				var bar: int=arena.assignment.find(slot)
				arena.send_action(bar)
	if match_time>(8.0 if host else 7.5):
		var okay: bool=saw_stealth and saw_detection and saw_backstab and saw_dive and saw_knockdown and b.hp==43 and not arena.Null.stealthed(a) and arena.locked_target_for(b.actor_id)==a.actor_id
		if host:okay=okay and a.champion_model==null and not ResourceLoader.has_cached("res://assets/characters/null.glb")
		if okay:print("NULL NETWORK %s PASS: replicated stealth, proximity detection, auto-target restoration, backstab and dive; observer=%s" % ["HOST" if host else "CLIENT",observer])
		else:push_error("Null network failed host=%s observer=%s stealth=%s detection=%s stab=%s dive=%s down=%s hp=%s" % [host,observer,saw_stealth,saw_detection,saw_backstab,saw_dive,saw_knockdown,b.hp])
		arena.leave_session("");quit(0 if okay else 1)
	return false
