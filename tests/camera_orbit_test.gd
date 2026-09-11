extends SceneTree
## Exercise the real input, spring-arm physics and authored-character materials.
## Rendering the fade itself is covered by the native visual camera probe.
const Course = preload("res://scripts/world_starwalk.gd")
var game
var actor
var checks := 0
var failures := 0

class MemoryConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func mouse(index: int, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = down
	event.position = Vector2(40, 40)
	return event

func drag_vertical(displacement: float) -> void:
	var event := InputEventMouseMotion.new()
	event.screen_relative = Vector2(0, displacement)
	event.relative = event.screen_relative
	game._input(event)

func place_camera(feet: Vector3, pitch: float, yaw := 0.0, distance := 9.0) -> void:
	actor.position = feet
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	actor.reset_physics_interpolation()
	game.pivot.rotation.y = yaw
	game.arm.rotation.x = pitch
	game.arm.spring_length = distance
	game.movement_controls.zoom_target = distance
	game.movement_controls.zoom_velocity = 0.0
	game._process(0)

func settle(frames := 5) -> void:
	for frame in frames:
		game._process(1.0 / 60)
		await physics_frame
		await process_frame

func inspect_orbit_input() -> void:
	var controls = game.movement_controls
	game.player_options.sensitivity = 1
	for inverted in [false, true]:
		game.player_options.invert_y = inverted
		game._unhandled_input(mouse(MOUSE_BUTTON_RIGHT, true))
		check(controls.right, "A world-owned right-button press starts camera orbit")
		drag_vertical(10000.0 if inverted else -10000.0)
		check(game.arm.rotation.x > deg_to_rad(89) and game.arm.rotation.x < PI / 2,
			"Normal/inverted mouse look reaches almost straight upward without flipping")
		var top: float = game.arm.rotation.x
		drag_vertical(10000.0 if inverted else -10000.0)
		check(is_equal_approx(game.arm.rotation.x, top), "Dragging beyond the upper pole is stable")
		drag_vertical(-10000.0 if inverted else 10000.0)
		check(game.arm.rotation.x < deg_to_rad(-89) and game.arm.rotation.x > -PI / 2,
			"Normal/inverted mouse look reaches almost straight downward without flipping")
		game._input(mouse(MOUSE_BUTTON_RIGHT, false))
		check(not controls.right, "Releasing an extreme-angle orbit ends the gesture")
	game.player_options.invert_y = false

func inspect_collision() -> void:
	check(game.arm.shape is SphereShape3D and game.arm.shape.radius >= 0.19,
		"The gameplay camera sweeps a real volume to keep its near plane clear")
	check(game.arm.collision_mask == 1 and game.camera.near <= 0.05001,
		"Camera collision uses terrain, excludes player bodies, and supports close views")
	for degrees in [30.0, 60.0, 89.1]:
		place_camera(Vector3(0, 0.05, 0), deg_to_rad(degrees))
		await settle()
		check(game.camera.global_position.y >= 0.18 and game.camera.global_position.y < 0.4,
			"Looking upward at %.1f degrees keeps the camera above the real arena floor" % degrees)
		check(game.arm.get_hit_length() < game.arm.spring_length and game.arm.spring_length == 9,
			"Ground collision retracts the camera while preserving the requested distance")
		check((-game.camera.global_basis.z).y > sin(deg_to_rad(degrees)) - 0.001,
			"Floor collision preserves the requested upward viewing direction")
	place_camera(Vector3(0, 0.05, 0), deg_to_rad(89.1))
	await settle()
	check(game.arm.get_hit_length() < 3,
		"A floor collision can move the camera closer than the ordinary wheel zoom minimum")
	place_camera(Vector3(0, 0.05, 16), 0)
	await settle()
	check(game.camera.global_position.z > 16 and game.camera.global_position.z <= 17.46,
		"The same camera volume stops before the arena boundary wall")
	place_camera(Vector3(15, 1.25, 0), deg_to_rad(89.1))
	await settle()
	check(game.camera.global_position.y >= 1.38 and game.camera.global_position.y < 1.6,
		"Upward orbit collides with the raised terrace instead of passing through it")
	place_camera(Vector3(15, 0.65, 8), deg_to_rad(89.1))
	await settle()
	var ramp_height: float = game.Layout.surface_height(game.camera.global_position)
	check(game.camera.global_position.y > ramp_height + 0.17,
		"The camera retains clearance over the actual sloped stairs")
	game.world_mode = true
	place_camera(Course.platform_position(60) + Vector3.UP * 0.05, deg_to_rad(89.1))
	await settle()
	check(game.camera.global_position.y >= Course.platform_position(60).y + 0.18 and game.arm.get_hit_length() < 2,
		"Even a narrow high Starwalk landing blocks an upward-looking camera")
	place_camera(Vector3(200, 30, 0), deg_to_rad(89.1))
	await settle()
	check(game.camera.global_position.y < actor.global_position.y - 7 and game.arm.get_hit_length() > 8.99,
		"In open space the camera can orbit underneath the character at full requested distance")
	check((-game.camera.global_basis.z).y > 0.999,
		"The view points virtually straight up at the vertical jump puzzle")
	check(game.movement_controls.zoom_target == 9 and game.arm.spring_length == 9,
		"Leaving an obstruction restores the full preferred zoom automatically")

func inspect_aim_handoff() -> void:
	place_camera(Vector3(0, 0.05, 0), deg_to_rad(89.1), 0, 7)
	await settle()
	var ordinary_shape: Shape3D = game.arm.shape
	var ordinary_pitch: float = game.arm.rotation.x
	var aim = game.outlaw_aim_test
	game.send_action(game.assignment.find(8))
	check(aim.enabled, "Defense Detonation can acquire the camera from an upward orbit")
	for frame in 45:
		aim.physics_tick()
		await settle(1)
	check(aim.owns_camera() and game.arm.spring_length < 2 and game.arm.shape != ordinary_shape,
		"Aiming retains its shoulder framing and its own collision shape")
	check(game.movement_controls.zoom_target == 7, "Aiming preserves ordinary wheel zoom preference")
	aim.leave()
	for frame in 45:
		aim.physics_tick()
		await settle(1)
	check(not aim.owns_camera() and game.arm.shape == ordinary_shape and is_equal_approx(game.arm.rotation.x, ordinary_pitch),
		"Leaving aim restores the full upward pitch and ordinary collision volume")
	check(game.arm.spring_length == 7 and game.arm.get_hit_length() < 2 and game.camera.global_position.y >= 0.18,
		"Returning to upward orbit preserves preferred zoom while continuing to respect the floor")

func material_snapshot(model: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				result.append({"mesh": mesh, "surface": surface, "material": material,
					"override": mesh.material_override, "surface_override": mesh.get_surface_override_material(surface),
					"mode": material.distance_fade_mode, "min": material.distance_fade_min_distance,
					"max": material.distance_fade_max_distance})
	return result

func restored(snapshot: Array[Dictionary]) -> bool:
	for item in snapshot:
		var material: BaseMaterial3D = item.mesh.get_active_material(item.surface)
		if material != item.material or item.mesh.material_override != item.override or item.mesh.get_surface_override_material(item.surface) != item.surface_override:
			return false
		if material.distance_fade_mode != item.mode or material.distance_fade_min_distance != item.min or material.distance_fade_max_distance != item.max:
			return false
	return true

func inspect_material_fade() -> void:
	var fade = game.camera_character_fade
	fade.reset()
	game.spawn_actor(90, 90, 0, "Outlaw", Vector3(205, 30, 0))
	var other = game.actors[90]
	var art = actor.champion_model.outlaw_art
	# This attached mesh deliberately shares a resource, as future equipment may.
	var shared := StandardMaterial3D.new()
	shared.resource_name = "CameraTestSharedEquipment"
	shared.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	shared.distance_fade_min_distance = 4.0
	shared.distance_fade_max_distance = 7.0
	for target in [actor, other]:
		var attachment := MeshInstance3D.new()
		attachment.name = "SharedEquipmentAttachment"
		attachment.mesh = BoxMesh.new()
		attachment.mesh.material = shared
		target.champion_model.outlaw_art.model.add_child(attachment)
	var original := material_snapshot(actor.champion_model)
	var remote := material_snapshot(other.champion_model)
	var health_material: Material = actor.health_mesh.material_override
	check(original.size() > 8 and remote.size() == original.size(), "Two fully authored Outlaws include body, equipment, and shared-attachment materials")
	fade.update(actor)
	var active := material_snapshot(actor.champion_model)
	var all_fade := true
	var has_knife := false
	for item in active:
		var material: BaseMaterial3D = item.material
		all_fade = all_fade and material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		all_fade = all_fade and material.distance_fade_min_distance > 0 and material.distance_fade_min_distance < material.distance_fade_max_distance
		has_knife = has_knife or "Bowie" in material.resource_name
	check(all_fade and has_knife, "Body and authored weapon materials use progressive near-camera dither fading")
	check(restored(remote) and shared.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED,
		"Fading the followed player does not change another player or a shared equipment resource")
	check(actor.health_mesh.material_override == health_material and health_material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED,
		"Character fading leaves nameplate and health materials alone")
	var owned_references_preserved := true
	for item in original:
		if item.material in art.materials:
			owned_references_preserved = owned_references_preserved and item.mesh.get_active_material(item.surface) == item.material
	check(owned_references_preserved, "Actor-owned material identities remain connected to damage and team presentation")
	actor.flash = 0.2
	actor.visual_tick(0, game.camera, false)
	var flash_reaches_visible_materials := true
	for item in active:
		if item.material in art.materials:
			flash_reaches_visible_materials = flash_reaches_visible_materials and item.material.albedo_color == Color.WHITE
	check(flash_reaches_visible_materials, "Damage flashes still reach the rendered faded character")
	fade.update(other)
	check(restored(original), "Changing followed character restores the previous body's exact material bindings and fade settings")
	fade.update(null)
	check(restored(remote), "Ending follow restores the second character and shared equipment bindings")
	fade.reset()
	game._process(0)
	check(actor.champion_model.outlaw_art.materials[0].distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER,
		"The gameplay render update applies fade to its followed actor")
	game.menu_camera.make_current()
	game._process(0)
	check(restored(original), "Switching away from the gameplay camera clears its character fade")
	game.camera.make_current()
	game._process(0)
	# Keep strong material references so teardown can be checked after actor removal.
	game.clear_actors()
	var teardown_restored := true
	for item in original:
		teardown_restored = teardown_restored and item.material.distance_fade_mode == item.mode
	check(teardown_restored, "Clearing actors restores transient fade settings before freeing their models")

func inspect_roster_fade() -> void:
	var fade = game.camera_character_fade
	for title in ["Ember", "Vanguard", "Luminary", "Fulcrum"]:
		var id: int = 100 + game.actors.size()
		game.spawn_actor(id, id, 0, title, Vector3(200, 30, 0))
		var target = game.actors[id]
		var presenter: Node3D = target.champion_model
		var art = presenter.get(title.to_lower() + "_art")
		var costume: Node3D = art.model
		if title == "Vanguard":
			target.shield = 10
			target.visual_tick(0, game.camera, false)
			art.StrikeFX.spawn(presenter, Vector3.ZERO, Vector3.FORWARD, target.base_color)
		var before := material_snapshot(costume)
		var effects: Array[Dictionary] = []
		for item in material_snapshot(presenter):
			if not costume.is_ancestor_of(item.mesh): effects.append(item)
		fade.update(target)
		var fading := not before.is_empty()
		for item in material_snapshot(costume):
			fading = fading and item.material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			fading = fading and item.material.distance_fade_min_distance < item.material.distance_fade_max_distance
		check(fading, title + " authored costume and attached equipment receive progressive camera fading")
		if title == "Vanguard":
			check(effects.size() >= 10 and art.ward.visible and art.pulse.visible and restored(effects),
				"Vanguard's active ward, pulse, strike arc/sparks, and prewarmed effects keep their own unfaded materials")
		fade.reset()
		check(restored(before) and restored(effects), title + " restores its original costume materials without changing gameplay effects")
	game.clear_actors()

func run() -> void:
	game = preload("res://tests/ui_test_arena.gd").new()
	game.config = MemoryConfig.new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.champion_choice.select(game.Kits.NAMES.find("Outlaw"))
	game.local_match()
	game.phase = "match"
	game.application_focused = true
	game.panel.hide()
	actor = game.actors[game.local_id]
	inspect_orbit_input()
	await inspect_collision()
	await inspect_aim_handoff()
	inspect_material_fade()
	inspect_roster_fade()
	game.queue_free()
	await process_frame
	print("Camera orbit checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
