extends SceneTree
var arena
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func reset(champion: String) -> void:
	arena.mode = 3
	arena.roster = {1: {"champion": champion, "team": 0}}
	arena.begin_round()
	arena.phase = "match"
	for a in arena.actors.values():
		a.owner_peer = a.actor_id
		a.position = Vector3(0, 0, 4 - a.actor_id * 2)
	for i in range(10):
		for a in arena.actors.values():
			a.velocity = Vector3(0, -2, 0)
			a.move_and_slide()
		await physics_frame
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await reset("Ember")
	var a = arena.actors[1]
	var b = arena.actors[4]
	for i in range(3):
		arena.resolve_spell(a, 0, b)
	check(a.identity.heat == 60 and a.identity.brands[b.actor_id].count == 3, "Kindle builds Heat and caps brands")
	b.hp = 100
	arena.resolve_spell(a, 1, b)
	check(b.hp == 70 and not a.identity.brands.has(b.actor_id), "Flashpoint consumes three brands for burst")
	b.hp = 100
	arena.resolve_spell(a, 7, b)
	check(b.hp == 54 and a.identity.heat == 0, "Supernova spends Heat for scaled damage")
	check(not arena.try_spell(a.actor_id, 7, b.actor_id), "Supernova cannot be used without Heat")
	arena.ClassMechanics.control(arena, a, b, 3, "Solar Flare", false, true)
	arena.damage(a, b, 1)
	check(b.stunned == 0, "Damage breaks Solar Flare")
	a.identity.heat = 40
	arena.resolve_spell(a, 9, a)
	check(a.identity.heat == 20 and a.identity.wake > 0, "Cinderstep spends Heat and creates a trail")
	await reset("Vanguard")
	a = arena.actors[1]; b = arena.actors[4]
	var ally = arena.actors[2]
	arena.resolve_spell(a, 0, b)
	check(a.identity.resolve == 20, "Sundering Blow grants Resolve")
	b.hp = 100
	arena.resolve_spell(a, 1, b)
	check(b.hp == 71 and a.identity.resolve == 0, "Oathbreaker spends Resolve and consumes exposure")
	arena.resolve_spell(a, 7, ally)
	arena.damage(b, ally, 20)
	check(ally.hp == 86 and a.hp == 94 and a.identity.resolve == 6, "Intercede shares damage and grants Resolve")
	arena.resolve_spell(a, 8, a)
	a.position = Vector3(0, 0, 2); b.position = Vector3(0, 0, -2); a.rotation.y = 0
	var before: float = a.hp
	arena.damage(b, a, 20)
	check(is_equal_approx(a.hp, before - 6), "Hold the Line reduces frontal damage")
	var pos: Vector3 = a.position
	arena.move_ability(a, Vector3(3, 0, 0))
	check(a.position == pos, "Hold the Line resists displacement")
	before = a.hp
	arena.damage(b, ally, 20)
	check(is_equal_approx(a.hp, before - 1.8), "Hold the Line also reduces redirected frontal damage")
	await reset("Luminary")
	a = arena.actors[1]; b = arena.actors[4]; ally = arena.actors[2]
	for target in [a, ally, ally, b]:
		if target == b:
			continue
		arena.resolve_spell(a, 7, target)
	check(a.identity.stars.size() == 3, "Guiding Stars have a shared capacity")
	arena.resolve_spell(a, 7, ally)
	check(arena.ClassMechanics.star_count(a, a.actor_id) == 0 and arena.ClassMechanics.star_count(a, ally.actor_id) == 3, "Fourth star moves oldest star")
	ally.hp = 40
	arena.resolve_spell(a, 1, ally)
	check(ally.hp == 74 and a.identity.stars.size() == 2, "Falling Star consumes one star for rescue healing")
	ally.identity.root = 2
	arena.resolve_spell(a, 2, ally)
	check(ally.identity.root == 0 and ally.identity.immune == 3, "Absolution consumes star to clear and resist roots")
	ally.hp = 20
	arena.resolve_spell(a, 9, ally)
	arena.damage(b, ally, 80)
	check(ally.hp == 1 and ally.identity.last == 0, "Last Light saves one lethal hit")
	arena.damage(b, ally, 2)
	check(ally.hp == 0, "Last Light does not grant continuing immortality")
	await reset("Fulcrum")
	a = arena.actors[1]; b = arena.actors[4]; ally = arena.actors[2]
	check(not arena.validate_spell(a, 1, b.actor_id).is_empty(), "Inward requires an anchor")
	arena.resolve_spell(a, 7, a)
	check(a.identity.anchor_left == 20, "Anchor projects onto arena floor")
	var anchor: Vector3 = a.identity.anchor_pos
	b.position = anchor + Vector3(4, 0, 0)
	var distance: float = b.position.distance_to(anchor)
	arena.resolve_spell(a, 1, b)
	check(b.position.distance_to(anchor) < distance, "Inward pulls toward anchor")
	distance = b.position.distance_to(anchor)
	arena.resolve_spell(a, 8, b)
	check(b.position.distance_to(anchor) > distance, "Outward pushes away from anchor")
	b.position = anchor + Vector3(1, 0, 0)
	arena.resolve_spell(a, 9, a)
	arena.ClassMechanics.tick(arena, a, 0.1)
	check(b.identity.slow > 0, "Heavy Orbit slows nearby enemies")
	arena.resolve_spell(a, 11, a)
	check(b.hp == 78 and b.identity.root > 0 and a.identity.anchor_left == 0, "Collapse consumes anchor for damage and root")
	a.position = Vector3(0, 0, 2); ally.position = Vector3(0, 0, -2)
	pos = a.position
	arena.resolve_spell(a, 10, ally)
	check(ally.position == pos and a.position == Vector3(0, 0, -2), "Counterweight exchanges ally positions")
	a.position = Vector3(-6, 0, 9); ally.position = Vector3(-6, 0, 0)
	await physics_frame
	check(not arena.validate_spell(a, 10, ally.actor_id).is_empty(), "Counterweight rejects a pillar-blocked exchange")
	arena.world_mode = true
	a.position = Vector3(0, 0, 2); b.position = Vector3(0, 0, -2); a.rotation.y = 0
	check(not arena.try_spell(a.actor_id, 3, b.actor_id), "Bystanders cannot be controlled")
	arena.duels[a.actor_id] = b.actor_id
	arena.duels[b.actor_id] = a.actor_id
	check(not arena.validate_spell(a, 10, ally.actor_id).is_empty(), "Duel participants cannot swap with bystanders")
	arena.world_mode = false
	for champion in arena.Kits.NAMES:
		await reset(champion)
		a = arena.actors[1]
		check(a.kit.size() == (13 if champion == "Fulcrum" else 12) and a.cooldowns.size() == a.kit.size(), champion + " has the supported slot count")
		for ability in a.kit:
			check(arena.AbilityArt.texture_for(ability.name, champion) != null, ability.name + " has an icon")
		a.identity.heat = 70
		a.identity.stars = [{"id": 2, "left": 9.0}]
		a.identity.anchor_pos = Vector3(1, 0, 2)
		a.cooldowns[11] = 8.0
		var state: Dictionary = a.snapshot()
		a.reset_identity()
		a.receive(bytes_to_var(var_to_bytes(state)), true)
		check(a.identity.heat == 70 and a.identity.stars.size() == 1 and a.cooldowns[11] == 8, "Expanded state round-trips for " + champion)
		arena.update_visuals(0)
		check(arena.ability_buttons[11].visible, "Second bar is visible for " + champion)
	arena.default_bindings()
	var old: Array = []
	for i in range(arena.TOTAL_SLOTS):
		old.append(i % 7)
	arena.config.set_value("hud", "assignment", old)
	arena.load_layout()
	var all_reachable := true
	for i in range(12):
		all_reachable = all_reachable and arena.assignment.has(i)
	check(all_reachable, "Full legacy layouts migrate by replacing duplicate slots")
	arena.config.set_value("hud", "assignment", [])
	print("Class identity checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
