extends RefCounted
## Server-authoritative Null state; visibility is evaluated per observer.
const DETECT_RANGE := 3.5
const DETECT_SECONDS := .7
const COMBAT_SECONDS := 8.0
const LIFT_SECONDS := .5
const LIFT_SPEED := 10.0
const DIVE_SPEED := 25.0
const DIVE_TRAVEL_SECONDS := .4
const MAX_DIVE_SPEED := 65.0
const DIVE_ENTRY_SPEED := 4.0
const DIVE_SPEED_RESPONSE := 24.0
const DIVE_STEP := 1.0/60.0
const CONTACT := 1.0
const REGEN_SECONDS := 6.0
const Smoke = preload("res://scripts/smoke_bomb.gd")

static func initialize(a) -> void:
	a.identity.merge({"stealth":false,"stealth_serial":0,"stealth_detection":{},"combat_left":0.0,
		"null_haste":0.0,"null_vantage":{},"null_action":"","null_action_serial":0,
		"essence":0.0,"chronoshift_select":false,"chronoshift_locks":{},"chronoshift_uses":{},"null_regen":{},"smoke_bomb":{}},true)

static func stealthed(a) -> bool:
	return a != null and a.hp > 0 and a.identity.get("stealth",false)

static func detected(a, observer) -> bool:
	if observer == null or observer.hp <= 0: return false
	if deadeye_detection(a,observer): return true
	return float(a.identity.get("stealth_detection",{}).get(observer.actor_id,0.0)) >= DETECT_SECONDS and a.position.distance_to(observer.position) <= DETECT_RANGE

static func deadeye_detection(a, observer) -> bool:
	return observer != null and observer.hp > 0 and observer.team != a.team and observer.champion == "Outlaw" and observer.casting >= 0 and observer.kit[observer.casting].kind == "deadeye"

static func targetable(game, observer, a) -> bool:
	if observer == null or a == null: return false
	return not stealthed(a) or a == observer or a.team == observer.team or detected(a,observer)

static func break_stealth(game, a) -> void:
	if not a.identity.get("stealth",false): return
	a.identity.stealth = false
	a.identity.stealth_detection = {}
	# Re-engagement restores the existing duel/1v1 target lock immediately.
	for other in game.actors.values():
		var opponent: int = game.locked_target_for(other.actor_id)
		if opponent == a.actor_id: other.target_id = opponent
	if not game.dedicated: game.sync_target_lock()

static func offensive(a, spell: Dictionary) -> bool:
	if spell.kind in ["deadeye","flare_cc","wake","orbit","collapse"] or spell.get("aim_mode","")=="hitscan":return true
	return spell.kind not in a.Kits.SELF_KINDS and spell.kind not in a.Kits.ALLY_KINDS and spell.kind != "unavailable"

static func begin_ability(game, a, spell: Dictionary, b) -> void:
	if not offensive(a,spell): return
	# Blindside preserves existing stealth, without changing its combat flagging.
	if not (a.champion == "Null" and spell.kind == "blindside"):
		break_stealth(game,a)
	a.identity.combat_left = COMBAT_SECONDS
	if b != null and b != a and b.team != a.team and game.may_harm(a,b):
		b.identity.combat_left = COMBAT_SECONDS
		# A valid directed attack breaks concealment even if mitigation prevents damage.
		break_stealth(game,b)

static func direct_hit(game, a, b) -> void:
	if b == null or a.team == b.team or not game.may_harm(a,b): return
	a.identity.combat_left = COMBAT_SECONDS
	b.identity.combat_left = COMBAT_SECONDS
	break_stealth(game,a); break_stealth(game,b)

static func enter(game, a) -> void:
	a.identity.stealth = true
	a.identity.stealth_serial += 1
	a.identity.stealth_detection = {}
	for enemy in game.actors.values():
		if enemy.team == a.team or enemy == a: continue
		if deadeye_detection(a,enemy):
			a.identity.stealth_detection[enemy.actor_id] = DETECT_SECONDS
			continue
		if enemy.cast_target == a.actor_id and enemy.casting >= 0:
			game.cancel_own_cast(enemy,"Target vanished")
		if enemy.target_id == a.actor_id: enemy.target_id = -1
	if not game.dedicated:
		if game.actors.has(game.local_id) and game.actors[game.local_id].team != a.team:
			if game.selected_id == a.actor_id: game.selected_id = -1
			if game.focus_id == a.actor_id: game.focus_id = -1

