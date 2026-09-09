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
