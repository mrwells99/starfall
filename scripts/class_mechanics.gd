extends RefCounted

const INSTANT_PROC_DURATION := 4.0
const GravityAnchorEffect = preload("res://scripts/gravity_anchor_effect.gd")
const SolarFlareIndicator = preload("res://scripts/solar_flare_indicator.gd")

static func point_los(game, a: Vector3, b: Vector3) -> bool:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a + Vector3.UP, b + Vector3.UP, 1)).is_empty()

static func can_help(game, a, b) -> bool:
	if not game.world_mode or a == b:
		return true
	return not game.duels.has(a.actor_id) and not game.duels.has(b.actor_id)

static func star_count(a, id: int) -> int:
	var n := 0
	for star in a.identity.stars:
		if star.id == id:
			n += 1
	return n

static func consume_star(a, id: int) -> bool:
	for i in range(a.identity.stars.size()):
		if a.identity.stars[i].id == id:
			a.identity.stars.remove_at(i)
			return true
	return false

static func validate(game, a, spell: Dictionary, b) -> String:
	var s: Dictionary = a.identity
	var outlaw_reason: String = game.Outlaw.validate(game, a, spell, b)
	if not outlaw_reason.is_empty(): return outlaw_reason
	if spell.kind in a.Kits.ALLY_KINDS and not can_help(game, a, b):
		return "That fighter is in a duel"
	if spell.kind == "pull" and b.team == a.team and not can_help(game, a, b):
		return "That fighter is in a duel"
	if spell.kind in ["intercede", "pilgrim", "swap"] and a == b:
		return "Select another ally"
	if spell.kind == "pilgrim" and star_count(a, b.actor_id) == 0:
		return "That ally needs your Guiding Star"
	if spell.kind == "swap" and (s.hold > 0 or b.identity.hold > 0):
		return "Cannot exchange a fighter holding the line"
	if spell.kind == "swap" and (game.CC.airborne_immune(a) or game.CC.airborne_immune(b)):
		return "Cannot exchange during Backflip immunity"
	if spell.kind == "swap" and (a.test_move(a.transform, b.position - a.position) or b.test_move(b.transform, a.position - b.position)):
		return "Exchange path is blocked"
	if spell.kind == "gravity_starfall" and s.meditation < 50:
		return "Requires 50 Meditation"
	if spell.kind == "nova" and s.heat < 40:
		return "Requires 40 Heat"
	if spell.kind == "cinder" and s.heat < 20:
		return "Requires 20 Heat"
	if spell.kind == "unbroken" and s.resolve < 40:
		return "Requires 40 Resolve"
	if spell.kind in ["inward", "outward", "orbit", "collapse"]:
		if s.anchor_left <= 0:
			return "Place a Gravity Anchor first (Shift+1)"
		if a.position.distance_to(s.anchor_pos) > a.Kits.MAX_CAST_RANGE:
			return "Anchor out of range"
		if spell.kind in ["inward", "outward"] and b.position.distance_to(s.anchor_pos) > a.Kits.ANCHOR_CONTROL_RADIUS:
			return "Target out of anchor range"
	return ""

static func enemies(game, a, center: Vector3, radius: float, requires_sight: bool = true) -> Array:
	var out: Array = []
	for b in game.actors.values():
		if b.hp > 0 and b.team != a.team and game.may_harm(a, b) and center.distance_to(b.position) <= radius and (not requires_sight or point_los(game, center, b.position)):
			out.append(b)
	return out

static func heal(game, a, b, amount: float) -> void:
	if b.hp <= 0 or not can_help(game, a, b):
		return
	var dampening := 0.0 if game.world_mode else clampf((game.elapsed - 60) / 180.0, 0, 0.7)
	amount = minf(100 - b.hp, amount * (1 - dampening))
	b.hp += amount
	game.combat_event(a.actor_id, b.actor_id, "+%d" % ceili(amount), Color("97edb1"))

static func control(game, a, b, duration: float, title: String, root_only: bool = false, breaks: bool = false) -> void:
	if not game.may_harm(a, b) or b.hp <= 0 or (root_only and b.identity.immune > 0):
		return
	var category := "root" if root_only else ("incapacitate" if breaks else "stun")
	if game.CC.apply(b, category, duration, title) <= 0:
		game.combat_event(a.actor_id, b.actor_id, "IMMUNE", game.GOLD)
		return
	game.combat_event(a.actor_id, b.actor_id, title.to_upper(), game.GOLD)

