extends SceneTree
var arena
var host := false
var elapsed := 0.0
var match_time := 0.0
var applied := false
var sent := false
var success := false
func _initialize() -> void:
	host = "--test-host" in OS.get_cmdline_user_args()
	call_deferred("setup")
func setup() -> void:
	arena=load("res://arena.tscn").instantiate(); arena.set_script(load("res://tests/network_fixture_arena.gd")); root.add_child(arena)
	Engine.max_fps=60; arena.current_port=53198; arena.latency_ms=75
	if host: arena.host_session(true); print("TRINKET NETWORK READY")
	else: arena.champion_choice.select(4); arena.address.text="127.0.0.1"; arena.join_session()
func _process(delta: float) -> bool:
	if arena==null: return false
	elapsed+=delta
	if elapsed>20: push_error("Trinket network timed out"); quit(1); return false
	if host and arena.phase=="lobby" and arena.roster.size()==1:
		arena.roster[777]={"champion":"Ember","team":1}; arena.begin_round()
	if arena.phase!="match": return false
	match_time+=delta
	var actor
	for candidate in arena.actors.values():
		if candidate.champion=="Outlaw": actor=candidate
	if actor==null: return false
	if host and match_time>.6 and not applied:
		applied=true; arena.CC.apply(actor,"stun",5,"Network stun"); actor.gcd=1; actor.locked=2
	if not host and actor.stunned>0 and not sent:
		sent=true
		arena.send_action(arena.assignment.find(arena.Kits.TRINKET_SLOT))
	if actor.cooldowns[14]>116 and actor.stunned==0: success=true
	if match_time>(3.5 if host else 3.0):
		var passed: bool = success and actor.cooldowns[14]>116 and actor.cooldowns[14]<=120
		if passed: print("TRINKET NETWORK %s PASS: hotbar breaks server stun and replicates 120s cooldown" % ["HOST" if host else "CLIENT"])
		else: push_error("Trinket did not replicate: stun=%s cooldown=%s" % [actor.stunned,actor.cooldowns[14]])
		arena.leave_session(""); quit(0 if passed else 1)
	return false
