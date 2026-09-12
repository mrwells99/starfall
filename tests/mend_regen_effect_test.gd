extends SceneTree
## Client-only Mend visual checks. Healing authority is exercised separately.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func mend_slot(actor: CharacterBody3D) -> int:
	for slot in actor.kit.size():
		if actor.kit[slot].kind == "self_heal": return slot
	return -1

func advance(actor: CharacterBody3D, seconds: float) -> void:
	for frame in ceili(seconds * 60.0): actor.champion_model.animate(1.0 / 60.0, actor)

func run() -> void:
	for champion in ["Ember", "Luminary", "Fulcrum", "Vanguard", "Outlaw"]:
		var actor = load("res://scripts/combatant.gd").new()
		root.add_child(actor); actor.setup(1, 1, 0, champion)
		actor.presentation_grounded = true
		var slot := mend_slot(actor)
		check(slot >= 0, champion + " has Mend")
		var effect: Node3D = actor.champion_model.mend_regen_effect
		check(effect != null and effect.motes.size() == effect.CROSS_COUNT, champion + " has one retained Mend healing effect")
		check(not effect.visible, champion + " effect starts hidden")
		actor.casting = slot; actor.cast_left = 2.0
		advance(actor, .45)
		check(effect.visible and effect.intensity > .99, champion + " gets the full green cross/glow effect while Mend casts")
		var active_crosses := 0
		for mote in effect.motes:
			if mote.material.albedo_color.a > .01: active_crosses += 1
		check(active_crosses > 0, champion + " Mend has visible rising crosses")
		actor.casting = -1; actor.cast_left = 0.0
		advance(actor, .25)
		check(not effect.visible and effect.light.light_energy == 0.0, champion + " effect ends immediately after Mend")
		actor.free()
	await process_frame
	print("Mend regen effect checks: %d passed / %d total" % [checks-failures, checks])
	quit(1 if failures else 0)
