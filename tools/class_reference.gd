extends SceneTree

func _initialize() -> void:
	var kits = load("res://scripts/kits.gd")
	var text := """# Class abilities

Current implementation, September 15, 2026. Fulcrum harnesses gravity and dark energy through Compression, Expansion, Ruin and Divide. Six explicitly labeled anchor range variants use 3m / 8m / 15m. Graviton and Fulcrum's Starfall are retired. Trinket remains Ctrl+1; Gravity Flow is Ctrl+2. Existing saved bindings are preserved and missing abilities enter free slots.

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
			text += "| %s | %s | %s | %s | %s | %ss%s |\n" % [("Ctrl+1" if i==14 else ("Ctrl+2" if i==15 else (str(i+1) if i<7 else "Shift+"+str(i-6)))), s.name, kits.summary(s), range_text, "Instant" if s.cast == 0 else str(s.cast) + "s", s.cd, " (off GCD)" if s.off else ""]
			ability_count += 1
		text += "\n"
	text += """## Shared rules

Base positive cast ranges are reduced by 25%, rounded to the nearest 0.5m, and capped at 18m. Severe then receives its explicit 10% increase from 3m to 3.3m, without another rounding pass. Opposing arena spawn lines are 20m apart, so direct targeted spells cannot reach the opposing spawn at the start. This does not prevent self abilities or change separately specified effect radii and displacement distances. Luminary healing links and Intercede's ongoing protection require allies within 18m and line of sight.

Heat, Resolve and Meditation cap at 100. Entropy deals 20 damage and generates 10 Meditation per second for 15 seconds. It is instant only with no active Entropy from that caster; spreading or refreshing uses a 0.8s cast. Cleansing it inflicts a three-second silence on the cleanser. Natural expiration, death and duel cleanup do not trigger backlash. Other damage defenses and silence diminishing returns remain applicable.

Ruin costs 33 Meditation per slash, dealing 108 damage to your selected enemy. Right starts the combo; left requires strictly more than 66 remaining and must follow within six seconds. Left unlocks Divide for six seconds and locks Ruin itself out for eight seconds — only two slashes per combo. Divide requires no further resource, uses the selected enemy with no manual aiming, charges 0.3s, then deals 162 damage in a 15m by 3m line. Casting Divide copies whatever remains of Ruin's eight-second lockout onto its own cooldown, so the two then tick down together. The 0.65s lingering area hits each enemy once. It can pass through up to 3m total solid cover around corners; a full pillar blocks it. The six-second ground rift slows by 50%. Gravity Flow lasts eight seconds on a 60-second cooldown: slashes bypass GCD, Divide has no charge, and each enemy a flow-charged Divide hits also detonates for damage to enemies within 5m.

Vanguard's Charge immediately applies a three-second root on a successful cast, subject to root immunity and diminishing returns. It then moves continuously at 32m/s along a collision-checked route and deals its existing 6 damage on arrival at melee range. Range, facing and LOS are checked initially; losing LOS afterwards does not cancel the rush. Detours use ramp entrances and avoid pillars, walls and terrace ledges. A target with no safe route is rejected before spending the cast. Target death or loss of duel permission cancels remaining travel/damage. The individual 12-second cooldown and off-GCD behavior are unchanged.

Each Luminary owns at most three stars. Brands, stars, anchors, defensive states, roots and ground fields are authoritative and replicated. Class resources reset between rounds and at duel boundaries. Stars expire after 30 seconds; brands after 10.

Compression and Expansion place anchors 3m / 8m / 15m ahead, swept against collision and projected onto safe ground. Each polarity shares a twelve-second cooldown across its range variants. Compression pulls visible enemies in a 6m radius, deals 132 damage and stuns for 1.2s, subject to normal control rules. It grants 20 Meditation when at least one valid enemy is caught. Expansion's 3.6m purple sphere deals 100 damage and launches enemies with momentum. Sight is judged from the caster, not the anchor: an enemy the anchor could see but you cannot is not affected. Each anchor stays for three seconds: exchange positions with it along a clear path, or consume it to grow a six-second black-grass field to a 6m radius over one second, slowing by 45%. These follow-ups are off GCD and mutually exclusive for that anchor.

Solar Flare is an untargeted 4m cone with a 108-degree total angle, aimed using Ember's character heading. Its local ground outline appears only for one second after a successful cast, including a cast that hits no enemies. Enemies inside the cone must also pass terrain line-of-sight and duel-permission checks. It retains its 18s cooldown, ordinary global cooldown and up-to-3s incapacitate, which breaks on damage.

Blink has two stored casts, restoring one charge at a time every 14s. Spending the second charge does not restart the first recharge. It moves up to 8m along the movement input sampled when casting, including diagonals; with no movement input it uses camera heading, even during free look or airborne momentum. It is off the global cooldown and stops at solid terrain. The hotbar shows remaining charges and a recharge countdown; one available charge stays usable while the other recharges.

Control categories have independent diminishing returns. Rooted characters can cast but cannot jump or start movement abilities; Absolution clears roots and slows. An already accepted Charge completes its committed travel. Hold the Line prevents movement and displacement but allows turning; attacking ends it. Damage reductions use the strongest applicable reduction, not multiplication.

Last Light prevents one lethal hit by leaving 1 HP; it is not a resurrection. Intercede redirects at most 30 raw damage, requires ongoing range and line of sight, and cannot form recursive damage chains. Mend always heals up to 28, without dampening. Other healing retains match dampening in arena matches only; world healing is never dampened.

World bystanders cannot damage, control, or displace duelists, or heal/protect/exchange places with them. Self abilities remain available. Bot priorities exercise each identity; they are introductory sparring AI, not a competitive benchmark.

Anchor effects, burning-field outlines, Supernova warnings, resource text, brand counts, star counts, and status icons expose combat state. Ruin continuation and Divide readiness highlight their hotbar icons. Earthsplitter applies a brief stun with a small airborne launch.
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
