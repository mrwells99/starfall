extends "res://scripts/arena_world.gd"

const Fighter = preload("res://scripts/combatant.gd")
const Kits = preload("res://scripts/kits.gd")
const AbilityArt = preload("res://scripts/ability_art.gd")
const Config = preload("res://scripts/config.gd")
# Seconds of global cooldown an ability triggers. The hotbar sweep needs the
# same number the simulation uses, so it lives here rather than inline.
const GCD_DURATION := 1.5
const CooldownOverlay = preload("res://scripts/cooldown_overlay.gd")
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
var input_timer := 0.0
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
	build_arena()
	build_camera()
	build_ui()
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(func(): leave_session("Host disconnected."))
	multiplayer.peer_disconnected.connect(on_peer_left)
	parse_arguments()

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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func styled_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color("16202c")
	back.set_border_width_all(1)
	back.border_color = Color("657586")
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
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
	return bar

func unit_frame(pos: Vector2, color: Color) -> VBoxContainer:
	var frame := VBoxContainer.new()
	frame.position = pos
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(on_unit_frame_input.bind(frame))
	ui.add_child(frame)
	add_label(frame, "", 18)
	frame.add_child(styled_bar(color, 27))
	frame.add_child(styled_bar(GOLD, 22))
	add_label(frame, "", 14)
	return frame

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
	add_label(party_box, "PARTY · F1–F3 to select")
	for i in range(3):
		party_buttons.append(add_button(party_box, "", select_party.bind(i)))
	enemy_box = VBoxContainer.new()
	ui.add_child(enemy_box)
	enemy_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	enemy_box.offset_left = -244
	enemy_box.offset_top = 220
	enemy_box.offset_right = -24
	enemy_box.offset_bottom = 360
	add_label(enemy_box, "ENEMIES · Tab / click frame")
	for i in range(3):
		enemy_buttons.append(add_button(enemy_box, "", select_enemy.bind(i)))
	var help := add_label(ui, "W/S move · A/D strafe · Q/E turn · Space jump\nRMB steer · LMB orbit · Both run · Wheel zoom\nTab / frames target · F1–F3 allies · F / G focus\n1–7 abilities · Hover for details · Esc menu", 14)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 24
	help.offset_top = -185
	help.offset_right = 400
	help.offset_bottom = -100
	var hotbar := HBoxContainer.new()
	ui.add_child(hotbar)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -340
	hotbar.offset_top = -117
	hotbar.offset_right = 340
	hotbar.offset_bottom = -25
	hotbar.add_theme_constant_override("separation", 6)
	for slot in range(7):
		var button := add_button(hotbar, "", send_action.bind(slot))
		button.custom_minimum_size = Vector2(92, 92)
		button.clip_contents = true
		ability_buttons.append(button)
		ability_images.append(AbilityArt.attach(button))
		var overlay = CooldownOverlay.new()
		button.add_child(overlay)
		overlay.set_key(str(slot + 1))
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
	panel.offset_left = -290
	panel.offset_top = -270
	panel.offset_right = 290
	panel.offset_bottom = 270
	panel.custom_minimum_size = Vector2(580, 520)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	add_label(stack, "R I N G F A L L  /  ARENA", 28)
	result_text = add_label(stack, "Choose a champion. Your full kit is ready.", 18)
	champion_choice = OptionButton.new()
	for title in ["Ember — ranged damage", "Vanguard — melee damage", "Luminary — healer", "Fulcrum — control"]:
		champion_choice.add_item(title)
	stack.add_child(champion_choice)
	mode_choice = OptionButton.new()
	mode_choice.add_item("Duel · 1v1", 1)
	mode_choice.add_item("Team arena · 3v3", 3)
	stack.add_child(mode_choice)
	main_row = HBoxContainer.new()
	stack.add_child(main_row)
	add_button(main_row, "Online", func(): menu_state = "online"; refresh_menu())
	add_button(main_row, "Offline", func(): menu_state = "offline"; refresh_menu())
	offline_row = HBoxContainer.new()
	stack.add_child(offline_row)
	add_button(offline_row, "Local sparring", local_match)
	add_button(offline_row, "Back", func(): menu_state = "main"; refresh_menu())
	online_row = HBoxContainer.new()
	stack.add_child(online_row)
	add_button(online_row, "Online queue", func(): menu_state = "queue"; refresh_menu())
	add_button(online_row, "Host lobby", func(): menu_state = "host"; refresh_menu())
	add_button(online_row, "Join lobby", func(): menu_state = "join"; refresh_menu())
	add_button(online_row, "Back", func(): menu_state = "main"; refresh_menu())
	queue_row = HBoxContainer.new()
	stack.add_child(queue_row)
	add_button(queue_row, "Find match", matchmake)
	add_button(queue_row, "Back", func(): menu_state = "online"; refresh_menu())
	host_row = HBoxContainer.new()
	stack.add_child(host_row)
	add_button(host_row, "Create lobby", host_lobby)
	add_button(host_row, "Back", func(): menu_state = "online"; refresh_menu())
	join_row = HBoxContainer.new()
	stack.add_child(join_row)
	code_field = LineEdit.new()
	code_field.placeholder_text = "Lobby code"
	code_field.max_length = Config.CODE_LENGTH
	code_field.custom_minimum_size.x = 150
	join_row.add_child(code_field)
	add_button(join_row, "Join", func(): join_lobby(code_field.text))
	add_button(join_row, "Back", func(): menu_state = "online"; refresh_menu())
	# Players never see the server address; this stays as a value holder for tests
	# and for the --join= command-line path. It is parented but hidden so the scene
	# owns it — an orphaned Control leaks its font and canvas RIDs at exit.
	address = LineEdit.new()
	address.text = Config.SERVER_ADDRESS
	address.hide()
	stack.add_child(address)
	lobby_text = add_label(stack, "Choose Online to matchmake into a duel or 3v3. Offline is local sparring vs bots.", 16)
	lobby_text.custom_minimum_size.y = 115
	start_button = add_button(stack, "Start round / Rematch", host_start)
	start_button.hide()
	resume_button = add_button(stack, "Resume / Close panel", func():
		if phase in ["match", "countdown"]:
			panel.hide())
	requeue_button = add_button(stack, "Requeue", requeue)
	requeue_button.hide()
	exit_button = add_button(stack, "Return to menu", func(): leave_session("Returned to menu."))
	ability_tooltip = preload("res://scripts/ability_tooltip.gd").new()
	ui.add_child(ability_tooltip)

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
	for actor in actors.values():
		remove_child(actor)
		actor.queue_free()
	actors.clear()
	selected_id = -1
	focus_id = -1

