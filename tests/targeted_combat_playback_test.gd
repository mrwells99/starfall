extends SceneTree
var checks := 0
var failures := 0
class DelayedFlare extends "res://scripts/solar_flare_history.gd":
	func rewind_age(_game, _caster) -> float: return .1
func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = preload("res://tests/ui_test_arena.gd").new()
	root.add_child(game); game.set_physics_process(false); game.set_process(false)
	game.roster = {1:{"champion":"Null","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round(); game.phase = "match"
	var a = game.actors[1]; var caster = game.actors[2]
	var prediction = preload("res://scripts/movement_prediction.gd").new()
	prediction.revision = 10
	var state: Dictionary = a.snapshot()
	state.motion_revision = 11; state.yaw = .4
	state.identity.null_action = "blindside"; state.identity.null_action_serial = 7
	prediction.pending = state.duplicate(true); prediction.reconcile(game,a)
	ck(is_equal_approx(game.local_yaw,.4), "Fresh Blindside faces the target")
	game.local_yaw = 1.1; game.pivot.rotation.y = 1.1
	state.motion_revision = 12
	prediction.pending = state.duplicate(true); prediction.reconcile(game,a)
	ck(is_equal_approx(game.local_yaw,1.1), "Old Blindside cannot snap camera on another displacement")
	state.motion_revision = 13; state.identity.null_action_serial = 8
	prediction.pending = state.duplicate(true); prediction.reconcile(game,a)
	ck(is_equal_approx(game.local_yaw,.4), "Next Blindside still turns camera")
	prediction.reset()
	ck(prediction.last_null_action_serial == -1, "New round resets consumed action")
	caster.position = Vector3.ZERO; caster.rotation.y = 0
	a.position = Vector3(0,0,-4.1)
	var history = DelayedFlare.new(); game.solar_flare_history = history
	history.tick(game,.02)
	for i in 6:
		a.position.z -= .1
		history.tick(game,1.0/60)
	ck(not game.ClassMechanics.flare_overlaps(caster,a), "Moving target has exited current cone")
	ck(history.overlaps(game,caster,a), "100ms delayed cone recovers seen edge overlap")
	ck(game.try_spell(2,8,-1) and a.stunned > 0, "Compensated Solar Flare actually applies control")
	ck(history.position_at(a,.251) == null, "History cannot exceed 250ms")
	a.motion_revision += 1
	ck(history.position_at(a,.1) == null, "Teleport immediately invalidates old positions")
	history.tick(game,.02)
	ck(history.position_at(a,.1) == null, "No interpolation across teleport")
	for i in 20: history.tick(game,1.0/60)
	ck(not history.overlaps(game,caster,a), "Old inside-cone position expires")
	a.hp = 0
	ck(history.position_at(a,.1) == null, "Death invalidates history immediately")
	a.hp = 1500
	game.epoch += 1; history.tick(game,.02)
	ck(history.position_at(a,.1) == null, "New round clears history")
	# Local prediction must not let the last packet override current jump input.
	a.cc_effects.clear(); a.stunned = 0; a.rotation.y = 0
	a.presentation_snapshot_serial = 2; a.presentation_grounded = null
	a.presentation_velocity = Vector3(-4,-6,0); a.velocity = Vector3(4,7,0)
	a.champion_model.animate(1.0/60,a)
	var jump = a.champion_model.null_art.omni_jump
	ck(jump.filtered_direction.x > 0, "Predicted jump follows current right input, not stale left packet")
	ck(is_equal_approx(jump.smooth_vertical,7), "Predicted jump uses current vertical velocity")
	var motion = preload("res://scripts/network_animation_motion.gd").new()
	a.presentation_grounded = false; a.presentation_vertical_speed = 7
	var previous: float = motion.vertical(a,1.0/60)
	var next: float = motion.vertical(a,1.0/60)
	ck(next < previous, "Remote jump advances between packets")
	game.free()
	print("Targeted combat playback checks: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
