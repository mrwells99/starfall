extends RefCounted
## Outlaw's authoritative combo state. Presentation never grants hits or charges.
# Travel is 30% farther at 50% higher speed, so duration scales by 1.3 / 1.5.
const ROLL_SECONDS := .55 * 1.3 / 1.5
const ROLL_DISTANCE := 6.0 * 1.3
const ROLL_ANIMATION_SPEED := .5
const ROLL_ANIMATION_SECONDS := ROLL_SECONDS / ROLL_ANIMATION_SPEED
# End on the recovered crouch; discard the source clip's stand-to-idle tail.
const ROLL_END_PHASE := .63
const ROLL_PRESENTATION_SECONDS := ROLL_ANIMATION_SECONDS * ROLL_END_PHASE
# Height is proportional to launch speed squared. Compensate the shorter
# airtime horizontally to preserve the requested increase in travel distance.
const BACKFLIP_SPEED := 12.0 * sqrt(.85 * .93)
const BACKFLIP_BACKWARD_SPEED := 3.0 * 2.0 * 1.2 / sqrt(.85 * .93)
const BACKFLIP_AIRTIME := 2.0 * BACKFLIP_SPEED / 20.0 # Matches shared movement gravity.
const COIN_SECONDS := 1.8
const COIN_SPEED := 5.0
const MAX_STACKS := 3
const DETONATION_SHOT_INTERVAL := .13
const DETONATION_HEALTH_FRACTION := .1
const SIGHT_RANGE := 18.0
const MOBILE_KINDS := ["deadeye"]
const STARSHOT_MOVE_SCALE := .7
const Lasso = preload("res://scripts/outlaw_lasso.gd")

static func can_cast_moving(actor, spell: Dictionary) -> bool:
	return actor.champion == "Outlaw" and (spell.kind in MOBILE_KINDS or spell.kind in ["severe", "starshot", "lasso"])

static func starshot_cast(actor) -> bool:
	return actor.champion == "Outlaw" and actor.casting >= 0 and actor.kit[actor.casting].kind == "starshot"

static func initialize(actor) -> void:
	actor.identity.merge({"defense_detonation": 0, "severe_bleeds": {}, "backflip_active": false,
		"lasso": {}, "lasso_knockdown": {},
		"backflip_combo": false, "backflip_elapsed": 0.0, "roll_left": 0.0, "roll_direction": Vector3.ZERO,
		"roll_distance": 0.0, "instant_severe": 0.0,
		"roll_animation_left": 0.0,
		"coin_left": 0.0, "coin_origin": Vector3.ZERO, "coin_direction": Vector3.FORWARD,
		"coin_momentum": Vector3.ZERO,
		"coin_position": Vector3.ZERO, "outlaw_channel": {}, "outlaw_action": "", "outlaw_action_serial": 0}, true)

static func backflip_airborne(a) -> bool:
	return a.identity.get("backflip_active", false) and (not a.is_on_floor() or a.velocity.y > .1)

static func mobile_cast(a) -> bool:
	return a.champion == "Outlaw" and a.casting >= 0 and a.kit[a.casting].kind in MOBILE_KINDS

static func deadeye_cast(a) -> bool:
	return mobile_cast(a) and a.kit[a.casting].kind == "deadeye"

static func unkickable(a) -> bool:
	return a.champion == "Outlaw" and a.casting >= 0 and a.kit[a.casting].kind in ["severe", "starshot", "deadeye", "lasso"]

static func detonation_burst_plan(a) -> Dictionary:
	# Snapshot all currently available stacks; never read live stacks per shot.
	var count := clampi(int(a.identity.get("defense_detonation", 0)), 0, MAX_STACKS)
	if a.champion != "Outlaw" or count == 0: return {}
	var offsets: Array[float] = []
	for shot in count: offsets.append(shot * DETONATION_SHOT_INTERVAL)
	return {"shots": count, "offsets": offsets, "health_fraction": DETONATION_HEALTH_FRACTION}

static func reserve_detonation_burst(game, a) -> Dictionary:
	# Called only after the authoritative aimed-fire request passes validation.
	# Reserve every shot together; newly earned stacks belong to the next burst.
	if not game.authoritative() or game.phase != "match": return {}
	if Lasso.busy(a): return {}
	if a.hp <= 0 or a.stunned > 0 or a.casting >= 0 or a.gcd > 0 or a.locked > 0: return {}
	if game.CC.spell_block(a) > 0 or a.identity.roll_left > 0 or a.identity.backflip_active: return {}
	var burst := detonation_burst_plan(a)
	if burst.is_empty(): return {}
	a.identity.defense_detonation = 0
	a.gcd = game.GCD_DURATION # Firing retains the original GCD; aiming has no cost.
	return burst

static func raw_los(game, from: Vector3, to: Vector3) -> bool:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()

static func trickshot_mode(game, a, b) -> String:
	if a.identity.coin_left > 0:
		var coin: Vector3 = a.identity.coin_position
		if coin.distance_to(b.position + Vector3.UP) <= SIGHT_RANGE and raw_los(game, a.position + Vector3.UP, coin) and raw_los(game, coin, b.position + Vector3.UP):
			return "coin"
	if a.identity.backflip_combo and backflip_airborne(a) and game.has_los(a, b):
		return "backflip"
	return ""

