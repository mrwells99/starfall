extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Art checks require a rendering window.")
		quit(1)
		return
	# The project now launches fullscreen, which would make the window size — and
	# therefore mouse coordinates and screenshot framing — depend on whoever's
	# monitor is running the suite. Pin it.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	arena.mode_choice.select(1)
	arena.local_match()
	arena.set_physics_process(false)
	arena.phase = "match"
	var actor = arena.actors[arena.local_id]
	arena.update_visuals(0)
	await create_timer(0.3).timeout
	for slot in range(7):
		var art: TextureRect = arena.ability_images[slot]
		check(art.texture != null, "Ember art loads: " + actor.kit[slot].name)
		check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Art passes input to ability button")
		check(art.get_index() < arena.cooldown_overlays[slot].get_index(), "Cooldown renders above art")
		check(Rect2(Vector2.ZERO, arena.ui.size).encloses(arena.ability_buttons[slot].get_global_rect()), "Slot fits viewport")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ember-icons-ready.png")
	actor.cooldowns[1] = 5.8
	actor.cooldowns[4] = 18.0
	actor.gcd = 0.9
	arena.update_visuals(0)
	check(arena.ability_images[1].visible and arena.cooldown_overlays[1].label.visible, "Art persists beneath countdown")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ember-icons-cooldowns.png")
	actor.cooldowns.fill(0.0)
	actor.gcd = 0.0
	actor.champion = "Luminary"
	actor.kit = arena.Kits.get_kit("Luminary")
	arena.update_visuals(0)
	check(arena.ability_images[0].texture == arena.AbilityArt.texture_for("Smite"), "Champion change replaces previous art")
	check(arena.ability_buttons[0].text.is_empty(), "Illustrated ability leaves the center clear")
	actor.champion = "Vanguard"
	actor.kit = arena.Kits.get_kit("Vanguard")
	arena.update_visuals(0)
	check(arena.ability_images[5].texture == arena.AbilityArt.texture_for("Mend"), "Vanguard shares Mend")
	for champion in arena.Kits.NAMES:
		actor.champion = champion
		actor.kit = arena.Kits.get_kit(champion)
		arena.update_visuals(0)
		for slot in range(7):
			var tex: Texture2D = arena.ability_images[slot].texture
			# A champion may legitimately be awaiting art. Assert the two states
			# precisely instead of demanding every ability be illustrated:
			# illustrated abilities show an optimized texture, and unillustrated
			# ones must fall back to the ability name rather than an empty slot.
			if arena.AbilityArt.PATHS.has(actor.kit[slot].name):
				check(tex != null and tex.get_width() <= 256,
					champion + " has optimized art: " + actor.kit[slot].name)
			else:
				check(tex == null and arena.ability_buttons[slot].text == actor.kit[slot].name,
					champion + " falls back to text: " + actor.kit[slot].name)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/" + champion.to_lower() + "-hotbar.png")
	check(arena.AbilityArt.texture_for("Future ability") == null, "Unknown ability safely falls back")
	# Model poses are presentation only: collision and combat transform stay put.
	for fighter in arena.actors.values():
		var before: Transform3D = fighter.transform
		fighter.casting = 0
		fighter.visual_tick(0.1, arena.camera)
		check(fighter.champion_model.left_arm.rotation.x < -0.5, "Casting poses the arm")
		fighter.casting = -1
		fighter.hp = 0
		fighter.visual_tick(0.4, arena.camera)
		check(fighter.champion_model.rotation.x < -1.0, "Defeated model falls")
		check(fighter.transform == before, "Visual poses never move the combat body")
		var collider: CollisionShape3D = fighter.get_child(0)
		check(is_equal_approx(collider.shape.radius, 0.42) and is_equal_approx(collider.shape.height, 1.8), "Art preserves collision dimensions")
		fighter.hp = 100
		fighter.visual_tick(0.4, arena.camera)
		check(is_zero_approx(fighter.champion_model.rotation.x), "Living pose recovers")
	print("Ability art checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
