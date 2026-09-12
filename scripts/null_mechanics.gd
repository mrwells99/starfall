extends RefCounted
## Server-authoritative Null state; visibility is evaluated per observer.
const DETECT_RANGE := 3.5
const DETECT_SECONDS := .7
const COMBAT_SECONDS := 10.0
const LIFT_SECONDS := .5
const LIFT_SPEED := 10.0
const DIVE_SPEED := 25.0
const CONTACT := 1.0

static func initialize(a) -> void:
	a.identity.merge({"stealth":false,"stealth_serial":0,"stealth_detection":{},"combat_left":0.0,
		"null_haste":0.0,"null_vantage":{},"null_action":"","null_action_serial":0},true)

static func stealthed(a) -> bool:
	return a != null and a.hp > 0 and a.identity.get("stealth",false)

static func detected(a, observer) -> bool:
	return observer != null and observer.hp > 0 and float(a.identity.get("stealth_detection",{}).get(observer.actor_id,0.0)) >= DETECT_SECONDS and a.position.distance_to(observer.position) <= DETECT_RANGE

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
		if enemy.cast_target == a.actor_id and enemy.casting >= 0:
			game.cancel_own_cast(enemy,"Target vanished")
		if enemy.target_id == a.actor_id: enemy.target_id = -1
	if not game.dedicated:
		if game.actors.has(game.local_id) and game.actors[game.local_id].team != a.team:
			if game.selected_id == a.actor_id: game.selected_id = -1
			if game.focus_id == a.actor_id: game.focus_id = -1

static func tick(game, a, delta: float) -> void:
	for field in ["combat_left","null_haste"]: a.identity[field] = maxf(0,float(a.identity.get(field,0))-delta)
	if not stealthed(a): return
	var progress: Dictionary = a.identity.stealth_detection
	for id in progress.keys():
		if not game.actors.has(id): progress.erase(id)
	for enemy in game.actors.values():
		if enemy == a or enemy.hp <= 0 or enemy.team == a.team:
			progress.erase(enemy.actor_id)
			continue
		if a.position.distance_to(enemy.position) <= DETECT_RANGE and game.has_los(a,enemy):
			progress[enemy.actor_id] = minf(DETECT_SECONDS,float(progress.get(enemy.actor_id,0))+delta)
		else: progress.erase(enemy.actor_id)
		if not targetable(game,enemy,a) and enemy.target_id == a.actor_id: enemy.target_id = -1

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
		if float(a.identity.combat_left)>0: return "In combat"
		if stealthed(a): return "Already stealthed"
	if spell.kind == "backstab" and not behind(a,b): return "Must be behind your target"
	if spell.kind in ["blindside","vantage"] and a.identity.root>0: return "Rooted"
	if spell.kind == "blindside" and landing(game,a,b)==null: return "No safe space behind target"
	if spell.kind == "vantage" and not a.is_on_floor(): return "Land before using Vantage Point"
	return ""

static func action(a, kind: String) -> void:
	a.identity.null_action=kind; a.identity.null_action_serial+=1

static func resolve(game, a, spell: Dictionary, b) -> bool:
	match spell.kind:
		"stab","backstab":
			if spell.kind == "backstab" and not behind(a,b): return true
			action(a,spell.kind); game.damage(a,b,spell.power)
		"blindside":
			var point: Variant = landing(game,a,b)
			if point != null:
				a.position=point; a.rotation.y=b.rotation.y; a.velocity=Vector3.ZERO
				a.motion_revision+=1; a.reset_physics_interpolation(); action(a,"blindside")
				if not game.dedicated and a.actor_id==game.local_id:
					game.local_yaw=a.rotation.y;game.pivot.rotation.y=a.rotation.y
		"vantage":
			action(a,"vantage")
			a.identity.null_vantage={"phase":"lift","elapsed":0.0,"target":b.actor_id,"power":spell.power,"direction":Vector3.UP}
			a.velocity=Vector3.UP*LIFT_SPEED; a.jump_queued=false; a.jump_buffer=0
			a.motion_revision+=1
		"nerve_lock":
			action(a,"stab"); game.ClassMechanics.control(game,a,b,4,"Nerve Lock")
		"null_haste":
			a.identity.null_haste=6.0
		"stealth": enter(game,a)
		_: return false
	return true

static func busy(a) -> bool:
	return not a.identity.get("null_vantage",{}).is_empty()

static func stop(a, authoritative: bool = true) -> void:
	a.identity.null_vantage={}; a.velocity=Vector3.ZERO
	if authoritative: a.motion_revision+=1

static func motion(game, a, delta: float) -> bool:
	if not busy(a): return false
	var s: Dictionary = a.identity.null_vantage
	if a.hp<=0 or a.stunned>0 or a.identity.root>0:
		stop(a,game.authoritative()); return false
	var b = game.actors.get(s.target)
	if b==null or b.hp<=0 or not game.may_harm(a,b) or not targetable(game,a,b): stop(a,game.authoritative()); return false
	a.jump_queued=false; a.jump_buffer=0
	var remaining:=delta
	if s.phase=="lift":
		var step:=minf(remaining,LIFT_SECONDS-float(s.elapsed))
		var rise:=LIFT_SPEED*step
		var collision=a.move_and_collide(Vector3.UP*rise)
		a.velocity=Vector3.UP*LIFT_SPEED; s.elapsed+=step; remaining-=step
		if collision!=null: stop(a,game.authoritative()); return true
		if float(s.elapsed)<LIFT_SECONDS-.00001: return true
		s.phase="dive";s.elapsed=0.0
	if s.phase=="recover":
		s.elapsed+=remaining; a.velocity=Vector3.ZERO
		if float(s.elapsed)>=.18: stop(a,game.authoritative())
		return true
	s.elapsed+=remaining
	if float(s.elapsed)>2.0: stop(a,game.authoritative()); return true
	var offset: Vector3=b.position-a.position
	if offset.length()>.001:
		s.direction=offset.normalized()
		var flat:=Vector2(offset.x,offset.z)
		if flat.length()>.05: a.rotation.y=atan2(-offset.x,-offset.z)
		var travel:=minf(DIVE_SPEED*remaining,maxf(0,offset.length()-CONTACT))
		var collision=a.move_and_collide(offset.normalized()*travel,false,.005)
		a.velocity=offset.normalized()*DIVE_SPEED
		if collision!=null: stop(a,game.authoritative()); return true
	if a.position.distance_to(b.position)<=CONTACT+.02 and game.authoritative():
		# Contact is resolved once, on the server, after a swept capsule movement.
		s.phase="recover";s.elapsed=0.0;a.velocity=Vector3.ZERO
		direct_hit(game,a,b); game.damage(a,b,float(s.power))
		if b.hp>0:
			var duration: float=game.CC.apply(b,"stun",4.0,"Vantage Point")
			if duration>0:
				b.identity.lasso_knockdown={"left":duration,"total":duration,"direction":a.basis.z,"travel":0.0,"null":true}
			game.combat_event(a.actor_id,b.actor_id,"VANTAGE POINT",Color.WHITE)
	return true
