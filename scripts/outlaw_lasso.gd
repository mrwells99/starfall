extends RefCounted
## Server-owned Lasso combo. Prediction only advances collision-swept motion.
const CAST := .7
const ROPE_SPEED := 70.0
const PULL_SPEED := 32.0
const CONTACT := 1.05
const MIN_PULL_TIME := .12 # Allow the articulated kick to finish even at melee range.
const REBOUND_TIME := .28
const REBOUND_DISTANCE := 2.0
const KNOCK_TIME := .18
const KNOCK_DISTANCE := 3.0
const DOWN_TIME := 1.5
const TIMEOUT := 1.1

static func state(a) -> Dictionary:
	return a.identity.get("lasso", {})

static func casting(a) -> bool:
	return a.casting >= 0 and a.kit[a.casting].kind == "lasso"

static func busy(a) -> bool:
	return state(a).get("phase", "") in ["rope", "pull", "rebound"]

static func begin(a) -> void:
	a.identity.lasso = {"phase":"cast", "air": a.identity.backflip_active, "target":a.cast_target}

static func release(game, a, b) -> void:
	a.identity.backflip_active = false
	a.identity.backflip_combo = false
	a.identity.roll_animation_left = 0.0
	a.identity.lasso = {"phase":"rope", "target":b.actor_id, "elapsed":0.0,
		"rope":a.position + Vector3.UP * 1.2, "factor":0.0, "source":"Lasso"}
	a.velocity = Vector3.ZERO
	a.motion_revision += 1
	a.identity.lasso.revision = a.motion_revision

static func release_stun(game, a, s: Dictionary) -> void:
	var b = game.actors.get(s.get("target", -1))
	if b != null and b.cc_effects.get("stun", {}).get("source", "") == s.get("source", "") and b.cc_effects.stun.get("lasso_owner",-1) == a.actor_id:
		game.CC.clear(b, ["stun"])

static func cancel(game, a) -> void:
	var s := state(a)
	if s.get("phase", "") == "pull": release_stun(game, a, s)
	a.identity.lasso = {}
	a.velocity = Vector3.ZERO
	a.motion_revision += 1

static func tick(game, a) -> void:
	var s := state(a)
	if s.is_empty(): return
	if s.phase == "cast":
		if not casting(a): a.identity.lasso = {}
		return
	if a.hp <= 0 or a.stunned > 0 or game.CC.spell_block(a) > 0 or a.identity.root > 0 or a.identity.hold > 0 or a.motion_revision != int(s.get("revision",a.motion_revision)):
		cancel(game, a)

static func knockdown_active(a) -> bool:
	var k: Dictionary = a.identity.get("lasso_knockdown", {})
	return not k.is_empty() and a.hp > 0 and a.cc_effects.get("stun", {}).get("source", "") == k.get("source", "") and a.cc_effects.stun.get("lasso_owner",-1) == k.get("owner",-1)

static func impact(game, a, b, s: Dictionary) -> void:
	var direction: Vector3 = b.position - a.position
	direction.y = 0
	direction = direction.normalized() if direction.length() > .001 else -a.basis.z
	var source: String = s.source
	# One DR application for the entire combo; never reset a dispelled stun.
	if b.cc_effects.get("stun", {}).get("source", "") == source and b.cc_effects.stun.get("lasso_owner",-1) == a.actor_id:
		var duration: float = DOWN_TIME * float(s.factor)
		b.cc_effects.stun.remaining = duration
		b.stunned = 0.0
		game.CC.sync(b)
		b.identity.lasso_knockdown = {"left":duration, "total":duration, "source":source,
			"direction":direction, "travel":KNOCK_TIME, "owner":a.actor_id}
		b.motion_revision += 1
	a.identity.defense_detonation = mini(3, a.identity.defense_detonation + 1)
	a.identity.lasso = {"phase":"rebound", "elapsed":0.0, "direction":-direction}
	a.rotation.y = atan2(-direction.x, -direction.z)
	a.motion_revision += 1
	a.identity.lasso.revision = a.motion_revision
	game.combat_event(a.actor_id, b.actor_id, "DROPKICK", Color("f2c676"))

static func motion(game, a, delta: float) -> bool:
	var k: Dictionary = a.identity.get("lasso_knockdown", {})
	if not k.is_empty():
		if not knockdown_active(a):
			a.identity.lasso_knockdown = {}
		else:
			k.left = maxf(0, float(k.left) - delta)
			var active: float = minf(delta, float(k.travel))
			k.travel = maxf(0, float(k.travel) - delta)
			if active > 0 and a.identity.hold <= 0:
				a.move_and_collide(k.direction * KNOCK_DISTANCE * active / KNOCK_TIME)
	var s := state(a)
	if not busy(a): return false
	a.jump_queued = false
	a.jump_buffer = 0
	var phase: String = s.phase
	var old_time: float = s.elapsed
	s.elapsed = old_time + delta
	if phase == "rebound":
		var old: float = minf(1, old_time / REBOUND_TIME)
		var now: float = minf(1, float(s.elapsed) / REBOUND_TIME)
		var rise := .38 * (4 * now * (1-now) - 4 * old * (1-old))
		a.move_and_collide(s.direction * REBOUND_DISTANCE * (now-old) + Vector3.UP * rise)
		a.velocity = Vector3.ZERO
		if now >= 1:
			a.identity.lasso = {}
			if game.authoritative(): a.motion_revision += 1
		return true
	var b = game.actors.get(s.target)
	if b == null or b.hp <= 0 or b.team == a.team or not game.may_harm(a,b) or float(s.elapsed) > TIMEOUT:
		if game.authoritative(): cancel(game,a)
		return true
	if phase == "rope":
		var destination: Vector3 = b.position + Vector3.UP * 1.2
		var next: Vector3 = s.rope.move_toward(destination, ROPE_SPEED * delta)
		if not game.Outlaw.raw_los(game, s.rope, next):
			if game.authoritative(): cancel(game,a)
			return true
		s.rope = next
		if next.distance_to(destination) < .01 and game.authoritative():
			s.phase = "pull"; s.elapsed = 0.0
			var duration: float = game.CC.apply(b,"stun",TIMEOUT + DOWN_TIME,s.source)
			if duration > 0: b.cc_effects.stun.lasso_owner = a.actor_id
			s.factor = duration / (TIMEOUT + DOWN_TIME)
			a.motion_revision += 1
			s.revision = a.motion_revision
		return true
	var offset: Vector3 = b.position - a.position
	var distance := offset.length()
	if distance > CONTACT:
		var before: Vector3 = a.position
		var collision = a.move_and_collide(offset.normalized() * minf(PULL_SPEED * delta, distance-CONTACT))
		a.velocity = (a.position-before) / maxf(delta,.001)
		var horizontal := Vector3(offset.x,0,offset.z)
		if horizontal.length() > .001: a.rotation.y = atan2(-offset.x,-offset.z)
		if collision != null:
			if game.authoritative(): cancel(game,a)
			return true
	if a.position.distance_to(b.position) <= CONTACT + .02:
		a.velocity = Vector3.ZERO
		if float(s.elapsed) >= MIN_PULL_TIME and game.authoritative(): impact(game,a,b,s)
	return true
