# Context — where Starfall is right now

_Short-term memory. Keep concise. Historical decisions live in [`DECISIONS.md`](DECISIONS.md); long-range plan lives in [`ROADMAP.md`](ROADMAP.md)._

Last updated: **2026-09-08**.

Next character handoff: the owner requested this workflow be logged before asking for another class. Read [`CHARACTER_PIPELINE.md`](CHARACTER_PIPELINE.md) first: it preserves the references, exact files, local tool paths, rig/clip settings, build commands, verified results, implementation lessons and outstanding quality issues.

Latest Ember work (2026-09-08): the owner rejected the faceted model and rigid movement and requested a Blender-authored character based on the supplied hooded celestial mage reference. `art_source/ember.blend` and `assets/characters/ember.glb` now provide a smooth skinned model with 52 bones and seven clips, integrated through `scripts/ember_art.gd`. The old Ember construction branch is removed. `scenes/ember_preview.tscn` is an interactive animation viewer. See the Ember section in `ART_DIRECTION.md` for workflow and remaining visual limitations.

Latest Vanguard (2026-09-08): the owner rejected the exposed-face/head-down-carry attempt and explicitly requested a helmet. The new live Blender Vanguard has a closed visor helmet, head-up two-handed guard, calmer forged armor/crystals, 39 bones and eight clips. `scripts/vanguard_authored.gd` integrates it; Ember and gameplay are unchanged. Old studies and the procedural fallback are recoverable in ignored local `artifacts/archive/` ZIPs. Current source, commands, validation and remaining visual limits: [`VANGUARD_REBUILD_BRIEF.md`](VANGUARD_REBUILD_BRIEF.md). Appearance is **not owner-approved**. The 90% usage stop rule remains active. Arena handoff: `ART_SLICE_HANDOFF.md`.

## Class identity implementation — 2026-09-08

Owner authorized the four class concepts with baseline mobility, Mend/sustain, and damage reduction retained. Each class now has twelve abilities on 1–7 / Shift+1–5; every ability has an icon. Full current rules: [`CLASS_ABILITIES.md`](CLASS_ABILITIES.md). `class_mechanics.gd` implements resources, stars, ally interception, gravity fields and exchanges; `Combatant.identity` is replicated. Protocol version is 0.6.0, requiring matching client/server builds. No deployment was performed. Human balance testing remains next. Validation: class mechanics 89/89, baseline combat 81/81, world 13/13, rendered art 131/131, UI 192/192; real ENet team/latency test (including second-bar input and resource snapshots) and six-peer match passed. New art totals about 1.2MiB; eight generated icons plus reused existing art cover all 48 slots.

## Current milestone

**Playable prototype with dedicated-server mode landed.** The game runs in two modes: **Offline** (local sparring vs bots) and **Online** (join a dedicated server or a player-hosted lobby). The pipeline that would actually deploy that server to DigitalOcean does not exist yet.

## Objective

Close the "push to `main` → buddies play the new build" loop:

1. GitHub Actions builds Linux/Windows/Mac exports on push to `main` and publishes a GitHub Release tagged with `Config.VERSION`.
2. A DigitalOcean droplet runs the Linux server binary under `systemd`; Actions SSH-deploys and restarts the service.
3. A small client-side launcher (bash + `.bat`) checks GitHub Releases on startup, downloads the new build when `Config.VERSION` differs, and launches Godot.

Until all three exist, buddies play by manually launching Godot from a checkout.

## Recently completed (this batch)

- **Sanctum lighting and landscape:** shared live/baked lighting profile, lower ambient/fill, warm shrine lighting and a new indirect bake; large exterior cliffs, hanging foundations, broken approaches, distant sanctuaries and subtle non-volumetric mist. Landscape6batches/19,116triangles, no colliders/shadow passes. Map57/57, combat81/81, world13/13. Assets remain just under8MiB. Current complete handoff: `ART_SLICE_HANDOFF.md`.

