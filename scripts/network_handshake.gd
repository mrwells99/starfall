extends RefCounted

# Runs before SceneMultiplayer permits ANY scene RPC. An RPC cannot safely
# negotiate versions because differing method tables can misroute that RPC too.
const Config = preload("res://scripts/config.gd")
const PROTOCOL := 3
var game
var schema := ""
var rejection := ""

func setup(arena) -> void:
	game = arena
	schema = fingerprint(game.get_script())
	game.multiplayer.auth_callback = receive
	game.multiplayer.auth_timeout = 5.0
	game.multiplayer.peer_authenticating.connect(begin)
	game.multiplayer.peer_authentication_failed.connect(failed)

static func fingerprint(script: Script) -> String:
	var entries := {}
	while script != null:
		var rpc_config: Dictionary = script.get_rpc_config()
		for method in script.get_script_method_list():
			if not rpc_config.has(method.name) or entries.has(method.name):
				continue
			var types := []
			for argument in method.args:
				types.append([argument.type, str(argument.class_name)])
			entries[str(method.name)] = [rpc_config[method.name], types, method.return.type, method.default_args.size()]
		script = script.get_base_script()
	return JSON.stringify(entries).sha256_text()

func begin(peer: int) -> void:
	rejection = ""
	# The server speaks first. Legacy servers never receive an auth payload
	# they cannot understand; the client simply times out with a clear message.
	if game.multiplayer.is_server():
		game.multiplayer.send_auth(peer, hello_packet())

func hello_packet() -> PackedByteArray:
	return JSON.stringify({"game": "starfall", "protocol": PROTOCOL, "version": Config.VERSION, "schema": schema}).to_utf8_buffer()

func receive(peer: int, payload: PackedByteArray) -> void:
	var hello = JSON.parse_string(payload.get_string_from_utf8()) if payload.size() <= 1024 else null
	var reason := "Network protocol mismatch. Update and restart both the game and server."
	if hello is Dictionary and hello.get("game") == "starfall" and hello.get("protocol") == PROTOCOL:
		if hello.get("version") == Config.VERSION and hello.get("schema") == schema:
			if not game.multiplayer.is_server():
				game.multiplayer.send_auth(peer, hello_packet())
			game.multiplayer.complete_auth(peer)
			return
		if hello.get("version") != Config.VERSION:
			reason = "Version mismatch — this game is v%s, the other build is v%s. Update and restart both the game and server." % [Config.VERSION, str(hello.get("version", "unknown")).left(32)]
		else:
			reason = "Network build mismatch despite matching version numbers. Restart the game and server using the same build."
	if not game.multiplayer.is_server():
		rejection = reason
		game.call_deferred("leave_session", reason)
	else:
		# Both sides already exchanged their hello, so the client can describe
		# the mismatch locally without invoking a potentially incompatible RPC.
		game.multiplayer.disconnect_peer(peer)

func failed(_peer: int) -> void:
	if game.network and not game.multiplayer.is_server():
		var reason := rejection if not rejection.is_empty() else "Server could not complete the compatibility check. It may be running an older build. Update and restart both the game and server."
		game.call_deferred("leave_session", reason)
