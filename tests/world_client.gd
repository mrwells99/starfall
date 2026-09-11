extends SceneTree

# Connects to a --world server the way the World menu button does, and reports
# whether the world actually admits it.

var arena
var clock := 0.0
var done := false

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.address.text = "127.0.0.1"
	arena.enter_world()

func _process(delta: float) -> bool:
	if done or not is_instance_valid(arena):
		return false
	clock += delta
	# "match", not "countdown": round_started() puts every client into a
	# countdown, and the world has none — the next snapshot corrects it. Waiting
	# for the corrected phase proves the client is actually playing.
	if arena.phase == "match" and clock > 2.0:
		if arena.selected_id != -1 or arena.enemy_box.visible:
			push_error("World arrival auto-targeted an actor or displayed arena frames")
			quit(1)
			return false
		for id in arena.TrainingDummies.IDS:
			if not arena.actors.has(id) or not arena.actors[id].training_dummy or arena.actors[id].hp < 1:
				push_error("World client missing a replicated training dummy")
				quit(1)
				return false
		print("WORLD CLIENT IN: phase=%s actors=%d local=%d" % [arena.phase, arena.actors.size(), arena.local_id])
		done = true
		if "--test-hold" in OS.get_cmdline_user_args():
			return false
		arena.leave_session("done")
		quit(0)
		return false
	if clock > 20.0:
		push_error("World client stuck: phase=%s status=%s roster=%d" % [arena.phase, arena.status, arena.roster.size()])
		quit(1)
		return false
	return false
