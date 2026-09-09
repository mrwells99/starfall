extends "res://scripts/arena_world.gd"

const Fighter = preload("res://scripts/combatant.gd")
const Kits = preload("res://scripts/kits.gd")
const AbilityArt = preload("res://scripts/ability_art.gd")
const Config = preload("res://scripts/config.gd")
# Seconds of global cooldown an ability triggers. The hotbar sweep needs the
# same number the simulation uses, so it lives here rather than inline.
const GCD_DURATION := 1.5
const CooldownOverlay = preload("res://scripts/cooldown_overlay.gd")
const Auras = preload("res://scripts/auras.gd")
const UserConfig = preload("res://scripts/user_config.gd")
# Most fighters carry one or two effects; five is beyond anything the current
# kits can stack, and pooling avoids rebuilding nodes every frame.
const AURA_SLOTS := 5
# Action bars. Seven buttons per row; twelve abilities span two rows. The extra
# bars hold alternate bindings for those same abilities.
const BAR_COUNT := 3
const ClassMechanics = preload("res://scripts/class_mechanics.gd")
const BAR_SLOTS := 7
const TOTAL_SLOTS := BAR_COUNT * BAR_SLOTS
# 40% smaller than the original 92px, and every bar now matches rather than the
# extra bars being arbitrarily smaller than the first.
const DEFAULT_SLOT_SIZE := 55
const MIN_SLOT_SIZE := 28
const MAX_SLOT_SIZE := 140

# --- UI palette ---------------------------------------------------------------
# One place for every colour the interface uses, so the menu, the HUD and the
# hotbar stay in step. Keyed to the cosmic sanctum: void-blue grounds, slate
# structure, and a small number of bright accents that only appear on things the
# player can act on.
const UI_VOID := Color("0b0a16")        # deepest ground, panel fill
const UI_PANEL := Color("141227")       # raised surface
const UI_SURFACE := Color("1d1a35")     # controls at rest
const UI_SURFACE_HI := Color("2b2650")  # controls under the cursor
const UI_EDGE := Color("3b3566")        # ordinary borders
const UI_EDGE_HI := Color("8f7fd4")     # borders that want attention
const UI_TEXT := Color("e8e6f5")
const UI_TEXT_DIM := Color("9a94bd")
const UI_ACCENT := Color("f4c778")      # gold: confirm, primary action
const UI_VIOLET := Color("c9a0ff")      # arcane highlight
const UI_CYAN := Color("6fe3ff")        # ally / friendly
const UI_ROSE := Color("ff7d92")        # enemy / danger

# Fills a StyleBoxFlat so every surface shares one shape language.
func ui_box(fill: Color, edge: Color, radius: int = 6, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box
var actors: Dictionary = {}
var local_id := 1
var selected_id := -1
var focus_id := -1
var phase := "menu"
var mode := 1
var winner := -1
var elapsed := 0.0
var countdown := 0.0
var epoch := 0
var nav = preload("res://scripts/arena_navigation.gd").new()
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var ring: MeshInstance3D
var ui: Control
var panel: PanelContainer
var lobby_text: Label
var result_text: Label
var notice: Label
var scoreboard: Label
var player_frame: VBoxContainer
var target_frame: VBoxContainer
var focus_frame: VBoxContainer
var party_box: VBoxContainer
var party_buttons: Array[Button] = []
var ability_buttons: Array[Button] = []
var ability_images: Array[TextureRect] = []
var cooldown_overlays: Array = []
var champion_choice: OptionButton
var mode_choice: OptionButton
var address: LineEdit
var start_button: Button
var network := false
var roster: Dictionary = {}
var status := ""
var notice_time := 0.0
var snapshot_timer := 0.0
var input_seq := 0
var action_seq := 0
var last_snapshot := -1
var snapshot_seq := 0
var local_yaw := 0.0
var queued_jump := false
var latency_ms := 0
var packets_received := 0
var connected_seconds := 0.0
var ping_timer := 0.0
var round_trip_ms := 0
var exit_button: Button
var resume_button: Button
var enemy_box: VBoxContainer
var enemy_buttons: Array[Button] = []
var ability_tooltip: PanelContainer
var mouse_capture_origin := Vector2.ZERO
var has_capture_origin := false
var dedicated := false
var min_players := Config.DEFAULT_MIN_PLAYERS
var current_port := Config.SERVER_PORT
var remote_min_players := Config.DEFAULT_MIN_PLAYERS
var remote_in_round := false
var rematch_delay := 8.0
var menu_state := "main"
var main_row: HBoxContainer
var offline_row: HBoxContainer
var online_row: HBoxContainer
var queue_row: HBoxContainer
var host_row: HBoxContainer
var join_row: HBoxContainer
var code_field: LineEdit
var config := UserConfig.new()
var controls = preload("res://scripts/key_bindings.gd").new()
var prediction = preload("res://scripts/movement_prediction.gd").new()
var keybind_menu
var match_settings: Button
var controls_help: Label
var settings_row: HBoxContainer
var window_mode_choice: OptionButton
var resolution_choice: OptionButton
# --- edit mode ----------------------------------------------------------------
# HUD layout, keybinds and hotbar assignment are all player-owned client state,
# so they live in the same config file and none of them touch the simulation.
var edit_mode := false
var edit_overlay: Control
var edit_hint: Label
var dragging: Control = null
var drag_offset := Vector2.ZERO
# binds[slot] is the physical keycode that fires that hotbar slot.
var binds: Array[int] = []
# assignment[slot] is which ability of the champion's kit that slot casts. The
# identity mapping is the default; editing it is how a player moves Blink onto
# slot 1 without the server needing to know anything about it.
var assignment: Array[int] = []
var bar_roots: Array[HBoxContainer] = []
var bar_handles: Array[PanelContainer] = []
# Offline only: forces every bot onto one champion so a matchup can be tested
# deliberately instead of whatever the role filler happens to pick.
var opponent_choice: OptionButton
# Must not collide with a champion index. add_item() treats a negative id as
# "use the item's index", so the sentinel has to be a real positive number.
const RANDOM_OPPONENT := 100
# --- world mode ---------------------------------------------------------------
# A persistent hangout on the arena map: no rounds, no timer, no victory. It runs
# as a variant of "match" rather than a new phase, so movement, casting, input
# and snapshots all work unchanged and only the round lifecycle differs.
#
# Damage is refused unless both fighters agreed to a duel, so standing around is
# safe and a fight is always something both people chose.
var world_mode := false
var duels := {}          # actor_id -> actor_id, server-authoritative pairing
var duel_offers := {}    # target_id -> challenger_id, pending invitations
var pending_offer := -1  # client: who has challenged me
var respawn_timers := {}
var rebinding := -1
var drag_slot := -1
var movable_frames: Array[Control] = []
var hotbar_root: HBoxContainer
var default_positions := {}
# Frames the player has dragged. Their position is theirs and is not recomputed.
var moved_frames := {}
var cc_tracker: VBoxContainer
var cc_icon: TextureRect
var cc_sweep: Control
var cc_label: Label
var cc_total := 0.0
var cc_key := ""
var camera_dirty := false
var camera_save_timer := 1.0
var slot_size := DEFAULT_SLOT_SIZE
var slot_size_field: LineEdit
var drag_ghost: TextureRect
var self_auras: HBoxContainer
var size_label: Label
var settings_extra: Array[Control] = []
var lobby_code := ""
var intent := ""
var probe_index := 0
var probe_ports: Array = []
var pending_code := ""
var private_lobby := false
var claimed := false
var requeue_button: Button
var searching := false

func _ready() -> void:
	Input.use_accumulated_input = false
	controls.setup(TOTAL_SLOTS)
	build_arena()
	build_camera()
	build_ui()
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(func(): leave_session("Host disconnected."))
	multiplayer.peer_disconnected.connect(on_peer_left)
	# Rows are shown and hidden by refresh_menu(). Without a first call, the
	# launch screen displayed every submenu at once — Online, Offline, the lobby
	# rows and the code field all stacked on top of each other.
	default_bindings()
	refresh_binds()
	refresh_menu()
	# Only the parts that need a settled layout are deferred; the bind and
	# assignment tables are needed by the very first frame.
	call_deferred("initialise_player_config")
	parse_arguments()

func initialise_player_config() -> void:
	load_settings()
	register_movable_frames()
	apply_slot_size(slot_size)
	# A test run must not inherit the machine's saved HUD. Layout, keybinds and
	# ability assignment all live in user://, so whoever ran the game last would
	# otherwise decide what the suites see — an emptied slot 0 silently breaks
	# every hotbar and combat assertion, with nothing pointing at the cause.
	if running_under_script():
		return
	load_layout()

# True when launched with --script, which is how every suite runs.
static func running_under_script() -> bool:
	return OS.get_cmdline_args().has("--script")

func authoritative() -> bool:
	return not network or multiplayer.is_server()

func build_camera() -> void:
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.6, 9)
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 10
	arm.rotation.x = -0.38
	arm.collision_mask = 1
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	arm.add_child(camera)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.86
	ring.mesh = torus
	ring.material_override = material(GOLD, true)
	add_child(ring)
	ring.hide()

