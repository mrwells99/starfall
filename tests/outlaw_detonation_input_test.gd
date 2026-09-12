extends SceneTree
var game
var a
var b
var checks:=0
var failures:=0
var results:Array=[]
class TestConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass
func _initialize() -> void: call_deferred("run")
func ck(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func mouse(index: int, pressed: bool) -> InputEventMouseButton:
	var event:=InputEventMouseButton.new(); event.button_index=index; event.pressed=pressed; return event
func step(delta:=1.0/60) -> void:
	for actor in game.actors.values():
		actor.gcd=maxf(0,actor.gcd-delta); actor.action_budget=maxf(0,actor.action_budget-delta)
	game.outlaw_aim_test.physics_tick()
	game._process(delta)
	game.update_visuals(delta)
	# Keep a controlled camera so body hit accuracy and recoil sampling are measurable.
	game.camera.global_position=a.position+Vector3(.55,1.6,1.65)
	game.camera.look_at(game.aimed_combat.firing_origin(b.body_hitboxes.points))
	game.camera.rotate_object_local(Vector3.RIGHT,game.outlaw_aim_test.recoil_pitch)
	game.aimed_combat.tick(game,delta)
	game.outlaw_aim_test.fire_tick(delta)
	game.outlaw_detonation.tick(game)
func prepare(count: int) -> void:
	game.clear_actors()
	game.world_mode=false; game.mode=1
	game.roster={1:{"champion":"Outlaw","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round(); game.phase="match"; game.application_focused=true
	a=game.actors[1]; b=game.actors[2]
	a.position=Vector3(0,20,0); b.position=Vector3(0,20,-6)
	a.presentation_grounded=true; b.presentation_grounded=true; a.identity.defense_detonation=count
	game.camera.top_level=true
	for frame in 20: step()
	results.clear()
	await physics_frame
func run() -> void:
	game=load("res://arena.tscn").instantiate(); game.config=TestConfig.new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.aimed_shot_resolved.connect(func(result): results.append(result))
	for count in [1,2,3]:
		await prepare(count)
		game.movement_controls.begin(mouse(MOUSE_BUTTON_RIGHT,true))
		game.send_action(game.assignment.find(8))
		for frame in 20: step()
		ck(game.outlaw_aim_test.reticle.visible,"Crosshair appears before firing")
		game._input(mouse(MOUSE_BUTTON_LEFT,true)); game._input(mouse(MOUSE_BUTTON_LEFT,false))
		for frame in 35:
			game._input(mouse(MOUSE_BUTTON_LEFT,true)); step()
		ck(results.is_empty() and a.identity.defense_detonation == count and a.gcd == 0,"Repeated trigger pulls cannot skip the .6s charge or spend resources early")
		step()
		ck(a.identity.defense_detonation==0 and results.size()==1,"One trigger pull charges .6s, then reserves stacks and fires")
		ck(game.outlaw_aim_test.recoil_pitch>0 and game.outlaw_aim_test.recoil_pitch<=.005,"Each shot adds only a small quarter-degree recoil")
		if count>1: ck(game.outlaw_aim_test.enabled,"Aiming remains active between shots despite the zero-stack snapshot")
		for frame in 22:
			# Repeated clicks cannot restart or duplicate a committed burst.
			game._input(mouse(MOUSE_BUTTON_LEFT,true)); game._input(mouse(MOUSE_BUTTON_LEFT,false)); step()
		ck(results.size()==count and b.hp==b.MAX_HEALTH-count*roundi(b.BASE_MAX_HEALTH*game.Outlaw.DETONATION_HEALTH_FRACTION*b.DAMAGE_SCALE),"The click fires exactly the available stack count with aimed damage")
		ck(not game.outlaw_aim_test.enabled and not game.outlaw_aim_test.reticle.visible,"The final confirmed shot automatically exits aiming")
		ck(game.movement_controls.right and game.has_capture_origin,"Automatic exit preserves the player's held right-click")
		for index in range(1,results.size()): ck(results[index].time-results[index-1].time>=.13-.00001 and results[index].time-results[index-1].time<.15,"Rendered-frame scheduling respects the 130ms shot interval")
		game._input(mouse(MOUSE_BUTTON_RIGHT,false))
		ck(not game.movement_controls.right,"Mouse release still clears the preserved hold")
	await prepare(3)
	game.send_action(game.assignment.find(8)); for frame in 20: step()
	game._input(mouse(MOUSE_BUTTON_LEFT,true)); for frame in 36: step()
	step(.3); step(.016)
	ck(game.outlaw_aim_test.fire_sent==2 and results.size()==2,"A frame stall cannot compress the remaining local shot effects into adjacent frames")
	step(.13)
	ck(results.size()==3 and not game.outlaw_aim_test.enabled,"Burst completes normally after a frame stall")
	await prepare(0)
	game.send_action(game.assignment.find(8)); for frame in 20: step()
	game._input(mouse(MOUSE_BUTTON_LEFT,true)); for frame in 36: step()
	ck(results.is_empty() and game.outlaw_aim_test.enabled,"No stacks leaves aiming available but fires no free shot")
	await prepare(3)
	game.send_action(game.assignment.find(8)); for frame in 20: step()
	game._input(mouse(MOUSE_BUTTON_LEFT,true)); for frame in 36: step()
	game.application_focused=false; step()
	for frame in 20: step()
	ck(results.size()==1 and game.outlaw_detonation.bursts.is_empty() and not game.outlaw_aim_test.enabled,"Focus loss cancels remaining shots and clears the aiming state")
	await prepare(3)
	game.send_action(game.assignment.find(8)); for frame in 20: step()
	game._input(mouse(MOUSE_BUTTON_LEFT,true)); for frame in 15: step()
	game.send_action(game.assignment.find(8)); for frame in 45: step()
	ck(results.is_empty() and a.identity.defense_detonation == 3 and a.gcd == 0 and not game.aimed_combat.tracking.active(1),"Leaving aim during charge cancels the pending shot without spending stacks or GCD")
	game.send_action(game.assignment.find(8)); for frame in 20: step()
	game._input(mouse(MOUSE_BUTTON_LEFT,true)); for frame in 35: step()
	ck(results.is_empty(),"Reentering aim cannot reuse a canceled charge")
	step(); ck(results.size() == 1,"Reentered aim fires after its own complete trigger charge")
	game.clear_actors(); game.queue_free(); await process_frame
	print("Outlaw detonation input checks: %d passed / %d total" % [checks-failures,checks])
	quit(1 if failures else 0)
