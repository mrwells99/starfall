extends SceneTree
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var placed := false
var sent := false
var seen_pull := false
var seen_down := false
var seen_free := false
func _initialize() -> void:
	host="--test-host" in OS.get_cmdline_user_args(); call_deferred("setup")
func setup() -> void:
	arena=load("res://arena.tscn").instantiate(); arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps=60; arena.current_port=53196
	arena.latency_ms=75 if "--test-latency" in OS.get_cmdline_user_args() else 0
	if host: arena.host_session(true); print("LASSO NETWORK READY")
	else: arena.champion_choice.select(4); arena.address.text="127.0.0.1"; arena.join_session()
func _process(delta: float) -> bool:
	if arena==null: return false
	elapsed+=delta
	if elapsed>20: push_error("Lasso network timeout"); quit(1); return false
	if host and arena.phase=="lobby" and arena.roster.size()==1:
		for entry in arena.roster.values(): entry.team=0
		arena.roster[777]={"champion":"Ember","team":1}; arena.begin_round()
	if arena.phase!="match": return false
	match_time+=delta
	var a
	var b
	for actor in arena.actors.values():
		if actor.champion=="Outlaw": a=actor
		else: b=actor
	if a==null or b==null: return false
	if host and not placed:
		placed=true; a.position=Vector3(0,.025,4); b.position=Vector3(0,.025,-10)
		a.rotation.y=0; b.rotation.y=PI; a.motion_revision+=1; b.motion_revision+=1
	if not host and not sent and match_time>.7:
		sent=true; arena.selected_id=b.actor_id; arena.send_action(arena.assignment.find(11))
	seen_pull=seen_pull or arena.Outlaw.Lasso.state(a).get("phase","")=="pull"
	seen_down=seen_down or arena.Outlaw.Lasso.knockdown_active(b)
	seen_free=seen_free or (a.identity.defense_detonation==1 and not arena.Outlaw.Lasso.busy(a) and b.stunned>.5)
	if match_time>(5.5 if host else 4.5):
		var okay: bool=seen_pull and seen_down and seen_free and a.identity.defense_detonation==1 and b.hp==100 and b.stunned==0 and not arena.Outlaw.Lasso.busy(a)
		if host: okay=okay and a.champion_model==null and not ResourceLoader.has_cached("res://assets/characters/outlaw.glb")
		if okay: print("LASSO NETWORK %s PASS: traveling pull, stun, knockdown, early recovery and exactly one stack" % ["HOST" if host else "CLIENT"])
		else: push_error("Lasso network failed: host=%s pull=%s down=%s free=%s stacks=%s phase=%s" % [host,seen_pull,seen_down,seen_free,a.identity.defense_detonation,arena.Outlaw.Lasso.state(a)])
		arena.leave_session(""); quit(0 if okay else 1)
	return false
