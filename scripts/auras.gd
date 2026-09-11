extends RefCounted

# Buffs and debuffs, derived rather than stored.
#
# Every effect in the game is already a timer on the combatant — `stunned`,
# `locked`, `shield`, `sprint`, `dr_timer`. Storing a second parallel list of
# "active auras" would mean two sources of truth that can disagree, and would
# have to be replicated separately. Instead this reads the fields that are
# already authoritative and already in every snapshot, so an aura cannot be
# shown that the simulation does not believe in.
#
# Display names depend on champion: the same shield field is Ward on Ember,
# Iron Skin on Vanguard, Umbra on Fulcrum, and Sanctuary when a Luminary put it
# there. Only the name changes — the mechanic is one field.

const DEBUFF := "debuff"
const BUFF := "buff"

static func shield_name(champion: String) -> String:
	match champion:
		"Vanguard":
			return "Iron Skin"
		"Fulcrum":
			return "Umbra"
		"Luminary":
			return "Sanctuary"
		_:
			return "Ward"

# Returns active auras, most urgent first, as
# {key, name, kind, remaining, description, color}, with optional stacks.
static func active(actor, sources: Array = [], local_source: int = -1) -> Array:
	var out: Array = []
	if actor == null or actor.hp <= 0:
		return out
	# Brands are stored on their caster, keyed by victim, and are already in
	# snapshots. Read that state rather than adding a second debuff timer.
	for caster in sources:
		if caster.hp <= 0: continue
		var brand: Dictionary = caster.identity.get("brands", {}).get(actor.actor_id, {})
		var stacks := int(brand.get("count", 0))
		var remaining := float(brand.get("left", 0.0))
		if stacks <= 0 or remaining <= 0: continue
		var aura := {"key": "brand_%s" % caster.actor_id, "name": "Brand ×%d" % stacks,
			"kind": DEBUFF, "remaining": remaining, "stacks": stacks,
			"source": "Flashpoint", "caster_id": caster.actor_id, "color": Color("ff9c54"),
			"description": "%s Brand: %d/3 stacks. This Ember's Flashpoint consumes these stacks for bonus damage. Kindle refreshes the duration." % ["Your" if caster.actor_id == local_source else "Ember #%d's" % caster.actor_id, stacks]}
		if caster.actor_id == local_source: out.push_front(aura)
		else: out.append(aura)
	for source_id in actor.identity.dots:
		var dot: Dictionary = actor.identity.dots[source_id]
		var stacks := int(dot.get("stacks", 1))
		out.append({"key": "graviton_%s" % source_id, "name": "Graviton ×%d" % stacks, "kind": DEBUFF, "remaining": dot.left, "color": Color("b98cff"), "source": "Graviton", "description": "%d damage each second (%d/2 stacks). Generates no Meditation. DPS Mend removes this DoT." % [3 * stacks, stacks]})
	for source_id in actor.identity.entropy_dots:
		out.append({"key": "entropy_%s" % source_id, "name": "Entropy", "kind": DEBUFF, "remaining": actor.identity.entropy_dots[source_id].left, "color": Color("d395ff"), "source": "Entropy", "description": "2 damage and 5 Meditation for its caster each second. Cannot stack per caster. DPS Mend removes this DoT."})
	if actor.stunned > 0:
		out.append({
			"key": "stun", "name": "Stunned", "kind": DEBUFF,
			"remaining": actor.stunned, "color": Color("ff7d92"),
			"source": actor.stun_from, "cc": "STUNNED",
			"description": "Cannot move, act or cast. Damage does not break it. Dispel removes it.",
		})
	if actor.locked > 0:
		out.append({
			"key": "lockout", "name": "Spell Lockout", "kind": DEBUFF,
			"remaining": actor.locked, "color": Color("e8845f"),
			"source": actor.lock_from, "cc": "LOCKED OUT",
			"description": "Interrupted. Most abilities are unusable; defensive and movement abilities still work.",
		})
	if actor.shield > 0:
		# Sanctuary comes from a Luminary, so the source is more accurate than
		# guessing from the champion wearing it. Fall back for old snapshots.
		var name: String = actor.shield_from if not actor.shield_from.is_empty() else shield_name(actor.champion)
		out.append({
			"key": "shield", "name": name, "kind": BUFF,
			"remaining": actor.shield, "color": Color("6fe3ff"),
			"source": actor.shield_from,
			"description": "Takes 60% less damage from every hit. Does not prevent control or interrupts.",
		})
	if actor.sprint > 0:
		out.append({
			"key": "sprint", "name": "Grace", "kind": BUFF,
			"remaining": actor.sprint, "color": Color("97edb1"),
			"source": actor.sprint_from,
			"description": "Moves 65% faster. Does not increase jump height or clear stuns.",
		})
	var identity: Dictionary = actor.identity
	for source_id in identity.get("severe_bleeds", {}):
		out.append({"key": "severe_%s" % source_id, "name": "Severe", "kind": DEBUFF, "remaining": identity.severe_bleeds[source_id].left, "color": Color("dd6c74"), "source": "Severe", "description": "Bleeds for 2 damage each second for 5 seconds. Refreshes per caster. DPS Mend removes it."})
	if identity.get("coin_left", 0.0) > 0:
		out.append({"key": "coin_combo", "name": "Coin Trickshot", "kind": BUFF, "remaining": identity.coin_left, "color": Color("f2c676"), "source": "Coin Toss", "description": "One off-GCD Trickshot while the coin is in flight. Both bullet segments must clear terrain."})
	if preload("res://scripts/crowd_control.gd").airborne_immune(actor):
		if identity.get("lasso",{}).get("air",false):
			var lasso: Dictionary = identity.lasso
			var duration: float = preload("res://scripts/outlaw_lasso.gd").REBOUND_TIME if lasso.phase == "rebound" else preload("res://scripts/outlaw_lasso.gd").TIMEOUT
			out.append({"key":"airborne_lasso", "name":"Lasso", "kind":BUFF, "remaining":maxf(.01,actor.cast_left if lasso.phase=="cast" else duration-float(lasso.get("elapsed",0))), "color":Color("92ceff"), "source":"Lasso", "description":"Immune to crowd control and displacement while airborne during Lasso. Ends on landing or when the combo finishes."})
		else:
			out.append({"key": "backflip", "name": "Backflip", "kind": BUFF, "remaining": maxf(.01, 1.2 - identity.backflip_elapsed), "color": Color("92ceff"), "source": "Backflip", "description": "Immune to crowd control and displacement until landing. One airborne Trickshot opportunity."})
	for proc in [
		["instant_severe", "Instant Severe", "Roll", "Roll grants 1.5 seconds to use one instant Severe. Severe's range, cooldown and global cooldown still apply. Consumed on successful use."],
		["instant_collapse", "Instant Collapse", "Collapse", "Inward grants 4s to cast one instant Collapse off the global cooldown. Collapse's own cooldown still applies. Consumed when used."],
		["instant_graviton", "Instant Graviton", "Graviton", "A landed Collapse grants 4s to cast one instant Graviton. The global cooldown still applies. Consumed when used."],
	]:
		if identity.get(proc[0], 0.0) > 0:
			out.append({"key": proc[0], "name": proc[1], "source": proc[2], "description": proc[3], "kind": BUFF, "remaining": identity[proc[0]], "color": Color("c9a0ff")})
	for item in [["root", "Rooted", "Collapse", "Cannot move; can still cast.", DEBUFF], ["slow", "Slowed", "Heavy Orbit", "Movement reduced by 45%.", DEBUFF], ["immune", "Absolution", "Absolution", "Immune to roots and slows.", BUFF], ["last", "Last Light", "Last Light", "The next lethal hit leaves 1 HP, then protection ends.", BUFF], ["hold", "Hold the Line", "Hold the Line", "Stationary, displacement resistant; 70% frontal damage reduction.", BUFF], ["guard_left", "Intercede", "Intercede", "Redirecting 30% of an ally's incoming damage, up to the remaining budget.", BUFF], ["challenge_left", "Challenge", "Challenge", "Marked enemy attacking allies grants Resolve.", BUFF]]:
		if identity.get(item[0], 0.0) > 0:
			out.append({"key": item[0], "name": item[1], "source": item[2], "description": item[3], "kind": item[4], "remaining": identity[item[0]], "color": Color("c9a0ff")})
	for aura in out:
		if aura.key == "root" and actor.cc_effects.has("root"):
			aura.source = actor.cc_effects.root.source
		if aura.key == "stun":
			if actor.cc_effects.has("incapacitate"):
				aura.name = "Incapacitated"
				aura.cc = "INCAPACITATED"
				aura.description = "Cannot move or cast. Any damage breaks this effect."
			elif actor.cc_effects.has("disorient"):
				aura.name = "Disoriented"
				aura.cc = "DISORIENTED"
				aura.description = "Cannot move or cast. Damage can break this effect; 20 total damage guarantees it."
	for category in ["silence", "disarm"]:
		if actor.cc_effects.has(category):
			var effect: Dictionary = actor.cc_effects[category]
			out.append({"key": category, "name": "Silenced" if category == "silence" else "Disarmed", "cc": category.to_upper(), "source": effect.source, "kind": DEBUFF, "remaining": effect.remaining, "color": Color("b899df"), "description": "Cannot cast abilities. Movement is allowed; damage does not break this effect."})
	return out

# The crowd control currently on a fighter, or an empty dictionary. Stuns
# outrank lockouts because a stun stops everything and a lockout only stops most
# of it — if both are running, the stun is the one you are waiting out.
static func crowd_control(actor) -> Dictionary:
	var best := {}
	for aura in active(actor):
		if not aura.has("cc"):
			continue
		if best.is_empty() or aura.key == "stun":
			best = aura
	return best

# Compact form for overhead nameplates, where there is no room for a panel.
static func nameplate_text(actor) -> String:
	var parts: Array[String] = []
	for aura in active(actor):
		parts.append("%s %.0fs" % [aura.name, ceil(aura.remaining)])
	return "  ".join(parts)
