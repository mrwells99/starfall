extends SceneTree
var game
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func choose(champion: String) -> void:
	game.champion_choice.select(game.Kits.NAMES.find(champion))
	game.champion_choice.item_selected.emit(game.champion_choice.selected)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game = preload("res://tests/ui_test_arena.gd").new(); root.add_child(game)
	game.set_physics_process(false); await process_frame
	game.config.data.clear()
	game.default_bindings(); game.controls.actions = game.controls.DEFAULTS.duplicate(true)
	game.controls.setup(game.TOTAL_SLOTS)
	# Recreate an existing shared setup, including an F1 hotbar position.
	game.controls.assign(game, "bar_0", 0, KEY_F1)
	game.controls.save(game.config)
	game.config.set_value("hud", "binds", game.binds.duplicate())
	game.config.set_value("hud", "assignment", game.assignment.duplicate())
	game.load_layout()
	var starter: Dictionary = game.control_state()
	ck(game.binds[0] == KEY_F1, "Legacy shared setup migrates without losing F1")
	game.save_layout()
	ck(not game.config.data.has_section("champion_controls"), "Ordinary HUD save does not customize a class")
	choose("Vanguard")
	ck(game.control_state() == starter, "First Vanguard visit inherits shared starter")
	game.swap_slots(6, 0)
	var warrior: Dictionary = game.control_state()
	ck(game.assignment[0] == 6 and game.binds[0] == KEY_F1, "Charge moves to F1")
	choose("Ember")
	ck(game.control_state() == starter and game.assignment[0] == 0, "Vanguard drag cannot move Ember Blink")
	game.swap_slots(6, 5)
	game.controls.assign(game, "bar_5", 0, KEY_F6)
	game.controls.assign(game, "bar_5", 1, KEY_B | KEY_MASK_SHIFT)
	game.controls.assign(game, "forward", 0, KEY_J)
	game.save_layout()
	var mage: Dictionary = game.control_state()
	ck(game.assignment[5] == 6 and game.binds[5] == KEY_F6, "Blink gets its separate F6 position")
	choose("Vanguard")
	ck(game.control_state() == warrior, "Vanguard restores all bindings and Charge position")
	ck(game.controls.actions.forward[0] == KEY_W, "Ember movement binding cannot affect Vanguard")
	choose("Luminary")
	ck(game.control_state() == starter, "Uncustomized third class still inherits shared template")
	choose("Ember")
	ck(game.control_state() == mage, "Ember restores primary, secondary, movement and positions")
	game.keybind_menu.open()
	ck(game.keybind_menu.heading.text == "EMBER KEYBINDS", "Editor names the class being customized")
	game.keybind_menu.close()
	# Round-trip the actual configuration representation to catch aliasing/save bugs.
	var serialized: String = game.config.data.encode_to_text()
	game.config.data.clear(); game.config.data.parse(serialized)
	game.default_bindings(); game.load_layout()
	ck(game.control_state() == mage, "Class profile survives config serialization and reload")
	choose("Vanguard")
	ck(game.control_state() == warrior, "Other saved profile survives reload independently")
	game.reset_all_keybinds()
	ck(game.assignment == warrior.assignment and game.binds[0] != KEY_F1, "Reset keys applies only to active class and preserves ability layout")
	choose("Ember")
	ck(game.control_state() == mage, "Resetting Vanguard does not reset Ember")
	choose("Vanguard"); game.reset_layout()
	choose("Ember")
	ck(game.control_state() == mage, "Resetting Vanguard layout does not reset Ember")
	ck(game.config.get_value("hud", "assignment", []) == starter.assignment and game.config.get_value("hud", "binds", []) == starter.binds, "Shared starting template stays unchanged")
	# The actual spawned champion wins over a stale menu selection.
	game.mode = 1; game.roster = {1: {"champion": "Ember", "team": 0}}
	game.begin_round(); game.phase = "match"
	choose("Vanguard")
	ck(game.controls_champion == "Ember" and game.control_state() == mage, "In-match binding edits belong to actual local champion")
	game.controls.assign(game, "bar_5", 0, KEY_F7); game.save_layout()
	game.clear_actors(); game.refresh_menu()
	ck(game.controls_champion == "Vanguard" and game.binds[5] != KEY_F7, "Leaving character restores selected class without leakage")
	print("Champion controls checks: %d passed / %d total" % [checks-failures, checks])
	game.queue_free(); await process_frame; quit(1 if failures else 0)
