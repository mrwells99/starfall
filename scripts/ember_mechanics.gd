extends RefCounted
## Ember gameplay is authoritative. Particle positions/frames never enter combat.
const ASH_SECONDS := 6.0
const REFORM_SECONDS := .65
const CINDER_SECONDS := 3.0
const WAKE_OUTER := 5.0
const WAKE_INNER := 3.0
const TRAIL_RADIUS := 1.5
const ROUTE_SPACING := .3
const SNAPSHOT_KEYS := ["ash_phase","ash_left","ash_serial","ash_origin","ash_yaw","ash_return","cinder_left","cinder_serial","cinder_trail","wake","wake_pos","wake_serial"]

static func spirit(a) -> bool:
	return a != null and a.hp > 0 and int(a.identity.get("ash_phase", 0)) == 1

static func busy(a) -> bool:
	return a != null and a.hp > 0 and int(a.identity.get("ash_phase", 0)) > 0

static func hidden_from(a, observer) -> bool:
	return spirit(a) and (observer == null or (a != observer and a.team != observer.team))

static func start_ash(game, a) -> void:
	var s: Dictionary = a.identity
	s.ash_serial = int(s.get("ash_serial",0)) + 1
	s.ash_phase = 1
	s.ash_left = ASH_SECONDS
	s.ash_origin = a.position
	s.ash_yaw = a.rotation.y
	s.cinder_left = 0.0
	a.ember_route = PackedVector3Array([a.position])
	a.queued_spell.clear()
	game.CC.clear(a, game.CC.CATEGORIES)
	a.identity.slow = 0.0
	a.identity.severe_slow = 0.0
	a.identity.gravity_slow = 0.0
	a.identity.crippling_verdict = 0.0
	a.motion_revision += 1
	for enemy in game.actors.values():
		if enemy.team == a.team: continue
		if enemy.cast_target == a.actor_id and enemy.casting >= 0: game.cancel_own_cast(enemy, "Target turned to ash")
		if enemy.target_id == a.actor_id: enemy.target_id = -1
	game.ember_effect(a, "ash_start", a.position, a.position)

static func recall_ash(game, a) -> void:
	if not spirit(a): return
	if a.ember_route.is_empty() or a.ember_route[-1].distance_to(a.position) > .01: a.ember_route.append(a.position)
	a.identity.ash_phase = 2
	a.identity.ash_left = REFORM_SECONDS
	a.identity.ash_return = a.ember_route.duplicate()
	a.identity.ash_destination = a.position
	a.velocity = Vector3.ZERO
	a.jump_queued = false
	a.jump_buffer = 0.0
	a.motion_revision += 1
	game.ember_effect(a, "ash_return", a.identity.ash_origin, a.position, a.ember_route)

static func resolve(game, a, spell: Dictionary, b) -> bool:
	if a.champion != "Ember": return false
	var s: Dictionary = a.identity
	match spell.kind:
		"ash": start_ash(game,a)
		"wake":
			s.wake = 5.0
			s.wake_tick = 0.0
			s.wake_pos = a.position
			s.wake_end = a.position
			s.wake_serial = int(s.get("wake_serial",0))+1
		"cinder":
			s.heat -= 20
			s.cinder_left = CINDER_SECONDS
			s.cinder_serial = int(s.get("cinder_serial",0))+1
			s.cinder_trail = [{"position":a.position,"left":5.0}]
			s.cinder_tick = 0.0
			a.motion_revision += 1
		_:
			return false
	return true

static func in_ring(point: Vector3, center: Vector3) -> bool:
	var distance := Vector2(point.x-center.x,point.z-center.z).length()
	return absf(point.y-center.y) <= 2.0 and distance >= WAKE_INNER and distance <= WAKE_OUTER

static func in_trail(point: Vector3, trail: Array) -> bool:
	for i in trail.size():
		var start: Vector3 = trail[maxi(0,i-1)].position
		var end: Vector3 = trail[i].position
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point,start,end)) <= TRAIL_RADIUS: return true
	return false

