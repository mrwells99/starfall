extends RefCounted
## Gravity/dark-energy combat. All damage, combo state and displacement are server-owned.
const Kinds := ["anchor_compression", "anchor_expansion", "anchor_exchange", "anchor_field", "ruin", "divide", "gravity_flow", "entropy"]
const COMPRESSION_RADIUS := 6.0
const EXPANSION_RADIUS := COMPRESSION_RADIUS * .6
const COMPRESSION_POWER := 22.0 * .6
const COMPRESSION_STUN := 2.0 * .6
const ANCHOR_LIFETIME := 3.0
const ANCHOR_COOLDOWN := 12.0
const COMPRESSION_RESOURCE := 20.0
const FIELD_DURATION := 6.0
const FIELD_GROWTH := 1.0
const FIELD_RADIUS := 6.0
const RUIN_RANGE := 10.0
# VFX-only now: the sword swing still sweeps this arc, but the hit itself is a
# single locked tab target rather than anyone caught inside the sweep.
const RUIN_HALF_ANGLE := deg_to_rad(75.0)
const RUIN_COST := 33.0
const RUIN_SECONDS := .26
# After the second (left) slash, Ruin locks out on its own; Divide then
# inherits whatever is left of it so the two tick down on one shared clock.
const RUIN_COOLDOWN := 8.0
const DIVIDE_RANGE := 15.0
const DIVIDE_WIDTH := 3.0
const DIVIDE_SECONDS := .30
const DIVIDE_CHARGE := .3
const DIVIDE_LINGER := .65
const RIFT_DURATION := 6.0
const COVER_ALLOWANCE := 3.0
const COMBO_WINDOW := 6.0
const FLOW_DURATION := 8.0
const FLOW_SPLASH_RADIUS := 5.0
const FLOW_SPLASH_MULTIPLIER := .5
const CLEANSE_SILENCE := 3.0
const Smoke = preload("res://scripts/smoke_bomb.gd")
# Append only: indices form the compact gravity snapshot contract.
const SNAPSHOT_DEFAULT_KEYS := ["gravity_motion","gravity_slow","gravity_flow","ruin_combo","ruin_window","divide_ready","fulcrum_serial","fulcrum_action","fulcrum_action_left","fulcrum_slashes","gravity_rifts","gravity_field","anchor_kind","anchor_age","divide_yaw","divide_flow","anchor_serial","instant_graviton","instant_collapse","orbit","dots","anchor_left","anchor_pos"]

static func reset(a) -> void:
	a.identity.merge({"gravity_motion": {}, "gravity_slow": 0.0,"instant_graviton":0.0,"instant_collapse":0.0,"orbit":0.0,"dots":{},"anchor_left":0.0,"anchor_pos":Vector3.ZERO})
	if a.champion != "Fulcrum": return
	a.identity.merge({"gravity_flow": 0.0, "ruin_combo": 0, "ruin_window": 0.0, "divide_ready": 0.0,
		"fulcrum_serial": 0, "fulcrum_action": "", "fulcrum_action_left": 0.0,
		"fulcrum_slashes": [], "gravity_rifts": [], "gravity_field": {}, "anchor_kind": "", "anchor_age": 0.0,
		"divide_yaw": 0.0, "divide_flow": false, "anchor_serial": 0})

static func entropy_active(game, a) -> bool:
	for target in game.actors.values():
		if target.hp > 0 and game.may_harm(a,target) and float(target.identity.entropy_dots.get(a.actor_id,{}).get("left",0)) > 0: return true
	return false

static func cast_seconds(game, a, spell: Dictionary) -> float:
	if spell.kind == "entropy": return .8 if entropy_active(game,a) else 0.0
	if spell.kind == "divide": return 0.0 if a.identity.get("gravity_flow",0.0)>0 else DIVIDE_CHARGE
	if spell.kind == "graviton" and a.identity.instant_graviton>0: return 0.0
	if spell.kind == "collapse" and a.identity.instant_collapse>0: return 0.0
	if spell.kind == "severe" and a.identity.instant_severe>0: return 0.0
	return float(spell.cast)