func local_match() -> void:
	if network:
		leave_session("")
	mode = mode_choice.get_selected_id()
	roster = {1: {"champion": Kits.NAMES[champion_choice.selected], "team": 0}}
	begin_round()

func host_session(dedicated_mode: bool = false) -> void:
	leave_session("")
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
		print("DEDICATED READY %s port=%d mode=%d min_players=%d rematch_delay=%.1f private=%s" % [Config.VERSION, current_port, mode, min_players, rematch_delay, private_lobby])
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
	if network:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	network = false
	dedicated = false
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
	var in_menu: bool = phase == "menu"
	if main_row:
		main_row.visible = in_menu and menu_state == "main"
	if offline_row:
		offline_row.visible = in_menu and menu_state == "offline"
	if online_row:
		online_row.visible = in_menu and menu_state == "online"
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

func host_start() -> void:
	if authoritative() and phase in ["lobby", "results"]:
		begin_round()

func begin_round() -> void:
	clear_actors()
	epoch += 1
	elapsed = 0
	countdown = 3
	winner = -1
	phase = "countdown"
	var counts := [0, 0]
	var id := 1
	for peer in roster:
		var entry: Dictionary = roster[peer]
		spawn_actor(id, peer, entry.team, entry.champion, spawn_position(entry.team, counts[entry.team]))
		counts[entry.team] += 1
		id += 1
	for side in range(2):
		while counts[side] < mode:
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
	if network:
		round_started.rpc(epoch, mode, make_snapshot())

