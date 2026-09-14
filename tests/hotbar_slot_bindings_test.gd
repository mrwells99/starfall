extends SceneTree
var game
var checks := 0
var failures := 0
class MemoryConfig extends "res://scripts/user_config.gd":
	func load_config() -> void: pass
	func save_config() -> void: pass
	func apply_display() -> void: pass
class TestArena extends "res://tests/ui_test_arena.gd":
	var dispatched: Array[int] = []
	func try_spell(_id: int, slot: int, _requested: int, _camera_yaw: Variant = null) -> bool:
		dispatched.append(slot)
		return true
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures += 1; push_error(message)
func settle():
	game.update_visuals(0)
	await process_frame
	await process_frame
func press(code: int):
	var event := InputEventKey.new()
	event.pressed = true; event.physical_keycode = code; event.keycode = code
	game._unhandled_input(event)
func run():
	game = TestArena.new(); game.config = MemoryConfig.new(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.roster={1:{"champion":"Null","team":0},2:{"champion":"Ember","team":1}}
	game.begin_round(); game.phase="match"; game.panel.hide()
	game.actors[1].position=Vector3(0,0,4)
	game.begin_rebind(0); game.finish_rebind(KEY_U)
	game.controls.assign(game,"bar_0",1,KEY_I)
	game.begin_rebind(1); game.finish_rebind(KEY_O)
	game.controls.assign(game,"bar_1",1,KEY_P)
	var primary: Array = game.binds.duplicate(); var secondary: Array = game.controls.secondary.duplicate()
	game.swap_slots(0,1)
	check(game.binds==primary and game.controls.secondary==secondary,"Swapping abilities retains both bindings on every slot")
	press(KEY_U); press(KEY_I); press(KEY_O); press(KEY_P)
	check(game.dispatched==[1,1,0,0],"Primary and secondary keys dispatch each slot's new ability, not its original ability")
	await settle()
	var before: Rect2 = game.ability_buttons[1].get_global_rect()
	game.swap_slots(0,20)
	await settle()
	check(game.ability_buttons[1].get_global_rect().is_equal_approx(before),"Emptying an earlier slot cannot slide another slot into its position")
	check(not game.ability_buttons[0].visible,"An empty gameplay slot stays visually hidden")
	game.dispatched.clear(); press(KEY_U); press(KEY_I)
	check(game.dispatched.is_empty(),"An emptied slot's retained keys do not follow its moved ability")
	check(game.binds==primary and game.controls.secondary==secondary,"Moving to another bar retains all primary and secondary slot bindings")
	game.save_layout()
	var saved: String = game.config.data.encode_to_text()
	game.config.data = ConfigFile.new(); game.config.data.parse(saved)
	game.default_bindings(); game.controls.secondary.fill(0); game.load_layout()
	check(game.assignment[20]==1 and game.assignment[0]==-1 and game.assignment[1]==0,"Ability placement survives saved-layout reload")
	check(game.binds==primary and game.controls.secondary==secondary,"Slot bindings survive saved-layout reload independently of abilities")
	game.dispatched.clear();press(KEY_O);press(KEY_P)
	check(game.dispatched==[0,0],"Reloaded bindings cast the ability currently occupying the slot")
	game.queue_free();await process_frame
	print("Hotbar slot binding checks: %d passed / %d total"%[checks-failures,checks])
	quit(1 if failures else 0)
