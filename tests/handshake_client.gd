extends SceneTree
var arena
var elapsed := 0.0
var finished := false
func _initialize() -> void: call_deferred("setup")
func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.address.text = "127.0.0.1"
	arena.world_mode = true
	arena.intent = "queue"
	arena.connect_to(27943)
func _process(delta: float) -> bool:
	if arena == null or finished: return false
	elapsed += delta
	if not arena.actors.is_empty() or arena.phase in ["lobby", "countdown", "match"]:
		finished = true
		push_error("Incompatible peer reached the gameplay session")
		quit(1)
	elif arena.phase == "menu" and elapsed > .1:
		finished = true
		var message: String = arena.status.to_lower()
		if "mismatch" not in message and "compatibility" not in message:
			push_error("Missing actionable compatibility error: " + arena.status)
			quit(1)
		else:
			print("HANDSHAKE REJECTION PASS: " + arena.status)
			quit(0)
	elif elapsed > 12:
		finished = true
		push_error("Compatibility check did not terminate")
		quit(1)
	return false