static func tick(game, a, delta: float) -> void:
	Smoke.tick(a,delta)
	for field in ["combat_left","null_haste"]: a.identity[field] = maxf(0,float(a.identity.get(field,0))-delta)
	tick_regen(game,a,delta)
	var locks: Dictionary = a.identity.get("chronoshift_locks", {})
	for slot in locks.keys():
		locks[slot] = maxf(0.0, float(locks[slot]) - delta)
		if locks[slot] <= 0.0: locks.erase(slot)
	if not stealthed(a): return
	var progress: Dictionary = a.identity.stealth_detection
	for id in progress.keys():
		if not game.actors.has(id): progress.erase(id)
	for enemy in game.actors.values():
		if enemy == a or enemy.hp <= 0 or enemy.team == a.team:
			progress.erase(enemy.actor_id)
			continue
		if deadeye_detection(a,enemy):
			# Use the existing warning/visibility state, not a global stealth break.
			progress[enemy.actor_id] = DETECT_SECONDS
		elif a.position.distance_to(enemy.position) <= DETECT_RANGE and game.has_los(a,enemy):
			progress[enemy.actor_id] = minf(DETECT_SECONDS,float(progress.get(enemy.actor_id,0))+delta)
		else: progress.erase(enemy.actor_id)
		if not targetable(game,enemy,a) and enemy.target_id == a.actor_id: enemy.target_id = -1

static func tick_regen(game, a, delta: float) -> void:
	var regen: Dictionary=a.identity.get("null_regen",{})
	if regen.is_empty(): return
	if a.hp<=0:
		a.identity.null_regen={}
		return
	var elapsed:=minf(maxf(0.0,delta),float(regen.get("left",0.0)))
	regen.left=maxf(0.0,float(regen.left)-elapsed)
	regen.tick=float(regen.get("tick",0.0))+elapsed
	var healing:=0.0
	while float(regen.tick)>=1.0:
		healing+=float(regen.rate)
		regen.tick=float(regen.tick)-1.0
	# Preserve the listed total even if the simulation's final step is fractional.
	if float(regen.left)<=.00001:
		healing+=float(regen.rate)*float(regen.tick)
		regen={}
	a.identity.null_regen=regen
	if healing<=0: return
	var amount:=minf(a.MAX_HEALTH-a.hp,healing)
	if amount<=0: return
	a.hp+=amount
	game.combat_event(a.actor_id,a.actor_id,"+%d" % ceili(amount),Color("97edb1"))

static func behind(a, b) -> bool:
	var offset: Vector3 = a.position-b.position; offset.y=0
	return offset.length() > .1 and b.basis.z.dot(offset.normalized()) > .5

static func landing(game, a, b) -> Variant:
	var point: Vector3 = b.position+b.basis.z*1.2
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.2,point-Vector3.UP*2.5,1))
	if hit.is_empty() or hit.normal.y < .6: return null
	point=hit.position+Vector3.UP*.03
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=a.get_child(0).shape
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.9)
	query.collision_mask=1;query.margin=.005
	if not game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return null
	# Blink through clear space only; never place the capsule across a wall.
	if not game.ClassMechanics.point_los(game,a.position,point): return null
	return point

static func validate(game, a, spell: Dictionary, b) -> String:
	if a.champion != "Null": return ""
	if spell.kind == "stealth":
		if not stealthed(a) and float(a.identity.combat_left)>0 and not choosing_chronoshift(a): return "In combat"
	if spell.kind == "backstab" and not behind(a,b): return "Must be behind your target"
	if spell.kind in ["blindside","vantage"] and a.identity.root>0: return "Rooted"
	if spell.kind == "blindside" and landing(game,a,b)==null: return "No safe space behind target"
	if spell.kind == "chronoshift" and float(a.identity.get("essence", 0.0)) < 100.0: return "Requires 100 Essence"
	return ""

static func choosing_chronoshift(a) -> bool:
	return bool(a.identity.get("chronoshift_select", false))

static func chronoshift_candidate(a, slot: int) -> bool:
	var kind: String = a.kit[slot].kind
	return kind != "interrupt" and kind != "chronoshift" and (a.cooldowns[slot] > 0.0 or (kind == "stealth" and not stealthed(a)))

static func select_chronoshift(game, a, slot: int, requested: int = -1) -> String:
	if a.champion != "Null" or not choosing_chronoshift(a): return ""
	if slot < 0 or slot >= a.kit.size(): return "Choose an ability"
	var spell: Dictionary = a.kit[slot]
	if spell.kind == "interrupt": return "Chronoshift cannot reset Kick"
	if spell.kind != "stealth" and (spell.kind == "chronoshift" or float(spell.cd) <= 0.0): return "Choose an ability with a cooldown"
	if float(a.identity.get("chronoshift_locks", {}).get(slot, 0.0)) > 0.0: return "Chronoshift reset is not ready"
	if not chronoshift_candidate(a,slot): return "That ability is already ready"
	if float(a.identity.get("essence",0.0)) < 100.0: return "Requires 100 Essence"
	# Validate the recast before spending. Only its normal cooldown is waived;
	# target, range, GCD, control and casting restrictions still apply.
	var previous_cooldown: float = a.cooldowns[slot]
	a.cooldowns[slot] = 0.0
	var reason: String = game.ability_block_reason(a,slot,requested)
	a.cooldowns[slot] = previous_cooldown
	if not reason.is_empty(): return reason
	a.identity.essence = maxf(0.0, float(a.identity.essence) - 100.0)
	a.cooldowns[slot] = 0.0
	a.identity.chronoshift_locks[slot] = 120.0 if spell.kind == "stealth" else float(spell.cd) * 2.0
	a.identity.chronoshift_uses[slot] = true
	# Selection remains active through this request's final validation, allowing
	# only this immediate Stealth cast to bypass combat. Caller clears it.
	game.combat_event(a.actor_id, a.actor_id, "CHRONOSHIFT · %s" % spell.name, Color("b9c9d6"))
	return ""

