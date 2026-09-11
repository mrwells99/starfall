extends RefCounted

const MOUSE_FLAG := 1 << 30
const MOVEMENT := ["forward", "backward", "strafe_left", "strafe_right", "turn_left", "turn_right", "jump", "autorun", "walk", "recenter_camera"]
var mouse_held: Dictionary = {}
var suppressed: Dictionary = {}

const DEFAULTS := {
	"forward": [KEY_W, 0], "backward": [KEY_S, 0],
	"strafe_left": [KEY_A, 0], "strafe_right": [KEY_D, 0],
	"turn_left": [KEY_Q, 0], "turn_right": [KEY_E, 0], "jump": [KEY_SPACE, 0],
	"autorun": [KEY_NUMLOCK, 0], "walk": [0, 0], "recenter_camera": [KEY_HOME, 0],
	"target_next": [KEY_TAB, 0], "target_previous": [KEY_TAB | KEY_MASK_SHIFT, 0],
	"party_1": [KEY_F1, 0], "party_2": [KEY_F2, 0], "party_3": [KEY_F3, 0],
	"set_focus": [KEY_F, 0], "target_focus": [KEY_G, 0],
	"target_arena_1": [0, 0], "target_arena_2": [0, 0], "target_arena_3": [0, 0],
	"focus_arena_1": [0, 0], "focus_arena_2": [0, 0], "focus_arena_3": [0, 0],
	"chat": [KEY_ENTER, KEY_KP_ENTER], "challenge": [KEY_C, 0], "accept_duel": [KEY_Y, 0],
}
const LABELS := {
	"forward": "Move forward", "backward": "Move backward",
	"strafe_left": "Strafe left", "strafe_right": "Strafe right",
	"turn_left": "Turn left", "turn_right": "Turn right",
	"jump": "Jump", "target_next": "Target next enemy", "target_previous": "Target previous enemy",
	"autorun": "Toggle autorun", "walk": "Toggle walk / run", "recenter_camera": "Recenter camera",
	"party_1": "Target party member 1 (self)", "party_2": "Target party member 2", "party_3": "Target party member 3",
	"target_arena_1": "Target arena 1", "target_arena_2": "Target arena 2", "target_arena_3": "Target arena 3",
	"focus_arena_1": "Focus arena 1", "focus_arena_2": "Focus arena 2", "focus_arena_3": "Focus arena 3",
	"chat": "Open chat", "set_focus": "Set focus", "target_focus": "Target focus", "challenge": "Challenge to duel", "accept_duel": "Accept duel",
}
var actions: Dictionary = DEFAULTS.duplicate(true)
var secondary: Array = []

func setup(total: int) -> void:
	secondary.resize(total)
	secondary.fill(0)

func value(game, action: String, column: int) -> int:
	if action.begins_with("bar_"):
		var slot := int(action.trim_prefix("bar_"))
		return int(game.binds[slot] if column == 0 else secondary[slot])
	return int(actions[action][column])

func put(game, action: String, column: int, code: int) -> void:
	if action.begins_with("bar_"):
		var slot := int(action.trim_prefix("bar_"))
		if column == 0:
			game.binds[slot] = code
		else:
			secondary[slot] = code
	else:
		actions[action][column] = code

func rows(game) -> Array:
	var out: Array = actions.keys()
	for slot in range(game.TOTAL_SLOTS):
		out.append("bar_%d" % slot)
	return out

static func reserved(code: int) -> bool:
	if code & MOUSE_FLAG:
		return (code & KEY_CODE_MASK) not in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
	return (code & KEY_CODE_MASK) in [KEY_ESCAPE, KEY_F11] or code == (KEY_ENTER | KEY_MASK_ALT)

static func label(code: int) -> String:
	if code == 0: return "Unbound"
	if not code & MOUSE_FLAG: return OS.get_keycode_string(code)
	var prefix := ""
	for pair in [[KEY_MASK_CTRL, "Ctrl+"], [KEY_MASK_ALT, "Alt+"], [KEY_MASK_SHIFT, "Shift+"], [KEY_MASK_META, "Meta+"]]:
		if code & pair[0]: prefix += pair[1]
	return prefix + {MOUSE_BUTTON_MIDDLE: "Middle mouse", MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}.get(code & KEY_CODE_MASK, "Mouse")

