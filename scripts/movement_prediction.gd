extends RefCounted

# Only movement is predicted. Combat results, control, resources and ability
# displacement arrive from the authority. Replay runs during a physics tick.
var history: Array = []
var pending: Dictionary = {}
var revision := -1
const HISTORY_LIMIT := 180

func reset() -> void:
	history.clear()
	pending.clear()
	revision = -1

func reconcile(game, actor) -> void:
	if pending.is_empty():
		return
	var state: Dictionary = pending
	pending = {}
	var ack: int = state.get("move_ack", -1)
	while not history.is_empty() and int(history[0].seq) <= ack:
		history.pop_front()
	var old_position: Vector3 = actor.position
	var forced: bool = revision != int(state.get("motion_revision", 0)) or actor.hp <= 0
	revision = int(state.get("motion_revision", 0))
	actor.position = state.pos
	actor.velocity = state.get("velocity", Vector3.ZERO)
	actor.rotation.y = state.yaw
	if forced:
		history.clear()
	else:
		for command in history:
			game.apply_input(actor.actor_id, command.move, command.yaw, command.jump, game.selected_id)
			game.simulate_movement(actor, command.delta)
	# Ignore sub-frame correction noise on clear ground; large errors, collision,
	# knockbacks and teleports always reconcile against the server.
	if not forced and actor.position.distance_to(old_position) < 0.12 and not actor.test_move(actor.transform, old_position - actor.position):
		actor.position = old_position

func predict(game, actor, command: Dictionary) -> void:
	history.append(command)
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	game.apply_input(actor.actor_id, command.move, command.yaw, command.jump, game.selected_id)
	game.simulate_movement(actor, command.delta)
