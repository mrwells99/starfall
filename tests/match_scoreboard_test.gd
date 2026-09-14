extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.mode = 1
	game.roster = {1: {"champion": "Ember", "team": 0}}
	game.begin_round()
	game.phase = "match"
	var a = game.actors[1]
	var b = game.actors[2]
	b.hp = 10
	game.damage(a, b, 80)
	game.damage(a, b, 80)
	check(a.match_stats.damage == 10 and a.match_stats.kills == 1, "Overkill and repeated hits on defeated actors are excluded")
	a.hp = 95
	game.ClassMechanics.heal(game, a, a, 30)
	game.ClassMechanics.heal(game, a, a, 30)
	check(a.match_stats.healing == 5, "Overhealing is excluded")
	b.hp = 100
	for i in range(4): game.ClassMechanics.control(game, a, b, 2, "Test stun")
	check(a.match_stats.cc == 3, "Successful diminished CC counts; immune fourth attempt does not")
	var kick_slot := -1
	for i in range(a.kit.size()):
		if a.kit[i].kind == "interrupt": kick_slot = i
	check(kick_slot >= 0, "Interrupt fixture exists")
	if kick_slot >= 0:
		b.casting = -1
		game.resolve_spell(a, kick_slot, b)
		check(a.match_stats.interrupts == 0, "Missed interrupt is excluded")
		b.casting = 0
		game.resolve_spell(a, kick_slot, b)
		check(a.match_stats.interrupts == 1, "Successful interrupt is counted once")
	var states: Array = game.make_snapshot()
	a.match_stats.damage = 999
	game.finish_round(game.epoch, 0, states)
	check(a.match_stats.damage == 10, "Reliable final state restores authoritative totals")
	check(game.menu_presentation.metrics.get_child_count() == 2, "Results show both teams")
	game.record_stat(a, "damage", 50)
	check(a.match_stats.damage == 10, "Results freeze totals")
	game.begin_round()
	check(game.actors[1].match_stats.damage == 0 and game.actors[1].match_stats.kills == 0, "Rematch clears totals")
	print("Match scoreboard checks: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