static func resolve(game, a, spell: Dictionary, b) -> bool:
	var s: Dictionary = a.identity
	match spell.kind:
		"graviton":
			if not game.may_harm(a, b):
				return true
			s.instant_graviton = 0.0
			game.damage(a, b, spell.power)
			if b.hp > 0 and game.may_harm(a, b):
				var previous: Dictionary = b.identity.dots.get(a.actor_id, {})
				b.identity.dots[a.actor_id] = {"left": 11.0, "tick": previous.get("tick", 1.0), "stacks": mini(2, int(previous.get("stacks", 0)) + 1)}
		"entropy":
			if b.hp > 0 and game.may_harm(a, b):
				var previous: Dictionary = b.identity.entropy_dots.get(a.actor_id, {})
				b.identity.entropy_dots[a.actor_id] = {"left": 15.0, "tick": previous.get("tick", 1.0)}
		"gravity_starfall":
			var power: float = spell.power + s.meditation * 0.4
			s.meditation = 0.0
			for other in enemies(game, a, b.position, a.Kits.STARFALL_RADIUS):
				game.damage(a, other, power)
		"kindle":
			game.damage(a, b, spell.power)
			s.heat = minf(100, s.heat + 20)
			var brand: Dictionary = s.brands.get(b.actor_id, {"count": 0, "left": 0.0})
			s.brands[b.actor_id] = {"count": mini(3, int(brand.count) + 1), "left": 10.0}
		"flashpoint":
			var n: int = s.brands.get(b.actor_id, {}).get("count", 0)
			s.brands.erase(b.actor_id)
			game.damage(a, b, 12 + n * 6)
			s.heat = minf(100, s.heat + 10)
			if n == 3:
				for other in enemies(game, a, b.position, 5):
					if other != b:
						game.damage(a, other, 10)
		"nova":
			var power: float = 18 + s.heat * 0.4
			s.heat = 0.0
			for other in enemies(game, a, b.position, 5):
				game.damage(a, other, power)
		"stoke":
			s.heat = minf(100, s.heat + 30)
		"flare_cc", "earth":
			var radius: float = a.Kits.SOLAR_FLARE_RANGE if spell.kind == "flare_cc" else 8.0
			for other in enemies(game, a, a.position, radius):
				var offset: Vector3 = other.position - a.position
				if spell.kind == "flare_cc": offset.y = 0
				var forward: float = (-a.basis.z).dot(offset.normalized())
				var cutoff: float = cos(a.Kits.SOLAR_FLARE_HALF_ANGLE) if spell.kind == "flare_cc" else .5
				var overlaps_flare: bool = spell.kind == "flare_cc" and offset.length_squared() <= .000001
				if (not overlaps_flare and forward < cutoff - .000001) or (spell.kind == "earth" and absf(a.basis.x.dot(offset)) > 1.5):
					continue
				if spell.kind == "earth":
					game.damage(a, other, 12)
				control(game, a, other, 1 if spell.kind == "earth" else 3, spell.name, false, spell.kind == "flare_cc")
				if spell.kind == "earth" and other.stun_from == spell.name and other.stunned > 0 and other.identity.hold <= 0:
					other.velocity.y = 4.0
					other.motion_revision += 1
		"cinder", "wake":
			s.wake_pos = a.position
			if spell.kind == "cinder":
				s.heat -= 20
				game.move_ability(a, -a.basis.z * 6)
			s.wake_end = a.position
			s.wake = 5.0
			s.wake_tick = 0.0
		"sunder":
			game.damage(a, b, 13)
			s.resolve = minf(100, s.resolve + 20)
			s.exposed = b.actor_id
			s.exposed_left = 6.0
		"oath":
			var power: float = 15 + s.resolve * 0.3 + (8 if s.exposed == b.actor_id and s.exposed_left > 0 else 0)
			s.resolve = 0.0
			s.exposed_left = 0.0
			game.damage(a, b, power)
		"intercede":
			var offset: Vector3 = b.position - a.position
			game.move_ability(a, offset.normalized() * maxf(0, offset.length() - 1.8))
			s.guard = b.actor_id
			s.guard_left = 5.0
			s.guard_budget = 30.0
		"hold":
			s.hold = 4.0
		"challenge":
			s.challenge = b.actor_id
			s.challenge_left = 6.0
		"unbroken":
			s.resolve -= 40
			a.shield = maxf(a.shield, 4)
			a.shield_from = spell.name
		"star":
			if s.stars.size() >= 3:
				s.stars.pop_front()
			s.stars.append({"id": b.actor_id, "left": 30.0})
		"falling":
			heal(game, a, b, 34 if consume_star(a, b.actor_id) else 18)
		"stitch":
			heal(game, a, b, 27)
			if star_count(a, b.actor_id) > 0:
				for other in game.actors.values():
					if other != b and other.team == a.team and star_count(a, other.actor_id) > 0 and a.position.distance_to(other.position) <= a.Kits.MAX_CAST_RANGE and game.has_los(a, other):
						heal(game, a, other, 9)
						break
		"absolution":
			game.CC.clear(b, ["stun", "incapacitate", "disorient", "root"])
			b.stunned = 0.0
			b.stun_from = ""
			b.identity.root = 0.0
			b.identity.slow = 0.0
			b.identity.disorient = false
			if consume_star(a, b.actor_id):
				b.identity.immune = 3.0
		"pilgrim":
			consume_star(a, b.actor_id)
			var offset: Vector3 = b.position - a.position
			game.move_ability(a, offset.normalized() * maxf(0, offset.length() - 1.8))
		"last":
			b.identity.last = 4.0
		"starfall":
			game.damage(a, b, 16)
			for other in game.actors.values():
				if other.team == a.team and star_count(a, other.actor_id) > 0 and a.position.distance_to(other.position) <= a.Kits.MAX_CAST_RANGE and game.has_los(a, other):
					heal(game, a, other, 8 * star_count(a, other.actor_id))
		"anchor":
			# Sweep a sphere at foot height, then project onto actual ground.
			var query := PhysicsShapeQueryParameters3D.new()
			var shape := SphereShape3D.new()
			shape.radius = 0.4
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, a.position + Vector3(0, 0.5, 0))
			query.motion = -a.basis.z * 10
			query.collision_mask = 1
			var fraction: float = game.get_world_3d().direct_space_state.cast_motion(query)[0]
			var point: Vector3 = a.position + query.motion * fraction
			var floor_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 5, 1))
			if floor_hit.is_empty():
				return true
			s.anchor_pos = floor_hit.position
			s.anchor_left = 20.0
			s.orbit = 0.0
		"inward", "outward":
			if not game.may_harm(a, b):
				return true
			if spell.kind == "inward":
				s.instant_collapse = INSTANT_PROC_DURATION
			var offset: Vector3 = s.anchor_pos - b.position
			offset.y = 0
			if spell.kind == "outward":
				offset = -offset
				if offset.length() < 0.01:
					offset = -a.basis.z
			var previous_position: Vector3 = b.position
			game.move_ability(b, offset.normalized() * (8.0 if spell.kind == "outward" else minf(8, maxf(0, offset.length() - 1))))
			if b.casting >= 0 and b.position.distance_squared_to(previous_position) > .000001:
				b.casting = -1
				game.combat_event(a.actor_id, b.actor_id, "INTERRUPTED", game.GOLD)
		"orbit":
			s.orbit = 6.0
		"swap":
			var old: Vector3 = a.position
			a.position = b.position
			b.position = old
			a.motion_revision += 1
			b.motion_revision += 1
			a.reset_physics_interpolation()
			b.reset_physics_interpolation()
		"collapse":
			s.instant_collapse = 0.0
			var empowered: bool = s.meditation >= 75
			var targets := enemies(game, a, s.anchor_pos, 6, false)
			if not targets.is_empty():
				s.instant_graviton = INSTANT_PROC_DURATION
			for other in targets:
				game.damage(a, other, 22)
				control(game, a, other, 3 if empowered else 2, "Collapse", not empowered)
			s.anchor_left = 0.0
			s.orbit = 0.0
		_:
			return false
	game.combat_event(a.actor_id, b.actor_id, spell.name.to_upper(), a.Kits.color(a.champion))
	return true

