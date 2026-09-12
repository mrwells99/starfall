extends "res://scripts/arena_world.gd"
const CC = preload("res://scripts/crowd_control.gd")

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
const Outlaw = preload("res://scripts/outlaw_mechanics.gd")
var aimed_combat = preload("res://scripts/aimed_combat.gd").new()
var outlaw_detonation = preload("res://scripts/outlaw_detonation.gd").new()
var hitboxes_enabled := true
signal aimed_shot_resolved(result: Dictionary)
var outlaw_fx
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
const UNKICKABLE_CAST_COLOR := Color("808080")

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
var selected_id := -1:
	set(value):
		var opponent: int=locked_target_for(local_id)
		var candidate: int = opponent if opponent!=-1 else value
		selected_id = candidate if not actors.has(local_id) or not actors.has(candidate) or Null.targetable(self,actors[local_id],actors[candidate]) else -1
var focus_id := -1
var phase := "menu"
var mode := 1
var winner := -1
var elapsed := 0.0
var countdown := 0.0
var epoch := 0
var nav = preload("res://scripts/arena_navigation.gd").new()
const Null = preload("res://scripts/null_mechanics.gd")
const VanguardCharge = preload("res://scripts/vanguard_charge.gd")
const BlinkCharges = preload("res://scripts/blink_charges.gd")
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var menu_camera: Camera3D
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
var actors_by_peer: Dictionary = {}
var status := ""
var notice_time := 0.0
var snapshot_timer := 0.0
var input_seq := 0
var action_seq := 0
var last_snapshot := -1
var snapshot_seq := 0
var local_yaw := 0.0
var queued_jump := false
var movement_controls = preload("res://scripts/movement_controls.gd").new()
var camera_character_fade = preload("res://scripts/camera_character_fade.gd").new()
var jump_serial := 0
var pending_jump_id := 0
var jump_sent_at := 0
var pending_jump_revision := 0
const JUMP_RETRY_MS := 350
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
var previous_frame_cap := -1
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
var player_options
var controls = preload("res://scripts/key_bindings.gd").new()
var prediction = preload("res://scripts/movement_prediction.gd").new()
var keybind_menu
var match_settings: Button
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
var social
var network_handshake
var recovery
var chat_last_sent := {}
var next_world_actor_id := 1
const TrainingDummies = preload("res://scripts/training_dummies.gd")
var world_mode := false:
	set(value):
		world_mode = value
		if is_inside_tree():
			set_world_starwalk(value)
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
var offline_rematch_button: Button
var quit_button: Button
var menu_presentation = preload("res://scripts/menu_presentation.gd").new()
var combat_text = preload("res://scripts/combat_text.gd").new()
var spectator = preload("res://scripts/spectator_presentation.gd").new()
var round_summary: Label
var result_info: Dictionary = {}
var rematch_deadline := 0
var graphics_choice: OptionButton
var frame_limit_choice: OptionButton
var render_scale_choice: OptionButton
var fps_toggle: CheckButton
var performance_label: Label
var application_focused := true
var performance_timer := 0.0
var availability_timer := 0.0
var ability_reasons: Dictionary = {}
var searching := false
var outlaw_aim_test = preload("res://scripts/outlaw_aim_test.gd").new()

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Input.use_accumulated_input = false
	movement_controls.game = self
	controls.setup(TOTAL_SLOTS)
	build_arena()
	set_world_starwalk(world_mode)
	build_camera()
	build_ui()
	recovery = preload("res://scripts/session_recovery.gd").new()
	recovery.setup(self)
	if not dedicated: recovery.install_ui()
	network_handshake = preload("res://scripts/network_handshake.gd").new()
	network_handshake.setup(self)
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(func(): leave_session("Host disconnected."))
	# ENet emits this signal before removing the departing peer from its send
	# list. Process departures after polling so lobby/world RPCs cannot target
	# the connection whose channels have already been torn down.
	multiplayer.peer_disconnected.connect(on_peer_left, CONNECT_DEFERRED)
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
	if not dedicated:
		outlaw_fx = preload("res://scripts/outlaw_effects.gd").new()
		add_child(outlaw_fx)
		outlaw_fx.install(self)
		outlaw_aim_test.setup(self)

func initialise_player_config() -> void:
	if dedicated:
		return
	load_settings()
	register_movable_frames()
	apply_slot_size(slot_size)
	ui.resized.connect(keep_action_bars_on_screen, CONNECT_DEFERRED)
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
	pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pivot.position = Vector3(0, 1.6, 9)
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = movement_controls.ZOOM_MAX
	arm.rotation.x = -0.38
	arm.collision_mask = 1
	# Sweep a small volume so steep upward views retract above floors and
	# ledges instead of letting the near plane clip through them.
	var camera_clearance := SphereShape3D.new()
	camera_clearance.radius = 0.20
	arm.shape = camera_clearance
	arm.margin = 0.04
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.current = true
	arm.add_child(camera)
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.position = Vector3(24, 23, 30)
	menu_camera.look_at(Vector3(0, 0, 0))
	menu_camera.fov = 58
	menu_camera.make_current()
	ring = MeshInstance3D.new()
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.91
	ring.mesh = torus
	ring.material_override = material(Color.WHITE, true)
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
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	var amount := Label.new()
	bar.add_child(amount)
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.add_theme_color_override("font_shadow_color", Color.BLACK)
	amount.add_theme_color_override("font_color", UI_TEXT)
	amount.add_theme_constant_override("shadow_offset_x", 1)
	amount.add_theme_constant_override("shadow_offset_y", 1)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := Panel.new()
	edge.name = "Edge"
	edge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
const ENEMY_EDGE := Color("df7385")

func hud_health_color(champion: String) -> Color:
	return Kits.color(champion).lerp(Color("131b2b"), 0.48)

func paint_bar_edge(bar: ProgressBar, color: Color, width: int) -> void:
	var edge := bar_edge(bar)
	if edge == null:
		return
	# Each bar owns one style. Replacing it every tick invalidates the HUD theme
	# and allocates hundreds of resources per second in a six-player match.
	var box: StyleBoxFlat
	if edge.has_theme_stylebox_override("panel"):
		box = edge.get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = Color.TRANSPARENT
		box.set_corner_radius_all(4)
		edge.add_theme_stylebox_override("panel", box)
	if box.border_color != color:
		box.border_color = color
	if box.border_width_left != width:
		box.set_border_width_all(width)

# A party or enemy row: still a Button so clicking it targets, but the health is
# a real bar rather than a number. The bar is a child so the button keeps its
# rect for click-to-target; the button's own text is left empty and the label
# inside the bar carries the words, or the button would draw underneath it.
func install_dr_column(button: Button, left: bool) -> void:
	button.custom_minimum_size.x = 330
	var health := roster_bar(button)
	health.anchor_right = 0
	health.offset_left = 114 if left else 4
	health.offset_right = 326 if left else 216
	var details = button.get_node("Details")
	details.anchor_right = 0
	details.offset_left = health.offset_left
	details.offset_right = health.offset_right
	var diminishing = preload("res://scripts/dr_icons.gd").new()
	diminishing.name = "DiminishingReturns"
	button.add_child(diminishing)
	diminishing.install(self)
	diminishing.add_theme_constant_override("h_separation", 2)
	diminishing.add_theme_constant_override("v_separation", 2)
	for chip in diminishing.get_children():
		chip.custom_minimum_size = Vector2(28, 28)
	diminishing.left_side = left
	diminishing.position.x = 4 if left else 224
	var badge = preload("res://scripts/team_badge.gd").new()
	badge.name = "TeamBadge"
	badge.hostile = left
	badge.position = Vector2(332 if left else -22, 12)
	badge.size = Vector2(18, 18)
	button.add_child(badge)

func roster_row(parent: Node, callback: Callable) -> Button:
	var button := add_button(parent, "", callback)
	button.custom_minimum_size = Vector2(220, 64)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	var bar := styled_bar(UI_EDGE, 40)
	bar.custom_minimum_size = Vector2(0, 40)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 4
	bar.offset_right = -4
	bar.offset_top = 4
	bar.anchor_bottom = 0
	bar.offset_bottom = 44
	button.add_child(bar)
	var percentage := bar.get_child(0) as Label
	percentage.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	percentage.offset_left = -62
	percentage.offset_right = -4
	percentage.offset_top = 1
	percentage.offset_bottom = 22
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var resource = preload("res://scripts/thin_resource_bar.gd").new()
	resource.name = "ThinResource"
	bar.add_child(resource)
	resource.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	resource.offset_left = 3
	resource.offset_right = -3
	resource.offset_top = -12
	resource.offset_bottom = -2
	var details = preload("res://scripts/arena_frame_details.gd").new()
	details.name = "Details"
	button.add_child(details)
	details.install(self)
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
	add_label(frame, "", 15).hide()
	frame.add_child(styled_bar(color, 27))
	frame.add_child(styled_bar(GOLD, 22))
	var state = add_label(frame, "", 14)
	var meter = preload("res://scripts/resource_meter.gd").new()
	meter.name = "ResourceMeter"
	state.add_child(meter)
	meter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var chronoshift = preload("res://scripts/chronoshift_status.gd").new()
	chronoshift.name = "ChronoshiftStatus"
	# Its host is not the VBoxContainer itself: that container owns the layout of
	# direct Control children. ChronoshiftStatus derives its manual offset from
	# this state line so it can render above the whole health frame.
	state.add_child(chronoshift)
	chronoshift.install()
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
	chip.custom_minimum_size = Vector2(30, 30)
	chip.hide()
	# A fixed tile overlays the countdown on its icon without widening the strip.
	var row := Control.new()
	row.custom_minimum_size = Vector2(28, 28)
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var art := TextureRect.new()
	art.name = "Icon"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(22, 22)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return chip

func paint_aura(chip: PanelContainer, aura: Dictionary) -> void:
	chip.show()
	chip.set_meta("aura", aura)
	var tint: Color = aura.color
	# Reuse the chip's style. Allocating and registering a new material-like UI
	# resource for every visible aura at 60 Hz creates avoidable render churn.
	if chip.get_meta("aura_tint", Color.TRANSPARENT) != tint:
		var box := ui_box(Color(tint.r * 0.22, tint.g * 0.22, tint.b * 0.22, 0.92), tint, 4)
		box.content_margin_left = 1
		box.content_margin_right = 1
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		chip.add_theme_stylebox_override("panel", box)
		chip.set_meta("aura_tint", tint)
	# Show the icon of the ability that caused the effect, the way WoW does —
	# an Ember stun and a Vanguard stun should be distinguishable at a glance.
	# Effects with no illustrated source (diminishing returns, or an older
	# snapshot) fall back to the name, so a chip is never blank.
	var row := chip.get_child(0) as Control
	var art := row.get_child(0) as TextureRect
	var icon: Texture2D = AbilityArt.texture_for(aura.get("source", ""))
	if icon == null: icon = AbilityArt.texture_for(aura.name)
	if icon == null and aura.key == "lockout": icon = AbilityArt.texture_for("Disrupt")
	if icon == null and aura.key == "stun": icon = AbilityArt.texture_for("Stasis")
	art.texture = icon
	art.visible = icon != null
	var label := row.get_child(1) as Label
	label.add_theme_color_override("font_color", Color.WHITE)
	row.custom_minimum_size.x = 28 if icon != null else 112
	label.add_theme_font_size_override("font_size", 12 if icon != null else 10)
	label.text = ("×%d" % int(aura.stacks) if aura.has("stacks") else str(ceili(aura.remaining))) if icon != null else "%s %s" % [aura.name, format_aura_time(aura.remaining)]

# Long effects do not need tenths; the last few seconds do, because that is when
# you are deciding whether to wait it out.
static func format_aura_time(t: float) -> String:
	return "%.0fs" % ceil(t) if t >= 10.0 else "%.1fs" % t

