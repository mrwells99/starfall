extends SceneTree

# Render the real game meshes and real imported textures as review boards.
# Run: godot --path . --script tools/art_review.gd
const Kits = preload("res://scripts/kits.gd")
const Art = preload("res://scripts/ability_art.gd")
const Fighter = preload("res://scripts/combatant.gd")
var canvas: Control

func _initialize() -> void:
	call_deferred("run")

func label(text: String, at: Vector2, font_size: int, color: Color = Color("e6e6ee")) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	canvas.add_child(node)
	return node

func icon_row(champion: String, at: Vector2, edge: int, names: bool = true) -> void:
	var kit := Kits.get_kit(champion)
	for i in range(7):
		var art := TextureRect.new()
		art.texture = Art.texture_for(kit[i].name)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.position = at + Vector2(i * (edge + 8), 0)
		art.size = Vector2(edge, edge)
		canvas.add_child(art)
		if names:
			label(kit[i].name, art.position + Vector2(0, edge + 6), 15)

func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Art review needs a rendering window.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("0c0c19")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b6c4ef")
	world.environment.ambient_light_energy = 0.7
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_color = Color("ffe3bb")
	light.light_energy = 1.25
	scene.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("8f95ff")
	fill.light_energy = 0.8
	scene.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.2
	camera.position = Vector3(0, 3.0, 8)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	canvas = Control.new()
	layer.add_child(canvas)
	label("STARFALL", Vector2(48, 30), 20, Color("bc9ae8"))
	label("THE SUMMONED", Vector2(48, 60), 34)
	label("Three worlds. One arena.", Vector2(48, 108), 17, Color("9394ae"))
	var fighters: Array = []
	var subtitles := ["EMBER STAFF / CINDER ROBES", "ASTRAL STEEL / KITE SHIELD", "DAWN HALO / CELESTIAL FEATHERS"]
	for i in range(3):
		var fighter = Fighter.new()
		fighter.setup(i + 1, 1, 0, Kits.NAMES[i])
		scene.add_child(fighter)
		fighter.position = Vector3((i - 1) * 4.2, 0, 0)
		fighter.champion_model.scale = Vector3.ONE * 1.35
		fighter.rotation.y = PI + 0.3
		fighter.nameplate.hide()
		fighter.health_pivot.hide()
		fighter.cast_pivot.hide()
		fighters.append(fighter)
		var x := 48 + i * 410
		label(Kits.NAMES[i].to_upper(), Vector2(x, 567), 25)
		label(subtitles[i], Vector2(x, 603), 12, Color("9394ae"))
		icon_row(Kits.NAMES[i], Vector2(x, 638), 44, false)
	label("Original in-engine models  /  Painted ability illustrations", Vector2(48, 745), 15, Color("9394ae"))
	await capture("res://artifacts/champion-lineup.png")
	# Back view verifies the absolute team-color cloth and silhouette from play camera.
	for fighter in fighters:
		fighter.rotation.y = -0.3
	await capture("res://artifacts/champion-lineup-back.png")
	scene.hide()
	for child in canvas.get_children():
		child.queue_free()
	await process_frame
	label("STARFALL / ABILITY ATLAS", Vector2(48, 25), 26)
	label("20 original icons. 21 ability slots. Shared Mend.", Vector2(48, 62), 16, Color("9394ae"))
	for i in range(3):
		var y := 110 + i * 218
		label(Kits.NAMES[i].to_upper(), Vector2(48, y), 21, Color("bc9ae8"))
		icon_row(Kits.NAMES[i], Vector2(48, y + 36), 128)
	await capture("res://artifacts/ability-atlas.png")
	print("Art review boards saved in artifacts/")
	quit()
