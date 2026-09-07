# Ringfall

A Godot 4.5 arena-combat prototype with WoW-style third-person controls and fixed champion kits. Choose a champion and play local sparring, host a duel, or run a 3v3 team arena. No gear or leveling.

## Play

Open `project.godot` in Godot and press **F5**, or run:

```sh
godot --path .
```

Select your champion and **Duel · 1v1** or **Team arena · 3v3**, then choose **Local sparring**. Empty slots become bots. In local 3v3, each team has a healer, melee fighter, and ranged caster. A three-second countdown starts each round. The round ends when every member of one team is dead; your teammates keep fighting if you die first.

### Controls

| Input | Action |
| --- | --- |
| W / S | Forward / backward |
| A / D | Turn; strafe while holding RMB |
| Q / E | Strafe |
| Space | Jump |
| Hold RMB | Steer character and camera |
| Hold LMB | Orbit camera independently |
| Hold both mouse buttons | Run forward |
| Wheel | Zoom; camera retracts against geometry |
| Tab | Cycle living enemies |
| Click a character / world | Camera control only; never changes target |
| F1 / F2 / F3 | Select yourself / first teammate / second teammate |
| Click party / enemy frame | Select that teammate / enemy |
| Click player / target / focus frame | Select the character represented by that frame |
| F / G | Set focus / select focus target |
| 1–7 or hotbar click | Use ability |
| Hover ability | Short effect description |
| Hold Shift while hovering | Full mechanics, values, targeting rules, and limitations |
| Escape | Cancel cast, otherwise clear target, otherwise open panel |

Character models and overhead nameplates are never clickable targets. Mouse-look restores the cursor to its original position when released. Shift expands or collapses the current tooltip immediately without moving the pointer.

Opening the panel stops your movement but **does not pause combat**, locally or online. Use Resume or Escape to close it.

### Champions

| Key | Ember — ranged | Vanguard — melee | Luminary — healer |
| --- | --- | --- | --- |
| 1 | Firebolt: casted damage | Cleave: melee damage | Smite: casted damage |
| 2 | Flare: instant burst | Crush: melee burst | Renewal: instant ally heal |
| 3 | Disrupt: interrupt | Pummel: melee interrupt | Dispel: remove an ally's stun |
| 4 | Stasis: casted stun | Bash: melee stun | Rebuke: casted stun |
| 5 | Ward: damage reduction | Iron Skin: damage reduction | Sanctuary: ally damage reduction |
| 6 | Mend: self heal | Mend: self heal | Greater Heal: repeatable ally heal |
| 7 | Blink: forward escape | Charge: close on target | Grace: movement speed boost |

Helpful Luminary abilities use your friendly target; with an enemy or no target selected they fall back to yourself. Select party members with F1–F3 or their frames. Dead allies cannot be healed. Blue health bars identify allies; red bars identify enemies, relative to your team. The character model and overhead bar use absolute team colors.

## Play with friends

1. Everyone uses the same project version and Godot 4.5.
2. Host chooses champion and mode, then **Host lobby**.
3. Other players choose champions, enter the host's IP, and click **Join**. For two copies on one computer, use `127.0.0.1`.
4. Wait for players to appear in the lobby. The host clicks **Start round / Rematch**.

Duel supports two people; 3v3 supports six. Teams are assigned alternately as players join. Vacant slots become bots; bot filling prefers missing roles, but human champion choices are unrestricted. Choose your champion before hosting/joining. To change roster or champions after a round, leave and create a new lobby. The host can immediately rematch the same roster.

Connections use **UDP 27840**. On a LAN, use the host computer's LAN IP and allow this port in its firewall. Internet connections require a reachable host address and appropriate UDP forwarding, or a shared VPN network. There is no relay, account service, or automatic matchmaking. Network tests currently cover localhost, not an external internet connection.

A disconnected client is replaced by a bot. If the host leaves, clients return to the menu; there is no host migration. Joining an active round is rejected with an explanation.

Command-line shortcuts:

```sh
godot --path . -- --local --team --champion=Luminary
godot --path . -- --host --team --champion=Vanguard
godot --path . -- --join=127.0.0.1 --champion=Ember
```

