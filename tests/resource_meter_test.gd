extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.disable_3d = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode_choice.select(1)
	for i in range(game.Kits.NAMES.size()):
		game.champion_choice.select(i)
		game.local_match()
		game.phase = "match"
		var actor = game.actors[game.local_id]
		actor.identity.heat = 40.0
		actor.identity.resolve = 40.0
		actor.identity.meditation = 75.0
		actor.identity.stars = [{"id": 2, "left": 30.0}, {"id": 3, "left": 30.0}]
		game.selected_id = 4
		game.focus_id = 5
		game.update_visuals(0)
		var meter = game.player_frame.get_child(3).get_node("ResourceMeter")
		check(meter.visible and meter.champion == actor.champion, "Own meter follows selected champion")
		check(meter.amount == [40, 40, 2, 75][i], "Meter reads replicated class resource")
		var before: String = meter.cache
		game.update_visuals(0)
		check(meter.cache == before, "Unchanged resource reuses draw state")
		check(game.target_frame.get_child(1).get_child(0).text == "100%" and game.focus_frame.get_child(1).get_child(0).text == "100%", "Target and focus show only health percentages")
		actor.hp = 0
		game.update_visuals(0)
		check(not meter.is_visible_in_tree(), "Elimination hides personal resources")
	game.leave_session("")
	game.toggle_edit_mode(true)
	game.update_visuals(0)
	check(game.player_frame.get_child(3).get_node("ResourceMeter").is_visible_in_tree(), "HUD editor includes resource previews")
	game.queue_free()
	await process_frame
	await process_frame
	print("Resource meter checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
