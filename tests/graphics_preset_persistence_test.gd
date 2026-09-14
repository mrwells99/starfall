extends SceneTree
var checks := 0
var failures := 0

class MemoryConfig extends "res://scripts/user_config.gd":
	var saved_text := ""
	var saves := 0
	func load_config() -> void:
		if not saved_text.is_empty(): data.parse(saved_text)
	func save_config() -> void:
		saves += 1
		saved_text = data.encode_to_text()
	func apply_display() -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	var config := MemoryConfig.new()
	game.config = config
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var original_mode := config.window_mode()
	for preset in ["High", "Balanced", "Performance", "High"]:
		var index: int = config.GRAPHICS_PRESETS.find(preset)
		var saves_before := config.saves
		game.graphics_choice.select(index)
		game.graphics_choice.item_selected.emit(index)
		check(config.graphics_preset() == preset, "Selection applies " + preset + " immediately")
		check(config.saves == saves_before + 1, "Selection saves without clicking Apply")
		check(config.window_mode() == original_mode, "Preset does not apply pending display-mode settings")
	var saved: String = config.saved_text
	game.queue_free()
	await process_frame
	var restored := MemoryConfig.new()
	restored.saved_text = saved
	var reopened = preload("res://tests/ui_test_arena.gd").new()
	reopened.config = restored
	root.add_child(reopened)
	await process_frame
	reopened.set_process(false)
	reopened.set_physics_process(false)
	check(restored.graphics_preset() == "High", "Fresh session restores last saved preset")
	check(reopened.graphics_choice.selected == restored.GRAPHICS_PRESETS.find("High"), "Reopened menu displays saved preset")
	check(root.scaling_3d_scale > 1, "Saved High rendering scale is reapplied on startup")
	reopened.queue_free()
	await process_frame
	print("Graphics preset persistence checks: %d passed / %d total" % [checks-failures, checks])
	quit(1 if failures else 0)