static func off_gcd(a, spell: Dictionary) -> bool:
	return spell.off or (spell.kind in ["ruin","divide"] and a.identity.get("gravity_flow",0.0)>0) or (spell.kind=="collapse" and a.identity.instant_collapse>0)

static func placement(game, a, distance: float) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new(); shape.radius=.4
	query.shape=shape; query.transform=Transform3D(Basis.IDENTITY,a.position+Vector3.UP*.5)
	query.motion=-a.basis.z*distance; query.collision_mask=1
	var fraction: float = game.get_world_3d().direct_space_state.cast_motion(query)[0]
	var point: Vector3 = a.position+query.motion*fraction
	var floor_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*5,1))
	if floor_hit.is_empty() or floor_hit.normal.y < .5: return {}
	return {"point":floor_hit.position}

static func validate(game, a, spell: Dictionary) -> String:
	if spell.kind not in Kinds: return ""
	var s: Dictionary = a.identity
	if spell.kind in ["anchor_compression","anchor_expansion"] and placement(game,a,spell.range).is_empty(): return "No safe ground for anchor"
	if spell.kind in ["anchor_exchange","anchor_field"]:
		if s.anchor_left<=0: return "Place either anchor first; follow up within 3s"
		if spell.kind=="anchor_exchange":
			if a.test_move(a.transform,s.anchor_pos+Vector3.UP*.025-a.position): return "Exchange path is blocked"
	if spell.kind=="ruin":
		if s.fulcrum_action_left>0: return "Completing slash"
		if s.ruin_combo==1 and s.ruin_window>0 and s.meditation<=66: return "Left slash requires more than 66 Meditation"
		if s.meditation<RUIN_COST: return "Requires 33 Meditation"
	if spell.kind=="divide":
		if s.divide_ready<=0: return "Complete Ruin right then left to unlock Divide"
		if s.fulcrum_action_left>0: return "Completing slash"
	return ""

static func action(a, name: String, duration: float) -> void:
	a.identity.fulcrum_serial+=1
	a.identity.fulcrum_action=name
	a.identity.fulcrum_action_left=duration

static func begin(a, spell: Dictionary, yaw: Variant = null) -> void:
	if spell.kind=="divide":
		a.identity.divide_yaw=a.rotation.y if yaw==null else float(yaw)
		a.identity.divide_flow=a.identity.gravity_flow>0

