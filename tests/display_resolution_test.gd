extends SceneTree
const Config = preload("res://scripts/user_config.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var config := Config.new()
	check(Config.available_resolutions()[0] == Vector2i.ZERO, "Native is the first resolution choice")
	check(Vector2i(2560, 1440) in Config.available_resolutions(), "Common 1440p option is available")
	check(config.resolution() == Vector2i.ZERO, "Default fullscreen resolution is native")
	config.set_value("display", "resolution", Vector2i(1280, 720))
	check(config.resolution_scale(Vector2i(2560, 1440)) == 1.0, "Legacy windowed selection does not downsample fullscreen")
	for mode in [Config.WINDOW_BORDERLESS, Config.WINDOW_EXCLUSIVE]:
		config.set_value("display", "window_mode", mode)
		config.set_value("display", "fullscreen_resolution", Vector2i(1920, 1080))
		check(is_equal_approx(config.resolution_scale(Vector2i(2560, 1440)), .75), "Fullscreen 1080p target scales a 1440p output correctly")
		config.set_value("display", "fullscreen_resolution", Vector2i.ZERO)
		check(config.resolution_scale(Vector2i(3840, 2160)) == 1.0, "Native follows a different monitor without a fixed pixel size")
	config.set_value("graphics", "render_scale", .85)
	check(is_equal_approx(config.resolution_scale(Vector2i(2560, 1440)), .85), "User 3D percentage remains an explicit additional multiplier")
	config.set_value("display", "window_mode", Config.WINDOW_WINDOWED)
	check(config.resolution() == Vector2i(1280, 720), "Windowed resolution is preserved separately")
	check(is_equal_approx(config.resolution_scale(Vector2i(1280, 720)), .85), "Windowed output is not downscaled twice")
	config.apply_render_resolution(root)
	check(is_equal_approx(root.scaling_3d_scale, .85), "Render scale reaches the actual viewport")
	print("Display resolution checks: %d passed / %d total" % [checks-failures, checks])
	quit(1 if failures else 0)
