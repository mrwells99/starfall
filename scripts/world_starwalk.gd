extends Node3D
## World-only traversal. Static collision is identical on clients and servers;
## only the authority handles gates, progress and rescue teleports.
const Geometry = preload("res://scripts/arena_geometry.gd")
# Flat landing at the top of the eastern terrace stairs.
const ENTRY := Vector3(15, 1.2, 4.5)
const HOME := Vector3(0, 0.15, 0)
const START := Vector3(42, 12, 0)
const FALL_Y := -6.0
const COUNT := 72
const STAGE_LENGTH := 24
const RISES := [0.72, 0.90, 0.82, 0.95, 0.65, 0.88]
const STAGE_NAMES := ["THE SHATTERED WAKE", "THE GRAVITY WELL", "THE CROWN OF STARS"]
const ENTRY_WAIT := 8.0
var game
var progress: Dictionary = {}
var entry_waits: Dictionary = {}

static func platform_position(index: int) -> Vector3:
	# A rising, breathing spiral: over two full turns and 59m of ascent.
	# Every rise stays below the existing jump apex; narrow landings demand
	# deliberate takeoff placement with the unchanged airborne momentum.
	var angle := PI + index * 0.20
	var radius := 18.0 - index * 0.055 + sin(index * 0.42) * 1.1
	var cycles: int = index / RISES.size()
	var height := 12.0 + cycles * 4.92
	for i in range(index % RISES.size()): height += RISES[i]
	return Vector3(60.0 + cos(angle) * radius, height, sin(angle) * radius)

static func platform_size(index: int) -> Vector3:
	if index == COUNT: return Vector3(3.6, 0.7, 3.6)
	if index % STAGE_LENGTH == 0: return Vector3(4.6, 0.7, 4.6)
	if index < 24:
		return Vector3(2.0 if index % 3 == 0 else 1.8, 0.7, 1.8)
	if index < 48:
		return Vector3(1.5, 0.7, 2.0) if index % 2 == 0 else Vector3(2.0, 0.7, 1.5)
	return Vector3(1.5, 0.7, 1.5)

func build(owner_game) -> void:
	game = owner_game
	for i in range(COUNT + 1):
		var body := StaticBody3D.new()
		body.name = "Landing%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = platform_position(i) - Vector3.UP * 0.35
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = platform_size(i)
		collider.shape = box
		body.add_child(collider)
		add_child(body)
	if DisplayServer.get_name() != "headless":
		build_art()

func build_art() -> void:
	var geo = Geometry.new()
	var stone = game._rock_material("39344f", 1.0, 2)
	var trim = game._rock_material("a58a68", 1.0, 3)
	var cyan = game._energy("4fe4ff", 1.7)
	var violet = game._energy("d36bff", 1.5)
	var gold = game._energy("ffca70", 1.8)
	var palette := [cyan, violet, gold]
	for glow_material in palette:
		glow_material.set_shader_parameter("emission_gain", 1.4)
	for i in range(COUNT + 1):
		var p := platform_position(i)
		var size := platform_size(i)
		var glow = palette[mini(i / STAGE_LENGTH, 2)]
		geo.block(stone, p - Vector3.UP * 0.35, size)
		# Exact collision rims make narrow landings readable against the spectacle.
		for side in [-1.0, 1.0]:
			geo.block(glow, p + Vector3(side * (size.x / 2 - 0.05), 0.015, 0), Vector3(0.065, 0.035, size.z))
			geo.block(glow, p + Vector3(0, 0.015, side * (size.z / 2 - 0.05)), Vector3(size.x, 0.035, 0.065))
		geo.ring(trim, p + Vector3.UP * 0.025, 0.40, 0.045)
		geo.rock(stone, p - Vector3.UP * 2.8, Vector3(size.x * 0.75, 2.1, size.z * 0.75), i * 0.7)
		geo.rock(glow, p - Vector3.UP * 1.85, Vector3(0.20, 0.9, 0.20), 0, Color.WHITE, 5)
		if i < COUNT:
			var direction := platform_position(i + 1) - p
			direction.y = 0
			direction = direction.normalized()
			var tangent := Vector3(-direction.z, 0, direction.x)
			var tip := p + Vector3.UP * 0.04 + direction * 0.35
			var arrow: Array[Vector3] = [tip - direction * 0.40 + tangent * 0.20, tip, tip - direction * 0.40 - tangent * 0.20]
			geo.ribbon(glow, arrow, 0.055)
		if i > 0 and i % 4 == 0:
			label_at("%02d" % i, p + Vector3(0, 0.05, 0.5), 22, Color("dcceff"), true)
		if i % STAGE_LENGTH == 0:
			geo.ring(glow, p + Vector3.UP * 0.03, 1.45 if i == COUNT else 1.9, 0.07)
	gate(geo, ENTRY, cyan, trim)
	gate(geo, platform_position(COUNT), gold, trim)
	geo.ring(cyan, HOME - Vector3.UP * 0.11, 1.5, 0.04)
	geo.finish(self)
	label_at("S T A R W A L K  /  A S C E N S I O N", ENTRY + Vector3(0, 4.0, 0), 32, Color("92eeff"))
	label_at("Stand in the ring for 8 seconds\n72 jumps · 59m climb · Falls return to the center", ENTRY + Vector3(0, 3.25, 0), 22, Color("ded6f5"))
	var colors := [Color("92eeff"), Color("e7a4ff"), Color("ffda9c")]
	for stage in range(3):
		var p := platform_position(stage * STAGE_LENGTH)
		var outward := Vector3(p.x - 60, 0, p.z).normalized()
		var sign_position := p + outward * 4.6
		label_at("%02d / %s" % [stage + 1, STAGE_NAMES[stage]], sign_position + Vector3.UP * 3.4, 25, colors[stage])
		var caption: String = ["Aim your takeoff · Carry your momentum", "Narrow ledges · Find your footing", "The final ascent · Every landing counts"][stage]
		label_at(caption, sign_position + Vector3.UP * 2.9, 18, Color("ded6f5"))
	label_at("YOU WALKED THE STARS", platform_position(COUNT) + Vector3(0, 4, 0), 36, Color("ffe2af"))
	label_at("72 / 72 · Enter the gold ring to return", platform_position(COUNT) + Vector3(0, 3.3, 0), 23, Color("ded6f5"))
	var scenery = load("res://scripts/world_starwalk_scenery.gd").new()
	scenery.name = "AscensionScenery"
	add_child(scenery)
	scenery.build(self)