## Combat and AI

Offensive abilities check living target, team, range, facing, and line of sight both when starting and finishing a cast. Helpful spells also check range and sight. Moving or jumping cancels cast-time abilities. Most actions share a 1.5-second global cooldown; keys 3, 5, and 7 bypass it. Abilities currently cannot be used during another cast.

Interrupting an active cast causes a four-second spell lockout. Control durations diminish to half, then quarter, then immunity; the category resets 18 seconds after the last successful control ends. A ward reduces damage by 60% for five seconds. Blink and Charge sweep the character capsule against geometry, so they cannot cross pillars or walls.

Healing reduction begins after 60 seconds and reaches its 70% cap at 186 seconds (3:06), helping long healer matches resolve. Initial numbers are intended for playtesting, not established balance.

Bots use a clearance-aware grid to navigate pillars, approach targets, use interrupts and defenses, heal injured allies, and dispel control. They remain simple training opponents rather than competitive AI.

Cast bars, floating damage/healing numbers, hit flashes, overhead health bars, stun/lockout indicators, party frames, focus frames, and persistent results expose the combat state.

## Networking design

The hosting player is the authoritative server. Clients submit normalized movement intent and ability requests; the host owns collision, targeting validation, HP, cooldowns, casting, crowd control, and victory. Client requests are tied to the sender's fighter, validated, and rate-limited. Round IDs and sequence numbers reject stale inputs and snapshots.

Movement inputs run at 30 Hz; compressed state snapshots at 20 Hz. Clients interpolate authoritative positions. Cast requests, feedback events, lobby changes, and results are reliable; movement and snapshots are ordered/unreliable. Snapshot decompression is capped at 64 KiB. No client movement prediction, lag compensation, host migration, authentication, or production anti-cheat is implemented. Input-to-motion delay is visible at high latency; camera orbit responds immediately.

For repeatable delay testing, append `--latency-ms=75` to both host and client commands. This adds 75 ms to client input/action sends and 75 ms to host snapshots, beyond actual network delay. It does not emulate packet loss, jitter, or delayed reliable events. The displayed RTT measures the underlying ping exchange and excludes this artificial delay.

## Files

- `scripts/arena.gd`: match flow, authoritative simulation, networking, UI, input, and bots.
- `scripts/combatant.gd`: per-fighter state, visuals, and snapshots.
- `scripts/kits.gd`: champion ability data and short/detailed player-facing descriptions.
- `scripts/ability_tooltip.gd`: live Shift-hover tooltip presentation.
- `scripts/arena_navigation.gd`: pillar-aware pathfinding.
- `scripts/arena_world.gd`: generated arena geometry and lighting.

No external assets or dependencies are required. Art is placeholder geometry; animations, audio, resource systems, configurable keybindings, matchmaking, ranked progression, and production polish remain future work.

For a detailed engineering handoff, read [CLAUDE.md](CLAUDE.md).

## Verify

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/combat_test.gd
python3 tests/run_network.py
python3 tests/run_network.py --test-team --test-latency
python3 tests/run_six.py
godot --path . --script tests/visual_check.gd
godot --path . --script tests/ui_test.gd
```

Run network suites sequentially because each uses UDP 27840. They launch real host/client processes, exercise movement and casting, check state synchronization and rematches, and verify disconnect takeover. The six-peer test checks a complete human-controlled 3v3 roster and synchronized team results. The visual check briefly opens a window and saves staged lobby and healer screenshots to `artifacts/`. The UI test also requires a real window: it exercises model-click prevention, frame targeting, repeated mouse capture, keybinds, Shift-hover switching and tooltip bounds, and saves tooltip screenshots. Headless Godot is unsuitable for cursor-position/capture assertions.

Implementation references: [Godot multiplayer](https://docs.godotengine.org/en/4.4/tutorials/networking/high_level_multiplayer.html), [grid navigation](https://docs.godotengine.org/en/4.4/classes/class_astargrid2d.html), and [byte-array compression](https://docs.godotengine.org/en/4.4/classes/class_packedbytearray.html).