static func grant_essence(a, spell: Dictionary, slot: int) -> void:
	if a.champion != "Null" or spell.kind not in ["stab", "backstab", "interrupt", "nerve_lock", "blindside", "vantage"]: return
	var uses: Dictionary = a.identity.get("chronoshift_uses", {})
	if uses.has(slot):
		uses.erase(slot)
		return
	a.identity.essence = minf(120.0, float(a.identity.get("essence", 0.0)) + 30.0)

static func action(a, kind: String) -> void:
	a.identity.null_action=kind; a.identity.null_action_serial+=1

static func can_cast_moving(a, spell: Dictionary) -> bool:
	return a.champion == "Null" and spell.kind == "blindside"

static func resolve(game, a, spell: Dictionary, b) -> bool:
	match spell.kind:
		"stab","backstab":
			if spell.kind == "backstab" and not behind(a,b): return true
			action(a,spell.kind); game.damage(a,b,spell.power); grant_essence(a,spell,a.kit.find(spell))
		"blindside":
			var point: Variant = landing(game,a,b)
			if point != null:
				var departure: Vector3 = a.position
				a.position=point
				var facing: Vector3 = b.position - a.position
				if Vector2(facing.x,facing.z).length_squared() > .000001:
					a.rotation.y=atan2(-facing.x,-facing.z)
				a.velocity=Vector3.ZERO
				a.motion_revision+=1; a.reset_physics_interpolation(); action(a,"blindside")
				game.outlaw_effect(a.actor_id,b.actor_id,departure,point,"blindside_smoke")
				if not game.dedicated and a.actor_id==game.local_id:
					game.local_yaw=a.rotation.y;game.pivot.rotation.y=a.rotation.y
				grant_essence(a,spell,a.kit.find(spell))
		"vantage":
			action(a,"vantage")
			a.identity.null_vantage={"phase":"lift","elapsed":0.0,"target":b.actor_id,"power":spell.power,"direction":Vector3.UP}
			a.velocity=Vector3.UP*lift_velocity(0.0); a.jump_queued=false; a.jump_buffer=0
			a.motion_revision+=1
			grant_essence(a,spell,a.kit.find(spell))
		"nerve_lock":
			action(a,"stab"); game.ClassMechanics.control(game,a,b,4,"Nerve Lock"); grant_essence(a,spell,a.kit.find(spell))
		"null_haste":
			a.identity.null_haste=6.0
		"regen_pot":
			# The pot restores 268.8 health after the owner's additional 20% reduction,
			# clears attached DoTs immediately, then delivers six one-second pulses.
			a.identity.dots.clear()
			game.Fulcrum.cleanse_entropy(game,a,a)
			if a.hp<=0: return true
			a.identity.severe_bleeds.clear()
			a.identity.null_regen={"left":REGEN_SECONDS,"tick":0.0,"rate":spell.power*a.HEALTH_SCALE*.8/REGEN_SECONDS}
		"stealth": break_stealth(game,a) if stealthed(a) else enter(game,a)
		"chronoshift": a.identity.chronoshift_select = true
		"smoke_bomb":
			Smoke.cast(a)
			game.combat_event(a.actor_id,a.actor_id,"SMOKE BOMB",Color("b9c0c7"))
		_: return false
	return true

static func busy(a) -> bool:
	return not a.identity.get("null_vantage",{}).is_empty()

static func stop(a, authoritative: bool = true) -> void:
	a.identity.null_vantage={}; a.velocity=Vector3.ZERO
	if authoritative: a.motion_revision+=1

static func lift_height(elapsed: float) -> float:
	# Integrate the easing exactly: a strong launch settles toward the dive,
	# while every tick size still covers five meters in the original half-second.
	var phase:=clampf(elapsed/LIFT_SECONDS,0.0,1.0)
	return LIFT_SPEED*LIFT_SECONDS*(1.6*phase-.6*phase*phase)

static func lift_velocity(elapsed: float) -> float:
	return LIFT_SPEED*(1.6-1.2*clampf(elapsed/LIFT_SECONDS,0.0,1.0))