func add_label(parent: Node, text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	# Everything sits on dark, moving art, so text carries its own shadow rather
	# than relying on the background staying dark behind it.
	label.add_theme_color_override("font_color", UI_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 40)
	button.focus_mode = Control.FOCUS_NONE
	style_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

# `primary` marks the one action a screen is really offering — it gets the gold
# edge so a menu reads at a glance instead of presenting a wall of equal buttons.
func style_button(button: Button, primary: bool = false) -> void:
	var edge := UI_ACCENT if primary else UI_EDGE
	button.add_theme_stylebox_override("normal", ui_box(UI_SURFACE, edge))
	button.add_theme_stylebox_override("hover", ui_box(UI_SURFACE_HI, UI_EDGE_HI))
	button.add_theme_stylebox_override("pressed", ui_box(UI_VOID, UI_ACCENT))
	button.add_theme_stylebox_override("disabled", ui_box(UI_PANEL, UI_EDGE))
	button.add_theme_color_override("font_color", UI_ACCENT if primary else UI_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", UI_ACCENT)
	button.add_theme_color_override("font_disabled_color", UI_TEXT_DIM)
	button.add_theme_font_size_override("font_size", 16)

# A one-pixel divider. Cheaper than a texture and it keeps sections apart
# without adding another box.
func style_picker(picker: OptionButton) -> void:
	picker.custom_minimum_size.y = 42
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_theme_stylebox_override("normal", ui_box(UI_SURFACE, UI_EDGE))
	picker.add_theme_stylebox_override("hover", ui_box(UI_SURFACE_HI, UI_EDGE_HI))
	picker.add_theme_stylebox_override("pressed", ui_box(UI_VOID, UI_ACCENT))
	picker.add_theme_stylebox_override("focus", ui_box(UI_SURFACE, UI_EDGE_HI))
	picker.add_theme_color_override("font_color", UI_TEXT)
	picker.add_theme_color_override("font_hover_color", Color.WHITE)
	picker.add_theme_font_size_override("font_size", 16)
	# The popup is a separate control tree and keeps the engine default unless
	# it is dressed too, which reads as a different application entirely.
	var popup := picker.get_popup()
	popup.add_theme_stylebox_override("panel", ui_box(UI_PANEL, UI_EDGE_HI, 8))
	popup.add_theme_color_override("font_color", UI_TEXT)
	popup.add_theme_color_override("font_hover_color", UI_ACCENT)
	popup.add_theme_font_size_override("font_size", 16)

func ui_rule() -> Control:
	var rule := ColorRect.new()
	rule.color = UI_EDGE
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func styled_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", ui_box(UI_VOID, UI_EDGE, 4))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var amount := Label.new()
	bar.add_child(amount)
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.add_theme_color_override("font_shadow_color", Color.BLACK)
	amount.add_theme_constant_override("shadow_offset_x", 1)
	amount.add_theme_constant_override("shadow_offset_y", 1)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := Panel.new()
	edge.name = "Edge"
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(edge)
	return bar

# The always-on-top border ring of a bar. Transparent fill so the health colour
# still reads through it.
func bar_edge(bar: ProgressBar) -> Panel:
	return bar.get_node_or_null("Edge") as Panel

# A hotter, more saturated red than the damage colour: this is a persistent
# "that is an enemy" marker, not a one-frame hit flash, so it has to hold its own
# against a bright class-coloured fill underneath it.
const ENEMY_EDGE := Color("ff2d4e")

func paint_bar_edge(bar: ProgressBar, color: Color, width: int) -> void:
	var edge := bar_edge(bar)
	if edge == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = color
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	edge.add_theme_stylebox_override("panel", box)

# A party or enemy row: still a Button so clicking it targets, but the health is
# a real bar rather than a number. The bar is a child so the button keeps its
# rect for click-to-target; the button's own text is left empty and the label
# inside the bar carries the words, or the button would draw underneath it.
func roster_row(parent: Node, callback: Callable) -> Button:
	var button := add_button(parent, "", callback)
	button.custom_minimum_size = Vector2(220, 34)
	var bar := styled_bar(UI_EDGE, 26)
	bar.custom_minimum_size = Vector2(0, 26)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 4
	bar.offset_right = -4
	bar.offset_top = 4
	bar.offset_bottom = -4
	button.add_child(bar)
	return button

# The bar inside a roster row, or null.
func roster_bar(button: Button) -> ProgressBar:
	return button.get_child(0) as ProgressBar if button.get_child_count() > 0 else null

func unit_frame(pos: Vector2, color: Color) -> VBoxContainer:
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 3)
	frame.position = pos
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(on_unit_frame_input.bind(frame))
	ui.add_child(frame)
	add_label(frame, "", 18)
	frame.add_child(styled_bar(color, 27))
	frame.add_child(styled_bar(GOLD, 22))
	add_label(frame, "", 14)
	var auras := HBoxContainer.new()
	auras.add_theme_constant_override("separation", 3)
	auras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(auras)
	for i in range(AURA_SLOTS):
		auras.add_child(aura_widget())
	return frame

# One aura chip: a coloured border, an abbreviated name and a countdown. Hover
# detection is done by rectangle test in update_ability_tooltip(), the same way
# the hotbar does it, so the chips do not need to swallow mouse events.
func aura_widget() -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(0, 26)
	chip.hide()
	# PanelContainer sizes itself to a single child, so icon and text share a
	# row rather than being parented directly and overlapping.
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	var art := TextureRect.new()
	art.name = "Icon"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(22, 22)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(art)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(label)
	return chip

func paint_aura(chip: PanelContainer, aura: Dictionary) -> void:
	chip.show()
	chip.set_meta("aura", aura)
	var tint: Color = aura.color
	var box := ui_box(Color(tint.r * 0.22, tint.g * 0.22, tint.b * 0.22, 0.92), tint, 4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", box)
	# Show the icon of the ability that caused the effect, the way WoW does —
	# an Ember stun and a Vanguard stun should be distinguishable at a glance.
	# Effects with no illustrated source (diminishing returns, or an older
	# snapshot) fall back to the name, so a chip is never blank.
	var row := chip.get_child(0) as HBoxContainer
	var art := row.get_child(0) as TextureRect
	var icon: Texture2D = AbilityArt.texture_for(aura.get("source", ""))
	art.texture = icon
	art.visible = icon != null
	var label := row.get_child(1) as Label
	label.add_theme_color_override("font_color", tint)
	label.text = format_aura_time(aura.remaining) if icon != null else "%s %s" % [aura.name, format_aura_time(aura.remaining)]

# Long effects do not need tenths; the last few seconds do, because that is when
# you are deciding whether to wait it out.
static func format_aura_time(t: float) -> String:
	return "%.0fs" % ceil(t) if t >= 10.0 else "%.1fs" % t

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard = add_label(ui, "STARFALL", 22)
	scoreboard.position = Vector2(24, 16)
	player_frame = unit_frame(Vector2(24, 56), BLUE)
	target_frame = unit_frame(Vector2(330, 56), RED)
	focus_frame = unit_frame(Vector2(636, 56), GOLD)
	party_box = VBoxContainer.new()
	party_box.position = Vector2(24, 220)
	ui.add_child(party_box)
	add_label(party_box, "PARTY · select by key or frame")
	for i in range(3):
		party_buttons.append(roster_row(party_box, select_party.bind(i)))
	enemy_box = VBoxContainer.new()
	ui.add_child(enemy_box)
	enemy_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	enemy_box.offset_left = -244
	enemy_box.offset_top = 220
	enemy_box.offset_right = -24
	enemy_box.offset_bottom = 360
	add_label(enemy_box, "ENEMIES · select by key or frame")
	for i in range(3):
		enemy_buttons.append(roster_row(enemy_box, select_enemy.bind(i)))
	var help := add_label(ui, "W/S move · A/D strafe · Q/E turn · Space jump\nRMB steer · LMB orbit · Both run · Wheel zoom\nTab / frames target · F1–F3 allies · F / G focus\n1–7 / Shift+1–5 abilities · Hover for details · Esc menu", 14)
	help.add_theme_color_override("font_color", UI_TEXT_DIM)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 24
	controls_help = help
	help.offset_top = -185
	help.offset_right = 400
	help.offset_bottom = -100
	# Twelve abilities fill the first two bars; the third holds alternate bindings.
	for bar in range(BAR_COUNT):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		row.offset_left = -340
		row.offset_right = 340
		# Stacked upward from the primary bar.
		row.offset_top = -117 - bar * 74
		row.offset_bottom = -25 - bar * 74
		ui.add_child(row)
		bar_roots.append(row)
		var handle := PanelContainer.new()
		handle.name = "Handle"
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		handle.custom_minimum_size = Vector2(26, 0)
		handle.add_theme_stylebox_override("panel", ui_box(UI_SURFACE_HI, UI_ACCENT, 4))
		handle.hide()
		var grip := Label.new()
		grip.text = "⠿"
		grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grip.add_theme_color_override("font_color", UI_ACCENT)
		handle.add_child(grip)
		row.add_child(handle)
		bar_handles.append(handle)
		if bar == 0:
			hotbar_root = row
		for slot in range(BAR_SLOTS):
			var index := bar * BAR_SLOTS + slot
			var button := add_button(row, "", send_action.bind(index))
			button.custom_minimum_size = Vector2(DEFAULT_SLOT_SIZE, DEFAULT_SLOT_SIZE)
			button.clip_contents = true
			ability_buttons.append(button)
			ability_images.append(AbilityArt.attach(button))
			var overlay = CooldownOverlay.new()
			button.add_child(overlay)
			cooldown_overlays.append(overlay)
	notice = add_label(ui, "", 21)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -350
	notice.offset_top = 170
	notice.offset_right = 350
	notice.offset_bottom = 202
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.modulate = GOLD
	panel = PanelContainer.new()
	ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_top = -280
	panel.offset_right = 300
	panel.offset_bottom = 280
	panel.custom_minimum_size = Vector2(600, 560)
	var shell := ui_box(Color(UI_VOID.r, UI_VOID.g, UI_VOID.b, 0.94), UI_EDGE_HI, 10, 2)
	shell.content_margin_left = 0
	shell.content_margin_right = 0
	shell.content_margin_top = 0
	shell.content_margin_bottom = 0
	shell.shadow_color = Color(0, 0, 0, 0.55)
	shell.shadow_size = 18
	panel.add_theme_stylebox_override("panel", shell)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var wordmark := add_label(stack, "S T A R F A L L", 34)
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wordmark.add_theme_color_override("font_color", UI_ACCENT)
	var subtitle := add_label(stack, "COSMIC  ARENA", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UI_VIOLET)
	stack.add_child(ui_rule())
	result_text = add_label(stack, "Choose a champion. Your full kit is ready.", 16)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.add_theme_color_override("font_color", UI_TEXT_DIM)
	champion_choice = OptionButton.new()
	for title in ["Ember — ranged damage", "Vanguard — melee damage", "Luminary — healer", "Fulcrum — control"]:
		champion_choice.add_item(title)
	style_picker(champion_choice)
	stack.add_child(champion_choice)
	mode_choice = OptionButton.new()
	mode_choice.add_item("Duel · 1v1", 1)
	mode_choice.add_item("Team arena · 3v3", 3)
	style_picker(mode_choice)
	stack.add_child(mode_choice)
	main_row = HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 10)
	stack.add_child(main_row)
	style_button(add_button(main_row, "Online", func(): menu_state = "online"; refresh_menu()), true)
	add_button(main_row, "Offline", func(): menu_state = "offline"; refresh_menu())
	add_button(main_row, "Settings", func(): menu_state = "settings"; refresh_menu())
	offline_row = HBoxContainer.new()
	offline_row.alignment = BoxContainer.ALIGNMENT_CENTER
	offline_row.add_theme_constant_override("separation", 10)
	stack.add_child(offline_row)
	style_button(add_button(offline_row, "Local sparring", local_match), true)
	opponent_choice = OptionButton.new()
	opponent_choice.add_item("Opponent: random roles", RANDOM_OPPONENT)
	for i in range(Kits.NAMES.size()):
		opponent_choice.add_item("Opponent: %s" % Kits.NAMES[i], i)
	style_picker(opponent_choice)
	offline_row.add_child(opponent_choice)
	add_button(offline_row, "Back", func(): menu_state = "main"; refresh_menu())
	online_row = HBoxContainer.new()
	online_row.alignment = BoxContainer.ALIGNMENT_CENTER
	online_row.add_theme_constant_override("separation", 10)
	stack.add_child(online_row)
	add_button(online_row, "Online queue", func(): menu_state = "queue"; refresh_menu())
	add_button(online_row, "Host lobby", func(): menu_state = "host"; refresh_menu())
	add_button(online_row, "Join lobby", func(): menu_state = "join"; refresh_menu())
	add_button(online_row, "World", enter_world)
	add_button(online_row, "Back", func(): menu_state = "main"; refresh_menu())
	settings_row = HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 10)
	stack.add_child(settings_row)
	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 8)
	stack.add_child(size_row)
	size_label = add_label(size_row, "Action bar slot size (default %d):" % DEFAULT_SLOT_SIZE, 14)
	slot_size_field = LineEdit.new()
	slot_size_field.text = str(DEFAULT_SLOT_SIZE)
	slot_size_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_size_field.custom_minimum_size = Vector2(90, 36)
	slot_size_field.add_theme_stylebox_override("normal", ui_box(UI_VOID, UI_EDGE))
	slot_size_field.add_theme_stylebox_override("focus", ui_box(UI_VOID, UI_ACCENT))
	slot_size_field.add_theme_color_override("font_color", UI_ACCENT)
	size_row.add_child(slot_size_field)
	settings_extra.append(size_row)
	style_button(add_button(settings_row, "Apply", apply_settings), true)
	add_button(settings_row, "Keybinds", func(): keybind_menu.open())
	add_button(settings_row, "Edit HUD", func(): toggle_edit_mode(true))
	add_button(settings_row, "Back", func(): menu_state = "main"; refresh_menu())
	queue_row = HBoxContainer.new()
	queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_row.add_theme_constant_override("separation", 10)
	stack.add_child(queue_row)
	style_button(add_button(queue_row, "Find match", matchmake), true)
	add_button(queue_row, "Back", func(): menu_state = "online"; refresh_menu())
	host_row = HBoxContainer.new()
	host_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_row.add_theme_constant_override("separation", 10)
	stack.add_child(host_row)
	style_button(add_button(host_row, "Create lobby", host_lobby), true)
	add_button(host_row, "Back", func(): menu_state = "online"; refresh_menu())
	join_row = HBoxContainer.new()
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	join_row.add_theme_constant_override("separation", 10)
	stack.add_child(join_row)
	code_field = LineEdit.new()
	code_field.placeholder_text = "Lobby code"
	code_field.max_length = Config.CODE_LENGTH
	code_field.custom_minimum_size = Vector2(160, 40)
	code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_field.add_theme_stylebox_override("normal", ui_box(UI_VOID, UI_EDGE))
	code_field.add_theme_stylebox_override("focus", ui_box(UI_VOID, UI_ACCENT))
	code_field.add_theme_color_override("font_color", UI_ACCENT)
	code_field.add_theme_color_override("font_placeholder_color", UI_TEXT_DIM)
	code_field.add_theme_font_size_override("font_size", 20)
	join_row.add_child(code_field)
	style_button(add_button(join_row, "Join", func(): join_lobby(code_field.text)), true)
	add_button(join_row, "Back", func(): menu_state = "online"; refresh_menu())
	window_mode_choice = OptionButton.new()
	window_mode_choice.add_item("Windowed", UserConfig.WINDOW_WINDOWED)
	window_mode_choice.add_item("Fullscreen (borderless)", UserConfig.WINDOW_BORDERLESS)
	window_mode_choice.add_item("Fullscreen (exclusive)", UserConfig.WINDOW_EXCLUSIVE)
	style_picker(window_mode_choice)
	# Without this the disabled state of the resolution picker was only
	# recomputed on the next refresh_menu(), so choosing Windowed left
	# resolution greyed out and apparently broken.
	window_mode_choice.item_selected.connect(func(_i): refresh_menu())
	stack.add_child(window_mode_choice)
	resolution_choice = OptionButton.new()
	for res in UserConfig.available_resolutions():
		resolution_choice.add_item("%d x %d" % [res.x, res.y])
	style_picker(resolution_choice)
	stack.add_child(resolution_choice)
	# Players never see the server address; this stays as a value holder for tests
	# and for the --join= command-line path. It is parented but hidden so the scene
	# owns it — an orphaned Control leaks its font and canvas RIDs at exit.
	address = LineEdit.new()
	address.text = Config.SERVER_ADDRESS
	address.hide()
	stack.add_child(address)
	lobby_text = add_label(stack, "Choose Online to matchmake into a duel or 3v3. Offline is local sparring vs bots.", 16)
	lobby_text.custom_minimum_size.y = 96
	lobby_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_text.add_theme_color_override("font_color", UI_TEXT_DIM)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	stack.add_child(ui_rule())
	start_button = add_button(stack, "Start round / Rematch", host_start)
	start_button.hide()
	resume_button = add_button(stack, "Resume / Close panel", func():
		if phase in ["match", "countdown"]:
			panel.hide())
	requeue_button = add_button(stack, "Requeue", requeue)
	requeue_button.hide()
	match_settings = add_button(stack, "Settings", func(): menu_state = "settings"; refresh_menu())
	exit_button = add_button(stack, "Return to menu", func(): leave_session("Returned to menu."))
	ability_tooltip = preload("res://scripts/ability_tooltip.gd").new()
	ui.add_child(ability_tooltip)
	# Follows the cursor while an ability is being dragged, so the gesture has
	# something to look at instead of happening invisibly.
	drag_ghost = TextureRect.new()
	drag_ghost.name = "DragGhost"
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	drag_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	drag_ghost.modulate = Color(1, 1, 1, 0.8)
	drag_ghost.z_index = 90
	drag_ghost.hide()
	ui.add_child(drag_ghost)
	self_auras = HBoxContainer.new()
	self_auras.name = "SelfAuras"
	self_auras.alignment = BoxContainer.ALIGNMENT_END
	self_auras.add_theme_constant_override("separation", 4)
	self_auras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_auras.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	self_auras.offset_left = -420
	self_auras.offset_right = -24
	self_auras.offset_top = 150
	self_auras.offset_bottom = 182
	ui.add_child(self_auras)
	for i in range(AURA_SLOTS):
		self_auras.add_child(aura_widget())
	keybind_menu = preload("res://scripts/keybind_menu.gd").new()
	ui.add_child(keybind_menu)
	keybind_menu.setup(self)
	build_cc_tracker()
	build_edit_overlay()

func spawn_actor(id: int, peer: int, side: int, choice: String, pos: Vector3) -> void:
	var actor = Fighter.new()
	actor.name = "Fighter%d" % id
	actor.setup(id, peer, side, choice)
	add_child(actor)
	actor.position = pos
	actor.rotation.y = 0 if side == 0 else PI
	actor.net_position = pos
	actor.net_yaw = actor.rotation.y
	actors[id] = actor

func clear_actors() -> void:
	prediction.reset()
	for actor in actors.values():
		remove_child(actor)
		actor.queue_free()
	actors.clear()
	selected_id = -1
	focus_id = -1

func local_match() -> void:
	world_mode = false
	if network:
		leave_session("")
	mode = mode_choice.get_selected_id()
	roster = {1: {"champion": Kits.NAMES[champion_choice.selected], "team": 0}}
	begin_round()

