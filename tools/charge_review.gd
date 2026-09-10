extends SceneTree
## Short runtime review on the secondary screen; no mouse capture or input.
var game
var a
var b
var label: Label
var time := 0.0
var scenario := -1
var started := false
var moved := false
var captures := 0

func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1000, 760))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(50, 50))
	DisplayServer.window_set_title("Starfall — Charge movement check")
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.ui.hide()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 19)
	layer.add_child(label)
	next_scenario()

func next_scenario() -> void:
	scenario += 1
	if scenario >= 3:
		print("CHARGE REVIEW COMPLETE")
		quit()
		return
	time = 0
	started = false
	moved = false
	captures = 0
	game.mode = 1
	game.roster = {1: {"champion": "Vanguard", "team": 0}, 2: {"champion": "Fulcrum", "team": 1}}
	game.begin_round()
	game.phase = "match"
	game.ui.hide()
	a = game.actors[1]
	b = game.actors[2]
	a.position = [Vector3(0, .025, 6), Vector3(-6, .025, 10), Vector3(10, .025, 0)][scenario]
	b.position = [Vector3(0, .025, -6), Vector3(-1, .025, 6), Vector3(15, 1.225, 0)][scenario]
	a.look_at(Vector3(b.position.x, a.position.y, b.position.z))
	a.reset_physics_interpolation()
	b.reset_physics_interpolation()
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 23
	game.camera.global_position = Vector3(22, 24, 23)
	game.camera.look_at(Vector3(2, 0, 1))
	game.camera.make_current()

func _physics_process(delta: float) -> bool:
	if game == null or scenario >= 3: return false
	time += delta
	if not started and time >= .7:
		started = game.try_spell(1, 6, 2)
	if started and scenario == 1 and time > .78 and not moved:
		moved = true
		b.position = Vector3(-6, .025, 0)
	for actor in [a, b]: game.tick_actor(actor, delta)
	game.update_visuals(delta)
	game.ui.hide()
	label.text = "%s\nCharge: %s    Root: %.1fs    Target HP: %.0f" % [["OPEN APPROACH", "TARGET MOVES BEHIND COVER", "ROUTE UP THE TERRACE RAMP"][scenario], "travelling" if not a.charge.is_empty() else "ready / arrived", b.identity.root, b.hp]
	if "--capture" in OS.get_cmdline_user_args() and not a.charge.is_empty() and captures < 3:
		captures += 1
		capture("%d-%d" % [scenario, captures])
	if time > 3.8: next_scenario()
	return false

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/charge-review")
	root.get_texture().get_image().save_png("res://artifacts/charge-review/" + name + ".png")
