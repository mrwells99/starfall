# Context — where Ringfall is right now

_Short-term memory. Keep concise. Historical decisions live in [`DECISIONS.md`](DECISIONS.md); long-range plan lives in [`ROADMAP.md`](ROADMAP.md)._

Last updated: **2026-09-07**.

## Current milestone

**Playable prototype with dedicated-server mode landed.** The game runs in two modes: **Offline** (local sparring vs bots) and **Online** (join a dedicated server or a player-hosted lobby). The pipeline that would actually deploy that server to DigitalOcean does not exist yet.

## Objective

Close the "push to `main` → buddies play the new build" loop:

1. GitHub Actions builds Linux/Windows/Mac exports on push to `main` and publishes a GitHub Release tagged with `Config.VERSION`.
2. A DigitalOcean droplet runs the Linux server binary under `systemd`; Actions SSH-deploys and restarts the service.
3. A small client-side launcher (bash + `.bat`) checks GitHub Releases on startup, downloads the new build when `Config.VERSION` differs, and launches Godot.

Until all three exist, buddies play by manually launching Godot from a checkout.

## Recently completed (this batch)

- **Documentation reorganized** into `docs/` as persistent shared memory for AI agents. Main README rewritten as a short operating manual.
- **Dedicated server mode** — `--dedicated --mode=team --min-players=2 --rematch-delay=8`. No local player, auto-start when threshold met, auto-rematch after each round, holds in lobby when roster drops below threshold.
- **Version handshake** in `register_player` — hard reject on mismatch.
- **Online menu rewritten** — Online now offers **Online queue**, **Host lobby**, and **Join lobby**. No server address or port appears anywhere in the UI.
- **Online queue** — picks the port from the selected mode (duel 27840 / team 27841), shows "Searching for an opponent…" with an `n of m players ready` count, and drops into the round when the server auto-starts.
- **Private lobbies** — a fixed pool of `--dedicated --lobby` processes on 27850–27853. Host lobby claims the first idle slot and returns a 4-character code; Join lobby probes the pool for that code. No broker process. Reasoning and rejected alternatives in [`DECISIONS.md`](DECISIONS.md).
- **Server is now six processes** — templated `ringfall@<instance>` systemd unit driven by one env file per instance in `deploy/instances/`.
- New `scripts/config.gd` centralizes deploy-time constants. `SERVER_ADDRESS` points at `play.leafmods.com`.
- **Deploy scripts and runbook** — `deploy/setup.sh`, `deploy/ringfall@.service`, `deploy/instances/*.env`, `deploy/deploy.sh`, and [`DEPLOY.md`](DEPLOY.md).
- New integration tests `tests/run_dedicated.py` (queue) and `tests/run_lobby.py` (private lobbies, including probing past a claimed slot).

## Known-good state

All six suites pass as of this batch: `combat_test` 47/47, `ui_test` 64/64, `run_network`, `run_six`, `run_dedicated`, `run_lobby` all exit 0.

Watch for `ERROR:` in test output — `run_network.py`, `run_six.py`, `run_dedicated.py` and `run_lobby.py` all fail the run if the string appears. A `Control` created but never added to the scene tree leaks its font and canvas RIDs at exit and trips exactly this check; that is how the orphaned `address` field was caught.

## Known blockers

None coded. Waiting on droplet provisioning (user is spinning it up) before running the first manual deploy. Nothing in the lobby/queue work has been exercised against a real droplet yet — only against local processes.

## Immediate next steps (in order)

1. **Droplet provisioning** — user creates the DO droplet, adds `A` record for `play.leafmods.com`, runs `deploy/setup.sh` on the droplet, runs `deploy/deploy.sh` from dev machine. Runbook in [`DEPLOY.md`](DEPLOY.md).
2. **Verify buddies can connect** — Online queue into a match, and a shared code into a private lobby, from their own machines.
3. **GitHub Actions workflow** — build + publish on push to `main`, run the equivalent of `deploy/deploy.sh` in CI.
4. **Client-side launcher** with forced-update-on-mismatch behavior.
5. Once the loop closes, real playtesting. Feel-tuning follows.

## Queued next (requested, not started)

HUD work, in the user's stated order:

1. WoW-style radial sweep for the global cooldown on the hotbar.
2. Radial sweep plus a countdown number for per-ability cooldowns.
3. Streamline ability tooltips — fold cast/range/cooldown into the plain hover and delete the Shift-expanded variant entirely (`Kits.description()` loses its `expanded` parameter; `tests/ui_test.gd` has five assertions built on Shift that need rewriting, not deleting).
4. A cast bar under the overhead nameplate, in addition to the one in the unit frames.

Note for whoever picks these up: the hotbar refreshes on state change, not per frame. A sweep that animates smoothly needs the overlay to run its own `_process` timer and take a correction from each server snapshot.

## Explicitly not in progress

- Client movement prediction / reconciliation (still real past ~80 ms RTT, deferred until buddies can actually play regularly).
- Extracting subsystems from `scripts/arena.gd` (1524 lines).
- Assets, animation, audio.
- Authentication, host migration, anti-cheat, ranked/skill-based matchmaking.
