# Decisions — long-term reasoning memory

_Meaningful decisions that future agents should not silently reverse. Trivial implementation choices don't belong here. Each entry: what was decided, why, alternatives considered, consequences._

Newest first.

## 2026-09-08 — Implement class identities while preserving the combat baseline

The owner authorized Ember Heat, Vanguard Resolve, Luminary Guiding Stars, and Fulcrum Gravity Anchor mechanics, with baseline mobility, damage reduction and sustain preserved. Kits expand to twelve slots over two action bars rather than replacing those tools. Anchor placement follows facing, stops at terrain and projects to ground, retaining keyboard/target combat. All abilities have painted icons; existing art is reused where appropriate. Version 0.6.0 separates these state/kit changes from older clients. Full implemented rules are in `CLASS_ABILITIES.md`; numbers need human playtesting.

---

## 2026-09-08 — Blender-authored Ember and Luminary with shared core locomotion

**Decision:** The owner explicitly requested replacing Ember's faceted model and rigid movement with a complete Blender-authored skinned character, then requested the same process and mostly the same animations for Luminary with a distinct supplied reference and creative liberty. This authorizes the skeletal asset pipeline for these two classes and supersedes older statements deferring all rig/animation work. Vanguard was subsequently authored via the same pipeline — see `VANGUARD_REBUILD_BRIEF.md`.

**Implementation:** Separately named editable Blender sources and GLB assets, class-specific presentation modules, seven matching clip durations, shared core gait, Blender verification and rendered Godot regression checks. Luminary adapts the staff-side arm and adds hair/cape controls. Animation remains presentation-only; collision, targeting, gameplay and network authority are unchanged.

**Scope:** These requests authorize local project integration, not automatic production-quality approval, remote publication or unrelated class redesigns. See `CHARACTER_PIPELINE.md` for exact files, workflow and known limitations.



## 2026-09-07 — Begin ability icons and original player models

**Decision:** The owner explicitly requested the full three-class icon roster and player models. This supersedes the prior blanket placeholder-only restriction for ability artwork and character presentation.

**Implementation:** Twenty generated painted icons cover the 21 slots (shared Mend). Original faceted Godot meshes provide distinct class silhouettes and simple procedural poses, while preserving collision, targeting and authoritative combat. Art mapping remains client presentation data outside ability dictionaries and snapshots.

**Scope:** These are usable first-pass designs, not a final champion-lore commitment. Environment art, audio and a skeletal animation pipeline are not implied by this decision. See `ART_DIRECTION.md` for current assets and review commands.

---

## 2026-09-07 — Theme: Cosmic Gladiators

**Decision:** Starfall's setting and visual theme is **Cosmic Gladiators** — fighters summoned from different worlds and universes to compete in an ancient cosmic arena. Space + fantasy: celestial temples, floating islands, black holes and nebulae in the background, ancient gods watching from massive structures. Champions range from alien assassins to celestial knights to weird cosmic beasts. Visual identity is deep purples and blues with extremely bright magical accents, stars, glowing weapons, cosmic effects. Full detail in [`ART_DIRECTION.md`](ART_DIRECTION.md).

**Why:** Set directly by the project owner. It also fits the structural constraints already in place: an arena disconnected from any world explains why fighters arrive at equal power with no gear and no leveling, and why an unrelated roster of champions shares one map. The fiction and the LoL-style structure reinforce each other rather than fighting.

**Alternatives considered:** None — this was a directive, not a trade-off analysis.

**Consequences:**

- [`ART_DIRECTION.md`](ART_DIRECTION.md) is the source of truth for how this is executed. Champion concepts, arena design, VFX, and background work should be checked against it.
- This does **not** reverse "Placeholder art, defer aesthetics" below. No external assets, no animation system yet. It gives placeholder work a direction to lean toward, not permission to start an art pipeline.
- Cross-universe variety is intentional: champions are *not* required to share a silhouette language or material palette.
- Existing functional colors (absolute team blue/red, the feedback cue palette) were chosen for contrast against a near-black background. Re-tuning them against a deep-purple cosmic palette is an open question, not a settled one — see the open list in [`ART_DIRECTION.md`](ART_DIRECTION.md).

