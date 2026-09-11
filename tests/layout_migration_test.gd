extends SceneTree

var arena
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func legacy_layout() -> Dictionary:
	var primary: Array = []
	var assignment: Array = []
	var secondary: Array = []
	for slot in range(arena.TOTAL_SLOTS):
		primary.append(KEY_1 + slot if slot < 7 else ((KEY_1 + slot - 7) | KEY_MASK_SHIFT if slot < 13 else 0))
		assignment.append(slot if slot < 13 else -1)
		secondary.append(0)
	return {"primary": primary, "assignment": assignment, "secondary": secondary, "actions": arena.controls.DEFAULTS.duplicate(true)}

func load_saved_layout(saved: Dictionary) -> void:
	# Exercise the actual saved-config format and migration without touching
	# the player's user:// preferences.
	var serialized := ConfigFile.new()
	serialized.set_value("hud", "binds", saved.primary)
	serialized.set_value("hud", "assignment", saved.assignment)
	serialized.set_value("controls", "bar_secondary", saved.secondary)
	serialized.set_value("controls", "actions", saved.actions)
	arena.config.data = ConfigFile.new()
	check(arena.config.data.parse(serialized.encode_to_text()) == OK, "Legacy layout reloads from the saved config format")
	arena.default_bindings()
	arena.load_layout()
	arena.update_visuals(0)

func run() -> void:
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.set_physics_process(false)
	arena.mode = 1
	arena.roster = {1: {"champion": "Fulcrum", "team": 0}, 2: {"champion": "Vanguard", "team": 1}}
	arena.begin_round()
	arena.phase = "match"
	arena.panel.hide()
	var preferred := KEY_7 | KEY_MASK_SHIFT
	var saved := legacy_layout()
	load_saved_layout(saved)
	check(arena.kit_slot(13) == 13 and arena.binds[13] == preferred, "Uncustomized legacy layout gains Entropy on Shift+7")

	saved = legacy_layout()
	saved.primary[0] = preferred
	load_saved_layout(saved)
	check(arena.binds[0] == preferred and arena.binds[13] == 0, "Existing primary key keeps precedence over Entropy's proposed default")
	check(arena.kit_slot(13) == 13 and arena.ability_buttons[13].visible, "Entropy remains available as a clickable slot when its key is occupied")
	arena.actors[1].position = Vector3.ZERO
	arena.actors[2].position = Vector3(0, 0, -3)
	arena.actors[1].rotation.y = 0
	arena.selected_id = 2
	arena.ability_buttons[13].pressed.emit()
	check(arena.actors[2].identity.entropy_dots.has(1), "Unbound migrated Entropy still casts through its hotbar button")

	saved = legacy_layout()
	saved.secondary[0] = preferred
	load_saved_layout(saved)
	check(arena.controls.secondary[0] == preferred and arena.binds[13] == 0, "Existing secondary shortcut is preserved without a conflicting Entropy key")

	saved = legacy_layout()
	saved.actions.target_next = [preferred, 0]
	load_saved_layout(saved)
	check(arena.controls.actions.target_next[0] == preferred and arena.binds[13] == 0, "Custom targeting shortcut is preserved without also casting Entropy")

	saved = legacy_layout()
	saved.secondary[13] = KEY_F8
	load_saved_layout(saved)
	check(arena.controls.secondary[13] == KEY_F8 and arena.binds[13] == 0, "An existing secondary binding on the empty slot is retained for Entropy")

	saved = legacy_layout()
	for slot in range(13, arena.TOTAL_SLOTS):
		saved.assignment[slot] = 0
	saved.primary[arena.TOTAL_SLOTS - 1] = KEY_F8
	load_saved_layout(saved)
	check(arena.kit_slot(arena.TOTAL_SLOTS - 1) == 13 and arena.binds[arena.TOTAL_SLOTS - 1] == KEY_F8, "Full old layout replaces a duplicate slot while retaining its custom key")
	check(arena.binds.slice(0, 13) == saved.primary.slice(0, 13), "Migrating the new spell preserves the previous thirteen primary bindings")
	saved = legacy_layout()
	load_saved_layout(saved)
	check(arena.assignment.has(14) and arena.binds[arena.assignment.find(14)] == (KEY_1 | KEY_MASK_CTRL),"Legacy bars gain Trinket on Ctrl+1")
	saved = legacy_layout(); saved.primary[0] = KEY_1 | KEY_MASK_CTRL
	load_saved_layout(saved)
	check(arena.binds[0] == (KEY_1 | KEY_MASK_CTRL) and arena.binds[arena.assignment.find(14)] == 0,"Trinket migration preserves a conflicting saved key and remains clickable")
	for title in arena.Kits.NAMES:
		arena.roster={1:{"champion":title,"team":0},2:{"champion":"Ember","team":1}}
		arena.begin_round(); arena.phase="match"; arena.default_bindings(); arena.update_visuals(0)
		check(arena.kit_slot(14)==14 and arena.ability_buttons[14].visible,title+" exposes Trinket on the hotbar")
		if title=="Outlaw": check(arena.kit_slot(12)==12 and arena.ability_buttons[12].visible,"Outlaw exposes Boot Kick without moving existing skills")
	print("Layout migration checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
