extends "res://scripts/arena.gd"
## Benchmark-only instrumentation. Production scripts and settings are unchanged.
var bench_round := 0
var bench_tick := 0
var bench_active := false
var bench_replay := false
var bench_events: Array = []
var bench_tape: Dictionary = {}
var bench_current: Dictionary = {}
var bench_context := ""
var bench_physics_us := 0
var bench_visual_us := 0
var bench_tick_count := 0
var bench_origin := 0
var bench_suppress_events := false
var bench_suppress_flash := false
var bench_suppress_beams := false
var bench_suppress_strikes := false
var bench_profile_strikes := false
var bench_retain_strike_material := false
var bench_pause_unfocused := false

func trace_event(kind: String, ability: String, source: int, victim: int, started: int, extra: Dictionary = {}) -> void:
	var record := {"round": bench_round, "tick": bench_tick, "kind": kind, "ability": ability, "source": source, "victim": victim,
		"start_us": started, "end_us": Time.get_ticks_usec(), "frame": Engine.get_process_frames()}
	record.merge(extra)
	bench_events.append(record)

func gather_input(_delta: float) -> void:
	pass # Six simulated fighters; keyboard/mouse cannot alter the replay.

func tick_camera_save(_delta: float) -> void:
	pass # Never write the owner's preferences from a benchmark.

func check_winner() -> void:
	pass # The sample has a fixed duration; damage clamps at 1 HP below.

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	if bench_active and bench_pause_unfocused and not application_focused:
		Engine.max_fps = 15
		return
	if bench_active:
		bench_tick += 1
	super._physics_process(delta)
	bench_physics_us += Time.get_ticks_usec() - started
	bench_tick_count += 1

func update_visuals(delta: float) -> void:
	var started := Time.get_ticks_usec()
	if bench_suppress_flash:
		for fighter in actors.values(): fighter.flash = 0.0
	super.update_visuals(delta)
	bench_visual_us += Time.get_ticks_usec() - started

func bot_think(actor, delta: float) -> void:
	if not bench_active:
		actor.move_input = Vector2.ZERO
		return
	var key := "%d:%d" % [bench_tick, actor.actor_id]
	if bench_replay:
		if not bench_tape.has(key):
			trace_event("replay_missing", "", actor.actor_id, -1, Time.get_ticks_usec())
			return
		var command: Dictionary = bench_tape[key]
		for cast in command.casts:
			actor.move_input = cast.move
			actor.rotation.y = cast.yaw
			actor.target_id = cast.target
			var accepted := try_spell(actor.actor_id, cast.slot, cast.requested)
			if accepted != cast.accepted:
				trace_event("replay_mismatch", actor.kit[cast.slot].name, actor.actor_id, cast.requested, Time.get_ticks_usec(), {"expected": cast.accepted, "actual": accepted})
		actor.move_input = command.move
		actor.rotation.y = command.yaw
		actor.target_id = command.target
		actor.jump_queued = command.jump
	else:
		bench_current = {"casts": []}
		super.bot_think(actor, delta)
		bench_current.merge({"move": actor.move_input, "yaw": actor.rotation.y, "target": actor.target_id, "jump": actor.jump_queued})
		bench_tape[key] = bench_current
		bench_current = {}

func try_spell(id: int, slot: int, requested: int) -> bool:
	var started := Time.get_ticks_usec()
	var actor = actors.get(id)
	var ability: String = actor.kit[slot].name if actor != null and slot >= 0 and slot < actor.kit.size() else "invalid"
	var command := {"slot": slot, "requested": requested, "move": actor.move_input if actor != null else Vector2.ZERO,
		"yaw": actor.rotation.y if actor != null else 0.0, "target": actor.target_id if actor != null else -1}
	var accepted := super.try_spell(id, slot, requested)
	if not bench_replay and not bench_current.is_empty():
		command.accepted = accepted
		bench_current.casts.append(command)
	if accepted:
		trace_event("cast", ability, id, requested, started, {"champion": actor.champion, "cast_time": actor.kit[slot].cast})
	return accepted

func resolve_spell(actor, slot: int, victim) -> void:
	var started := Time.get_ticks_usec()
	var previous := bench_context
	bench_context = actor.kit[slot].name
	super.resolve_spell(actor, slot, victim)
	trace_event("resolve", bench_context, actor.actor_id, victim.actor_id if victim != null else -1, started, {"champion": actor.champion})
	bench_context = previous

func damage(source, victim, amount: float) -> void:
	var previous := bench_context
	if bench_context.is_empty():
		if source.champion == "Fulcrum" and amount == 2 and victim.identity.entropy_dots.has(source.actor_id):
			bench_context = "Entropy tick"
		elif source.champion == "Fulcrum" and amount in [3.0, 6.0] and victim.identity.dots.has(source.actor_id):
			bench_context = "Graviton tick"
		elif source.champion == "Ember" and amount == 4 and source.identity.wake > 0:
			bench_context = "Burning field tick"
		else:
			bench_context = "Periodic/redirect damage"
	super.damage(source, victim, minf(amount, maxf(0, victim.hp - 1)))
	bench_context = previous

func combat_event(source: int, victim: int, text: String, color: Color) -> void:
	var started := Time.get_ticks_usec()
	if not bench_suppress_events:
		if (bench_suppress_strikes or bench_profile_strikes) and source != victim and actors.has(source) and actors[source].champion == "Vanguard" and text.begins_with("−"):
			# Retain the real label, hit flash and attack animation; isolate only arc/sparks.
			show_event(epoch, victim, victim, text, color)
			actors[source].champion_model.present_strike()
			if bench_profile_strikes:
				preload("res://tools/frame_time_strike.gd").spawn(self, actors[source].position, actors[victim].position, actors[source].base_color)
		else:
			super.combat_event(source, victim, text, color)
	trace_event("impact", bench_context if not bench_context.is_empty() else text, source, victim, started, {"text": text})

func beam(from: Vector3, to: Vector3, color: Color) -> void:
	var started := Time.get_ticks_usec()
	if not bench_suppress_beams:
		super.beam(from, to, color)
	trace_event("beam_creation", bench_context, -1, -1, started)
