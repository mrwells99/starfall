extends RefCounted
## Defense Detonation aiming; legacy filename retained for existing tool references.
## Firing is intentionally disconnected. Neither toggling nor clicking spends stacks.
const RETICLE_START_WEIGHT := .25 # Show early in the pan, after a camera clearance update.
const SHOULDER_DISTANCE := 1.65
const SHOULDER_RIGHT := .55
const SHOULDER_FOV := 62.0
var game
var reticle: Control
var enabled := false
var progress := 0.0
var transition_velocity := 0.0
var weight := 0.0
var saved := false
var saved_length := 9.0
var saved_position := Vector3.ZERO
var saved_pitch := -.38
var saved_fov := 75.0
var saved_shape: Shape3D
var saved_near := .05
var aim_pitch := -.04
var shoulder_right := SHOULDER_RIGHT
var actor_id := -1
var camera_shape := SphereShape3D.new()
var shoulder_ready := false

func setup(host) -> void:
	game = host
	camera_shape.radius = .14
	reticle = load("res://scripts/aim_reticle.gd").new()
	reticle.name = "DefenseDetonationReticle"
	game.ui.add_child(reticle)
	reticle.hide()

func available() -> bool:
	return game != null and not game.dedicated and game.movement_controls.camera_active() and game.actors.has(game.local_id) and game.actors[game.local_id].champion == "Outlaw" and game.actors[game.local_id].hp > 0

func ready_to_aim() -> bool:
	if not available(): return false
	var actor = game.actors[game.local_id]
	return block_reason(actor).is_empty()

func block_reason(actor) -> String:
	if actor.hp <= 0: return "You are defeated"
	if actor.stunned > 0: return "Controlled"
	if actor.casting >= 0: return "Already casting"
	if actor.identity.roll_left > 0: return "Rolling"
	if actor.identity.backflip_active: return "Backflipping"
	return ""

func owns_camera() -> bool:
	return saved

func toggle() -> void:
	if enabled:
		leave()
	elif ready_to_aim():
		if not saved:
			saved_length = game.arm.spring_length
			saved_position = game.arm.position
			saved_pitch = game.arm.rotation.x
			saved_fov = game.camera.fov
			saved_near = game.camera.near
			saved_shape = game.arm.shape
			aim_pitch = -.04
			saved = true
		actor_id = game.local_id
		enabled = true
		shoulder_ready = false
		game.movement_controls.left = false
		# Keep an owned right-button gesture alive while aiming owns mouse look.
		# Physical button polling would also pick up presses owned by the UI.
		game.movement_controls.zoom_velocity = 0.0
		game.capture_mouse()

func leave(resume_gesture: bool = true) -> void:
	enabled = false
	if is_instance_valid(reticle): reticle.hide()
	if game != null:
		if resume_gesture and game.movement_controls.right and game.movement_controls.active() and actor_id == game.local_id:
			game.capture_mouse()
		else:
			game.release_mouse()

func clear_pose() -> void:
	if game != null and game.actors.has(actor_id):
		var model = game.actors[actor_id].champion_model
		if model != null and model.outlaw_art != null: model.outlaw_art.test_aim_weight = 0.0

func restore_camera() -> void:
	if saved and game != null:
		game.arm.spring_length = clampf(saved_length,game.movement_controls.ZOOM_MIN,game.movement_controls.ZOOM_MAX)
		game.arm.position = saved_position
		game.arm.rotation.x = saved_pitch
		game.arm.shape = saved_shape
		game.camera.fov = saved_fov
		game.camera.near = saved_near
	saved = false

func reset() -> void:
	clear_pose()
	if enabled: leave(false)
	progress = 0; weight = 0; transition_velocity = 0; actor_id = -1
	shoulder_ready = false
	restore_camera()
	if is_instance_valid(reticle): reticle.hide()

