extends RefCounted

# Everything the player can change about their own client: display settings,
# keybinds, hotbar assignments and HUD layout. One file, because these are all
# "my machine, my preferences" and splitting them would mean four load paths
# that can each fail differently.
#
# Never authoritative for anything the server cares about. A corrupt or absent
# config must degrade to defaults, never to a broken client, so every read is
# defaulted and the file is only rewritten on an explicit save.

const PATH := "user://starfall.cfg"

const WINDOW_WINDOWED := 0
const WINDOW_BORDERLESS := 1
const WINDOW_EXCLUSIVE := 2

# Offered in the resolution picker. Anything larger than the player's monitor is
# filtered out at build time rather than listed and then rejected.
const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

var data := ConfigFile.new()

func load_config() -> void:
	# A missing file is the normal first-run case, not an error.
	data.load(PATH)

func save_config() -> void:
	data.save(PATH)

func get_value(section: String, key: String, fallback):
	return data.get_value(section, key, fallback)

func set_value(section: String, key: String, value) -> void:
	data.set_value(section, key, value)

# --- display ------------------------------------------------------------------

func window_mode() -> int:
	return int(get_value("display", "window_mode", WINDOW_BORDERLESS))

func resolution() -> Vector2i:
	var stored = get_value("display", "resolution", Vector2i.ZERO)
	return stored if stored is Vector2i else Vector2i.ZERO

func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match window_mode():
		WINDOW_EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WINDOW_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := resolution()
			if size.x > 0 and size.y > 0:
				DisplayServer.window_set_size(size)
				# Re-centre, or a window larger than the previous one can end up
				# with its title bar off the top of the screen.
				var screen := DisplayServer.screen_get_size()
				DisplayServer.window_set_position((screen - size) / 2)

# Resolutions that actually fit the player's monitor.
static func available_resolutions() -> Array:
	if DisplayServer.get_name() == "headless":
		return RESOLUTIONS.duplicate()
	var screen := DisplayServer.screen_get_size()
	var out: Array = []
	for res in RESOLUTIONS:
		if res.x <= screen.x and res.y <= screen.y:
			out.append(res)
	if out.is_empty():
		out.append(Vector2i(1280, 720))
	return out
