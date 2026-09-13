# Networking addon review — 12 September 2026

Review only. No networking, addon settings, tick rates, or deployment changes were made. Findings below distinguish visual smoothness, bandwidth, and server CPU; those are not interchangeable.

## Netfox 1.35.3

The downloaded version is recorded in `addons/netfox/plugin.cfg`. It is not connected to Starfall's runtime: `project.godot` has no Netfox autoload configuration and the game scripts do not use its synchronizers. Starfall already has immediate client movement prediction, replay, ordered unreliable snapshots, physics interpolation, jump retries, forced-movement revisions, and bounded aimed-hit history. Netfox should be a source of selected ideas, not an automatic replacement.

### Best candidates

| Priority | Idea in plain terms | What it helps | Possible downside |
| --- | --- | --- | --- |
| 1 | Play remote positions along a short, timestamped timeline instead of continually chasing the newest position. | Smoother opponents when packets arrive unevenly. | Adds some display delay; needs outage/teleport handling and matching shot-rewind timing. Does not reduce server CPU. |
| 2 | Correct the player's true simulated position accurately, but soften ordinary corrections in the displayed model/camera. | Fewer visible rubberbanding bumps. | Excessive smoothing feels floaty; visuals and hitboxes must stay coherent. Teleports and forced movement must remain explicit resets. |
| 3 | Make client and server agree more precisely about which movement commands were simulated at which times. | Fewer actual prediction errors, particularly during jitter or sprint/slow changes. | Higher complexity; careless queuing/replay can increase CPU or introduce speed exploits. Measure first. |
| 4 | Define smaller, class-specific network data and stop repeating stable spawn information. | Less serialization/copying and fewer bytes. | Missing state can break effects, UI, reconnects, or prediction. Requires versioned schema and full coverage. |
| 5 | Later, send changes against a state the receiving player confirmed, with periodic full repair updates. | Mainly bandwidth savings. | Per-player histories, comparisons and acknowledgements may increase CPU. Current compression already works well. |
| 6 | In a larger World, reduce updates for distant nonparticipants using cached relevance lists. | Bandwidth and client processing at scale. | Pop-in/stale targets if boundaries are too aggressive. Little benefit in a small arena; does not automatically stop server simulation or hitboxes. |

Suggested order: instrument correction sizes, packet arrival jitter, snapshot bytes and server milliseconds; then prototype remote timeline playback plus correct shot timestamps; next examine command/replay mismatches. Treat compact snapshots as a measured optimization, not a presumed main-lag fix. Full Netfox rollback migration is not the first recommendation.

### Specific code evidence

**Remote playback.** `scripts/arena.gd:2321–2326` eases each remote actor toward its single latest `net_position` with `delta * 22`. It has no timestamped movement snapshot queue. `addons/netfox/tick-interpolator.gd:79–93` retains explicit from/to states and teleport handling; `:135–180` uses the network tick fraction. These are useful concepts, but Netfox's two-state tick interpolator is not itself a ready-made adaptive jitter buffer. Do not stack it on the existing smoothing without choosing one authoritative presentation timeline. The current shot timestamp subtracts a fixed 50 ms allowance in `scripts/aimed_combat.gd:202`; it must instead correspond to the actually rendered target state if playback delay changes. [Netfox interpolation guide](https://foxssake.github.io/netfox/latest/netfox/nodes/tick-interpolator/).

**Local corrections.** `scripts/movement_prediction.gd:18–58` restores the server state and replays pending inputs, but discards clear-space position corrections under 12 cm. Larger corrections remain immediate. Crossing this threshold is a plausible source of visible bumps, not a proven explanation for every reported rubberband. A bounded visual correction offset would address reconciliation rather than normal physics-frame interpolation. Keep server authority, collision checks, floor-contact overrides and motion revisions.