---

## 2026-09-07 — Fulcrum, and `pull` as the first two-sided ability

**Decision:** A fourth champion, **Fulcrum**, joins the roster as a mid-range control specialist. Its signature is **Tether** (`kind: "pull"`), which drags the selected fighter 8 m toward the caster and works on **either team**.

**Why a controller:** the first three champions all solve problems by pointing at a target — ranged damage, melee damage, healing. Fulcrum's answer is to move the target instead, which is the first identity that leans on the positioning, line-of-sight and coordination the game says it is about. It is also the roster's first champion whose strongest play is often dealing zero damage.

**Why it was cheap:** six of seven slots reuse existing `kind` values with new numbers and names, so the kit inherits the balance skeleton every champion shares (spammable, burst, interrupt, stun, defensive, heal, mobility). Only `pull` is new, and it is `charge` run backwards — the server already sweeps an actor toward a point with collision and a stopping radius, so the same helper moves the victim rather than the caster.

**Two-sided targeting:** `validate_spell` splits abilities into friendly and hostile and rejects the wrong side. `pull` is exempt from that check alone; it still requires range, line of sight, facing, and a target other than yourself. It is deliberately not a soft interrupt — being moved does not cancel a cast, because that is Horizon's job and stacking both onto one ability would make Tether the only button worth pressing.

**Alternatives considered:**

- **A stealth assassin.** The most familiar WoW-arena archetype and the most requested shape. Rejected for now: stealth is a server-authoritative visibility system, not an ability.
- **A time manipulator** rewinding position or health. Rejected: rewinding health is a balance and networking problem well beyond a new kit.
- **Tether as enemy-only.** Simpler, and it matches Charge. Rejected because the ally save is what makes Fulcrum a 3v3 champion rather than a duelist.

**Consequences:**

- `Kits.NAMES` grew, and the server validates champion choice against it, so `Config.VERSION` went to **0.3.0** and older clients are refused.
- Fulcrum has **no icons and no dedicated model yet**. `AbilityArt.texture_for()` returns null for unknown names and the hotbar falls back to the ability name; `champion_model.build()` has no Fulcrum branch and produces a generic silhouette. Both degrade rather than break, and the art suite now asserts that fallback explicitly instead of demanding every ability be illustrated.
- Local sparring's auto-fill still builds healer / melee / ranged, so bots never pick Fulcrum. A human can, and bots fill around them.

---

## 2026-09-07 — A queue holds you for the next round; it never turns you away

**Decision:** On a dedicated server, `register_player` accepts a client that connects during `countdown`, `match` or `results`. The player waits in the roster and is spawned by the next `begin_round()`. Player-hosted lobbies keep the stricter rule — they have a host whose lobby you are genuinely waiting on.

**Why:** The queue servers auto-rematch continuously, so a round is in progress nearly all the time. The old check (`phase != "lobby"` → reject) meant the Online queue only worked during the few idle seconds between matches; every other attempt was bounced with "Lobby unavailable or full. Ask the host to return to the lobby." — a message that makes no sense in matchmaking, where there is no host. Private lobbies were unaffected because you claim an *idle* slot, which is why they worked while the queue appeared broken.

**Why it is safe:** actors are built from the roster at `begin_round()`, so registering mid-round spawns nothing. A waiting client ignores in-flight snapshots because `receive_snapshot` drops anything whose epoch does not match, and `round_started` is broadcast to all peers, so the newcomer is picked up by the next round. `maybe_auto_start()` still requires `phase == "lobby"`, so a mid-round registration cannot start a second round.

**Alternatives considered:**

