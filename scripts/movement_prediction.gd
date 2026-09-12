extends RefCounted

# Only movement is predicted. Combat results, control, resources and ability
# displacement arrive from the authority. Replay runs during a physics tick.
var history: Array = []
var pending: Dictionary = {}
var revision := -1
var grounded_override: Variant = null
const HISTORY_LIMIT := 180

func reset() -> void:
	history.clear()
	pending.clear()
	revision = -1
	grounded_override = null

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
	actor.jump_queued = false
	actor.jump_buffer = state.get("jump_buffer", 0.0)
	actor.walking = state.get("walk", false)
	actor.rotation.y = state.yaw
	# Roll's remaining travel is movement state; rewind it before replaying inputs.
	# Combat buffs and combo resources remain server-owned.
	for key in ["roll_left", "roll_direction", "roll_distance", "backflip_active", "lasso", "lasso_knockdown", "null_vantage"]:
		if state.get("identity", {}).has(key):
			var value = state.identity[key]
			actor.identity[key] = value.duplicate(true) if value is Dictionary else value
	# A position rewind does not update CharacterBody3D's cached floor contact.
	# Use the server contact for the first replay/prediction step; subsequent
	# move_and_slide calls provide fresh contact at the replayed position.
	grounded_override = state.get("grounded", null)
	if forced:
		history.clear()
		actor.reset_physics_interpolation()
	else:
		for command in history:
			actor.walking = command.get("walk", false)
			if command.jump: actor.jump_buffer = command.get("buffer", 0.0)
			game.apply_input(actor.actor_id, command.move, command.yaw, command.jump, game.selected_id)
			game.simulate_movement(actor, command.delta, grounded_override)
			grounded_override = null
	# Ignore sub-frame correction noise on clear ground; large errors, collision,
	# knockbacks and teleports always reconcile against the server.
	if not forced and actor.position.distance_to(old_position) < 0.12 and not actor.test_move(actor.transform, old_position - actor.position):
		actor.position = old_position

func predict(game, actor, command: Dictionary) -> void:
	actor.walking = command.get("walk", false)
	if command.jump: actor.jump_buffer = command.get("buffer", 0.0)
	history.append(command)
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	game.apply_input(actor.actor_id, command.move, command.yaw, command.jump, game.selected_id)
	game.simulate_movement(actor, command.delta, grounded_override)
	grounded_override = null