static func resolve(game, a, spell: Dictionary, target = null) -> bool:
	if spell.kind not in Kinds or spell.kind=="entropy": return false
	var s: Dictionary = a.identity
	match spell.kind:
		"anchor_compression", "anchor_expansion":
			var landing := placement(game,a,spell.range)
			if landing.is_empty(): return true
			s.anchor_pos=landing.point; s.anchor_left=ANCHOR_LIFETIME; s.anchor_age=0.0; s.anchor_kind=spell.kind; s.anchor_serial+=1
			# Range variants share one cooldown for each polarity.
			for i in a.kit.size():
				if a.kit[i].kind==spell.kind: a.cooldowns[i]=ANCHOR_COOLDOWN
			var compression: bool = spell.kind=="anchor_compression"
			# Sight is judged from the caster, not the anchor: enemies() defaults to
			# checking from its center point (the anchor), which let a hidden caster
			# land a hit through an anchor the enemy could see. Skip that check here
			# and rely solely on the has_los(a, target) filter below.
			var targets: Array = game.ClassMechanics.enemies(game,a,s.anchor_pos,COMPRESSION_RADIUS if compression else EXPANSION_RADIUS,false)
			targets=targets.filter(func(target): return game.has_los(a,target))
			if compression and not targets.is_empty(): s.meditation=minf(100,s.meditation+COMPRESSION_RESOURCE)
			for b in targets:
				if not game.has_los(a,b): continue
				var direction: Vector3 = b.position-s.anchor_pos; direction.y=0
				if direction.length_squared()<.001: direction=-a.basis.z
				if not game.CC.airborne_immune(b) and b.identity.hold<=0:
					game.cancel_own_cast(b,"")
					if compression:
						game.ClassMechanics.control(game,a,b,COMPRESSION_STUN,"Anchor Compression")
						b.identity.gravity_motion={"kind":"pull","left":.2,"duration":.2,"start":b.position,"end":s.anchor_pos+direction.normalized()*.3+Vector3.UP*.025}
					else:
						b.identity.gravity_motion={"kind":"blast","left":1.0,"elapsed":0.0}
						b.velocity=direction.normalized()*15.0+Vector3.UP*7.5
					b.jump_queued=false; b.jump_buffer=0; b.motion_revision+=1
				game.damage(a,b,COMPRESSION_POWER if compression else float(spell.power))
		"anchor_exchange":
			var old: Vector3 = a.position
			a.position=s.anchor_pos+Vector3.UP*.025; s.anchor_pos=old-Vector3.UP*.025
			s.anchor_left=0.0; a.velocity=Vector3.ZERO; a.motion_revision+=1; a.reset_physics_interpolation()
		"anchor_field":
			s.gravity_field={"serial":s.anchor_serial,"position":s.anchor_pos,"left":FIELD_DURATION,"age":0.0}
			s.anchor_left=0.0
		"gravity_flow": s.gravity_flow=FLOW_DURATION
		"ruin":
			var left: bool = s.ruin_combo==1 and s.ruin_window>0
			s.meditation=maxf(0,s.meditation-RUIN_COST)
			s.ruin_combo=0 if left else 1; s.ruin_window=0.0 if left else COMBO_WINDOW
			if left:
				s.divide_ready=COMBO_WINDOW
				# Only two slashes per combo: lock Ruin out until Divide is thrown
				# (or the window lapses), instead of allowing a third slash.
				for i in a.kit.size():
					if a.kit[i].kind=="ruin": a.cooldowns[i]=RUIN_COOLDOWN
			var kind := "ruin_left" if left else "ruin_right"
			action(a,kind,RUIN_SECONDS)
			s.fulcrum_slashes.append({"serial":s.fulcrum_serial,"kind":kind,"position":a.position,"yaw":a.rotation.y,"age":0.0,"power":spell.power,"hits":[],"target_id":target.actor_id if target!=null else -1})
		"divide":
			if not a.Kits.DIVIDE_MANUAL_AIM and target!=null and target!=a:
				var offset:Vector3=target.position-a.position
				s.divide_yaw=atan2(-offset.x,-offset.z)
			s.divide_ready=0.0; s.ruin_combo=0; s.ruin_window=0.0
			# Divide clones whatever is left of Ruin's lockout onto itself, so the
			# combo's two finishers end up ticking down on one shared clock.
			var ruin_cooldown := 0.0
			for i in a.kit.size():
				if a.kit[i].kind=="ruin": ruin_cooldown=a.cooldowns[i]
			for i in a.kit.size():
				if a.kit[i].kind=="divide": a.cooldowns[i]=ruin_cooldown
			action(a,"divide",DIVIDE_SECONDS)
			s.fulcrum_slashes.append({"serial":s.fulcrum_serial,"kind":"divide","position":a.position,"yaw":s.divide_yaw,"age":0.0,"power":spell.power,"flow":s.divide_flow,"hits":[]})
	game.combat_event(a.actor_id,a.actor_id,spell.name.to_upper(),a.Kits.color(a.champion))
	return true

static func swing_progress(t: float) -> float:
	# Continuous speed: initially slow, then accelerates rapidly through mid-swing.
	return pow(clampf(t,0,1),2.3)

static func valid_enemy(game, a, b) -> bool:
	return b.hp>0 and b.team!=a.team and game.may_harm(a,b) and not Smoke.separates(game,a,b)