static func validate(game, a, spell: Dictionary, b) -> String:
	if a.champion != "Outlaw": return ""
	if spell.kind == "lasso":
		if a.identity.root > 0: return "Rooted"
		if not a.is_on_floor() and not backflip_airborne(a): return "Requires ground or Backflip"
	if spell.kind == "trickshot":
		if not ((a.identity.backflip_combo and backflip_airborne(a)) or a.identity.coin_left > 0):
			return "Requires Backflip or Coin Toss combo"
		if trickshot_mode(game, a, b).is_empty(): return "Combo shot is blocked by terrain"
	if spell.kind in ["roll", "deadeye"] and not a.is_on_floor():
		return "Land before using " + spell.name
	return ""

static func action(a, name: String) -> void:
	a.identity.outlaw_action = name
	a.identity.outlaw_action_serial += 1

static func begin_channel(game, a, spell: Dictionary, target: int) -> void:
	if spell.kind == "lasso":
		Lasso.begin(a)
		return
	if spell.kind not in MOBILE_KINDS: return
	var marked: Array = []
	# Deadeye acquires all eligible opponents; visibility is checked at completion.
	for enemy in game.actors.values():
		if enemy.hp > 0 and enemy.team != a.team and game.may_harm(a, enemy): marked.append(enemy.actor_id)
	a.identity.outlaw_channel = {"kind": spell.kind, "slot": a.casting, "target": target, "marked": marked}
	# Reserve the cooldown now; an unfinished cast refunds it during cleanup.
	a.cooldowns[a.casting] = spell.cd
	action(a, "aim")

static func refund_interrupted_channel(game, a) -> void:
	if not game.authoritative(): return
	var channel: Dictionary = a.identity.get("outlaw_channel", {})
	if channel.get("kind", "") == "deadeye" and not channel.get("completed", false):
		var slot: int = int(channel.get("slot", -1))
		if slot >= 0 and slot < a.kit.size() and a.kit[slot].kind == "deadeye":
			a.cooldowns[slot] = 0.0
	channel.clear()

static func hit(game, a, b, damage: float, from: Vector3, tag: String) -> void:
	game.damage(a, b, roundf(damage))
	action(a, "gun" if tag == "ricochet_hit" else tag)
	game.outlaw_effect(a.actor_id, b.actor_id, from, b.position + Vector3.UP, tag)

static func tick_channel(game, a, delta: float) -> void:
	if not mobile_cast(a):
		refund_interrupted_channel(game, a)
		return
	var channel: Dictionary = a.identity.outlaw_channel
	if channel.is_empty():
		a.casting = -1
		return
	a.cast_left = maxf(0, a.cast_left - delta)
	if a.cast_left <= 0:
		# Finishing counts even if every marked enemy escapes sight or range.
		channel.completed = true
		for id in channel.marked:
			var target = game.actors.get(id)
			if target != null and target.hp > 0 and target.team != a.team and game.may_harm(a, target) and a.position.distance_to(target.position) <= SIGHT_RANGE and game.has_los(a, target):
				hit(game, a, target, target.MAX_HEALTH * .4, a.position + Vector3.UP, "gun")
	if a.cast_left <= 0:
		a.casting = -1
		a.identity.outlaw_channel.clear()

static func resolve(game, a, spell: Dictionary, b, camera_yaw: Variant = null) -> bool:
	if a.champion != "Outlaw": return false
	match spell.kind:
		"lasso": Lasso.release(game, a, b)
		"starshot": hit(game, a, b, spell.power, a.position + Vector3.UP, "gun")
		"severe":
			a.identity.instant_severe = 0.0
			hit(game, a, b, b.hp * .15, a.position + Vector3.UP, "knife")
			if b.hp > 0 and game.may_harm(a, b):
				var previous: Dictionary = b.identity.severe_bleeds.get(a.actor_id, {})
				b.identity.severe_bleeds[a.actor_id] = {"left": 5.0, "tick": previous.get("tick", 1.0)}
		"roll":
			a.identity.roll_left = ROLL_SECONDS
			a.identity.roll_animation_left = ROLL_PRESENTATION_SECONDS
			a.identity.roll_distance = 0.0
			a.identity.roll_direction = game.BlinkCharges.direction(a, camera_yaw)
			a.motion_revision += 1
			action(a, "roll")
		"backflip":
			a.identity.backflip_active = true
			a.identity.backflip_combo = true
			a.identity.backflip_elapsed = 0.0
			var backward: Vector3 = a.basis.z * BACKFLIP_BACKWARD_SPEED
			a.velocity = Vector3(backward.x, BACKFLIP_SPEED, backward.z)
			# Leave cached ground contact before the next normal movement sample.
			a.move_and_collide(Vector3.UP * .04)
			a.motion_revision += 1
			action(a, "backflip")
		"coin_toss":
			a.identity.coin_left = COIN_SECONDS
			a.identity.coin_origin = a.position + Vector3.UP * 1.15
			a.identity.coin_position = a.identity.coin_origin
			var yaw: float = a.rotation.y if camera_yaw == null else float(camera_yaw)
			a.identity.coin_direction = Basis(Vector3.UP, yaw) * Vector3.FORWARD
			# Inherit world velocity once at release, including airborne momentum.
			# Later movement or camera turns cannot steer a coin already in flight.
			a.identity.coin_momentum = a.velocity
			action(a, "coin")
		"trickshot":
			var mode := trickshot_mode(game, a, b)
			if mode.is_empty(): return true
			var from: Vector3 = a.position + Vector3.UP
			if mode == "coin":
				from = a.identity.coin_position
				game.outlaw_effect(a.actor_id, a.actor_id, a.position + Vector3.UP, from, "ricochet")
				a.identity.coin_left = 0.0
			else: a.identity.backflip_combo = false
			var before: float = b.hp
			hit(game, a, b, spell.power, from, "ricochet_hit" if mode == "coin" else "gun")
			if b.hp < before or b.training_dummy:
				a.identity.defense_detonation = mini(MAX_STACKS, a.identity.defense_detonation + 1)
		_:
			return false
	return true

