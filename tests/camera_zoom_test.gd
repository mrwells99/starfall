extends SceneTree
var game
var zoom
var checks := 0
var failures := 0

class MemoryConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func reset_zoom(distance := 8.0) -> void:
	game.arm.spring_length = distance; zoom.zoom_target = distance; zoom.zoom_velocity = 0.0
func wheel(steps: float) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if steps >= 0 else MOUSE_BUTTON_WHEEL_DOWN
	event.factor = absf(steps); event.pressed = true
	game._unhandled_input(event)
func advance(seconds: float, rate: int) -> void:
	for frame in roundi(seconds*rate): zoom.tick(1.0/rate)

func run() -> void:
	root.disable_3d = true
	game = preload("res://tests/ui_test_arena.gd").new(); game.config = MemoryConfig.new(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.set_physics_process(false)
	game.champion_choice.select(game.Kits.NAMES.find("Outlaw")); game.local_match(); game.phase = "match"; game.application_focused = true
	zoom = game.movement_controls
	check(game.arm.spring_length == 9 and zoom.zoom_target == 9,"Default camera starts within the halved nine-metre maximum")
	reset_zoom(); wheel(.25)
	var quarter: float = zoom.zoom_target
	check(quarter < 8 and quarter > 7.5 and game.arm.spring_length == 8,"Fractional wheel input changes the destination without snapping the camera")
	for step in 3: wheel(.25)
	var full: float = zoom.zoom_target
	reset_zoom(); wheel(1)
	check(is_equal_approx(full,zoom.zoom_target),"Four quarter wheel events equal one full event")
	wheel(-1)
	check(is_equal_approx(zoom.zoom_target,8),"Equal in/out input restores the preferred distance")
	reset_zoom(5); wheel(1)
	check(is_equal_approx(zoom.zoom_target/5,full/8),"Wheel increments are proportional at close and far distances")
	reset_zoom(); wheel(1)
	var positions := [8.0]
	for frame in 30:
		zoom.tick(1.0/60); positions.append(game.arm.spring_length)
	var first: float = positions[0]-positions[1]
	var second: float = positions[1]-positions[2]
	check(first > 0 and second > first,"Camera starts moving immediately and accelerates over the first frames")
	check(positions[10]-positions[11] < second,"Zoom decelerates smoothly after its speed peak")
	check(positions[2] != zoom.zoom_target and positions[4] < positions[2],"Camera retains motion between wheel events")
	var smooth := true
	for frame in range(1,positions.size()): smooth = smooth and positions[frame] <= positions[frame-1] and positions[frame] >= zoom.zoom_target-.00001
	check(smooth and absf(positions[18]-zoom.zoom_target) < .006,"Single-step zoom converges promptly without overshooting")
	advance(.5,60)
	check(is_equal_approx(game.arm.spring_length,zoom.zoom_target) and zoom.zoom_velocity == 0,"Settled zoom stops completely")
	reset_zoom(); wheel(1); advance(.05,60)
	var velocity: float = zoom.zoom_velocity
	var current: float = game.arm.spring_length
	wheel(1)
	check(zoom.zoom_velocity == velocity and game.arm.spring_length == current,"Repeated input retains velocity and current position")
	wheel(-3)
	check(zoom.zoom_velocity == velocity and game.arm.spring_length == current,"Reversing direction does not jump position or reset velocity")
	advance(.3,60)
	check(game.arm.spring_length > current and zoom.zoom_velocity > 0,"Reverse input smoothly brakes and changes direction")
	var results := []
	for rate in [30,60,144]:
		reset_zoom(); wheel(3); advance(.5,rate)
		results.append(game.arm.spring_length)
		check(game.arm.spring_length >= 3 and game.arm.spring_length <= 9,"Zoom remains bounded at %d FPS" % rate)
	check(absf(results[0]-results[1]) < .00002 and absf(results[0]-results[2]) < .00002,"Zoom timing is stable across 30, 60 and 144 FPS")
	for direction in [1,-1]:
		reset_zoom(); wheel(direction*100)
		for frame in 80: zoom.tick(1.0/60)
		check(is_equal_approx(zoom.zoom_target,3 if direction == 1 else 9) and game.arm.spring_length == zoom.zoom_target,"Repeated scrolling respects the reduced zoom limit")
		wheel(direction*100); advance(.5,60)
		check(zoom.zoom_velocity == 0,"Holding input against a distance limit does not accumulate momentum")
	reset_zoom(); wheel(1); advance(.05,60)
	game.application_focused = false; current = game.arm.spring_length
	wheel(1); zoom.tick(.1)
	check(zoom.zoom_velocity == 0 and game.arm.spring_length == current and is_equal_approx(zoom.zoom_target,full),"Focus loss freezes zoom and rejects new wheel input")
	game.application_focused = true; game.panel.show(); wheel(1); zoom.tick(.1)
	check(game.arm.spring_length == current and is_equal_approx(zoom.zoom_target,full),"Menus cannot queue world-camera scrolling")
	game.panel.hide(); reset_zoom(); wheel(1); advance(.05,60)
	var target: float = zoom.zoom_target
	game.send_action(game.assignment.find(8))
	check(game.outlaw_aim_test.enabled and zoom.zoom_velocity == 0,"Entering Detonation aiming clears ordinary zoom inertia")
	wheel(1)
	game.outlaw_aim_test.tick(.12); game.outlaw_aim_test.apply_camera(); current = game.arm.spring_length
	zoom.tick(.1)
	check(game.arm.spring_length == current and zoom.zoom_target == target,"Normal scrolling and its spring cannot alter the shoulder-camera transition")
	game.outlaw_aim_test.leave(); wheel(-1)
	check(zoom.zoom_target == target,"Returning from aim also owns its transition until complete")
	game.outlaw_aim_test.tick(.6); zoom.tick(.01)
	check(game.arm.spring_length > 3 and game.arm.spring_length <= 9 and not game.outlaw_aim_test.owns_camera(),"Normal zoom resumes safely after shoulder-camera restoration")
	reset_zoom(); wheel(0); wheel(NAN); zoom.tick(0)
	check(game.arm.spring_length == 8 and zoom.zoom_target == 8 and is_finite(zoom.zoom_velocity),"Zero or invalid input does not corrupt camera state")
	game.config.set_value("hud","camera_distance",6.75); zoom.zoom_velocity = 3; game.load_layout()
	check(zoom.zoom_target == 6.75 and zoom.zoom_velocity == 0,"Reloading camera preferences clears transient inertia and preserves fractional distance")
	for old_distance in [18.0,12,100.0]:
		game.config.set_value("hud","camera_distance",old_distance); game.load_layout()
		check(game.arm.spring_length == 9 and zoom.zoom_target == 9,"Old saved zoom above the new limit clamps to nine metres")
	zoom.zoom_target = 18; advance(.5,60)
	check(zoom.zoom_target == 9 and game.arm.spring_length == 9,"A stale runtime target cannot restore the previous maximum")
	game.clear_actors(); game.queue_free(); await process_frame
	print("Camera zoom checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
