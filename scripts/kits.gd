extends RefCounted

const NAMES = ["Ember", "Vanguard", "Luminary"]

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
	elif champion == "Luminary":
		kit[0] = spell("Smite", "damage", 10, 28, 1.5, 0)
		kit[1] = spell("Renewal", "heal", 18, 28, 0, 7)
		kit[2] = spell("Dispel", "dispel", 0, 28, 0, 10, true)
		kit[3] = spell("Rebuke", "control", 3, 20, 1, 18)
		kit[4] = spell("Sanctuary", "ally_shield", 5, 28, 0, 22, true)
		kit[5] = spell("Greater Heal", "heal", 27, 28, 1.8, 0)
		kit[6] = spell("Grace", "sprint", 4, 0, 0, 16, true)
	return kit

# These are player-facing explanations of the actual prototype rules, not lore.
# Numeric effects use the same kit dictionaries that the simulation reads.
static func summary(ability: Dictionary) -> String:
	match ability.kind:
		"damage":
			return "Deal %s damage to an enemy." % ability.power
		"heal":
			return "Restore up to %s health to an ally or yourself." % ability.power
		"self_heal":
			return "Restore up to %s of your own health." % ability.power
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
		"blink":
			return "Move up to %s meters in the direction you face." % ability.power
		"charge":
			return "Rush toward an enemy and deal %s damage if you reach melee range." % ability.power
		"sprint":
			return "Move 65%% faster for %s seconds." % ability.power
	return ""

static func description(ability: Dictionary, champion: String) -> String:
	var self_only: bool = ability.kind in ["shield", "self_heal", "blink", "sprint"]
	var lines: Array[String] = [ability.name, "", summary(ability), ""]
	lines.append("%s  ·  Range %s" % [
		"Instant" if ability.cast <= 0 else "%ss cast" % ability.cast,
		"Self" if self_only else "%s m" % ability.range])
	lines.append("Cooldown %s  ·  Cost None" % ["None" if ability.cd <= 0 else "%ss" % ability.cd])
	# Only worth a line when it is the exception: most abilities trigger the GCD.
	if ability.off:
		lines.append("Off the global cooldown.")
	if champion == "Vanguard" and ability.kind == "interrupt":
		lines.append("Vanguard ignores spell lockout.")
	return "\n".join(lines)
