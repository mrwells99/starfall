extends SceneTree

var arena
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func point_mouse(point: Vector2) -> void:
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)

func mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func shift_drag(from: Vector2, to: Vector2) -> void:
	for step in [[from, true], [to, false]]:
		var e := InputEventMouseButton.new()
		e.position = step[0]
		e.global_position = step[0]
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = step[1]
		e.shift_pressed = true
		point_mouse(step[0])
		arena.handle_shift_drag(e)

func click(point: Vector2) -> void:
	point_mouse(point)
	mouse_button(point, MOUSE_BUTTON_LEFT, true)
	mouse_button(point, MOUSE_BUTTON_LEFT, false)
	await process_frame
	arena.update_visuals(0)

func key_event(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI tests require a game window; run without --headless.")
		quit(1)
		return
	# The project now launches fullscreen, which would make the window size — and
	# therefore mouse coordinates and screenshot framing — depend on whoever's
	# monitor is running the suite. Pin it.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	Input.use_accumulated_input = false
	arena = load("res://arena.tscn").instantiate()
	root.add_child(arena)
	# HUD positions persist in user://, so a previous run — or a real player's
	# saved layout on a dev machine — could move frames out from under this
	# suite's click coordinates. Start from the shipped layout every time.
	arena.register_movable_frames()
	arena.reset_layout()
	arena.mode_choice.select(1)
	arena.local_match()
	arena.set_physics_process(false)
	arena.phase = "match"
	arena.actors[1].position = Vector3(0, 0, 8)
	arena.actors[4].position = Vector3(0, 0, -2)
	arena.update_visuals(0)
	await create_timer(0.4).timeout
	await physics_frame
	await process_frame
	arena.update_visuals(0)
	var original: int = arena.selected_id
	var own_point: Vector2 = arena.camera.unproject_position(arena.actors[1].position + Vector3.UP)
	var enemy_point: Vector2 = arena.camera.unproject_position(arena.actors[4].position + Vector3.UP)
	await click(own_point)
	check(arena.selected_id == original, "Clicking own model does not target self")
	arena.selected_id = 1
	await click(enemy_point)
	check(arena.selected_id == 1, "Clicking enemy model does not change target")
	arena.selected_id = -1
	await click(enemy_point)
	check(arena.selected_id == -1, "Clicking a model does not acquire a cleared target")
	arena.selected_id = 4
	for attempt in range(3):
		point_mouse(own_point)
		mouse_button(own_point, MOUSE_BUTTON_LEFT, true)
		mouse_button(own_point, MOUSE_BUTTON_RIGHT, true)
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Both-button movement still captures mouse")
		mouse_button(own_point, MOUSE_BUTTON_LEFT, false)
		mouse_button(own_point, MOUSE_BUTTON_RIGHT, false)
		check(arena.selected_id == 4, "Repeated both-button movement preserves target")
	arena.update_visuals(0)
	await click(arena.player_frame.get_global_rect().get_center())
	check(arena.selected_id == 1, "Clicking player health frame selects self")
	await click(arena.party_buttons[1].get_global_rect().get_center())
	check(arena.selected_id == 2, "Clicking party frame selects ally")
	await click(arena.enemy_buttons[1].get_global_rect().get_center())
	check(arena.selected_id == 5, "Clicking enemy frame selects enemy")
	arena.focus_id = 4
	arena.update_visuals(0)
	await process_frame
	await click(arena.focus_frame.get_global_rect().get_center())
	check(arena.selected_id == 4, "Clicking focus frame selects focused actor")
	key_event(KEY_TAB)
	await process_frame
	key_event(KEY_TAB, false)
	check(arena.selected_id == 5, "Tab cycles enemy targets")
	key_event(KEY_F1)
	await process_frame
	key_event(KEY_F1, false)
	check(arena.selected_id == 1, "Friendly targeting keybind still works")
	arena.update_visuals(0)
	point_mouse(arena.ability_buttons[0].get_global_rect().get_center())
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.visible, "Hover shows custom tooltip")
	# One hover, everything on it. There is no Shift variant any more.
	var hovered: String = arena.ability_tooltip.label.text
	check(hovered.contains("Deal 16"), "Hover gives the effect description")
	check(hovered.contains("Cooldown") and hovered.contains("Range") and hovered.contains("Cost"),
		"Hover carries cast, range, cooldown and cost")
	check(hovered.contains("Instant") or hovered.contains("cast"), "Hover states cast time")
	check(not hovered.contains("Shift"), "Tooltip no longer advertises a Shift variant")
	await process_frame
	await process_frame
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.size.y < 220, "Tooltip stays compact after layout")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/tooltip-short.png")
	key_event(KEY_SHIFT)
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.label.text == hovered, "Holding Shift changes nothing")
	key_event(KEY_SHIFT, false)
	arena.panel.show()
	arena.update_ability_tooltip()
	check(not arena.ability_tooltip.visible, "Opening menu hides tooltip")
	arena.panel.hide()
	arena.capture_mouse()
	arena.update_ability_tooltip()
	check(not arena.ability_tooltip.visible, "Mouse-look hides tooltip")
	arena.release_mouse()
	for champion in arena.Kits.NAMES:
		for ability in arena.Kits.get_kit(champion):
			var text: String = arena.Kits.description(ability, champion)
			check(not arena.Kits.summary(ability).is_empty() and text.contains("Cooldown"),
				"Description coverage: " + ability.name)
			arena.ability_tooltip.present(ability, champion, Vector2(1100, 740), arena.ui.size)
			await process_frame
			await process_frame
			arena.ability_tooltip.present(ability, champion, Vector2(1100, 740), arena.ui.size)
			check(Rect2(Vector2.ZERO, arena.ui.size).encloses(arena.ability_tooltip.get_global_rect()), "Tooltip fits viewport: " + ability.name)
	# Cooldown sweep: an ability on cooldown shades its slot and shows a number;
	# an off-GCD ability must not be shaded by the global cooldown.
	var me = arena.actors[arena.local_id]
	me.cooldowns[1] = 6.0
	me.gcd = 1.2
	arena.update_visuals(0)
	check(arena.cooldown_overlays[1].remaining > 5.0 and not arena.cooldown_overlays[1].is_gcd,
		"Ability cooldown drives its own sweep")
	check(arena.cooldown_overlays[1].label.visible, "Ability cooldown shows a number")
	check(arena.cooldown_overlays[0].is_gcd and arena.cooldown_overlays[0].remaining > 0.0,
		"Global cooldown sweeps a ready slot")
	check(not arena.cooldown_overlays[0].label.visible, "Global cooldown shows no number")
	check(arena.cooldown_overlays[2].remaining == 0.0, "Off-GCD ability is not swept by the global cooldown")
	me.cooldowns[1] = 0.0
	me.gcd = 0.0
	arena.update_visuals(0)
	check(arena.cooldown_overlays[1].remaining == 0.0, "Sweep clears when the cooldown ends")
	check(arena.CooldownOverlay.format_time(72.0) == "2m" and arena.CooldownOverlay.format_time(12.4) == "13"
		and arena.CooldownOverlay.format_time(3.4) == "3.4", "Countdown formats like OmniCC")
	# --- aura chips on the unit frame -----------------------------------------
	var me2 = arena.actors[arena.local_id]
	me2.stunned = 3.0
	me2.shield = 5.0
	# Real effects carry the ability that applied them; combat_test covers that
	# resolve_spell records it. Set it here so the display can be tested alone.
	me2.stun_from = "Stasis"
	me2.shield_from = "Ward"
	arena.update_visuals(0)
	var strip := arena.player_frame.get_child(4) as HBoxContainer
	var shown := 0
	for chip in strip.get_children():
		if (chip as PanelContainer).visible:
			shown += 1
	check(shown == 2, "Active auras appear as chips on the unit frame")
	var first := strip.get_child(0) as PanelContainer
	var first_row := first.get_child(0) as HBoxContainer
	check(first.has_meta("aura"), "Aura chip carries its data")
	# The stun came from an ability, so the chip shows that ability's icon and
	# the text collapses to just the countdown.
	check((first_row.get_child(0) as TextureRect).visible,
		"Aura chip shows the icon of the ability that caused it")
	check((first_row.get_child(1) as Label).text.contains("s"),
		"Aura chip counts down")
	# Hovering a chip explains the effect.
	point_mouse(first.get_global_rect().get_center())
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.visible and arena.ability_tooltip.label.text.contains("Cannot move"),
		"Hovering an aura describes it")
	me2.stunned = 0
	me2.shield = 0
	me2.stun_from = ""
	me2.shield_from = ""
	arena.update_visuals(0)
	var still := 0
	for chip in strip.get_children():
		if (chip as PanelContainer).visible:
			still += 1
	check(still == 0, "Chips clear when the effects expire")

	# --- edit mode: layout, keybinds, ability assignment ----------------------
	arena.toggle_edit_mode(true)
	check(arena.edit_mode and arena.edit_overlay.visible, "Edit mode shows its overlay")
	check(arena.ability_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Hotbar stops swallowing clicks while editing")
	# Swapping two slots moves the abilities, not the cooldowns underneath.
	var before_first: int = arena.assignment[0]
	var before_last: int = arena.assignment[6]
	arena.swap_slots(0, 6)
	check(arena.assignment[0] == before_last and arena.assignment[6] == before_first,
		"Dragging one slot onto another swaps the abilities")
	check(arena.kit_slot(0) == before_last, "Bar position resolves to the assigned ability")
	arena.swap_slots(0, 6)
	# Rebinding is de-duplicated: taking a key from another slot gives that slot
	# the key it replaced, so no key ever fires two abilities.
	arena.begin_rebind(2)
	check(arena.rebinding == 2, "Clicking a slot starts a rebind")
	arena.finish_rebind(KEY_1)
	check(arena.binds[2] == KEY_1 and arena.binds[0] != KEY_1, "Rebinding steals the key from its old slot")
	check(arena.binds[0] == KEY_3, "The displaced slot inherits the freed key")
	arena.reset_layout()
	check(arena.binds[0] == KEY_1 and arena.binds[2] == KEY_3 and arena.assignment[3] == 3,
		"Reset restores default binds and assignment")
	# --- extra action bars ----------------------------------------------------
	check(arena.ability_buttons.size() == arena.TOTAL_SLOTS and arena.bar_roots.size() == arena.BAR_COUNT,
		"Every bar is built")
	var second: int = arena.BAR_SLOTS * 2
	check(arena.assignment[second] == -1 and arena.binds[second] == 0,
		"Third bar starts empty and unbound")
	check(arena.kit_slot(second) == -1, "An empty slot resolves to no ability")
	# Dragging an ability from bar one onto bar two moves it there.
	arena.swap_slots(0, second)
	check(arena.kit_slot(second) == 0 and arena.kit_slot(0) == -1,
		"An ability can be dragged onto a second bar")
	# The moved slot can then take its own key, independent of bar one.
	arena.begin_rebind(second)
	arena.finish_rebind(KEY_Z)
	check(arena.binds[second] == KEY_Z, "A second-bar slot takes its own keybind")
	arena.reset_layout()
	check(arena.kit_slot(0) == 0 and arena.kit_slot(second) == -1, "Reset clears the extra bars")

	# --- class colours --------------------------------------------------------
	var Kits = load("res://scripts/kits.gd")
	var shades := {}
	for champ in Kits.NAMES:
		shades[Kits.color(champ).to_html()] = champ
	check(shades.size() == Kits.NAMES.size(), "Every champion has a distinct class colour")
	arena.update_visuals(0)
	var bar_fill := (arena.player_frame.get_child(1) as ProgressBar).get_theme_stylebox("fill") as StyleBoxFlat
	check(bar_fill.bg_color == Kits.color(arena.actors[arena.local_id].champion),
		"The health bar is filled with the champion's class colour")
	# The team border is an overlay drawn over the fill, so it is visible at any
	# health rather than only where the bar is empty.
	var own_edge: StyleBoxFlat = arena.bar_edge(arena.player_frame.get_child(1)).get_theme_stylebox("panel")
	check(own_edge.border_color == arena.BLUE, "The border still says which side they are on")
	arena.toggle_edit_mode(false)
	check(not arena.edit_mode and not arena.edit_overlay.visible, "Done leaves edit mode")
	check(arena.ability_buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP, "Hotbar is clickable again")

	# A malformed saved assignment must be refused whole, not half-applied —
	# a duplicate entry would make one ability unreachable.
	arena.config.set_value("hud", "assignment", [0, 0, 1, 2, 3, 4, 5])
	arena.load_layout()
	var default_order := true
	for i in range(7):
		if arena.assignment[i] != i:
			default_order = false
	check(default_order, "A duplicated assignment is rejected")
	arena.config.set_value("hud", "assignment", [])

	# --- roster rows are real bars -------------------------------------------
	arena.update_visuals(0)
	var ally = arena.actors[arena.party_ids()[1]]
	ally.hp = 40.0
	arena.update_visuals(0)
	var ally_bar: ProgressBar = arena.roster_bar(arena.party_buttons[1])
	check(ally_bar != null and ally_bar.value == 40.0, "Party rows show health as a bar, not a number")
	check((ally_bar.get_child(0) as Label).text.contains("40 HP"), "The bar still carries the readable numbers")
	var ally_fill := ally_bar.get_theme_stylebox("fill") as StyleBoxFlat
	check(ally_fill.bg_color == Kits.color(ally.champion), "Roster bars use the class colour")
	var foe_id: int = arena.enemy_ids()[0]
	arena.actors[foe_id].hp = 85.0
	arena.update_visuals(0)
	var foe_bar: ProgressBar = arena.roster_bar(arena.enemy_buttons[0])
	check(foe_bar.value == 85.0, "Enemy rows track health too")
	var foe_edge: StyleBoxFlat = arena.bar_edge(foe_bar).get_theme_stylebox("panel")
	var ally_edge: StyleBoxFlat = arena.bar_edge(ally_bar).get_theme_stylebox("panel")
	check(foe_edge.border_color == arena.ENEMY_EDGE and foe_edge.border_width_left > ally_edge.border_width_left,
		"Enemies carry a heavier red border than allies")
	# The border is drawn over the fill, so it survives at full health.
	arena.actors[foe_id].hp = 100.0
	arena.update_visuals(0)
	check(arena.bar_edge(foe_bar).visible and (arena.bar_edge(foe_bar).get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 3,
		"The enemy border is still there at full health")

	# --- shift-drag rearranges bars outside edit mode --------------------------
	arena.reset_layout()
	check(not arena.edit_mode, "Shift-drag does not require edit mode")
	var far: int = arena.BAR_SLOTS * 2
	var from_rect: Vector2 = arena.ability_buttons[0].get_global_rect().get_center()
	var to_rect: Vector2 = arena.ability_buttons[far].get_global_rect().get_center()
	shift_drag(from_rect, to_rect)
	check(arena.kit_slot(far) == 0 and arena.kit_slot(0) == -1,
		"Shift-dragging moves an ability onto another bar mid-match")
	# Without shift the same drag must cast, not rearrange.
	arena.reset_layout()
	arena.drag_slot = -1
	var plain := InputEventMouseButton.new()
	plain.position = from_rect
	plain.global_position = from_rect
	plain.button_index = MOUSE_BUTTON_LEFT
	plain.pressed = true
	check(not arena.handle_shift_drag(plain), "A plain click is left alone for the ability to handle")

	# Hovering a slot on another bar must not read past the end of the kit.
	# With three bars there are 21 positions and 7 abilities, and a shift-drag
	# makes the empty ones visible — which is how this crashed.
	arena.reset_layout()
	# Leaving edit mode reopened the menu panel, and the tooltip is suppressed
	# while it is up — without this both hover checks pass for the wrong reason.
	arena.panel.hide()
	arena.drag_slot = 0
	arena.update_visuals(0)
	var empty_slot := arena.ability_buttons[arena.BAR_SLOTS * 2 + 4] as Button
	check(empty_slot.is_visible_in_tree(), "Empty slots are visible while dragging")
	point_mouse(empty_slot.get_global_rect().get_center())
	await process_frame
	arena.update_ability_tooltip()
	check(not arena.ability_tooltip.visible, "Hovering an empty slot shows no tooltip and does not crash")
	arena.swap_slots(0, arena.BAR_SLOTS * 2 + 4)
	arena.update_visuals(0)
	point_mouse(arena.ability_buttons[arena.BAR_SLOTS * 2 + 4].get_global_rect().get_center())
	await process_frame
	arena.update_ability_tooltip()
	check(arena.ability_tooltip.visible and arena.ability_tooltip.label.text.contains("Deal 16"),
		"A slot on another bar describes the ability actually assigned to it")
	arena.drag_slot = -1
	arena.reset_layout()

	# --- personal aura strip, moveable readouts, CC greying -------------------
	arena.panel.hide()
	var self_me = arena.actors[arena.local_id]
	self_me.stunned = 4.0
	self_me.stun_from = "Stasis"
	self_me.shield = 6.0
	self_me.shield_from = "Ward"
	arena.update_visuals(0)
	check(arena.self_auras.visible, "Your own buffs and debuffs get their own strip")
	var strip_shown := 0
	for chip in arena.self_auras.get_children():
		if (chip as PanelContainer).visible:
			strip_shown += 1
	check(strip_shown == 2, "The strip lists every effect on you")
	# Your own nameplate must not repeat what the strip and the readout say.
	var mine_overhead := 0
	for holder in self_me.aura_icons:
		if (holder as Node3D).visible:
			mine_overhead += 1
	check(mine_overhead == 0, "Your own nameplate does not repeat your effects")
	# Everyone else still shows theirs overhead.
	var other = arena.actors[arena.enemy_ids()[0]]
	other.stunned = 3.0
	other.stun_from = "Stasis"
	arena.update_visuals(0)
	var other_overhead := 0
	for holder in other.aura_icons:
		if (holder as Node3D).visible:
			other_overhead += 1
	check(other_overhead > 0, "Other fighters still show their effects overhead")

	# Held slots read as unusable, not merely counting down.
	check(arena.ability_buttons[0].modulate.r < 0.9, "Slots grey out while you are held")
	self_me.stunned = 0.0
	self_me.shield = 0.0
	self_me.stun_from = ""
	self_me.shield_from = ""
	arena.update_visuals(0)
	check(arena.ability_buttons[0].modulate.r >= 0.99, "Slots return to normal once the hold ends")
	check(not arena.self_auras.visible, "The strip hides when nothing is on you")

	# Both readouts are arrangeable.
	arena.register_movable_frames()
	var arrangeable := {}
	for frame in arena.movable_frames:
		arrangeable[frame.name] = true
	check(arrangeable.has("SelfAuras") and arrangeable.has("CrowdControl"),
		"The aura strip and crowd control readout can be moved in Edit HUD")

	# The ghost follows the cursor: motion must be handled before the button guard.
	arena.drag_slot = 0
	arena.show_drag_ghost(0)
	var start: Vector2 = arena.drag_ghost.position
	point_mouse(Vector2(500, 260))
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(500, 260)
	motion.global_position = motion.position
	arena.handle_shift_drag(motion)
	check(arena.drag_ghost.position != start, "The dragged icon follows the cursor")
	arena.drag_slot = -1
	arena.show_drag_ghost(-1)

	# --- modifier keys, slot size, persistence, drag ghost --------------------
	arena.reset_layout()
	# Shift+1, Alt+1 and 1 are three different bindings, not one key.
	var plain_one := InputEventKey.new()
	plain_one.keycode = KEY_1
	var shift_one := InputEventKey.new()
	shift_one.keycode = KEY_1
	shift_one.shift_pressed = true
	var alt_one := InputEventKey.new()
	alt_one.keycode = KEY_1
	alt_one.alt_pressed = true
	var bare_shift := InputEventKey.new()
	bare_shift.keycode = KEY_SHIFT
	var b_plain: int = arena.event_binding(plain_one)
	var b_shift: int = arena.event_binding(shift_one)
	var b_alt: int = arena.event_binding(alt_one)
	check(b_plain != b_shift and b_shift != b_alt and b_plain != b_alt,
		"Modifiers make distinct bindings from the same key")
	check(arena.event_binding(bare_shift) == 0, "A bare modifier is not a binding")
	arena.begin_rebind(3)
	arena.finish_rebind(b_shift)
	check(arena.binds[3] == b_shift, "Shift+1 can be bound to a slot")
	check(OS.get_keycode_string(arena.binds[3]).contains("Shift"), "The bound key reads as Shift+1")
	check(arena.binds[0] == b_plain, "Plain 1 still belongs to its own slot")

	# Slot size, with the default exposed in the settings field.
	check(arena.DEFAULT_SLOT_SIZE == 55, "Slots default to 40% smaller than the original 92px")
	check(arena.slot_size_field != null and arena.slot_size_field.text == str(arena.DEFAULT_SLOT_SIZE),
		"The size field shows the default")
	arena.apply_slot_size(70)
	check(arena.ability_buttons[0].custom_minimum_size.x == 70, "Bars resize to a typed value")
	check(arena.ability_buttons[arena.BAR_SLOTS].custom_minimum_size.x == 70, "Every bar resizes together")
	arena.apply_slot_size(9999)
	check(arena.slot_size == arena.MAX_SLOT_SIZE, "An absurd size is clamped rather than accepted")
	arena.apply_slot_size(arena.DEFAULT_SLOT_SIZE)

	# The drag ghost gives the gesture something visible.
	arena.drag_slot = -1
	arena.show_drag_ghost(0)
	check(arena.drag_ghost.visible and arena.drag_ghost.texture != null, "Dragging shows the icon under the cursor")
	arena.show_drag_ghost(-1)
	check(not arena.drag_ghost.visible, "The ghost is put away when the drag ends")

	# Local play must not inherit world rules.
	arena.world_mode = true
	arena.local_match()
	check(not arena.world_mode, "Local sparring clears world mode")
	check(arena.actors.size() > 1, "Local sparring still fills the other side with bots")

	# --- offline opponent picker ----------------------------------------------
	check(arena.opponent_choice != null, "Offline offers an opponent choice")
	check(arena.opponent_choice.get_item_id(0) == arena.RANDOM_OPPONENT,
		"The random option uses a sentinel that cannot collide with a champion index")
	arena.opponent_choice.select(2)
	arena.mode = 1
	arena.roster = {1: {"champion": "Ember", "team": 0}}
	arena.begin_round()
	var picked := ""
	for a in arena.actors.values():
		if a.team == 1:
			picked = a.champion
	check(picked == Kits.NAMES[arena.opponent_choice.get_selected_id()],
		"The chosen champion is what you spar against")
	arena.opponent_choice.select(0)
	arena.begin_round()
	check(arena.actors.size() == 2, "Random still fills the opposing side")

	# The personal CC readout must be draggable even with no active effect.
	arena.clear_actors()
	arena.toggle_edit_mode(true)
	arena.update_visuals(0)
	await process_frame
	var cc_start: Vector2 = arena.cc_tracker.position
	var cc_point: Vector2 = arena.cc_tracker.get_global_rect().get_center()
	point_mouse(cc_point)
	mouse_button(cc_point, MOUSE_BUTTON_LEFT, true)
	point_mouse(cc_point + Vector2(-150, -100))
	mouse_button(cc_point + Vector2(-150, -100), MOUSE_BUTTON_LEFT, false)
	await process_frame
	check(arena.cc_tracker.position.distance_to(cc_start) > 50, "CC preview moves with a real mouse drag")
	var cc_saved: Vector2 = arena.cc_tracker.position
	arena.toggle_edit_mode(false)
	arena.cc_tracker.position = cc_start
	arena.load_layout()
	check(arena.cc_tracker.position.is_equal_approx(cc_saved), "CC position reloads from the saved HUD layout")

	print("UI checks: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
