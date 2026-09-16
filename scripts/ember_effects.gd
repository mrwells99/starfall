extends Node3D
## Render-only Ember compositor. Events start local clocks; snapshots describe state.
const Flame = preload("res://scripts/ability_flame.gd")
const Rules = preload("res://scripts/ember_mechanics.gd")
const FLAME_B = preload("res://assets/effects/ember/flame_02.png")
const FIRE = preload("res://assets/effects/ember/fire_01.png")
const FIREBALL = preload("res://assets/effects/ember/fireball-front.jpg")
const SMOKE = preload("res://assets/effects/ember/smoke_01.png")
const SCORCH = preload("res://assets/effects/ember/scorch_01.png")
const ASH_SHADER = preload("res://shaders/ember_ash.gdshader")
var game
var actor
var ring
var trail
var barrier
var spirit_aura
var warning
var ash_motes
var statue: Node3D
var statue_rig: Skeleton3D
var statue_material: ShaderMaterial
var ghost_material: ShaderMaterial
var body_meshes: Array[MeshInstance3D] = []
var transients: Array = []
var batches: Array = []
var ash_serial := -1
var ash_phase := 0
var phase_age := 0.0
var ash_age := 0.0
var wake_serial := -1
var route := PackedVector3Array()
var origin := Vector3.ZERO
var cached_trail := PackedVector3Array()
var warning_target := Vector3.INF
var observer_visible := true

func _init() -> void:
	name = "EmberEffects"

func batch(texture: Texture2D, count: int, size: Vector2, flat: bool = false):
	var node := Flame.new()
	add_child(node)
	node.top_level = true
	node.global_transform = Transform3D.IDENTITY
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.configure(texture,count,size,flat)
	batches.append(node)
	return node

func setup(arena, owner_actor) -> void:
	game = arena; actor = owner_actor
	ring = batch(Flame.FLAME,128,Vector2(.8,1.55))
	trail = batch(FLAME_B,288,Vector2(.85,1.2))
	barrier = batch(FLAME_B,48,Vector2(.65,1.25))
	spirit_aura = batch(Flame.FLAME,24,Vector2(.65,1.15))
	warning = batch(SCORCH,48,Vector2(1.55,1.55),true)
	ash_motes = batch(SMOKE,128,Vector2(.13,.18))
	ash_motes.material.set_shader_parameter("hot_color",Color(.43,.39,.34))
	ash_motes.material.set_shader_parameter("edge_color",Color(.055,.045,.04))
	ash_motes.material.set_shader_parameter("rise",0.0)
	for i in 8:
		transients.append({"batch":batch(FIRE,96,Vector2(1.0,1.65)),"tail":batch(Flame.FLAME,16,Vector2(.4,.65)),"age":99.0,"life":0.0,"kind":""})
	ghost_material = ShaderMaterial.new(); ghost_material.shader = ASH_SHADER
	ghost_material.set_shader_parameter("spirit",1.0)
	statue_material = ShaderMaterial.new(); statue_material.shader = ASH_SHADER
	# Retain an unanimated copy with shared meshes; no GPU readback on entering Ash.
	var art = actor.champion_model.ember_art
	statue = art.asset.instantiate()
	add_child(statue); statue.top_level = true; statue.visible = false
	statue.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for child in statue.find_children("*","Node",true,false):
		if child is AnimationPlayer: child.stop(); child.set_process(false)
		if child is Skeleton3D: statue_rig = child
		if child is MeshInstance3D:
			child.material_override = statue_material
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in art.model.find_children("*","MeshInstance3D",true,false): body_meshes.append(child)

