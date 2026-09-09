extends RefCounted

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
		if a.position.distance_to(s.anchor_pos) > 28:
			return "Anchor out of range"
		if spell.kind in ["inward", "outward"] and b.position.distance_to(s.anchor_pos) > 28:
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
	var factor: float = [1.0, 0.5, 0.25, 0.0][mini(b.dr_count, 3)]
	if factor <= 0:
		return
	b.dr_count += 1
	b.dr_timer = 18 + duration * factor
	if root_only:
		b.identity.root = duration * factor
	else:
		b.stunned = duration * factor
		b.stun_from = title
		b.casting = -1
		b.identity.disorient = breaks
	game.combat_event(a.actor_id, b.actor_id, title.to_upper(), game.GOLD)

static func resolve(game, a, spell: Dictionary, b) -> bool:
	var s: Dictionary = a.identity
	match spell.kind:
		"graviton":
			if not game.may_harm(a, b):
				return true
			s.instant_graviton = false
			game.damage(a, b, spell.power)
			if b.hp > 0 and game.may_harm(a, b):
				var previous: Dictionary = b.identity.dots.get(a.actor_id, {})
				b.identity.dots[a.actor_id] = {"left": 8.0, "tick": previous.get("tick", 1.0)}
		"gravity_starfall":
			var power: float = spell.power + s.meditation * 0.4
			s.meditation = 0.0
			game.damage(a, b, power)
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
			for other in enemies(game, a, a.position, 8):
				var offset: Vector3 = other.position - a.position
				var forward: float = (-a.basis.z).dot(offset.normalized())
				if forward < 0.5 or (spell.kind == "earth" and absf(a.basis.x.dot(offset)) > 1.5):
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
					if other != b and other.team == a.team and star_count(a, other.actor_id) > 0 and a.position.distance_to(other.position) <= 28 and game.has_los(a, other):
						heal(game, a, other, 9)
						break
		"absolution":
			b.stunned = 0.0
			b.stun_from = ""
			b.identity.root = 0.0
			b.identity.slow = 0.0
			b.identity.disorient = false
			b.dr_timer = minf(b.dr_timer, 18)
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
				if other.team == a.team and star_count(a, other.actor_id) > 0 and a.position.distance_to(other.position) <= 28 and game.has_los(a, other):
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
			var offset: Vector3 = s.anchor_pos - b.position
			offset.y = 0
			if spell.kind == "outward":
				offset = -offset
				if offset.length() < 0.01:
					offset = -a.basis.z
			game.move_ability(b, offset.normalized() * (8.0 if spell.kind == "outward" else minf(8, maxf(0, offset.length() - 1))))
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
			var empowered: bool = s.meditation >= 75
			var targets := enemies(game, a, s.anchor_pos, 6, false)
			if not targets.is_empty():
				s.instant_graviton = true
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
	# Attached DoTs live on their victim, so Mend removes every caster's effect.
	for source_id in s.dots.keys():
		var source = game.actors.get(source_id)
		if source == null or source.hp <= 0 or not game.may_harm(source, a):
			s.dots.erase(source_id)
			continue
		var dot: Dictionary = s.dots[source_id]
		var active_delta := minf(delta, dot.left)
		dot.left -= delta
		dot.tick -= active_delta
		while dot.tick <= 0.00001 and a.hp > 0 and game.may_harm(source, a):
			dot.tick += 1.0
			source.identity.meditation = minf(100, source.identity.meditation + 5)
			game.damage(source, a, 2.0)
		# Lethal damage can reset identity when a world duel ends.
		if a.hp <= 0 or dot.left <= 0:
			s.dots.erase(source_id)
	for field in ["anchor_left", "orbit", "root", "slow", "immune", "last", "hold", "guard_left", "challenge_left", "challenge_tick", "exposed_left", "wake", "wake_tick"]:
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
		for b in enemies(game, a, s.anchor_pos, 6, false):
			if b.identity.immune <= 0:
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
				if b.identity.immune <= 0:
					b.identity.slow = 0.2
				if pulse:
					game.damage(a, b, 4)

static func before_damage(game, source, victim, amount: float) -> float:
	if victim.identity.disorient:
		victim.stunned = 0.0
		victim.identity.disorient = false
	for a in game.actors.values():
		var s: Dictionary = a.identity
		if a.hp <= 0 or a.team != victim.team:
			continue
		if s.challenge_left > 0 and s.challenge == source.actor_id and a != victim and s.challenge_tick <= 0:
			s.resolve = minf(100, s.resolve + 15)
			s.challenge_tick = 1.0
		if a != victim and s.guard_left > 0 and s.guard == victim.actor_id and s.guard_budget > 0 and a.position.distance_to(victim.position) <= 28 and game.has_los(a, victim) and can_help(game, a, victim):
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
		if s.meditation >= 50 and (foe.stunned > 0 or s.meditation >= 95):
			a.move_input = Vector2.ZERO
			if game.try_spell(a.actor_id, 12, foe.actor_id):
				return true
		if s.instant_graviton and game.try_spell(a.actor_id, 0, foe.actor_id):
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
		var s: Dictionary = a.identity
		var marker := a.get_node_or_null("GravityMarker") as Node3D
		if marker == null:
			marker = Node3D.new()
			marker.name = "GravityMarker"
			a.add_child(marker)
			marker.top_level = true
			var mesh := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.975
			ring.outer_radius = 1.0
			mesh.mesh = ring
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("b98cff")
			mat.emission_enabled = true
			mat.emission = Color("9f60ff")
			mat.emission_energy_multiplier = 0.8
			mesh.material_override = mat
			marker.add_child(mesh)
			var label := Label3D.new()
			label.name = "Timer"
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position.y = 0.7
			label.font_size = 30
			marker.add_child(label)
		marker.visible = a.hp > 0 and s.anchor_left > 0
		if marker.visible:
			marker.global_position = s.anchor_pos + Vector3.UP * 0.08
			var radius := 6.0 if s.orbit > 0 or (a.casting >= 0 and a.kit[a.casting].kind == "collapse") else 1.0
			marker.get_child(0).scale = Vector3(radius, 0.2, radius)
			(marker.get_node("Timer") as Label3D).text = "%s ANCHOR %.1f" % ["ALLY" if game.actors.has(game.local_id) and game.actors[game.local_id].team == a.team else "ENEMY", s.anchor_left]
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
		var star_total := 0
		var brand_total := 0
		for owner in game.actors.values():
			if owner.hp > 0:
				star_total += star_count(owner, a.actor_id)
				brand_total += int(owner.identity.brands.get(a.actor_id, {}).get("count", 0))
		if star_total > 0:
			a.nameplate.text += "\n" + "✦".repeat(star_total)
		if brand_total > 0:
			a.nameplate.text += "\nBRANDS %d" % brand_total
		var resource := ""
		if a.champion == "Ember":
			resource = "HEAT %d/100" % s.heat
		elif a.champion == "Vanguard":
			resource = "RESOLVE %d/100" % s.resolve
		elif a.champion == "Fulcrum":
			resource = "MEDITATION %d/100" % s.meditation
			if s.meditation >= 75:
				resource += "\nCOLLAPSE STUN READY"
			if s.instant_graviton:
				resource += "\nINSTANT GRAVITON"
		elif a.champion == "Luminary":
			resource = "STARS %d/3" % s.stars.size()
		if not resource.is_empty():
			a.nameplate.text += "\n" + resource
		if a.actor_id == game.local_id and not resource.is_empty():
			(game.player_frame.get_child(3) as Label).text = resource

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
