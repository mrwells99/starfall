extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/lobby.png")
	arena.mode_choice.select(1)
	arena.champion_choice.select(2)
	arena.local_match()
	await create_timer(4).timeout
	arena.selected_id = arena.party_ids()[1]
	arena.actors[arena.selected_id].hp = 40
	arena.send_action(5)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/team-arena.png")
	quit()
