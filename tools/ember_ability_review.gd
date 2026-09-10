extends SceneTree
## Passive secondary-screen review; never captures mouse or drives OS input.
var game
var ember
var elapsed := 0.0
var stage := -1
var label: Label
var expiry_captured := false

func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 30
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.mode = 1
	game.roster = {1: {"champion": "Ember", "team": 0}, 2: {"champion": "Vanguard", "team": 1}}
	game.begin_round()
	game.phase = "match"
	game.fps_toggle.set_pressed_no_signal(false)
	ember = game.actors[1]
	ember.position = Vector3(0, .025, 2)
	ember.rotation.y = 0
	game.actors[2].position = Vector3(0, .025, -1)
	game.selected_id = -1
	for actor in game.actors.values(): actor.reset_physics_interpolation()
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 14
	game.camera.global_position = Vector3(8, 14, 14)
	game.camera.look_at(Vector3(0, 0, 0))
	game.camera.make_current()
	# Arena loads the user's window preferences during setup. Override only this
	# review's live window afterwards; never save these settings.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(0)
	DisplayServer.window_set_size(Vector2i(1280, 900))
	DisplayServer.window_set_position(DisplayServer.screen_get_position(0) + Vector2i(30, 40))
	DisplayServer.window_set_title("Starfall — Ember cone and Blink review")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 70)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
	game.update_visuals(0)

func _process(delta: float) -> bool:
	if ember == null: return false
	elapsed += delta
	for actor in game.actors.values(): game.tick_actor(actor, delta)
	game.update_visuals(delta)
	var next := int(elapsed / 2.0)
	if next >= 3:
		print("EMBER VISUAL REVIEW COMPLETE")
		quit()
		return false
	if next != stage:
		stage = next
		if stage > 0:
			game.try_spell(1, 6, -1, PI / 2 if stage == 1 else -PI / 2)
			# Keep this static review composed around the same aiming area.
			ember.position = Vector3(0, .025, 2)
			ember.reset_physics_interpolation()
		if stage == 2: game.try_spell(1, 8, -1)
		game.update_visuals(0)
		label.text = "Solar Flare — 4m aimed cone\nBlink — %d charges%s" % [ember.identity.blink_charges, " · recharge in progress" if stage > 0 else ""]
		capture(stage)
	if stage == 2 and elapsed > 5.1 and not expiry_captured:
		expiry_captured = true
		capture(3)
	return false

func capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/ember-review")
	var filename := "cone-expired.png" if index == 3 else "%d-charges.png" % (2 - index)
	root.get_texture().get_image().save_png("res://artifacts/ember-review/" + filename)
