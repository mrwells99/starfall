extends Node3D
## Run this scene for an interactive, same-camera corner A/B. No match is started.

const Graphics = preload("res://scripts/sanctum_graphics.gd")
var arena: Node3D
var camera: Camera3D
var corner: Node3D
var _status: Label
var _high: CheckButton
var _target := Vector3(-7, 1.5, 5.1)
var _distance := 11.77
var _yaw := 0.682
var _pitch := 0.374
var _dragging := false

func _ready() -> void:
	arena = load("res://arena.tscn").instantiate()
	add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.set_process_input(false)
	arena.set_process_unhandled_input(false)
	arena.set_process_unhandled_key_input(false)
	arena.get("ui").hide()
	corner = arena.get_node("CosmicSanctum/QualitySlice/CornerUpgrade")
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 58
	camera.current = true
	_build_controls()
	_set_view(0)
	_high.button_pressed = RenderingServer.get_current_rendering_method() == "forward_plus"
	Graphics.apply(arena, _high.button_pressed)
	_refresh_status()

func _build_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var margin := MarginContainer.new()
	margin.position = Vector2(24, 24)
	canvas.add_child(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.065, 0.94)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := Label.new()
	title.text = "SANCTUM · THE ASTRAL ARENA"
	title.add_theme_font_size_override("font_size", 21)
	column.add_child(title)
	var description := Label.new()
	description.text = "Weathered stone · patinated bronze · celestial armillaries"
	description.modulate = Color("aeb9c9")
	column.add_child(description)
	var corner_toggle := CheckButton.new()
	corner_toggle.text = "Upgraded arena"
	corner_toggle.button_pressed = corner.enabled
	corner_toggle.toggled.connect(func(on: bool): corner.set_enabled(on))
	column.add_child(corner_toggle)
	_high = CheckButton.new()
	_high.text = "High lighting"
	_high.disabled = RenderingServer.get_current_rendering_method() != "forward_plus"
	_high.toggled.connect(func(on: bool):
		Graphics.apply(arena, on)
		_refresh_status())
	column.add_child(_high)
	var views := HBoxContainer.new()
	column.add_child(views)
	var names := ["Corner", "Stonework", "Wall shrine", "Arena"]
	for index in range(names.size()):
		var button := Button.new()
		button.text = names[index]
		button.pressed.connect(_set_view.bind(index))
		views.add_child(button)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color("aeb9c9")
	column.add_child(_status)
	var help := Label.new()
	help.text = "Drag to orbit · Scroll to zoom"
	help.add_theme_font_size_override("font_size", 13)
	column.add_child(help)

func _refresh_status() -> void:
	_status.text = "Forward+ · " + ("High lighting" if _high.button_pressed else "Base lighting") \
		if RenderingServer.get_current_rendering_method() == "forward_plus" \
		else "Compatibility · High lighting available in the Forward+ preview"

func _set_view(index: int) -> void:
	var eyes := [Vector3(-0.1,5.8,13.6), Vector3(-2.8,3.1,9.8),
		Vector3(-10,4.6,17), Vector3(27,23,31)]
	var targets := [Vector3(-7,1.5,5.1), Vector3(-6,2.0,5.8),
		Vector3(-17.7,2.5,12.5), Vector3(-2,0,0)]
	_target = targets[index]
	var offset: Vector3 = eyes[index] - _target
	_distance = offset.length()
	_yaw = atan2(offset.x, offset.z)
	_pitch = asin(offset.y / _distance)
	_update_camera()

func _update_camera() -> void:
	camera.position = _target + Vector3(sin(_yaw) * cos(_pitch),
		sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.look_at(_target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(3.0, _distance * 0.9)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(65.0, _distance * 1.1)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.006, 0.04, 1.35)
		_update_camera()
