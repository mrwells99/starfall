extends TextureRect
## Isolated, cached portrait render: redraw on selection/visibility only, never
## run combat animation or add a continuously rendered menu scene.
var viewport: SubViewport
var stage: Node3D
var current_model: Node3D
var champion := ""
var enabled := false
var dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Drag left or right to rotate your champion"
	custom_minimum_size = Vector2(240, 320)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	viewport = SubViewport.new()
	viewport.size = Vector2i(480, 640)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	texture = viewport.get_texture()
	stage = Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("151a2c")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("acb9db")
	world.environment.ambient_light_energy = 0.65
	stage.add_child(world)
	for entry in [[Vector3(-25,-30,0), Color("fff1d9"), 1.5], [Vector3(-15,140,0), Color("aaa0ff"), 1.0]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = entry[0]
		light.light_color = entry[1]
		light.light_energy = entry[2]
		light.shadow_enabled = false
		stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.05
	camera.position = Vector3(0, 1.35, 4)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.make_current()
	resized.connect(redraw)
	get_tree().root.size_changed.connect(redraw)

func show_champion(selected: String, active: bool) -> void:
	visible = active
	enabled = active
	if viewport == null: return
	if not active:
		dragging = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if champion != selected:
		champion = selected
		if current_model != null:
			stage.remove_child(current_model)
			current_model.queue_free()
		var asset = load("res://assets/characters/%s.glb" % selected.to_lower()) as PackedScene
		current_model = asset.instantiate()
		stage.add_child(current_model)
		for node in current_model.find_children("*", "AnimationPlayer", true, false):
			node.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for clip in node.get_animation_list():
				if String(clip).get_slice("/", String(clip).count("/")) == "Idle":
					node.play(clip)
					node.advance(0)
					break
	redraw()

func _gui_input(event: InputEvent) -> void:
	if not enabled or current_model == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			dragging = false
			return
		current_model.rotate_y(event.relative.x * 0.01)
		redraw()
		accept_event()

func redraw() -> void:
	if enabled and viewport != null and DisplayServer.get_name() != "headless" and not get_tree().root.disable_3d:
		# Supersample the cached portrait, independently of gameplay render scale.
		# Preserve its aspect ratio when capping resolution on high-DPI displays.
		var pixels := size * get_global_transform_with_canvas().get_scale() * get_tree().root.get_final_transform().get_scale() * 2.0
		pixels *= minf(1.0, 1536.0 / maxf(pixels.x, pixels.y))
		viewport.size = Vector2i(maxi(1, ceili(pixels.x)), maxi(1, ceili(pixels.y)))
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
