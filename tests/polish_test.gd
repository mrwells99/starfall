extends SceneTree
var arena
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(8):
		for actor in arena.actors.values():
			actor.velocity = Vector3(0, -2, 0)
			actor.move_and_slide()
		await physics_frame
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await process_frame
	arena.update_visuals(0)
	check(arena.main_row.visible and arena.quit_button.visible, "Launch offers play and quit")
	check(not arena.resume_button.visible and not arena.exit_button.visible and not arena.scoreboard.visible, "Launch hides match-only controls and HUD")
	check(arena.menu_camera.current, "Launch uses the arena overview camera")
	arena.menu_state = "settings"
	arena.refresh_menu()
	check(not arena.champion_choice.visible and not arena.mode_choice.visible and not arena.resume_button.visible, "Settings hides champion, mode and resume")
	check(arena.graphics_choice.is_visible_in_tree() and arena.frame_limit_choice.is_visible_in_tree(), "Performance settings are reachable")
	arena.menu_state = "offline"
	arena.champion_choice.select(0)
	arena.mode_choice.select(1)
	arena.local_match()
	arena.phase = "match"
	var me = arena.actors[1]
	var enemy = arena.actors[4]
	me.position = Vector3(0, 0.1, 6)
	enemy.position = Vector3(0, 0.1, -6)
	await settle()
	check(arena.camera.current and not arena.menu_camera.current, "Match restores gameplay camera")
	arena.selected_id = 4
	check(arena.ability_block_reason(me, 0, 4).is_empty(), "Ready spell has no advisory block")
	check(arena.ability_block_reason(me, 0, -1) == "Select a living target", "Cleared offensive target is explained")
	check(arena.ability_block_reason(me, 4, -1).is_empty(), "Self defensive remains usable without an enemy target")
	enemy.position.z = -15
	arena.update_visuals(0)
	check(arena.cooldown_overlays[0].availability_label.text == "RANGE", "Ready but distant attack has a range badge")
	check(not arena.try_spell(1, 0, 4) and me.casting == -1, "Authoritative casting rejects the same distant target")
	enemy.position.z = -6
	me.rotation.y = PI
	check(arena.ability_block_reason(me, 0, 4) == "Face your target", "Facing warning uses casting rules")
	me.rotation.y = 0
	me.move_input = Vector2(1, 0)
	check(arena.ability_block_reason(me, 0, 4) == "Stand still to cast", "Moving cast warning")
	me.move_input = Vector2.ZERO
	var nova := -1
	for i in range(me.kit.size()):
		if me.kit[i].kind == "nova": nova = i
	check(nova >= 0 and arena.ability_block_reason(me, nova, 4) == "Requires 40 Heat", "Resource warning before activation")
	me.identity.heat = 50
	check(arena.ability_block_reason(me, nova, 4).is_empty(), "Resource warning clears when resource is gained")
	check(me.identity.heat == 50 and me.cooldowns[nova] == 0, "Read-only preview never spends resources or starts a cooldown")
	me.casting = 0
	check(arena.ability_block_reason(me, 4, 4) == "Already casting", "Off-GCD defensive does not bypass active casting")
	me.casting = -1
	me.position = Vector3(-6, 0, 9)
	enemy.position = Vector3(-6, 0, 0)
	await physics_frame
	check(arena.ability_block_reason(me, 0, 4) == "Target is out of line of sight", "Actual pillar produces LOS warning")
	arena.assignment[14] = nova
	arena.update_visuals(0)
	check(arena.cooldown_overlays[14].availability_reason == arena.cooldown_overlays[nova].availability_reason, "Rearranged/duplicate slots use their assigned ability")
	me.hp = 0
	arena.elapsed = 93
	arena.finish_round(arena.epoch, 1, arena.make_snapshot())
	arena.update_visuals(0)
	check(arena.offline_rematch_button.visible and not arena.resume_button.visible, "Offline results offer Play again, not disabled resume")
	check(arena.round_summary.text.contains("01:33") and arena.round_summary.text.contains("Blue 2/3"), "Summary reports duration and survivors")
	check(not arena.scoreboard.visible, "Results hide the combat HUD")
	var old_epoch: int = arena.epoch
	arena.offline_rematch_button.pressed.emit()
	check(arena.epoch == old_epoch + 1 and arena.phase == "countdown" and arena.actors[1].hp == 100, "Play again actually begins a fresh round")
	check(arena.actors.size() == 6 and arena.actors[1].champion == "Ember", "Rematch preserves class and mode")
	arena.leave_session("")
	arena.update_visuals(0)
	arena.toggle_edit_mode(true)
	arena.update_visuals(0)
	check(arena.bar_roots[0].is_visible_in_tree() and arena.player_frame.visible, "Menu HUD editing still exposes frames and action bars")
	arena.toggle_edit_mode(false)
	# Test policy independently of machine-specific saved preferences.
	var cfg = arena.UserConfig.new()
	check(cfg.frame_budget("match", true) == 60 and cfg.frame_budget("menu", true) == 30 and cfg.frame_budget("match", false) == 15, "Gameplay, menu, and background have explicit budgets")
	cfg.set_value("graphics", "frame_limit", 144)
	check(cfg.frame_budget("countdown", true) == 144 and cfg.frame_budget("results", true) == 30, "Selected gameplay budget does not uncap results")
	check(Engine.physics_ticks_per_second == 60, "Rendering budgets do not change simulation frequency")
	check(cfg.graphics_preset() == "Balanced" and cfg.render_scale() == 1.0, "Default retains native resolution with Balanced effects")
	cfg.set_value("graphics", "preset", "invalid")
	cfg.set_value("graphics", "frame_limit", 0)
	cfg.set_value("graphics", "render_scale", 0.0)
	check(cfg.graphics_preset() == "Balanced" and cfg.frame_limit() == 60 and cfg.render_scale() == 1.0, "Invalid saved graphics values fall back safely")
	print("Polish checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