static func tick(game, a, delta: float) -> void:
	var s: Dictionary = a.identity
	if a.hp <= 0:
		a.reset_identity()
		return
	# Each family is attached to the victim; both can coexist and Mend clears both.
	tick_dots(game, a, s.dots, delta, 3.0, 0.0)
	tick_dots(game, a, a.identity.entropy_dots, delta, 2.0, 5.0)
	game.Outlaw.tick(game, a, delta)
	s = a.identity
	if a.hp <= 0:
		return
	for field in ["instant_collapse", "instant_graviton", "anchor_left", "orbit", "root", "slow", "immune", "last", "hold", "guard_left", "challenge_left", "challenge_tick", "exposed_left", "wake", "wake_tick"]:
		s[field] = maxf(0, s[field] - delta)
	for id in s.brands.keys():
		s.brands[id].left -= delta
		if s.brands[id].left <= 0 or not game.actors.has(id) or game.actors[id].hp <= 0:
			s.brands.erase(id)
	for i in range(s.stars.size() - 1, -1, -1):
		s.stars[i].left -= delta
		if s.stars[i].left <= 0 or not game.actors.has(s.stars[i].id) or game.actors[s.stars[i].id].hp <= 0:
			s.stars.remove_at(i)
	if s.anchor_left > 0 and s.orbit > 0:
		for b in enemies(game, a, s.anchor_pos, a.Kits.HEAVY_ORBIT_RADIUS, false):
			if b.identity.immune <= 0 and not game.CC.airborne_immune(b):
				b.identity.slow = 0.2
	if s.wake > 0:
		var pulse: bool = s.wake_tick <= 0
		if pulse:
			s.wake_tick = 1.0
		for b in game.actors.values():
			if b.hp <= 0 or b.team == a.team or not game.may_harm(a, b):
				continue
			var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(b.position, s.wake_pos, s.wake_end)
			var radius := 5.0 if s.wake_pos == s.wake_end else 1.5
			if b.position.distance_to(nearest) <= radius and point_los(game, nearest, b.position):
				if b.identity.immune <= 0 and not game.CC.airborne_immune(b):
					b.identity.slow = 0.2
				if pulse:
					game.damage(a, b, 4)

