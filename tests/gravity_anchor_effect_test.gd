extends SceneTree
var checks := 0
var failures := 0
var game

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.mode = 3
	game.roster = {1: {"champion": "Fulcrum", "team": 0}, 4: {"champion": "Fulcrum", "team": 1}}
	game.begin_round()
	game.phase = "match"
	game.local_id = 1
	game.update_visuals(0)
	var a = game.actors[1]
	var b = game.actors[2]
	var first = a.get_node("GravityMarker")
	var second = b.get_node("GravityMarker")
	check(not first.visible and not first.is_processing(), "Unplaced anchor is hidden and does not animate")
	check(first.find_children("*", "CollisionObject3D", true, false).is_empty(), "Relic has no collision or targeting surface")
	a.identity.anchor_left = 20.0
	a.identity.anchor_pos = Vector3(1, 0, 2)
	b.identity.anchor_left = 13.0
	b.identity.anchor_pos = Vector3(4, 0, -2)
	var before: Dictionary = a.identity.duplicate(true)
	game.update_visuals(0)
	check(a.identity == before, "Presentation does not mutate replicated mechanics")
	check(first.visible and second.visible, "Concurrent anchors both appear")
	check(first.timer.text.begins_with("ALLY") and second.timer.text.begins_with("ENEMY"), "Allegiance is labeled independently")
	check(first.global_position.is_equal_approx(Vector3(1, 0.08, 2)), "Relic uses authoritative ground position")
	first._process(1.0)
	check(first.body.scale.is_equal_approx(Vector3.ONE), "Arrival reaches full size")
	var prior_basis: Basis = first.outer.basis
	first._process(0.2)
	check(not first.outer.basis.is_equal_approx(prior_basis), "Ring rotates during idle")
	check(second.age == 0.0, "One anchor animation cannot advance another")
	a.position += Vector3(3, 0, 0)
	game.update_visuals(0)
	check(first.global_position.is_equal_approx(Vector3(1, 0.08, 2)), "Moving caster does not move placed relic")
	a.identity.orbit = 6.0
	game.update_visuals(0)
	check(first.boundary.scale.x == a.Kits.HEAVY_ORBIT_RADIUS and first.body.scale.x == 1.0, "Heavy Orbit expands truthful boundary without enlarging model")
	a.identity.orbit = 0.0
	a.casting = 11
	game.update_visuals(0)
	check(first.boundary.scale.x == 6.0, "Collapse retains six-meter warning")
	a.casting = -1
	game.update_visuals(0)
	check(first.boundary.scale.x == 1.0, "Interrupted Collapse returns to ordinary boundary")
	a.identity.anchor_left = 15.0
	game.update_visuals(0)
	a.identity.anchor_left = 20.0
	game.update_visuals(0)
	check(first.age == 0.0, "Replacement at same location restarts appearance")
	first._process(1.0)
	a.identity.anchor_pos += Vector3.RIGHT
	game.update_visuals(0)
	check(first.age == 0.0, "Replacement at new location resets without trailing old position")
	game.player_options.reduced_effects = true
	game.update_visuals(0)
	prior_basis = first.outer.basis
	first._process(0.2)
	check(first.outer.basis.is_equal_approx(prior_basis) and first.body.scale == Vector3.ONE, "Reduced effects retains static full-size relic")
	a.hp = 0
	game.update_visuals(0)
	check(not first.visible and not first.is_processing() and second.visible, "Caster death clears only its own effect")
	a.hp = 100
	a.identity.anchor_left = 0.0
	game.update_visuals(0)
	check(not first.visible, "Expired or consumed anchor remains hidden")
	b.identity.anchor_left = 0.0
	game.update_visuals(0)
	check(not second.visible, "All effects clear independently")
	var old = weakref(first)
	game.begin_round()
	await process_frame
	check(old.get_ref() == null, "Round reset frees old anchor presentation")
	print("Gravity Anchor checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