static func tick(game, a, delta: float) -> void:
	if a.champion != "Ember" or a.hp <= 0: return
	var s: Dictionary = a.identity
	if busy(a):
		s.ash_left = maxf(0,float(s.ash_left)-delta)
		if spirit(a):
			if a.ember_route.is_empty() or a.ember_route[-1].distance_to(a.position) >= ROUTE_SPACING:
				a.ember_route.append(a.position)
				# Six seconds at 1.5x speed fits below this bound, including jumping.
				if a.ember_route.size() > 256: a.ember_route.remove_at(1)
			if s.ash_left <= 0: recall_ash(game,a)
		elif s.ash_left <= 0:
			s.ash_phase = 0
			s.erase("ash_return")
			s.erase("ash_destination")
			a.ember_route.clear()
			a.motion_revision += 1
	if float(s.get("cinder_left",0)) > 0:
		s.cinder_left = maxf(0,float(s.cinder_left)-delta)
		if a.stunned > 0 or s.root > 0: s.cinder_left = 0.0
		var trail: Array = s.get("cinder_trail",[])
		if trail.is_empty() or Vector3(trail[-1].position).distance_to(a.position) >= .5:
			trail.append({"position":a.position,"left":5.0})
			if trail.size() > 96: trail.pop_front()
			s.cinder_trail = trail
	if s.has("cinder_trail"):
		var trail: Array = s.cinder_trail
		for i in range(trail.size()-1,-1,-1):
			trail[i].left -= delta
			if trail[i].left <= 0: trail.remove_at(i)
		s.cinder_tick = maxf(0,float(s.get("cinder_tick",0))-delta)
		var pulse: bool = s.cinder_tick <= 0
		if pulse: s.cinder_tick = 1.0
		for b in game.actors.values():
			if not valid_enemy(game,a,b) or not in_trail(b.position,trail): continue
			var nearest := INF
			var contact: Vector3 = a.position
			for i in trail.size():
				var p := Geometry3D.get_closest_point_to_segment(b.position,trail[maxi(0,i-1)].position,trail[i].position)
				if b.position.distance_squared_to(p) < nearest:
					nearest = b.position.distance_squared_to(p); contact = p
			if game.ClassMechanics.point_los(game,contact,b.position): apply_field(game,a,b,pulse,4.0)
	if s.wake > 0:
		var pulse: bool = s.wake_tick <= 0
		if pulse: s.wake_tick = 1.0
		for b in game.actors.values():
			if valid_enemy(game,a,b) and in_ring(b.position,s.wake_pos) and game.ClassMechanics.point_los(game,s.wake_pos,b.position):
				apply_field(game,a,b,pulse,6.0)

static func valid_enemy(game, a, b) -> bool:
	return b.hp > 0 and b.team != a.team and not spirit(b) and game.may_harm(a,b) and not game.Null.Smoke.separates(game,a,b)

static func apply_field(game, a, b, pulse: bool, power: float) -> void:
	if b.identity.immune <= 0 and not game.CC.airborne_immune(b): b.identity.slow = .2
	if pulse: game.damage(a,b,power,true)

static func snapshot_for(states: Array, observer_id: int) -> Array:
	# Conceal the actual position/velocity/route from enemy peers during spirit.
	var observer: Dictionary = {}
	for state in states:
		if state.id == observer_id: observer = state; break
	var result: Array = []
	for state in states:
		var s: Dictionary = state.get("identity",{})
		if state.has("ember"):
			s = s.duplicate()
			for index in state.ember: s[SNAPSHOT_KEYS[index]] = state.ember[index]
		if int(s.get("ash_phase",0)) != 1 or (not observer.is_empty() and state.team == observer.team):
			result.append(state); continue
		var concealed: Dictionary = state.duplicate(true)
		concealed.pos = s.ash_origin
		concealed.yaw = s.get("ash_yaw",0.0)
		concealed.velocity = Vector3.ZERO
		concealed.target = -1
		concealed.cast_target = -1
		concealed.erase("aim_stamp")
		result.append(concealed)
	return result
