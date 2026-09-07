# Deploy — Starfall dedicated server on DigitalOcean

> **Superseded for production.** Starfall now deploys as Docker containers via
> GitHub Actions — see [`../DEPLOYMENT.md`](../DEPLOYMENT.md). This runbook
> describes the older source-on-droplet + systemd model, whose scripts are
> archived in [`../deploy/legacy-systemd/`](../deploy/legacy-systemd/).
> It is kept because it still works as a registry-free fallback, and because the
> droplet facts below — DNS, firewall ports, SELinux, version bumps — remain
> accurate under Docker.
>
> **Never run both models on one droplet:** they bind the same UDP ports.

_Runbook for provisioning and updating the shared dedicated server. Source-on-droplet for MVP (no build step) — GitHub Actions automation lands next, per [`ROADMAP.md`](ROADMAP.md)._

**Deploy target:** `play.leafmods.com` (see [`DECISIONS.md`](DECISIONS.md) for the domain choice).

Repo files that make this work:

- [`deploy/legacy-systemd/setup.sh`](../deploy/legacy-systemd/setup.sh) — one-shot droplet bootstrap.
- [`deploy/starfall@.service`](../deploy/legacy-systemd/starfall@.service) — templated systemd unit installed by `setup.sh`. One instance per env file.
- [`deploy/instances/`](../deploy/legacy-systemd/instances) — one `<name>.env` per server process, each setting `STARFALL_ARGS`. Installed to `/etc/starfall/`.
- [`deploy/deploy.sh`](../deploy/legacy-systemd/deploy.sh) — repeatable manual deploy from your dev machine.

## Prerequisites

- DigitalOcean account with an SSH key uploaded.
- DNS access to `leafmods.com` (any registrar / provider is fine).
- Local `ssh` and `rsync` (built in on Linux/macOS; on Windows use WSL or Git Bash).

## 1. Provision the droplet

Suggested spec — small is fine for 6 humans:

- **Ubuntu 24.04 LTS** or **Rocky Linux 9** (both supported by `deploy/legacy-systemd/setup.sh`).
- Basic / regular Intel, **1 GB RAM / 1 vCPU** ($6/mo). Bump to 2 GB if snapshots start dropping under load; unlikely at this scale.
- Region: pick whichever is nearest most buddies.
- Enable IPv6 (free, and lets you add an `AAAA` record later without reprovisioning).
- Add your SSH key.

Note the droplet's public IPv4 address once it's up.

`setup.sh` detects the distro from `/etc/os-release` and picks the right package manager (`apt`/`dnf`) and firewall tool (`ufw`/`firewalld`). On Rocky/RHEL, SELinux is Enforcing by default — if an instance fails to start, run `sudo ausearch -m avc -ts recent` to check for SELinux denials before assuming a code issue.

## 2. DNS

Add an `A` record for `play.leafmods.com` pointing at the droplet's IPv4. TTL 300–3600 is fine.

Optional: `AAAA` for the droplet's IPv6 (dual-stack). Not required — the client currently opens IPv4 to whatever `Config.SERVER_ADDRESS` resolves to.

Verify with `dig +short play.leafmods.com` — you should see the droplet IP.

## 3. Bootstrap the droplet

From your dev machine:

```sh
# Ship just the deploy folder to a temp path:
scp -r deploy/legacy-systemd/ root@play.leafmods.com:/tmp/starfall-deploy/

# Review then run:
ssh root@play.leafmods.com 'less /tmp/starfall-deploy/setup.sh'   # optional
ssh root@play.leafmods.com 'bash /tmp/starfall-deploy/setup.sh'
```

`setup.sh` does:

- Installs `unzip`, `rsync`, `ufw`, `wget`, `ca-certificates`.
- Opens `22/tcp` plus `27840/udp`, `27841/udp` and `27850-27853/udp` in `ufw`, enables the firewall.
- Creates a `starfall` system user (no login shell, home = `/opt/starfall`).
- Downloads Godot 4.5.1 stable from the official GitHub release, installs to `/usr/local/bin/godot`.
- Installs `starfall@.service` under `/etc/systemd/system/`, copies `deploy/legacy-systemd/instances/*.env` to `/etc/starfall/`, and `systemctl enable`s one instance per env file.

Idempotent — safe to re-run when upgrading Godot or re-provisioning.

## 4. First deploy

Still from your dev machine, in the project root:

```sh
./deploy/legacy-systemd/deploy.sh
```

This `rsync`s the repo into `/opt/starfall` (excluding `.git`, `.godot`, `artifacts`, and this script itself), reinstalls the unit template and every env file, then **stops all instances, rebuilds `.godot/`, and starts them again**, finally tailing recent logs.

