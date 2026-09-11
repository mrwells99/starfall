extends RefCounted
## Server-owned Lasso combo. Prediction only advances collision-swept motion.
const CAST := .7
const ROPE_SPEED := 70.0
const PULL_SPEED := 32.0
const CONTACT := 1.05
const MIN_PULL_TIME := .12 # Allow the articulated kick to finish even at melee range.
const REBOUND_TIME := .4375 # Another 20% slower: previous 0.35s / 0.8 playback speed.
const REBOUND_DISTANCE := 2.0
const KNOCK_TIME := .18
const KNOCK_DISTANCE := 3.0
const DOWN_TIME := 1.5
const TIMEOUT := 1.1
const AIR_DRIFT_SCALE := .25
const FALL_SPEED := 1.5
const FALL_GRAVITY := 4.0
const NORMAL_GRAVITY := 20.0
const ROUTE_CLEARANCE := .03

static func pull_path(a, target: Vector3) -> PackedVector3Array:
	# Approach at the target's foot height. A diagonal root-to-root pull would
	# enter the departure floor downhill, or the terrace wall uphill.
	var away:=Vector3(a.position.x-target.x,0,a.position.z-target.z)
	away=away.normalized() if away.length()>.001 else a.basis.z
	var finish:=target+away*CONTACT+Vector3.UP*ROUTE_CLEARANCE
	var direct:=PackedVector3Array([finish])
	if clear_path(a,direct): return direct
	# Only clear the height difference; do not climb arbitrary walls or roofs.
	# Every leg sweeps the entire movement capsule, including its headroom.
	var height:=maxf(a.position.y,finish.y)+.08
	var lifted:=PackedVector3Array([Vector3(a.position.x,height,a.position.z),Vector3(finish.x,height,finish.z),finish])
	return lifted if clear_path(a,lifted) else PackedVector3Array()

static func clear_path(a, points: PackedVector3Array) -> bool:
	var previous: Vector3=a.position
	var length:=0.0
	for point in points:
		var pose: Transform3D=a.transform
		pose.origin=previous
		var movement:=point-previous
		if a.test_move(pose,movement,null,.005): return false
		length+=movement.length()
		previous=point
	return length<=PULL_SPEED*TIMEOUT

static func state(a) -> Dictionary:
	return a.identity.get("lasso", {})

static func casting(a) -> bool:
	return a.casting >= 0 and a.kit[a.casting].kind == "lasso"

static func busy(a) -> bool:
	return state(a).get("phase", "") in ["rope", "pull", "rebound"]

static func begin(a) -> void:
	a.identity.lasso = {"phase":"cast", "air": a.identity.backflip_active, "target":a.cast_target}
	if a.identity.lasso.air:
		# Save world momentum once; do not compound the slowdown each frame.
		a.identity.lasso.resume_velocity = a.velocity
		a.velocity.x *= AIR_DRIFT_SCALE
		a.velocity.z *= AIR_DRIFT_SCALE
		a.motion_revision += 1
	a.identity.lasso.revision = a.motion_revision

static func air_gravity(a, delta: float) -> bool:
	var s := state(a)
	if not s.get("air",false) or s.get("phase","") not in ["cast","rope"]: return false
	# The unslowed velocity keeps aging while suspended. Restoring an old
	# positive launch velocity after cancellation would create another jump.
	var normal: Vector3 = s.get("resume_velocity",a.velocity)
	normal.y -= NORMAL_GRAVITY * delta
	s.resume_velocity = normal
	a.velocity.y = a.velocity.y - NORMAL_GRAVITY * delta if a.velocity.y > 0 else maxf(-FALL_SPEED,a.velocity.y-FALL_GRAVITY*delta)
	return true

static func air_collisions(a) -> void:
	var s := state(a)
	if not s.has("resume_velocity") or s.get("phase","") not in ["cast","rope"]: return
	var normal: Vector3 = s.resume_velocity
	for i in a.get_slide_collision_count():
		var surface: Vector3 = a.get_slide_collision(i).get_normal()
		if normal.dot(surface) < 0: normal = normal.slide(surface)
	s.resume_velocity = normal

