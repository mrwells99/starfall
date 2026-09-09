extends RefCounted

const DEFAULTS := {
	"forward": [KEY_W, 0], "backward": [KEY_S, 0],
	"strafe_left": [KEY_A, 0], "strafe_right": [KEY_D, 0],
	"turn_left": [KEY_Q, 0], "turn_right": [KEY_E, 0], "jump": [KEY_SPACE, 0],
	"target_next": [KEY_TAB, 0], "target_previous": [KEY_TAB | KEY_MASK_SHIFT, 0],
	"party_1": [KEY_F1, 0], "party_2": [KEY_F2, 0], "party_3": [KEY_F3, 0],
	"set_focus": [KEY_F, 0], "target_focus": [KEY_G, 0],
	"challenge": [KEY_C, 0], "accept_duel": [KEY_Y, 0],
}
const LABELS := {
	"forward": "Move forward", "backward": "Move backward",
	"strafe_left": "Strafe left", "strafe_right": "Strafe right",
	"turn_left": "Turn left / strafe with right mouse", "turn_right": "Turn right / strafe with right mouse",
	"jump": "Jump", "target_next": "Target next enemy", "target_previous": "Target previous enemy",
	"party_1": "Target party member 1 (self)", "party_2": "Target party member 2", "party_3": "Target party member 3",
	"set_focus": "Set focus", "target_focus": "Target focus", "challenge": "Challenge to duel", "accept_duel": "Accept duel",
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
	return (code & KEY_CODE_MASK) in [KEY_ESCAPE, KEY_F11] or code == (KEY_ENTER | KEY_MASK_ALT)

# Conflicts swap, just like the original bar editor. Both menus share this path.
func assign(game, action: String, column: int, code: int) -> String:
	if reserved(code):
		return "Escape, F11 and Alt+Enter are reserved for the menu and window controls."
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

func held(action: String) -> float:
	for binding in actions[action]:
		var code: int = binding & KEY_CODE_MASK
		if code == 0 or not Input.is_physical_key_pressed(code):
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