func host_session(dedicated_mode: bool = false, world: bool = false) -> void:
	leave_session("")
	world_mode = world
	dedicated = dedicated_mode
	mode = mode_choice.get_selected_id()
	var peer := ENetMultiplayerPeer.new()
	var max_peers := 6 if private_lobby else (mode * 2 if dedicated else 5)
	var error := peer.create_server(current_port, max_peers)
	if error != OK:
		say("Could not host on UDP %d: %s" % [current_port, error_string(error)])
		return
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	network = true
	if dedicated:
		roster = {}
		phase = "lobby"
		status = "Starfall dedicated on UDP %d · %dv%d · v%s" % [current_port, mode, mode, Config.VERSION]
		print("DEDICATED READY %s port=%d mode=%d min_players=%d rematch_delay=%.1f private=%s world=%s" % [Config.VERSION, current_port, mode, min_players, rematch_delay, private_lobby, world_mode])
	else:
		roster = {1: {"champion": Kits.NAMES[champion_choice.selected], "team": 0}}
		phase = "lobby"
		status = "Hosting on UDP %d. Share your LAN IP with friends." % current_port
	refresh_lobby()

func join_session() -> void:
	var host_address := address.text.strip_edges()
	leave_session("")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, current_port)
	if error != OK:
		say("Could not connect: %s" % error_string(error))
		return
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	network = true
	phase = "connecting"
	connected_seconds = 0
	status = "Connecting to %s…" % host_address
	refresh_lobby()

func connect_to(port: int) -> bool:
	close_peer()
	current_port = port
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.text.strip_edges(), port)
	if error != OK:
		return false
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	network = true
	phase = "connecting"
	connected_seconds = 0
	return true

# Tear the peer down without resetting menu state — used between probe steps.
func close_peer() -> void:
	if network:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network = false

# The world is one shared, always-running server, so it needs no mode choice and
# no queue — you simply connect to it.
func enter_world() -> void:
	intent = "queue"
	searching = false
	world_mode = true
	lobby_code = ""
	status = "Entering the world…"
	if not connect_to(Config.WORLD_PORT):
		leave_session("Could not reach the world. Try again in a moment.")
		return
	refresh_lobby()

func matchmake() -> void:
	mode = mode_choice.get_selected_id()
	intent = "queue"
	searching = true
	lobby_code = ""
	status = "Searching for an opponent…" if mode == 1 else "Searching for players…"
	if not connect_to(Config.DUEL_PORT if mode == 1 else Config.TEAM_PORT):
		leave_session("Could not reach the server. Try again in a moment.")
		return
	refresh_lobby()

func requeue() -> void:
	close_peer()
	clear_actors()
	roster.clear()
	epoch += 1
	winner = -1
	matchmake()

func host_lobby() -> void:
	mode = mode_choice.get_selected_id()
	pending_code = ""
	begin_probe("host", "Creating lobby…", Config.LOBBY_PORTS.duplicate())

func join_lobby(code: String) -> void:
	var wanted := normalize_code(code)
	if wanted.length() != Config.CODE_LENGTH:
		say("Enter the %d-character lobby code." % Config.CODE_LENGTH)
		return
	pending_code = wanted
	# The first character names the slot, so a join goes straight to the right
	# server instead of walking the pool. An unrecognised prefix falls back to
	# the full walk — that keeps old codes working if the pool is ever resized.
	var slot := slot_from_code(wanted)
	if slot >= 0:
		begin_probe("join", "Looking for lobby %s…" % wanted, [Config.LOBBY_PORTS[slot]])
	else:
		begin_probe("join", "Looking for lobby %s…" % wanted, Config.LOBBY_PORTS.duplicate())

# Private lobbies live on a fixed pool of server processes. The client walks the
# pool one port at a time: "host" takes the first idle one, "join" takes the one
# holding the code. No broker process is involved.
func begin_probe(kind: String, message: String, ports: Array) -> void:
	intent = kind
	searching = false
	lobby_code = ""
	probe_ports = ports
	probe_index = -1
	status = message
	next_probe()

func next_probe() -> void:
	probe_index += 1
	if probe_index >= probe_ports.size():
		var reason := "All lobbies are in use right now." if intent == "host" else "No lobby found with code %s." % pending_code
		intent = ""
		close_peer()
		phase = "menu"
		status = reason
		say(reason)
		refresh_lobby()
		return
	if not connect_to(probe_ports[probe_index]):
		call_deferred("next_probe")
		return
	refresh_lobby()

func on_connection_failed() -> void:
	if intent in ["host", "join"]:
		next_probe()
	else:
		leave_session("Could not reach the server. Try again in a moment.")

func normalize_code(code: String) -> String:
	var out := ""
	for c in code.strip_edges().to_upper():
		if Config.CODE_ALPHABET.contains(c):
			out += c
	return out

# Which pool slot this server is. -1 when running on a port outside the pool.
func slot_index() -> int:
	return Config.LOBBY_PORTS.find(current_port)

# Decode the slot a code was issued by. -1 if it does not name a live slot.
func slot_from_code(code: String) -> int:
	if code.length() != Config.CODE_LENGTH:
		return -1
	var slot := Config.CODE_ALPHABET.find(code[0])
	return slot if slot >= 0 and slot < Config.LOBBY_PORTS.size() else -1

# The first character encodes the slot; the rest is random. Pool members mint
# codes independently with no coordination, so without this two of them could
# issue the same string — and a joiner, which stops at the first match, would
# silently send players to the wrong lobby.
func make_code() -> String:
	var slot := slot_index()
	var out := Config.CODE_ALPHABET[slot] if slot >= 0 else Config.CODE_ALPHABET[randi() % Config.CODE_ALPHABET.length()]
	for _i in range(Config.CODE_LENGTH - 1):
		out += Config.CODE_ALPHABET[randi() % Config.CODE_ALPHABET.length()]
	return out

func leave_session(message: String) -> void:
	if keybind_menu != null:
		keybind_menu.close()
	if network:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network = false
	dedicated = false
	world_mode = false
	menu_state = "main"
	intent = ""
	searching = false
	remote_in_round = false
	lobby_code = ""
	pending_code = ""
	roster.clear()
	clear_actors()
	phase = "menu"
	epoch += 1
	winner = -1
	status = message
	panel.show()
	release_mouse()
	refresh_lobby()
	if not message.is_empty():
		say(message)

func on_connected() -> void:
	match intent:
		"host":
			claim_lobby.rpc_id(1, mode, Config.VERSION)
		"join":
			resolve_lobby.rpc_id(1, pending_code, Config.VERSION)
		_:
			register_player.rpc_id(1, Kits.NAMES[champion_choice.selected], Config.VERSION)

# --- private lobby claim / lookup, server side -------------------------
@rpc("any_peer", "call_remote", "reliable")
func claim_lobby(size_per_team: int, client_version: String) -> void:
	if not network or not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if client_version != Config.VERSION:
		rejected.rpc_id(peer, version_message(client_version))
		return
	if not private_lobby or claimed or not roster.is_empty() or phase != "lobby":
		lobby_busy.rpc_id(peer)
		return
	mode = clampi(size_per_team, 1, 3)
	min_players = mode * 2
	claimed = true
	lobby_code = make_code()
	print("LOBBY CLAIMED code=%s port=%d mode=%d" % [lobby_code, current_port, mode])
	lobby_found.rpc_id(peer, lobby_code, mode)

@rpc("any_peer", "call_remote", "reliable")
func resolve_lobby(code: String, client_version: String) -> void:
	if not network or not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if client_version != Config.VERSION:
		rejected.rpc_id(peer, version_message(client_version))
		return
	if not private_lobby or not claimed or code != lobby_code:
		lobby_busy.rpc_id(peer)
		return
	if phase != "lobby" or roster.size() >= mode * 2:
		rejected.rpc_id(peer, "That lobby is already full or in a round.")
		return
	lobby_found.rpc_id(peer, lobby_code, mode)

# This pool member is not the one we want — hang up and try the next port.
@rpc("authority", "call_remote", "reliable")
func lobby_busy() -> void:
	next_probe()

@rpc("authority", "call_remote", "reliable")
func lobby_found(code: String, size_per_team: int) -> void:
	lobby_code = code
	mode = size_per_team
	mode_choice.select(1 if mode == 3 else 0)
	intent = ""
	register_player.rpc_id(1, Kits.NAMES[champion_choice.selected], Config.VERSION)

func version_message(client_version: String) -> String:
	return "Version mismatch — server is v%s, your client is v%s. Update to play." % [Config.VERSION, client_version]

@rpc("any_peer", "call_remote", "reliable")
func register_player(choice: String, client_version: String) -> void:
	if not network or not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if roster.has(peer):
		return
	if client_version != Config.VERSION:
		rejected.rpc_id(peer, version_message(client_version))
		return
	if choice not in Kits.NAMES:
		rejected.rpc_id(peer, "Unknown champion.")
		return
	if roster.size() >= mode * 2:
		rejected.rpc_id(peer, "That server is full. Try again in a moment.")
		return
	# A queue has to hold you for the NEXT round rather than turning you away.
	# These servers auto-rematch continuously, so a round is in progress most of
	# the time, and rejecting mid-round meant the queue only ever worked in the
	# few idle seconds between matches. Registering now costs nothing: actors are
	# built from the roster at begin_round(), and a waiting client ignores
	# in-flight snapshots because its epoch is stale.
	# Player-hosted lobbies keep the stricter rule — they have a host to wait for.
	var accepting: bool = phase == "lobby" or (dedicated and phase in ["countdown", "match", "results"])
	if not accepting:
		rejected.rpc_id(peer, "Lobby unavailable. Ask the host to return to the lobby.")
		return
	var counts := [0, 0]
	for entry in roster.values():
		counts[entry.team] += 1
	var side := 0 if counts[0] < counts[1] else 1
	roster[peer] = {"champion": choice, "team": side}
	broadcast_lobby()
	maybe_auto_start()

func maybe_auto_start() -> void:
	if world_mode and authoritative():
		# The world is always running: the first arrival starts it, and everyone
		# after that walks into it rather than restarting it for the people
		# already there.
		if phase == "lobby":
			begin_round()
		else:
			admit_to_world()
		return
	if not dedicated or not authoritative() or phase != "lobby":
		return
	if roster.size() >= min_players:
		print("DEDICATED ROUND START epoch=%d humans=%d/%d" % [epoch + 1, roster.size(), mode * 2])
		begin_round()

@rpc("authority", "call_remote", "reliable")
func rejected(reason: String) -> void:
	leave_session(reason)

func broadcast_lobby() -> void:
	refresh_lobby()
	if network:
		lobby_state.rpc(roster, mode, "" if dedicated else status, min_players, phase != "lobby")

@rpc("authority", "call_remote", "reliable")
func lobby_state(players: Dictionary, size_per_team: int, message: String, needed: int, in_round: bool) -> void:
	roster = players
	mode = size_per_team
	remote_min_players = maxi(1, needed)
	remote_in_round = in_round
	mode_choice.select(1 if mode == 3 else 0)
	phase = "lobby"
	status = message
	panel.show()
	refresh_lobby()

func refresh_lobby() -> void:
	start_button.visible = network and multiplayer.is_server() and phase in ["lobby", "results"] and not dedicated
	if phase == "lobby":
		var lines: Array[String] = []
		if dedicated:
			lines.append("Dedicated · %dv%d · %d/%d players" % [mode, mode, roster.size(), min_players])
		elif searching and remote_in_round:
			lines.append("Match in progress — you are in for the next round.")
			lines.append("%d players queued" % roster.size())
		elif searching:
			lines.append("Searching for an opponent…" if mode == 1 else "Searching for players…")
			lines.append("%d of %d players ready" % [roster.size(), remote_min_players])
		elif not lobby_code.is_empty():
			lines.append("Lobby code:  %s" % lobby_code)
			lines.append("Share it — friends pick Online → Join lobby.")
			lines.append("%d of %d players ready" % [roster.size(), remote_min_players])
		else:
			lines.append("%dv%d lobby — %d human player(s)" % [mode, mode, roster.size()])
		for peer in roster:
			lines.append("%s: %s%s" % ["Blue" if roster[peer].team == 0 else "Red", roster[peer].champion, " (you)" if peer == multiplayer.get_unique_id() else ""])
		if dedicated:
			lines.append("Round auto-starts when %d players are connected." % min_players)
		elif not searching and lobby_code.is_empty():
			lines.append("Host starts when ready. Empty slots are filled by bots.")
		lobby_text.text = "\n".join(lines)
	else:
		lobby_text.text = status
	if phase not in ["results", "match", "countdown"]:
		result_text.text = "Choose a champion. Your full kit is ready."
	refresh_menu()

func refresh_menu() -> void:
	var in_menu: bool = phase == "menu" or menu_state == "settings"
	if match_settings:
		match_settings.visible = phase != "menu" and menu_state != "settings"
	if main_row:
		main_row.visible = in_menu and menu_state == "main"
	if offline_row:
		offline_row.visible = in_menu and menu_state == "offline"
	if online_row:
		online_row.visible = in_menu and menu_state == "online"
	if settings_row:
		settings_row.visible = in_menu and menu_state == "settings"
	for extra in settings_extra:
		extra.visible = in_menu and menu_state == "settings"
	if opponent_choice:
		opponent_choice.visible = in_menu and menu_state == "offline"
	if window_mode_choice:
		window_mode_choice.visible = in_menu and menu_state == "settings"
	if resolution_choice:
		# Resolution only means anything in windowed mode; fullscreen adopts the
		# monitor. Showing a disabled picker is clearer than hiding it, because
		# it explains why the setting is unavailable.
		resolution_choice.visible = in_menu and menu_state == "settings"
		resolution_choice.disabled = window_mode_choice != null and window_mode_choice.get_selected_id() != UserConfig.WINDOW_WINDOWED
	if queue_row:
		queue_row.visible = in_menu and menu_state == "queue"
	if host_row:
		host_row.visible = in_menu and menu_state == "host"
	if join_row:
		join_row.visible = in_menu and menu_state == "join"
	if mode_choice:
		mode_choice.visible = not in_menu or menu_state in ["queue", "host", "offline"]
	if requeue_button:
		requeue_button.visible = phase == "results" and network and not multiplayer.is_server()
	# refresh_lobby() writes the session status into this label, so only speak
	# for it while sitting in the menu with nothing to report.
	if lobby_text and phase == "menu":
		match menu_state:
			"online":
				lobby_text.text = "Queue for a public match, or use a private code to play with friends."
			"queue":
				lobby_text.text = "Pick a mode, then Find match.\nYou are matched with the next player who queues."
			"host":
				lobby_text.text = "Creates a private lobby and gives you a code to share."
			"join":
				lobby_text.text = "Enter the %d-character code a friend gave you." % Config.CODE_LENGTH
			"offline":
				lobby_text.text = "Spar against bots.\nEmpty team slots are filled automatically."
			"settings":
				lobby_text.text = "Display settings apply immediately and are remembered.\nKeybinds configures controls and bars. Edit HUD arranges your layout."
			_:
				lobby_text.text = "Online plays against people.\nOffline is local sparring against bots."