static func release(game, a, b) -> void:
	var previous := state(a)
	a.identity.backflip_active = false
	a.identity.backflip_combo = false
	a.identity.roll_animation_left = 0.0
	a.identity.lasso = {"phase":"rope", "target":b.actor_id, "elapsed":0.0,
		"rope":a.position + Vector3.UP * 1.2, "factor":0.0, "source":"Lasso"}
	if previous.get("air",false):
		a.identity.lasso.air = true
		a.identity.lasso.resume_velocity = previous.get("resume_velocity",a.velocity)
	else:
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
	if s.get("air",false) and s.get("phase","") in ["cast","rope"]:
		# Landing, terrain, death and a newer displacement take precedence over
		# restoring airborne momentum. Never replay a stale launch through them.
		if a.hp > 0 and (not a.is_on_floor() or a.velocity.y > .1) and a.motion_revision == int(s.get("revision",a.motion_revision)):
			a.velocity = s.get("resume_velocity",a.velocity)
			if a.stunned > 0 or a.identity.root > 0 or a.identity.hold > 0:
				a.velocity.x = 0; a.velocity.z = 0
	elif s.get("phase","") != "cast":
		a.velocity = Vector3.ZERO
	a.identity.lasso = {}
	a.motion_revision += 1

static func tick(game, a) -> void:
	var s := state(a)
	if s.is_empty(): return
	if s.phase == "cast":
		if not casting(a): cancel(game,a)
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
	a.identity.lasso = {"phase":"rebound", "elapsed":0.0, "direction":-direction, "air":s.get("air",false)}
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
		if s.get("air",false):
			if a.is_on_floor() and a.velocity.y <= 0: a.velocity = Vector3.ZERO
			air_gravity(a,delta)
			a.move_and_slide()
			air_collisions(a)
		var destination: Vector3 = b.position + Vector3.UP * 1.2
		var next: Vector3 = s.rope.move_toward(destination, ROPE_SPEED * delta)
		if not game.Outlaw.raw_los(game, s.rope, next):
			if game.authoritative(): cancel(game,a)
			return true
		s.rope = next
		if next.distance_to(destination) < .01 and game.authoritative():
			s.path=pull_path(a,b.position); s.destination=b.position
			if s.path.is_empty(): cancel(game,a); return true
			s.phase = "pull"; s.elapsed = 0.0
			var duration: float = game.CC.apply(b,"stun",TIMEOUT + DOWN_TIME,s.source)
			if duration > 0: b.cc_effects.stun.lasso_owner = a.actor_id
			s.factor = duration / (TIMEOUT + DOWN_TIME)
			a.motion_revision += 1
			s.revision = a.motion_revision
		return true
	var before: Vector3=a.position
	if game.authoritative() and (not s.has("path") or b.position.distance_to(s.get("destination",b.position))>.25):
		s.path=pull_path(a,b.position); s.destination=b.position
	var path: PackedVector3Array=s.get("path",PackedVector3Array())
	var budget:=PULL_SPEED*delta
	while budget>.0001 and a.position.distance_to(b.position)>CONTACT+.02:
		if path.is_empty():
			if game.authoritative():
				path=pull_path(a,b.position); s.destination=b.position
				if path.is_empty(): cancel(game,a); return true
			else: break
		var offset: Vector3=path[0]-a.position
		var distance: float=offset.length()
		if distance<.005: path.remove_at(0); continue
		var travel:=minf(budget,distance)
		var collision=a.move_and_collide(offset/distance*travel,false,.005)
		budget-=travel
		if collision!=null:
			# Leave a little swept clearance before ordinary movement resumes.
			a.move_and_collide(collision.get_normal()*.01)
			if game.authoritative(): cancel(game,a)
			return true
		if travel>=distance-.0001: path.remove_at(0)
	s.path=path
	a.velocity=(a.position-before)/maxf(delta,.001)
	var facing: Vector3=b.position-a.position
	if Vector2(facing.x,facing.z).length()>.001: a.rotation.y=atan2(-facing.x,-facing.z)
	if a.position.distance_to(b.position) <= CONTACT + .02:
		a.velocity = Vector3.ZERO
		if float(s.elapsed) >= MIN_PULL_TIME and game.authoritative(): impact(game,a,b,s)
	return true