- **Reject with a better message** ("a round is in progress, try again in 30s"). Honest, but it makes the player do the queue's job.
- **Spawn the late joiner into the running round.** Rejected: teams are balanced at `begin_round()`, and dropping someone into a match already in progress at partial HP is a different feature, not a fix.

**Consequence:** `lobby_state` gained an `in_round` flag so a queued client can say "Match in progress — you are in for the next round" instead of "Searching…". That is a protocol change, so `Config.VERSION` went to **0.2.0** and older clients are refused — which is the handshake doing its job.

---

## 2026-09-07 — Deploy as Docker containers from GHCR, not source on the droplet

**Decision:** Production deployment is six containers from one image, built and pushed to GHCR by GitHub Actions on every push to `main`, then rolled out over SSH. The image bundles a checksum-pinned Godot binary, the project source, and a **pre-built import cache**; it does not use Godot's export pipeline. The previous source-on-droplet + systemd model is archived in `deploy/legacy-systemd/`, not deleted.

**Why:** The systemd model needed the droplet to hold source, a matching Godot version, and a warm `.godot/` cache built at deploy time with every service stopped — a race we had to hand-sequence in `deploy.sh`. A prebuilt image makes the artifact immutable, moves the import step to build time, makes "what is running?" answerable by tag, and makes rollback a redeploy of an older tag instead of a git checkout.

**Why bundle rather than export:** the repo has no `export_presets.cfg` and no external assets — all geometry is generated at runtime — so an export needs ~1 GB of export templates to produce a `.pck` that is essentially the source we already ship. Bundling gets the properties that matter (immutable artifact, no runtime writes to the project, no import race, fast start) without that. Revisit when the project gains real assets.

**Alternatives considered:**

- **Keep systemd, add Actions.** Least change, and it works. Rejected: the artifact stays mutable, rollback means redeploying an old commit and rebuilding the cache, and the droplet needs a toolchain.
- **Godot export to `.pck` + server binary.** The conventional production answer and where this should end up eventually. Rejected for now on cost/benefit — see above.
- **One container running all six servers under a supervisor.** Fewer moving parts in compose. Rejected: one crash takes down every queue and lobby, and per-instance resource limits and health become impossible.
- **`network_mode: host`** instead of published UDP ports. Avoids Docker's UDP NAT entirely, which is the usual advice for game servers. Not needed — a real 3v3 and the full lobby-code probe were verified end to end through published ports. Kept as the documented switch if UDP NAT ever misbehaves.

**Consequences:**

- The compose service list, `Config.LOBBY_PORTS`, `.env`, and the firewall are four places encoding the same port set. They must change together.
- Rolling back across a `Config.VERSION` change disconnects every connected client with a version error — correct handshake behavior, but it looks like an outage. Noted in [`../DEPLOYMENT.md`](../DEPLOYMENT.md).
- The deploy account is deliberately **not** in the `docker` group (root-equivalent); it has passwordless sudo for two root-owned wrapper scripts with no meaningful arguments.
- Health is judged by the ENet socket being bound, not by the process existing.

---

## 2026-09-07 — Private lobbies: a fixed pool of server processes, no broker

**Decision:** Private lobbies are dedicated server processes from a fixed pool, one per port in `Config.LOBBY_PORTS` (currently 27850–27853), each launched with `--dedicated --lobby --port=N`. A slot sits idle until a client claims it. The client finds a slot by **probing the pool in port order**: "Host lobby" takes the first unclaimed slot, "Join lobby" walks the pool asking each server whether it holds the entered code. The server answers `lobby_found` or `lobby_busy`; on `lobby_busy` the client hangs up and tries the next port. There is no matchmaker or broker service.

**Why:** `scripts/arena.gd` is a single-match state machine — `phase`, `roster`, `actors`, `mode`, `epoch` are all process-globals, and every snapshot is broadcast with `rpc()` to all peers. Rooms inside one process would mean partitioning all of that and converting every broadcast to per-room addressing: a rewrite of the core, in the same change as new behavior. Probing a small pool reuses the already-working dedicated path untouched, and costs one extra round trip per idle slot walked.

