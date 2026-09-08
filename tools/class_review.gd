extends SceneTree
var arena
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.champion_choice.select(3)
	arena.local_match()
	arena.set_physics_process(false)
	arena.phase = "match"
	var a = arena.actors[arena.local_id]
	a.position = Vector3(0, 0, 8)
	a.rotation.y = 0
	for i in range(12):
		a.velocity = Vector3(0, -2, 0)
		a.move_and_slide()
		await physics_frame
	arena.resolve_spell(a, 7, a)
	arena.resolve_spell(a, 9, a)
	arena.update_visuals(0)
	await create_timer(1.3).timeout
	a.flash = 0
	arena.update_visuals(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/fulcrum-gravity-ready.png")
	quit()