func suppress_held_movement() -> void:
	for action in MOVEMENT:
		for binding in actions[action]:
			if not binding & MOUSE_FLAG and binding != 0 and Input.is_physical_key_pressed(binding & KEY_CODE_MASK): suppressed[binding] = true

func apply_preset(game, classic: bool) -> String:
	var preset := {"forward": KEY_W, "backward": KEY_S, "strafe_left": KEY_Q if classic else KEY_A, "strafe_right": KEY_E if classic else KEY_D, "turn_left": KEY_A if classic else KEY_Q, "turn_right": KEY_D if classic else KEY_E}
	for action in rows(game):
		if preset.has(action): continue
		for col in range(2):
			if value(game, action, col) in preset.values():
				return "Preset not applied: %s is already used by %s. Rebind it first." % [label(value(game, action, col)), action]
	for action in preset:
		actions[action][0] = preset[action]
		if actions[action][1] in preset.values(): actions[action][1] = 0
	game.refresh_binds()
	game.save_layout()
	return "Movement preset applied. Other bindings and action bars are preserved."

# Conflicts swap, just like the original bar editor. Both menus share this path.
func assign(game, action: String, column: int, code: int) -> String:
	if reserved(code):
		return "Left/right mouse and the wheel control the camera. Escape, F11 and Alt+Enter are also reserved."
	var previous := value(game, action, column)
	for other in rows(game):
		for col in range(2):
			if code != 0 and (other != action or col != column) and value(game, other, col) == code:
				put(game, other, col, previous)
	put(game, action, column, code)
	game.refresh_binds()
	return "Binding saved. Conflicting bindings swap places."

func matches(action: String, code: int) -> bool:
	return code != 0 and actions[action].has(code)

# Holding Shift does not suppress Jump unless that exact chord is assigned.
func matches_jump(game, code: int) -> bool:
	if matches("jump", code): return true
	if not code & KEY_MASK_SHIFT or not matches("jump", code & ~KEY_MASK_SHIFT): return false
	for pair in actions.values():
		if pair.has(code): return false
	return not game.binds.has(code) and not secondary.has(code)

func held(action: String) -> float:
	for binding in actions[action]:
		var code: int = binding & KEY_CODE_MASK
		var down: bool = mouse_held.has(code) and Input.is_mouse_button_pressed(code) if binding & MOUSE_FLAG else Input.is_physical_key_pressed(code)
		if not down: suppressed.erase(binding)
		if code == 0 or not down or suppressed.has(binding):
			continue
		if binding & KEY_MASK_SHIFT and not Input.is_physical_key_pressed(KEY_SHIFT):
			continue
		if binding & KEY_MASK_CTRL and not Input.is_physical_key_pressed(KEY_CTRL):
			continue
		if binding & KEY_MASK_ALT and not Input.is_physical_key_pressed(KEY_ALT):
			continue
		if binding & KEY_MASK_META and not Input.is_physical_key_pressed(KEY_META):
			continue
		return 1.0
	return 0.0

func save(config) -> void:
	config.set_value("controls", "actions", actions)
	config.set_value("controls", "bar_secondary", secondary)

func load_from(config) -> void:
	actions = DEFAULTS.duplicate(true)
	var saved = config.get_value("controls", "actions", {})
	if saved is Dictionary:
		for action in actions:
			var pair = saved.get(action, [])
			if pair is Array and pair.size() == 2:
				for col in range(2):
					if pair[col] is int and pair[col] >= 0 and not reserved(pair[col]):
						actions[action][col] = pair[col]
	var alt = config.get_value("controls", "bar_secondary", [])
	if alt is Array and alt.size() == secondary.size():
		for slot in range(secondary.size()):
			secondary[slot] = alt[slot] if alt[slot] is int and alt[slot] >= 0 and not reserved(alt[slot]) else 0