static func in_divide(position: Vector3, origin: Vector3, yaw: float) -> bool:
	var local: Vector3 = Basis(Vector3.UP,-yaw)*(position-origin)
	return absf(local.y)<=3.2 and local.z<=.42 and local.z>=-DIVIDE_RANGE-.42 and absf(local.x)<=DIVIDE_WIDTH*.5+.42

static func tick(game, a, delta: float) -> void:
	var s: Dictionary = a.identity
	s.gravity_slow=maxf(0,float(s.get("gravity_slow",0))-delta)
	if a.champion!="Fulcrum" or a.hp<=0: return
	for field in ["gravity_flow","ruin_window","divide_ready","fulcrum_action_left"]: s[field]=maxf(0,float(s[field])-delta)
	if s.ruin_window<=0: s.ruin_combo=0
	if s.anchor_left>0: s.anchor_age+=delta
	if not s.gravity_field.is_empty():
		var field: Dictionary = s.gravity_field
		field.left-=delta; field.age+=delta
		if field.left<=0: s.gravity_field={}
		else:
			var radius := FIELD_RADIUS*smoothstep(0,FIELD_GROWTH,float(field.age))
			for b in game.ClassMechanics.enemies(game,a,field.position,radius,false):
				if b.identity.immune<=0 and not game.CC.airborne_immune(b): b.identity.slow=.2
	for rift in s.gravity_rifts.duplicate():
		rift.left-=delta
		if rift.left<=0: s.gravity_rifts.erase(rift); continue
		for b in game.actors.values():
			if valid_enemy(game,a,b) and in_divide(b.position,rift.position,rift.yaw) and cover_allows(game,rift.position,b.position):
				if b.identity.immune<=0 and not game.CC.airborne_immune(b): b.identity.gravity_slow=.2
	for slash in s.fulcrum_slashes.duplicate():
		var previous: float = slash.age
		slash.age+=delta
		var divide: bool = slash.kind=="divide"
		var duration := DIVIDE_SECONDS if divide else RUIN_SECONDS
		if divide and previous<DIVIDE_SECONDS and slash.age>=DIVIDE_SECONDS:
			s.gravity_rifts.append({"serial":slash.serial,"position":slash.position,"yaw":slash.yaw,"left":RIFT_DURATION})
		if (divide and slash.age>=DIVIDE_SECONDS and previous<DIVIDE_SECONDS+DIVIDE_LINGER) or (not divide and previous<RUIN_SECONDS):
			for b in game.actors.values():
				if b.actor_id in slash.hits or not valid_enemy(game,a,b): continue
				# Divide is a positional line; Ruin is now a locked tab target, not
				# a cone anyone standing nearby can be caught in.
				var overlaps: bool = in_divide(b.position,slash.position,slash.yaw) if divide else b.actor_id==slash.get("target_id",-1)
				if not overlaps: continue
				if divide:
					if not cover_allows(game,slash.position,b.position): continue
				elif not game.ClassMechanics.point_los(game,slash.position,b.position): continue
				slash.hits.append(b.actor_id)
				game.damage(a,b,slash.power)
				if divide and slash.get("flow",false):
					# Gravity Flow trades Divide's old execute bonus for a blast
					# around each enemy it connects with.
					for nearby in game.ClassMechanics.enemies(game,a,b.position,FLOW_SPLASH_RADIUS):
						if nearby.actor_id==b.actor_id or nearby.actor_id in slash.hits: continue
						game.damage(a,nearby,slash.power*FLOW_SPLASH_MULTIPLIER)
		if slash.age>duration+(DIVIDE_LINGER if divide else .35): s.fulcrum_slashes.erase(slash)