The stop-warm-start dance is deliberate: six Godot processes racing to create the import cache on a cold checkout corrupt it. One warm-up run with `--quit` builds it while nothing else is running.

Expected output near the end:

```
DEDICATED READY 0.1.0 port=27841 mode=3 min_players=2 rematch_delay=8.0 private=false
```

## 5. Verify

From your dev machine:

```sh
# Watch live logs:
ssh root@play.leafmods.com "journalctl -u 'starfall@*' -f"

# Status:
ssh root@play.leafmods.com "systemctl status 'starfall@*'"

# Manual client join test — from a checkout on your dev machine.
# --join= targets the duel queue port and bypasses the menu:
godot --path . -- --join=play.leafmods.com --champion=Ember
# ...then launch another client the same way. Round should auto-start.
```

You should see six listeners on the droplet:

```sh
ssh root@play.leafmods.com 'ss -ulnp | grep 278'
```

Then verify the three player-facing paths from the game itself:

| Path | Expected |
| --- | --- |
| Online → Online queue (Duel) | "Searching for an opponent…", then a round once a second player queues. |
| Online → Host lobby | A 4-character code appears. `LOBBY CLAIMED` in the instance log. |
| Online → Join lobby, enter that code | Both players land in the same round. |

No address or port should be visible anywhere in the UI during any of this.

## 6. Deploy loop

For every subsequent push to `main`:

```sh
./deploy/legacy-systemd/deploy.sh
```

Once GitHub Actions is set up (next roadmap item), this runs in CI on every push. Until then, this is your one-liner.

## Log inspection

```sh
# Live tail:
journalctl -u 'starfall@*' -f

# Last hour:
journalctl -u 'starfall@*' --since '1 hour ago'

# Around a specific event, e.g. a crash:
journalctl -u 'starfall@*' --since '10 min ago' --no-pager

# Filter for dedicated-mode lines:
journalctl -u 'starfall@*' | grep DEDICATED
```

`DEDICATED READY|ROUND START|ROUND END|REMATCH|WAITING` lines mark all state transitions — see [`TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md).

## Version bumps

The server hard-rejects clients whose `Config.VERSION` doesn't match. When you change `Config.VERSION`:

1. Deploy the server (`./deploy/legacy-systemd/deploy.sh`) so it's on the new version.
2. Buddies pull latest and re-launch. (Once the client launcher exists, this becomes automatic.)

Mismatched clients will get: `Version mismatch — server is vX, your client is vY. Update to play.`

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `ExecStart failed` in `systemctl status` | `journalctl -u starfall@<instance> -n 100`. Most often: a missing or corrupt `.godot/` import cache — re-run `deploy.sh`, which rebuilds it with every instance stopped. |
| One instance dead, others fine | Its port is taken, or its env file is malformed. `systemctl cat starfall@<instance>` shows the resolved `STARFALL_ARGS`. |
| Clients get "Version mismatch" | `Config.VERSION` in the server's `scripts/config.gd` doesn't match the client's. Redeploy the server. |
| Client "Could not connect" | DNS pointing at the right IP? Are **all six** UDP ports open in `ufw` on the droplet AND in any DO/cloud firewall you attached? Check with `ss -ulnp | grep 278` on the droplet — you should see six listeners. |
| Queue works but lobby codes never resolve | The lobby pool ports (27850–27853) are open on the droplet but blocked in the cloud firewall, or `Config.LOBBY_PORTS` has drifted from `deploy/instances/`. Both lists must match. |
| Server binds but no clients see it | Confirm the process is actually the Starfall dedicated instance: `ps aux | grep godot`, then compare its command line to the systemd unit. |
| Godot version wrong | Re-run `setup.sh` — it re-checks and re-installs. Or override `GODOT_VERSION` / `GODOT_URL` env vars. |
| Deploy fails on `systemctl restart` | You're SSHing as a non-root user without passwordless sudo. Deploy script currently assumes `root@` — either SSH as root or add sudoers rule. |
| "All lobbies are in use" with nobody playing | A crashed client still holds a slot until ENet times its peer out. `systemctl restart starfall@lobby<N>` frees it immediately. |

## What's not automated yet

- **GitHub Actions on push to `main`** — next roadmap item. Will run the equivalent of `deploy.sh` from CI using a stored SSH key.
- **Client-side auto-updater** — after Actions, a small launcher checks GitHub Releases and forces client updates.
- **Backups / snapshots** — the server holds no persistent state (matches are ephemeral). Nothing to back up currently. If we add persistent identities / stats later, revisit.
