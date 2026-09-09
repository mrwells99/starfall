extends RefCounted

const SELF_KINDS := ["shield", "self_heal", "blink", "sprint", "cinder", "stoke", "wake", "hold", "unbroken", "anchor", "orbit", "collapse"]
const ALLY_KINDS := ["heal", "ally_shield", "dispel", "falling", "absolution", "stitch", "star", "pilgrim", "last", "intercede", "swap"]
const KIT_SIZE := 13 # Maximum; Fulcrum has thirteen, other kits have twelve.

const NAMES = ["Ember", "Vanguard", "Luminary", "Fulcrum"]

# Class colours. Chosen to be distinguishable at a glance against the dark UI
# and from each other, and to match how each champion already reads: Ember is
# fire, Vanguard is armour, Luminary is restoration, Fulcrum is gravity.
const COLORS := {
	"Ember": Color("ff8a4c"),
	"Vanguard": Color("ffd166"),
	"Luminary": Color("7ee08a"),
	"Fulcrum": Color("b98cff"),
}

static func color(champion: String) -> Color:
	return COLORS.get(champion, Color("9fb0c2"))

static func spell(title: String, kind: String, power: float, reach: float, cast: float, cd: float, off: bool = false) -> Dictionary:
	return {"name": title, "kind": kind, "power": power, "range": reach, "cast": cast, "cd": cd, "off": off}

static func get_kit(champion: String) -> Array:
	var kit := [
		spell("Firebolt", "damage", 16, 28, 1.5, 0),
		spell("Flare", "damage", 22, 22, 0, 7),
		spell("Disrupt", "interrupt", 4, 22, 0, 12, true),
		spell("Stasis", "control", 4, 20, 0.8, 16),
		spell("Ward", "shield", 5, 0, 0, 22, true),
		spell("Mend", "self_heal", 28, 0, 2, 16),
		spell("Blink", "blink", 8, 0, 0, 14, true)
	]
	if champion == "Vanguard":
		kit[0] = spell("Cleave", "damage", 13, 3.5, 0, 0)
		kit[1] = spell("Crush", "damage", 25, 3.5, 0, 7)
		kit[2] = spell("Pummel", "interrupt", 4, 4, 0, 12, true)
		kit[3] = spell("Bash", "control", 3, 3.5, 0, 16)
		kit[4] = spell("Iron Skin", "shield", 5, 0, 0, 22, true)
		kit[6] = spell("Charge", "charge", 6, 22, 0, 12, true)
	elif champion == "Fulcrum":
		kit[0] = spell("Collapse", "damage", 14, 24, 1.3, 0)
		kit[1] = spell("Tidal Force", "damage", 20, 20, 0, 7)
		kit[2] = spell("Horizon", "interrupt", 4, 22, 0, 12, true)
		kit[3] = spell("Anchor", "control", 3.5, 18, 0.6, 16)
		kit[4] = spell("Umbra", "shield", 5, 0, 0, 22, true)
		kit[6] = spell("Tether", "pull", 8, 22, 0, 14, true)
	elif champion == "Luminary":
		kit[0] = spell("Smite", "damage", 10, 28, 1.5, 0)
		kit[1] = spell("Renewal", "heal", 18, 28, 0, 7)
		kit[2] = spell("Dispel", "dispel", 0, 28, 0, 10, true)
		kit[3] = spell("Rebuke", "control", 3, 20, 1, 18)
		kit[4] = spell("Sanctuary", "ally_shield", 5, 28, 0, 22, true)
		kit[5] = spell("Greater Heal", "heal", 27, 28, 1.8, 0)
		kit[6] = spell("Grace", "sprint", 4, 0, 0, 16, true)
	if champion == "Ember":
		kit[0] = spell("Kindle", "kindle", 16, 28, 1.5, 0)
		kit[1] = spell("Flashpoint", "flashpoint", 12, 22, 0, 7)
		kit.append_array([
			spell("Supernova", "nova", 18, 26, 2.2, 20),
			spell("Solar Flare", "flare_cc", 3, 8, 0, 18),
			spell("Cinderstep", "cinder", 6, 0, 0, 18, true),
			spell("Stoke", "stoke", 30, 0, 1.5, 12),
			spell("Burning Wake", "wake", 5, 0, 0, 18)])
	elif champion == "Vanguard":
		kit[0] = spell("Sundering Blow", "sunder", 13, 3.5, 0, 0)
		kit[1] = spell("Oathbreaker", "oath", 15, 3.5, 0.8, 7)
		kit.append_array([
			spell("Intercede", "intercede", 5, 22, 0, 18, true),
			spell("Hold the Line", "hold", 4, 0, 0, 20, true),
			spell("Challenge", "challenge", 6, 22, 0, 16),
			spell("Earthsplitter", "earth", 12, 8, 0.7, 18),
			spell("Unbroken", "unbroken", 4, 0, 0, 20, true)])
	elif champion == "Luminary":
		kit[1] = spell("Falling Star", "falling", 18, 28, 0, 7)
		kit[2] = spell("Absolution", "absolution", 0, 28, 0, 10, true)
		kit[5] = spell("Stitchlight", "stitch", 27, 28, 1.8, 0)
		kit.append_array([
			spell("Guiding Star", "star", 1, 28, 0, 0),
			spell("Pilgrim's Step", "pilgrim", 0, 22, 0, 16, true),
			spell("Last Light", "last", 4, 28, 0, 45, true),
			spell("Mend", "self_heal", 28, 0, 2, 16),
			spell("Starfall", "starfall", 16, 28, 1.5, 12)])
	else:
		kit[0] = spell("Graviton", "graviton", 6, 24, 1.3, 0)
		kit[1] = spell("Inward", "inward", 8, 24, 0, 9)
		kit.append_array([
			spell("Gravity Anchor", "anchor", 20, 0, 0.6, 4),
			spell("Outward", "outward", 8, 24, 0, 9),
			spell("Heavy Orbit", "orbit", 6, 0, 0, 16),
			spell("Counterweight", "swap", 0, 22, 0, 22, true),
			spell("Collapse", "collapse", 22, 0, 1.5, 18),
			spell("Starfall", "gravity_starfall", 20, 28, 2.0, 12)])
	return kit