func spawn_position(side: int, index: int) -> Vector3:
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
	if phase in ["countdown", "match"]:
		gather_input(delta)
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
	if not panel.visible and actor.hp > 0:
		var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if not right:
			var turn := (key(KEY_Q) - key(KEY_E)) * delta * 2.5
			local_yaw += turn
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				pivot.rotation.y += turn
		movement = Vector2(key(KEY_D) - key(KEY_A), key(KEY_S) - key(KEY_W))
		if right:
			movement.x += key(KEY_E) - key(KEY_Q)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				movement.y = -1
		movement = movement.limit_length()
	input_timer -= delta
	if authoritative():
		apply_input(local_id, movement, local_yaw, queued_jump, selected_id)
		queued_jump = false
	elif input_timer <= 0:
		input_timer = 1.0 / 30.0
		input_seq += 1
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
	actor.action_budget = maxf(0, actor.action_budget - delta)
	actor.input_age += delta
	if actor.hp <= 0:
		actor.casting = -1
		actor.velocity = Vector3.ZERO
		return
	for i in range(7):
		actor.cooldowns[i] = maxf(0, actor.cooldowns[i] - delta)
	for field in ["gcd", "stunned", "locked", "shield", "sprint", "dr_timer"]:
		actor.set(field, maxf(0, actor.get(field) - delta))
	if actor.dr_timer == 0:
		actor.dr_count = 0
	if actor.owner_peer == 0:
		bot_think(actor, delta)
	elif actor.input_age > 0.3:
		actor.move_input = Vector2.ZERO
	var direction: Vector3 = actor.basis * Vector3(actor.move_input.x, 0, actor.move_input.y)
	if actor.stunned > 0:
		direction = Vector3.ZERO
		actor.casting = -1
	var speed := 6.5 if actor.move_input.y <= 0 else 3.8
	if actor.sprint > 0:
		speed *= 1.65
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	if actor.jump_queued and actor.is_on_floor() and actor.stunned <= 0:
		actor.velocity.y = 7
	actor.jump_queued = false
	actor.velocity.y -= 20 * delta
	actor.move_and_slide()
	if actor.casting >= 0:
		if direction.length() > 0.01 or not actor.is_on_floor():
			actor.casting = -1
			feedback(actor, "Cast cancelled by movement")
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

func has_los(a, b) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a.position + Vector3.UP, b.position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func spell_target(actor, slot: int, requested: int) -> int:
	var kind: String = actor.kit[slot].kind
	if kind in ["shield", "self_heal", "blink", "sprint"]:
		return actor.actor_id
	if kind in ["heal", "ally_shield", "dispel"]:
		if actors.has(requested) and actors[requested].team == actor.team:
			return requested
		return actor.actor_id # Enemy or no target: helpful spells fall back to self.
	return requested

func validate_spell(actor, slot: int, victim_id: int) -> String:
	if not actors.has(victim_id) or actors[victim_id].hp <= 0:
		return "Select a living target"
	var victim = actors[victim_id]
	var spell: Dictionary = actor.kit[slot]
	var friendly: bool = spell.kind in ["heal", "ally_shield", "dispel", "shield", "self_heal", "blink", "sprint"]
	# A pull is aimed at whoever is selected, ally or enemy — the only ability
	# that does not care which side the target is on. It still needs range,
	# line of sight and facing, because it is an aimed ability either way.
	if spell.kind == "pull":
		if victim == actor:
			return "Select another fighter"
	elif (victim.team == actor.team) != friendly:
		return "Select an ally" if friendly else "Select an enemy"
	if victim == actor:
		return ""
	if actor.position.distance_to(victim.position) > float(spell.range):
		return "Out of range"
	if not has_los(actor, victim):
		return "Target is out of line of sight"
	if not friendly and (-actor.basis.z).dot((victim.position - actor.position).normalized()) < 0:
		return "Face your target"
	return ""