**Input timing.** The client records each physics command (`scripts/arena.gd:2356`) and replays its history (`scripts/movement_prediction.gd:48`). The server accepts only newer input, overwrites the current command (`scripts/arena.gd:2409`) and acknowledges the latest sequence after one physics step (`:2513`). Several arriving packets are not necessarily several simulated steps. Replay also uses currently available movement modifiers rather than advancing complete historical sprint/slow/root state. Correlate correction size with acknowledgement gaps and modifier changes before deciding on tick alignment, input bundles or movement-state history. Netfox's `encoder/redundant-history-encoder.gd:34` and rollback freshness tracking are useful references. Wider rollback requires replay-safe effects and authoritative state; it can add work rather than remove it. [Netfox rollback guide](https://foxssake.github.io/netfox/latest/netfox/nodes/rollback-synchronizer/).

**Clocks and jitter.** Netfox keeps sampled RTT/jitter and gradually disciplines time (`network-time-synchronizer.gd:70–121,170–237`). Its reference clock and monotonic simulation clock are deliberately separate. Starfall's animation snapshot clocks already prevent frozen poses between packets; do not replace those blindly. Borrowing a stable timestamp reference could help remote playback and diagnostics, but a new clock must not retime authoritative cooldowns or duplicate the existing physics loop. [Netfox time synchronization guide](https://foxssake.github.io/netfox/latest/netfox/guides/network-time-synchronizer/).

**Payloads.** `scripts/combatant.gd:229–231` deep-copies full identity, cooldowns and control state; `scripts/arena.gd:2265` collects every actor. `:2434–2435` serializes/compresses the array **once**, then broadcasts it. Netfox selects explicit properties and compact identifiers (`state-synchronizer.gd:16`, `encoder/snapshot-history-encoder.gd:22`, `encoder/diff-history-encoder.gd:48`). Its per-peer diff generation (`state-synchronizer.gd:183–204`) adds work that Starfall's shared broadcast currently avoids.

**Delta caveats.** Cooldown arrays and nested identity dictionaries change continuously; treating each as one Netfox property still sends that changing property. Consider expiry timestamps or change-driven status records only with correct cleanse/refresh/reconnect handling. Netfox diffs compare against acknowledged states and periodically send full state, but its missing-reference fallback in `encoder/diff-history-encoder.gd:111` must not be copied without stricter recovery. Its synchronizer still extracts state every tick and can send an empty-diff RPC: enabling diffs is not equivalent to disabling idle work.

**Relevance and bursts.** `peer-visibility-filter.gd:20–36,89–117` caches recipients and supports manual refresh. For moving World actors, refresh at controlled intervals/cell changes with generous combat margins; peer-join-only refresh is insufficient. `rollback/composite/rollback-history-transmitter.gd:88–96` staggers full refreshes. Borrow staggering only if a future per-actor delta design needs it, and retain batching rather than creating a packet for every actor.

### Local snapshot baseline, not a live-server profile

Actual `make_snapshot()` and DEFLATE path, 600 iterations per case on this computer, Godot 4.7.2 headless. This is synthetic synchronized movement/timers: actors share velocity and timer values, making the data more repetitive than varied live combat. Includes construction, serialization and compression; excludes combat simulation, hitboxes, network/RPC overhead and busy-match effect stacks. The live Defense Detonation timestamp path in `scripts/outlaw_aim_test.gd:229` uses the same fixed visual allowance discussed above and must be kept aligned too.

| Actors | Mean preparation time per snapshot | Mean compressed bytes per recipient | Approximate bytes/second per recipient at 20 Hz |
| --- | ---: | ---: | ---: |
| 2 | 0.086 ms | 982 | 19,640 |
| 6 | 0.199 ms | 1,228 | 24,560 |
| 12 | 0.371 ms | 1,497 | 29,940 |