# These are player-facing explanations of the actual prototype rules, not lore.
# Numeric effects use the same kit dictionaries that the simulation reads.
static func summary(ability: Dictionary) -> String:
	var concepts := {
		"kindle": "Deal 16 damage. Gain 20 Heat and add a brand (up to 3) for 10s.",
		"flashpoint": "Consume your brands: 12 + 6 damage per brand. Three brands also deal 10 splash damage within 5m. Gain 10 Heat.",
		"nova": "Requires 40 Heat. Consume all Heat: 18 + 0.4 damage per Heat to enemies within 5m of the target.",
		"flare_cc": "Disorient enemies in your forward 8m cone for up to 3s. Damage breaks it; shares stun diminishing returns.",
		"cinder": "Requires and spends 20 Heat. Dash 6m and leave a 5s burning trail that slows enemies by 45%.",
		"stoke": "Generate 30 Heat. Maximum 100 Heat.",
		"wake": "Create a 5m burning field at your feet for 5s. It slows enemies by 45% and deals 4 damage each second.",
		"sunder": "Deal 13 damage and gain 20 Resolve (maximum 100). Expose this enemy to your next Oathbreaker for 6s.",
		"oath": "Spend all Resolve: deal 15 + 0.3 damage per Resolve, plus 8 against your exposed target.",
		"intercede": "Rush to another ally. For 5s redirect 30% of their damage to yourself, up to 30 total, while within 28m and line of sight. Redirected damage grants Resolve.",
		"hold": "For 4s, stand still and take 70% less frontal damage; resist displacement. Turning is allowed. Attacking ends this stance. Does not stack with stronger reduction.",
		"challenge": "For 6s, this enemy attacking your allies grants you 15 Resolve per hit, at most once per second.",
		"earth": "Deal 12 damage and stun enemies in a narrow 8m forward line for up to 1s. Shares stun diminishing returns.",
		"unbroken": "Spend 40 Resolve to gain 4s of 60% damage reduction.",
		"falling": "Heal 18. Consume one of your stars on the target to heal 16 more.",
		"absolution": "Remove stun, root and slow. Consume one of your stars to grant 3s immunity to roots and slows.",
		"stitch": "Heal 27. A starred target echoes 9 healing to one other starred ally within 28m and line of sight.",
		"star": "Place a star on an ally or yourself for 30s. Maximum 3 total per Luminary; placing a fourth moves your oldest star.",
		"pilgrim": "Consume your star on another ally to rush toward them. Stops at terrain.",
		"last": "For 4s, the first lethal hit leaves the ally at 1 HP and consumes this protection. Further damage can kill.",
		"starfall": "Deal 16 damage and heal each of your starred allies for 8 per star within 28m and line of sight.",
		"anchor": "Place a visible gravity anchor on the ground up to 10m ahead, stopping before walls. Lasts 20s. Replacing it ends its orbit.",
		"inward": "Pull an enemy up to 8m toward your anchor. Requires an active anchor within 28m. Works through line-of-sight blockers; movement still stops at solid terrain.",
		"outward": "Push an enemy up to 8m away from your anchor. Requires an active anchor within 28m. Works through line-of-sight blockers; movement still stops at solid terrain.",
		"orbit": "Your anchor creates a 6m slowing field for 6s, even through line-of-sight blockers. Enemies inside move 45% slower.",
		"swap": "Exchange positions with another ally. Both routes must be clear; cannot cross terrain.",
		"graviton": "Deal 6 damage and apply an 8s DoT: 2 damage and 5 Meditation each second. Refreshes your own DoT without stacking. Collapse hits make your next Graviton instant.",
		"gravity_starfall": "Requires at least 50 Meditation. After a 2s cast, spend all Meditation to deal 20 + 0.4 damage per Meditation (40–60). Interrupted casts spend nothing.",
		"collapse": "Consume your anchor: deal 22 damage within 6m and root for up to 2s. At 75+ Meditation, stun for up to 3s instead; Meditation is not spent. Hitting any enemy makes your next Graviton instant. Works through line-of-sight blockers. Control shares diminishing returns."
	}
	if concepts.has(ability.kind):
		return concepts[ability.kind]
	match ability.kind:
		"damage":
			return "Deal %s damage to an enemy." % ability.power
		"heal":
			return "Restore up to %s health to an ally or yourself." % ability.power
		"self_heal":
			return "Restore up to %s of your own health. For DPS classes, completing the cast also removes attached damage-over-time effects. Ground hazards can still hurt you." % ability.power
		"interrupt":
			return "Interrupt an enemy's cast and lock out their spells for %s seconds." % ability.power
		"control":
			return "Stun an enemy for up to %s seconds, stopping movement and casting." % ability.power
		"shield":
			return "Take 60%% less damage for %s seconds." % ability.power
		"ally_shield":
			return "An ally or you takes 60%% less damage for %s seconds." % ability.power
		"dispel":
			return "Remove a stun from an ally or yourself."
		"pull":
			return "Drag your target up to %s meters toward you. Works on an enemy or an ally." % ability.power
		"blink":
			return "Move up to %s meters in the direction you face." % ability.power
		"charge":
			return "Rush toward an enemy and deal %s damage if you reach melee range." % ability.power
		"sprint":
			return "Move 65%% faster for %s seconds." % ability.power
	return ""

static func description(ability: Dictionary, champion: String) -> String:
	var self_only: bool = ability.kind in SELF_KINDS
	var lines: Array[String] = [ability.name, "", summary(ability), ""]
	lines.append("%s  ·  Range %s" % [
		"Instant" if ability.cast <= 0 else "%ss cast" % ability.cast,
		"Self" if self_only else "%s m" % ability.range])
	lines.append("Cooldown %s  ·  Cost: see effect" % ["None" if ability.cd <= 0 else "%ss" % ability.cd])
	# Only worth a line when it is the exception: most abilities trigger the GCD.
	if ability.off:
		lines.append("Off the global cooldown.")
	if champion == "Vanguard" and ability.kind == "interrupt":
		lines.append("Vanguard ignores spell lockout.")
	return "\n".join(lines)