func event(kind: String, from: Vector3, to: Vector3, path: PackedVector3Array = PackedVector3Array()) -> void:
	if kind == "ash_start":
		capture_statue(from)
		return
	if kind == "ash_return":
		route = path.duplicate(); origin = from
		return
	var entry: Dictionary = transients[0]
	for candidate in transients:
		if candidate.age >= candidate.life: entry = candidate; break
		if candidate.age > entry.age: entry = candidate
	entry.kind = kind; entry.age = 0.0
	entry.life = .45 if kind == "kindle" else (1.15 if kind == "nova" else .85)
	entry.from = from; entry.to = to
	var fx = entry.batch
	fx.intensity = 0.0; fx.target_intensity = 1.0
	fx.material.set_shader_parameter("flame_texture",FIREBALL if kind == "kindle" else FIRE)
	fx.material.set_shader_parameter("black_background",kind == "kindle")
	fx.material.set_shader_parameter("hot_color",Color(1,.98,.92) if kind == "flare_cc" else Color(1,.83,.37))
	fx.material.set_shader_parameter("edge_color",Color(1,.78,.39) if kind == "flare_cc" else Color(1,.12,.012))
	fx.particle_size = Vector2(.8,.8) if kind == "kindle" else Vector2(1.1,2.0)
	if kind == "flare_cc":
		var positions := PackedVector3Array()
		var yaw := atan2(-(to-from).x,-(to-from).z)
		for i in 48:
			var angle := yaw+lerpf(-actor.Kits.SOLAR_FLARE_HALF_ANGLE,actor.Kits.SOLAR_FLARE_HALF_ANGLE,fmod(i*.618,1.0))
			var radius: float = sqrt(float(i+1)/48.0)*actor.Kits.SOLAR_FLARE_RANGE
			positions.append(from+Vector3(-sin(angle)*radius,.7,-cos(angle)*radius))
		fx.points(positions)
	elif kind != "kindle":
		fx.ring(to,0.0,5.0 if kind == "nova" else .65,96 if kind == "nova" else 20)

func capture_statue(at: Vector3) -> void:
	origin = at; ash_age = 0.0
	var art = actor.champion_model.ember_art
	statue.global_transform = art.model.global_transform
	statue.global_position = at
	if statue_rig != null:
		for i in mini(statue_rig.get_bone_count(),art.skeleton.get_bone_count()):
			statue_rig.set_bone_pose(i,art.skeleton.get_bone_pose(i))

func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor) or not is_instance_valid(game): return
	var active: bool = actor.hp > 0 and game.phase == "match"
	var s: Dictionary = actor.identity
	var reduced: bool = game.player_options.reduced_effects
	var observer = game.actors.get(game.local_id)
	observer_visible = not Rules.hidden_from(actor,observer)
	var phase := int(s.get("ash_phase",0)) if active else 0
	if phase > 0 and int(s.get("ash_serial",0)) != ash_serial:
		ash_serial = int(s.get("ash_serial",0)); capture_statue(s.get("ash_origin",actor.position))
		ash_age = maxf(0,Rules.ASH_SECONDS-float(s.get("ash_left",Rules.ASH_SECONDS))) if phase == 1 else Rules.ASH_SECONDS
	if phase != ash_phase:
		ash_phase = phase
		phase_age = maxf(0.0, (Rules.ASH_SECONDS if phase == 1 else Rules.REFORM_SECONDS)-float(s.get("ash_left",0))) if phase > 0 else 0.0
		if phase == 2: route = s.get("ash_return",route)
	if phase == 0: ash_serial = -1
	phase_age += delta; ash_age += delta
	update_ash(phase,observer_visible,reduced)
	ring.target_intensity = 1.0 if active and float(s.get("wake",0)) > 0 else 0.0
	if ring.target_intensity == 0: wake_serial = -1
	if ring.target_intensity > 0 and int(s.get("wake_serial",0)) != wake_serial:
		wake_serial = int(s.get("wake_serial",0))
		ring.ring(s.wake_pos,Rules.WAKE_INNER+.18,Rules.WAKE_OUTER-.28,64 if reduced else 128)
	var trail_state: Array = s.get("cinder_trail",[]) if active else []
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for i in trail_state.size():
		var center: Vector3 = trail_state[i].position
		var fade := smoothstep(0.0,.35,float(trail_state[i].left))
		for side in [-1,0,1]:
			if reduced and side != 0: continue
			var along: Vector3 = (center-Vector3(trail_state[maxi(0,i-1)].position)).normalized()
			var lateral := Vector3(along.z,0,-along.x)
			points.append(center+lateral*side*.82+Vector3.UP*.5)
			colors.append(Color(1,1,1,fade))
	trail.target_intensity = 1.0 if not points.is_empty() else 0.0
	trail.points(points,colors)
	barrier.target_intensity = .7 if active and actor.shield > 0 and observer_visible and phase == 0 else 0.0
	if barrier.target_intensity > 0: barrier.ring(actor.position,.85,1.05,24 if reduced else 48)
	spirit_aura.target_intensity = .45 if active and phase == 1 and observer_visible else 0.0
	if spirit_aura.target_intensity > 0: spirit_aura.ring(actor.position,.25,.55,12 if reduced else 24)
	# Cosmetic cast clock advances between snapshots, matching Mend/regen's local fades.
	var nova: bool = active and actor.casting >= 0 and actor.kit[actor.casting].kind == "nova" and game.actors.has(actor.cast_target)
	warning.target_intensity = 0.0
	if nova:
		var progress: float = 1.0-actor.presentation_cast_left()/maxf(.001,actor.cast_duration)
		warning.target_intensity = lerpf(.12,.75,progress)
		var target: Vector3 = game.actors[actor.cast_target].position
		if target.distance_to(warning_target) > .05:
			warning_target = target; warning.ring(target+Vector3.UP*.035,0,4.5,48)
	for entry in transients:
		entry.age += delta
		var fx = entry.batch
		fx.target_intensity = 1.0 if active and entry.age < entry.life-.18 else 0.0
		entry.tail.target_intensity = fx.target_intensity if entry.kind == "kindle" else 0.0
		if entry.kind == "kindle" and entry.age < entry.life:
			var t := clampf(entry.age/.30,0,1)
			var from: Vector3 = entry.from+Vector3.UP*1.15
			var to: Vector3 = entry.to+Vector3.UP*.95
			fx.points(PackedVector3Array([from.lerp(to,t)]))
			var tail_points := PackedVector3Array()
			var tail_colors := PackedColorArray()
			for i in 16:
				tail_points.append(from.lerp(to,maxf(0,t-float(i)*.012)))
				tail_colors.append(Color(1,1,1,1.0-float(i)/16.0))
			entry.tail.points(tail_points,tail_colors)
	for fx in batches: fx.advance(delta)
	# Hard concealment wins over graceful fades: no residual aura reveals the spirit.
	if phase == 1 and not observer_visible:
		spirit_aura.visible = false; barrier.visible = false

