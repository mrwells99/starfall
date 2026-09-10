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
		check(not mine.health_pivot.visible, "Own health/resource/nameplate icons are hidden")
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
		check(mine.nameplate == null and other.health_pivot.find_children("*", "Label3D", true, false).is_empty(), "Nameplate has no text nodes")
		var resource = game.roster_bar(game.party_buttons[0]).get_node("ThinResource")
		check(is_equal_approx(resource.fraction, 2.0/3.0 if mine.champion in ["Luminary","Outlaw"] else 0.5), "Party resource reads " + mine.champion)
		check(resource.size.y == 10, "Roster resource strip is ten pixels tall")
		check(is_equal_approx(mine.resource_mesh.scale.x, resource.fraction), "World and roster resource values agree")
		var enemy_resource = game.roster_bar(game.enemy_buttons[0]).get_node("ThinResource")
		check(is_equal_approx(enemy_resource.fraction, other.ThinResource.value(other)), "Arena resource reads current state")
		check(other.aura_icons[0].visible and other.aura_icons[0].get_child_count() == 1, "Buff icon appears without text")
		other.hp = 0
		game.update_visuals(0)
		check(not other.team_marker.ground.visible, "Defeated enemies lose their ground marker")
		check(not other.health_pivot.visible and not enemy_resource.visible, "Defeated actors hide overhead and roster resources")
	game.queue_free()
	await process_frame
	await process_frame
	print("Nameplate checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
