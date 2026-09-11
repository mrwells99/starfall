extends RefCounted
## Independent authoritative DR tracks. Interrupt lockouts deliberately excluded.
const CATEGORIES := ["stun", "incapacitate", "disorient", "silence", "disarm", "root"]
const NAMES := ["Stun", "Incapacitated", "Disoriented", "Silence", "Disarm", "Root"]
const RESET := 18.0
const FACTORS := [1.0, 0.5, 0.25, 0.0]
const BREAK_CHANCE := 0.25
const BREAK_DAMAGE := 20.0 # 20% of the game's fixed 100 maximum HP.
static func airborne_immune(actor) -> bool:
	var lasso: Dictionary = actor.identity.get("lasso", {})
	var airborne_lasso: bool = lasso.get("air",false) and lasso.get("phase","") in ["cast","rope","pull","rebound"]
	return (actor.identity.get("backflip_active", false) or airborne_lasso) and (not actor.is_on_floor() or actor.velocity.y > .1)
static func remaining(actor, category: String) -> float:
	return float(actor.cc_effects.get(category, {}).get("remaining", 0.0))
static func apply(actor, category: String, duration: float, source: String) -> float:
	if category not in CATEGORIES or duration <= 0 or actor.hp <= 0: return 0.0
	if airborne_immune(actor): return 0.0
	if category == "silence" and actor.champion == "Vanguard": return 0.0
	if category == "disarm" and actor.champion not in ["Vanguard", "Outlaw"]: return 0.0
	if category == "root" and actor.identity.get("immune", 0) > 0: return 0.0
	var track: Dictionary = actor.dr_states.get(category, {"count": 0, "remaining": 0.0})
	var factor: float = FACTORS[mini(int(track.count), 3)]
	if factor == 0: return 0.0 # Immune attempts do not extend the reset window.
	var effective := duration * factor
	actor.cc_effects[category] = {"remaining": effective, "source": source, "damage": 0.0}
	actor.dr_states[category] = {"count": mini(int(track.count) + 1, 3), "remaining": RESET + effective}
	if category in ["stun", "incapacitate", "disorient"]: actor.stunned = 0
	sync(actor)
	if category in ["stun", "incapacitate", "disorient", "silence", "disarm"]: actor.casting = -1
	return effective
static func clear(actor, categories: Array) -> void:
	for category in categories:
		if actor.cc_effects.has(category):
			actor.cc_effects.erase(category)
			if actor.dr_states.has(category): actor.dr_states[category].remaining = RESET
	if "stun" in categories or "incapacitate" in categories or "disorient" in categories:
		actor.stunned = 0.0
		actor.stun_from = ""
		actor.identity.disorient = false
	if "root" in categories: actor.identity.root = 0.0
	sync(actor)
static func tick(actor, delta: float) -> void:
	var had_hard := false
	var had_root: bool = actor.cc_effects.has("root")
	for category in actor.cc_effects.keys():
		if category in ["stun", "incapacitate", "disorient"]: had_hard = true
		actor.cc_effects[category].remaining = maxf(0, remaining(actor, category) - delta)
		if remaining(actor, category) <= 0: actor.cc_effects.erase(category)
	for category in actor.dr_states.keys():
		var track: Dictionary = actor.dr_states[category]
		track.remaining = maxf(0, float(track.remaining) - delta)
		# A track remains diminished until 18s after its last active effect ends.
		track.remaining = maxf(track.remaining, RESET + remaining(actor, category)) if actor.cc_effects.has(category) else track.remaining
		if track.remaining <= 0: actor.dr_states.erase(category)
	if had_hard:
		actor.stunned = 0.0
		actor.stun_from = ""
		actor.identity.disorient = false
	if had_root: actor.identity.root = 0.0
	sync(actor)
static func sync(actor) -> void:
	for category in ["stun", "incapacitate", "disorient"]:
		if remaining(actor, category) > actor.stunned:
			actor.stunned = remaining(actor, category)
			actor.stun_from = actor.cc_effects[category].source
			actor.identity.disorient = category == "incapacitate"
	if actor.cc_effects.has("root"): actor.identity.root = remaining(actor, "root")
static func on_damage(actor, amount: float, roll: float = -1.0) -> void:
	if amount <= 0: return
	if actor.cc_effects.has("incapacitate"): clear(actor, ["incapacitate"])
	if actor.cc_effects.has("disorient"):
		var effect: Dictionary = actor.cc_effects.disorient
		effect.damage += amount
		var chance := randf() if roll < 0 else roll
		if effect.damage >= BREAK_DAMAGE or chance < BREAK_CHANCE: clear(actor, ["disorient"])
static func spell_block(actor) -> float:
	if airborne_immune(actor): return 0.0
	if actor.champion == "Outlaw": return maxf(remaining(actor, "disarm"), remaining(actor, "silence"))
	return remaining(actor, "disarm" if actor.champion == "Vanguard" else "silence")
static func reset(actor) -> void:
	actor.cc_effects.clear()
	actor.dr_states.clear()
