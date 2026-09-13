extends SceneTree
var arena
var host:=false
var elapsed:=0.0
var match_time:=0.0
var placed:=false
var sent:=false
var stage:=0
var saw_cloud:=false
var saw_fixed:=false
var saw_expiry:=false
var saw_damage:=false
var checks_ok:=true
var before_hp:=0.0
func _initialize():
	host="--test-host" in OS.get_cmdline_user_args();call_deferred("setup")
func setup():
	arena=load("res://arena.tscn").instantiate();arena.set_script(load("res://tests/network_fixture_arena.gd"));root.add_child(arena)
	Engine.max_fps=60;arena.current_port=53194
	arena.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host:arena.host_session(true);print("SMOKE NETWORK READY")
	else:
		arena.champion_choice.select(arena.Kits.NAMES.find("Null"));arena.address.text="127.0.0.1";arena.join_session()
func _process(delta:float)->bool:
	if arena==null:return false
	elapsed+=delta
	if elapsed>22:push_error("Smoke network timeout");quit(1);return false
	if host and arena.phase=="lobby" and arena.roster.size()==1:
		for entry in arena.roster.values():entry.team=0
		arena.roster[777]={"champion":"Ember","team":1};arena.begin_round()
	if arena.phase!="match":return false
	match_time+=delta
	var a
	var b
	for actor in arena.actors.values():
		if actor.champion=="Null":a=actor
		else:b=actor
	if a==null or b==null:return false
	if host and not placed:
		b.owner_peer=0 # Synthetic opponent is a fixture bot, not a connected peer777.
		placed=true;a.position=Vector3(0,.025,0);b.position=Vector3(0,.025,-6);a.rotation.y=0;b.rotation.y=PI
		a.motion_revision+=1;b.motion_revision+=1
	if not host and not sent and match_time>1:
		sent=true;arena.send_action(arena.assignment.find(10))
	var cloud:Dictionary=a.identity.get("smoke_bomb",{})
	if not cloud.is_empty():
		saw_cloud=true
		if a.position.z>5 and absf(cloud.position.z)<.1:saw_fixed=true
	elif saw_cloud:saw_expiry=true
	if a.hp<a.MAX_HEALTH:saw_damage=true
	if host:
		if stage==0 and not cloud.is_empty():
			checks_ok=checks_ok and arena.validate_spell(b,1,a.actor_id)=="Smoke Bomb blocks this target" and not arena.try_spell(b.actor_id,1,a.actor_id) and b.cooldowns[1]==0
			stage=1
		elif stage==1 and match_time>2:
			b.position.z=-2;b.motion_revision+=1;before_hp=a.hp
			checks_ok=checks_ok and arena.try_spell(b.actor_id,1,a.actor_id) and a.hp<before_hp
			stage=2
		elif stage==2 and match_time>3:
			a.position.z=6;b.position.z=-6;a.motion_revision+=1;b.motion_revision+=1;b.cooldowns[1]=0;b.gcd=0;before_hp=a.hp
			checks_ok=checks_ok and arena.try_spell(b.actor_id,1,a.actor_id) and a.hp<before_hp
			stage=3
	if match_time>(8.5 if host else 8):
		var okay:bool=checks_ok and saw_cloud and saw_fixed and saw_expiry and saw_damage
		if host:okay=okay and stage==3 and a.champion_model==null and a.get_node_or_null("SmokeBombEffect")==null
		if okay:print("SMOKE NETWORK %s PASS: owner cast, replicated fixed cloud/expiry, mixed-side rejection and same-side damage"%["HOST" if host else "CLIENT"])
		else:push_error("Smoke network failed host=%s stage=%s valid=%s cloud=%s fixed=%s expiry=%s damage=%s"%[host,stage,checks_ok,saw_cloud,saw_fixed,saw_expiry,saw_damage])
		arena.leave_session("");quit(0 if okay else 1)
	return false
