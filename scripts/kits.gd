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

static func description(ability: Dictionary, champion: String, expanded: bool) -> String:
	var brief := "%s\n%s" % [ability.name, summary(ability)]
	if not expanded:
		return brief + "\n\nHold Shift for full details."
	var self_only: bool = ability.kind in ["shield", "self_heal", "blink", "sprint"]
	var helpful: bool = ability.kind in ["heal", "ally_shield", "dispel"]
	var lines: Array[String] = [brief, ""]
	lines.append("Cast: %s  |  Cooldown: %s" % ["%ss" % ability.cast if ability.cast > 0 else "Instant", "%ss" % ability.cd if ability.cd > 0 else "None"])
	lines.append("Range: %s  |  Cost: None" % ["Self" if self_only else "%s meters" % ability.range])
	lines.append("Global cooldown: %s" % ["Bypasses it; does not trigger it." if ability.off else "Triggers 1.5 seconds when used or casting starts."])
	if self_only:
		lines.append("Target: Always yourself; your selected target is unchanged.")
	elif helpful:
		lines.append("Target: Selected living ally. With an enemy or no target selected, casts on yourself. A selected dead ally is invalid.")
		lines.append("Other allies must be in range and line of sight. Facing is not required.")
	else:
		lines.append("Target: Selected living enemy, in range and line of sight, in your forward half-circle.")
	if ability.cast > 0:
		lines.append("Stand still and stay grounded. Moving, jumping, Escape, a stun or an interrupt cancels the cast. Target checks repeat when it finishes; changing selection does not redirect it.")
		lines.append("Its own cooldown starts on completion; a cancelled cast keeps any global cooldown already triggered.")
	else:
		lines.append("Usable while moving. Its own cooldown starts immediately on use.")
	match ability.kind:
		"damage", "charge":
			lines.append("Damage is reduced by a target's ward. No critical hits, armor, damage-over-time effect or area damage.")
		"heal", "self_heal":
			lines.append("Health caps at 100. Healing reduction begins at 60s, rises by 1 percentage point every 1.8s, and caps at 70% at 186s. Cannot revive the dead.")
		"interrupt":
			lines.append("Only succeeds against an active cast. A missed interrupt still spends the cooldown. Deals no damage and does not stun. Vanguard ignores spell lockout.")
		"control":
			lines.append("Shared stun diminishing returns: %ss → %ss → %ss → immune. Resets 18s after the last successful stun ends. Damage does not break it; Dispel removes it. An immune target still costs the cooldown." % [ability.power, ability.power * 0.5, ability.power * 0.25])
		"shield", "ally_shield":
			lines.append("Reduces each damage hit; it is not an absorb shield. Reapplying refreshes duration without stacking. Does not prevent control or interrupts.")
		"dispel":
			lines.append("Removes only stun, not spell lockout, wards or other effects. Does not reset stun diminishing returns. An unstunned target still costs the cooldown. You cannot cast it while stunned yourself.")
		"blink":
			lines.append("Stops against pillars and walls; it does not pass through them or grant immunity. Travel may be shorter than its maximum distance. Does not clear stuns.")
		"sprint":
			lines.append("Increases forward, strafe and backward speed. Does not increase jump height or clear stuns. Reapplying refreshes duration without stacking.")
	if ability.kind == "charge":
		lines.append("Stops about 1.8m from the target, or earlier at geometry. Damage requires ending within 3.5m. No minimum range, stun or immunity; a blocked charge still costs the cooldown.")
	lines.append("Cannot be used while dead, stunned or already casting, even when off the global cooldown.")
	if champion != "Vanguard":
		lines.append("Available during spell lockout." if ability.kind in ["shield", "blink", "sprint"] else "Unavailable during spell lockout.")
	return "\n".join(lines)