- **Authored Sanctum arena:** expanded the approved section to all four covers, the full floor, all boundary walls and both terraces/ramps, using shared Blender-authored meshes, UV-based PBR materials and native baked lighting in Compatibility. No new collision. Runtime environment budget approximately7.94MiB including meshes and lightmap; map57/57, combat81/81. Rebuild and continuation notes: `ART_SLICE_HANDOFF.md`. Actual render: `artifacts/sanctum-slice.png`. Cosmic backdrop, portals and atmospheric decor retain the previous procedural pass.

- **Cosmic Sanctum richness pass:** distinct basalt, worn floor, blue terrace tile and bronze materials; triplanar derivative relief; true emissive glyphs; animated banners, embers and floating debris; two distant watcher shrines; depth fog and a cached sky with a cheap motion layer. Visible cover now matches its existing collision width. No new textures or colliders. Map 57/57 and combat 65/65; visual review in `artifacts/sanctum-*.png`. Details in `ART_DIRECTION.md`.

- **Roster art pass:** 20 painted ability icons cover all three seven-slot kits; original in-engine Ember, Vanguard and Luminary models replace capsules, with procedural movement/cast/hit/defeat poses. Owner explicitly authorized this art work. See `ART_DIRECTION.md`; review boards regenerate with `tools/art_review.gd`.

- **Theme established — Cosmic Gladiators.** Space + fantasy: summoned fighters from different worlds, an ancient arena floating in space, celestial temples, nebulae, gods watching; deep purples/blues with extremely bright magical accents. Set by the user, now canon in [`ART_DIRECTION.md`](ART_DIRECTION.md) and [`DECISIONS.md`](DECISIONS.md). The owner subsequently authorized ability icons and player models; see the roster art pass above.
- **Documentation reorganized** into `docs/` as persistent shared memory for AI agents. Main README rewritten as a short operating manual.
- **Dedicated server mode** — `--dedicated --mode=team --min-players=2 --rematch-delay=8`. No local player, auto-start when threshold met, auto-rematch after each round, holds in lobby when roster drops below threshold.
- **Version handshake** in `register_player` — hard reject on mismatch.
- **Buffs and debuffs** — `scripts/auras.gd` derives every effect from the timers the simulation already keeps, shown as hoverable chips on unit frames and on overhead nameplates.
- **Edit HUD** — drag frames, rebind hotbar keys, swap ability positions. Client-side only; bar positions translate to kit indices before reaching the simulation.
- **Display settings** — window mode and resolution, persisted to `user://starfall.cfg` with the HUD layout and keybinds.
- **Fulcrum**, a fourth champion — mid-range control, signature ability `Tether` pulls an enemy *or* an ally 8 m toward the caster. Six of seven slots reuse existing ability kinds; only `pull` is new. Needs icons and a champion model — both degrade to fallbacks, neither breaks. `Config.VERSION` is now **0.3.0**.
- **Cosmic sanctum map** (parallel agent session) — new arena geometry, layout, sky shaders and environment texture, with `tests/map_test.gd`, 57 checks. Bot pathing and line of sight verified intact against it.
- **Queue fix** — a dedicated server now accepts players who connect mid-round and holds them for the next one. Previously the queue only worked in the idle seconds between matches; private lobbies were unaffected, which is why they worked while the queue looked broken. `Config.VERSION` is now **0.2.0** (the `lobby_state` RPC gained a field), so every client must be re-downloaded.
- **Ability icons and champion models** (parallel agent session) — generated icons for all twenty abilities, wired into the hotbar behind the cooldown overlay, plus built champion models replacing the primitive placeholder bodies. Carries `tests/ability_art_test.gd`, 84 checks.
- **Icon assets downscaled 1254px -> 256px before the first push**, 44 MB to 2.4 MB. They display at 92 px; git keeps blobs forever. See the asset budget in [`ART_DIRECTION.md`](ART_DIRECTION.md).
- **HUD pass** — WoW-style radial cooldown sweeps with OmniCC-style countdowns on the hotbar, single-hover ability tooltips (the Shift-expanded variant is gone), and a cast bar under the overhead nameplate. No art needed for any of it; the overlay works unchanged once icons land.
- **Online menu rewritten** — Online now offers **Online queue**, **Host lobby**, and **Join lobby**. No server address or port appears anywhere in the UI.
- **Online queue** — picks the port from the selected mode (duel 27840 / team 27841), shows "Searching for an opponent…" with an `n of m players ready` count, and drops into the round when the server auto-starts.
- **Private lobbies** — a fixed pool of `--dedicated --lobby` processes on 27850–27853. Host lobby claims the first idle slot and returns a 4-character code; Join lobby probes the pool for that code. No broker process. Reasoning and rejected alternatives in [`DECISIONS.md`](DECISIONS.md).
- **Server is now six containers** from one image — `docker-compose.yml`, deployed by GitHub Actions to GHCR and then over SSH. See [`../DEPLOYMENT.md`](../DEPLOYMENT.md).
- New `scripts/config.gd` centralizes deploy-time constants. `SERVER_ADDRESS` points at `play.leafmods.com`.
- **Docker deployment** — `Dockerfile` (pinned Godot, pre-built import cache, non-root, read-only rootfs), `docker-compose.yml`, `.env.example`, `.github/workflows/deploy.yml`, `deploy/bootstrap.sh` + `install-docker-rocky.sh` + `create-deploy-user.sh`, and [`../DEPLOYMENT.md`](../DEPLOYMENT.md). The old systemd model is archived in `deploy/legacy-systemd/`.
- New integration tests `tests/run_dedicated.py` (queue) and `tests/run_lobby.py` (private lobbies, including probing past a claimed slot).