static func cover_allows(game, origin: Vector3, position: Vector3) -> bool:
	# Only inspect colliders actually along this ray, avoiding a scene-wide search.
	var start := origin+Vector3.UP
	var finish := position+Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(start,finish,1)
	query.hit_from_inside=true
	var spans: Array[Vector2]=[]
	for attempt in 12:
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			spans.sort_custom(func(x,y):return x.x<y.x)
			var total:=0.0;var end:=0.0
			for span in spans: total+=maxf(0,span.y-maxf(end,span.x));end=maxf(end,span.y)
			return total*start.distance_to(finish)<=COVER_ALLOWANCE+.00001
		var body=hit.collider
		var supported:=false
		for node in body.get_children():
			if not node is CollisionShape3D or node.disabled: continue
			if not node.shape is BoxShape3D: return false
			var inverse: Transform3D=node.global_transform.affine_inverse()
			var p: Vector3=inverse*start;var d: Vector3=inverse*finish-p;var half: Vector3=node.shape.size*.5
			var low:=0.0;var high:=1.0;var entry_axis:=-1;var exit_axis:=-1
			for axis in 3:
				if absf(d[axis])<.000001:
					if absf(p[axis])>half[axis]:high=-1
				else:
					var x:=(-half[axis]-p[axis])/d[axis];var y:=(half[axis]-p[axis])/d[axis]
					if minf(x,y)>low:low=minf(x,y);entry_axis=axis
					if maxf(x,y)<high:high=maxf(x,y);exit_axis=axis
			if high>low:
				supported=true
				# Full traversals of arena-size pillars stay blocked even along their
				# 2.8m narrow face. Glancing corner cuts may spend the 3m allowance.
				if minf(node.shape.size.x,node.shape.size.z)>=2.5 and entry_axis==exit_axis: return false
				if low<=.00001: return false # Origin inside solid terrain.
				spans.append(Vector2(low,high))
		if not supported:return false
		var excluded: Array[RID]=query.exclude;excluded.append(hit.rid);query.exclude=excluded
	return false

static func motion(game, a, delta: float) -> bool:
	var state: Dictionary = a.identity.get("gravity_motion",{})
	if state.is_empty(): return false
	state.left-=delta
	a.jump_queued=false; a.jump_buffer=0
	if state.kind=="pull":
		var progress := smoothstep(0,1,1-float(state.left)/float(state.duration))
		var point: Vector3 = Vector3(state.start).lerp(state.end,progress)
		a.velocity=(point-a.position)/maxf(delta,.0001)
		a.move_and_slide()
	else:
		state.elapsed+=delta
		a.velocity.y-=20*delta; a.move_and_slide()
		if a.is_on_wall() or (a.is_on_floor() and state.elapsed>.08): state.left=0.0
	if state.left<=0:
		a.identity.gravity_motion={}
		if state.kind=="pull": a.velocity=Vector3.ZERO
	return true

static func cleanse_entropy(game, cleanser, target) -> void:
	# Only explicit removal triggers punishment; expiration/death/duel cleanup do not.
	var sources: Array = target.identity.entropy_dots.keys()
	target.identity.entropy_dots.clear()
	for id in sources:
		var source = game.actors.get(id)
		if source==null or source.hp<=0 or not game.may_harm(source,cleanser) or cleanser.hp<=0: continue
		game.CC.apply(cleanser,"silence",CLEANSE_SILENCE,"Entropy backlash")

static func bot(game, a, foe) -> bool:
	var s: Dictionary = a.identity
	if not foe.identity.entropy_dots.has(a.actor_id):
		a.move_input=Vector2.ZERO
		if game.try_spell(a.actor_id,13,foe.actor_id): return true
	if s.divide_ready>0:
		a.move_input=Vector2.ZERO
		if game.try_spell(a.actor_id,12,foe.actor_id): return true
	if s.meditation>66 and s.gravity_flow<=0 and game.try_spell(a.actor_id,15,a.actor_id): return true
	if s.meditation>=RUIN_COST and a.position.distance_to(foe.position)<=RUIN_RANGE and game.try_spell(a.actor_id,0,a.actor_id): return true
	if s.anchor_left>0 and foe.position.distance_to(s.anchor_pos)<6 and game.try_spell(a.actor_id,11,a.actor_id): return true
	var distance: float = a.position.distance_to(foe.position)
	return game.try_spell(a.actor_id,1 if distance<5 else (2 if distance<11 else 3),a.actor_id)
