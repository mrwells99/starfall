extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.disable_3d = true
	root.gui_embed_subwindows = true
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var intro = game.menu_presentation.introduction
	for i in range(game.Kits.NAMES.size()):
		game.menu_state = "online"
		game.champion_choice.select(i)
		game.refresh_menu()
		var champion: String = game.Kits.NAMES[i]
		check(intro.visible and intro.selected == champion and not intro.resource.text.is_empty(), "Champion guide follows selection: " + champion)
		var kit: Array = game.Kits.get_kit(champion)
		for row in intro.rows:
			if not row.visible: continue
			var found := false
			for spell in kit:
				if spell.name == row.text:
					found = row.get_meta("ability") == spell and row.tooltip_text.is_empty() and row.icon != null
			check(found, "Signature art and description match live kit: " + row.text)
		intro.rows[0].mouse_entered.emit()
		check(intro.tooltip.visible and intro.tooltip.icon.texture == intro.rows[0].icon, "Hover immediately shows illustrated tooltip")
		check(intro.tooltip.label.text.contains(game.Kits.summary(intro.rows[0].get_meta("ability"))), "Hover describes the live ability")
		intro.rows[0].pressed.emit()
		check(intro.find_children("*", "AcceptDialog", true, false).is_empty(), "Click never opens a popup")
		intro.rows[0].mouse_exited.emit()
		check(not intro.tooltip.visible, "Leaving ability hides tooltip")
		intro.all_button.pressed.emit()
		check(game.menu_state == "abilities" and intro.library, "All Abilities opens the library")
		var visible_count := 0
		for row in intro.rows:
			if row.visible: visible_count += 1
		check(visible_count == kit.size() and game.menu_presentation.preview.visible, "Library lists entire kit with character preview")
		intro.all_button.pressed.emit()
		check(game.menu_state == "online" and not intro.library, "Back returns to selection")
		game.leave_session("")
	game.menu_state = "main"
	game.refresh_menu()
	check(not intro.visible and not game.menu_presentation.hero.visible, "Launch hides champion introduction")
	game.menu_state = "host"
	game.refresh_menu()
	check(not intro.visible and game.menu_presentation.preview.visible, "Host options retain preview without duplicating guide")
	game.queue_free()
	await process_frame
	await process_frame
	print("Champion introduction checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