func build_ui() -> void:
	combat_text.setup(self)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard = add_label(ui, "STARFALL", 22)
	scoreboard.position = Vector2(24, 16)
	performance_label = add_label(ui, "", 14)
	performance_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	performance_label.offset_left = -205
	performance_label.offset_right = -16
	performance_label.offset_top = 16
	performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	performance_label.hide()
	player_frame = unit_frame(Vector2(24, 56), BLUE)
	target_frame = unit_frame(Vector2(330, 56), RED)
	focus_frame = unit_frame(Vector2(636, 56), GOLD)
	# Equal widths and mirrored offsets center the pair at every aspect ratio.
	# The middle gap fits player DR; target DR sits outside the target on its right.
	for entry in [[player_frame, -297, 221], [target_frame, 76, 221], [focus_frame, 409, 180]]:
		var frame: VBoxContainer = entry[0]
		frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		frame.offset_left = entry[1]
		frame.offset_right = entry[1] + entry[2]
		frame.offset_top = -285
		frame.offset_bottom = -180
		for index in [1, 2]:
			frame.get_child(index).custom_minimum_size.x = entry[2]
		frame.get_child(1).custom_minimum_size.y = 22 if frame == focus_frame else 32
		if frame == focus_frame:
			frame.get_child(2).custom_minimum_size.y = 18
		for chip in frame.get_child(4).get_children():
			chip.custom_minimum_size.x = 30
	for frame in [player_frame, target_frame]:
		var dr = preload("res://scripts/dr_icons.gd").new()
		dr.name = "DiminishingReturns"
		frame.get_child(1).add_child(dr)
		dr.install(self)
		dr.columns = 2
		dr.position = Vector2(229, 0)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 1)
	party_box.position = Vector2(24, 220)
	ui.add_child(party_box)
	for i in range(3):
		party_buttons.append(roster_row(party_box, select_party.bind(i)))
		install_dr_column(party_buttons[i], false)
	enemy_box = VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 1)
	ui.add_child(enemy_box)
	enemy_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	enemy_box.offset_left = -354
	enemy_box.offset_top = 220
	enemy_box.offset_right = -24
	enemy_box.offset_bottom = 360
	for i in range(3):
		enemy_buttons.append(roster_row(enemy_box, select_enemy.bind(i)))
		install_dr_column(enemy_buttons[i], true)
		enemy_buttons[i].gui_input.connect(on_enemy_frame_input.bind(i))
		enemy_buttons[i].tooltip_text = "Left-click to target · Right-click to set focus"
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
	for title in ["Ember — ranged damage", "Vanguard — melee damage", "Luminary — healer", "Fulcrum — control", "Outlaw — melee / ranged combos", "Null — stealth / ambush"]:
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
	var graphics_row := HBoxContainer.new()
	graphics_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(graphics_row)
	settings_extra.append(graphics_row)
	graphics_choice = OptionButton.new()
	for preset in UserConfig.GRAPHICS_PRESETS:
		graphics_choice.add_item("Graphics: " + preset)
	style_picker(graphics_choice)
	graphics_row.add_child(graphics_choice)
	render_scale_choice = OptionButton.new()
	for scale in UserConfig.RENDER_SCALES:
		render_scale_choice.add_item("3D resolution: %d%%" % roundi(scale * 100))
	style_picker(render_scale_choice)
	graphics_row.add_child(render_scale_choice)
	var pacing_row := HBoxContainer.new()
	pacing_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(pacing_row)
	settings_extra.append(pacing_row)
	frame_limit_choice = OptionButton.new()
	for limit in UserConfig.FRAME_LIMITS:
		frame_limit_choice.add_item("Frame limit: %d FPS" % limit, limit)
	style_picker(frame_limit_choice)
	pacing_row.add_child(frame_limit_choice)
	fps_toggle = CheckButton.new()
	fps_toggle.text = "Show FPS"
	pacing_row.add_child(fps_toggle)
	style_button(add_button(settings_row, "Apply", apply_settings), true)
	add_button(settings_row, "Keybinds", func(): keybind_menu.open())
	add_button(settings_row, "Edit HUD", func(): toggle_edit_mode(true))
	add_button(settings_row, "Back", func(): menu_state = "main"; refresh_lobby())
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
	round_summary = add_label(stack, "", 16)
	round_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	round_summary.hide()
	lobby_text = add_label(stack, "Choose Online to matchmake into a duel or 3v3. Offline is local sparring vs bots.", 16)
	lobby_text.custom_minimum_size.y = 72
	lobby_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_text.add_theme_color_override("font_color", UI_TEXT_DIM)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	stack.add_child(ui_rule())
	start_button = add_button(stack, "Start round / Rematch", host_start)
	start_button.hide()
	offline_rematch_button = add_button(stack, "Play again", host_start)
	style_button(offline_rematch_button, true)
	resume_button = add_button(stack, "Resume", func():
		if phase in ["match", "countdown"]:
			panel.hide())
	requeue_button = add_button(stack, "Requeue", requeue)
	requeue_button.hide()
	match_settings = add_button(stack, "Settings", func(): menu_state = "settings"; refresh_menu())
	exit_button = add_button(stack, "Leave match", func(): leave_session(""))
	quit_button = add_button(stack, "Quit game", func(): save_layout(); get_tree().quit())
	menu_presentation.install(self)
	spectator.install(self)
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
	player_options = preload("res://scripts/player_options.gd").new()
	player_options.install(self)
	keybind_menu = preload("res://scripts/keybind_menu.gd").new()
	ui.add_child(keybind_menu)
	keybind_menu.setup(self)
	build_cc_tracker()
	build_edit_overlay()
	social = preload("res://scripts/session_social.gd").new()
	ui.add_child(social)
	social.setup(self)

func spawn_actor(id: int, peer: int, side: int, choice: String, pos: Vector3) -> void:
	var actor = Fighter.new()
	actor.name = "Fighter%d" % id
	# World players are independent, even if the lobby assigned the same side.
	actor.setup(id, peer, id if world_mode else side, choice, not dedicated)
	actor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(actor)
	actor.training_dummy = world_mode and id in TrainingDummies.IDS
	if actor.training_dummy and not dedicated: TrainingDummies.decorate(actor)
	actor.position = pos
	actor.rotation.y = 0 if side == 0 else PI
	actor.net_position = pos
	actor.net_yaw = actor.rotation.y
	actors[id] = actor
	actor.owner_peer_changed.connect(_on_actor_owner_changed.bind(actor))
	_refresh_peer_actor(peer)
	if hitboxes_enabled: actor.setup_hitboxes()
	if world_mode:
		next_world_actor_id = maxi(next_world_actor_id, id + 1)
	actor.get_global_transform_interpolated()
	actor.reset_physics_interpolation()

func clear_actors() -> void:
	camera_character_fade.reset()
	outlaw_aim_test.reset()
	aimed_combat.reset()
	outlaw_detonation.reset()
	combat_text.clear()
	spectator.reset()
	result_info.clear()
	rematch_deadline = 0
	ability_reasons.clear()
	availability_timer = 0.0
	prediction.reset()
	movement_controls.cancel()
	movement_controls.walking = false
	jump_serial = 0
	for actor in actors.values():
		remove_child(actor)
		actor.queue_free()
	actors.clear()
	actors_by_peer.clear()
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
	if dedicated:
		# Headless rendering still has a frame loop. Bound it without reducing
		# physics frequency or the 20 Hz network snapshot cadence.
		previous_frame_cap = Engine.max_fps
		Engine.max_fps = Engine.physics_ticks_per_second
	mode = mode_choice.get_selected_id()
	var peer := ENetMultiplayerPeer.new()
	var max_peers := 6 if private_lobby else (mode * 2 if dedicated else 5)
	if world_mode:
		max_peers = Config.WORLD_MAX_PLAYERS
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
	recovery.remember_attempt()
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
	menu_presentation.show_error("")
	close_peer()
	current_port = port
	recovery.remember_attempt()
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
	if message.is_empty() and recovery != null: recovery.token = ""
	if previous_frame_cap >= 0:
		Engine.max_fps = previous_frame_cap
		previous_frame_cap = -1
	if keybind_menu != null:
		keybind_menu.close()
	if network:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network = false
	chat_last_sent.clear()
	duels.clear()
	duel_offers.clear()
	pending_offer = -1
	if social != null:
		social.reset()
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
	menu_camera.make_current()
	status = message
	panel.show()
	release_mouse()
	refresh_lobby()
	if not message.is_empty():
		menu_presentation.show_error(message)
	else:
		menu_presentation.show_error("")

func on_connected() -> void:
	status = "Connected — joining session…"
	if intent == "reconnect":
		request_rejoin.rpc_id(1, recovery.token)
		return
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
	var player_limit := Config.WORLD_MAX_PLAYERS if world_mode else mode * 2
	if roster.size() + recovery.reserved_count() >= player_limit:
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
	recovery.issue(peer)
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
	if intent == "reconnect": recovery.token = ""
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
	# Roster broadcasts also reach fighters still playing or reading results.
	# Only a waiting client should enter the lobby while that round continues.
	if in_round and actors.has(local_id) and phase in ["match", "countdown", "results"]:
		refresh_menu()
		return
	phase = "lobby"
	menu_state = "main"
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
	var settings := menu_state == "settings"
	var choosing := phase == "menu" and not settings
	var playing := phase in ["match", "countdown"]
	var results := phase == "results" and not settings
	main_row.visible = choosing and menu_state == "main"
	offline_row.visible = choosing and menu_state == "offline"
	online_row.visible = choosing and menu_state == "online"
	queue_row.visible = choosing and menu_state == "queue"
	host_row.visible = choosing and menu_state == "host"
	join_row.visible = choosing and menu_state == "join"
	settings_row.visible = settings
	for extra in settings_extra:
		extra.visible = settings
	window_mode_choice.visible = settings
	resolution_choice.visible = settings
	resolution_choice.disabled = window_mode_choice.get_selected_id() != UserConfig.WINDOW_WINDOWED
	champion_choice.visible = choosing and menu_state in ["online", "offline", "queue", "host", "join", "abilities"]
	mode_choice.visible = choosing and menu_state in ["queue", "host", "offline"]
	opponent_choice.visible = choosing and menu_state == "offline"
	match_settings.visible = phase != "menu" and not settings
	resume_button.visible = playing and not settings
	resume_button.disabled = not playing
	start_button.visible = network and multiplayer.is_server() and not dedicated and phase in ["lobby", "results"] and not settings
	start_button.text = "Rematch" if results else "Start round"
	offline_rematch_button.visible = results and not network
	# Requeue is an explicit way to leave a public queue. Private players stay
	# together for their automatic rematch instead of being sent to strangers.
	requeue_button.visible = results and network and not multiplayer.is_server() and searching
	requeue_button.text = "Find another match"
	exit_button.visible = phase != "menu" and not settings
	exit_button.text = "Cancel" if phase == "connecting" else ("Leave lobby" if phase == "lobby" else "Return to menu")
	quit_button.visible = choosing and menu_state == "main"
	round_summary.visible = results
	if settings:
		result_text.text = "Settings"
		lobby_text.text = "Display and controls are remembered.\nCombat continues while settings are open." if playing else "Display and controls are remembered.\nArrange your layout with Edit HUD."
	elif results:
		var victory: bool = actors.has(local_id) and actors[local_id].team == winner
		result_text.text = "%s — %s team wins" % ["VICTORY" if victory else "DEFEAT", "Blue" if winner == 0 else "Red"]
		refresh_result_status()
	elif playing:
		result_text.text = "Round in progress"
		lobby_text.text = "Combat continues while this menu is open."
	elif phase == "connecting":
		result_text.text = "Connecting"
	elif phase == "lobby":
		result_text.text = "Waiting for players"
	elif choosing:
		result_text.text = "Choose a champion. Your full kit is ready."
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
			_:
				lobby_text.text = status if not status.is_empty() else "Online plays against people.\nOffline is local sparring against bots."

	if player_options != null: player_options.refresh()
	if recovery != null: recovery.refresh()
	menu_presentation.refresh()

func refresh_result_status() -> void:
	if phase != "results" or menu_state == "settings":
		return
	if not network:
		lobby_text.text = "Play again with the same champion and matchup."
	elif result_info.get("automatic", false):
		var needed := int(result_info.get("needed", 2))
		if roster.size() < needed:
			lobby_text.text = "Waiting for players (%d/%d).\nYou will stay in this lobby for the next round." % [roster.size(), needed]
		else:
			var seconds := maxi(0, ceili((rematch_deadline - Time.get_ticks_msec()) / 1000.0))
			lobby_text.text = "Next round in %ds\nYou are staying with this lobby." % seconds if seconds > 0 else "Starting the next round…"
	elif multiplayer.is_server():
		lobby_text.text = "Start a rematch when everyone is ready."
	else:
		lobby_text.text = "Waiting for the host to start a rematch."

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
	if rebinding >= 0 and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		finish_rebind(event_binding(event))
		return true
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
	if spell.kind == "trinket": return 0.0
	if spell.get("local_only", false): return actor.stunned
	if CC.spell_block(actor) > 0: return maxf(actor.stunned, CC.spell_block(actor))
	if actor.stunned > 0.0:
		return actor.stunned
	if actor.locked > 0.0 and actor.champion not in ["Vanguard","Null"] and spell.kind not in ["shield", "blink", "sprint", "roll", "backflip"]:
		return actor.locked
	return 0.0

func update_cc_tracker() -> void:
	if cc_tracker == null:
		return
	var holder = actors.get(local_id)
	var cc: Dictionary = Auras.crowd_control(holder) if holder != null else {}
	if cc.is_empty() and edit_mode:
		cc = {"key": "preview", "remaining": 3.0, "source": "Bash", "cc": "CC INDICATOR", "color": Color("ff7d92")}
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
# Mouse bindings use a separate device flag; KeyBindings.label renders both.
static func event_binding(event: InputEvent) -> int:
	var code := 0
	if event is InputEventMouseButton:
		code = preload("res://scripts/key_bindings.gd").MOUSE_FLAG | event.button_index
	elif event is InputEventKey:
		code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	else: return 0
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
		# Only reposition rows the player has not moved themselves; a saved
		# position is theirs and resizing should not throw it away.
		if not moved_frames.has(row.name):
			position_default_action_bar(bar)
	keep_action_bars_on_screen.call_deferred()

func position_default_action_bar(bar: int) -> void:
	var row := bar_roots[bar]
	var step := slot_size + 8
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -(slot_size * BAR_SLOTS + 48) / 2
	row.offset_right = (slot_size * BAR_SLOTS + 48) / 2
	row.offset_top = -(25 + slot_size + bar * step)
	row.offset_bottom = -(25 + bar * step)

func keep_action_bars_on_screen() -> void:
	if ui == null or ui.size.x <= 0 or ui.size.y <= 0: return
	var bounds := Rect2(Vector2.ZERO, ui.size)
	for bar in range(bar_roots.size()):
		var row := bar_roots[bar]
		if row == dragging: continue
		# Saved coordinates may come from a larger monitor. Recover each lost
		# row to its own default position; clamping them all piles bars together.
		if not bounds.encloses(row.get_rect()):
			moved_frames.erase(str(row.name))
			position_default_action_bar(bar)

func refresh_binds() -> void:
	for slot in range(cooldown_overlays.size()):
		# An unbound slot shows nothing rather than a stray "0".
		var binding: int = binds[slot] if binds[slot] != 0 else controls.secondary[slot]
		cooldown_overlays[slot].set_key(controls.label(binding) if binding != 0 else "")

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
		config.set_value("hud", "camera_distance", movement_controls.zoom_target)
		config.save_config()