static func tick_dots(game, a, dots: Dictionary, delta: float, tick_damage: float, meditation: float) -> void:
	for source_id in dots.keys():
		var source = game.actors.get(source_id)
		if source == null or source.hp <= 0 or not game.may_harm(source, a):
			dots.erase(source_id)
			continue
		var dot: Dictionary = dots[source_id]
		var active_delta := minf(delta, dot.left)
		dot.left -= delta
		dot.tick -= active_delta
		while dot.tick <= 0.00001 and a.hp > 0 and game.may_harm(source, a):
			dot.tick += 1.0
			source.identity.meditation = minf(100, source.identity.meditation + meditation)
			game.damage(source, a, tick_damage * int(dot.get("stacks", 1)))
		# Lethal damage can reset identity when a world duel ends.
		if a.hp <= 0 or dot.left <= 0:
			dots.erase(source_id)

static func before_damage(game, source, victim, amount: float) -> float:
	for a in game.actors.values():
		if a.training_dummy: continue
		var s: Dictionary = a.identity
		if a.hp <= 0 or a.team != victim.team:
			continue
		if s.challenge_left > 0 and s.challenge == source.actor_id and a != victim and s.challenge_tick <= 0:
			s.resolve = minf(100, s.resolve + 15)
			s.challenge_tick = 1.0
		if a != victim and s.guard_left > 0 and s.guard == victim.actor_id and s.guard_budget > 0 and a.position.distance_to(victim.position) <= a.Kits.MAX_CAST_RANGE and game.has_los(a, victim) and can_help(game, a, victim):
			var redirected: float = minf(s.guard_budget, amount * 0.3)
			s.guard_budget -= redirected
			s.resolve = minf(100, s.resolve + redirected)
			# Direct capped damage avoids recursive chains between two guardians.
			var guarded: float = redirected * damage_multiplier(source, a)
			if guarded >= a.hp and s.last > 0:
				guarded = maxf(0, a.hp - 1)
				s.last = 0.0
			a.hp = maxf(0, a.hp - guarded)
			if a.hp <= 0:
				a.casting = -1
			game.combat_event(source.actor_id, a.actor_id, "INTERCEDE −%d" % ceili(guarded), game.RED)
			amount -= redirected
			break
	return amount

static func bot(game, a, foe, ally) -> bool:
	var s: Dictionary = a.identity
	if a.champion == "Fulcrum":
		if foe.casting >= 0:
			for slot in [1, 8]:
				if game.try_spell(a.actor_id, slot, foe.actor_id):
					return true
		if not foe.identity.entropy_dots.has(a.actor_id) and game.try_spell(a.actor_id, 13, foe.actor_id):
			return true
		if s.instant_collapse > 0 and s.anchor_left > 0 and game.try_spell(a.actor_id, 11, a.actor_id):
			return true
		if s.meditation >= 50 and (foe.stunned > 0 or s.meditation >= 95):
			a.move_input = Vector2.ZERO
			if game.try_spell(a.actor_id, 12, foe.actor_id):
				return true
		if s.instant_graviton > 0 and game.try_spell(a.actor_id, 0, foe.actor_id):
			return true
		if not foe.identity.dots.has(a.actor_id):
			a.move_input = Vector2.ZERO
			if game.try_spell(a.actor_id, 0, foe.actor_id):
				return true
		if s.anchor_left <= 0:
			a.move_input = Vector2.ZERO
			return game.try_spell(a.actor_id, 7, a.actor_id)
		if foe.position.distance_to(s.anchor_pos) < 6:
			if s.orbit <= 0 and game.try_spell(a.actor_id, 9, a.actor_id):
				return true
			a.move_input = Vector2.ZERO
			return game.try_spell(a.actor_id, 11, a.actor_id)
	if a.champion == "Ember" and s.heat >= 60:
		a.move_input = Vector2.ZERO
		return game.try_spell(a.actor_id, 7, foe.actor_id)
	if a.champion == "Luminary":
		if ally.hp < 22 and game.try_spell(a.actor_id, 9, ally.actor_id):
			return true
		if star_count(a, ally.actor_id) == 0 and ally.hp > 45:
			return game.try_spell(a.actor_id, 7, ally.actor_id)
	if a.champion == "Vanguard" and ally != a and ally.hp < 45:
		return game.try_spell(a.actor_id, 7, ally.actor_id)
	return false

