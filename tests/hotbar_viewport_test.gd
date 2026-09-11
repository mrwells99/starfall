extends SceneTree
## Saved desktop coordinates must never hide a class's abilities on another display.
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
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame
	game.update_visuals(0)
	await process_frame

func check_abilities(label: String) -> void:
	var screen := Rect2(Vector2.ZERO, game.ui.size)
	var expected: Array[int] = []
	var kit: Array = preload("res://scripts/kits.gd").get_kit("Outlaw")
	for ability in kit.size():
		if kit[ability].kind != "unavailable": expected.append(ability)
	var assigned: Array[int] = []
	for slot in range(game.TOTAL_SLOTS):
		var ability: int = game.kit_slot(slot)
		if ability < 0: continue
		assigned.append(ability)
		check(game.ability_buttons[slot].is_visible_in_tree() and screen.encloses(game.ability_buttons[slot].get_global_rect()), label + ": ability %d is visible inside the viewport" % slot)
	assigned.sort()
	check(assigned == expected, label + ": all %d available Outlaw abilities remain assigned exactly once" % expected.size())

func run() -> void:
	root.disable_3d = true
	if "--capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_current_screen(0)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(40, 50))
		DisplayServer.window_set_title("Starfall — Outlaw ability bar verification")
	game = preload("res://tests/ui_test_arena.gd").new()
	game.config = MemoryConfig.new()
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.set_process(false)
	game.mode = 1
	game.roster = {1: {"champion": "Outlaw", "team": 0}, 2: {"champion": "Vanguard", "team": 1}}
	game.begin_round()
	game.phase = "match"
	game.panel.hide()
	game.ui.size = Vector2(1280, 720)
	await settle()
	# These are the actual stale bar coordinates from the reported layout.
	var places := {"ActionBar1": Vector2(296, 944), "ActionBar2": Vector2(296, 881), "ActionBar3": Vector2(296, 818)}
	# A normal saved layout also contains non-HBox controls. Checking one of
	# those against Array[HBoxContainer] raises an engine error before a match.
	places.CrowdControl = Vector2(422, 608)
	places.PlayerFrame = Vector2(414, 515)
	places.TargetFrame = Vector2(787, 515)
	places.FocusFrame = Vector2(1048, 515)
	places.PartyFrame = Vector2(24, 220)
	places.EnemyFrame = Vector2(1068, 220)
	game.config.set_value("hud", "frames", places)
	game.config.set_value("hud", "moved", [])
	game.config.set_value("hud", "slot_size", 55)
	var assignments: Array = game.assignment.duplicate()
	assignments[0] = 1
	assignments[1] = 0
	var bindings: Array = game.binds.duplicate()
	bindings[0] = KEY_F8
	game.config.set_value("hud", "assignment", assignments)
	game.config.set_value("hud", "binds", bindings)
	game.load_layout()
	await settle()
	check_abilities("Unmoved saved bars")
	check(game.assignment == assignments and game.binds == bindings, "Recovering bar positions preserves custom ability order and keys")
	check(game.cc_tracker.position.is_equal_approx(places.CrowdControl), "Full saved layout restores a non-HBox panel without typed-array errors")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/outlaw-forge-v2/hotbar-viewport-fixed.png")

	# A real custom placement stays put when it already fits.
	places.ActionBar1 = Vector2(90, 300)
	game.config.set_value("hud", "frames", places)
	game.config.set_value("hud", "moved", ["ActionBar1"])
	game.load_layout()
	await settle()
	check(game.bar_roots[0].position.is_equal_approx(Vector2(90, 300)), "Valid custom bar position is preserved")
	check_abilities("Custom saved bar")

	# Lost custom bars return to separate default rows instead of overlapping.
	places.ActionBar1 = Vector2(2500, 1600)
	game.config.set_value("hud", "frames", places)
	game.config.set_value("hud", "moved", ["ActionBar1", "ActionBar2", "ActionBar3"])
	game.load_layout()
	await settle()
	check_abilities("Off-screen custom bars")
	check(not game.bar_roots[0].get_rect().intersects(game.bar_roots[1].get_rect()), "Recovered bars do not overlap")
	for dimensions in [Vector2(1920, 1080), Vector2(3440, 1440), Vector2(1280, 720)]:
		game.ui.size = dimensions
		await settle()
		check_abilities("Resized to %s" % dimensions)
	# A valid large-screen custom placement can fall outside a smaller monitor.
	game.ui.size = Vector2(3440, 1440)
	await settle()
	game.bar_roots[0].position = Vector2(2700, 800)
	game.moved_frames["ActionBar1"] = true
	game.ui.size = Vector2(1280, 720)
	await settle()
	check_abilities("Resized custom layout")
	check(game.assignment == assignments and game.binds == bindings, "Resizing preserves ability order and bindings")
	# Shared assignments stay intact, but Outlaw's retired Aim Test is hidden.
	assignments[10] = -1; bindings[10] = KEY_F9
	game.config.set_value("hud","assignment",assignments)
	game.config.set_value("hud","binds",bindings)
	game.load_layout(); await settle()
	check(game.kit_slot(10) == -1 and not game.ability_buttons[10].visible and game.binds[10] == KEY_F9,"Old Aim Test slot stays hidden without overwriting its shared saved key")
	check(game.assignment[0] == 1 and game.assignment[1] == 0 and game.binds[0] == KEY_F8,"Merging aim into Detonation preserves existing combat ability order and keys")
	check_abilities("Migrated older layout")
	game.queue_free()
	await process_frame
	print("Hotbar viewport checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