static func tick(game, a, delta: float) -> void:
	game.ClassMechanics.tick_dots(game, a, a.identity.severe_bleeds, delta, 2, 0)
	if a.champion != "Outlaw": return
	# Covers CC, forced movement, manual cancel and death without depending on
	# which system cleared casting. Runs before the dead-actor early return.
	if not mobile_cast(a) or a.hp <= 0: refund_interrupted_channel(game, a)
	if a.hp <= 0: return
	# Cosmetic recovery only: never delays movement, casts or the instant buff.
	a.identity.roll_animation_left = maxf(0, a.identity.get("roll_animation_left", 0.0) - delta)
	if a.identity.roll_left <= 0 and (a.casting >= 0 or a.stunned > 0 or a.identity.backflip_active or a.identity.outlaw_action != "roll"):
		a.identity.roll_animation_left = 0.0
	a.identity.instant_severe = maxf(0, a.identity.instant_severe - delta)
	if a.identity.backflip_active:
		a.identity.backflip_elapsed += delta
		if a.is_on_floor() and a.velocity.y <= 0:
			a.identity.backflip_active = false
			a.identity.backflip_combo = false
	if a.identity.coin_left > 0:
		var previous: Vector3 = a.identity.coin_position
		a.identity.coin_left = maxf(0, a.identity.coin_left - delta)
		var t: float = COIN_SECONDS - a.identity.coin_left
		var launch_velocity: Vector3 = a.identity.coin_direction * COIN_SPEED + a.identity.get("coin_momentum", Vector3.ZERO)
		var next: Vector3 = a.identity.coin_origin + launch_velocity * t + Vector3.UP * (5.4 * t - 3.0 * t * t)
		if not raw_los(game, previous, next): a.identity.coin_left = 0.0
		else: a.identity.coin_position = next

static func roll_motion(game, a, delta: float) -> bool:
	if a.identity.get("roll_left", 0.0) <= 0: return false
	if a.stunned > 0 or a.identity.root > 0 or a.identity.hold > 0:
		a.identity.roll_left = 0.0
		a.identity.roll_animation_left = 0.0
		return false
	var active: float = minf(delta, a.identity.roll_left)
	var distance: float = ROLL_DISTANCE / ROLL_SECONDS * active
	var before: Vector3 = a.position
	var collision = a.move_and_collide(a.identity.roll_direction * distance)
	a.identity.roll_distance += a.position.distance_to(before)
	a.identity.roll_left = maxf(0, a.identity.roll_left - delta)
	if a.identity.roll_left < .00001: a.identity.roll_left = 0.0
	if collision != null:
		a.identity.roll_left = 0.0
		a.identity.roll_animation_left = 0.0
	if a.identity.roll_left <= 0 and a.identity.roll_distance > .01 and game.authoritative():
		a.identity.instant_severe = 1.5
	a.velocity.x = 0; a.velocity.z = 0
	a.velocity.y -= 20 * delta
	a.move_and_slide()
	a.jump_queued = false; a.jump_buffer = 0
	return true

static func bot(game, a, foe) -> bool:
	if (a.identity.backflip_combo or a.identity.coin_left > 0) and game.try_spell(a.actor_id, 2, foe.actor_id): return true
	if a.position.distance_to(foe.position) < 3 and game.try_spell(a.actor_id, 1, foe.actor_id): return true
	if a.cooldowns[7] <= 0 and game.try_spell(a.actor_id, 7, -1): return true
	if a.cooldowns[3] <= 0 and a.is_on_floor() and game.try_spell(a.actor_id, 3, -1): return true
	if game.try_spell(a.actor_id, 9, -1): return true
	if game.has_los(a, foe) and a.position.distance_to(foe.position) <= SIGHT_RANGE:
		a.move_input = Vector2.ZERO
	return game.try_spell(a.actor_id, 0, foe.actor_id)
