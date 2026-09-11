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
var zoom_target := ZOOM_MAX
var zoom_velocity := 0.0
var follow_delay := 0.0
const CLICK_DISTANCE := 5.0
const ZOOM_MIN := 3.0
const ZOOM_MAX := 9.0
const ZOOM_STEP := .08 # Logarithmic step: proportional, reciprocal in/out, accepts fractional wheel input.
const ZOOM_RESPONSE := 24.0 # Brief acceleration, then a critically damped stop (about .28s to 99%).

func camera_active() -> bool:
	if game == null or game.panel == null or game.player_options == null: return false
	return game.application_focused and game.phase in ["match", "countdown"] and not game.panel.visible and not game.edit_mode and not game.keybind_menu.visible and not game.player_options.dialog.visible and not game.social.typing() and game.actors.has(game.local_id)

func active() -> bool:
	return camera_active() and game.actors[game.local_id].hp > 0

func cancel() -> void:
	if game == null: return
	zoom_velocity = 0.0
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
		var sensitivity: float = .004 * game.player_options.mouse_sensitivity()
		game.pivot.rotation.y -= event.screen_relative.x * sensitivity
		game.arm.rotation.x = clampf(game.arm.rotation.x - event.screen_relative.y * sensitivity * (-1.0 if game.player_options.invert_y else 1.0), -1.15, 0.12)
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
	if game.outlaw_aim_test.enabled:
		game.local_yaw = lerp_angle(game.local_yaw,game.pivot.rotation.y,1.0-exp(-30.0*delta))
	elif right: align_facing()
	elif game.actors[game.local_id].stunned <= 0:
		var turn: float = (game.controls.held("turn_left") - game.controls.held("turn_right")) * delta * game.player_options.turn_speed
		game.local_yaw += turn
		if not left: game.pivot.rotation.y += turn
	var movement := Vector2(game.controls.held("strafe_right") - game.controls.held("strafe_left"), game.controls.held("backward") - game.controls.held("forward"))
	if game.controls.held("forward") > 0 or game.controls.held("backward") > 0: autorun = false
	if right or game.outlaw_aim_test.enabled: movement.x += game.controls.held("turn_right") - game.controls.held("turn_left")
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

func scroll_zoom(steps: float) -> void:
	if not camera_active() or game.outlaw_aim_test.owns_camera() or not is_finite(steps): return
	zoom_target = clampf(zoom_target * exp(clampf(-steps * ZOOM_STEP, -20.0, 20.0)), ZOOM_MIN, ZOOM_MAX)
	game.camera_dirty = true

func tick_zoom(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	zoom_target = clampf(zoom_target, ZOOM_MIN, ZOOM_MAX)
	# Exact spring solution, so input retains velocity and feels the same at any FPS.
	# Only the requested boom length changes; SpringArm3D still handles terrain.
	var offset: float = game.arm.spring_length - zoom_target
	var response: float = zoom_velocity + ZOOM_RESPONSE * offset
	var decay := exp(-ZOOM_RESPONSE * delta)
	var distance: float = zoom_target + (offset + response * delta) * decay
	zoom_velocity = (zoom_velocity - ZOOM_RESPONSE * response * delta) * decay
	game.arm.spring_length = clampf(distance, ZOOM_MIN, ZOOM_MAX)
	if (distance <= ZOOM_MIN and zoom_velocity < 0) or (distance >= ZOOM_MAX and zoom_velocity > 0): zoom_velocity = 0.0
	if absf(game.arm.spring_length - zoom_target) < .0001 and absf(zoom_velocity) < .001:
		game.arm.spring_length = zoom_target
		zoom_velocity = 0.0

func tick(delta: float) -> void:
	if not camera_active():
		zoom_velocity = 0.0
		if left or right or autorun: cancel()
		return
	if not game.outlaw_aim_test.owns_camera():
		tick_zoom(delta)
	else:
		zoom_velocity = 0.0
	follow_delay = maxf(0.0, follow_delay - delta)
	if game.player_options.camera_follow and not left and not right and not game.outlaw_aim_test.owns_camera() and follow_delay == 0 and game.actors[game.local_id].move_input.length() > 0.01:
		game.pivot.rotation.y = lerp_angle(game.pivot.rotation.y, game.local_yaw, 1.0 - exp(-5.0 * delta))

func select_at(point: Vector2) -> void:
	var origin: Vector3 = game.camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + game.camera.project_ray_normal(point) * 100, 3)
	query.exclude = [game.actors[game.local_id].get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is CharacterBody3D and game.actors.values().has(hit.collider):
		game.selected_id = hit.collider.actor_id