func save_layout() -> void:
	if arm != null:
		config.set_value("hud", "camera_distance", movement_controls.zoom_target)
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
				if binds[empty] == 0 and controls.secondary[empty] == 0:
					var preferred := default_slot_binding(ability)
					var available := true
					for action in controls.rows(self):
						for column in range(2):
							if controls.value(self, action, column) == preferred:
								available = false
					# A new ability may be clicked/rebound; existing player bindings
					# must never be duplicated or stolen during automatic migration.
					if available:
						binds[empty] = preferred
	var saved_actions = config.get_value("controls", "actions", {})
	for added in ["autorun", "walk", "recenter_camera"]:
		if saved_actions is Dictionary and saved_actions.has(added): continue
		var preferred: int = controls.actions[added][0]
		if preferred == 0: continue
		for other in controls.rows(self):
			if other == added: continue
			for col in range(2):
				if controls.value(self, other, col) == preferred: controls.actions[added][0] = 0
	var moved = config.get_value("hud", "moved", [])
	if moved is Array:
		for name in moved:
			moved_frames[str(name)] = true
	apply_slot_size(int(config.get_value("hud", "slot_size", DEFAULT_SLOT_SIZE)))
	if slot_size_field != null:
		slot_size_field.text = str(slot_size)
	var distance = config.get_value("hud", "camera_distance", 0.0)
	if arm != null:
		if (distance is float or distance is int) and is_finite(float(distance)) and distance > 0.0:
			arm.spring_length = float(distance)
		arm.spring_length = clampf(arm.spring_length, movement_controls.ZOOM_MIN, movement_controls.ZOOM_MAX)
	movement_controls.zoom_target = arm.spring_length
	movement_controls.zoom_velocity = 0.0
	var places = config.get_value("hud", "frames", {})
	if places is Dictionary:
		for frame in movable_frames:
			if frame != null and places.has(frame.name):
				if (frame in [player_frame, target_frame, focus_frame, party_box, enemy_box] or (frame is HBoxContainer and frame in bar_roots)) and not moved_frames.has(str(frame.name)):
					continue # Adopt new defaults while preserving explicitly moved frames.
				frame.position = places[frame.name]
				if frame == enemy_box:
					frame.position.x = clampf(frame.position.x, 0, maxf(0, ui.size.x - frame.size.x))
	keep_action_bars_on_screen.call_deferred()
	refresh_binds()

# Preserve class bindings, with the shared trinket on Ctrl+1 in the third bar.
func default_slot_binding(slot: int) -> int:
	if slot == Kits.TRINKET_SLOT: return KEY_1 | KEY_MASK_CTRL
	if slot < BAR_SLOTS: return KEY_1 + slot
	return (KEY_1 + slot - BAR_SLOTS) | KEY_MASK_SHIFT if slot < Kits.KIT_SIZE else 0

func default_bindings() -> void:
	binds.resize(TOTAL_SLOTS)
	assignment.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		binds[i] = default_slot_binding(i)
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
	player_options.apply_sensitivity()
	if slot_size_field != null and slot_size_field.text.strip_edges().is_valid_int():
		apply_slot_size(int(slot_size_field.text))
		slot_size_field.text = str(slot_size)
	config.set_value("hud", "slot_size", slot_size)
	config.set_value("display", "window_mode", window_mode_choice.get_selected_id())
	var options := UserConfig.available_resolutions()
	var index: int = clampi(resolution_choice.selected, 0, options.size() - 1)
	if index >= 0 and index < options.size():
		config.set_value("display", "resolution", options[index])
	config.set_value("graphics", "preset", UserConfig.GRAPHICS_PRESETS[graphics_choice.selected])
	config.set_value("graphics", "frame_limit", frame_limit_choice.get_selected_id())
	config.set_value("graphics", "render_scale", UserConfig.RENDER_SCALES[render_scale_choice.selected])
	config.set_value("graphics", "show_fps", fps_toggle.button_pressed)
	config.save_config()
	save_layout()
	config.apply_graphics(self)
	config.apply_display()
	refresh_menu()

func load_settings() -> void:
	config.load_config()
	player_options.load_preferences()
	graphics_choice.select(UserConfig.GRAPHICS_PRESETS.find(config.graphics_preset()))
	frame_limit_choice.select(UserConfig.FRAME_LIMITS.find(config.frame_limit()))
	render_scale_choice.select(UserConfig.RENDER_SCALES.find(config.render_scale()))
	fps_toggle.button_pressed = bool(config.get_value("graphics", "show_fps", false))
	config.apply_graphics(self)
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
	menu_state = "main"
	next_world_actor_id = 1
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
		spawn_actor(id, peer, entry.team, entry.champion, spawn_position(entry.team, id if world_mode else counts[entry.team]))
		counts[entry.team] += 1
		id += 1
	if world_mode:
		TrainingDummies.spawn(self)
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
	refresh_menu()
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
		camera.make_current()
		if world_mode:
			selected_id = -1
		else:
			cycle_target()
		sync_target_lock()

func locked_target_for(id: int) -> int:
	if phase not in ["match","countdown"] or not actors.has(id): return -1
	if world_mode:
		var opponent: int=duels.get(id,-1)
		return opponent if actors.has(opponent) and not Null.stealthed(actors[opponent]) else -1
	if mode==1:
		for actor in actors.values():
			if actor.actor_id!=id and actor.team!=actors[id].team and not actor.training_dummy and not Null.stealthed(actor): return actor.actor_id
	return -1

func sync_target_lock() -> void:
	var opponent:=locked_target_for(local_id)
	if opponent!=-1:
		selected_id=opponent
		actors[local_id].target_id=opponent

@rpc("authority", "call_remote", "reliable")
func round_started(round_epoch: int, size_per_team: int, states: Array) -> void:
	if world_mode and epoch == round_epoch and actors.has(local_id):
		for data in states:
			if not actors.has(data.id):
				spawn_actor(data.id, data.peer, data.team, data.champion, data.pos)
				actors[data.id].receive(data, true)
		return
	clear_actors()
	menu_state = "main"
	epoch = round_epoch
	last_snapshot = -1
	mode = size_per_team
	winner = -1
	countdown = 0 if world_mode else 3
	elapsed = 0
	phase = "match" if world_mode else "countdown"
	for data in states:
		spawn_actor(data.id, data.peer, data.team, data.champion, data.pos)
		actors[data.id].receive(data, true)
	assign_local()
	result_text.text = "Round in progress — combat continues with this panel open."
	panel.hide()
	refresh_menu()

func on_peer_left(peer: int) -> void:
	if not network or not multiplayer.is_server():
		return
	recovery.reserve(peer)
	roster.erase(peer)
	chat_last_sent.erase(peer)
	if world_mode:
		var departed := actor_for_peer(peer)
		if departed >= 0:
			remove_world_actor(departed)
			world_actor_left.rpc(epoch, departed)
			sync_duels()
		broadcast_lobby()
		return
	if private_lobby and roster.is_empty() and recovery.reserved_count() == 0:
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
	elif phase == "results":
		broadcast_lobby()

func announce_disconnect() -> void:
	if network and multiplayer.is_server() and phase in ["match", "countdown"]:
		combat_event(-1, -1, "Player disconnected — bot took over", GOLD)

func make_snapshot() -> Array:
	var states: Array = []
	for actor in actors.values():
		var state: Dictionary = actor.snapshot()
		state["aim_stamp"] = actor.aim_stamp
		states.append(state)
	return states

func _physics_process(delta: float) -> void:
	# ENet polling and registration continue through SceneMultiplayer. World has
	# no reconnect reservations: an empty roster leaves only its training dummies.
	# The first admitted player resumes simulation on the next physics tick.
	if dedicated and world_mode and network and multiplayer.is_server() and roster.is_empty():
		snapshot_timer = 0.0
		return
	if phase == "connecting":
		connected_seconds += delta
		if not dedicated:
			lobby_text.text = "%s\n%.0fs elapsed · Cancel to stop" % [status, connected_seconds]
		if connected_seconds > 10:
			if intent in ["host", "join"]:
				next_probe()
			else:
				leave_session("Could not reach the server. Try again in a moment.")
	if not dedicated:
		var budget := config.frame_budget(phase, application_focused)
		if Engine.max_fps != budget:
			Engine.max_fps = budget
		tick_camera_save(delta)
		outlaw_aim_test.physics_tick()
	if phase in ["countdown", "match"]:
		if not authoritative() and actors.has(local_id):
			prediction.reconcile(self, actors[local_id])
		if not dedicated:
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
	if hitboxes_enabled and phase in ["match", "countdown"]:
		aimed_combat.tick(self,delta)
		if not dedicated: outlaw_aim_test.fire_tick(delta)
		outlaw_detonation.tick(self)

func gather_input(delta: float) -> void:
	if not actors.has(local_id):
		return
	var actor = actors[local_id]
	var movement: Vector2 = movement_controls.sample(delta)
	var jump_now := queued_jump and movement_controls.active() and phase == "match"
	if jump_now:
		jump_serial += 1
		pending_jump_id = jump_serial
		jump_sent_at = Time.get_ticks_msec()
		pending_jump_revision = actor.motion_revision
	var jump_age := Time.get_ticks_msec() - jump_sent_at
	if jump_age > JUMP_RETRY_MS: pending_jump_id = 0
	actor.walking = movement_controls.walking
	if authoritative():
		apply_input(local_id, movement, local_yaw, jump_now, selected_id)
		if jump_now: actor.jump_buffer = 0.1 if player_options.jump_buffer else 0.0
	else:
		input_seq += 1
		var command := {"seq": input_seq, "move": movement, "yaw": local_yaw, "jump": jump_now, "delta": delta, "walk": movement_controls.walking, "buffer": 0.1 if player_options.jump_buffer else 0.0}
		if phase == "match": prediction.predict(self, actor, command)
		else: apply_input(local_id, Vector2.ZERO, local_yaw, false, selected_id)
		deliver_input(epoch, input_seq, movement, local_yaw, pending_jump_id, selected_id, jump_age, movement_controls.walking, pending_jump_revision, player_options.jump_buffer)
	queued_jump = false

