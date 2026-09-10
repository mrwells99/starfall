extends SceneTree

func _initialize() -> void:
	var kits = load("res://scripts/kits.gd")
	var text := """# Class abilities

Current implementation, September 10, 2026. Outlaw has ten available abilities: Defense Detonation on Shift+2 now owns shoulder aiming, with its firing stage still disabled. The separate Aim Test entry is retired and its old Shift+4 slot is empty. Fulcrum has twelve available abilities: Horizon and the direct Anchor stun are removed, with their old default key 3 and 4 slots left empty to preserve all other saved bindings. Gravity Anchor remains on Shift+1, Starfall on Shift+6 and Entropy on Shift+7. Ember, Vanguard and Luminary have twelve abilities, ending at Shift+5. All available slots can be rebound or moved in Edit HUD.

Older saved layouts gain missing abilities in empty slots, or replace a duplicate slot if the bars are full. Existing primary, secondary, and action bindings take priority. Entropy receives Shift+7 only when that key is free; otherwise its migrated slot remains clickable and can be rebound in Settings. A custom binding already attached to that slot is retained.

Range is the actual maximum distance to the selected target. Self-targeted abilities show their stored 0m range; their effect radii, anchor limits, or movement distances are listed separately. Cast times below are the ordinary values; the effect descriptions explain temporary instant-cast buffs. Outlaw's provisional cooldowns and unspecified tuning are documented in OUTLAW_CLASS.md.

"""
	var ability_count := 0
	for champion in kits.NAMES:
		text += "## " + champion + "\n\n| Key | Ability | Effect | Range | Cast | Cooldown |\n| --- | --- | --- | --- | --- | --- |\n"
		var kit: Array = kits.get_kit(champion)
		for i in range(kit.size()):
			var s: Dictionary = kit[i]
			if s.kind == "unavailable": continue
			var range_text := "Self (%s m)" % s.range if s.kind in kits.SELF_KINDS else "%s m" % s.range
			if s.kind == "flare_cc": range_text = "4 m cone"
			if s.kind == "deadeye": range_text = "18 m sight at completion"
			text += "| %s | %s | %s | %s | %s | %ss%s |\n" % [str(i + 1) if i < 7 else "Shift+" + str(i - 6), s.name, kits.summary(s), range_text, "Instant" if s.cast == 0 else str(s.cast) + "s", s.cd, " (off GCD)" if s.off else ""]
			ability_count += 1
		text += "\n"
	text += """## Shared rules

All positive cast ranges are reduced by 25%, rounded to the nearest 0.5m, and capped at 18m. Opposing arena spawn lines are 20m apart, so direct targeted spells cannot reach the opposing spawn at the start. This does not prevent self abilities or change separately specified effect radii and displacement distances. Luminary healing links and Intercede's ongoing protection require allies within 18m and line of sight.

Heat, Resolve and Meditation cap at 100. Graviton deals 6 initial damage and applies an 11-second DoT, dealing 3 damage each second per stack with at most two stacks per caster. Reapplication refreshes both stacks without delaying the next tick. Graviton generates no Meditation. These are two damage-over-time stacks, not stored casts.

Entropy is an instant 15-second DoT that deals 2 damage and generates 5 Meditation for its caster each second. Each caster can maintain only one Entropy stack on a target; reapplication refreshes its duration without delaying the next tick. Graviton and Entropy can coexist. Completed DPS Mend clears all attached DoTs; standing in a ground hazard still deals damage. DoTs stop when their caster dies, departs, or can no longer harm the target.

Inward grants a four-second buff for one instant, off-global-cooldown Collapse. A landed Collapse grants a separate four-second buff for one instant Graviton. Each buff disappears when used or when its window expires; another qualifying cast refreshes the window to four seconds without stacking. Failed cast attempts neither consume nor refresh the remaining time. Collapse's own 18-second cooldown still applies, and its instant cast does not restart the global cooldown. Instant Graviton retains its normal global cooldown. At 75+ Meditation, Collapse stuns for up to 3 seconds without spending Meditation.

Vanguard's Charge immediately applies a three-second root on a successful cast, subject to root immunity and diminishing returns. It then moves continuously at 32m/s along a collision-checked route and deals its existing 6 damage on arrival at melee range. Range, facing and LOS are checked initially; losing LOS afterwards does not cancel the rush. Detours use ramp entrances and avoid pillars, walls and terrace ledges. A target with no safe route is rejected before spending the cast. Target death or loss of duel permission cancels remaining travel/damage. The individual 12-second cooldown and off-GCD behavior are unchanged.

Fulcrum's Starfall requires at least 50 Meditation and consumes all Meditation only on successful cast completion. It deals 20 + 0.4 damage per point spent to hostile targets within 5m of the selected target's position at completion, including the selected target. Splash requires line of sight from the impact center. Interrupted casts spend no Meditation. Luminary's Starfall retains its separate damage and starred-ally healing effect.

Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Gravity Anchor is placed up to 10m in the direction faced, swept against terrain and projected onto the floor. It lasts 20 seconds. Anchor abilities need the caster within 18m of the anchor. Inward and Outward need their target within 9m of the anchor (1.5 times Heavy Orbit's 6m radius), while retaining their existing 18m caster-to-target limit. Actual displacement by either ability immediately cancels the enemy's current cast without school lockout or GCD refund. Zero movement does not interrupt. Horizon and the direct Anchor stun are no longer available; Gravity Anchor remains. Inward, Outward, Collapse and Heavy Orbit ignore line-of-sight blockers; pushes and pulls still stop at solid collision. Non-anchor ground effects still require line of sight. Counterweight exchanges immediately after validation; both swept routes must be clear.

Solar Flare is an untargeted 4m cone with a 108-degree total angle, aimed using Ember's character heading. Its local ground outline appears only for one second after a successful cast, including a cast that hits no enemies. Enemies inside the cone must also pass terrain line-of-sight and duel-permission checks. It retains its 18s cooldown, ordinary global cooldown and up-to-3s incapacitate, which breaks on damage.

Blink has two stored casts, restoring one charge at a time every 14s. Spending the second charge does not restart the first recharge. It moves up to 8m along the movement input sampled when casting, including diagonals; with no movement input it uses camera heading, even during free look or airborne momentum. It is off the global cooldown and stops at solid terrain. The hotbar shows remaining charges and a recharge countdown; one available charge stays usable while the other recharges.

Control categories have independent diminishing returns. Rooted characters can cast but cannot jump or start movement abilities; Absolution clears roots and slows. An already accepted Charge completes its committed travel. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Mend always heals up to 28, without dampening. Other healing retains match dampening in arena matches only; world healing is never dampened.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor rings and timers, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Instant Collapse and instant Graviton show buff countdowns and highlight their hotbar icons only while the four-second windows remain active. Earthsplitter applies a brief stun with a small airborne launch.
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
