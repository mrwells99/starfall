extends SceneTree
var arena
var checks := 0
var failures := 0
func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	for champion in arena.Kits.NAMES:
		arena.mode = 1
		arena.roster = {1: {"champion": champion, "team": 0}, 2: {"champion": "Ember", "team": 1}}
		arena.begin_round(); arena.phase = "match"
		var a = arena.actors[1]; var b = arena.actors[2]
		ck(is_equal_approx(a.position.distance_to(b.position), 20), "Opposing spawns are twenty metres apart")
		a.identity.heat = 100; a.identity.resolve = 100; a.identity.meditation = 100
		a.identity.anchor_left = 20; a.identity.anchor_pos = Vector3(0, 0, 2)
		for slot in a.kit.size():
			var spell: Dictionary = a.kit[slot]
			if spell.range > 0:
				ck(spell.range <= 18, "%s range fits the new cap" % spell.name)
			if spell.kind in arena.Kits.SELF_KINDS or spell.kind in arena.Kits.ALLY_KINDS:
				continue
			ck(not arena.try_spell(1, slot, 2) and a.casting == -1, "%s cannot start on an enemy at opposing spawn" % spell.name)
		var reach: float = a.kit[0].range
		a.position = Vector3(0, .01, 3); b.position = a.position + Vector3(0, 0, -reach-.01)
		ck(arena.validate_spell(a, 0, 2) == "Out of range", "Primary rejects just beyond its listed range: " + champion)
		b.position = a.position + Vector3(0, 0, -minf(6.0, reach-.01))
		ck(arena.validate_spell(a, 0, 2).is_empty(), "Primary remains usable after approaching: " + champion)
		if champion == "Fulcrum":
			a.identity.anchor_pos = a.position + Vector3(18.01, 0, 0)
			ck(arena.validate_spell(a, 11, 1) == "Anchor out of range", "Remote anchor control is capped too")
	ck(arena.Kits.get_kit("Vanguard")[0].range == 2.5, "Melee reach is reduced from 3.5 to 2.5m")
	ck(arena.Kits.get_kit("Ember")[2].range == 16.5, "Interrupt reach is reduced from22 to16.5m")
	ck(arena.Kits.get_kit("Luminary")[5].range == 18, "Healing reach is capped at18m")
	print("Spell range checks: %d passed / %d total" % [checks-failures, checks])
	arena.queue_free(); await process_frame
	quit(1 if failures else 0)