At two actors this measured preparation is about 1.7 ms of work per second on this machine, not per frame. It does not support calling snapshot compression the current main CPU bottleneck. Full raw states were roughly 5.9–35.7 KB; current compression already removes substantial repetition. These numbers do not predict production hardware or prove a future optimization's savings. Evidence: `artifacts/netfox-review-20260912/snapshot-baseline.json` and `snapshot-baseline.log`; isolated diagnostic script lives beside them.

### Avoid as quick fixes

- Do not make all movement reliable: delayed old movement is not more useful than a newer update.
- Do not lower the 60 Hz combat/physics rate merely because Netfox defaults to a different network rate.
- Do not increase snapshot frequency before measuring payload and correction causes.
- Do not enable generic full rollback over combat damage, healing, cooldowns, particles and sounds without replay-safe state and one-time-event guards.
- Do not promise that fewer bytes means less CPU, or that smoother rendering removes actual packet delay.

No Netfox integration is approved or implemented by this review.

## Ezcha Network 2.7.2

**Bottom line: useful for online-service/lobby features, not a fix for Starfall's movement synchronization or server CPU.** This is a different category from Netfox. The local plugin wraps Ezcha authentication, lobbies/relay, trophies, leaderboards and datastores (`addons/ezcha_network/plugin.cfg`, `lib/singleton.gd`). It does not contain a replacement for our movement prediction, snapshot interpolation or hitbox lag compensation. [Official plugin documentation](https://github.com/ezcha-network/godot-plugin/blob/godot-4.x/docs.md).

What is worth borrowing or considering:

- **Pick a good server region before a match.** `lib/client.gd:273–309` probes candidate relay servers in batches of five and sorts by measured delay. The general idea could apply to Starfall's dedicated servers, if multiple regions are available. Use repeated actual game-transport RTT/jitter samples rather than copying the single HTTP request measurement in `lib/dto/relay_server.gd:28–40`; HTTP startup time is not the same as ongoing game packet delay. Potentially lowers players' network latency, not simulation CPU. Tradeoffs: startup probes, noisy selection and infrastructure requirements; no automatic in-match migration.
- **Optional lobby/account convenience.** Join codes, visibility, guest sessions, version-filtered lobby listing and structured error messages could improve joining and session management. Starfall already has lobby/roster/duel flows and a pre-RPC version/schema handshake; do not replace those safeguards with a lobby version label. Accounts, trophies and cloud data are product features requiring service setup, not lag optimizations.
- **Host-migration reference only for a separately requested player-hosted mode.** `lib/class/relay_multiplayer_peer.gd:703` remaps peer IDs and updates its spawners. That does not transfer Starfall's full authoritative match state, pending shots, cooldowns or reconciliation history. It is not seamless failover for the current dedicated server.

Why I would not replace the current combat transport with its relay just to chase smoother movement:

`lib/class/relay_multiplayer_peer.gd:128,490` uses **WebSocketPeer**. Game packets also go through `_ws.send`; transfer mode/channel numbers are included in that packet format, but the underlying connection remains WebSocket/TCP. Lost data can hold up later data on that stream. This can be less suitable than the current ENet unreliable-ordered movement/snapshot channels for fast combat during packet loss. A relay adds another path/service dependency; it may improve reachability, but is not guaranteed to improve ping. It still leaves a host responsible for gameplay simulation. [Godot's WebSocket guidance](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).

Integration costs/risks: external-service availability and region suitability, authentication/reconnect handling, authority remapping, account privacy, deployment setup, and careful key handling. The editor plugin adds an autoload and export platform on enable; `lib/export_plugin.gd:15–31` only excludes configured keys when the matching exclusion feature is requested. Never ship privileged server API credentials in a player build. No credentials were read or external Ezcha sessions/relays contacted in this review; current service pricing/capacity was not evaluated.

Recommendation: retain ENet and the targeted Netfox-inspired improvements for combat. Keep Ezcha on the optional list if account/lobby/relay product features become a separate priority. No Ezcha configuration or integration was changed.