**Alternatives considered:**

- **Multiple rooms inside one process.** The "right" answer at scale and the only one that isn't capped. Rejected for now: it is a rewrite of arena.gd's core, and [`ROADMAP.md`](ROADMAP.md) already wants that file decomposed *before* it grows new responsibilities.
- **A broker/hub process** holding a `code → port` registry, with clients connecting to it first. Cleaner than probing and removes the walk. Rejected for now because it needs a second process type, its own liveness tracking of the pool, and a claim protocol — more moving parts than probing four ports.
- **Peer-hosted lobbies with the code encoding the host's IP.** Cheapest to build and needs no server at all. Rejected because it does not work: the host would have to port-forward UDP, and Godot's ENet layer here has no relay or NAT punchthrough. Fine on a LAN, useless for buddies on the open internet — which is the actual use case.

**Consequences:**

- Concurrent private lobbies are capped at `Config.LOBBY_PORTS.size()`. Adding a slot means adding a port there **and** a service in `docker-compose.yml` and a port in `.env`; the two lists must stay in step or clients will probe a dead port and time out.
- Codes use an alphabet that omits look-alike characters (`0/O`, `1/I/L`, `5/S`, `2/Z`, `8/B`) because they get read aloud over voice chat. The **first character encodes the issuing slot**, the rest is random: pool members mint codes with no coordination, so this is what makes a cross-slot collision impossible rather than merely unlikely. A joiner therefore dials the right server directly instead of walking the pool. `Config.LOBBY_PORTS` must never grow past `CODE_ALPHABET`.
- A slot releases automatically when its last player disconnects (`LOBBY RELEASED` in the log). A crashed client leaves the slot held until ENet times the peer out.
- This reverses the "multiple concurrent lobbies per server process" line previously in [`ROADMAP.md`](ROADMAP.md)'s not-planned list — that item said no *rooms in one process*, which still holds. Concurrency now comes from more processes.

---

## 2026-09-07 — Deploy target: `play.leafmods.com` (domain, not raw IP or IPv6)

**Decision:** The dedicated server is reachable at `play.leafmods.com`. `Config.SERVER_ADDRESS` is set to that hostname. DNS `A` record points at the DO droplet's IPv4.

**Why:** A domain separates identity from location. If we ever move the server (new droplet, different region, different provider), buddies with old clients still resolve to whatever the DNS says — no forced client rebuild solely due to an IP change. The user already owns `leafmods.com`, so incremental cost is zero.

**Alternatives considered:**

- **Raw droplet IPv4** — free, and DO droplet IPs don't rotate. Rejected because any future server move would need a forced client rebuild + republish, even though only the address changed.
- **IPv6 address** — free and stable, but some buddies' ISPs and home routers still don't handle v6 cleanly; IPv6 literals in code are ugly. Rejected. AAAA record can be added later without touching client code.

**Consequence:** The client resolves `play.leafmods.com` on connect. If DNS is misconfigured or unreachable, Godot's `create_client` will fail with "Connection failed" — same failure path as an unreachable IP.

---

## 2026-09-07 — Repository as persistent AI shared memory

**Decision:** Documentation is reorganized around `docs/` as the source of truth. The main `README.md` (symlinked from `CLAUDE.md`) is a short operating manual — it explains **how to use the system**, not what the system contains. Persistent knowledge lives in `docs/*.md`.

**Why:** Multiple AI agents (Claude Code, Cursor, Codex, and others) collaborate here across sessions. Without a shared persistent memory, each agent starts from scratch and re-learns the same context. Concentrating knowledge into one giant README made it easy to load but hard to update selectively — agents either dumped everything into one file or invented ad-hoc structure per session.

**Alternatives considered:**

- Keep the giant merged README. Rejected — it kept growing and mixed unrelated concerns (design, architecture, deploy, testing) so agents couldn't update one area cleanly.
- Use `AGENTS.md` or per-tool convention files. Rejected — creates duplication; the symlink strategy already gets multiple tools onto the same content.

