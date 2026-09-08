extends SceneTree

var arena
var clock := 0.0
var connected_seen := false
var match_seen := false
var finishing := false
# --queued-only: connect while a round is already running and verify the queue
# holds us for the next one instead of rejecting us. Whether that next round
# actually starts depends on other players staying connected, which is not what
# this is testing.
var queued_only := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--queued-only":
			queued_only = true
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.address.text = "127.0.0.1"
	arena.mode_choice.select(1)
	# Exercise the real queue path: matchmake() picks the port from the mode.
	arena.matchmake()

func _process(delta: float) -> bool:
	if not is_instance_valid(arena) or finishing:
		return false
	clock += delta
	if clock > 40:
		push_error("Dedicated client timeout: phase=%s connected=%s match=%s" % [arena.phase, connected_seen, match_seen])
		quit(1)
		return false
	if arena.phase in ["lobby", "countdown", "match"]:
		connected_seen = true
	if queued_only:
		# A rejection tears the session down and drops us back to the menu.
		if connected_seen and arena.phase == "menu":
			push_error("Queue rejected a mid-round join: %s" % arena.status)
			quit(1)
			return false
		if connected_seen and clock > 6:
			print("DEDICATED CLIENT QUEUED: phase=%s roster=%d" % [arena.phase, arena.roster.size()])
			finishing = true
			arena.leave_session("Test complete")
			quit(0)
		return false
	if arena.phase in ["countdown", "match"] and not match_seen:
		match_seen = true
		print("DEDICATED CLIENT AUTO-START epoch=%d actors=%d" % [arena.epoch, arena.actors.size()])
	if match_seen and clock > 12:
		var local_ok: bool = arena.actors.has(arena.local_id)
		print("DEDICATED CLIENT PASS: connected=%s match_seen=%s local_actor=%s" % [connected_seen, match_seen, local_ok])
		arena.leave_session("Test complete")
		finishing = true
		quit(0 if (connected_seen and match_seen and local_ok) else 1)
		return false
	return false