## Known-good state

Roster art validation: combat 47/47, UI 73/73, art/model checks 84/84 (all three classes on both teams). Review boards: `artifacts/champion-lineup.png`, `champion-lineup-back.png`, `ability-atlas.png`. The UI suite requires a virtual screen large enough to reach the hotbar; see `ART_DIRECTION.md`.

All six suites pass as of this batch: `combat_test` 47/47, `ui_test` 64/64, `run_network`, `run_six`, `run_dedicated`, `run_lobby` all exit 0.

Watch for `ERROR:` in test output — `run_network.py`, `run_six.py`, `run_dedicated.py` and `run_lobby.py` all fail the run if the string appears. A `Control` created but never added to the scene tree leaks its font and canvas RIDs at exit and trips exactly this check; that is how the orphaned `address` field was caught.

## Repository hygiene

`artifacts/` is **no longer tracked**. It holds screenshots and review renders that every test run rewrites, so tracking them added multi-megabyte blobs to history for output that is regenerated on demand — `.git` reached 371 MB against a ~90 MB working tree. `artifacts/.gdignore` is kept so Godot does not import whatever lands there, and docs still reference the paths, since the review tools recreate them locally.

Untracking stops the growth but does not shrink existing history. Reclaiming that 371 MB would need a history rewrite (`git filter-repo`), which is disruptive with a shared remote and has deliberately not been done.

`tests/check_references.py` fails CI when a committed file references a resource that is not itself committed. Two agents in one repository will otherwise ship half a coupled change: a preload of a file, or a call to a method, whose other half is still local. It catches the file case; the method case is only caught by actually running the suites, so **verify the staged tree rather than the working tree** — `git archive $(git write-tree)` into a temp directory and run them there.

## Known blockers

None. **The pipeline is live**: push to `main` runs the suites, builds the image, pushes to GHCR and deploys six containers to the droplet, pinned to `sha-<commit>`. `play.leafmods.com` resolves to it.

Nobody has played a match against the droplet yet — the health gate only proves the ENet socket is bound, not that a client can reach it from outside. That is the next thing to verify.

Three traps hit during the first live deploys, all fixed, all worth knowing:

