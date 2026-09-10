extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	root.disable_3d = true
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var options = game.player_options
	game.config.set_value("comfort", "sensitivity", 1.75)
	game.config.set_value("comfort", "invert_y", true)
	game.config.set_value("comfort", "ui_scale", 1.1)
	game.config.set_value("comfort", "reduced_effects", true)
	game.config.set_value("practice", "difficulty", 2)
	options.load_preferences()
	check(options.sensitivity == 1.75 and options.invert_y and options.reduced_effects, "Comfort preferences load")
	check(is_equal_approx(root.content_scale_factor, 1.1) and options.difficulty == 2, "UI scaling and bot difficulty apply")
	options.save()
	game.config.load_config()
	check(game.config.get_value("comfort", "sensitivity", 0) == 1.75, "Comfort preferences persist")
	game.config.set_value("comfort", "sensitivity", 999)
	game.config.set_value("comfort", "ui_scale", -1)
	game.config.set_value("practice", "difficulty", -1)
	options.load_preferences()
	check(options.sensitivity == 3 and options.ui_scale == 1 and options.difficulty == 0, "Out-of-range preferences are constrained")
	game.mode_choice.select(1)
	game.local_match()
	game.phase = "match"
	var mine = game.actors[1]
	var foe = game.actors[4]
	options.passive = true
	foe.move_input = Vector2.ONE
	foe.casting = 0
	game.bot_think(foe, 1)
	check(foe.move_input == Vector2.ZERO and foe.casting == -1, "Passive opponents do not move or cast")
	options.passive = false
	for level in range(3):
		options.difficulty = level
		foe.ai_timer = 0
		foe.casting = -1
		game.bot_think(foe, 0.01)
		check(is_equal_approx(foe.ai_timer, options.THINK_INTERVALS[level]), "Difficulty changes bot decision interval")
	game.combat_text.clear()
	game.show_event(game.epoch, 5, 2, "−10", Color.RED)
	check(game.combat_text.entries.is_empty(), "Unrelated combat does not flood floating text")
	game.show_event(game.epoch, 1, 4, "−10", Color.RED)
	game.show_event(game.epoch, 4, 1, "−5", Color.RED)
	check(game.combat_text.entries.size() == 2, "Outgoing and incoming results both appear")
	game.show_event(game.epoch, 5, 2, "INTERRUPTED", Color.RED)
	check(game.combat_text.interrupts.has(2), "Other players' frame interrupt markers remain available")
	game.combat_text.clear()
	for i in range(8): game.show_event(game.epoch, 1, 4, "IMMUNE", Color.YELLOW)
	check(game.combat_text.entries.size() == 1, "Repeated immunity messages combine")
	check(foe.flash == 0, "Reduced flashes suppress damage flashes")
	game.combat_text.clear()
	game.CC.apply(foe, "incapacitate", 5, "Solar Flare")
	game.damage(mine, foe, 1)
	var broken := false
	for entry in game.combat_text.entries:
		if entry.node.text == "CC BROKEN": broken = true
	check(broken, "Early damage breaks produce explicit feedback")
	game.recovery.reservations["a".repeat(64)] = {"epoch": game.epoch, "expires": Time.get_ticks_msec() - 1}
	check(game.recovery.reserved_count() == 0, "Expired reconnect reservations are discarded")
	game.recovery.reservations["b".repeat(64)] = {"epoch": game.epoch - 1, "expires": Time.get_ticks_msec() + 90000}
	check(game.recovery.reserved_count() == 0, "Reconnect tickets cannot cross rounds")
	check(not game.recovery.reclaim(99, "invalid"), "Malformed reconnect tickets are refused")
	game.queue_free()
	await process_frame
	await process_frame
	print("Quality of life checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
