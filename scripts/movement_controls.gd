extends RefCounted
## World gestures own their entire press/drag/release, independent of HUD overlap.
var game
var left := false
var right := false
var dragged := false
var drag_distance := 0.0
var click_origin := Vector2.ZERO
var autorun := false
var walking := false
var zoom_target := 10.0
var follow_delay := 0.0
const CLICK_DISTANCE := 5.0

func camera_active() -> bool:
	if game == null or game.panel == null or game.player_options == null: return false
	return game.application_focused and game.phase in ["match", "countdown"] and not game.panel.visible and not game.edit_mode and not game.keybind_menu.visible and not game.player_options.dialog.visible and not game.social.typing() and game.actors.has(game.local_id)

func active() -> bool:
	return camera_active() and game.actors[game.local_id].hp > 0

func cancel() -> void:
	if game == null: return
	left = false
	right = false
	dragged = false
	autorun = false
	game.queued_jump = false
	game.pending_jump_id = 0
	game.controls.mouse_held.clear()
	game.controls.suppress_held_movement()
	game.release_mouse()

func align_facing() -> void:
	if game.actors.has(game.local_id) and game.actors[game.local_id].stunned <= 0 and game.actors[game.local_id].hp > 0:
		game.local_yaw = game.pivot.rotation.y

# Called before GUI dispatch only to continue/release an already-owned gesture.
func input(event: InputEvent) -> bool:
	if game == null: return false
	if event is InputEventKey and not event.pressed:
		var released: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		for binding in game.controls.suppressed.keys():
			if (binding & KEY_CODE_MASK) == released: game.controls.suppressed.erase(binding)
	if event is InputEventMouseButton and not event.pressed:
		game.controls.mouse_held.erase(event.button_index)
	if not camera_active():
		if left or right or autorun: cancel()
		return false
	if event is InputEventMouseMotion and (left or right):
		drag_distance += event.screen_relative.length()
		dragged = dragged or drag_distance > CLICK_DISTANCE
		game.pivot.rotation.y -= event.screen_relative.x * 0.004 * game.player_options.sensitivity
		game.arm.rotation.x = clampf(game.arm.rotation.x - event.screen_relative.y * 0.004 * game.player_options.sensitivity * (-1.0 if game.player_options.invert_y else 1.0), -1.15, 0.12)
		if right: align_facing()
		follow_delay = 0.4
		return true
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and (left or right):
		if event.pressed:
			begin(event)
		else:
			var was_click: bool = left and not right and not dragged and event.button_index == MOUSE_BUTTON_LEFT
			if event.button_index == MOUSE_BUTTON_LEFT: left = false
			else: right = false
			if not left and not right:
				game.release_mouse()
				if was_click: select_at(click_origin)
		return true
	return false

# Only unhandled presses may start a world gesture or a held mouse binding.
func begin(event: InputEventMouseButton) -> void:
	if not camera_active(): return
	if not left and not right:
		click_origin = event.position
		drag_distance = 0.0
		dragged = false
	if event.button_index == MOUSE_BUTTON_LEFT: left = true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		right = true
		align_facing()
	if left and right:
		dragged = true
		autorun = false
	game.capture_mouse()

func sample(delta: float) -> Vector2:
	if not active():
		if not camera_active(): cancel()
		else:
			autorun = false
			game.queued_jump = false
			game.pending_jump_id = 0
		return Vector2.ZERO
	if right: align_facing()
	elif game.actors[game.local_id].stunned <= 0:
		var turn: float = (game.controls.held("turn_left") - game.controls.held("turn_right")) * delta * game.player_options.turn_speed
		game.local_yaw += turn
		if not left: game.pivot.rotation.y += turn
	var movement := Vector2(game.controls.held("strafe_right") - game.controls.held("strafe_left"), game.controls.held("backward") - game.controls.held("forward"))
	if game.controls.held("forward") > 0 or game.controls.held("backward") > 0: autorun = false
	if right: movement.x += game.controls.held("turn_right") - game.controls.held("turn_left")
	if autorun or (left and right): movement.y = -1
	return movement.limit_length()

func action(code: int) -> void:
	if game.controls.matches("autorun", code):
		autorun = not autorun
		game.notice.text = "Autorun on" if autorun else "Autorun off"
		game.notice_time = 1.5
	if game.controls.matches("walk", code):
		walking = not walking
		game.notice.text = "Walking" if walking else "Running"
		game.notice_time = 1.5
	if game.controls.matches("recenter_camera", code):
		game.pivot.rotation.y = game.local_yaw
		follow_delay = 0.4

func tick(delta: float) -> void:
	if not camera_active():
		if left or right or autorun: cancel()
		return
	game.arm.spring_length = lerpf(game.arm.spring_length, zoom_target, 1.0 - exp(-18.0 * delta))
	follow_delay = maxf(0.0, follow_delay - delta)
	if game.player_options.camera_follow and not left and not right and follow_delay == 0 and game.actors[game.local_id].move_input.length() > 0.01:
		game.pivot.rotation.y = lerp_angle(game.pivot.rotation.y, game.local_yaw, 1.0 - exp(-5.0 * delta))

func select_at(point: Vector2) -> void:
	var origin: Vector3 = game.camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + game.camera.project_ray_normal(point) * 100, 3)
	query.exclude = [game.actors[game.local_id].get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is CharacterBody3D and game.actors.values().has(hit.collider):
		game.selected_id = hit.collider.actor_id
