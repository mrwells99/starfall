extends "res://scripts/arena.gd"

# This suite measures scripted player input and replicated results. Autonomous
# interrupts/heals can legitimately prevent those results and make the test
# dependent on scheduling. Keep six real actors and their normal physics, but
# hold bot decisions until the scripted first round has been verified.
var hold_bot_decisions := true

func bot_think(actor, delta: float) -> void:
	if hold_bot_decisions:
		actor.move_input = Vector2.ZERO
		return
	super.bot_think(actor, delta)

# Exercise loss on the actual ENet path without changing production transport.
var dropped_first_jump := false
func deliver_input(round_epoch: int, seq: int, movement: Vector2, yaw: float, jump_id: int, selected: int, jump_age: int, walking: bool, revision: int, buffer_jump: bool) -> void:
	if "--test-drop-jump" in OS.get_cmdline_user_args() and jump_id > 0 and not dropped_first_jump:
		dropped_first_jump = true
		return
	super.deliver_input(round_epoch, seq, movement, yaw, jump_id, selected, jump_age, walking, revision, buffer_jump)