# Replicated state drives the same anchor and resource readouts on every peer.
static func paint(game) -> void:
	for a in game.actors.values():
		if a.training_dummy: continue
		var s: Dictionary = a.identity
		var flare_outline := a.get_node_or_null("SolarFlareOutline") as MeshInstance3D
		if a.champion == "Ember" and a.actor_id == game.local_id and flare_outline == null:
			flare_outline = SolarFlareIndicator.new()
			a.add_child(flare_outline)
		if flare_outline != null:
			# Solar Flare occupies slot 8. Its replicated cooldown starts only on
			# a successful cast, even when the cone misses every enemy.
			var just_cast: bool = a.champion == "Ember" and a.cooldowns[8] > float(a.kit[8].cd) - SolarFlareIndicator.VISIBLE_SECONDS
			flare_outline.visible = just_cast and a.actor_id == game.local_id and a.hp > 0 and game.phase == "match"
		if a.champion == "Fulcrum":
			var marker = a.get_node_or_null("GravityMarker")
			if marker == null:
				marker = GravityAnchorEffect.new()
				a.add_child(marker)
			var radius: float = a.Kits.HEAVY_ORBIT_RADIUS if s.orbit > 0 else (6.0 if a.casting >= 0 and a.kit[a.casting].kind == "collapse" else 1.0)
			var ally: bool = game.actors.has(game.local_id) and game.actors[game.local_id].team == a.team
			marker.sync(s.anchor_left, s.anchor_pos, radius, ally, a.hp > 0, game.player_options.reduced_effects)
		var wake := field_marker(a, "BurningField", Color("ff8a4c"))
		wake.visible = a.hp > 0 and s.wake > 0
		if wake.visible:
			wake.global_position = (s.wake_pos + s.wake_end) * 0.5 + Vector3.UP * 0.09
			var length: float = s.wake_pos.distance_to(s.wake_end)
			wake.scale = Vector3(5, 0.15, 5) if length < 0.01 else Vector3(1.5, 0.15, length * 0.5 + 1.5)
			if length > 0.01:
				wake.look_at(s.wake_end + Vector3.UP * 0.09, Vector3.UP)
		var nova := field_marker(a, "NovaWarning", Color("ffbb55"))
		nova.visible = a.hp > 0 and a.casting >= 0 and a.kit[a.casting].kind == "nova" and game.actors.has(a.cast_target)
		if nova.visible:
			nova.global_position = game.actors[a.cast_target].position + Vector3.UP * 0.1
			nova.scale = Vector3(5, 0.15, 5)
		var starfall := field_marker(a, "StarfallWarning", Color("bb88ff"))
		starfall.visible = a.hp > 0 and a.casting >= 0 and a.kit[a.casting].kind == "gravity_starfall" and game.actors.has(a.cast_target)
		if starfall.visible:
			starfall.global_position = game.actors[a.cast_target].position + Vector3.UP * 0.1
			starfall.scale = Vector3(a.Kits.STARFALL_RADIUS, 0.15, a.Kits.STARFALL_RADIUS)

static func field_marker(a, node_name: String, tint: Color) -> MeshInstance3D:
	var node := a.get_node_or_null(node_name) as MeshInstance3D
	if node != null:
		return node
	node = MeshInstance3D.new()
	node.name = node_name
	var ring := TorusMesh.new()
	ring.inner_radius = 0.95
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 8
	node.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.8
	node.material_override = mat
	a.add_child(node)
	node.top_level = true
	return node

static func damage_multiplier(source, victim) -> float:
	var multiplier := 0.4 if victim.shield > 0 else 1.0
	if victim.identity.hold > 0 and (-victim.basis.z).dot((source.position - victim.position).normalized()) >= 0:
		multiplier = minf(multiplier, 0.3)
	return multiplier