func send_action(slot: int) -> void:
	if phase != "match" or not actors.has(local_id):
		return
	if authoritative():
		try_spell(local_id, slot, selected_id)
	else:
		action_seq += 1
		deliver_action(epoch, action_seq, slot, selected_id)

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
		actor.casting = -1
		return
	try_spell(id, slot, selected)

func try_spell(id: int, slot: int, requested: int) -> bool:
	if not authoritative() or phase != "match" or not actors.has(id) or slot < 0 or slot >= 7:
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
				combat_event(actor.actor_id, victim.actor_id, "INTERRUPTED", GOLD)
			else:
				feedback(actor, "Interrupt missed — target was not casting")
		"control":
			var factor: float = [1.0, 0.5, 0.25, 0.0][mini(victim.dr_count, 3)]
			if factor == 0:
				combat_event(actor.actor_id, victim.actor_id, "IMMUNE", GOLD)
			else:
				victim.stunned = spell.power * factor
				victim.casting = -1
				victim.dr_count += 1
				victim.dr_timer = 18 + victim.stunned
				combat_event(actor.actor_id, victim.actor_id, "STUN %.1fs" % victim.stunned, GOLD)
		"shield", "ally_shield":
			victim.shield = spell.power
			combat_event(actor.actor_id, victim.actor_id, "WARD", BLUE)
		"dispel":
			victim.stunned = 0
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
	actor.move_and_collide(motion)

func damage(source, victim, amount: float) -> void:
	var actual := minf(victim.hp, amount * (0.4 if victim.shield > 0 else 1.0))
	victim.hp = maxf(0, victim.hp - actual)
	combat_event(source.actor_id, victim.actor_id, "−%d" % ceili(actual), RED)
	if victim.hp == 0:
		victim.casting = -1
		victim.move_input = Vector2.ZERO
		combat_event(source.actor_id, victim.actor_id, "DEFEATED", GOLD)

func check_winner() -> void:
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

