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
# {key, name, kind, remaining, description, color}.
static func active(actor) -> Array:
	var out: Array = []
	if actor == null or actor.hp <= 0:
		return out
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
	# Diminishing returns is not an effect on the fighter, but it decides whether
	# your next stun is worth casting, so it belongs on the frame.
	if actor.dr_timer > 0 and actor.dr_count > 0:
		var next_text := "immune to further stuns"
		if actor.dr_count == 1:
			next_text = "next stun lasts 50%"
		elif actor.dr_count == 2:
			next_text = "next stun lasts 25%"
		out.append({
			"key": "dr", "name": "Diminished %d" % actor.dr_count, "kind": DEBUFF,
			"remaining": actor.dr_timer, "color": Color("c9a0ff"),
			"source": "",
			"description": "Recently stunned — %s. Resets 18s after the last stun ends." % next_text,
		})
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