# --- edit mode ----------------------------------------------------------------
# WoW's Edit Mode in miniature: drag frames where you want them, click a hotbar
# slot to rebind its key, drag one slot onto another to swap abilities. All of
# it is client-side presentation — the server is never told and never cares.

# Shift + drag rearranges the bars at any time, in a match or in the world,
# without going through Edit HUD. The event is consumed so the slot underneath
# never fires the ability.
func handle_shift_drag(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if drag_slot >= 0:
			move_drag_ghost()
		return false
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return false
	var point: Vector2 = ui.get_global_mouse_position()
	if event.pressed:
		if not event.shift_pressed:
			return false
		var slot := hotbar_slot_at(point)
		if slot < 0:
			return false
		drag_slot = slot
		update_visuals(0)
		show_drag_ghost(slot)
		get_viewport().set_input_as_handled()
		return true
	if drag_slot >= 0:
		var target := hotbar_slot_at(point)
		if target >= 0 and target != drag_slot:
			swap_slots(drag_slot, target)
		drag_slot = -1
		show_drag_ghost(-1)
		update_visuals(0)
		get_viewport().set_input_as_handled()
		return true
	return false

# Returns true when the event belonged to edit mode and must not travel further.
func handle_edit_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if rebinding >= 0:
			if event.keycode == KEY_ESCAPE:
				rebinding = -1
				refresh_edit_hint()
			else:
				var binding := event_binding(event)
				# Ignore a bare modifier: the player is still reaching for the key.
				if binding != 0:
					finish_rebind(binding)
			return true
		if event.keycode == KEY_ESCAPE:
			toggle_edit_mode(false)
			return true
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = ui.get_global_mouse_position()
		if event.pressed:
			var slot := hotbar_slot_at(point)
			if slot >= 0:
				drag_slot = slot
				show_drag_ghost(slot)
				return true
			var frame := movable_at(point)
			if frame != null:
				dragging = frame
				drag_offset = frame.position - point
				return true
			return false
		# Release: a slot press that ends on another slot swaps the two
		# abilities; one that ends where it began is a click, meaning rebind.
		if drag_slot >= 0:
			var target := hotbar_slot_at(point)
			if target >= 0 and target != drag_slot:
				swap_slots(drag_slot, target)
			elif target == drag_slot:
				begin_rebind(drag_slot)
			drag_slot = -1
			show_drag_ghost(-1)
			return true
		if dragging != null:
			moved_frames[dragging.name] = true
			dragging = null
			save_layout()
			return true
		return false
	if event is InputEventMouseMotion and drag_slot >= 0:
		move_drag_ghost()
		return true
	if event is InputEventMouseMotion and dragging != null:
		# Clamped so a frame cannot be dragged entirely off-screen and lost.
		var wanted: Vector2 = ui.get_global_mouse_position() + drag_offset
		var limit: Vector2 = ui.size - dragging.size
		dragging.position = Vector2(clampf(wanted.x, 0, maxf(0, limit.x)), clampf(wanted.y, 0, maxf(0, limit.y)))
		return true
	return false

# Centre-screen crowd control readout: the icon of whatever is holding you, what
# kind of control it is, and a radial timer. Placed above the middle so it does
# not sit on top of your own champion, and it reuses CooldownOverlay rather than
# growing a second radial renderer.
func build_cc_tracker() -> void:
	cc_tracker = VBoxContainer.new()
	cc_tracker.name = "CrowdControl"
	cc_tracker.alignment = BoxContainer.ALIGNMENT_CENTER
	cc_tracker.add_theme_constant_override("separation", 6)
	cc_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc_tracker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cc_tracker.offset_left = -90
	cc_tracker.offset_right = 90
	# Below the character's feet: above centre it sat over their head and hid the
	# thing you are watching while you wait out the stun.
	cc_tracker.offset_top = 96
	cc_tracker.offset_bottom = 232
	cc_tracker.hide()
	ui.add_child(cc_tracker)
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cc_tracker.add_child(holder)
	cc_icon = TextureRect.new()
	cc_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc_icon.custom_minimum_size = Vector2(84, 84)
	cc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cc_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	holder.add_child(cc_icon)
	cc_sweep = CooldownOverlay.new()
	cc_icon.add_child(cc_sweep)
	cc_sweep.set_key("")
	cc_label = add_label(cc_tracker, "", 20)
	cc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# How long this particular ability is locked out by crowd control. A stun stops
# everything; a lockout stops most things, and mirrors the exemptions try_spell
# already applies — Vanguard ignores it, and defensive or movement abilities
# still work through it.
func cc_block_remaining(actor, spell: Dictionary) -> float:
	if actor.stunned > 0.0:
		return actor.stunned
	if actor.locked > 0.0 and actor.champion != "Vanguard" and spell.kind not in ["shield", "blink", "sprint"]:
		return actor.locked
	return 0.0

func update_cc_tracker() -> void:
	if cc_tracker == null:
		return
	var holder = actors.get(local_id)
	var cc: Dictionary = Auras.crowd_control(holder) if holder != null else {}
	if cc.is_empty():
		cc_tracker.hide()
		cc_total = 0.0
		cc_key = ""
		return
	# The original duration is not replicated, so the peak observed value stands
	# in for it. A refreshed or re-applied effect raises the peak, which is
	# exactly when the sweep should restart.
	if cc.key != cc_key or cc.remaining > cc_total:
		cc_key = cc.key
		cc_total = cc.remaining
	cc_tracker.show()
	var art: Texture2D = AbilityArt.texture_for(cc.get("source", ""))
	cc_icon.texture = art
	cc_icon.visible = art != null
	var box := ui_box(Color(0, 0, 0, 0.55), cc.color, 8, 2)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	(cc_tracker.get_child(0) as PanelContainer).add_theme_stylebox_override("panel", box)
	cc_label.text = cc.cc
	cc_label.add_theme_color_override("font_color", cc.color)
	cc_sweep.sync(cc.remaining, maxf(cc_total, 0.01), false)

func build_edit_overlay() -> void:
	edit_overlay = Control.new()
	edit_overlay.name = "EditOverlay"
	# Ignore the mouse: dragging is resolved by rectangle tests in _input, so the
	# overlay must not sit between the cursor and the frames being moved.
	edit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit_overlay.hide()
	ui.add_child(edit_overlay)
	var wash := ColorRect.new()
	wash.color = Color(UI_VOID.r, UI_VOID.g, UI_VOID.b, 0.45)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit_overlay.add_child(wash)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", ui_box(UI_PANEL, UI_ACCENT, 8))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -430
	banner.offset_right = 430
	banner.offset_top = 24
	edit_overlay.add_child(banner)
	edit_hint = Label.new()
	edit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edit_hint.add_theme_font_size_override("font_size", 14)
	edit_hint.add_theme_color_override("font_color", UI_ACCENT)
	banner.add_child(edit_hint)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	# Centre of the screen, not under the banner: the HUD clusters along the top
	# edge, and these are real buttons that capture the mouse, so sitting over a
	# frame would make that frame undraggable.
	controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	controls.offset_left = -220
	controls.offset_right = 220
	controls.offset_top = -22
	controls.offset_bottom = 22
	edit_overlay.add_child(controls)
	style_button(add_button(controls, "Done", func(): toggle_edit_mode(false)), true)
	add_button(controls, "Reset layout", reset_layout)

# Frames the player may reposition. Registered after build_ui() so the list is
# built from the nodes that actually exist rather than repeated by hand.
func register_movable_frames() -> void:
	movable_frames.clear()
	default_positions.clear()
	# Stable names. These are the keys a saved layout is stored under, and Godot's
	# generated names (@VBoxContainer@105) shift whenever node creation order
	# changes — which would silently apply a player's saved position to the wrong
	# frame after any unrelated UI edit.
	var named := [
		[player_frame, "PlayerFrame"], [target_frame, "TargetFrame"],
		[focus_frame, "FocusFrame"], [party_box, "PartyFrame"],
		[enemy_box, "EnemyFrame"],
	]
	for bar in range(bar_roots.size()):
		named.append([bar_roots[bar], "ActionBar%d" % (bar + 1)])
	named.append([self_auras, "SelfAuras"])
	named.append([cc_tracker, "CrowdControl"])
	for entry in named:
		var frame: Control = entry[0]
		if frame == null:
			continue
		frame.name = entry[1]
		default_positions[frame.name] = frame.position
		# Deliberately NOT re-anchored. These sit directly under `ui`, which is a
		# plain Control rather than a container, so nothing re-lays them out and
		# `position` already writes through to the anchor offsets. Leaving the
		# anchors alone also means a frame pinned to the right edge stays pinned
		# there when the window changes size.
		movable_frames.append(frame)

func movable_at(point: Vector2) -> Control:
	# Reverse order so the topmost frame wins when two overlap.
	for i in range(movable_frames.size() - 1, -1, -1):
		var frame := movable_frames[i]
		if frame != null and frame.is_visible_in_tree() and frame.get_global_rect().has_point(point):
			return frame
	return null

func hotbar_slot_at(point: Vector2) -> int:
	for slot in range(ability_buttons.size()):
		var button := ability_buttons[slot]
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
			return slot
	return -1

func toggle_edit_mode(on: bool) -> void:
	edit_mode = on
	rebinding = -1
	dragging = null
	if edit_overlay:
		edit_overlay.visible = on
	for button in ability_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	for handle in bar_handles:
		handle.visible = on
	if on:
		panel.hide()
		release_mouse()
	else:
		save_layout()
		panel.show()
	refresh_edit_hint()
	refresh_menu()

func refresh_edit_hint() -> void:
	if edit_hint == null:
		return
	if rebinding >= 0:
		edit_hint.text = "Press a key for slot %d…    Esc cancels" % (rebinding + 1)
	else:
		edit_hint.text = "EDIT MODE\nCLICK a slot to rebind its key  ·  DRAG a slot onto another to move the ability  ·  DRAG a frame to reposition it\nUse Settings → Keybinds for movement, targeting and secondary bindings  ·  Esc or Done to finish"

func begin_rebind(slot: int) -> void:
	rebinding = slot
	refresh_edit_hint()

func finish_rebind(code: int) -> void:
	if rebinding < 0:
		return
	if controls.reserved(code):
		edit_hint.text = "That key is reserved for menu/window controls. Choose another key."
		return
	controls.assign(self, "bar_%d" % rebinding, 0, code)
	rebinding = -1
	save_layout()
	refresh_binds()
	refresh_edit_hint()

# A binding is a keycode with Godot's modifier mask folded in, so 1, Shift+1,
# Alt+1 and Ctrl+1 are four distinct values in the same table.
# OS.get_keycode_string() already renders the mask as "Shift+1", so the label
# needs no special handling.
static func event_binding(event: InputEventKey) -> int:
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	# A modifier pressed on its own is not a binding.
	if code in [KEY_SHIFT, KEY_ALT, KEY_CTRL, KEY_META]:
		return 0
	if event.shift_pressed:
		code |= KEY_MASK_SHIFT
	if event.alt_pressed:
		code |= KEY_MASK_ALT
	if event.ctrl_pressed:
		code |= KEY_MASK_CTRL
	if event.meta_pressed:
		code |= KEY_MASK_META
	return code

# Slot size is a single number: the bars are square grids, so a width and a
# height would only ever be set to the same value.
func apply_slot_size(size: int) -> void:
	slot_size = clampi(size, MIN_SLOT_SIZE, MAX_SLOT_SIZE)
	for button in ability_buttons:
		button.custom_minimum_size = Vector2(slot_size, slot_size)
		button.size = Vector2(slot_size, slot_size)
	for bar in range(bar_roots.size()):
		var row := bar_roots[bar]
		var step := slot_size + 8
		# Only reposition rows the player has not moved themselves; a saved
		# position is theirs and resizing should not throw it away.
		if not moved_frames.has(row.name):
			row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
			row.offset_left = -(slot_size * BAR_SLOTS + 48) / 2
			row.offset_right = (slot_size * BAR_SLOTS + 48) / 2
			row.offset_top = -(25 + slot_size + bar * step)
			row.offset_bottom = -(25 + bar * step)

func refresh_binds() -> void:
	if controls_help != null:
		controls_help.text = "%s/%s move · %s/%s strafe · %s jump\nRMB steer · LMB orbit · Both run · Wheel zoom\n%s enemies · %s/%s/%s allies\nKeys shown on bars · Settings → Keybinds · Esc menu" % [control_label("forward"), control_label("backward"), control_label("strafe_left"), control_label("strafe_right"), control_label("jump"), control_label("target_next"), control_label("party_1"), control_label("party_2"), control_label("party_3")]
	for slot in range(cooldown_overlays.size()):
		# An unbound slot shows nothing rather than a stray "0".
		var binding: int = binds[slot] if binds[slot] != 0 else controls.secondary[slot]
		cooldown_overlays[slot].set_key(OS.get_keycode_string(binding) if binding != 0 else "")

# Picks the dragged icon up under the cursor, or puts it away.
func show_drag_ghost(slot: int) -> void:
	if drag_ghost == null:
		return
	if slot < 0:
		drag_ghost.hide()
		return
	var texture: Texture2D = ability_images[slot].texture if slot < ability_images.size() else null
	drag_ghost.texture = texture
	drag_ghost.size = Vector2(slot_size, slot_size)
	drag_ghost.visible = texture != null
	move_drag_ghost()

func move_drag_ghost() -> void:
	if drag_ghost != null and drag_ghost.visible:
		drag_ghost.position = ui.get_global_mouse_position() - drag_ghost.size * 0.5

func swap_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= assignment.size() or b >= assignment.size():
		return
	var carried := assignment[a]
	assignment[a] = assignment[b]
	assignment[b] = carried
	save_layout()

# Zooming fires many events in a row; writing the file on each one would mean
# dozens of disk writes for one scroll. Flushed on a short delay instead, and
# again on quit.
func tick_camera_save(delta: float) -> void:
	if not camera_dirty:
		return
	camera_save_timer -= delta
	if camera_save_timer <= 0.0:
		camera_dirty = false
		camera_save_timer = 1.0
		config.set_value("hud", "camera_distance", arm.spring_length)
		config.save_config()

func save_layout() -> void:
	if arm != null:
		config.set_value("hud", "camera_distance", arm.spring_length)
	controls.save(config)
	config.set_value("hud", "binds", binds)
	config.set_value("hud", "assignment", assignment)
	var places := {}
	for frame in movable_frames:
		if frame != null:
			places[frame.name] = frame.position
	config.set_value("hud", "frames", places)
	config.set_value("hud", "slot_size", slot_size)
	config.set_value("hud", "moved", moved_frames.keys())
	config.save_config()

func load_layout() -> void:
	controls.load_from(config)
	var stored_binds = config.get_value("hud", "binds", [])
	if stored_binds is Array and stored_binds.size() == TOTAL_SLOTS:
		for i in range(binds.size()):
			binds[i] = int(stored_binds[i])
	var stored_assign = config.get_value("hud", "assignment", [])
	if stored_assign is Array and stored_assign.size() == TOTAL_SLOTS:
		# Refuse a malformed table rather than half-applying it: a duplicated or
		# out-of-range entry would make an ability unreachable.
		var ok := true
		for value in stored_assign:
			var index := int(value)
			# -1 is an empty slot, and the same ability may legitimately appear
			# on more than one bar — that is what the extra bars are for.
			if index < -1 or index >= Kits.KIT_SIZE:
				ok = false
				break
		if ok:
			for i in range(assignment.size()):
				assignment[i] = int(stored_assign[i])
	# Migrate older layouts without losing their existing bindings.
	for ability in range(Kits.KIT_SIZE):
		if not assignment.has(ability):
			var empty := assignment.find(-1)
			if empty < 0:
				for slot in range(assignment.size() - 1, -1, -1):
					if assignment.count(assignment[slot]) > 1:
						empty = slot
						break
			if empty >= 0:
				assignment[empty] = ability
				if binds[empty] == 0:
					binds[empty] = (KEY_1 + ability % BAR_SLOTS) | KEY_MASK_SHIFT
	var moved = config.get_value("hud", "moved", [])
	if moved is Array:
		for name in moved:
			moved_frames[str(name)] = true
	apply_slot_size(int(config.get_value("hud", "slot_size", DEFAULT_SLOT_SIZE)))
	if slot_size_field != null:
		slot_size_field.text = str(slot_size)
	var distance = config.get_value("hud", "camera_distance", 0.0)
	if arm != null and distance is float and distance > 0.0:
		arm.spring_length = clampf(distance, 3.0, 18.0)
	var places = config.get_value("hud", "frames", {})
	if places is Dictionary:
		for frame in movable_frames:
			if frame != null and places.has(frame.name):
				frame.position = places[frame.name]
	refresh_binds()

# Two populated bars: keys 1-7 and Shift+1-5. Third bar remains available.
func default_bindings() -> void:
	binds.resize(TOTAL_SLOTS)
	assignment.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		var first_bar: bool = i < BAR_SLOTS
		binds[i] = (KEY_1 + i) if first_bar else ((KEY_1 + i - BAR_SLOTS) | KEY_MASK_SHIFT if i < Kits.KIT_SIZE else 0)
		assignment[i] = i if i < Kits.KIT_SIZE else -1

func reset_layout() -> void:
	default_bindings()
	# Put the frames back before saving. Clearing the stored dictionary alone did
	# nothing, because save_layout() immediately rewrote it from wherever the
	# frames happened to be sitting.
	moved_frames.clear()
	apply_slot_size(DEFAULT_SLOT_SIZE)
	if slot_size_field != null:
		slot_size_field.text = str(DEFAULT_SLOT_SIZE)
	for frame in movable_frames:
		if frame != null and default_positions.has(frame.name):
			frame.position = default_positions[frame.name]
	save_layout()
	refresh_binds()

func apply_settings() -> void:
	if slot_size_field != null and slot_size_field.text.strip_edges().is_valid_int():
		apply_slot_size(int(slot_size_field.text))
		slot_size_field.text = str(slot_size)
	config.set_value("hud", "slot_size", slot_size)
	config.set_value("display", "window_mode", window_mode_choice.get_selected_id())
	var options := UserConfig.available_resolutions()
	var index: int = clampi(resolution_choice.selected, 0, options.size() - 1)
	if index >= 0 and index < options.size():
		config.set_value("display", "resolution", options[index])
	config.save_config()
	save_layout()
	config.apply_display()
	refresh_menu()

func load_settings() -> void:
	config.load_config()
	if window_mode_choice:
		for i in range(window_mode_choice.item_count):
			if window_mode_choice.get_item_id(i) == config.window_mode():
				window_mode_choice.select(i)
	if resolution_choice:
		var options := UserConfig.available_resolutions()
		var stored := config.resolution()
		for i in range(options.size()):
			if options[i] == stored:
				resolution_choice.select(i)
	config.apply_display()

func host_start() -> void:
	if authoritative() and phase in ["lobby", "results"]:
		begin_round()

func begin_round() -> void:
	clear_actors()
	epoch += 1
	elapsed = 0
	countdown = 0.0 if world_mode else 3.0
	winner = -1
	# The world has no countdown to wait through; you arrive and you are there.
	phase = "match" if world_mode else "countdown"
	duels.clear()
	duel_offers.clear()
	respawn_timers.clear()
	var counts := [0, 0]
	var id := 1
	for peer in roster:
		var entry: Dictionary = roster[peer]
		spawn_actor(id, peer, entry.team, entry.champion, spawn_position(entry.team, counts[entry.team]))
		counts[entry.team] += 1
		id += 1
	if world_mode:
		# No bots, and no teams that mean anything — everyone stands alone until
		# they agree to a duel.
		assign_local()
		broadcast_round()
		return
	for side in range(2):
		while counts[side] < mode:
			var forced := -1
			if opponent_choice != null and not network:
				forced = opponent_choice.get_selected_id()
			if forced != RANDOM_OPPONENT and forced >= 0 and forced < Kits.NAMES.size() and side == 1:
				spawn_actor(id, 0, side, Kits.NAMES[forced], spawn_position(side, counts[side]))
				counts[side] += 1
				id += 1
				continue
			var choices := ["Luminary", "Vanguard", "Ember"] if mode == 3 else ["Ember"]
			var choice := "Ember"
			for candidate in choices:
				var exists := false
				for actor in actors.values():
					if actor.team == side and actor.champion == candidate:
						exists = true
				if not exists:
					choice = candidate
					break
			spawn_actor(id, 0, side, choice, spawn_position(side, counts[side]))
			counts[side] += 1
			id += 1
	assign_local()
	result_text.text = "Round in progress — combat continues with this panel open."
	panel.hide()
	broadcast_round()

func broadcast_round() -> void:
	if network:
		round_started.rpc(epoch, mode, make_snapshot())

func spawn_position(side: int, index: int) -> Vector3:
	if world_mode:
		# Scattered around the middle rather than lined up on two team sides.
		var angle := float(index) * 1.9
		return Vector3(cos(angle) * 7.0, 0.05, sin(angle) * 7.0)
	return Vector3((index - 1) * 3.5 if mode == 3 else 0.0, 0.05, 10 if side == 0 else -10)

func assign_local() -> void:
	local_id = -1
	for actor in actors.values():
		if actor.owner_peer == multiplayer.get_unique_id():
			local_id = actor.actor_id
	if actors.has(local_id):
		local_yaw = actors[local_id].rotation.y
		pivot.rotation.y = local_yaw
		cycle_target()

@rpc("authority", "call_remote", "reliable")
func round_started(round_epoch: int, size_per_team: int, states: Array) -> void:
	clear_actors()
	epoch = round_epoch
	last_snapshot = -1
	mode = size_per_team
	winner = -1
	countdown = 3
	elapsed = 0
	phase = "countdown"
	for data in states:
		spawn_actor(data.id, data.peer, data.team, data.champion, data.pos)
		actors[data.id].receive(data, true)
	assign_local()
	result_text.text = "Round in progress — combat continues with this panel open."
	panel.hide()

func on_peer_left(peer: int) -> void:
	if not network or not multiplayer.is_server():
		return
	roster.erase(peer)
	if private_lobby and roster.is_empty():
		claimed = false
		lobby_code = ""
		print("LOBBY RELEASED port=%d" % current_port)
	for actor in actors.values():
		if actor.owner_peer == peer:
			actor.owner_peer = 0
			actor.move_input = Vector2.ZERO
			actor.casting = -1
	if phase == "lobby":
		broadcast_lobby()
	elif phase in ["match", "countdown"]:
		call_deferred("announce_disconnect")

func announce_disconnect() -> void:
	if network and multiplayer.is_server() and phase in ["match", "countdown"]:
		combat_event(-1, -1, "Player disconnected — bot took over", GOLD)

func make_snapshot() -> Array:
	var states: Array = []
	for actor in actors.values():
		states.append(actor.snapshot())
	return states

func _physics_process(delta: float) -> void:
	if phase == "connecting":
		connected_seconds += delta
		if connected_seconds > 10:
			if intent in ["host", "join"]:
				next_probe()
			else:
				leave_session("Could not reach the server. Try again in a moment.")
	tick_camera_save(delta)
	if phase in ["countdown", "match"]:
		if not authoritative() and actors.has(local_id):
			prediction.reconcile(self, actors[local_id])
		gather_input(delta)
		if authoritative() and world_mode:
			tick_world(delta)
		if authoritative():
			if phase == "countdown":
				countdown = maxf(0, countdown - delta)
				for actor in actors.values():
					actor.velocity = Vector3(0, actor.velocity.y - 20 * delta, 0)
					actor.move_and_slide()
				if countdown == 0:
					phase = "match"
			else:
				elapsed += delta
				for actor in actors.values():
					tick_actor(actor, delta)
				check_winner()
		if network and multiplayer.is_server():
			snapshot_timer -= delta
			if snapshot_timer <= 0:
				snapshot_timer = 0.05
				snapshot_seq += 1
				deliver_snapshot(epoch, snapshot_seq, make_snapshot(), phase, elapsed, countdown)
	if network and not multiplayer.is_server() and phase in ["match", "countdown", "results"]:
		for actor in actors.values():
			if actor.actor_id == local_id and phase == "match":
				continue
			actor.position = actor.position.lerp(actor.net_position, minf(1, delta * 22))
			actor.rotation.y = lerp_angle(actor.rotation.y, actor.net_yaw, minf(1, delta * 22))
		ping_timer -= delta
		if ping_timer <= 0:
			ping_timer = 1
			ping_host.rpc_id(1, Time.get_ticks_msec())
	update_visuals(delta)

func gather_input(delta: float) -> void:
	if not actors.has(local_id):
		return
	var actor = actors[local_id]
	var movement := Vector2.ZERO
	if not panel.visible and not edit_mode and actor.hp > 0:
		var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if not right:
			var turn := (controls.held("turn_left") - controls.held("turn_right")) * delta * 2.5
			local_yaw += turn
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				pivot.rotation.y += turn
		movement = Vector2(controls.held("strafe_right") - controls.held("strafe_left"), controls.held("backward") - controls.held("forward"))
		if right:
			movement.x += controls.held("turn_right") - controls.held("turn_left")
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				movement.y = -1
		movement = movement.limit_length()
	if authoritative():
		apply_input(local_id, movement, local_yaw, queued_jump, selected_id)
		queued_jump = false
	else:
		input_seq += 1
		var command := {"seq": input_seq, "move": movement, "yaw": local_yaw, "jump": queued_jump, "delta": delta}
		if phase == "match":
			prediction.predict(self, actor, command)
		else:
			apply_input(local_id, Vector2.ZERO, local_yaw, false, selected_id)
		deliver_input(epoch, input_seq, movement, local_yaw, queued_jump, selected_id)
		queued_jump = false

func key(code: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(code) else 0.0

func apply_input(id: int, movement: Vector2, yaw: float, jump: bool, selected: int) -> void:
	if not actors.has(id) or not movement.is_finite() or not is_finite(yaw):
		return
	var actor = actors[id]
	actor.move_input = movement.limit_length()
	if actor.stunned <= 0 and actor.hp > 0:
		actor.rotation.y = wrapf(yaw, -PI, PI)
	actor.jump_queued = actor.jump_queued or jump
	actor.target_id = selected if actors.has(selected) else -1
	actor.input_age = 0

func peer_actor(peer: int) -> int:
	for actor in actors.values():
		if actor.owner_peer == peer:
			return actor.actor_id
	return -1

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(round_epoch: int, seq: int, movement: Vector2, yaw: float, jump: bool, selected: int) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch or phase not in ["match", "countdown"]:
		return
	var id := peer_actor(multiplayer.get_remote_sender_id())
	if not actors.has(id) or seq <= actors[id].last_input_seq:
		return
	actors[id].last_input_seq = seq
	apply_input(id, movement, yaw, jump, selected)

func deliver_input(round_epoch: int, seq: int, movement: Vector2, yaw: float, jump: bool, selected: int) -> void:
	if latency_ms > 0:
		await get_tree().create_timer(latency_ms / 1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_input.rpc_id(1, round_epoch, seq, movement, yaw, jump, selected)

func deliver_snapshot(round_epoch: int, seq: int, states: Array, round_phase: String, time: float, start_time: float) -> void:
	if latency_ms > 0:
		await get_tree().create_timer(latency_ms / 1000.0).timeout
	if network and multiplayer.is_server() and epoch == round_epoch:
		var payload := var_to_bytes(states).compress(FileAccess.COMPRESSION_DEFLATE)
		receive_snapshot.rpc(round_epoch, seq, payload, round_phase, time, start_time)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot(round_epoch: int, seq: int, payload: PackedByteArray, round_phase: String, time: float, start_time: float) -> void:
	if round_epoch != epoch or seq <= last_snapshot or phase == "results":
		return
	var decoded = bytes_to_var(payload.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Array:
		return
	var states: Array = decoded
	last_snapshot = seq
	packets_received += 1
	for data in states:
		if actors.has(data.id):
			actors[data.id].receive(data)
			if data.id == local_id:
				prediction.pending = data.duplicate(true)
	if phase != "results":
		phase = round_phase
	elapsed = time
	countdown = start_time

@rpc("any_peer", "call_remote", "unreliable", 3)
func ping_host(stamp: int) -> void:
	if network and multiplayer.is_server():
		pong.rpc_id(multiplayer.get_remote_sender_id(), stamp)

@rpc("authority", "call_remote", "unreliable", 3)
func pong(stamp: int) -> void:
	round_trip_ms = Time.get_ticks_msec() - stamp

func tick_actor(actor, delta: float) -> void:
	ClassMechanics.tick(self, actor, delta)
	actor.action_budget = maxf(0, actor.action_budget - delta)
	actor.input_age += delta
	if actor.hp <= 0:
		actor.casting = -1
		actor.velocity = Vector3.ZERO
		return
	for i in range(actor.cooldowns.size()):
		actor.cooldowns[i] = maxf(0, actor.cooldowns[i] - delta)
	for field in ["gcd", "stunned", "locked", "shield", "sprint", "dr_timer"]:
		actor.set(field, maxf(0, actor.get(field) - delta))
	if actor.dr_timer == 0:
		actor.dr_count = 0
	if actor.owner_peer == 0:
		bot_think(actor, delta)
	elif actor.input_age > 0.3:
		actor.move_input = Vector2.ZERO
	if actor.stunned > 0:
		actor.casting = -1
	var direction := simulate_movement(actor, delta)
	actor.last_motion_seq = actor.last_input_seq
	if actor.casting >= 0:
		if direction.length() > 0.01 or not actor.is_on_floor():
			cancel_own_cast(actor, "Cast cancelled by movement")
		else:
			actor.cast_left -= delta
			if actor.cast_left <= 0:
				var slot: int = actor.casting
				var victim_id: int = actor.cast_target
				actor.casting = -1
				var reason := validate_spell(actor, slot, victim_id)
				if reason.is_empty():
					resolve_spell(actor, slot, actors.get(victim_id))
				else:
					feedback(actor, reason)

func simulate_movement(actor, delta: float) -> Vector3:
	if actor.hp <= 0:
		actor.velocity = Vector3.ZERO
		actor.jump_queued = false
		return Vector3.ZERO
	var direction: Vector3 = actor.basis * Vector3(actor.move_input.x, 0, actor.move_input.y)
	if actor.identity.root > 0 or actor.identity.hold > 0:
		direction = Vector3.ZERO
	if actor.stunned > 0:
		direction = Vector3.ZERO
	var speed := 6.5 if actor.move_input.y <= 0 else 3.8
	if actor.sprint > 0:
		speed *= 1.65
	if actor.identity.slow > 0 and actor.identity.immune <= 0:
		speed *= 0.55
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	if actor.jump_queued and actor.is_on_floor() and actor.stunned <= 0 and actor.identity.root <= 0 and actor.identity.hold <= 0:
		actor.velocity.y = 7
	actor.jump_queued = false
	actor.velocity.y -= 20 * delta
	actor.move_and_slide()
	return direction

func has_los(a, b) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a.position + Vector3.UP, b.position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func spell_target(actor, slot: int, requested: int) -> int:
	var kind: String = actor.kit[slot].kind
	if kind in Kits.SELF_KINDS:
		return actor.actor_id
	if kind in Kits.ALLY_KINDS:
		if actors.has(requested) and actors[requested].team == actor.team:
			return requested
		return actor.actor_id # Enemy or no target: helpful spells fall back to self.
	return requested

func validate_spell(actor, slot: int, victim_id: int) -> String:
	if not actors.has(victim_id) or actors[victim_id].hp <= 0:
		return "Select a living target"
	var victim = actors[victim_id]
	var spell: Dictionary = actor.kit[slot]
	var friendly: bool = spell.kind in Kits.ALLY_KINDS or spell.kind in Kits.SELF_KINDS
	# A pull is aimed at whoever is selected, ally or enemy — the only ability
	# that does not care which side the target is on. It still needs range,
	# line of sight and facing, because it is an aimed ability either way.
	if spell.kind == "pull":
		if victim == actor:
			return "Select another fighter"
	elif (victim.team == actor.team) != friendly:
		return "Select an ally" if friendly else "Select an enemy"
	var identity_reason: String = ClassMechanics.validate(self, actor, spell, victim)
	if not identity_reason.is_empty():
		return identity_reason
	if not friendly and victim.team != actor.team and not may_harm(actor, victim):
		return "Challenge them to a duel first"
	if victim == actor:
		return ""
	if actor.position.distance_to(victim.position) > float(spell.range):
		return "Out of range"
	if not has_los(actor, victim):
		return "Target is out of line of sight"
	if not friendly and (-actor.basis.z).dot((victim.position - actor.position).normalized()) < 0:
		return "Face your target"
	return ""

# Translates a hotbar position into the ability sitting in it. Everything below
# this point — cooldowns, validation, the server — still speaks in kit indices.
func kit_slot(bar_slot: int) -> int:
	if bar_slot < 0 or bar_slot >= assignment.size():
		return -1
	return assignment[bar_slot]

func send_action(slot: int) -> void:
	# In edit mode a hotbar click means "rebind me", not "cast me".
	if edit_mode:
		begin_rebind(slot)
		return
	if phase != "match" or not actors.has(local_id):
		return
	var ability := kit_slot(slot)
	if ability < 0:
		return
	if authoritative():
		try_spell(local_id, ability, selected_id)
	else:
		action_seq += 1
		deliver_action(epoch, action_seq, ability, selected_id)

func deliver_action(round_epoch: int, seq: int, slot: int, selected: int) -> void:
	if latency_ms > 0:
		await get_tree().create_timer(latency_ms / 1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_action.rpc_id(1, round_epoch, seq, slot, selected)

@rpc("any_peer", "call_remote", "reliable", 1)
func submit_action(round_epoch: int, seq: int, slot: int, selected: int) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch or phase != "match":
		return
	var id := peer_actor(multiplayer.get_remote_sender_id())
	if not actors.has(id) or seq <= actors[id].last_action_seq:
		return
	var actor = actors[id]
	actor.last_action_seq = seq
	if actor.action_budget > 0:
		return
	actor.action_budget = 0.05
	if slot == -1:
		cancel_own_cast(actor, "")
		return
	try_spell(id, slot, selected)

# Cancelling a cast before it goes off clears the global cooldown.
#
# The GCD is charged when the cast BEGINS, so without this you paid for a spell
# that never happened. Used by both cancel paths — Escape, and moving or leaving
# the ground — so they cannot drift apart.
func cancel_own_cast(actor, message: String) -> void:
	if actor.casting < 0:
		return
	var spell: Dictionary = actor.kit[actor.casting]
	actor.casting = -1
	if not spell.off:
		actor.gcd = 0.0
	if not message.is_empty():
		feedback(actor, message)

func try_spell(id: int, slot: int, requested: int) -> bool:
	if not authoritative() or phase != "match" or not actors.has(id) or slot < 0 or slot >= actors[id].kit.size():
		return false
	var actor = actors[id]
	if actor.hp <= 0 or actor.stunned > 0:
		return false
	var spell: Dictionary = actor.kit[slot]
	if actor.casting >= 0:
		feedback(actor, "Already casting")
		return false
	if actor.cooldowns[slot] > 0 or (actor.gcd > 0 and not spell.off):
		feedback(actor, "Ability is not ready")
		return false
	if actor.locked > 0 and actor.champion != "Vanguard" and spell.kind not in ["shield", "blink", "sprint"]:
		feedback(actor, "Spell school locked out")
		return false
	if actor.identity.root > 0 and spell.kind in ["blink", "charge", "cinder", "pilgrim", "intercede", "swap"]:
		feedback(actor, "Rooted")
		return false
	var victim_id := spell_target(actor, slot, requested)
	var reason := validate_spell(actor, slot, victim_id)
	if not reason.is_empty():
		feedback(actor, reason)
		return false
	if float(spell.cast) > 0:
		if actor.move_input.length() > 0.01 or not actor.is_on_floor():
			feedback(actor, "Stand still to cast")
			return false
		actor.casting = slot
		actor.cast_left = spell.cast
		actor.cast_target = victim_id
	else:
		resolve_spell(actor, slot, actors[victim_id])
	if not spell.off:
		actor.gcd = GCD_DURATION
	return true

func resolve_spell(actor, slot: int, victim) -> void:
	var spell: Dictionary = actor.kit[slot]
	actor.cooldowns[slot] = spell.cd
	if spell.kind not in Kits.SELF_KINDS and spell.kind not in Kits.ALLY_KINDS:
		actor.identity.hold = 0.0
	if ClassMechanics.resolve(self, actor, spell, victim):
		return
	match spell.kind:
		"damage":
			damage(actor, victim, spell.power)
		"heal", "self_heal":
			# Gentle dampening prevents healer stalemates in longer rounds.
			var dampening := clampf((elapsed - 60) / 180.0, 0, 0.7)
			var amount := minf(100 - victim.hp, spell.power * (1.0 - dampening))
			victim.hp = minf(100, victim.hp + amount)
			combat_event(actor.actor_id, victim.actor_id, "+%d" % ceili(amount), Color("97edb1"))
		"interrupt":
			if victim.casting >= 0:
				victim.casting = -1
				victim.locked = spell.power
				victim.lock_from = spell.name
				combat_event(actor.actor_id, victim.actor_id, "INTERRUPTED", GOLD)
			else:
				feedback(actor, "Interrupt missed — target was not casting")
		"control":
			var factor: float = [1.0, 0.5, 0.25, 0.0][mini(victim.dr_count, 3)]
			if factor == 0:
				combat_event(actor.actor_id, victim.actor_id, "IMMUNE", GOLD)
			else:
				victim.identity.disorient = false
				victim.stunned = spell.power * factor
				victim.stun_from = spell.name
				victim.casting = -1
				victim.dr_count += 1
				victim.dr_timer = 18 + victim.stunned
				combat_event(actor.actor_id, victim.actor_id, "STUN %.1fs" % victim.stunned, GOLD)
		"shield", "ally_shield":
			victim.shield = spell.power
			victim.shield_from = spell.name
			combat_event(actor.actor_id, victim.actor_id, "WARD", BLUE)
		"dispel":
			victim.stunned = 0
			victim.stun_from = ""
			victim.dr_timer = minf(victim.dr_timer, 18)
			combat_event(actor.actor_id, victim.actor_id, "DISPELLED", Color("97edb1"))
		"blink":
			move_ability(actor, -actor.basis.z * float(spell.power))
			combat_event(actor.actor_id, actor.actor_id, "BLINK", BLUE)
		"charge":
			var offset: Vector3 = victim.position - actor.position
			offset.y = 0
			move_ability(actor, offset.normalized() * maxf(0, offset.length() - 1.8))
			if actor.position.distance_to(victim.position) <= 3.5:
				damage(actor, victim, spell.power)
		"sprint":
			actor.sprint = spell.power
			actor.sprint_from = spell.name
			combat_event(actor.actor_id, actor.actor_id, "GRACE", Color("97edb1"))
		"pull":
			# Charge's arithmetic, applied to the target instead of the caster.
			# Stops 2m short so nobody ends up standing inside anyone.
			var pull_offset: Vector3 = actor.position - victim.position
			pull_offset.y = 0
			var travel := minf(float(spell.power), maxf(0.0, pull_offset.length() - 2.0))
			if travel > 0.0:
				move_ability(victim, pull_offset.normalized() * travel)
			combat_event(actor.actor_id, victim.actor_id, "TETHER", Color("c9a0ff"))

func move_ability(actor, motion: Vector3) -> void:
	# Sweep the character capsule: mobility cannot cross pillars or walls.
	if actor.identity.hold <= 0:
		actor.move_and_collide(motion)
		actor.motion_revision += 1

# In the world, damage only lands between two people who agreed to fight.
func may_harm(source, victim) -> bool:
	if not world_mode:
		return true
	return duels.get(source.actor_id, -1) == victim.actor_id

func damage(source, victim, amount: float) -> void:
	if not may_harm(source, victim):
		feedback(source, "Challenge them to a duel first")
		return
	if victim.hp <= 0:
		return
	amount = ClassMechanics.before_damage(self, source, victim, amount)
	var reduction := ClassMechanics.damage_multiplier(source, victim)
	var actual := minf(victim.hp, amount * reduction)
	if victim.identity.last > 0 and actual >= victim.hp:
		actual = maxf(0, victim.hp - 1)
		victim.identity.last = 0.0
		combat_event(source.actor_id, victim.actor_id, "LAST LIGHT", GOLD)
	victim.hp = maxf(0, victim.hp - actual)
	combat_event(source.actor_id, victim.actor_id, "−%d" % ceili(actual), RED)
	if victim.hp == 0:
		victim.casting = -1
		victim.move_input = Vector2.ZERO
		combat_event(source.actor_id, victim.actor_id, "DEFEATED", GOLD)
		if world_mode:
			end_duel(victim.actor_id, source.actor_id)

# --- duels --------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func challenge_duel(target_id: int) -> void:
	if not (network and multiplayer.is_server()):
		return
	offer_duel(actor_for_peer(multiplayer.get_remote_sender_id()), target_id)

func offer_duel(from_id: int, target_id: int) -> void:
	if not world_mode or from_id < 0 or not actors.has(target_id) or from_id == target_id:
		return
	if duels.has(from_id) or duels.has(target_id):
		return
	duel_offers[target_id] = from_id
	combat_event(from_id, target_id, "DUEL OFFERED", GOLD)
	var peer: int = actors[target_id].owner_peer
	if peer > 1 and network:
		duel_invited.rpc_id(peer, from_id, actors[from_id].champion)
	elif target_id == local_id:
		duel_invited(from_id, actors[from_id].champion)

@rpc("any_peer", "call_remote", "reliable")
func accept_duel() -> void:
	if not (network and multiplayer.is_server()):
		return
	confirm_duel(actor_for_peer(multiplayer.get_remote_sender_id()))

func confirm_duel(target_id: int) -> void:
	if not world_mode or not duel_offers.has(target_id):
		return
	var from_id: int = duel_offers[target_id]
	duel_offers.erase(target_id)
	if not actors.has(from_id) or duels.has(from_id) or duels.has(target_id):
		return
	duels[from_id] = target_id
	duels[target_id] = from_id
	# Both start clean, so a duel is never decided by who was already hurt.
	for id in [from_id, target_id]:
		actors[id].hp = 100
		actors[id].reset_identity()
		actors[id].stunned = 0
		actors[id].locked = 0
		actors[id].dr_count = 0
		actors[id].dr_timer = 0
	combat_event(from_id, target_id, "DUEL", GOLD)

func end_duel(loser_id: int, winner_id: int) -> void:
	duels.erase(loser_id)
	duels.erase(winner_id)
	for id in [loser_id, winner_id]:
		if actors.has(id):
			actors[id].reset_identity()
	combat_event(winner_id, loser_id, "DUEL WON", GOLD)
	# Losing a duel is not death: back up shortly, at full health.
	respawn_timers[loser_id] = 3.0

@rpc("authority", "call_remote", "reliable")
func duel_invited(from_id: int, champion: String) -> void:
	pending_offer = from_id
	say("%s challenges you to a duel — %s to accept" % [champion, control_label("accept_duel")])

# Spawns any roster member who does not yet have a body, without disturbing
# anyone already in the world.
func admit_to_world() -> void:
	var next_id := 1
	for actor in actors.values():
		next_id = maxi(next_id, actor.actor_id + 1)
	for peer in roster:
		var present := false
		for actor in actors.values():
			if actor.owner_peer == peer:
				present = true
		if present:
			continue
		var entry: Dictionary = roster[peer]
		spawn_actor(next_id, peer, entry.team, entry.champion, spawn_position(entry.team, next_id % 3))
		next_id += 1
	broadcast_round()

# Which actor a peer controls, or -1.
func actor_for_peer(peer: int) -> int:
	for actor in actors.values():
		if actor.owner_peer == peer:
			return actor.actor_id
	return -1

# Brings the defeated back rather than leaving a body in a persistent world.
func tick_world(delta: float) -> void:
	for id in respawn_timers.keys():
		respawn_timers[id] -= delta
		if respawn_timers[id] <= 0.0:
			respawn_timers.erase(id)
			if actors.has(id):
				var actor = actors[id]
				actor.hp = 100
				actor.reset_identity()
				actor.stunned = 0
				actor.locked = 0
				actor.shield = 0
				actor.position = spawn_position(actor.team, id % 3)
				combat_event(id, id, "RECOVERED", Color("97edb1"))

func check_winner() -> void:
	# A persistent world has no victory condition.
	if world_mode:
		return
	var alive := [0, 0]
	for actor in actors.values():
		if actor.hp > 0:
			alive[actor.team] += 1
	if alive[0] == 0 or alive[1] == 0:
		winner = 0 if alive[1] == 0 else 1
		finish_round(epoch, winner, make_snapshot())
		if network:
			finish_round.rpc(epoch, winner, make_snapshot())

@rpc("authority", "call_remote", "reliable")
func finish_round(round_epoch: int, winning_team: int, states: Array) -> void:
	if epoch != round_epoch:
		return
	winner = winning_team
	phase = "results"
	for data in states:
		if actors.has(data.id):
			actors[data.id].receive(data, authoritative())
	for actor in actors.values():
		actor.casting = -1
	panel.show()
	release_mouse()
	var victory: bool = actors.has(local_id) and actors[local_id].team == winner
	result_text.text = "%s — %s team wins" % ["VICTORY" if victory else "DEFEAT", "Blue" if winner == 0 else "Red"]
	status = "Host can start a rematch. Leave and host again to change the roster." if network else "Choose Local sparring for another round."
	refresh_lobby()
	if dedicated and authoritative():
		print("DEDICATED ROUND END winner=team%d elapsed=%.1fs" % [winner, elapsed])
		get_tree().create_timer(rematch_delay).timeout.connect(_dedicated_rematch)

func _dedicated_rematch() -> void:
	if not dedicated or not authoritative() or phase != "results":
		return
	if roster.size() >= min_players:
		print("DEDICATED REMATCH epoch=%d humans=%d/%d" % [epoch + 1, roster.size(), mode * 2])
		begin_round()
	else:
		phase = "lobby"
		status = "Waiting for %d players (%d connected)…" % [min_players, roster.size()]
		broadcast_lobby()
		print("DEDICATED WAITING humans=%d/%d" % [roster.size(), min_players])

func bot_think(actor, delta: float) -> void:
	actor.move_input = Vector2.ZERO
	actor.ai_timer -= delta
	actor.path_timer -= delta
	if actor.stunned > 0:
		return
	var enemies: Array = []
	var friends: Array = []
	for other in actors.values():
		if other.hp <= 0:
			continue
		if other.team == actor.team:
			friends.append(other)
		else:
			enemies.append(other)
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a, b): return actor.position.distance_squared_to(a.position) < actor.position.distance_squared_to(b.position))
	friends.sort_custom(func(a, b): return a.hp < b.hp)
	var foe = enemies[0]
	var ally = friends[0]
	var destination = ally if actor.champion == "Luminary" and ally.hp < 76 else foe
	actor.target_id = destination.actor_id
	var offset: Vector3 = destination.position - actor.position
	offset.y = 0
	if offset.length() > 0.1:
		actor.look_at(actor.position + offset, Vector3.UP)
	var visible := has_los(actor, destination)
	var desired_range := 2.8 if actor.champion == "Vanguard" else 20.0
	if actor.casting < 0 and (not visible or offset.length() > desired_range):
		if actor.path_timer <= 0:
			actor.path_timer = 0.45
			actor.path = nav.route(actor.position, destination.position)
		var point := Vector2(actor.position.x, actor.position.z)
		while actor.path.size() > 0 and point.distance_to(actor.path[0]) < 0.55:
			actor.path.remove_at(0)
		if actor.path.size() > 0:
			var next := Vector3(actor.path[0].x, actor.position.y, actor.path[0].y)
			var direction: Vector3 = (next - actor.position).normalized()
			var local: Vector3 = actor.basis.inverse() * direction
			actor.move_input = Vector2(local.x, local.z)
	elif actor.casting < 0 and actor.champion != "Vanguard" and destination == foe and offset.length() < 7:
		# Kite toward a clear cell, instead of backing into a pillar.
		var retreat: Vector3 = actor.position - offset.normalized() * 3
		var cell: Vector2i = nav.nearest(retreat)
		var direction: Vector3 = Vector3(cell.x, actor.position.y, cell.y) - actor.position
		if direction.length() > 0.5:
			var local: Vector3 = actor.basis.inverse() * direction.normalized()
			actor.move_input = Vector2(local.x, local.z)
	if actor.ai_timer > 0 or actor.casting >= 0:
		return
	actor.ai_timer = 0.25
	if ClassMechanics.bot(self, actor, foe, ally):
		return
	if actor.hp < 45 and try_spell(actor.actor_id, 4, actor.actor_id):
		return
	if actor.champion == "Luminary":
		if ally.stunned > 0 and try_spell(actor.actor_id, 2, ally.actor_id):
			return
		if ally.hp < 76:
			if try_spell(actor.actor_id, 1, ally.actor_id):
				return
			if visible and offset.length() < 27:
				actor.move_input = Vector2.ZERO
				if try_spell(actor.actor_id, 5, ally.actor_id):
					return
	else:
		if foe.casting >= 0 and foe.cast_left < 1.0 and try_spell(actor.actor_id, 2, foe.actor_id):
			return
		if actor.champion == "Vanguard" and offset.length() > 7 and try_spell(actor.actor_id, 6, foe.actor_id):
			return
		if actor.champion == "Ember" and offset.length() < 5 and actor.cooldowns[6] == 0:
			actor.rotation.y += PI
			try_spell(actor.actor_id, 6, actor.actor_id)
			return
		if actor.hp < 55 and not visible:
			actor.move_input = Vector2.ZERO
			if try_spell(actor.actor_id, 5, actor.actor_id):
				return
	if visible and offset.length() <= desired_range:
		actor.move_input = Vector2.ZERO
		if foe.stunned <= 0 and try_spell(actor.actor_id, 3, foe.actor_id):
			return
		if actor.champion != "Luminary" and try_spell(actor.actor_id, 1, foe.actor_id):
			return
		try_spell(actor.actor_id, 0, foe.actor_id)

func feedback(actor, text: String) -> void:
	if actor.owner_peer == 0:
		return
	if actor.actor_id == local_id:
		say(text)
	elif network:
		private_notice.rpc_id(actor.owner_peer, epoch, text)

@rpc("authority", "call_remote", "reliable")
func private_notice(round_epoch: int, text: String) -> void:
	if round_epoch == epoch:
		say(text)

func combat_event(source: int, victim: int, text: String, color: Color) -> void:
	show_event(epoch, source, victim, text, color)
	if network:
		show_event.rpc(epoch, source, victim, text, color)

@rpc("authority", "call_remote", "reliable")
func show_event(round_epoch: int, source: int, victim: int, text: String, color: Color) -> void:
	if round_epoch != epoch:
		return
	if not actors.has(victim):
		say(text)
		return
	var actor = actors[victim]
	actor.flash = 0.16
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.position = actor.position + Vector3(randf_range(-0.3, 0.3), 3, 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.5, 1.1)
	tween.tween_property(label, "modulate:a", 0.0, 1.1)
	tween.chain().tween_callback(label.queue_free)
	if source != victim and actors.has(source):
		if actors[source].champion == "Vanguard" and text.begins_with("−"):
			actors[source].champion_model.present_strike()
			preload("res://scripts/vanguard_strike.gd").spawn(self, actors[source].position, actor.position, actors[source].base_color)
		else:
			beam(actors[source].position, actor.position, color)

func beam(from: Vector3, to: Vector3, color: Color) -> void:
	if from.distance_to(to) < 0.01:
		return
	var effect := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.height = from.distance_to(to)
	effect.mesh = mesh
	effect.material_override = material(color, true)
	add_child(effect)
	effect.position = (from + to) * 0.5 + Vector3.UP
	effect.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	get_tree().create_timer(0.16).timeout.connect(effect.queue_free)

func say(text: String) -> void:
	notice.text = text
	notice_time = 3.5

# Placeholder HUD shown while arranging the layout outside a match. Everything
# is positioned exactly as it will be in play; only the contents are invented.
func show_edit_previews() -> void:
	var champion: String = Kits.NAMES[champion_choice.selected]
	var kit: Array = Kits.get_kit(champion)
	for entry in [[player_frame, "YOU", champion], [target_frame, "TARGET", "Luminary"], [focus_frame, "FOCUS", "Vanguard"]]:
		var frame: VBoxContainer = entry[0]
		frame.visible = true
		(frame.get_child(0) as Label).text = "%s · %s" % [entry[1], entry[2]]
		var bar := frame.get_child(1) as ProgressBar
		bar.value = 100
		(bar.get_child(0) as Label).text = "100 / 100 HP"
		(frame.get_child(2) as ProgressBar).visible = false
		(frame.get_child(3) as Label).text = ""
		for chip in (frame.get_child(4) as HBoxContainer).get_children():
			(chip as PanelContainer).hide()
	party_box.visible = true
	enemy_box.visible = true
	for i in range(3):
		party_buttons[i].visible = true
		party_buttons[i].text = "%s  %s   100 HP" % [control_label("party_%d" % (i + 1)), Kits.NAMES[i]]
		enemy_buttons[i].visible = true
		enemy_buttons[i].text = "%s  100 HP" % Kits.NAMES[i]
	for slot in range(ability_buttons.size()):
		var button := ability_buttons[slot]
		button.visible = true
		cooldown_overlays[slot].sync(0.0, 0.0, false)
		var ability := kit_slot(slot)
		if ability < 0:
			button.modulate = Color(1, 1, 1, 0.45)
			button.text = ""
			ability_images[slot].visible = false
			continue
		button.modulate = Color.WHITE
		var spell: Dictionary = kit[ability]
		var art := AbilityArt.texture_for(spell.name)
		ability_images[slot].texture = art
		ability_images[slot].visible = art != null
		button.text = "" if art != null else spell.name

func update_frame(frame: VBoxContainer, id: int, prefix: String) -> void:
	frame.set_meta("actor_id", id)
	frame.visible = actors.has(id)
	if not frame.visible:
		return
	var actor = actors[id]
	(frame.get_child(0) as Label).text = "%s · %s" % [prefix, actor.champion]
	var health := frame.get_child(1) as ProgressBar
	health.value = actor.hp
	var friendly: bool = actors.has(local_id) and actor.team == actors[local_id].team
	var fill := health.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Kits.color(actor.champion)
	# Class colour fills the bar, so the border is the only thing left saying
	# which side someone is on. It has to be bold and it has to be there at full
	# health, which means drawing it over the fill rather than behind it.
	paint_bar_edge(health, BLUE if friendly else ENEMY_EDGE, 1 if friendly else 3)
	(health.get_child(0) as Label).text = "%d / 100 HP" % ceili(actor.hp)
	var cast := frame.get_child(2) as ProgressBar
	cast.visible = actor.casting >= 0
	if actor.casting >= 0:
		var total: float = actor.kit[actor.casting].cast
		cast.value = 100 * (1 - actor.cast_left / maxf(0.01, total))
		(cast.get_child(0) as Label).text = "%s · %.1fs" % [actor.kit[actor.casting].name, actor.cast_left]
	(frame.get_child(3) as Label).text = "DEFEATED" if actor.hp <= 0 else ""
	var strip := frame.get_child(4) as HBoxContainer
	var auras := Auras.active(actor)
	for i in range(AURA_SLOTS):
		var chip := strip.get_child(i) as PanelContainer
		if i < auras.size():
			paint_aura(chip, auras[i])
		else:
			chip.hide()
			if chip.has_meta("aura"):
				chip.remove_meta("aura")

func update_visuals(delta: float) -> void:
	champion_choice.disabled = network
	mode_choice.disabled = network
	resume_button.disabled = phase not in ["match", "countdown"]
	start_button.visible = network and multiplayer.is_server() and phase in ["lobby", "results"]
	notice_time -= delta
	if notice_time <= 0:
		notice.text = ""
	if phase == "countdown":
		notice.text = "Arena opens in %d" % ceili(countdown)
	if actors.has(local_id):
		pivot.position = actors[local_id].position + Vector3(0, 1.6, 0)
	for actor in actors.values():
		actor.visual_tick(delta, camera)
	ring.visible = actors.has(selected_id) and actors[selected_id].hp > 0
	if ring.visible:
		ring.position = actors[selected_id].position + Vector3(0, 0.08, 0)
	if edit_mode and not actors.has(local_id):
		# Editing from the menu, with no match running. WoW shows dummy frames
		# for exactly this reason: otherwise there is nothing on screen to drag.
		show_edit_previews()
		return
	update_frame(player_frame, local_id, "YOU")
	update_frame(target_frame, selected_id, "TARGET")
	update_frame(focus_frame, focus_id, "FOCUS")
	var connection := "LOCAL" if not network else ("HOST" if multiplayer.is_server() else "%dms RTT" % round_trip_ms)
	scoreboard.text = "STARFALL   /   %dv%d   /   %s                                      %02d:%02d" % [mode, mode, connection, int(elapsed) / 60, int(elapsed) % 60]
	if elapsed > 60:
		scoreboard.text += "  Healing −%d%%" % int(clampf((elapsed - 60) / 180.0, 0, 0.7) * 100)
	var party := party_ids()
	party_box.visible = not party.is_empty()
	for i in range(3):
		party_buttons[i].visible = i < party.size()
		if i < party.size():
			var member = actors[party[i]]
			paint_roster_row(party_buttons[i], member, "%s  %s" % [control_label("party_%d" % (i + 1)), member.champion], true)
	var enemies := enemy_ids()
	enemy_box.visible = not enemies.is_empty()
	for i in range(3):
		enemy_buttons[i].visible = i < enemies.size()
		if i < enemies.size():
			var foe = actors[enemies[i]]
			paint_roster_row(enemy_buttons[i], foe, foe.champion, false)
	for actor in actors.values():
		var hostile: bool = actors.has(local_id) and actor.team != actors[local_id].team
		actor.mark_hostile(hostile)
		# Your own effects are already on the personal strip and the centre-screen
		# readout; repeating them over your own head is noise.
		var overhead: Array = [] if actor.actor_id == local_id else Auras.active(actor)
		actor.paint_nameplate_auras(overhead, AbilityArt)
	paint_self_auras()
	# Before the bar: it maintains cc_total, which the slots use as the sweep
	# denominator.
	update_cc_tracker()
	ClassMechanics.paint(self)
	for slot in range(TOTAL_SLOTS):
		var button := ability_buttons[slot]
		var ability := kit_slot(slot)
		# Empty slots stay hidden in play and visible while editing, so there is
		# somewhere to drop an ability.
		button.visible = actors.has(local_id) and (ability >= 0 or edit_mode or drag_slot >= 0)
		if not button.visible:
			continue
		if ability < 0:
			button.text = ""
			ability_images[slot].visible = false
			cooldown_overlays[slot].sync(0.0, 0.0, false)
			button.modulate = Color(1, 1, 1, 0.45)
			continue
		var actor = actors[local_id]
		var spell: Dictionary = actor.kit[ability]
		var art := AbilityArt.texture_for(spell.name)
		ability_images[slot].texture = art
		ability_images[slot].visible = art != null
		ability_images[slot].modulate = Color("b6a4cf") if button.button_pressed else Color.WHITE
		# Unillustrated abilities retain the existing text fallback.
		button.text = "" if art != null or actor.cooldowns[ability] > 0.0 else spell.name
		# The ability's own cooldown wins the slot: it is the longer wait and the
		# one worth a number. The global cooldown only shows where nothing else is
		# running, and never on an off-GCD ability.
		var own: float = actor.cooldowns[ability]
		var global_cd: float = 0.0 if spell.off else actor.gcd
		# Crowd control is a real reason the slot is unusable, so it sweeps too.
		# Whichever wait is LONGER wins the slot, because that is the honest
		# answer to "when can I press this" — a 16s cooldown outlives a 2s stun,
		# and a 4s lockout outlives a spell that is already off cooldown.
		var held: float = cc_block_remaining(actor, spell)
		# A slot you cannot press because you are held reads as unusable, not just
		# as counting down.
		button.modulate = Color(0.55, 0.58, 0.72) if held > 0.0 else Color.WHITE
		if held > own and held > 0.0:
			cooldown_overlays[slot].sync(held, maxf(cc_total, held), false)
		elif own > 0.0:
			cooldown_overlays[slot].sync(own, maxf(spell.cd, own), false)
		elif global_cd > 0.0:
			cooldown_overlays[slot].sync(global_cd, GCD_DURATION, true)
		else:
			cooldown_overlays[slot].sync(0.0, 0.0, false)
		if actor.hp <= 0:
			button.modulate = Color("83919e")
	update_ability_tooltip()

# Aura strips live at child index 4 of a unit frame. Party and enemy rows are
# plain buttons with no strip, so they are skipped rather than special-cased.
func chip_in_strip(strip: HBoxContainer, pointer: Vector2) -> PanelContainer:
	if strip == null or not strip.is_visible_in_tree():
		return null
	for child in strip.get_children():
		var panel := child as PanelContainer
		if panel.visible and panel.has_meta("aura") and panel.get_global_rect().has_point(pointer):
			return panel
	return null

func aura_chip_at(frame: Node, pointer: Vector2) -> PanelContainer:
	if frame == null or not (frame is VBoxContainer) or frame.get_child_count() < 5:
		return null
	if not (frame as Control).is_visible_in_tree():
		return null
	for chip in (frame.get_child(4) as HBoxContainer).get_children():
		var panel := chip as PanelContainer
		if panel.visible and panel.has_meta("aura") and panel.get_global_rect().has_point(pointer):
			return panel
	return null

# Your own buffs and debuffs, top right, the way an MMO puts them.
func paint_self_auras() -> void:
	if self_auras == null:
		return
	var mine: Array = Auras.active(actors[local_id]) if actors.has(local_id) else []
	self_auras.visible = not mine.is_empty() or edit_mode
	for i in range(AURA_SLOTS):
		var chip := self_auras.get_child(i) as PanelContainer
		if i < mine.size():
			paint_aura(chip, mine[i])
		else:
			chip.hide()
			if chip.has_meta("aura"):
				chip.remove_meta("aura")

func paint_roster_row(button: Button, actor, title: String, friendly: bool) -> void:
	var bar := roster_bar(button)
	if bar == null:
		return
	bar.value = actor.hp
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Kits.color(actor.champion)
	paint_bar_edge(bar, BLUE if friendly else ENEMY_EDGE, 1 if friendly else 3)
	(bar.get_child(0) as Label).text = "%s   %d HP%s" % [title, ceili(actor.hp), "  STUN" if actor.stunned > 0 else ""]

func party_ids() -> Array[int]:
	var ids: Array[int] = []
	if not actors.has(local_id):
		return ids
	ids.append(local_id)
	for actor in actors.values():
		if actor.team == actors[local_id].team and actor.actor_id != local_id:
			ids.append(actor.actor_id)
	return ids

func select_party(index: int) -> void:
	var ids := party_ids()
	if index < ids.size():
		selected_id = ids[index]

func cycle_target(direction: int = 1) -> void:
	if not actors.has(local_id):
		return
	var candidates: Array[int] = []
	for actor in actors.values():
		if actor.team != actors[local_id].team and actor.hp > 0:
			candidates.append(actor.actor_id)
	if not candidates.is_empty():
		var current := candidates.find(selected_id)
		selected_id = candidates[(0 if direction > 0 else candidates.size() - 1) if current < 0 else posmod(current + direction, candidates.size())]

func _input(event: InputEvent) -> void:
	if keybind_menu != null and keybind_menu.visible:
		if keybind_menu.handle(event):
			get_viewport().set_input_as_handled()
		return
	if edit_mode and handle_edit_input(event):
		return
	if handle_shift_drag(event):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			release_mouse()
	if event is InputEventMouseMotion and not panel.visible:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			pivot.rotation.y -= event.relative.x * 0.004
			arm.rotation.x = clampf(arm.rotation.x - event.relative.y * 0.004, -1.15, 0.12)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				local_yaw = pivot.rotation.y
	# The game launches fullscreen, so it has to offer a way back out. F11 and
	# Alt+Enter are both what people already try.
	if event is InputEventKey and event.pressed and not event.echo:
		var alt_enter: bool = event.keycode == KEY_ENTER and event.alt_pressed
		if event.keycode == KEY_F11 or alt_enter:
			var full: bool = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if panel.visible and phase in ["match", "countdown"]:
			panel.hide()
		elif actors.has(local_id) and actors[local_id].casting >= 0:
			if authoritative():
				actors[local_id].casting = -1
			else:
				action_seq += 1
				deliver_action(epoch, action_seq, -1, selected_id)
		elif selected_id != -1:
			selected_id = -1
		else:
			panel.show()
			release_mouse()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible or keybind_menu.visible or edit_mode or phase not in ["match", "countdown"]:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(3, arm.spring_length - 0.8)
			camera_dirty = true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(18, arm.spring_length + 0.8)
			camera_dirty = true
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			capture_mouse()
	if event is InputEventKey and event.pressed and not event.echo:
		var pressed_binding := event_binding(event)
		# C challenges whoever you have targeted; Y accepts an offer. Both route
		# through the server, which owns the pairing.
		if world_mode and controls.matches("challenge", pressed_binding) and selected_id != -1:
			if authoritative():
				offer_duel(local_id, selected_id)
			else:
				challenge_duel.rpc_id(1, selected_id)
			return
		if world_mode and controls.matches("accept_duel", pressed_binding) and pending_offer != -1:
			if authoritative():
				confirm_duel(local_id)
			else:
				accept_duel.rpc_id(1)
			pending_offer = -1
			return
		var bound := binds.find(pressed_binding)
		if bound < 0:
			bound = controls.secondary.find(pressed_binding)
		if bound >= 0 and pressed_binding != 0:
			send_action(bound)
		if controls.matches("target_next", pressed_binding):
			cycle_target()
		if controls.matches("target_previous", pressed_binding):
			cycle_target(-1)
		for i in range(3):
			if controls.matches("party_%d" % (i + 1), pressed_binding):
				select_party(i)
		if controls.matches("set_focus", pressed_binding):
			focus_id = selected_id
		if controls.matches("target_focus", pressed_binding) and actors.has(focus_id):
			selected_id = focus_id
		if controls.matches("jump", pressed_binding):
			queued_jump = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_mouse(false)
		queued_jump = false
	# Flush on quit: anything changed since the last explicit save — a camera
	# zoom in particular — was otherwise lost when the window closed.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and config != null and arm != null and not binds.is_empty():
		save_layout()

func parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	var wants_dedicated := false
	var explicit_port := 0
	for arg in args:
		if arg.begins_with("--latency-ms="):
			latency_ms = clampi(int(arg.get_slice("=", 1)), 0, 500)
		elif arg == "--team":
			mode_choice.select(1)
		elif arg.begins_with("--mode="):
			mode_choice.select(1 if arg.get_slice("=", 1) == "team" else 0)
		elif arg.begins_with("--champion="):
			var choice := Kits.NAMES.find(arg.get_slice("=", 1))
			if choice >= 0:
				champion_choice.select(choice)
		elif arg == "--dedicated":
			wants_dedicated = true
		elif arg == "--lobby":
			private_lobby = true
		elif arg == "--world":
			world_mode = true
		elif arg.begins_with("--port="):
			explicit_port = clampi(int(arg.get_slice("=", 1)), 1, 65535)
		elif arg.begins_with("--min-players="):
			min_players = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--rematch-delay="):
			rematch_delay = maxf(0.5, float(arg.get_slice("=", 1)))
	if wants_dedicated:
		mode = mode_choice.get_selected_id()
		# The world opens for the first person through the door, whether or not
		# its port was given explicitly — this used to sit inside the port branch
		# and was skipped whenever --port was passed, which compose always does.
		if world_mode:
			min_players = 1
		if explicit_port > 0:
			current_port = explicit_port
		elif world_mode:
			current_port = Config.WORLD_PORT
		elif private_lobby:
			current_port = Config.LOBBY_PORTS[0]
		else:
			current_port = Config.DUEL_PORT if mode == 1 else Config.TEAM_PORT
		host_session(true, world_mode)
		return
	for arg in args:
		if arg == "--host":
			host_session()
		elif arg.begins_with("--join="):
			address.text = arg.get_slice("=", 1)
			join_session()
		elif arg == "--local":
			local_match()

func capture_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		mouse_capture_origin = ui.get_global_mouse_position()
		has_capture_origin = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse(restore_position: bool = true) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_capture_origin and restore_position:
		get_viewport().warp_mouse(mouse_capture_origin)
	has_capture_origin = false

func on_unit_frame_input(event: InputEvent, frame: VBoxContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var id: int = frame.get_meta("actor_id", -1)
		if actors.has(id):
			selected_id = id
		frame.accept_event()

func enemy_ids() -> Array[int]:
	var ids: Array[int] = []
	if actors.has(local_id):
		for actor in actors.values():
			if actor.team != actors[local_id].team:
				ids.append(actor.actor_id)
	return ids

func select_enemy(index: int) -> void:
	var ids := enemy_ids()
	if index >= 0 and index < ids.size():
		selected_id = ids[index]

func update_ability_tooltip() -> void:
	if panel.visible or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not actors.has(local_id):
		ability_tooltip.hide()
		return
	var pointer := ui.get_global_mouse_position()
	var strip_chip := chip_in_strip(self_auras, pointer)
	if strip_chip != null:
		var mine: Dictionary = strip_chip.get_meta("aura")
		ability_tooltip.present_text("%s\n\n%s\n\n%s remaining" % [
			mine.name, mine.description, format_aura_time(mine.remaining)], pointer, ui.size)
		return
	for frame in [player_frame, target_frame, focus_frame] + party_buttons + enemy_buttons:
		var chip := aura_chip_at(frame, pointer)
		if chip != null:
			var aura: Dictionary = chip.get_meta("aura")
			ability_tooltip.present_text("%s\n\n%s\n\n%s remaining" % [
				aura.name, aura.description, format_aura_time(aura.remaining)], pointer, ui.size)
			return
	for slot in range(ability_buttons.size()):
		var button := ability_buttons[slot]
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pointer):
			# `slot` is a position on a bar, not an index into the kit. With three
			# bars there are 21 positions and 12 abilities, so this has to be
			# translated — and an empty slot has nothing to describe.
			var ability := kit_slot(slot)
			if ability < 0:
				break
			var actor = actors[local_id]
			ability_tooltip.present(actor.kit[ability], actor.champion, pointer, ui.size)
			return
	ability_tooltip.hide()

func reset_all_keybinds() -> void:
	controls.actions = controls.DEFAULTS.duplicate(true)
	controls.secondary.fill(0)
	for slot in range(TOTAL_SLOTS):
		binds[slot] = (KEY_1 + slot) if slot < BAR_SLOTS else ((KEY_1 + slot - BAR_SLOTS) | KEY_MASK_SHIFT if slot < Kits.KIT_SIZE else 0)
	refresh_binds()
	save_layout()

func control_label(action: String) -> String:
	for binding in controls.actions[action]:
		if binding != 0:
			return OS.get_keycode_string(binding)
	return "Unbound"
