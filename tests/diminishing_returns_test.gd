extends SceneTree
const CC = preload("res://scripts/crowd_control.gd")
var checks := 0
var failures := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func clean(actor) -> void:
	CC.clear(actor, CC.CATEGORIES)
	CC.reset(actor)
	actor.hp = 100
	actor.locked = 0
func run() -> void:
	root.disable_3d = true
	game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode_choice.select(1)
	game.local_match()
	game.phase = "match"
	var target = game.actors[4]
	for category in CC.CATEGORIES:
		clean(target)
		target.champion = "Vanguard" if category == "disarm" else "Ember"
		for expected in [8.0, 4.0, 2.0, 0.0]:
			check(CC.apply(target, category, 8, "Test") == expected, "%s independent duration tier %s" % [category, expected])
			CC.clear(target, [category])
		CC.tick(target, 17.9)
		check(target.dr_states.has(category), "%s remains diminished until reset" % category)
		CC.tick(target, 0.11)
		check(not target.dr_states.has(category), "%s resets after 18 seconds" % category)
	clean(target)
	target.champion = "Ember"
	CC.apply(target, "stun", 4, "Natural expiry")
	CC.tick(target, 4)
	check(target.stunned == 0 and target.dr_states.stun.remaining == 18, "Natural expiry starts 18-second DR window")
	CC.apply(target, "root", 8, "Root")
	CC.tick(target, 4)
	check(target.dr_states.stun.remaining == 14 and target.dr_states.root.remaining == 22, "Each category resets on its own clock")
	CC.clear(target, ["root"])
	CC.tick(target, 14)
	check(not target.dr_states.has("stun") and target.dr_states.root.remaining == 4, "One category resets while another remains diminished")
	clean(target)
	target.champion = "Ember"
	CC.apply(target, "stun", 4, "Stun")
	check(CC.apply(target, "root", 6, "Root") == 6, "Stun does not diminish root")
	check(CC.apply(target, "incapacitate", 5, "Sleep") == 5, "Stun and root do not diminish incapacitate")
	CC.on_damage(target, 1, 0)
	check(not target.cc_effects.has("incapacitate") and target.stunned > 0 and target.identity.root > 0, "Damage breaks only incapacitate, retaining stun and root")
	check(target.dr_states.incapacitate.remaining == 18, "Early break starts exact 18-second reset")
	CC.clear(target, ["stun"])
	check(target.identity.root > 0 and target.stunned == 0, "Clearing stun leaves independent root")
	clean(target)
	CC.apply(target, "disorient", 8, "Confusion")
	CC.on_damage(target, 9, 0.9)
	check(CC.remaining(target, "disorient") > 0, "Disorient can survive damage below threshold")
	CC.on_damage(target, 11, 0.9)
	check(CC.remaining(target, "disorient") == 0, "Cumulative 20 damage guarantees disorient break")
	CC.apply(target, "disorient", 8, "Confusion")
	CC.on_damage(target, 0, 0)
	check(CC.remaining(target, "disorient") > 0, "Zero damage cannot break control")
	CC.on_damage(target, 1, 0.1)
	check(CC.remaining(target, "disorient") == 0, "Disorient supports chance-based early break")
	clean(target)
	CC.apply(target, "silence", 4, "Silence")
	check(target.stunned == 0 and CC.spell_block(target) == 4, "Silence blocks caster abilities without blocking movement")
	CC.on_damage(target, 10, 0)
	check(CC.remaining(target, "silence") == 4, "Silence does not break on damage")
	check(game.ability_block_reason(target, 0, 1) == "Silenced", "Authoritative and UI ability validation sees silence")
	check(CC.apply(target, "disarm", 4, "Disarm") == 0, "Disarm does not affect casters")
	clean(target)
	target.champion = "Vanguard"
	check(CC.apply(target, "silence", 4, "Silence") == 0, "Silence does not affect melee")
	CC.apply(target, "disarm", 4, "Disarm")
	check(target.stunned == 0 and game.ability_block_reason(target, 0, 1) == "Disarmed", "Disarm blocks melee abilities while allowing movement")
	CC.on_damage(target, 10, 0)
	check(CC.remaining(target, "disarm") == 4, "Disarm does not break on damage")
	clean(target)
	target.champion = "Ember"
	var caster = game.actors[1]
	for attempt in range(5):
		target.casting = 0
		game.resolve_spell(caster, 2, target)
		check(target.locked == caster.kit[2].power and target.dr_states.is_empty(), "Interrupt remains full strength without DR")
	CC.apply(target, "root", 5, "Root")
	CC.apply(target, "stun", 3, "Stun")
	var snapshot: Dictionary = target.snapshot()
	var replica = game.actors[5]
	replica.receive(snapshot, true)
	check(replica.dr_states == target.dr_states and replica.cc_effects == target.cc_effects, "All categories replicate in snapshots")
	replica.dr_states.root.count = 3
	check(target.dr_states.root.count == 1, "Snapshot category dictionaries do not alias")
	game.selected_id = 4
	game.update_visuals(0)
	await process_frame
	var icons = game.enemy_buttons[0].get_node("DiminishingReturns")
	var stun_icon = icons.get_child(0)
	check(stun_icon.visible and icons.get_child(5).visible, "Arena frame shows independent active DR icons")
	check(icons.get_global_rect().end.x < game.roster_bar(game.enemy_buttons[0]).get_global_rect().position.x, "Enemy DR icons sit left of health")
	game.actors[2].dr_states.stun = {"count": 1, "remaining": 10.0}
	game.update_visuals(0)
	await process_frame
	var party_icons = game.party_buttons[1].get_node("DiminishingReturns")
	check(party_icons.get_child(0).visible and party_icons.get_global_rect().position.x > game.roster_bar(game.party_buttons[1]).get_global_rect().end.x, "Party DR icons sit right of health")
	check(game.aura_chip_at(game.party_buttons[1], party_icons.get_child(0).get_global_rect().get_center()) == party_icons.get_child(0), "Party DR hover is available")
	check(stun_icon.get_meta("aura").description.contains("50%"), "DR hover explains the next duration tier")
	check(game.aura_chip_at(game.enemy_buttons[0], stun_icon.get_global_rect().get_center()) == stun_icon, "DR icon supports hover tooltip hit testing")
	for aura in game.Auras.active(target): check(not str(aura.key).begins_with("dr"), "No Diminished text aura under unit frames")
	for dimensions in [Vector2(1280,720), Vector2(1920,1080), Vector2(3440,1440)]:
		game.ui.size = dimensions
		await process_frame
		check(Rect2(Vector2.ZERO, dimensions).encloses(icons.get_global_rect()), "DR icons stay within %s" % dimensions)
	game.ui.size = Vector2(1280, 720)
	await process_frame
	game.config.set_value("hud", "frames", {"EnemyFrame": Vector2(1200, 220)})
	game.config.set_value("hud", "moved", ["EnemyFrame"])
	game.load_layout()
	await process_frame
	check(game.enemy_box.get_global_rect().end.x <= 1280, "Saved enemy layout keeps the expanded DR column onscreen")
	target.reset_identity()
	check(target.dr_states.is_empty() and target.cc_effects.is_empty(), "Respawn/duel reset clears all DR and controls")
	game.queue_free()
	await process_frame
	await process_frame
	print("Diminishing returns checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
