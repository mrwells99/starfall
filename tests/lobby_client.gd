extends SceneTree

# Drives one client through the private-lobby flow. With --host-lobby it claims a
# pool slot and prints the code it was given; with --join-code=XXXX it probes the
# pool for that code. --hold keeps the process alive so it keeps occupying a slot.

var arena
var clock := 0.0
var code_seen := false
var match_seen := false
var finishing := false
var want_host := false
var hold := false
var join_code := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host-lobby":
			want_host = true
		elif arg == "--hold":
			hold = true
		elif arg.begins_with("--join-code="):
			join_code = arg.get_slice("=", 1)
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.address.text = "127.0.0.1"
	arena.mode_choice.select(0)
	if want_host:
		arena.host_lobby()
	else:
		arena.join_lobby(join_code)

func _process(delta: float) -> bool:
	if not is_instance_valid(arena) or finishing:
		return false
	clock += delta
	if clock > 40:
		push_error("Lobby client timeout: phase=%s code=%s match=%s" % [arena.phase, arena.lobby_code, match_seen])
		quit(1)
		return false
	if not code_seen and not arena.lobby_code.is_empty():
		code_seen = true
		print("LOBBY CODE=%s port=%d" % [arena.lobby_code, arena.current_port])
	if arena.phase in ["countdown", "match"] and not match_seen:
		match_seen = true
		print("LOBBY MATCH epoch=%d actors=%d" % [arena.epoch, arena.actors.size()])
	if hold:
		return false
	if match_seen and clock > 8:
		print("LOBBY CLIENT PASS: code=%s match=%s local_actor=%s" % [arena.lobby_code, match_seen, arena.actors.has(arena.local_id)])
		finishing = true
		arena.leave_session("Test complete")
		quit(0)
	return false
