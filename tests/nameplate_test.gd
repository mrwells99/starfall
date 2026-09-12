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
	root.disable_3d = true
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode_choice.select(1)
	for i in range(game.Kits.NAMES.size()):
		game.champion_choice.select(i)
		game.local_match()
		game.phase = "match"
		var mine = game.actors[game.local_id]
		mine.identity.heat = 50
		mine.identity.resolve = 50
		mine.identity.meditation = 50
		mine.identity.stars = [{}, {}]
		mine.identity.defense_detonation = 2
		var other = game.actors[4]
		other.identity.stars = [{}, {}]
		other.shield = 4
		other.shield_from = "Ward"
		game.update_visuals(0)
		check(not mine.health_pivot.visible, "Own health/nameplate icons are hidden")
		check(other.health_pivot.visible, "Enemy nameplate is visible")
		check(not mine.team_marker.ground.visible, "The local player never gets a team ground ring")
		check(other.team_marker.ground.visible and other.team_marker.ground.material_override.albedo_color == other.team_marker.Badge.ENEMY, "Enemies retain red ground rings")
		check(game.actors[2].team_marker.ground.material_override.albedo_color == other.team_marker.Badge.ALLY, "Allies retain cyan ground rings")
		check(other.health_mesh.material_override.albedo_color == game.Kits.color(other.champion), "Team markers preserve class-colored health")
		game.selected_id = 4
		game.update_visuals(0)
		check(other.team_marker.brackets.visible and game.ring.visible, "Selected enemy gets white brackets and the stronger ring")
		game.selected_id = game.local_id
		game.update_visuals(0)
		check(not game.ring.visible and not mine.team_marker.brackets.visible, "Selecting yourself does not add a ground ring or nameplate markers")
		check(game.actors[2].health_pivot.visible, "Ally nameplate is visible")
		check(mine.nameplate == null and not other.nameplate_cast.visible, "Idle nameplates have no name/class text or cast row")
		var resource = game.roster_bar(game.party_buttons[0]).get_node("ThinResource")
		check(is_equal_approx(resource.fraction, 0.0 if mine.champion == "Null" else (2.0/3.0 if mine.champion in ["Luminary","Outlaw"] else 0.5)), "Party resource reads " + mine.champion)
		check(resource.size.y == 10, "Roster resource strip is ten pixels tall")
		check(mine.get("resource_mesh") == null and mine.get("resource_pivot") == null, "Nameplate resource strip is removed")
		check(mine.health_mesh.mesh.size == Vector2(1.54, 0.11) and mine.health_pivot.get_child(0).mesh.size == Vector2(1.6, 0.16), "Nameplate health geometry keeps its original dimensions")
		var enemy_resource = game.roster_bar(game.enemy_buttons[0]).get_node("ThinResource")
		check(is_equal_approx(enemy_resource.fraction, preload("res://scripts/thin_resource_bar.gd").value(other)), "Arena resource reads current state")
		check(other.aura_icons[0].visible and other.aura_icons[0].get_child_count() == 1, "Buff icon appears without text")
		# Exercise every castable spell, including champion-specific shared art.
		for slot in mine.kit.size():
			var spell: Dictionary = mine.kit[slot]
			if spell.cast <= 0: continue
			mine.casting = slot
			mine.cast_left = spell.cast
			mine.visual_tick(0, game.camera)
			var cast = mine.nameplate_cast
			check(cast.visible and cast.fraction == 0 and not cast.fill.visible, "A cast starts with an empty progress bar")
			check(cast.title.text == spell.name and cast.icon.texture == game.AbilityArt.texture_for(spell.name, mine.champion) and cast.icon.visible, "Nameplate cast identifies " + mine.champion + "/" + spell.name)
			var text_width: float = cast.title.font.get_string_size(cast.title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, cast.title.font_size).x * cast.title.pixel_size
			check(text_width <= cast.FILL_WIDTH and cast.icon.position.x + cast.ICON_SIZE * 0.5 < -cast.WIDTH * 0.5, "Cast name fits its fixed bar and icon sits beside it")
			mine.cast_left = spell.cast * 0.5
			mine.visual_tick(0, game.camera)
			check(is_equal_approx(cast.fraction, 0.5) and is_equal_approx(cast.fill.position.x - cast.FILL_WIDTH * cast.fraction * 0.5, -cast.FILL_WIDTH * 0.5), "Cast fills halfway from a stationary left edge")
			mine.cast_left = spell.cast * 0.25
			var snapshot: Dictionary = bytes_to_var(var_to_bytes(mine.snapshot()))
			mine.cast_left = spell.cast
			mine.receive(snapshot)
			mine.visual_tick(0, game.camera)
			check(is_equal_approx(cast.fraction, 0.75), "Cast progress uses replicated remaining time")
			game.update_visuals(0)
			check(not cast.is_visible_in_tree(), "Casting does not reveal the local player's nameplate")
			mine.cast_left = 0
			mine.visual_tick(0, game.camera)
			check(not cast.visible, "Finished cast row disappears")
			mine.cast_left = 1
			mine.casting = -1
			mine.visual_tick(0, game.camera)
			check(not cast.visible, "Cancelled or interrupted cast row disappears")
		other.casting = 0
		other.cast_left = 0.5
		game.update_visuals(0)
		check(other.nameplate_cast.is_visible_in_tree(), "Other players' active casts appear on their nameplates")
		other.hp = 0
		game.update_visuals(0)
		check(not other.team_marker.ground.visible, "Defeated enemies lose their ground marker")
		check(not other.health_pivot.visible and not enemy_resource.visible, "Defeated actors hide overhead and roster resources")
		check(not other.nameplate_cast.visible, "Defeat clears the overhead cast row")
	var server_actor = game.Fighter.new()
	server_actor.setup(90, 90, 0, "Ember", false)
	check(server_actor.nameplate_cast == null, "Dedicated actors create no cast UI or icon resources")
	server_actor.free()
	game.queue_free()
	await process_frame
	await process_frame
	print("Nameplate checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
