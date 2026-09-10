extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func has_effect(details, key: String) -> bool:
	for chip in details.strip.get_children():
		if chip.visible and chip.get_meta("aura", {}).get("key", "") == key: return true
	return false
func check_brands(game) -> void:
	game.mode = 3
	game.roster = {1: {"champion": "Ember", "team": 0}}
	game.begin_round()
	game.phase = "match"
	game.selected_id = 4
	game.focus_id = 4
	var caster = game.actors[1]
	var victim = game.actors[4]
	var icon = game.AbilityArt.texture_for("Flashpoint")
	for count in range(1, 4):
		victim.hp = 100
		game.resolve_spell(caster, 0, victim)
		game.update_visuals(0)
		var effects: Array = game.Auras.active(victim, game.actors.values(), game.local_id)
		check(effects[0].key == "brand_1" and effects[0].stacks == count and effects[0].remaining == 10.0, "Kindle immediately exposes Brand stacks and refreshed duration on its target")
		for frame in [game.target_frame, game.focus_frame]:
			var chip = frame.get_child(4).get_child(0)
			check(chip.visible and chip.get_child(0).get_child(0).texture == icon and chip.get_child(0).get_child(1).text == "×%d" % count, "Target/focus Brand uses Flashpoint art and a stack count")
		var roster_chip = game.enemy_buttons[0].get_node("Details").strip.get_child(0)
		check(roster_chip.visible and roster_chip.get_child(0).texture == icon and roster_chip.get_child(1).text == "×%d" % count, "Arena Brand tile shows the same icon and stacks")
		var overhead = victim.aura_icons[0]
		check(overhead.visible and overhead.get_child(0).texture == icon and overhead.get_node("Stacks").text == "×%d" % count, "Nameplate Brand shows its stack count")
	check(game.Auras.active(caster, game.actors.values()).is_empty(), "Brand is displayed on its victim, not its caster")
	var replicated: Dictionary = bytes_to_var(var_to_bytes(caster.snapshot()))
	caster.identity.brands.clear()
	caster.receive(replicated)
	check(game.Auras.active(victim, game.actors.values())[0].stacks == 3, "Brand display derives from replicated caster state")
	game.spawn_actor(7, 7, 0, "Ember", Vector3(3, 0, 0))
	var other = game.actors[7]
	other.identity.brands[victim.actor_id] = {"count": 1, "left": 4.0}
	var separate: Array = game.Auras.active(victim, [other, caster], game.local_id)
	check(separate.size() == 2 and separate[0].stacks == 3 and separate[0].caster_id == 1 and separate[1].stacks == 1, "Multiple Embers retain separate stacks with your Brand first")
	victim.hp = 100
	game.resolve_spell(caster, 1, victim)
	separate = game.Auras.active(victim, game.actors.values())
	check(separate.size() == 1 and separate[0].caster_id == 7, "Flashpoint consumes only its own Brand indicator")
	game.ClassMechanics.tick(game, other, 4.1)
	game.update_visuals(0)
	check(game.Auras.active(victim, game.actors.values()).is_empty() and not victim.aura_icons[0].visible, "Expired Brand disappears from the target and nameplate")
	victim.shield = 2
	game.update_visuals(0)
	check(victim.aura_icons[0].visible and not victim.aura_icons[0].get_node("Stacks").visible, "Reusing a nameplate icon for a buff clears the old Brand count")
