extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://arena.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.2).timeout
	game.menu_state = "settings"
	game.refresh_menu()
	game.keybind_menu.open()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/keybind-menu.png")
	game.keybind_menu.search.text = "action bar"
	game.keybind_menu.rebuild()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/keybind-bars.png")
	quit()