- A leftover `ringfall.service` from the pre-Docker model held UDP 27840, so `starfall-duel` could not bind. Never run both deployment models on one droplet.
- The GHCR package is created **private** on first push; the droplet cannot pull until it is made public or given a `read:packages` login.
- **Test scripts do not import assets.** A fresh checkout has no `.godot/imported/`, and `godot --script` will not build it — every `.ctex` fails to open and the Python harnesses fail on the `ERROR:` lines even though all assertions pass. CI now runs `--import` before the suites. This was invisible until the ability icons arrived, because the project previously had no assets at all.
- **A "healthy" container can be unreachable.** The container healthcheck runs inside the network namespace, where the server always binds its port; it cannot see a failed host-side publish. `starfall-duel` reported healthy for an hour with nothing listening on 27840, because the old systemd service held that port when the container was first created. `starfall-deploy` now fails the deploy if any container has no published ports. Symptom to recognise: `ss -ulnp | grep 278` shows fewer than six listeners while `docker ps` shows six healthy.
- `docker/metadata-action` sets `outputs.version` from the **highest-priority** tag, and `type=raw` outranks `type=sha` by default — so deploys pinned the mutable `latest` until explicit priorities were set. Waiting on droplet provisioning (user is spinning it up) before running the first manual deploy. Nothing in the lobby/queue work has been exercised against a real droplet yet — only against local processes.

## Immediate next steps (in order)

1. **Droplet provisioning** — user creates the Rocky 9 droplet, adds `A` record for `play.leafmods.com`, runs `deploy/bootstrap.sh`, adds the four GitHub secrets, pushes to `main`. Runbook in [`../DEPLOYMENT.md`](../DEPLOYMENT.md).
2. **Verify buddies can connect** — Online queue into a match, and a shared code into a private lobby, from their own machines.
3. **First real CI run** — the workflow is written and locally validated but has never executed against a droplet. Secrets and host-key pinning are the likely first failures.
4. **Client-side launcher** with forced-update-on-mismatch behavior.
5. Once the loop closes, real playtesting. Feel-tuning follows.

## Queued next

**Client distribution is the open gap.** The server auto-deploys on every merge to `main`; buddies do not. They run from a checkout or a ZIP of the repo, so after each push someone has to tell them to re-download. `Config.VERSION` is still `0.1.0` and nothing bumps it, so a stale client is accepted and can desync instead of being cleanly rejected. Closing this is roadmap item 3: CI exports Windows/Linux builds to GitHub Releases plus a small self-updating launcher.

## Explicitly not in progress

- Client movement prediction / reconciliation (still real past ~80 ms RTT, deferred until buddies can actually play regularly).
- Extracting subsystems from `scripts/arena.gd` (1524 lines).
- Audio and a full skeletal animation pipeline.
- Authentication, host migration, anti-cheat, ranked/skill-based matchmaking.

## Movement and keybinds — work in progress

Immediate local movement prediction and shared collision movement are implemented in `movement_prediction.gd` / `arena.gd`, with authoritative reconciliation, movement acknowledgments and displacement revisions. Version 0.7.0. Settings → Keybinds adds search, primary/secondary bindings, movement/targeting/bar rows, persistence and conflict swapping shared with Edit HUD. Locomotion start/stop/direction animation blending is removed. Baseline combat 81/81, movement/keybind checks 23/23, existing UI 192/192, team/latency network passed before final polish. A new 150ms movement-direction test initially used world axes for a reversed-facing client; corrected to local axes, but its rerun was blocked by automatic approval review reporting workspace credits exhausted. Final rendered header/search polish and that network retest remain pending. Do not claim final movement validation complete.

## Unique icons — 2026-09-08

Seventeen generated replacements remove every icon collision between distinct active abilities. 45 distinct abilities / 48 slots; only the same Mend ability shares art across classes. File/content audit passes, all new PNGs are 256px, both full and 55px contact sheets inspected. `UNIQUE_PROMPTS.md` records prompts and output files. Godot import/render remains pending under the approval-credit block; no deployment performed.