static func dive_goal_speed(s: Dictionary, distance: float) -> float:
	# Keep the original range scaling, but build speed as the gap closes.
	# A retreat never rebases the profile or sends progress backwards.
	var span:=maxf(.001,float(s.get("dive_distance",distance))-CONTACT)
	var progress:=clampf(1.0-maxf(0.0,distance-CONTACT)/span,0.0,1.0)
	s.dive_progress=maxf(float(s.get("dive_progress",0.0)),progress)
	return minf(MAX_DIVE_SPEED,float(s.get("dive_speed",DIVE_SPEED))*(.75+1.35*float(s.dive_progress)*float(s.dive_progress)))

static func motion(game, a, delta: float) -> bool:
	if not busy(a): return false
	var s: Dictionary = a.identity.null_vantage
	if a.hp<=0 or a.stunned>0 or a.identity.root>0:
		stop(a,game.authoritative()); return false
	var b = game.actors.get(s.target)
	if b==null or b.hp<=0 or not game.may_harm(a,b) or not targetable(game,a,b): stop(a,game.authoritative()); return false
	a.jump_queued=false; a.jump_buffer=0
	var remaining:=maxf(0.0,delta)
	if s.phase=="lift":
		var step:=minf(remaining,LIFT_SECONDS-float(s.elapsed))
		var rise:=lift_height(float(s.elapsed)+step)-lift_height(float(s.elapsed))
		var collision=a.move_and_collide(Vector3.UP*rise)
		s.elapsed+=step; remaining-=step; a.velocity=Vector3.UP*lift_velocity(float(s.elapsed))
		if collision!=null: stop(a,game.authoritative()); return true
		if float(s.elapsed)<LIFT_SECONDS-.00001: return true
		s.phase="dive";s.elapsed=0.0
		# Snapshot the range scale once. All easing state travels with the move
		# so client reconciliation can restore and replay the same acceleration.
		s.dive_distance=a.position.distance_to(b.position)
		s.dive_speed=clampf(float(s.dive_distance)/DIVE_TRAVEL_SECONDS,DIVE_SPEED,MAX_DIVE_SPEED)
		s.dive_progress=0.0;s.dive_current_speed=DIVE_ENTRY_SPEED
		s.direction=(b.position-a.position).normalized();a.velocity=s.direction*DIVE_ENTRY_SPEED
	if s.phase=="recover":
		s.elapsed+=remaining; a.velocity=Vector3.ZERO
		if float(s.elapsed)>=.18: stop(a,game.authoritative())
		return true
	if float(s.elapsed)+remaining>2.0: stop(a,game.authoritative()); return true
	# One sweep per ordinary physics tick; subdivide unusually large deltas so
	# their proximity curve cannot skip the gentle start or tunnel through cover.
	while remaining>.000001:
		var step:=minf(remaining,DIVE_STEP)
		var offset: Vector3=b.position-a.position
		var distance:=offset.length()
		if distance>.001:
			s.direction=offset/distance
			var flat:=Vector2(offset.x,offset.z)
			if flat.length()>.05: a.rotation.y=atan2(-offset.x,-offset.z)
			var initial_speed:=clampf(float(s.get("dive_current_speed",DIVE_ENTRY_SPEED)),0.0,MAX_DIVE_SPEED)
			var goal:=dive_goal_speed(s,distance)
			var response:=1.0-exp(-DIVE_SPEED_RESPONSE*step)
			var speed:=lerpf(initial_speed,goal,response)
			# Exact integral of the speed easing for this step, not end_speed*dt.
			var travel:=minf(goal*step+(initial_speed-goal)*response/DIVE_SPEED_RESPONSE,maxf(0.0,distance-CONTACT))
			var collision=a.move_and_collide(s.direction*travel,false,.005)
			s.dive_current_speed=speed;a.velocity=s.direction*speed
			if collision!=null: stop(a,game.authoritative()); return true
		remaining-=step;s.elapsed+=step
		if a.position.distance_to(b.position)<=CONTACT+.02: break
	if a.position.distance_to(b.position)<=CONTACT+.02 and game.authoritative():
		# Contact is resolved once, on the server, after a swept capsule movement.
		s.phase="recover";s.elapsed=0.0;a.velocity=Vector3.ZERO
		if Smoke.separates(game,a,b): return true
		direct_hit(game,a,b); game.damage(a,b,float(s.power))
		if b.hp>0:
			var duration: float=game.CC.apply(b,"stun",4.0,"Vantage Point")
			if duration>0:
				b.identity.lasso_knockdown={"left":duration,"total":duration,"direction":a.basis.z,"travel":0.0,"null":true}
			game.combat_event(a.actor_id,b.actor_id,"VANTAGE POINT",Color.WHITE)
	return true