**Consequence:** Agents must update the appropriate `docs/*.md` when durable knowledge changes. The main README should stay stable and short. New docs may be created for substantial recurring areas — see the README workflow section.

---

## 2026-09-07 — Dedicated server mode

**Decision:** Add `--dedicated` mode that runs the game as a server without a local player. Server auto-starts a round when `--min-players` humans have connected; auto-rematches `--rematch-delay` seconds after each round ends; holds in lobby when the roster drops below the threshold.

**Why:** The endgame vision is a shared dedicated server that buddies join without any of them needing to host locally. Building it inside the game process (not a separate binary) keeps the code path and RPC definitions identical between local host and dedicated server — no risk of protocol drift.

**Alternatives considered:**

- Extract a separate headless-server binary. Rejected for now — the game process is already headless-capable, and a second codebase would drift.
- Keep only player-hosted lobbies. Rejected — every session requires a friend to host, which is fragile.

**Consequence:** DevOps pipeline (GitHub Actions, systemd, client launcher) becomes the next priority. `Config.SERVER_ADDRESS` is the deploy-time target the client bakes in. See [`ROADMAP.md`](ROADMAP.md).

---

## 2026-09-07 — Version handshake, forced updates for now

**Decision:** Clients send `Config.VERSION` inside the existing `register_player` RPC. Servers hard-reject mismatched versions with a readable message and close the client's session.

**Why:** RPC checksums already break mismatched clients silently with a confusing error. An explicit version check produces a readable "update your client" message and futureproofs for signature-compatible protocol changes. During the prototype phase, forced updates are acceptable — buddies pull the latest before playing.

**Alternatives considered:**

- Silent compatibility shims. Rejected — the project is too early; shims accumulate faster than they can be removed.
- Version negotiation / feature flags. Rejected — no known cases where diverged versions could safely coexist.

**Consequence:** Every release increments `Config.VERSION`. The deploy pipeline must update `Config.VERSION` in both the built client artifact and the server binary in lockstep.

---

## 2026-09-07 — Online / Offline main menu; players never see an address

**Decision:** Main menu shows **Online** and **Offline**. Online offers three things: **Online queue** (public matchmaking, port chosen from the selected mode), **Host lobby** (claims a private slot, returns a code), and **Join lobby** (enter a code). Offline is the local-sparring flow. No address or port is shown anywhere in the UI. `address` remains in the scene as a hidden `LineEdit` — a value holder for tests and the `--join=` command line, parented so the scene frees it.

**Why:** Buddies should click Online → Online queue → play. Nobody should have to know or type `play.leafmods.com`. Codes cover the "I want to play with these specific people" case without exposing a host address, and without needing anyone to port-forward.

**Alternatives considered:**

- Auto-connect to the DO server on launch. Rejected — inflexible; blocks LAN play.
- Keeping a visible Join-by-address field. Rejected — the user explicitly does not want the URL surfaced. LAN and local testing still work via `--join=`.
- Server browser / lobby discovery. Deferred — over-engineered for a small crew.

**Consequence:** The server's own status line names its port, so `broadcast_lobby()` deliberately sends `""` instead of `status` to dedicated clients; the client composes its own lobby text. Changing that back would leak the port into the client UI.

---

## 2026-09-07 — README/CLAUDE consolidation via symlink

**Decision:** `CLAUDE.md` is a symlink to `README.md`. Any tool that auto-loads either filename gets the same content.

**Why:** Multiple AI tools (Claude Code, Cursor, and generic README readers) look at different filenames by convention. A symlink puts them all on the same file with zero duplication.

**Consequence:** Windows checkouts with symlinks disabled need `git config core.symlinks true`. Called out at the top of the README.

---

## Prior (undated) — No click-to-target on character models

**Decision:** Character models, overhead nameplates, damage labels, and the ground are never clickable target-select surfaces. Target selection is Tab (enemies), F1–F3 (self / teammates), or clickable UI frames only.