func input(event: InputEvent) -> bool:
	if not enabled: return false
	if not ready_to_aim():
		leave(); return false
	# Defense Detonation's own hotbar action is the only manual toggle out. Do not let
	# Escape reach the arena menu handler and indirectly close the preview.
	if event is InputEventKey and event.keycode == KEY_ESCAPE: return true
	if event is InputEventMouseButton:
		if not event.pressed: game.controls.mouse_held.erase(event.button_index)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Releases arrive here before normal movement input. Track both edges
			# without exiting aim or restarting its smoothed facing animation.
			game.movement_controls.right = event.pressed
			game.movement_controls.dragged = true
		# Preserve ordinary GUI activation when the cursor is available.
		if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			for slot in game.ability_buttons.size():
				var ability: int = game.kit_slot(slot)
				var button: Button = game.ability_buttons[slot]
				if ability >= 0 and game.actors[game.local_id].kit[ability].kind == "defense_detonation" and button.is_visible_in_tree() and button.get_global_rect().has_point(event.position): return false
		# A preview click never starts a targeting gesture or a shot.
		return event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]
	if event is InputEventMouseMotion:
		var sensitivity: float = .003 * game.player_options.sensitivity
		game.pivot.rotation.y -= event.screen_relative.x * sensitivity
		aim_pitch = clampf(aim_pitch-event.screen_relative.y*sensitivity*(-1 if game.player_options.invert_y else 1),-1.0,1.0)
		return true
	return false

func advance_transition(delta: float) -> void:
	if delta <= 0 or not is_finite(delta): return
	# Match normal zoom's spring, including momentum across rapid toggle reversals.
	# One blended weight drives camera distance, offset, pitch, FOV and gun raise.
	var target := 1.0 if enabled else 0.0
	var response_rate: float = game.movement_controls.ZOOM_RESPONSE
	var offset := progress-target
	var response := transition_velocity+response_rate*offset
	var decay := exp(-response_rate*delta)
	progress = clampf(target+(offset+response*delta)*decay,0.0,1.0)
	transition_velocity = (transition_velocity-response_rate*response*delta)*decay
	if (progress == 0 and transition_velocity < 0) or (progress == 1 and transition_velocity > 0): transition_velocity = 0.0
	if absf(progress-target) < .0001 and absf(transition_velocity) < .003:
		progress = target
		transition_velocity = 0.0
	weight = progress

func tick(delta: float) -> void:
	if game == null: return
	if saved and (not available() or actor_id != game.local_id):
		reset()
	if enabled and not ready_to_aim(): leave()
	advance_transition(delta)
	if progress < RETICLE_START_WEIGHT: shoulder_ready = false
	if saved and progress == 0:
		clear_pose(); restore_camera(); actor_id = -1
	if saved and game.actors.has(actor_id):
		var art = game.actors[actor_id].champion_model.outlaw_art
		art.test_aim_weight = weight if ready_to_aim() else 0.0
		# Compute the final aiming direction, independent of the moving camera boom.
		art.test_aim_direction = -(game.pivot.basis * Basis(Vector3.RIGHT,aim_pitch)).z
	reticle.visible = enabled and progress >= RETICLE_START_WEIGHT and shoulder_ready and ready_to_aim()

func physics_tick() -> void:
	if not saved or game == null: return
	shoulder_ready = enabled and progress >= RETICLE_START_WEIGHT
	# Sweep the shoulder offset too; the existing spring arm covers rearward travel.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_shape
	query.transform = Transform3D(Basis.IDENTITY,game.pivot.global_position)
	query.motion = game.pivot.global_basis.x*SHOULDER_RIGHT
	query.collision_mask = 1
	var fractions: PackedFloat32Array = game.get_world_3d().direct_space_state.cast_motion(query)
	shoulder_right = SHOULDER_RIGHT*fractions[0] if fractions.size() > 0 else 0.0

func apply_camera() -> void:
	if not saved: return
	game.arm.position = saved_position.lerp(Vector3(shoulder_right,0,0),weight)
	game.arm.spring_length = lerpf(saved_length,SHOULDER_DISTANCE,weight)
	game.arm.rotation.x = lerpf(saved_pitch,aim_pitch,weight)
	game.arm.shape = camera_shape
	game.camera.near = .05
	game.camera.fov = lerpf(saved_fov,SHOULDER_FOV,weight)