func key(code: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(code) else 0.0

func apply_input(id: int, movement: Vector2, yaw: float, jump: bool, selected: int) -> void:
	if not actors.has(id) or not movement.is_finite() or not is_finite(yaw):
		return
	var actor = actors[id]
	actor.move_input = movement.limit_length()
	if actor.stunned <= 0 and actor.hp > 0 and actor.charge.is_empty() and not Null.busy(actor):
		actor.rotation.y = wrapf(yaw, -PI, PI)
	actor.jump_queued = (actor.jump_queued or jump) and actor.charge.is_empty()
	var opponent:=locked_target_for(id)
	actor.target_id = opponent if opponent!=-1 else (selected if actors.has(selected) and Null.targetable(self,actor,actors[selected]) else -1)
	actor.input_age = 0

func peer_actor(peer: int) -> int:
	# Peer zero is shared by bots; retain the original first-match behavior.
	if peer > 0:
		var id: int = actors_by_peer.get(peer,-1)
		var actor = actors.get(id)
		if is_instance_valid(actor) and actor.owner_peer == peer and actor.actor_id == id:
			return id
		# Also supports actors inserted directly by offline/test fixtures.
		_refresh_peer_actor(peer)
		return actors_by_peer.get(peer,-1)
	for actor in actors.values():
		if actor.owner_peer == peer:
			return actor.actor_id
	return -1

func _refresh_peer_actor(peer: int) -> void:
	if peer <= 0: return
	actors_by_peer.erase(peer)
	for actor in actors.values():
		if actor.owner_peer == peer:
			actors_by_peer[peer] = actor.actor_id
			return

func _on_actor_owner_changed(previous: int, current: int, actor) -> void:
	if actors.get(actor.actor_id) != actor: return
	_refresh_peer_actor(previous)
	_refresh_peer_actor(current)

# Input sequence orders both movement packets and action-time movement samples.
func accept_movement(id: int, seq: int, movement: Vector2, yaw: float, jump_id: int, selected: int, jump_age: int, walking: bool, revision: int, buffer_jump: bool) -> bool:
	if not actors.has(id) or seq < 0 or not movement.is_finite() or not is_finite(yaw): return false
	var actor = actors[id]
	if seq <= actor.last_input_seq: return false
	actor.last_input_seq = seq
	actor.walking = walking
	apply_input(id, movement, yaw, false, selected)
	if jump_id > actor.last_jump_id:
		actor.last_jump_id = jump_id # Ack rejection too: retries must never become a later jump.
		if phase == "match" and jump_age >= 0 and jump_age <= JUMP_RETRY_MS and revision == actor.motion_revision and actor.hp > 0 and actor.stunned <= 0 and actor.identity.root <= 0 and actor.identity.hold <= 0:
			actor.jump_queued = true
			actor.jump_buffer = 0.1 if buffer_jump else 0.0
	return true

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(round_epoch: int, seq: int, movement: Vector2, yaw: float, jump_id: int, selected: int, jump_age: int, walking: bool, revision: int, buffer_jump: bool) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch or phase not in ["match", "countdown"]: return
	accept_movement(peer_actor(multiplayer.get_remote_sender_id()), seq, movement, yaw, jump_id, selected, jump_age, walking, revision, buffer_jump)

func deliver_input(round_epoch: int, seq: int, movement: Vector2, yaw: float, jump_id: int, selected: int, jump_age: int, walking: bool, revision: int, buffer_jump: bool) -> void:
	if latency_ms > 0: await get_tree().create_timer(latency_ms / 1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_input.rpc_id(1, round_epoch, seq, movement, yaw, jump_id, selected, jump_age, walking, revision, buffer_jump)

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
	if not states.is_empty(): aimed_combat.observe(float(states[0].get("aim_stamp",-1)))
	last_snapshot = seq
	packets_received += 1
	for data in states:
		if actors.has(data.id):
			if data.id == local_id and actors[data.id].champion == "Null":
				var null_state: Dictionary = data.get("identity",{})
				if null_state.get("null_action","") == "blindside" and int(null_state.get("null_action_serial",0)) != int(actors[data.id].identity.get("null_action_serial",0)):
					local_yaw = float(data.yaw)
					pivot.rotation.y = local_yaw
			if data.id == local_id and int(data.get("motion_revision", 0)) != actors[data.id].motion_revision:
				pending_jump_id = 0
				queued_jump = false
			actors[data.id].receive(data)
			if data.id == local_id:
				if int(data.get("jump_ack", 0)) >= pending_jump_id: pending_jump_id = 0
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
	Outlaw.Lasso.tick(self, actor)
	# Death resets class identity below, so release an unfinished reservation first.
	if actor.hp <= 0: Outlaw.refund_interrupted_channel(self, actor)
	ClassMechanics.tick(self, actor, delta)
	Null.tick(self, actor, delta)
	actor.action_budget = maxf(0, actor.action_budget - delta)
	actor.input_age += delta
	if actor.hp <= 0:
		actor.jump_queued = false
		actor.jump_buffer = 0
		actor.casting = -1
		actor.velocity = Vector3.ZERO
		return
	for i in range(actor.cooldowns.size()):
		if actor.kit[i].kind == "blink":
			BlinkCharges.tick(actor, i, delta)
		else:
			actor.cooldowns[i] = maxf(0, actor.cooldowns[i] - delta)
	for field in ["gcd", "stunned", "locked", "shield", "sprint"]:
		actor.set(field, maxf(0, actor.get(field) - delta))
	CC.tick(actor, delta)
	if not actor.charge.is_empty():
		VanguardCharge.tick(self, actor, delta)
		actor.last_motion_seq = actor.last_input_seq
		return
	if actor.training_dummy:
		actor.move_input = Vector2.ZERO
		actor.velocity = Vector3.ZERO
		actor.casting = -1
		return
	if actor.owner_peer == 0:
		bot_think(actor, delta)
	elif actor.input_age > 0.3:
		actor.move_input = Vector2.ZERO
	if actor.stunned > 0:
		actor.casting = -1
	var direction := simulate_movement(actor, delta)
	actor.last_motion_seq = actor.last_input_seq
	if Outlaw.mobile_cast(actor):
		Outlaw.tick_channel(self, actor, delta)
		return
	if actor.casting >= 0:
		if Outlaw.Lasso.casting(actor) and Outlaw.Lasso.state(actor).get("air", false) and actor.is_on_floor():
			cancel_own_cast(actor, "Lasso cancelled by landing")
		elif (direction.length() > 0.01 or not actor.is_on_floor()) and not Outlaw.can_cast_moving(actor, actor.kit[actor.casting]):
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
					if actor.kit[slot].kind == "lasso": Outlaw.Lasso.cancel(self,actor)
					feedback(actor, reason)

func simulate_movement(actor, delta: float, grounded_override: Variant = null) -> Vector3:
	actor.presentation_grounded = null
	if actor.hp <= 0:
		actor.velocity = Vector3.ZERO
		actor.jump_queued = false
		actor.jump_buffer = 0
		return Vector3.ZERO
	if not actor.charge.is_empty():
		VanguardCharge.advance(actor, delta)
		return actor.velocity.normalized()
	if Null.motion(self, actor, delta): return Vector3.ZERO
	if Outlaw.Lasso.motion(self, actor, delta): return Vector3.ZERO
	if Outlaw.roll_motion(self, actor, delta):
		return actor.identity.roll_direction
	var grounded: bool = actor.is_on_floor() if grounded_override == null else bool(grounded_override)
	var airborne_protected: bool = CC.airborne_immune(actor)
	if airborne_protected: grounded = false
	var immobilized: bool = not airborne_protected and (actor.stunned > 0 or actor.identity.root > 0 or actor.identity.hold > 0)
	var direction: Vector3 = actor.basis * Vector3(actor.move_input.x, 0, actor.move_input.y)
	if immobilized:
		direction = Vector3.ZERO
	var speed := 6.5 if actor.move_input.y <= 0 else 3.8
	if actor.walking or Outlaw.deadeye_cast(actor): speed *= 0.5
	if actor.sprint > 0 and not Outlaw.deadeye_cast(actor):
		speed *= 1.65
	if actor.identity.get("roll_haste", 0.0) > 0 and not Outlaw.deadeye_cast(actor): speed *= 1.25
	if Outlaw.severe_slowed(actor):
		speed *= .4
	elif actor.identity.slow > 0 and actor.identity.immune <= 0 and not airborne_protected:
		speed *= 0.55
	if Outlaw.starshot_cast(actor): speed *= Outlaw.STARSHOT_MOVE_SCALE
	if actor.identity.get("null_haste",0.0)>0: speed *= 1.5
	# Airborne movement carries world-space takeoff momentum, including when the
	# player releases movement or turns. Collisions and control effects still stop it.
	if grounded or immobilized:
		actor.velocity.x = direction.x * speed
		actor.velocity.z = direction.z * speed
	if immobilized or Outlaw.deadeye_cast(actor):
		actor.jump_queued = false
		actor.jump_buffer = 0
	if (actor.jump_queued or actor.jump_buffer > 0) and grounded and not immobilized:
		actor.velocity.y = 7
		actor.jump_buffer = 0
	actor.jump_queued = false
	actor.jump_buffer = maxf(0.0, actor.jump_buffer - delta)
	if not Outlaw.Lasso.air_gravity(actor,delta):
		actor.velocity.y -= 20 * delta
	actor.move_and_slide()
	Outlaw.Lasso.air_collisions(actor)
	return direction

func has_los(a, b) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a.position + Vector3.UP, b.position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func spell_target(actor, slot: int, requested: int) -> int:
	if aimed_combat.enabled(actor.kit[slot]): return actor.actor_id
	var kind: String = actor.kit[slot].kind
	if kind in Kits.SELF_KINDS:
		return actor.actor_id
	if kind in Kits.ALLY_KINDS:
		if actors.has(requested) and actors[requested].team == actor.team:
			return requested
		return actor.actor_id # Enemy or no target: helpful spells fall back to self.
	var opponent:=locked_target_for(actor.actor_id)
	return opponent if opponent!=-1 else requested

func validate_spell(actor, slot: int, victim_id: int) -> String:
	if not actors.has(victim_id) or actors[victim_id].hp <= 0:
		return "Select a living target"
	var victim = actors[victim_id]
	var spell: Dictionary = actor.kit[slot]
	var friendly: bool = spell.kind in Kits.ALLY_KINDS or spell.kind in Kits.SELF_KINDS or aimed_combat.enabled(spell)
	if spell.kind == "unavailable":
		return "Ability unavailable"
	# A pull is aimed at whoever is selected, ally or enemy — the only ability
	# that does not care which side the target is on. It still needs range,
	# line of sight and facing, because it is an aimed ability either way.
	if spell.kind == "pull":
		if victim == actor:
			return "Select another fighter"
	elif (victim.team == actor.team) != friendly:
		return "Select an ally" if friendly else "Select an enemy"
	if not friendly and not Null.targetable(self,actor,victim): return "Target is concealed"
	var null_reason: String = Null.validate(self,actor,spell,victim)
	if not null_reason.is_empty(): return null_reason
	var identity_reason: String = ClassMechanics.validate(self, actor, spell, victim)
	if not identity_reason.is_empty():
		return identity_reason
	if not friendly and victim.team != actor.team and not may_harm(actor, victim):
		return "Challenge them to a duel first"
	if victim == actor:
		return ""
	if actor.position.distance_to(victim.position) > float(spell.range):
		return "Out of range"
	# Trickshot was already checked against both physical ricochet segments.
	if spell.kind == "trickshot": return ""
	if spell.kind not in ["inward", "outward"] and not has_los(actor, victim):
		return "Target is out of line of sight"
	if not friendly and (-actor.basis.z).dot((victim.position - actor.position).normalized()) < 0:
		return "Face your target"
	return ""

# Translates a hotbar position into the ability sitting in it. Everything below
# this point — cooldowns, validation, the server — still speaks in kit indices.
func kit_slot(bar_slot: int) -> int:
	if bar_slot < 0 or bar_slot >= assignment.size():
		return -1
	var ability: int = assignment[bar_slot]
	var kit: Array = actors[local_id].kit if actors.has(local_id) else Kits.get_kit(Kits.NAMES[champion_choice.selected])
	return ability if ability >= 0 and ability < kit.size() and kit[ability].kind != "unavailable" else -1

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
	if actors[local_id].kit[ability].kind == "defense_detonation":
		outlaw_aim_test.toggle()
		return # A hotbar utility, never a combat command or targeting action.
	if aimed_combat.enabled(actors[local_id].kit[ability]):
		aimed_combat.local_slot = ability
		return
	# Sample intent now: a turn/release and cast may arrive between physics ticks.
	var movement: Vector2 = movement_controls.sample(0)
	var actor = actors[local_id]
	actor.walking = movement_controls.walking
	apply_input(local_id, movement, local_yaw, false, selected_id)
	if authoritative():
		try_spell(local_id, ability, selected_id, pivot.rotation.y)
	else:
		input_seq += 1
		action_seq += 1
		deliver_action(epoch, action_seq, ability, selected_id, input_seq, movement, local_yaw, movement_controls.walking, pivot.rotation.y)

func deliver_action(round_epoch: int, seq: int, slot: int, selected: int, move_seq: int = -1, movement: Vector2 = Vector2.ZERO, yaw: float = 0.0, walking: bool = false, camera_yaw: float = 0.0) -> void:
	if latency_ms > 0:
		await get_tree().create_timer(latency_ms / 1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_action.rpc_id(1, round_epoch, seq, slot, selected, move_seq, movement, yaw, walking, camera_yaw)

# The action carries intent, never position or velocity. Late actions validate
# with their own facing while preserving any newer movement already received.
func apply_action_intent(id: int, slot: int, selected: int, move_seq: int, movement: Vector2, yaw: float, walking: bool, camera_yaw: Variant = null) -> void:
	if not actors.has(id) or not movement.is_finite() or not is_finite(yaw): return
	var actor = actors[id]
	var newer_motion: bool = move_seq <= actor.last_input_seq
	var previous_yaw: float = actor.rotation.y
	var previous_move: Vector2 = actor.move_input
	var previous_walk: bool = actor.walking
	var previous_target: int = actor.target_id
	var previous_age: float = actor.input_age
	var previous_revision: int = actor.motion_revision
	if newer_motion:
		apply_input(id, movement, yaw, false, selected)
		actor.walking = walking
	else:
		accept_movement(id, move_seq, movement, yaw, 0, selected, 0, walking, actor.motion_revision, false)
	try_spell(id, slot, selected, camera_yaw)
	if newer_motion:
		if actor.motion_revision == previous_revision:
			actor.rotation.y = previous_yaw
		actor.move_input = previous_move
		actor.walking = previous_walk
		actor.target_id = previous_target
		actor.input_age = previous_age

@rpc("any_peer", "call_remote", "reliable", 1)
func submit_action(round_epoch: int, seq: int, slot: int, selected: int, move_seq: int, movement: Vector2, yaw: float, walking: bool, camera_yaw: float) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch or phase != "match": return
	var id := peer_actor(multiplayer.get_remote_sender_id())
	if not actors.has(id) or not movement.is_finite() or not is_finite(yaw) or not is_finite(camera_yaw) or seq <= actors[id].last_action_seq: return
	var actor = actors[id]
	actor.last_action_seq = seq
	if actor.action_budget > 0: return
	actor.action_budget = 0.05
	if slot == -1:
		cancel_own_cast(actor, "")
		return
	if move_seq < 0: return
	apply_action_intent(id, slot, selected, move_seq, movement, yaw, walking, camera_yaw)

func deliver_aimed_action(round_epoch: int, seq: int, slot: int, direction: Vector3, stamp: float, revision: int) -> void:
	if latency_ms > 0: await get_tree().create_timer(latency_ms/1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_aimed_action.rpc_id(1,round_epoch,seq,slot,direction,stamp,revision)

@rpc("any_peer", "call_remote", "reliable", 1)
func submit_aimed_action(round_epoch: int, seq: int, slot: int, direction: Vector3, stamp: float, revision: int) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch or not hitboxes_enabled: return
	var peer := multiplayer.get_remote_sender_id()
	aimed_combat.enqueue(self,peer_actor(peer),peer,seq,slot,direction,stamp,revision)

@rpc("authority", "call_remote", "reliable")
func report_aimed_shot(round_epoch: int, result: Dictionary) -> void:
	if round_epoch != epoch: return
	if result.get("source",-1) == local_id and result.get("damage",0) > 0 and is_instance_valid(aimed_combat.reticle):
		aimed_combat.reticle.confirm_hit()
	aimed_shot_resolved.emit(result)

func deliver_aim_mode(round_epoch: int, serial: int, on: bool) -> void:
	if latency_ms > 0: await get_tree().create_timer(latency_ms/1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_aim_mode.rpc_id(1,round_epoch,serial,on)

@rpc("any_peer", "call_remote", "reliable", 1)
func submit_aim_mode(round_epoch: int, serial: int, on: bool) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch: return
	var peer := multiplayer.get_remote_sender_id()
	var accepted: bool = aimed_combat.tracking.set_mode(self,peer_actor(peer),peer,serial,on)
	report_aim_mode.rpc_id(peer,round_epoch,serial,on and accepted,aimed_combat.clock)

@rpc("authority", "call_remote", "reliable", 1)
func report_aim_mode(round_epoch: int, serial: int, on: bool, started: float) -> void:
	if round_epoch == epoch and not dedicated: outlaw_aim_test.receive_mode(serial,on,started)

func deliver_detonation_charge(round_epoch: int, serial: int) -> void:
	if latency_ms > 0: await get_tree().create_timer(latency_ms/1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_detonation_charge.rpc_id(1,round_epoch,serial)

@rpc("any_peer", "call_remote", "reliable", 1)
func submit_detonation_charge(round_epoch: int, serial: int) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch: return
	var peer := multiplayer.get_remote_sender_id()
	var accepted: bool = aimed_combat.tracking.begin_charge(self,peer_actor(peer),peer,serial)
	report_detonation_charge.rpc_id(peer,round_epoch,serial,accepted)

@rpc("authority", "call_remote", "reliable", 1)
func report_detonation_charge(round_epoch: int, serial: int, accepted: bool) -> void:
	if round_epoch == epoch and not dedicated: outlaw_aim_test.receive_charge(serial,accepted)

func deliver_detonation(round_epoch: int, seq: int, burst_id: int, index: int, origin: Vector3, direction: Vector3, stamp: float, revision: int) -> void:
	if latency_ms > 0: await get_tree().create_timer(latency_ms/1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		submit_detonation.rpc_id(1,round_epoch,seq,burst_id,index,origin,direction,stamp,revision)

@rpc("any_peer", "call_remote", "reliable", 1)
func submit_detonation(round_epoch: int, seq: int, burst_id: int, index: int, origin: Vector3, direction: Vector3, stamp: float, revision: int) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch: return
	var peer := multiplayer.get_remote_sender_id()
	outlaw_detonation.enqueue(self,peer_actor(peer),peer,seq,burst_id,index,origin,direction,stamp,revision)

@rpc("any_peer", "call_remote", "reliable", 1)
func cancel_detonation(round_epoch: int, burst_id: int) -> void:
	if not network or not multiplayer.is_server() or round_epoch != epoch: return
	var peer := multiplayer.get_remote_sender_id()
	outlaw_detonation.cancel(self,peer_actor(peer),peer,burst_id)

func deliver_detonation_cancel(round_epoch: int, burst_id: int) -> void:
	# Match the shot transport delay so cancellation cannot overtake its start.
	if latency_ms > 0: await get_tree().create_timer(latency_ms/1000.0).timeout
	if network and not multiplayer.is_server() and epoch == round_epoch:
		cancel_detonation.rpc_id(1,round_epoch,burst_id)

@rpc("authority", "call_remote", "reliable")
func report_detonation_shot(round_epoch: int, result: Dictionary) -> void:
	if round_epoch != epoch: return
	var predicted := false
	if not dedicated and result.source == local_id: predicted = outlaw_aim_test.receive_shot(result)
	if result.get("fired",false):
		if not predicted: show_outlaw_effect(round_epoch,result.source,result.victim,result.from,result.position,"detonation")
		aimed_shot_resolved.emit(result)

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
	if spell.kind == "lasso": Outlaw.Lasso.cancel(self,actor)
	if not spell.off:
		actor.gcd = 0.0
	if not message.is_empty():
		feedback(actor, message)

# Shared by authoritative casting and advisory UI. This never spends resources,
# starts cooldowns, or mutates combat; clients still submit every action normally.
func ability_block_reason(actor, slot: int, requested: int) -> String:
	if phase != "match":
		return "Round has not started" if phase == "countdown" else "Round is over"
	if actor.kit[slot].kind == "defense_detonation": return outlaw_aim_test.block_reason(actor)
	if actor.hp <= 0:
		return "You are defeated"
	if actor.kit[slot].kind == "trinket":
		if actor.cooldowns[slot] > 0: return "Ability is not ready"
		return "" if CC.remaining(actor,"stun") > 0 else "Requires a stun"
	if actor.stunned > 0:
		return "Controlled"
	if CC.spell_block(actor) > 0:
		return "Disarmed" if actor.cc_effects.has("disarm") else "Silenced"
	var spell: Dictionary = actor.kit[slot]
	# Blink resolves independently without replacing the active cast or its timer.
	if actor.casting >= 0 and not (actor.champion == "Ember" and spell.kind == "blink"):
		return "Already casting"
	if not actor.charge.is_empty():
		return "Charging"
	if actor.identity.get("roll_left", 0.0) > 0: return "Rolling"
	if Outlaw.Lasso.busy(actor): return "Completing Lasso"
	if Null.busy(actor): return "Completing Vantage Point"
	var instant_collapse: bool = spell.kind == "collapse" and actor.identity.instant_collapse > 0
	var own_unavailable: bool = actor.identity.blink_charges <= 0 if spell.kind == "blink" else actor.cooldowns[slot] > 0
	if own_unavailable or (actor.gcd > 0 and not (spell.off or instant_collapse)):
		return "Ability is not ready"
	if actor.locked > 0 and actor.champion not in ["Vanguard", "Null"] and spell.kind not in ["shield", "blink", "sprint", "roll", "backflip"]:
		return "Spell school locked out"
	if actor.identity.root > 0 and spell.kind in ["blink", "charge", "cinder", "pilgrim", "intercede", "swap", "roll", "backflip"]:
		return "Rooted"
	var reason := validate_spell(actor, slot, spell_target(actor, slot, requested))
	if not reason.is_empty():
		return reason
	var instant_graviton: bool = spell.kind == "graviton" and actor.identity.instant_graviton > 0
	var instant_severe: bool = spell.kind == "severe" and actor.identity.instant_severe > 0
	if float(spell.cast) > 0 and not instant_graviton and not instant_collapse and not instant_severe and not Outlaw.can_cast_moving(actor, spell):
		if actor.move_input.length() > 0.01 or not actor.is_on_floor():
			return "Stand still to cast"
	return ""

func try_spell(id: int, slot: int, requested: int, camera_yaw: Variant = null) -> bool:
	if camera_yaw != null and (not (camera_yaw is float or camera_yaw is int) or not is_finite(float(camera_yaw))):
		return false
	if not authoritative() or phase != "match" or not actors.has(id) or slot < 0 or slot >= actors[id].kit.size():
		return false
	var actor = actors[id]
	if actor.kit[slot].get("local_only", false): return false
	if aimed_combat.enabled(actor.kit[slot]): return false # Requires validated aim, never a selected-target fallback.
	if actor.hp <= 0 or (actor.stunned > 0 and actor.kit[slot].kind != "trinket"):
		return false
	# Chronoshift is a two-press interaction: its key arms the choice, then the
	# normal keybind of a cooldown selects it. A ready ability instead cancels
	# selection and proceeds as its normal cast, so it never eats an input.
	if Null.choosing_chronoshift(actor):
		if actor.cooldowns[slot] > 0.0:
			var chronoshift_reason := Null.select_chronoshift(self, actor, slot)
			if chronoshift_reason.is_empty(): return true
			feedback(actor, chronoshift_reason)
			return false
		actor.identity.chronoshift_select = false
	var reason := ability_block_reason(actor, slot, requested)
	if not reason.is_empty():
		feedback(actor, reason)
		return false
	var spell: Dictionary = actor.kit[slot]
	if spell.kind == "trinket":
		CC.clear(actor, ["stun"])
		actor.identity.lasso_knockdown = {}
		actor.cooldowns[slot] = spell.cd
		combat_event(actor.actor_id, actor.actor_id, "STUN BROKEN", Color("97edb1"))
		return true
	var victim_id := spell_target(actor, slot, requested)
	if spell.kind == "charge":
		var victim = actors[victim_id]
		var route: PackedVector3Array = VanguardCharge.route_to(self, actor, victim.position)
		if route.is_empty():
			feedback(actor, "No safe route to target")
			return false
		Null.begin_ability(self,actor,spell,victim)
		actor.cooldowns[slot] = spell.cd
		actor.identity.hold = 0.0
		VanguardCharge.start(self, actor, victim, route, spell.power)
		return true
	Null.begin_ability(self,actor,spell,actors.get(victim_id))
	var instant_collapse: bool = spell.kind == "collapse" and actor.identity.instant_collapse > 0
	var instant_graviton: bool = spell.kind == "graviton" and actor.identity.instant_graviton > 0
	var instant_severe: bool = spell.kind == "severe" and actor.identity.instant_severe > 0
	if float(spell.cast) > 0 and not instant_graviton and not instant_collapse and not instant_severe:
		actor.casting = slot
		actor.cast_left = spell.cast
		actor.cast_target = victim_id
		Outlaw.begin_channel(self, actor, spell, victim_id)
	else:
		resolve_spell(actor, slot, actors[victim_id], camera_yaw)
	if not (spell.off or instant_collapse):
		actor.gcd = GCD_DURATION
	return true

func resolve_spell(actor, slot: int, victim, camera_yaw: Variant = null) -> void:
	var spell: Dictionary = actor.kit[slot]
	if spell.kind == "blink":
		if not BlinkCharges.spend(actor, slot): return
	else:
		actor.cooldowns[slot] = spell.cd
	if spell.kind not in Kits.SELF_KINDS and spell.kind not in Kits.ALLY_KINDS:
		actor.identity.hold = 0.0
	if Null.resolve(self,actor,spell,victim) or Outlaw.resolve(self, actor, spell, victim, camera_yaw) or ClassMechanics.resolve(self, actor, spell, victim):
		return
	match spell.kind:
		"damage":
			damage(actor, victim, spell.power)
		"heal", "self_heal":
			if spell.kind == "self_heal" and actor.champion != "Luminary":
				victim.identity.dots.clear()
				victim.identity.entropy_dots.clear()
				victim.identity.severe_bleeds.clear()
			# Mend always restores its listed amount. Match-only dampening still
			# prevents healer stalemates; persistent worlds never inherit it.
			var dampening := 0.0 if world_mode or spell.kind == "self_heal" else clampf((elapsed - 60) / 180.0, 0, 0.7)
			var healing_scale: float = Fighter.HEALTH_SCALE * (.8 if spell.kind == "self_heal" else 1.0)
			var amount := minf(victim.MAX_HEALTH - victim.hp, spell.power * healing_scale * (1.0 - dampening))
			victim.hp = minf(victim.MAX_HEALTH, victim.hp + amount)
			combat_event(actor.actor_id, victim.actor_id, "+%d" % ceili(amount), Color("97edb1"))
		"interrupt":
			if kick_immune(victim):
				combat_event(actor.actor_id, victim.actor_id, "IMMUNE", GOLD)
			elif victim.casting >= 0:
				victim.casting = -1
				victim.locked = spell.power
				victim.lock_from = spell.name
				combat_event(actor.actor_id, victim.actor_id, "INTERRUPTED", GOLD)
			else:
				feedback(actor, "Interrupt missed — target was not casting")
			Null.grant_essence(actor, spell, slot)
		"control":
			var duration := CC.apply(victim, "stun", spell.power, spell.name)
			combat_event(actor.actor_id, victim.actor_id, "STUN %.1fs" % duration if duration > 0 else "IMMUNE", GOLD)
		"shield", "ally_shield":
			victim.shield = spell.power
			victim.shield_from = spell.name
			combat_event(actor.actor_id, victim.actor_id, "WARD", BLUE)
		"dispel":
			CC.clear(victim, ["stun", "incapacitate", "disorient"])
			victim.stunned = 0
			victim.stun_from = ""
			combat_event(actor.actor_id, victim.actor_id, "DISPELLED", Color("97edb1"))
		"blink":
			move_ability(actor, BlinkCharges.direction(actor, camera_yaw) * float(spell.power))
			combat_event(actor.actor_id, actor.actor_id, "BLINK", BLUE)
		"charge":
			var route: PackedVector3Array = VanguardCharge.route_to(self, actor, victim.position)
			if not route.is_empty():
				VanguardCharge.start(self, actor, victim, route, spell.power)
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
	if actor.training_dummy or CC.airborne_immune(actor): return
	# Sweep the character capsule: mobility cannot cross pillars or walls.
	if actor.identity.hold <= 0:
		actor.move_and_collide(motion)
		actor.motion_revision += 1
		actor.reset_physics_interpolation()

# In the world, damage only lands between two people who agreed to fight.
func may_harm(source, victim) -> bool:
	if not world_mode:
		return true
	if duels.has(source.actor_id): return duels[source.actor_id]==victim.actor_id
	if victim.training_dummy: return not source.training_dummy
	return false

func damage(source, victim, amount: float, periodic: bool = false) -> void:
	if not may_harm(source, victim):
		feedback(source, "Challenge them to a duel first")
		return
	if victim.hp <= 0:
		return
	if not periodic: Null.direct_hit(self,source,victim)
	Null.break_stealth(self,victim)
	amount = ClassMechanics.before_damage(self, source, victim, amount)
	# Ability powers remain in their authored units; every health hit scales once.
	amount *= Fighter.DAMAGE_SCALE
	var reduction := ClassMechanics.damage_multiplier(source, victim)
	var actual := amount * reduction if victim.training_dummy else minf(victim.hp, amount * reduction)
	if victim.identity.last > 0 and actual >= victim.hp:
		actual = maxf(0, victim.hp - 1)
		victim.identity.last = 0.0
		combat_event(source.actor_id, victim.actor_id, "LAST LIGHT", GOLD)
	var controlled_before: bool = victim.cc_effects.has("incapacitate") or victim.cc_effects.has("disorient")
	CC.on_damage(victim, actual)
	if controlled_before and not victim.cc_effects.has("incapacitate") and not victim.cc_effects.has("disorient"):
		combat_event(source.actor_id, victim.actor_id, "CC BROKEN", GOLD)
	if reduction < 1.0 and actual > 0:
		combat_event(source.actor_id, victim.actor_id, "REDUCED", Color("91bbef"))
	victim.hp = maxf(1 if victim.training_dummy else 0, victim.hp - actual)
	combat_event(source.actor_id, victim.actor_id, "−%d" % ceili(actual), RED)
	if victim.hp == 0:
		victim.casting = -1
		Outlaw.refund_interrupted_channel(self, victim)
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
	if not world_mode or not actors.has(from_id) or not actors.has(target_id) or from_id == target_id:
		return
	if actors[from_id].hp <= 0 or actors[target_id].hp <= 0 or actors[target_id].owner_peer == 0:
		return
	if duels.has(from_id) or duels.has(target_id) or duel_offers.has(target_id) or from_id in duel_offers.values():
		return
	duel_offers[target_id] = from_id
	sync_duels()
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
	if not actors.has(from_id) or not actors.has(target_id) or duels.has(from_id) or duels.has(target_id):
		sync_duels()
		return
	duels[from_id] = target_id
	duels[target_id] = from_id
	clear_duel_offers(from_id)
	clear_duel_offers(target_id)
	sync_duels()
	# Both start clean, so a duel is never decided by who was already hurt.
	for id in [from_id, target_id]:
		actors[id].target_id=duels[id]
		actors[id].hp = actors[id].MAX_HEALTH
		actors[id].reset_identity()
		actors[id].cooldowns.fill(0.0)
		actors[id].gcd = 0.0
		actors[id].casting = -1
		actors[id].cast_left = 0.0
		actors[id].cast_target = -1
		actors[id].stunned = 0
		actors[id].locked = 0
		actors[id].shield = 0.0
		actors[id].sprint = 0.0
		actors[id].dr_count = 0
		actors[id].dr_timer = 0
	combat_event(from_id, target_id, "DUEL", GOLD)

func end_duel(loser_id: int, winner_id: int) -> void:
	duels.erase(loser_id)
	duels.erase(winner_id)
	sync_duels()
	for id in [loser_id, winner_id]:
		if actors.has(id):
			Outlaw.refund_interrupted_channel(self, actors[id])
			actors[id].reset_identity()
	combat_event(winner_id, loser_id, "DUEL WON", GOLD)
	# Losing a duel is not death: back up shortly, at full health.
	respawn_timers[loser_id] = 3.0

@rpc("authority", "call_remote", "reliable")
func duel_invited(from_id: int, champion: String) -> void:
	pending_offer = from_id
	if social != null:
		social.append_message("%s challenges you to a duel — use Accept or press %s" % [champion, control_label("accept_duel")])

# Spawns any roster member who does not yet have a body, without disturbing
# anyone already in the world.
func admit_to_world() -> void:
	var next_id := next_world_actor_id
	for actor in actors.values():
		next_id = maxi(next_id, actor.actor_id + 1)
	for peer in roster:
		if peer_actor(peer) != -1:
			continue
		var entry: Dictionary = roster[peer]
		spawn_actor(next_id, peer, entry.team, entry.champion, spawn_position(entry.team, next_id))
		next_id += 1
	broadcast_round()
	sync_duels()

# Which actor a peer controls, or -1.
func actor_for_peer(peer: int) -> int:
	return peer_actor(peer)

# Brings the defeated back rather than leaving a body in a persistent world.
func tick_world(delta: float) -> void:
	if world_starwalk != null:
		world_starwalk.tick(delta)
	for id in respawn_timers.keys():
		respawn_timers[id] -= delta
		if respawn_timers[id] <= 0.0:
			respawn_timers.erase(id)
			if actors.has(id):
				var actor = actors[id]
				actor.hp = actor.MAX_HEALTH
				actor.reset_identity()
				actor.stunned = 0
				actor.locked = 0
				actor.shield = 0
				actor.position = spawn_position(actor.team, id)
				actor.motion_revision += 1
				actor.reset_physics_interpolation()
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
		var info := {"duration": elapsed, "automatic": dedicated, "delay": rematch_delay, "needed": min_players}
		var states := make_snapshot()
		finish_round(epoch, winner, states, info)
		if network:
			finish_round.rpc(epoch, winner, states, info)

@rpc("authority", "call_remote", "reliable")
func finish_round(round_epoch: int, winning_team: int, states: Array, info: Dictionary = {}) -> void:
	if epoch != round_epoch:
		return
	winner = winning_team
	phase = "results"
	menu_state = "main"
	result_info = info.duplicate()
	rematch_deadline = Time.get_ticks_msec() + int(float(info.get("delay", 0)) * 1000)
	for data in states:
		if actors.has(data.id):
			actors[data.id].receive(data, authoritative())
	for actor in actors.values():
		actor.casting = -1
	panel.show()
	release_mouse()
	var survivors := [0, 0]
	for actor in actors.values():
		if actor.hp > 0:
			survivors[actor.team] += 1
	var seconds := int(info.get("duration", elapsed))
	round_summary.text = "%dv%d  ·  %02d:%02d\nSurvivors — Blue %d/%d  ·  Red %d/%d" % [mode, mode, seconds / 60, seconds % 60, survivors[0], mode, survivors[1], mode]
	refresh_menu()
	if dedicated and authoritative():
		print("DEDICATED ROUND END winner=team%d elapsed=%.1fs" % [winner, elapsed])
		get_tree().create_timer(rematch_delay).timeout.connect(_dedicated_rematch.bind(epoch))

func _dedicated_rematch(finished_epoch: int = -1) -> void:
	if not dedicated or not authoritative() or phase != "results" or (finished_epoch >= 0 and epoch != finished_epoch):
		return
	if roster.size() >= min_players:
		print("DEDICATED REMATCH epoch=%d humans=%d/%d" % [epoch + 1, roster.size(), mode * 2])
		begin_round()
	else:
		phase = "lobby"
		if private_lobby and roster.is_empty():
			claimed = false
			lobby_code = ""
		status = "Waiting for %d players (%d connected)…" % [min_players, roster.size()]
		broadcast_lobby()
		print("DEDICATED WAITING humans=%d/%d" % [roster.size(), min_players])

func bot_targets(actor, level: int) -> Array:
	var foe = null
	var ally = null
	var enemy_key := INF
	var ally_health := INF
	var enemy_tie := false
	var ally_tie := false
	for other in actors.values():
		if other.hp <= 0: continue
		if other.team == actor.team:
			if other.hp < ally_health:
				ally = other; ally_health = other.hp; ally_tie = false
			elif other.hp == ally_health: ally_tie = true
		elif Null.targetable(self,actor,other):
			var priority: float = other.hp if level == 2 else actor.position.distance_squared_to(other.position)
			if priority < enemy_key:
				foe = other; enemy_key = priority; enemy_tie = false
			elif priority == enemy_key: enemy_tie = true
	# Godot's sort is not stable. On equal best keys, preserve the exact old
	# sorting sequence (including hard mode's distance-then-health ordering).
	# The usual unique minimum needs no sorting or candidate arrays.
	if foe != null and enemy_tie:
		var enemies: Array = []
		for other in actors.values():
			if other.hp > 0 and other.team != actor.team and Null.targetable(self,actor,other): enemies.append(other)
		enemies.sort_custom(func(a, b): return actor.position.distance_squared_to(a.position) < actor.position.distance_squared_to(b.position))
		if level == 2: enemies.sort_custom(func(a, b): return a.hp < b.hp)
		foe = enemies[0]
	if foe != null and ally_tie:
		var friends: Array = []
		for other in actors.values():
			if other.hp > 0 and other.team == actor.team: friends.append(other)
		friends.sort_custom(func(a, b): return a.hp < b.hp)
		ally = friends[0]
	return [foe,ally]

func bot_think(actor, delta: float) -> void:
	actor.move_input = Vector2.ZERO
	if not network and player_options.passive and actors.has(local_id) and actor.team != actors[local_id].team:
		actor.casting = -1
		return
	var level: int = player_options.difficulty if not network else 1
	actor.ai_timer -= delta
	actor.path_timer -= delta
	if actor.stunned > 0:
		return
	var targets := bot_targets(actor,level)
	var foe = targets[0]
	var ally = targets[1]
	if foe == null:
		return
	var destination = ally if actor.champion == "Luminary" and ally.hp < ally.MAX_HEALTH * .76 else foe
	actor.target_id = destination.actor_id
	var offset: Vector3 = destination.position - actor.position
	offset.y = 0
	if offset.length() > 0.1:
		actor.look_at(actor.position + offset, Vector3.UP)
	var visible := has_los(actor, destination)
	var desired_range: float = 2.5 if actor.champion == "Outlaw" else float(actor.kit[0].range) * 0.85
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
	elif actor.casting < 0 and actor.champion not in ["Vanguard", "Outlaw", "Null"] and destination == foe and offset.length() < 7:
		# Kite toward a clear cell, instead of backing into a pillar.
		var retreat: Vector3 = actor.position - offset.normalized() * 3
		var cell: Vector2i = nav.nearest(retreat)
		var direction: Vector3 = Vector3(cell.x, actor.position.y, cell.y) - actor.position
		if direction.length() > 0.5:
			var local: Vector3 = actor.basis.inverse() * direction.normalized()
			actor.move_input = Vector2(local.x, local.z)
	if actor.ai_timer > 0 or actor.casting >= 0:
		return
	actor.ai_timer = 0.25 if network else player_options.THINK_INTERVALS[level]
	if actor.champion == "Null":
		if not Null.targetable(self,actor,foe): actor.move_input=Vector2.ZERO; return
		for slot in [2,6,1,7,3,0]:
			if slot==2 and foe.casting<0: continue
			if try_spell(actor.actor_id,slot,foe.actor_id): return
		return
	if actor.champion == "Outlaw":
		Outlaw.bot(self, actor, foe)
		return
	if (level > 0 or randf() < 0.35) and ClassMechanics.bot(self, actor, foe, ally):
		return
	if actor.hp < actor.MAX_HEALTH * .45 and try_spell(actor.actor_id, 4, actor.actor_id):
		return
	if actor.champion == "Luminary":
		if ally.stunned > 0 and try_spell(actor.actor_id, 2, ally.actor_id):
			return
		if ally.hp < ally.MAX_HEALTH * .76:
			if try_spell(actor.actor_id, 1, ally.actor_id):
				return
			if visible and offset.length() <= float(actor.kit[5].range):
				actor.move_input = Vector2.ZERO
				if try_spell(actor.actor_id, 5, ally.actor_id):
					return
	else:
		if actor.champion != "Fulcrum" and level > 0 and foe.casting >= 0 and foe.cast_left < (1.0 if level == 2 else 0.55) and try_spell(actor.actor_id, 2, foe.actor_id):
			return
		if actor.champion == "Vanguard" and offset.length() > 7 and try_spell(actor.actor_id, 6, foe.actor_id):
			return
		if actor.champion == "Ember" and offset.length() < 5 and actor.identity.blink_charges > 0:
			actor.move_input = Vector2.DOWN
			try_spell(actor.actor_id, 6, actor.actor_id)
			return
		if actor.hp < actor.MAX_HEALTH * .55 and not visible:
			actor.move_input = Vector2.ZERO
			if try_spell(actor.actor_id, 5, actor.actor_id):
				return
	if visible and offset.length() <= desired_range:
		actor.move_input = Vector2.ZERO
		if actor.champion != "Fulcrum" and foe.stunned <= 0 and try_spell(actor.actor_id, 3, foe.actor_id):
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
	if dedicated and source != victim and actors.has(source) and actors[source].hitbox_pose != null:
		if actors[source].champion == "Vanguard" and text.begins_with("−"):
			actors[source].hitbox_pose.art.strike()
	show_event(epoch, source, victim, text, color)
	if network:
		show_event.rpc(epoch, source, victim, text, color)

func outlaw_effect(source: int, victim: int, from: Vector3, to: Vector3, tag: String) -> void:
	show_outlaw_effect(epoch, source, victim, from, to, tag)
	if network: show_outlaw_effect.rpc(epoch, source, victim, from, to, tag)

@rpc("authority", "call_remote", "reliable")
func show_outlaw_effect(round_epoch: int, source: int, _victim: int, from: Vector3, to: Vector3, tag: String) -> void:
	if round_epoch != epoch or dedicated or not actors.has(source): return
	var presenter = actors[source].champion_model
	if presenter != null and presenter.outlaw_art != null:
		presenter.outlaw_art.fire(tag)
		if tag in ["gun", "ricochet", "detonation"]: from = presenter.outlaw_art.muzzle_position()
	if outlaw_fx != null and not player_options.reduced_effects: outlaw_fx.shot(from, to, tag)

@rpc("authority", "call_remote", "reliable")
func show_event(round_epoch: int, source: int, victim: int, text: String, color: Color) -> void:
	# combat_event still broadcasts this event to every connected client.
	if dedicated:
		return
	if round_epoch != epoch:
		return
	if not actors.has(victim):
		say(text)
		return
	spectator.record(source, victim, text)
	var actor = actors[victim]
	actor.flash = 0.0 if player_options.reduced_effects else 0.16
	if text == "INTERRUPTED": combat_text.interrupts[victim] = Time.get_ticks_msec() + 1200
	if source == local_id or victim == local_id or (spectator.active and victim == spectator.follow_id()):
		var feedback_color := color
		if text.begins_with("−"):
			feedback_color = Color("ff786b") if victim == local_id else Color("ffe8ad")
		elif text.begins_with("+"):
			feedback_color = Color("8fe8ad")
		combat_text.emit(actor, text, feedback_color)
	if player_options.reduced_effects: return
	if source != victim and actors.has(source):
		if actors[source].champion == "Vanguard" and text.begins_with("−"):
			actors[source].champion_model.present_strike()
			preload("res://scripts/vanguard_strike.gd").spawn(self, actors[source].position, actor.position, actors[source].base_color)
		elif text == "STARFALL" and actors[source].champion == "Fulcrum":
			beam(actor.position + Vector3(0, 12, 0), actor.position, Color("dbbaff"))
		elif actors[source].champion not in ["Outlaw", "Null"]:
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
	update_cc_tracker()
	var champion: String = Kits.NAMES[champion_choice.selected]
	var kit: Array = Kits.get_kit(champion)
	for entry in [[player_frame, "YOU", champion], [target_frame, "TARGET", "Luminary"], [focus_frame, "FOCUS", "Vanguard"]]:
		var frame: VBoxContainer = entry[0]
		frame.visible = true
		frame.get_child(0).hide()
		var bar := frame.get_child(1) as ProgressBar
		bar.value = 100
		(bar.get_child(0) as Label).text = "100%"
		(frame.get_child(2) as ProgressBar).visible = false
		(frame.get_child(3) as Label).text = ""
		var meter = frame.get_child(3).get_node("ResourceMeter")
		meter.show()
		frame.get_child(3).custom_minimum_size.y = 16
		meter.sync({"champion": entry[2], "identity": {"heat": 60, "resolve": 60, "meditation": 75, "stars": [{}, {}], "instant_graviton": 0.0, "instant_collapse": 0.0}}, frame == player_frame)
		for chip in (frame.get_child(4) as HBoxContainer).get_children():
			(chip as PanelContainer).hide()
	party_box.visible = true
	enemy_box.visible = not world_mode
	for i in range(3):
		party_buttons[i].visible = i > 0
		enemy_buttons[i].visible = true
		for row in [party_buttons[i], enemy_buttons[i]]:
			row.text = ""
			row.custom_minimum_size.y = 64
			var health := roster_bar(row)
			health.value = 100
			var thin = health.get_node("ThinResource")
			thin.show()
			thin.fraction = 0.65
			thin.tint = thin.COLORS.get(Kits.NAMES[i], Color.WHITE)
			thin.queue_redraw()
			(health.get_child(0) as Label).text = "100%"
			var details = row.get_node("Details")
			details.cast.hide()
			for chip in details.strip.get_children(): chip.hide()
			if row.has_node("DiminishingReturns"):
				for chip in row.get_node("DiminishingReturns").get_children(): chip.hide()
	for slot in range(ability_buttons.size()):
		var button := ability_buttons[slot]
		button.visible = true
		cooldown_overlays[slot].sync(0.0, 0.0, false)
		cooldown_overlays[slot].set_availability("")
		var ability := kit_slot(slot)
		if ability < 0:
			button.modulate = Color(1, 1, 1, 0.45)
			button.text = ""
			ability_images[slot].visible = false
			continue
		button.modulate = Color.WHITE
		var spell: Dictionary = kit[ability]
		var art := AbilityArt.texture_for(spell.name, champion)
		ability_images[slot].texture = art
		ability_images[slot].visible = art != null
		button.text = "" if art != null else spell.name

func kick_immune(actor) -> bool:
	return Outlaw.unkickable(actor) or CC.airborne_immune(actor)

func cast_bar_color(actor, interrupted: bool, normal: Color) -> Color:
	if interrupted: return Color("854657")
	return UNKICKABLE_CAST_COLOR if kick_immune(actor) else normal

func update_frame(frame: VBoxContainer, id: int, prefix: String) -> void:
	frame.set_meta("actor_id", id)
	frame.visible = actors.has(id)
	if not frame.visible:
		return
	var actor = actors[id]
	var friendly: bool = actors.has(local_id) and actor.team == actors[local_id].team
	if not friendly and Null.stealthed(actor): frame.hide(); return
	frame.get_child(0).hide()
	var health := frame.get_child(1) as ProgressBar
	health.value = actor.hp
	var fill := health.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = hud_health_color(actor.champion)
	# Class colour fills the bar, so the border is the only thing left saying
	# which side someone is on. It has to be bold and it has to be there at full
	# health, which means drawing it over the fill rather than behind it.
	paint_bar_edge(health, GOLD if frame == focus_frame else (BLUE if friendly else ENEMY_EDGE), 1 if frame == focus_frame else 2)
	(health.get_child(0) as Label).text = "%d%%" % ceili(100.0 * actor.hp / actor.MAX_HEALTH)
	if health.has_node("DiminishingReturns"):
		var dr = health.get_node("DiminishingReturns")
		var duel_target: bool = world_mode and duels.get(local_id, -1) == id
		dr.visible = frame == player_frame or duel_target or (mode == 1 and not world_mode and not friendly)
		if dr.visible: dr.sync(actor)
	var cast := frame.get_child(2) as ProgressBar
	var interrupted: bool = actor.hp > 0 and Time.get_ticks_msec() < int(combat_text.interrupts.get(id, 0))
	cast.visible = actor.casting >= 0 or interrupted
	var cast_fill: StyleBoxFlat = cast.get_theme_stylebox("fill")
	var cast_tint := cast_bar_color(actor, interrupted, Color("8b713e"))
	if cast_fill.bg_color != cast_tint: cast_fill.bg_color = cast_tint
	if interrupted:
		cast.value = 100
		(cast.get_child(0) as Label).text = "INTERRUPTED"
	elif actor.casting >= 0:
		var total: float = actor.kit[actor.casting].cast
		cast.value = 100 * (1 - actor.cast_left / maxf(0.01, total))
		(cast.get_child(0) as Label).text = "%s · %.1fs" % [actor.kit[actor.casting].name, actor.cast_left]
	(frame.get_child(3) as Label).text = "DEFEATED" if actor.hp <= 0 else ""
	var state := frame.get_child(3) as Label
	var meter = state.get_node("ResourceMeter")
	meter.visible = actor.hp > 0 and not actor.training_dummy
	state.custom_minimum_size.y = 16 if meter.visible else 18
	if meter.visible: meter.sync(actor, prefix == "YOU")
	var chronoshift = state.get_node_or_null("ChronoshiftStatus")
	if chronoshift != null: chronoshift.sync(actor)
	var strip := frame.get_child(4) as HBoxContainer
	var auras := Auras.active(actor, actors.values(), local_id)
	for i in range(AURA_SLOTS):
		var chip := strip.get_child(i) as PanelContainer
		if i < auras.size() and (frame != focus_frame or i < 5):
			paint_aura(chip, auras[i])
		else:
			chip.hide()
			if chip.has_meta("aura"):
				chip.remove_meta("aura")

# Follow the rendered actor pose, rather than the latest 60 Hz physics pose.
# Mouse look remains event-driven and is not interpolated a second time.
func _process(_delta: float) -> void:
	if dedicated:
		return
	outlaw_aim_test.tick(_delta)
	movement_controls.tick(_delta)
	combat_text.tick()
	var follow_id: int = spectator.follow_id()
	if actors.has(follow_id):
		pivot.global_position = actors[follow_id].get_global_transform_interpolated().origin + Vector3(0, 1.6, 0)
	outlaw_aim_test.apply_camera()
	camera_character_fade.update(actors.get(follow_id) if camera.current else null)
	update_proc_flash()

func proc_ready(actor, spell: Dictionary) -> bool:
	if spell.kind == "severe": return actor.identity.instant_severe > 0
	if spell.kind == "trickshot": return (actor.identity.backflip_combo and Outlaw.backflip_airborne(actor)) or actor.identity.coin_left > 0
	if spell.kind == "defense_detonation": return actor.identity.defense_detonation > 0
	return (spell.kind == "graviton" and actor.identity.instant_graviton > 0) or (spell.kind == "collapse" and actor.identity.instant_collapse > 0)

func update_proc_flash() -> void:
	var actor = actors.get(local_id)
	var pulse := 0.35 if player_options.reduced_effects else (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
	for slot in range(ability_images.size()):
		var ability := kit_slot(slot) if actor != null else -1
		var ready: bool = actor != null and actor.hp > 0 and ability >= 0 and proc_ready(actor, actor.kit[ability])
		ability_images[slot].self_modulate = Color(0.5, 0.4, 0.65).lerp(Color(1.5, 1.3, 0.85), pulse) if ready else Color.WHITE

func update_visuals(delta: float) -> void:
	if dedicated:
		return
	performance_timer -= delta
	performance_label.visible = fps_toggle.button_pressed
	if performance_label.visible and performance_timer <= 0.0:
		performance_timer = 0.5
		performance_label.text = "%d FPS  ·  %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(1, Engine.get_frames_per_second())]
	if social != null:
		social.refresh()
	champion_choice.disabled = network
	mode_choice.disabled = network
	resume_button.disabled = phase not in ["match", "countdown"]
	start_button.visible = network and multiplayer.is_server() and not dedicated and phase in ["lobby", "results"] and menu_state != "settings"
	notice_time -= delta
	if notice_time <= 0:
		notice.text = ""
	if phase == "countdown":
		notice.text = "Arena opens in %d" % ceili(countdown)
	for actor in actors.values():
		actor.visual_tick(delta, camera, actor.actor_id != local_id and not Null.stealthed(actor), cast_bar_color(actor, false, Color("c7a256")))
		if actor.champion == "Null" and actor.champion_model != null and actor.champion_model.null_art != null:
			actor.champion_model.null_art.visibility_for(actor,actors.get(local_id))
		if actors.has(local_id) and not Null.targetable(self,actors[local_id],actor):
			if selected_id==actor.actor_id: selected_id=-1
			if focus_id==actor.actor_id: focus_id=-1
		if actor.nameplate != null: actor.nameplate.visible=not Null.stealthed(actor) and actor.hp>0
	ring.visible = selected_id != local_id and actors.has(selected_id) and actors[selected_id].hp > 0
	if ring.visible:
		ring.position = actors[selected_id].position + Vector3(0, 0.08, 0)
	if edit_mode and not actors.has(local_id):
		# Editing from the menu, with no match running. WoW shows dummy frames
		# for exactly this reason: otherwise there is nothing on screen to drag.
		sync_hud_visibility()
		show_edit_previews()
		scoreboard.hide()
		return
	update_frame(player_frame, local_id, "YOU")
	update_frame(target_frame, selected_id, "TARGET")
	update_frame(focus_frame, focus_id, "FOCUS")
	var connection := "LOCAL" if not network else ("HOST" if multiplayer.is_server() else "%dms RTT" % round_trip_ms)
	scoreboard.text = "STARFALL   /   %dv%d   /   %s     ·     %02d:%02d" % [mode, mode, connection, int(elapsed) / 60, int(elapsed) % 60]
	if world_mode:
		scoreboard.text = "STARFALL   /   WORLD   /   %s" % connection
	if elapsed > 60 and not world_mode:
		scoreboard.text += "  Healing (except Mend) −%d%%" % int(clampf((elapsed - 60) / 180.0, 0, 0.7) * 100)
	var party := party_ids()
	party_box.visible = party.size() > 1
	for i in range(3):
		party_buttons[i].visible = i > 0 and i < party.size()
		if i < party.size():
			var member = actors[party[i]]
			paint_roster_row(party_buttons[i], member, "%s  %s" % [control_label("party_%d" % (i + 1)), member.champion], true)
	var enemies := enemy_ids()
	enemy_box.visible = not world_mode and mode != 1 and not enemies.is_empty()
	for i in range(3):
		enemy_buttons[i].visible = i < enemies.size()
		if i < enemies.size():
			var foe = actors[enemies[i]]
			enemy_buttons[i].visible = not Null.stealthed(foe)
			paint_roster_row(enemy_buttons[i], foe, "%d · %s" % [i + 1, "Dummy" if foe.training_dummy else foe.champion], false)
	for actor in actors.values():
		var hostile: bool = actors.has(local_id) and actor.team != actors[local_id].team
		actor.mark_hostile(hostile)
		if actor.team_marker != null:
			actor.team_marker.sync(hostile, actor.actor_id == local_id, actor.actor_id == selected_id)
		# Your own effects are already on the personal strip and the centre-screen
		# readout; repeating them over your own head is noise.
		var overhead: Array = [] if actor.actor_id == local_id else Auras.active(actor, actors.values(), local_id)
		actor.paint_nameplate_auras(overhead, AbilityArt)
	# Before the bar: it maintains cc_total, which the slots use as the sweep
	# denominator.
	update_cc_tracker()
	ClassMechanics.paint(self)
	availability_timer -= delta
	if actors.has(local_id) and (availability_timer <= 0.0 or delta == 0.0):
		availability_timer = 0.1
		var local_actor = actors[local_id]
		ability_reasons.clear()
		for ability in range(local_actor.kit.size()):
			ability_reasons[ability] = ability_block_reason(local_actor, ability, selected_id)
	for slot in range(TOTAL_SLOTS):
		var button := ability_buttons[slot]
		var ability := kit_slot(slot)
		cooldown_overlays[slot].set_charges(-1)
		cooldown_overlays[slot].set_chronoshift_target(false)
		cooldown_overlays[slot].set_chronoshift_lock(false)
		# Empty slots stay hidden in play and visible while editing, so there is
		# somewhere to drop an ability.
		button.visible = actors.has(local_id) and (ability >= 0 or edit_mode or drag_slot >= 0)
		if not button.visible:
			continue
		if ability < 0:
			button.text = ""
			ability_images[slot].visible = false
			cooldown_overlays[slot].sync(0.0, 0.0, false)
			cooldown_overlays[slot].set_availability("")
			button.modulate = Color(1, 1, 1, 0.45)
			continue
		var actor = actors[local_id]
		var spell: Dictionary = actor.kit[ability]
		var blink_available: bool = spell.kind == "blink" and actor.identity.blink_charges > 0
		if spell.kind == "blink": cooldown_overlays[slot].set_charges(actor.identity.blink_charges)
		if spell.kind == "defense_detonation": cooldown_overlays[slot].set_charges(actor.identity.defense_detonation)
		var art := AbilityArt.texture_for(spell.name, actor.champion)
		ability_images[slot].texture = art
		ability_images[slot].visible = art != null
		ability_images[slot].modulate = Color("b6a4cf") if button.button_pressed else Color.WHITE
		if spell.kind == "defense_detonation" and outlaw_aim_test.enabled: ability_images[slot].modulate = Color("81d5ff")
		# Unillustrated abilities retain the existing text fallback.
		button.text = "" if art != null or actor.cooldowns[ability] > 0.0 else spell.name
		# The ability's own cooldown wins the slot: it is the longer wait and the
		# one worth a number. The global cooldown only shows where nothing else is
		# running, and never on an off-GCD ability.
		var own: float = 0.0 if blink_available else actor.cooldowns[ability]
		var global_cd: float = 0.0 if spell.off or (spell.kind == "collapse" and actor.identity.instant_collapse > 0) else actor.gcd
		# Crowd control is a real reason the slot is unusable, so it sweeps too.
		# Whichever wait is LONGER wins the slot, because that is the honest
		# answer to "when can I press this" — a 16s cooldown outlives a 2s stun,
		# and a 4s lockout outlives a spell that is already off cooldown.
		var held: float = cc_block_remaining(actor, spell)
		var chronoshift_lock: float = float(actor.identity.get("chronoshift_locks", {}).get(ability, 0.0))
		var chronoshift_ready: bool = Null.choosing_chronoshift(actor) and actor.cooldowns[ability] > 0.0 and spell.kind != "chronoshift" and chronoshift_lock <= 0.0
		cooldown_overlays[slot].set_chronoshift_target(chronoshift_ready)
		cooldown_overlays[slot].set_chronoshift_lock(chronoshift_lock > 0.0)
		# A slot you cannot press because you are held reads as unusable, not just
		# as counting down.
		button.modulate = Color(0.55, 0.58, 0.72) if held > 0.0 else (Color("ffe699") if proc_ready(actor, spell) else Color.WHITE)
		if held > own and held > 0.0:
			cooldown_overlays[slot].sync(held, maxf(cc_total, held), false)
		elif own > 0.0:
			cooldown_overlays[slot].sync(own, maxf(spell.cd, own), false)
		elif global_cd > 0.0:
			cooldown_overlays[slot].sync(global_cd, GCD_DURATION, true)
		elif blink_available and actor.cooldowns[ability] > 0:
			cooldown_overlays[slot].sync(actor.cooldowns[ability], spell.cd, false, true)
		else:
			cooldown_overlays[slot].sync(0.0, 0.0, false)
		var reason: String = ability_reasons.get(ability, "")
		cooldown_overlays[slot].set_availability("" if edit_mode or drag_slot >= 0 else reason)
		if not reason.is_empty() and held <= 0 and own <= 0 and global_cd <= 0 and not edit_mode:
			ability_images[slot].modulate = Color("a0a0b5")
		if actor.hp <= 0:
			button.modulate = Color("83919e")
	refresh_result_status()
	sync_hud_visibility()
	if edit_mode: show_edit_previews()
	update_ability_tooltip()

func sync_hud_visibility() -> void:
	spectator.refresh()
	var show_hud := actors.has(local_id) and not panel.visible
	scoreboard.visible = show_hud
	notice.visible = show_hud
	for entry in [[player_frame, local_id], [target_frame, selected_id], [focus_frame, focus_id]]:
		var unit = actors.get(entry[1])
		var concealed: bool = unit != null and actors.has(local_id) and unit.team != actors[local_id].team and Null.stealthed(unit)
		entry[0].visible = ((show_hud and unit != null) or edit_mode) and not concealed
	party_box.visible = (show_hud and party_ids().size() > 1) or edit_mode
	enemy_box.visible = not world_mode and ((show_hud and not enemy_ids().is_empty() and mode != 1) or edit_mode)
	for bar in bar_roots:
		bar.visible = (show_hud and not spectator.active) or edit_mode
	if spectator.active and not edit_mode:
		player_frame.hide()
		cc_tracker.hide()
		ability_tooltip.hide()
	if not show_hud and not edit_mode:
		cc_tracker.hide()
	if not actors.has(local_id) and not menu_camera.current:
		menu_camera.make_current()

# Aura strips live at child index 4 of a unit frame. Party and enemy rows are
# plain buttons with no strip, so they are skipped rather than special-cased.
func chip_in_strip(strip: Control, pointer: Vector2) -> PanelContainer:
	if strip == null or not strip.is_visible_in_tree():
		return null
	for child in strip.get_children():
		var panel := child as PanelContainer
		if panel.visible and panel.has_meta("aura") and panel.get_global_rect().has_point(pointer):
			return panel
	return null

func aura_chip_at(frame: Node, pointer: Vector2) -> PanelContainer:
	if frame is Button and frame.has_node("Details"):
		if frame.has_node("DiminishingReturns"):
			var dr_chip := chip_in_strip(frame.get_node("DiminishingReturns"), pointer)
			if dr_chip != null: return dr_chip
		return chip_in_strip(frame.get_node("Details").strip, pointer)
	if frame == null or not (frame is VBoxContainer) or frame.get_child_count() < 5:
		return null
	if not (frame as Control).is_visible_in_tree():
		return null
	if frame.get_child(1).has_node("DiminishingReturns"):
		var dr_chip := chip_in_strip(frame.get_child(1).get_node("DiminishingReturns"), pointer)
		if dr_chip != null: return dr_chip
	for chip in (frame.get_child(4) as HBoxContainer).get_children():
		var panel := chip as PanelContainer
		if panel.visible and panel.has_meta("aura") and panel.get_global_rect().has_point(pointer):
			return panel
	return null

func paint_roster_row(button: Button, actor, _title: String, friendly: bool) -> void:
	var bar := roster_bar(button)
	if bar == null:
		return
	bar.value = actor.hp
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = hud_health_color(actor.champion)
	paint_bar_edge(bar, BLUE if friendly else ENEMY_EDGE, 2 if actor.actor_id == selected_id else 1)
	(bar.get_child(0) as Label).text = "%d%%" % ceili(actor.hp)
	bar.get_node("ThinResource").sync(actor)
	button.get_node("Details").sync(actor)
	if button.has_node("DiminishingReturns"): button.get_node("DiminishingReturns").sync(actor)


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
	var duel_opponent: int = duels.get(local_id, -1) if world_mode else -1
	for actor in actors.values():
		if actor.actor_id == local_id or actor.hp <= 0 or not Null.targetable(self,actors[local_id],actor):
			continue
		if world_mode:
			# Training dummies are click targets, never Tab targets. During a
			# duel only the opponent participates in keyboard target cycling.
			if actor.training_dummy: continue
			if duels.has(local_id):
				if actor.actor_id != duel_opponent: continue
			elif duels.has(actor.actor_id):
				continue
		elif actor.team == actors[local_id].team:
			continue
		candidates.append(actor.actor_id)
	if not candidates.is_empty():
		var current := candidates.find(selected_id)
		selected_id = candidates[(0 if direction > 0 else candidates.size() - 1) if current < 0 else posmod(current + direction, candidates.size())]

func _input(event: InputEvent) -> void:
	if outlaw_aim_test.input(event):
		get_viewport().set_input_as_handled()
		return
	if movement_controls.input(event):
		get_viewport().set_input_as_handled()
		return
	if player_options != null and player_options.dialog.visible: return
	if social != null and social.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if social != null and social.typing():
		return
	if keybind_menu != null and keybind_menu.visible:
		if keybind_menu.handle(event):
			get_viewport().set_input_as_handled()
		return
	if edit_mode:
		if handle_edit_input(event): get_viewport().set_input_as_handled()
		return
	# World chat controls participate in GUI focus navigation. Handle combat
	# targeting before GUI dispatch so Tab cannot focus chat instead of fighting.
	if world_mode and not panel.visible and phase in ["match", "countdown"] and event is InputEventKey and event.pressed and not event.echo:
		var binding := event_binding(event)
		var direction := 1 if controls.matches("target_next", binding) else (-1 if controls.matches("target_previous", binding) else 0)
		if direction != 0:
			if spectator.active: spectator.cycle(direction)
			else: cycle_target(direction)
			get_viewport().set_input_as_handled()
			return
	if handle_shift_drag(event):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2] and (movement_controls.left or movement_controls.right):
		_unhandled_input(event)
		get_viewport().set_input_as_handled()
		return
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
		if panel.visible and menu_state == "abilities":
			menu_state = menu_presentation.introduction.return_state
			refresh_menu()
		elif panel.visible and menu_state != "main":
			menu_state = "main"
			refresh_lobby()
		elif panel.visible and phase in ["match", "countdown"]:
			panel.hide()
		elif actors.has(local_id) and actors[local_id].casting >= 0:
			if authoritative():
				actors[local_id].casting = -1
			else:
				action_seq += 1
				deliver_action(epoch, action_seq, -1, selected_id)
		elif selected_id != -1 and locked_target_for(local_id)==-1:
			selected_id = -1
		else:
			panel.show()
			refresh_lobby()
			release_mouse()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if social.typing() or panel.visible or keybind_menu.visible or edit_mode or phase not in ["match", "countdown"]:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			movement_controls.scroll_zoom(event.factor)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			movement_controls.scroll_zoom(-event.factor)
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			movement_controls.begin(event)
			get_viewport().set_input_as_handled()
			return
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]: controls.mouse_held[event.button_index] = true
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]):
		var pressed_binding := event_binding(event)
		if movement_controls.active(): movement_controls.action(pressed_binding)
		if spectator.eliminated():
			if controls.matches("target_next", pressed_binding): spectator.cycle(1)
			if controls.matches("target_previous", pressed_binding): spectator.cycle(-1)
			return
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
			if controls.matches("target_arena_%d" % (i + 1), pressed_binding):
				select_enemy(i)
			if controls.matches("focus_arena_%d" % (i + 1), pressed_binding):
				focus_enemy(i)
		if controls.matches("set_focus", pressed_binding):
			focus_id = selected_id
		if controls.matches("target_focus", pressed_binding) and actors.has(focus_id):
			selected_id = focus_id
		if controls.matches_jump(self, pressed_binding):
			queued_jump = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused = true
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_focused = false
		has_capture_origin = false
		movement_controls.cancel()
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
	movement_controls.left = false
	movement_controls.right = false
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
	var opponent:=locked_target_for(local_id)
	if opponent!=-1: return [opponent]
	if actors.has(local_id):
		for actor in actors.values():
			if actor.team != actors[local_id].team and not actor.training_dummy and Null.targetable(self,actors[local_id],actor):
				ids.append(actor.actor_id)
	return ids

func select_enemy(index: int) -> void:
	var ids := enemy_ids()
	if index >= 0 and index < ids.size():
		selected_id = ids[index]

func focus_enemy(index: int) -> void:
	var ids := enemy_ids()
	if index >= 0 and index < ids.size():
		focus_id = ids[index]

func on_enemy_frame_input(event: InputEvent, index: int) -> void:
	if edit_mode or panel.visible or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		focus_enemy(index)
		enemy_buttons[index].accept_event()

func update_ability_tooltip() -> void:
	if panel.visible or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not actors.has(local_id):
		ability_tooltip.hide()
		return
	var pointer := ui.get_global_mouse_position()
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
			var text: String = Kits.description(actor.kit[ability], actor.champion)
			var reason := ability_block_reason(actor, ability, selected_id) if not edit_mode else ""
			ability_tooltip.present_availability(text, reason, pointer, ui.size, actor.kit[ability], actor.champion)
			return
	ability_tooltip.hide()

func reset_all_keybinds() -> void:
	controls.actions = controls.DEFAULTS.duplicate(true)
	controls.secondary.fill(0)
	for slot in range(TOTAL_SLOTS):
		binds[slot] = default_slot_binding(slot)
	refresh_binds()
	save_layout()

func control_label(action: String) -> String:
	for binding in controls.actions[action]:
		if binding != 0:
			return controls.label(binding)
	return "Unbound"

# Session social actions are validated by the authority; clients only request.
func request_duel_action(action: String) -> void:
	if not world_mode:
		return
	if authoritative():
		match action:
			"challenge": offer_duel(local_id, selected_id)
			"accept": confirm_duel(local_id)
			"decline": dismiss_duel(local_id)
	else:
		match action:
			"challenge": challenge_duel.rpc_id(1, selected_id)
			"accept": accept_duel.rpc_id(1)
			"decline": decline_duel.rpc_id(1)

func clear_duel_offers(id: int) -> void:
	for target in duel_offers.keys():
		if target == id or duel_offers[target] == id:
			duel_offers.erase(target)

func dismiss_duel(id: int) -> void:
	if not world_mode or not actors.has(id):
		return
	clear_duel_offers(id)
	sync_duels()

@rpc("any_peer", "call_remote", "reliable")
func decline_duel() -> void:
	if network and multiplayer.is_server():
		dismiss_duel(actor_for_peer(multiplayer.get_remote_sender_id()))

func sync_duels() -> void:
	sync_target_lock()
	pending_offer = duel_offers.get(local_id, -1)
	if network and multiplayer.is_server():
		duel_state.rpc(epoch, duels, duel_offers)

@rpc("authority", "call_remote", "reliable")
func duel_state(round_epoch: int, pairs: Dictionary, offers: Dictionary) -> void:
	if not world_mode or round_epoch != epoch:
		return
	duels = pairs.duplicate()
	duel_offers = offers.duplicate()
	pending_offer = duel_offers.get(local_id, -1)
	sync_target_lock()

func remove_world_actor(id: int) -> void:
	if not actors.has(id):
		return
	var opponent: int = duels.get(id, -1)
	duels.erase(id)
	duels.erase(opponent)
	if actors.has(opponent):
		actors[opponent].reset_identity()
		actors[opponent].casting = -1
	clear_duel_offers(id)
	respawn_timers.erase(id)
	var actor = actors[id]
	if authoritative() and Outlaw.Lasso.busy(actor): Outlaw.Lasso.cancel(self,actor)
	actors.erase(id)
	_refresh_peer_actor(actor.owner_peer)
	remove_child(actor)
	actor.queue_free()
	if selected_id == id: selected_id = -1
	if focus_id == id: focus_id = -1
	if pending_offer == id: pending_offer = -1
	for other in actors.values():
		if other.target_id == id: other.target_id = -1
		if other.cast_target == id: other.casting = -1

@rpc("authority", "call_remote", "reliable")
func world_actor_left(round_epoch: int, id: int) -> void:
	if world_mode and round_epoch == epoch:
		remove_world_actor(id)

func send_chat(message: String) -> void:
	if authoritative():
		relay_chat(multiplayer.get_unique_id(), message)
	elif network:
		request_chat.rpc_id(1, message)

@rpc("any_peer", "call_remote", "reliable", 4)
func request_chat(message: String) -> void:
	if network and multiplayer.is_server():
		relay_chat(multiplayer.get_remote_sender_id(), message)

func relay_chat(peer: int, message: String) -> void:
	var id := actor_for_peer(peer)
	if not actors.has(id) or message.length() > 240 or phase not in ["match", "countdown", "results"]:
		return
	var clean := ""
	for ch in message:
		var code := ch.unicode_at(0)
		if code >= 32 and code != 127 and not (code >= 0x202A and code <= 0x202E) and not (code >= 0x2066 and code <= 0x2069):
			clean += ch
	clean = clean.strip_edges()
	if clean.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(chat_last_sent.get(peer, -1000)) < 750:
		return
	chat_last_sent[peer] = now
	var line := "%s · %s #%d: %s" % ["World" if world_mode else "Match", actors[id].champion, id, clean]
	chat_message(epoch, line, id, clean)
	if network:
		chat_message.rpc(epoch, line, id, clean)

@rpc("authority", "call_remote", "reliable", 4)
func chat_message(round_epoch: int, message: String, speaker_id: int, bubble_text: String) -> void:
	if round_epoch == epoch and social != null:
		social.append_message(message)
		social.show_bubble(speaker_id, bubble_text)


@rpc("authority", "call_remote", "reliable")
func session_ticket(ticket: String) -> void:
	if ticket.length() != 64: return
	recovery.token = ticket
	recovery.endpoint = address.text.strip_edges()
	recovery.port = current_port

@rpc("any_peer", "call_remote", "reliable")
func request_rejoin(ticket: String) -> void:
	if not network or not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	if not recovery.reclaim(peer, ticket):
		rejected.rpc_id(peer, "That character is no longer available to reconnect. Join a new match.")
		return
	session_restored.rpc_id(peer, epoch, mode, make_snapshot(), phase, elapsed, countdown, lobby_code)
	broadcast_lobby()

@rpc("authority", "call_remote", "reliable")
func session_restored(round_epoch: int, size_per_team: int, states: Array, round_phase: String, time: float, start_time: float, code: String) -> void:
	round_started(round_epoch, size_per_team, states)
	phase = round_phase
	elapsed = time
	countdown = start_time
	lobby_code = code
	intent = ""
	input_seq = 0
	action_seq = 0
	refresh_lobby()