**Why:** A specific bug: both mouse buttons enabled forward run, mouse capture recentered the cursor over the player's own character, and the next click selected self. Removing model raycast picking is the root fix. In the process it became a product principle — explicit targeting via keys and frames is more predictable than click-selection and matches the WoW controls identity.

**Alternatives considered:**

- Restrict model picking to enemies only. Rejected — the recentered-cursor bug still affects nearby enemies during camera capture.
- Add a "click delay" to reject clicks near the capture point. Rejected — additive complexity for a rule that's clearer expressed as "no model picking."

**Consequence:** Do not add hidden click-to-select behavior to models, nameplates, damage labels, or the world. Combat line-of-sight raycasts remain (unrelated to input targeting).

---

## Prior (undated) — Authoritative server, no client movement authority

**Decision:** The host process is authoritative for combat, physics, bot decisions, HP, cooldowns, casting, crowd control, and match results. Clients submit normalized movement intent and ability requests; they never claim desired HP or position.

**Why:** Prevents common multiplayer cheats and keeps state consistent across clients. Authority centralization also keeps combat rules simple to reason about.

**Consequence:** Clients feel input-to-motion delay at high latency because they render server state without prediction. Client movement prediction / reconciliation is a real problem past ~80 ms RTT — deferred until playtesting justifies it. **Do not make HP or combat client-authoritative to hide lag.** Fix it with prediction, not authority splitting.

---

## Prior (undated) — DEFLATE for snapshot compression, not FASTLZ

**Decision:** Periodic snapshots are `var_to_bytes()`-encoded and compressed with `FileAccess.COMPRESSION_DEFLATE`. Receive path uses matching dynamic decompression capped at 65536 bytes.

**Why:** An earlier attempt used FASTLZ with `decompress_dynamic()`, which Godot 4 does not support. Snapshots failed to decompress. DEFLATE is supported for dynamic decompression and is a strict improvement over uncompressed (which exceeded ENet's MTU on six-fighter dictionaries and generated fragmentation/loss warnings).

**Consequence:** Do not pair FASTLZ with dynamic decompression. If snapshot content expands materially, verify compressed payload size stays under ENet's unreliable MTU.

---

## Prior (undated) — `server_relay = false`

**Decision:** `SceneMultiplayer.server_relay` is disabled before the ENet peer is assigned.

**Why:** With relay enabled, multiple simultaneous client disconnects produced engine errors about routing to dead peers. Disabling relay ensures clients talk only to the host — no peer-to-peer traffic — and eliminated the observed errors.

**Consequence:** Do not casually re-enable `server_relay` without retesting simultaneous-disconnect scenarios.

---

## Prior (undated) — Placeholder art, defer aesthetics

**Decision:** All models, effects, and audio are code-generated placeholders. No external assets. No animation tree. No audio.

**Why:** Aesthetics are a downstream tuning problem. Core mechanics and multiplayer feel need to be validated first. Building an art pipeline before knowing what the game feels like risks a lot of asset rework.

**Consequence:** Do not import external assets. Do not begin an animation system. When core feel is accepted, art can be layered in incrementally.

---

## Prior (undated) — Shared balance constants duplicated in code and prose

**Decision:** Numbers like 60 % ward mitigation, 1.5 s GCD, 65 % sprint boost, and the healing dampening curve are hard-coded in simulation (`scripts/arena.gd`) **and** repeated in expanded tooltip prose (`scripts/kits.gd`). Two sources.

**Why:** The tooltip needs to explain values to players. Building a shared constants module was deferred because numbers were stable enough that the duplication cost was lower than the abstraction cost.

**Alternative considered:** Centralize into a `scripts/balance.gd`. Currently deferred — flagged in [`ROADMAP.md`](ROADMAP.md) as the correct move once balance stabilizes.

**Consequence:** **When changing a balance value, change both places.** Divergence between code and tooltip is a real risk.
