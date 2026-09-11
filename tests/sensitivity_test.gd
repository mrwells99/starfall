extends SceneTree
var game
var checks := 0
var failures := 0
class MemoryConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	root.disable_3d = true
	game = load("res://tests/ui_test_arena.gd").new()
	game.config = MemoryConfig.new()
	game.config.set_value("comfort", "sensitivity", 1.6)
	root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.set_physics_process(false)
	var options = game.player_options
	check(options.sensitivity == 1.6 and options.ads_sensitivity == 1.6, "Existing settings preserve both normal and aiming speed on migration")
	game.menu_state = "settings"; game.refresh_menu()
	await process_frame
	check(options.sensitivity_slider.is_visible_in_tree() and options.ads_sensitivity_slider.is_visible_in_tree(), "Both sliders appear directly in Settings")
	options.sensitivity_slider.value = 1.8
	options.ads_sensitivity_slider.value = .6
	game.apply_settings()
	check(is_equal_approx(options.sensitivity,1.8) and is_equal_approx(options.ads_sensitivity,.6), "Settings Apply commits independent sensitivities")
	options.sensitivity = 1; options.ads_sensitivity = 1
	options.load_preferences()
	check(is_equal_approx(options.sensitivity,1.8) and is_equal_approx(options.ads_sensitivity,.6), "Both preferences survive reload")
	options.open(); options.apply(); options.dialog.hide()
	check(is_equal_approx(options.sensitivity,1.8) and is_equal_approx(options.ads_sensitivity,.6), "Comfort settings cannot overwrite mouse slider preferences")
	game.champion_choice.select(game.Kits.NAMES.find("Outlaw"))
	game.local_match(); game.phase = "match"; game.panel.hide(); game.application_focused = true
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(10,5)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT; button.pressed = true
	game.movement_controls.begin(button)
	game.pivot.rotation.y = 0; game.arm.rotation.x = -.3
	game._input(motion)
	check(is_equal_approx(game.pivot.rotation.y,-.072) and is_equal_approx(game.arm.rotation.x,-.336), "Ordinary camera uses general sensitivity on both axes")
	game.send_action(game.assignment.find(8))
	check(game.outlaw_aim_test.enabled, "Defense Detonation enters aiming")
	game.pivot.rotation.y = 0; game.outlaw_aim_test.aim_pitch = 0
	game._input(motion)
	check(is_equal_approx(game.pivot.rotation.y,-.018) and is_equal_approx(game.outlaw_aim_test.aim_pitch,-.009), "Aiming uses ADS sensitivity on both axes immediately during its transition")
	options.sensitivity = 3
	game.pivot.rotation.y = 0; game.outlaw_aim_test.aim_pitch = 0
	options.invert_y = true
	game._input(motion)
	check(is_equal_approx(game.pivot.rotation.y,-.018) and is_equal_approx(game.outlaw_aim_test.aim_pitch,.009), "ADS is independent of general sensitivity and honors inverted vertical look")
	options.invert_y = false
	game.send_action(game.assignment.find(8))
	game.pivot.rotation.y = 0; game.arm.rotation.x = -.3
	game._input(motion)
	check(is_equal_approx(game.pivot.rotation.y,-.12) and is_equal_approx(game.arm.rotation.x,-.36), "Leaving aim immediately restores general sensitivity with held right-click")
	button.pressed = false; game._input(button)
	game.config.set_value("comfort", "sensitivity", "invalid")
	game.config.set_value("comfort", "ads_sensitivity", NAN)
	options.load_preferences()
	check(options.sensitivity == 1 and options.ads_sensitivity == 1, "Malformed or nonfinite sensitivity safely falls back")
	game.config.set_value("comfort", "sensitivity", 100)
	game.config.set_value("comfort", "ads_sensitivity", -4)
	options.load_preferences()
	check(options.sensitivity == 3 and options.ads_sensitivity == .25, "Loaded sensitivity remains within slider bounds")
	game.clear_actors(); game.queue_free(); await process_frame
	print("Sensitivity checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
