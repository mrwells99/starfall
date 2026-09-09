extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)
func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.disable_3d = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode_choice.select(1)
	game.local_match()
	game.phase = "match"
	var s = game.spectator
	var me = game.actors[game.local_id]
	var ids: Array[int] = []
	var enemy := -1
	for actor in game.actors.values():
		if actor.team == me.team and actor != me: ids.append(actor.actor_id)
		if actor.team != me.team: enemy = actor.actor_id
	game.update_visuals(0)
	check(not s.active and not s.card.visible, "Living players have no spectator panel")
	s.record(enemy, me.actor_id, "STUN")
	s.record(enemy, me.actor_id, "−42")
	s.record(enemy, me.actor_id, "DEFEATED")
	me.hp = 0
	game.update_visuals(0)
	check(s.active and s.card.visible, "Death shows eliminated panel")
	check(s.survivors().size() == 2 and s.follow_id() in ids, "Only living teammates are followed")
	check(s.death_text.contains("42 damage") and s.death_text.contains("Stun"), "Recap preserves incoming damage and control events")
	check(not game.bar_roots[0].visible and not game.player_frame.visible, "Death hides unusable personal controls")
	var first: int = s.target_id
	s.next.pressed.emit()
	check(s.target_id != first and s.target_id in ids, "Next button switches teammates")
	s.previous.pressed.emit()
	check(s.target_id == first, "Previous button switches back")
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	game._unhandled_input(key)
	check(s.target_id != first, "Target-cycle key switches spectators")
	key.shift_pressed = true
	game._unhandled_input(key)
	check(s.target_id == first, "Reverse target-cycle key switches back")
	var frozen: String = s.death_text
	s.record(enemy, me.actor_id, "−999")
	check(s.death_text == frozen, "Late events do not rewrite the death recap")
	var original_size: Vector2 = game.ui.size
	for dimensions in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(3440, 1440)]:
		game.ui.size = dimensions
		s.refresh()
		check(Rect2(Vector2.ZERO, dimensions).encloses(s.card.get_rect()), "Spectator card fits %s" % dimensions)
	game.ui.size = original_size
	game._process(0)
	check(game.pivot.global_position.distance_to(game.actors[first].get_global_transform_interpolated().origin + Vector3(0, 1.6, 0)) < 0.01, "Camera follows spectator target")
	game.actors[first].hp = 0
	game.update_visuals(0)
	check(s.target_id != first and s.next.disabled, "Death of watched teammate selects remaining survivor")
	game.panel.show()
	game.sync_hud_visibility()
	check(not s.card.visible, "Pause hides spectator panel")
	game.panel.hide()
	game.sync_hud_visibility()
	check(s.card.visible, "Resume restores spectator panel")
	for id in ids: game.actors[id].hp = 0
	game.update_visuals(0)
	check(s.target_id == -1 and s.watching.text.contains("waiting"), "No survivors waits safely for authoritative result")
	game.finish_round(game.epoch, 1, game.make_snapshot())
	game.update_visuals(0)
	check(not s.active and not s.card.visible and game.panel.visible, "Results replace spectator controls")
	game.local_match()
	game.phase = "match"
	game.update_visuals(0)
	check(s.death_text.is_empty() and s.history.is_empty() and not s.active, "Rematch clears recap and spectating")
	check(game.bar_roots[0].visible and s.follow_id() == game.local_id, "Rematch restores own HUD and camera")
	game.world_mode = true
	game.actors[game.local_id].hp = 0
	game.update_visuals(0)
	check(not s.active, "World duels do not enter round spectating")
	game.queue_free()
	await process_frame
	await process_frame
	print("Spectator checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