func run() -> void:
	root.disable_3d = true
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode_choice.select(1)
	game.local_match()
	game.phase = "match"
	var enemy = game.actors[4]
	enemy.casting = 0
	enemy.cast_left = 0.5
	game.selected_id = 4
	game.focus_id = 5
	game.update_visuals(0)
	var details = game.enemy_buttons[0].get_node("Details")
	check(details.cast.visible and details.cast.get_child(0).text.contains(enemy.kit[0].name), "Enemy frame shows actual spell and remaining cast time")
	check(game.roster_bar(game.enemy_buttons[0]).get_child(0).text == "100%", "Arena health bars show only percentage")
	enemy.casting = -1
	enemy.locked = 4
	game.show_event(game.epoch, 1, 4, "INTERRUPTED", game.GOLD)
	game.update_visuals(0)
	check(details.cast.visible and details.cast.get_child(0).text == "INTERRUPTED", "Reliable interruption persists after casting clears")
	check(has_effect(details, "lockout"), "Lockout countdown is visible")
	check(game.target_frame.get_child(2).get_child(0).text == "INTERRUPTED", "Target frame also shows interrupt feedback")
	game.combat_text.interrupts[4] = 0
	game.combat_text.tick()
	game.update_visuals(0)
	check(not details.cast.visible, "Interrupt flash expires")
	var ally = game.actors[2]
	ally.hp = 20
	ally.stunned = 2
	game.update_visuals(0)
	var ally_details = game.party_buttons[1].get_node("Details")
	check(has_effect(ally_details, "low_hp") and has_effect(ally_details, "stun"), "Threatened teammate retains control countdown")
	ally.stunned = 0
	ally.identity.root = 3
	game.update_visuals(0)
	check(has_effect(ally_details, "root"), "Root countdown survives without a stun")
	check(game.enemy_buttons[0].get_theme_stylebox("normal") is StyleBoxEmpty, "No enclosing roster card")
	check(not game.player_frame.get_child(0).visible, "No duplicate class header")
	await process_frame
	var icon = ally_details.strip.get_child(0)
	check(game.aura_chip_at(game.party_buttons[1], icon.get_global_rect().get_center()) == icon, "Floating icon exposes its hover description")
	game.combat_text.clear()
	for i in range(20): game.combat_text.emit(enemy, "−5", Color.RED)
	check(game.combat_text.entries.size() == 1 and game.combat_text.entries[0].node.text == "−100", "Rapid damage is combined into one number")
	game.combat_text.emit(enemy, "+12", Color.GREEN)
	game.combat_text.emit(enemy, "INTERRUPTED", Color.YELLOW)
	check(game.combat_text.entries.size() == 3, "Healing and important event have separate lanes")
	game.combat_text.emit(enemy, "ABSORBED", Color.WHITE)
	check(game.combat_text.entries[-1].node.text == "INTERRUPTED", "Generic events cannot immediately replace an interrupt")
	game.combat_text.emit(enemy, "DEFEATED", Color.WHITE)
	check(game.combat_text.entries[-1].node.text == "DEFEATED", "Defeat takes priority over interruption")
	for entry in game.combat_text.entries: entry.created -= 2000
	game.combat_text.tick()
	check(game.combat_text.entries.is_empty(), "Expired combat labels are removed")
	for id in range(100):
		game.combat_text.emit({"actor_id": id, "position": Vector3.ZERO}, "−1", Color.RED)
	check(game.combat_text.entries.size() == 36, "Large crowds retain a bounded number of labels")
	for dimensions in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080), Vector2(2536, 1427), Vector2(2560, 1440), Vector2(3440, 1440)]:
		game.ui.size = dimensions
		await process_frame
		game.update_visuals(0)
		for row in game.party_buttons + game.enemy_buttons:
			check(Rect2(Vector2.ZERO, dimensions).encloses(row.get_global_rect()), "Team row fits %s: %s" % [dimensions, row.get_global_rect()])
	check(not game.party_buttons[0].visible and game.party_buttons[1].visible, "Self is excluded from the teammate overview")
	game.select_party(0)
	check(game.selected_id == game.local_id, "Existing self party binding remains unchanged")
	game.party_buttons[1].pressed.emit()
	check(game.selected_id == 2, "Visible teammate click still targets the correct actor")
	game.mode = 1
	game.selected_id = 4
	game.actors[1].dr_states.stun = {"count": 1, "remaining": 12.0}
	game.actors[4].dr_states.root = {"count": 2, "remaining": 9.0}
	game.update_visuals(0)
	game.sync_hud_visibility()
	check(not game.enemy_box.visible, "1v1 hides the duplicate enemy overview")
	var self_dr = game.player_frame.get_child(1).get_node("DiminishingReturns")
	var target_dr = game.target_frame.get_child(1).get_node("DiminishingReturns")
	check(self_dr.is_visible_in_tree() and self_dr.get_child(0).visible, "Self DR remains available without a self roster row")
	check(target_dr.is_visible_in_tree() and target_dr.get_child(5).visible, "1v1 target carries enemy DR")
	await process_frame
	check(game.aura_chip_at(game.target_frame, target_dr.get_child(5).get_global_rect().get_center()) == target_dr.get_child(5), "Target DR supports hover descriptions")
	game.mode = 3
	game.update_visuals(0)
	check(not target_dr.visible and game.enemy_box.visible, "Team matches show DR on the enemy overview without duplicate target DR")
	for dimensions in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080), Vector2(2536, 1427), Vector2(2560, 1440), Vector2(3440, 1440)]:
		game.ui.size = dimensions
		await process_frame
		for frame in [game.player_frame, game.target_frame, game.focus_frame]:
			check(Rect2(Vector2.ZERO, dimensions).encloses(frame.get_global_rect()), "Primary frames stay within the viewport")
		var pair_midpoint: float = (game.player_frame.position.x + game.target_frame.position.x + game.target_frame.size.x) * 0.5
		check(is_equal_approx(pair_midpoint, dimensions.x * 0.5), "Self and target are centered together at %s" % dimensions)
		check(not game.player_frame.get_global_rect().intersects(game.target_frame.get_global_rect()), "Self and target do not overlap")
		check(not game.target_frame.get_global_rect().intersects(game.focus_frame.get_global_rect()), "Compact focus does not overlap target")
	check(game.player_frame.get_child(1).size.x == 221 and game.target_frame.get_child(1).size.x == 221, "Primary health bars are fifteen percent narrower")
	var compact_actor = game.actors[6]
	compact_actor.hp = 20
	compact_actor.casting = 0
	compact_actor.cast_left = 0.5
	for category in game.CC.CATEGORIES:
		compact_actor.dr_states[category] = {"count": 1, "remaining": 10.0}
	game.update_visuals(0)
	await process_frame
	var compact_row = game.enemy_buttons[2]
	check(compact_row.custom_minimum_size.y == 64, "Busy rows use the fixed compact height")
	var compact_details = compact_row.get_node("Details")
	var compact_health = game.roster_bar(compact_row)
	check(compact_health.get_global_rect().encloses(compact_details.strip.get_child(0).get_global_rect()), "Effects are inset inside health")
	check(compact_row.get_global_rect().encloses(compact_details.cast.get_global_rect()), "Cast strip fits within the fixed row")
	check(compact_details.cast.global_position.y >= compact_health.get_global_rect().end.y, "Cast appears below health")
	var inset_resource = compact_health.get_node("ThinResource")
	check(compact_health.get_global_rect().encloses(inset_resource.get_global_rect()) and inset_resource.size.y == 10, "Thicker resource strip sits inside health")
	check(not compact_details.strip.get_global_rect().intersects(compact_health.get_child(0).get_global_rect()), "Effects do not cover health percentage")
	var busy_position: Vector2 = compact_row.position
	check(compact_row.get_global_rect().encloses(compact_row.get_node("DiminishingReturns").get_global_rect()), "Busy row contains both DR rows")
	compact_actor.hp = 100
	compact_actor.casting = -1
	compact_actor.dr_states.clear()
	game.update_visuals(0)
	await process_frame
	check(compact_row.custom_minimum_size.y == 64, "Quiet rows retain the same height without shifting targets")
	check(compact_row.position == busy_position, "Clearing casts and effects does not move the row")
	check_brands(game)
	game.leave_session("")
	check(game.combat_text.entries.is_empty() and game.combat_text.interrupts.is_empty(), "Session changes clear combat feedback")
	game.queue_free()
	await process_frame
	await process_frame
	print("Team HUD checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
