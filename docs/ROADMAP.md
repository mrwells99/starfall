# Roadmap — development priorities

_Practical, current, and small. This is not a speculative feature list — new items need a real motivation. Last updated 2026-09-07._

## Current milestone

**Close the "push to `main` → buddies play the new build" loop.** Dedicated server mode is done; the DevOps pipeline is not.

## In progress

**Droplet provisioning.** Deploy scripts + runbook are in the repo (`deploy/`, [`DEPLOY.md`](DEPLOY.md)). Server target: `play.leafmods.com`. Waiting on the DO droplet + DNS setup before the first manual deploy.

The server is now **six processes**, not one: a duel queue (27840), a 3v3 queue (27841), and a four-slot private lobby pool (27850–27853). `deploy/setup.sh` opens all six ports and enables one templated `ringfall@<instance>` unit per env file in `deploy/instances/`.

## Next up — in order

### 1. DigitalOcean droplet + first manual deploy — **in progress**

Pool sizing is a guess: four private lobby slots for a small crew. If they fill in practice, add ports to `Config.LOBBY_PORTS` **and** matching env files in `deploy/instances/` — the two lists must stay in step.

- User provisions a $6/mo Ubuntu 24.04 droplet.
- `A` record `play.leafmods.com` → droplet IP.
- Run `deploy/setup.sh` on the droplet (installs Godot 4.5.1, creates the `ringfall` user, opens UDP 27840/27841 and 27850–27853, installs `ringfall@.service` plus one env file per instance).
- Run `deploy/deploy.sh` from a dev machine to sync source, warm the import cache, and start all six instances.
- Buddies verify Online → Online queue drops them into a match, and that Host lobby / Join lobby work with a shared code. No address is typed at any point.

Runbook: [`DEPLOY.md`](DEPLOY.md).

### 2. GitHub Actions on push to `main`

- Run the equivalent of `deploy/deploy.sh` in CI using a stored SSH key + known-hosts entry.
- Bump `Config.VERSION` per release (or auto-bump from commit SHA / date).
- No client build required for this step — source-on-droplet stays the model for now.

### 3. Client-side launcher

- Bash script for Linux / Mac, `.bat` for Windows.
- On startup: hit `https://api.github.com/repos/<owner>/<repo>/releases/latest`, compare tag to a local `installed_version` file, download and extract if different, launch Godot.
- Fail modes: API unreachable → try to launch installed version; download fails → keep previous installed version.
- This is the step that makes exports worthwhile — the launcher ships a built Godot game, not source.

**When these three land, the loop closes.** A buddy runs the launcher, it fetches latest, connects to the server, plays with the freshest code.

## After the deploy loop closes

Ordered roughly by user-facing value, not by ease.

### Client movement prediction / reconciliation

Current server interpolation adds noticeable delay. Past ~80 ms RTT, control feel degrades. Keep server validation for HP and combat; add local movement prediction with server-authoritative correction. **Do not make HP or combat client-authoritative** — see [`DECISIONS.md`](DECISIONS.md).

### Extract subsystems from `arena.gd`

`scripts/arena.gd` is ~1,300 lines and growing. Real subsystem boundaries: input / camera, GUI, network session, bot decision-making, combat simulation, dedicated-server orchestration. Extract in reviewable steps with tests preserved. Do not do this in the same commit as behavior changes.

### Data-driven shared balance constants

Values like 60 % ward mitigation, 1.5 s GCD, 65 % sprint boost, healing dampening curve, charge stopping/damage radii are duplicated between simulation and tooltip prose. Centralize into `scripts/balance.gd` and reference from both. See [`DECISIONS.md`](DECISIONS.md) for the current tradeoff.

### Better team feedback

Status icons, target-of-target, combat log, death / spectator UI, clearer focus / selected frame treatment. Resource bars **if** resources are eventually added.

### Better bots

Coordinate interrupts, avoid wasted DR, kite without the ability-decision tick overriding retreat, switch pressure targets, choose useful healer positions. Current bots are training-quality only.

### Human control feel testing

Tune camera distance / pitch, movement / turn speed, jump, keybinds, and hotbar ergonomics with the user. Preserve the no-model-targeting rule from [`DECISIONS.md`](DECISIONS.md).

### Assets, animation, audio

Replace primitive models and beam cues incrementally after core feel is accepted. No existing asset pipeline to preserve — greenfield.

## Not on the roadmap

_These would need new reasoning to promote. Currently deferred or rejected:_

- **Ranked ladder, skill-based matchmaking** — the queue is first-come-first-served into a single process per mode. Deferred until casual play works.
- **Host migration** — dedicated server replaces the case that would need it.
- **Anti-cheat / authentication** — deferred; version handshake is the current defense.
- **Server browser / lobby discovery** — over-engineered for a small crew. Private lobbies use a shared code instead.
- **Multiple rooms inside one server process** — each process still runs exactly one lobby and one mode. Concurrency comes from running more processes (the private-lobby pool). Partitioning `arena.gd` into rooms is a core rewrite; see [`DECISIONS.md`](DECISIONS.md). Revisit only after that file is decomposed.
- **Resurrection or respawn during a round** — open design question, not planned.