func gate(geo, p: Vector3, glow: Material, stone: Material) -> void:
	geo.ring(glow, p + Vector3.UP * 0.035, 1.2, 0.12)
	var arch: Array[Vector3] = []
	for i in range(49):
		var a := PI * i / 48
		arch.append(p + Vector3(cos(a) * 1.65, sin(a) * 2.9, 0))
	geo.line_3d(stone, arch, 0.18)
	geo.line_3d(glow, arch, 0.06)

func label_at(caption: String, p: Vector3, font_size: int, color: Color, flat := false) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = p
	label.font_size = font_size
	label.pixel_size = 0.009
	label.modulate = color
	label.outline_size = 5
	label.no_depth_test = false
	if flat:
		label.rotation.x = -PI / 2
	else:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func near_floor(actor, p: Vector3, radius: float) -> bool:
	return Vector2(actor.position.x - p.x, actor.position.z - p.z).length() < radius and absf(actor.position.y - p.y) < 0.45

func tick(delta: float) -> void:
	if not game.world_mode or not game.authoritative(): return
	for id in progress.keys():
		if not game.actors.has(id): progress.erase(id)
	for id in entry_waits.keys():
		if not game.actors.has(id): entry_waits.erase(id)
	for actor in game.actors.values():
		var id: int = actor.actor_id
		var at_entry: bool = near_floor(actor, ENTRY, 1.0) and not game.duels.has(id) and not actor.training_dummy and actor.hp > 0
		if not at_entry:
			if entry_waits.has(id) and actor.hp > 0:
				game.feedback(actor, "Starwalk launch cancelled · Stay in the ring for 8 seconds")
			entry_waits.erase(id)
		if actor.training_dummy or actor.hp <= 0: continue
		if actor.position.y < FALL_Y:
			teleport(actor, HOME)
			progress.erase(id)
			game.combat_event(id, id, "The stars caught you · Back at the center", Color("92eeff"))
		elif at_entry:
			# Keep each player's dwell independent, and never inherit an old
			# actor's timer when a session rebuild reuses its numeric ID.
			if not entry_waits.has(id) or entry_waits[id].actor != actor.get_instance_id():
				entry_waits[id] = {"actor": actor.get_instance_id(), "elapsed": 0.0, "shown": 9}
			var wait: Dictionary = entry_waits[id]
			wait.elapsed += maxf(delta, 0.0)
			if float(wait.elapsed) >= ENTRY_WAIT:
				entry_waits.erase(id)
				teleport(actor, START)
				progress[id] = 0
				game.combat_event(id, id, "STARWALK · Follow the floating ruins", Color("92eeff"))
			else:
				var remaining := ceili(ENTRY_WAIT - float(wait.elapsed))
				if remaining != int(wait.shown):
					wait.shown = remaining
					game.feedback(actor, "STARWALK · Launching in %d… Stay in the ring" % remaining)
		elif near_floor(actor, platform_position(COUNT), 1.0):
			teleport(actor, HOME)
			progress.erase(id)
			game.combat_event(id, id, "STARWALK COMPLETE!", Color("ffda9c"))
		elif progress.has(id):
			for milestone in [24, 48]:
				if int(progress[id]) < milestone and near_floor(actor, platform_position(milestone), 2.5):
					progress[id] = milestone
					game.combat_event(id, id, "THE GRAVITY WELL · 24 / 72" if milestone == 24 else "THE CROWN OF STARS · 48 / 72", Color("d6b0ff"))

func teleport(actor, destination: Vector3) -> void:
	if not actor.identity.get("lasso", {}).is_empty():
		game.Outlaw.Lasso.cancel(game, actor)
	actor.position = destination + Vector3.UP * 0.08
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	actor.jump_queued = false
	actor.jump_buffer = 0
	actor.charge.clear()
	actor.identity.roll_left = 0.0
	actor.identity.backflip_active = false
	actor.identity.lasso = {}
	actor.casting = -1
	game.Outlaw.refund_interrupted_channel(game, actor)
	actor.motion_revision += 1
	actor.reset_physics_interpolation()
