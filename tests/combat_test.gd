extends SceneTree

var failures := 0
var checks := 0
var arena

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error(description)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(12):
		for actor in arena.actors.values():
			actor.velocity = Vector3(0, -2, 0)
			actor.move_and_slide()
		await physics_frame

func reset(choice: String = "Ember", team_size: int = 1) -> void:
	arena.mode = team_size
	arena.roster = {1: {"champion": choice, "team": 0}}
	arena.begin_round()
	arena.phase = "match"
	await settle()

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await reset()
	var player = arena.actors[1]
	var enemy = arena.actors[2]
	check(arena.validate_spell(player, 0, 2).is_empty(), "Open enemy in range is valid")
	check(not arena.try_spell(1, 0, -1), "Offensive spells require target")
	player.rotation.y = PI
	check(not arena.try_spell(1, 0, 2), "Facing is enforced")
	player.rotation.y = 0
	player.position = Vector3(-6, 0, 9)
	enemy.position = Vector3(-6, 0, 0)
	await physics_frame
	check(not arena.has_los(player, enemy), "Pillars block spells")
	check(not arena.try_spell(1, 0, 2), "Blocked spells cannot start")
	await reset()
	player = arena.actors[1]
	enemy = arena.actors[2]
	check(arena.try_spell(1, 0, 2) and player.casting == 0 and enemy.hp == 100, "Cast starts without early damage")
	player.move_input = Vector2(1, 0)
	arena.tick_actor(player, 0.1)
	check(player.casting == -1 and enemy.hp == 100, "Movement cancels casting")
	player.move_input = Vector2.ZERO
	player.gcd = 0
	await settle()
	check(arena.try_spell(1, 0, 2), "Stationary cast restarts")
	player.cast_left = 0.001
	arena.tick_actor(player, 0.01)
	check(enemy.hp == 84, "Completed cast deals damage")
	check(not arena.try_spell(1, 1, 2), "Global cooldown enforced")
	enemy.casting = 0
	enemy.cast_left = 1
	check(arena.try_spell(1, 2, 2), "Interrupt bypasses global cooldown")
	check(enemy.casting == -1 and enemy.locked == 4, "Interrupt cancels and locks spells")
	enemy.owner_peer = 9
	check(not arena.try_spell(2, 0, 1), "Lockout prevents spellcasting")
	check(not arena.try_spell(1, 2, 2), "Interrupt cooldown enforced")
	for expected in [4.0, 2.0, 1.0, 0.0]:
		enemy.stunned = 0
		arena.resolve_spell(player, 3, enemy)
		check(enemy.stunned == expected, "Control diminishing returns: %s" % expected)
	enemy.dr_timer = 0.001
	arena.tick_actor(enemy, 0.01)
	check(enemy.dr_count == 0, "Diminishing returns reset")
	enemy.hp = 100
	enemy.shield = 5
	arena.damage(player, enemy, 20)
	check(is_equal_approx(enemy.hp, 92), "Ward reduces damage by 60 percent")
	player.hp = 90
	arena.resolve_spell(player, 5, player)
	check(player.hp == 100, "Self heal caps at maximum")
	player.position = Vector3(-6, 0, 9)
	player.rotation.y = 0
	await physics_frame
	arena.resolve_spell(player, 6, player)
	check(player.position.z > 7, "Blink capsule sweep stops at pillar")
	await reset("Vanguard")
	player = arena.actors[1]
	enemy = arena.actors[2]
	check(not arena.try_spell(1, 0, 2), "Melee rejects distant target")
	check(arena.try_spell(1, 6, 2), "Charge available at range")
	check(player.position.distance_to(enemy.position) < 3.5 and enemy.hp == 94, "Charge closes distance and deals damage")
	await reset("Luminary", 3)
	player = arena.actors[1]
	var ally = arena.actors[2]
	enemy = arena.actors[4]
	check(arena.actors.size() == 6, "Team mode creates six fighters")
	var healers := [0, 0]
	for actor in arena.actors.values():
		if actor.champion == "Luminary":
			healers[actor.team] += 1
	check(healers == [1, 1], "Bot fill supplies one healer on each team")
	ally.hp = 40
	check(arena.try_spell(1, 1, 2) and ally.hp == 58, "Friendly healing reaches selected ally")
	ally.stunned = 3
	check(arena.try_spell(1, 2, 2) and ally.stunned == 0, "Healer dispel clears friendly control")
	check(not arena.try_spell(1, 0, 2), "Offensive spells cannot damage allies")
	check(arena.spell_target(player, 5, enemy.actor_id) == 1, "Helpful spell falls back to self with enemy targeted")
	ally.position = Vector3(-6, 0, 0)
	player.position = Vector3(-6, 0, 9)
	await physics_frame
	check(not arena.validate_spell(player, 5, 2).is_empty(), "Friendly heals respect line of sight")
	# A single death does not decide a team match; all opposing actors must die.
	arena.damage(player, enemy, 1000)
	arena.check_winner()
	check(arena.phase == "match", "Team round continues after first death")
	for actor in arena.actors.values():
		if actor.team == 1:
			arena.damage(player, actor, 1000)
	arena.check_winner()
	check(arena.phase == "results" and arena.winner == 0, "Team elimination ends round")
	arena.update_visuals(0)
	check(arena.result_text.text.begins_with("VICTORY"), "Persistent victory shown")
	await reset()
	player = arena.actors[1]
	enemy = arena.actors[2]
	arena.damage(enemy, player, 1000)
	arena.check_winner()
	check(arena.phase == "results" and arena.result_text.text.begins_with("DEFEAT"), "Player death ends duel with defeat")
	await reset()
	check(arena.actors[1].hp == 100 and arena.actors[2].hp == 100 and arena.actors[1].dr_count == 0, "Rematch resets all combat state")
	# Navigate from one side of a pillar to the other using actual collision movement.
	player = arena.actors[1]
	enemy = arena.actors[2]
	player.position = Vector3(-6, 0, 10)
	enemy.position = Vector3(-6, 0, 0)
	var route: PackedVector2Array = arena.nav.route(enemy.position, player.position)
	var detours := false
	for point in route:
		if absf(point.x + 6) >= 3:
			detours = true
	check(detours, "Navigation route detours around pillar clearance")
	for frame in range(300):
		arena.tick_actor(enemy, 1.0 / 60.0)
		await physics_frame
	check(arena.has_los(enemy, player), "Bot walks around pillar to acquire sight")
	# Inputs cannot inject non-finite positions or excessive movement speed.
	arena.apply_input(1, Vector2(999, 999), 0, false, 2)
	check(player.move_input.length() <= 1.001, "Server clamps movement intent")
	var old_yaw: float = player.rotation.y
	arena.apply_input(1, Vector2.ZERO, NAN, false, 2)
	check(player.rotation.y == old_yaw, "Non-finite input rejected")
	check(not arena.try_spell(1, 999, 2), "Invalid ability slot rejected")
	arena.update_visuals(0)
	check((arena.player_frame.get_child(1) as ProgressBar).value == player.hp, "Health UI reflects simulation")
	# Snapshot round-trip and terminal-state protection use the real wire format.
	var snapshot: Array = arena.make_snapshot()
	var packed := var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE)
	check(packed.size() < 1200, "Compressed snapshots fit conservative packet budget")
	arena.phase = "match"
	arena.last_snapshot = -1
	arena.receive_snapshot(arena.epoch, 10, packed, "match", 12.0, 0.0)
	check(arena.last_snapshot == 10 and arena.elapsed == 12, "Snapshot decompresses and applies")
	arena.receive_snapshot(arena.epoch, 9, packed, "match", 1.0, 0.0)
	check(arena.elapsed == 12, "Old snapshots cannot roll time backward")
	arena.phase = "results"
	arena.receive_snapshot(arena.epoch, 11, packed, "match", 13.0, 0.0)
	check(arena.phase == "results" and arena.elapsed == 12, "Delayed snapshots cannot undo match result")
	# --- Fulcrum: Tether is the only ability that targets either side ---------
	await reset("Fulcrum", 3)
	var grip = arena.actors[1]
	var foe_target = null
	var ally_target = null
	for a in arena.actors.values():
		if a.actor_id == 1:
			continue
		if a.team != grip.team and foe_target == null:
			foe_target = a
		elif a.team == grip.team and ally_target == null:
			ally_target = a
	check(grip.kit[6].name == "Tether" and grip.kit[6].off, "Tether is off the global cooldown")
	grip.position = Vector3(0, grip.position.y, 0)

	# Enemy: dragged toward the caster, stopping short rather than overlapping.
	foe_target.position = grip.position + Vector3(0, 0, -14)
	grip.look_at(Vector3(foe_target.position.x, grip.position.y, foe_target.position.z), Vector3.UP)
	await settle()
	var caster_before: Vector3 = grip.position
	check(arena.try_spell(1, 6, foe_target.actor_id), "Tether accepts an enemy target")
	await settle()
	var after_enemy: float = grip.position.distance_to(foe_target.position)
	check(after_enemy < 9.0, "Tether drags an enemy toward the caster")
	check(after_enemy > 1.0, "Tether stops short instead of overlapping the caster")
	check(grip.position.distance_to(caster_before) < 0.5, "Tether moves the target, not the caster")
	check(foe_target.hp == 100, "Tether deals no damage")

	# Ally: the same ability, used as a save.
	grip.cooldowns[6] = 0
	ally_target.position = grip.position + Vector3(0, 0, -13)
	grip.look_at(Vector3(ally_target.position.x, grip.position.y, ally_target.position.z), Vector3.UP)
	await settle()
	check(arena.try_spell(1, 6, ally_target.actor_id), "Tether accepts an ally target")
	await settle()
	check(grip.position.distance_to(ally_target.position) < 9.0, "Tether pulls an ally out of danger")

	grip.cooldowns[6] = 0
	check(not arena.try_spell(1, 6, 1), "Tether cannot target the caster")
	grip.cooldowns[6] = 0
	foe_target.position = grip.position + Vector3(0, 0, -60)
	await settle()
	check(not arena.try_spell(1, 6, foe_target.actor_id), "Tether respects its range")

	# --- auras are derived from simulation state, never stored separately -----
	await reset("Ember", 1)
	var Auras = load("res://scripts/auras.gd")
	var subject = arena.actors[1]
	subject.stunned = 2.4
	subject.shield = 4.0
	var list: Array = Auras.active(subject)
	var keys: Array = []
	for a in list:
		keys.append(a.key)
	check(keys.has("stun") and keys.has("shield"), "Auras reflect live simulation fields")
	for a in list:
		if a.key == "stun":
			check(a.kind == Auras.DEBUFF and is_equal_approx(a.remaining, 2.4), "Stun aura carries its own timer")
			check(not a.description.is_empty(), "Stun aura explains itself")
		if a.key == "shield":
			check(a.name == "Ward", "Shield aura is named for Ember's ability")
	check(Auras.shield_name("Vanguard") == "Iron Skin" and Auras.shield_name("Fulcrum") == "Umbra"
		and Auras.shield_name("Luminary") == "Sanctuary", "One shield field, four champion names")
	subject.hp = 0
	check(Auras.active(subject).is_empty(), "A defeated fighter shows no auras")
	subject.hp = 100
	subject.stunned = 0
	subject.shield = 0
	check(Auras.active(subject).is_empty(), "Auras clear when their timers do")
	subject.dr_count = 2
	subject.dr_timer = 9.0
	var dr_list: Array = Auras.active(subject)
	check(dr_list.size() == 1 and dr_list[0].key == "dr" and dr_list[0].description.contains("25%"),
		"Diminishing returns is surfaced with what the next stun will do")

	# An effect must remember which ability applied it, so the HUD can show that
	# ability's icon rather than a word.
	await reset("Ember", 1)
	var caster = arena.actors[1]
	var mark = arena.actors[2]
	caster.position = Vector3(0, 0, 6)
	mark.position = Vector3(0, 0, -2)
	caster.rotation.y = 0
	await settle()
	# resolve_spell rather than try_spell: Stasis has a 0.8s cast, so try_spell
	# would only begin one, and resolve_spell is the unit that records the source.
	arena.resolve_spell(caster, 3, mark)
	check(mark.stunned > 0 and mark.stun_from == "Stasis", "A stun records the ability that caused it")
	var stun_aura := {}
	for a in Auras.active(mark):
		if a.key == "stun":
			stun_aura = a
	check(stun_aura.get("source", "") == "Stasis", "The aura carries the source through to the HUD")
	arena.resolve_spell(caster, 5, mark)
	check(mark.stun_from == "Stasis", "An unrelated ability does not overwrite provenance")

	# --- cancelling your own cast refunds the global cooldown ------------------
	await reset("Ember", 1)
	var mover = arena.actors[1]
	var mark2 = arena.actors[2]
	mover.position = Vector3(0, 0, 6)
	mark2.position = Vector3(0, 0, -2)
	mover.rotation.y = 0
	await settle()
	check(arena.try_spell(1, 0, 2), "Firebolt begins casting")
	check(mover.casting == 0 and mover.gcd > 0, "Starting a cast charges the global cooldown")
	arena.cancel_own_cast(mover, "")
	check(mover.casting < 0 and mover.gcd == 0.0, "Cancelling your own cast refunds the global cooldown")

	# Walking out of a cast is the same cancellation and must refund too.
	mover.gcd = 0
	mover.cooldowns[0] = 0
	check(arena.try_spell(1, 0, 2), "Firebolt begins again")
	# The tick's other cancel condition: leaving the ground. move_input cannot be
	# used here because gather_input() runs first in the same tick and rewrites
	# it from the real (idle) keyboard.
	mover.position.y = 4.0
	arena._physics_process(0.05)
	check(mover.casting < 0 and mover.gcd == 0.0, "Leaving the ground mid-cast refunds it too")
	mover.position.y = 0.0

	# An enemy interrupt must NOT refund: the lockout is the punishment, and
	# refunding would reward being interrupted.
	mover.gcd = 0
	mover.cooldowns[0] = 0
	await settle()
	check(arena.try_spell(1, 0, 2), "Firebolt begins for the interrupt case")
	var charged: float = mover.gcd
	check(charged > 0, "Cast charged the global cooldown before the interrupt")
	arena.resolve_spell(mark2, 2, mover)
	check(mover.casting < 0 and mover.locked > 0, "The interrupt landed")
	check(mover.gcd > 0, "Being interrupted does not refund the global cooldown")

	# --- crowd control classification -----------------------------------------
	var victim2 = arena.actors[2]
	victim2.stunned = 0
	victim2.locked = 0
	check(Auras.crowd_control(victim2).is_empty(), "No control means no tracker")
	victim2.locked = 3.0
	victim2.lock_from = "Disrupt"
	check(Auras.crowd_control(victim2).get("cc", "") == "LOCKED OUT", "Lockout is crowd control")
	victim2.stunned = 2.0
	victim2.stun_from = "Stasis"
	var worst: Dictionary = Auras.crowd_control(victim2)
	check(worst.get("cc", "") == "STUNNED" and worst.get("source", "") == "Stasis",
		"A stun outranks a lockout, and carries the icon to show")
	victim2.shield = 5.0
	victim2.stunned = 0
	victim2.locked = 0
	check(Auras.crowd_control(victim2).is_empty(), "A buff is not crowd control")

	print("Combat checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
