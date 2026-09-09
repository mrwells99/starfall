extends SceneTree

func _initialize() -> void:
	var kits = load("res://scripts/kits.gd")
	var text := """# Class abilities

Current implementation, September 8, 2026. Balance is provisional and needs human playtesting. Fulcrum has fourteen abilities: 1–7 on the first bar and Shift+1–7 on the second, including Starfall on Shift+6 and Entropy on Shift+7. Other classes have twelve abilities, ending at Shift+5. All slots can be rebound or moved in Edit HUD.

Older saved layouts gain missing abilities in empty slots, or replace a duplicate slot if the bars are full. Existing primary, secondary, and action bindings take priority. Entropy receives Shift+7 only when that key is free; otherwise its migrated slot remains clickable and can be rebound in Settings. A custom binding already attached to that slot is retained.

Range is the actual maximum distance to the selected target. Self-targeted abilities show their stored 0m range; their effect radii, anchor limits, or movement distances are listed separately. Cast times below are the ordinary values; the effect descriptions explain instant-cast charges.

"""
	var ability_count := 0
	for champion in kits.NAMES:
		text += "## " + champion + "\n\n| Key | Ability | Effect | Range | Cast | Cooldown |\n| --- | --- | --- | --- | --- | --- |\n"
		var kit: Array = kits.get_kit(champion)
		for i in range(kit.size()):
			var s: Dictionary = kit[i]
			var range_text := "Self (%s m)" % s.range if s.kind in kits.SELF_KINDS else "%s m" % s.range
			text += "| %s | %s | %s | %s | %s | %ss%s |\n" % [str(i + 1) if i < 7 else "Shift+" + str(i - 6), s.name, kits.summary(s), range_text, "Instant" if s.cast == 0 else str(s.cast) + "s", s.cd, " (off GCD)" if s.off else ""]
			ability_count += 1
		text += "\n"
	text += """## Shared rules

All positive cast ranges are reduced by 25%, rounded to the nearest 0.5m, and capped at 18m. Opposing arena spawn lines are 20m apart, so direct targeted spells cannot reach the opposing spawn at the start. This does not prevent self abilities or change separately specified effect radii and displacement distances. Luminary healing links and Intercede's ongoing protection require allies within 18m and line of sight.

Heat, Resolve and Meditation cap at 100. Graviton deals 6 initial damage and applies an 11-second DoT, dealing 3 damage each second per stack with at most two stacks per caster. Reapplication refreshes both stacks without delaying the next tick. Graviton generates no Meditation. These are two damage-over-time stacks, not stored casts.

Entropy is an instant 15-second DoT that deals 2 damage and generates 5 Meditation for its caster each second. Each caster can maintain only one Entropy stack on a target; reapplication refreshes its duration without delaying the next tick. Graviton and Entropy can coexist. Completed DPS Mend clears all attached DoTs; standing in a ground hazard still deals damage. DoTs stop when their caster dies, departs, or can no longer harm the target.

Inward grants one stored instant, off-global-cooldown Collapse. Repeated Inward casts do not add another charge. The charge is retained until used, and Collapse's own 18-second cooldown still applies. Casting charged Collapse does not restart the global cooldown. A Collapse that hits an enemy grants one instant Graviton, also retained until used. At 75+ Meditation, Collapse stuns for up to 3 seconds (subject to diminishing returns) without spending Meditation.

Fulcrum's Starfall requires at least 50 Meditation and consumes all Meditation only on successful cast completion. It deals 20 + 0.4 damage per point spent to hostile targets within 5m of the selected target's position at completion, including the selected target. Splash requires line of sight from the impact center. Interrupted casts spend no Meditation. Luminary's Starfall retains its separate damage and starred-ally healing effect.

Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Gravity Anchor is placed up to 10m in the direction faced, swept against terrain and projected onto the floor. It lasts 20 seconds. Anchor abilities need the caster within 18m of the anchor. Inward and Outward additionally need their target within 18m of the anchor and within their 18m cast range. Inward, Outward, Collapse and Heavy Orbit ignore line-of-sight blockers; pushes and pulls still stop at solid collision. Non-anchor ground effects still require line of sight. Counterweight exchanges immediately after validation; both swept routes must be clear.

Stuns, disorients, and roots share diminishing returns. Solar Flare breaks on damage. Rooted characters can cast but cannot jump or use movement abilities; Absolution clears roots and slows. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Mend always heals up to 28, without dampening. Other healing retains match dampening in arena matches only; world healing is never dampened.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor rings and timers, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Charged Collapse and instant Graviton highlight their hotbar icons. Earthsplitter applies a brief stun with a small airborne launch. Exact character transformation animations, sound, and bespoke spell cinematics are not implemented by this class pass.
"""
	var output := FileAccess.open("res://docs/CLASS_ABILITIES.md", FileAccess.WRITE)
	if output == null:
		push_error("Could not write class reference: %s" % error_string(FileAccess.get_open_error()))
		quit(1)
		return
	output.store_string(text)
	output.close()
	print("Generated class reference: %d abilities with current cast ranges." % ability_count)
	quit()
