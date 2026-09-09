extends RefCounted

# Deployment constants. Update SERVER_ADDRESS when the DO droplet address changes
# and VERSION on every release — the deploy pipeline rewrites this file, and the
# server hard-rejects clients whose VERSION doesn't match.
#
# Duel and Team run as SEPARATE dedicated server processes on the same droplet,
# each bound to its own port. Clients pick a port based on the matchmaking mode.
const VERSION := "0.7.0"
const SERVER_ADDRESS := "play.leafmods.com"
const DUEL_PORT := 27840
const TEAM_PORT := 27841
# The persistent world: one always-running server, no queue and no lobby.
const WORLD_PORT := 27842
# Kept as an alias for legacy references / offline defaults.
const SERVER_PORT := DUEL_PORT
const DEFAULT_MIN_PLAYERS := 2

# Private lobbies: a fixed pool of dedicated processes, one per port, each idle
# until a player claims it with "Host lobby". The client probes the pool in order
# rather than asking a broker, so there is no separate matchmaker service to run.
# Concurrent private lobbies are capped at the size of this array.
const LOBBY_PORTS := [27850, 27851, 27852, 27853]
# Codes are short and read aloud over voice chat, so the alphabet omits the
# characters that get misheard or misread: 0/O, 1/I/L, 5/S, 2/Z, 8/B.
#
# The FIRST character is the index into LOBBY_PORTS of the slot that issued the
# code; the rest is random. Pool members mint codes with no coordination, so
# this is what makes a collision between two slots impossible rather than merely
# unlikely — and it lets a joining client skip the probe and dial the right
# server directly. LOBBY_PORTS must therefore never grow past the alphabet.
const CODE_ALPHABET := "ACDEFGHJKMNPQRTUVWXY3467"
const CODE_LENGTH := 4