func update_frame(frame: VBoxContainer, id: int, prefix: String) -> void:
	frame.set_meta("actor_id", id)
	frame.visible = actors.has(id)
	if not frame.visible:
		return
	var actor = actors[id]
	(frame.get_child(0) as Label).text = "%s · %s" % [prefix, actor.champion]
	var health := frame.get_child(1) as ProgressBar
	health.value = actor.hp
	var fill := health.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = BLUE if actors.has(local_id) and actor.team == actors[local_id].team else RED
	(health.get_child(0) as Label).text = "%d / 100 HP" % ceili(actor.hp)
	var cast := frame.get_child(2) as ProgressBar
	cast.visible = actor.casting >= 0
	if actor.casting >= 0:
		var total: float = actor.kit[actor.casting].cast
		cast.value = 100 * (1 - actor.cast_left / maxf(0.01, total))
		(cast.get_child(0) as Label).text = "%s · %.1fs" % [actor.kit[actor.casting].name, actor.cast_left]
	var statuses: Array[String] = []
	if actor.hp <= 0:
		statuses.append("DEAD")
	if actor.stunned > 0:
		statuses.append("STUN %.1fs" % actor.stunned)
	if actor.locked > 0:
		statuses.append("LOCKOUT %.1fs" % actor.locked)
	if actor.shield > 0:
		statuses.append("WARD %.1fs" % actor.shield)
	if actor.dr_timer > 0:
		statuses.append("DR %d · %.0fs" % [actor.dr_count, actor.dr_timer])
	(frame.get_child(3) as Label).text = "  ".join(statuses)

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
			party_buttons[i].text = "F%d  %s   %d HP%s" % [i + 1, member.champion, ceili(member.hp), "  STUN" if member.stunned > 0 else ""]
	var enemies := enemy_ids()
	enemy_box.visible = not enemies.is_empty()
	for i in range(3):
		enemy_buttons[i].visible = i < enemies.size()
		if i < enemies.size():
			var foe = actors[enemies[i]]
			enemy_buttons[i].text = "%s  %d HP%s" % [foe.champion, ceili(foe.hp), "  STUN" if foe.stunned > 0 else ""]
	for slot in range(7):
		var button := ability_buttons[slot]
		button.visible = actors.has(local_id)
		if not button.visible:
			continue
		var actor = actors[local_id]
		var spell: Dictionary = actor.kit[slot]
		var art := AbilityArt.texture_for(spell.name)
		ability_images[slot].texture = art
		ability_images[slot].visible = art != null
		ability_images[slot].modulate = Color("b6a4cf") if button.button_pressed else Color.WHITE
		# Unillustrated abilities retain the existing text fallback.
		button.text = "" if art != null or actor.cooldowns[slot] > 0.0 else spell.name
		# The ability's own cooldown wins the slot: it is the longer wait and the
		# one worth a number. The global cooldown only shows where nothing else is
		# running, and never on an off-GCD ability.
		var own: float = actor.cooldowns[slot]
		var global_cd: float = 0.0 if spell.off else actor.gcd
		if own > 0.0:
			cooldown_overlays[slot].sync(own, maxf(spell.cd, own), false)
		elif global_cd > 0.0:
			cooldown_overlays[slot].sync(global_cd, GCD_DURATION, true)
		else:
			cooldown_overlays[slot].sync(0.0, 0.0, false)
		button.modulate = Color("83919e") if actor.hp <= 0 else Color.WHITE
	update_ability_tooltip()

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

func cycle_target() -> void:
	if not actors.has(local_id):
		return
	var candidates: Array[int] = []
	for actor in actors.values():
		if actor.team != actors[local_id].team and actor.hp > 0:
			candidates.append(actor.actor_id)
	if not candidates.is_empty():
		selected_id = candidates[(candidates.find(selected_id) + 1) % candidates.size()]

func _input(event: InputEvent) -> void:
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
	if panel.visible or phase not in ["match", "countdown"]:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(3, arm.spring_length - 0.8)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(18, arm.spring_length + 0.8)
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			capture_mouse()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			cycle_target()
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			send_action(event.keycode - KEY_1)
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F3:
			select_party(event.keycode - KEY_F1)
		if event.keycode == KEY_F:
			focus_id = selected_id
		if event.keycode == KEY_G and actors.has(focus_id):
			selected_id = focus_id
		if event.keycode == KEY_SPACE:
			queued_jump = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_mouse(false)
		queued_jump = false

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
		elif arg.begins_with("--port="):
			explicit_port = clampi(int(arg.get_slice("=", 1)), 1, 65535)
		elif arg.begins_with("--min-players="):
			min_players = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--rematch-delay="):
			rematch_delay = maxf(0.5, float(arg.get_slice("=", 1)))
	if wants_dedicated:
		mode = mode_choice.get_selected_id()
		if explicit_port > 0:
			current_port = explicit_port
		elif private_lobby:
			current_port = Config.LOBBY_PORTS[0]
		else:
			current_port = Config.DUEL_PORT if mode == 1 else Config.TEAM_PORT
		host_session(true)
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
	for slot in range(ability_buttons.size()):
		var button := ability_buttons[slot]
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pointer):
			var actor = actors[local_id]
			ability_tooltip.present(actor.kit[slot], actor.champion, pointer, ui.size)
			return
	ability_tooltip.hide()