func update_ash(phase: int, reveal: bool, reduced: bool) -> void:
	var model = actor.champion_model.ember_art.model
	model.visible = reveal or phase != 1
	for mesh in body_meshes:
		mesh.material_override = ghost_material if phase > 0 else null
	ghost_material.set_shader_parameter("opacity",.45 if phase == 1 else 1.0)
	ghost_material.set_shader_parameter("spirit",1.0 if phase == 1 else 0.0)
	ghost_material.set_shader_parameter("dissolve",1.0-smoothstep(.34,Rules.REFORM_SECONDS,phase_age) if phase == 2 else 0.0)
	statue.visible = phase > 0 and ash_age < 1.0
	statue_material.set_shader_parameter("dissolve",smoothstep(.12,.9,ash_age))
	statue_material.set_shader_parameter("fall",smoothstep(.16,.85,ash_age))
	ash_motes.target_intensity = 1.0 if phase > 0 else 0.0
	if phase == 0: return
	var points := PackedVector3Array()
	var count := 48 if reduced else 128
	for i in count:
		var seed := fmod(i*.61803399,1.0)
		var angle := i*2.399963
		var spread := Vector3(cos(angle)*seed*.6,.04+seed*.13,sin(angle)*seed*.6)
		var p := origin+spread
		if phase == 1:
			p.y += (1.0-smoothstep(.2,.9,ash_age))*seed*1.7
		else:
			var travel := clampf((phase_age-seed*.10)/.42,0,1)
			p = route_point(travel)+spread*(1.0-travel*.7)
			p.y += sin(travel*PI)*(.3+seed*.6)+smoothstep(.6,1.0,travel)*seed*1.7
		points.append(p)
	ash_motes.points(points)

func route_point(progress: float) -> Vector3:
	if route.size() < 2: return origin.lerp(actor.position,progress)
	var total := 0.0
	for i in range(1,route.size()): total += route[i-1].distance_to(route[i])
	var remaining := total*progress
	for i in range(1,route.size()):
		var length := route[i-1].distance_to(route[i])
		if remaining <= length: return route[i-1].lerp(route[i],remaining/maxf(length,.0001))
		remaining -= length
	return route[-1]
