extends SceneTree

var arena
var clock := 0.0
var connected_seen := false
var match_seen := false
var finishing := false

func _initialize() -> void:
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
