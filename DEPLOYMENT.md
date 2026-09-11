# Deployment — Starfall on Docker

Production deployment for the Starfall dedicated servers: GitHub Actions builds
and tests, pushes an image to GHCR, and restarts the stack on a Rocky Linux 9
droplet over SSH.

This supersedes the source-on-droplet + systemd model, which is archived in
[`deploy/legacy-systemd/`](deploy/legacy-systemd/). **Do not run both** — they
bind the same UDP ports.

---

## What gets deployed

Three containers start by default: two public matchmaking queues and the persistent world.
The four private-lobby containers are optional (`COMPOSE_PROFILES=private-lobbies` in `.env`).
When disabling an existing pool, run `docker compose stop lobby1 lobby2 lobby3 lobby4`
once; then normal deployments keep those services disabled. Private lobby codes require
the pool to be enabled.

| Container | UDP | Role |
| --- | --- | --- |
| `starfall-duel` | 27840 | Duel queue (1v1) |
| `starfall-team` | 27841 | Team queue (3v3) |
| `starfall-world` | 27842 | Persistent world |
| `starfall-lobby1..4` | 27850–27853 | Private lobbies, claimed by code |

These port numbers are **baked into the client** at build time
(`scripts/config.gd`). Changing one means changing it in `config.gd`,
`.env`, `docker-compose.yml` and the firewall — and shipping a new client.

### Build strategy, and why

The image bundles the pinned Godot binary, the project source, and a
**pre-built import cache**; it does not use Godot's export pipeline.

Desktop exports have their own presets and download storage. Runtime character models and textures are
imported during the image build; dedicated actors do not load their presentation
models at runtime. A stripped server export remains a possible image-size improvement.
Bundling gets the properties that matter in production: one immutable artifact,
no writes to the project tree at run time, no import-cache race between
processes, and a fast start.

A future dedicated export could also reduce image size by excluding client assets.
The Docker build excludes authoring inputs (`art_source`, `assets-source`, and
unused Godot/Unity/Unreal source libraries). Finished runtime assets remain.
Read-only permissions are applied in the builder, avoiding an extra runtime
layer containing a second copy of the project. Originals stay in the repository.

---

## Required GitHub secrets

Repository → Settings → Secrets and variables → Actions.

| Secret | Example | Purpose |
| --- | --- | --- |
| `DEPLOY_HOST` | `play.leafmods.com` | Droplet hostname the workflow SSHes to. |
| `DEPLOY_USER` | `deploy` | Unprivileged deploy account created by `deploy/create-deploy-user.sh`. |
| `DEPLOY_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----…` | Private half of the deploy key. Ed25519, **no passphrase** (CI cannot type one), used for nothing else. |
| `DEPLOY_SSH_KNOWN_HOSTS` | `play.leafmods.com ssh-ed25519 AAAA…` | Pinned host key. Without it the workflow would have to trust the server blindly on first contact. |

No registry secret is needed for **pushing** — the workflow uses the built-in
`GITHUB_TOKEN` with `packages: write`.

Generate the deploy key and host-key pin:

```bash
ssh-keygen -t ed25519 -N "" -C ci@starfall -f ./starfall_deploy
ssh-keyscan -t ed25519 play.leafmods.com
```

The public half (`starfall_deploy.pub`) goes to `create-deploy-user.sh`; the
private half becomes `DEPLOY_SSH_KEY`; the `ssh-keyscan` output becomes
`DEPLOY_SSH_KNOWN_HOSTS`. Delete the local private key afterwards.

### Protecting the production environment

The `deploy` job runs in a GitHub Environment named `production`. Add required
reviewers and restrict it to the `main` branch in repo settings — that, not the
workflow file, is what stops an arbitrary branch from reaching the droplet.

---

## Required server setup

Use Rocky Linux 9 with Docker Compose. Size the machine from measured active-match
load; the previous 1 vCPU / 1 GB deployment saturated its CPU. See [Sizing](#sizing).

```bash
# 1. Ship the deploy scripts
scp -r deploy/ root@<droplet>:/tmp/starfall-deploy/

# 2. Read it, then run it. Takes the CI deploy key's PUBLIC half.
ssh root@<droplet> 'less /tmp/starfall-deploy/bootstrap.sh'
ssh root@<droplet> 'bash /tmp/starfall-deploy/bootstrap.sh "ssh-ed25519 AAAA... ci@starfall"'
```

`bootstrap.sh` is idempotent and runs the other two scripts in order:

1. Base packages; `firewalld` enabled; UDP 27840–27841 and 27850–27853 opened.
2. [`install-docker-rocky.sh`](deploy/install-docker-rocky.sh) — Docker CE from
   Docker's own repo (removing the `podman-docker` shim), plus a daemon config
   that caps log size, enables `live-restore`, and disables the userland proxy.
3. [`create-deploy-user.sh`](deploy/create-deploy-user.sh) — the `deploy` user,
   its authorized key, and two root-owned wrapper scripts it may run via sudo.
4. `/opt/starfall` seeded with `.env` from `.env.example`.

Then, manually:

- **DNS** — `A` record for `play.leafmods.com` → droplet IPv4.
- **Review `/opt/starfall/.env`** — at minimum confirm `STARFALL_IMAGE` matches
  your GHCR path (`ghcr.io/<owner>/<repo>`).
- **If the GHCR package is private**, log the host in once so `docker compose
  pull` can authenticate:

  ```bash
  echo <PAT_with_read:packages> | sudo docker login ghcr.io -u <github-user> --password-stdin
  ```

  Making the package public instead removes this credential entirely; the image
  contains no secrets, only the game server. That is the recommended option.

---

## First deploy — order of operations

There is a chicken-and-egg here worth knowing before you push.

A GHCR package **does not exist until the first successful build**, and it is
created **private**. So a naive first push goes: tests pass, image builds and
pushes, deploy fails at `docker compose pull` with `unauthorized`. Nothing is
broken — the droplet just cannot read a private package it has no credentials
for.

Do these in order:

1. **Droplet exists**, Rocky Linux 9, with your SSH access working.
2. **Generate the deploy key**, then run `bootstrap.sh` with its public half.
3. **`ssh-keyscan`** the droplet — this needs the host to exist, which is why it
   cannot be done earlier.
4. **Add the four secrets.**
5. **Solve GHCR read access**, one of:
   - *Recommended:* let the first run build and push, then set the package to
     public (package page → Package settings → Change visibility) and re-run
     the deploy job. The image contains only the game server — no secrets.
   - *Or, pre-emptively:* `docker login ghcr.io` on the droplet with a PAT
     scoped to `read:packages`. This works before the package exists, so the
     first push can then succeed end to end.
6. **DNS** — `A` record for `play.leafmods.com`. Needed by players; the deploy
   itself can use the raw IP as `DEPLOY_HOST`.
7. **Push to `main`.**

If you added required reviewers to the `production` environment, the deploy job
waits for approval rather than failing — check the run page.

## Deploying

Merge into `main`. The workflow runs tests → builds and pushes the image → SSHes in
and restarts the stack. Direct pushes to `main` also trigger this workflow.
Updates to pull requests targeting `main` run tests only; they never build or
deploy an image. Branch pushes without an open pull request do not run it.
Manual deployments must select `main`; other refs cannot build or deploy. A manual run without
a rollback tag must pass tests and build successfully before deploying.

On the server, each deploy:

1. Receives the current `docker-compose.yml` via `scp`.
2. Rewrites **only** the `STARFALL_TAG=` line in `/opt/starfall/.env`, recording
   the previous value in `/opt/starfall/.last-tag`. Everything else in `.env`
   belongs to the operator and is never overwritten.
3. Runs `sudo /usr/local/bin/starfall-deploy`, which performs
   `docker compose pull`, `docker compose up -d --remove-orphans`, waits for all
   enabled containers to report healthy, runs scoped image retention, and exits
   non-zero if the stack did not come up.

Images are tagged `sha-<short commit>`, plus `latest` on `main`. Deploys always
pin the SHA tag — never `latest`, which would make "what is running?" and "roll
back to what?" unanswerable.

---

## How to verify a deployment

From CI: the run summary shows the deployed tag and `docker compose ps` output.
The deploy step fails if fewer than the configured number of enabled containers become healthy.

From the droplet:

```bash
# Container state plus recent logs (read-only, allowed for the deploy user)
sudo /usr/local/bin/starfall-status 50

# Six UDP listeners expected
ss -ulnp | grep 278

# What is actually running, by digest
sudo docker compose -f /opt/starfall/docker-compose.yml images
```

Healthy startup logs one line per container:

```
DEDICATED READY 0.1.0 port=27841 mode=3 min_players=2 rematch_delay=8.0 private=false
```

The container healthcheck proves the ENet socket is bound, not merely that the
process exists — a Godot server that crashed after start fails it.

**Then verify the three player-facing paths from the game itself:**

| Path | Expected |
| --- | --- |
| Online → Online queue (Duel) | "Searching for an opponent…", then a round once a second player queues. |
| Online → Host lobby | A four-character code appears; `LOBBY CLAIMED` in that container's log. |
| Online → Join lobby with that code | Both players land in the same round. |

No address or port should be visible anywhere in the UI.

---

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| All containers `(healthy)` but players get "Could not reach the server" | A container can be healthy and still have **no host port mapping**. The healthcheck runs inside the network namespace, where the server always binds successfully — it cannot see a failed publish. Compare `ss -ulnp \| grep 278` (expect three listeners by default, seven with private lobbies) against `docker ps` (matching healthy services). Fix with `docker compose up -d --force-recreate <service>`. Cause is normally something else holding the port when the container was first created. `starfall-deploy` now fails the deploy when this happens, but a container created before that check existed can still be in this state. |
| `address already in use` on a game port | Something outside Docker holds it — most often a leftover `ringfall`/`starfall` systemd unit from the pre-Docker model. `ss -ulnp \| grep 278` names the process. Never run both deployment models on one droplet. |
| Clients rejected with a version error | `Config.VERSION` differs between client and server. Expected after a protocol change — everyone must re-download. |
| Queue says "Searching…" forever | Working as designed: it needs `*_MIN_PLAYERS` humans. Lobbies show a code immediately, which is why they can look fine while the queue looks broken. |

## Desktop downloads

The deployment builds Windows and Linux launchers/clients and serves them from
`https://play.leafmods.com/downloads/`. See [Linux distribution](docs/LINUX_DISTRIBUTION.md) and [Windows distribution](docs/WINDOWS_DISTRIBUTION.md)
for the one-time HTTPS setup, sharing link, and update behavior. Only exported
client files are public; the source repository can be private. TCP 80/443 are
required in addition to the existing game UDP ports.

## Automatic server-image retention

The old `docker image prune` removed dangling images only. Immutable `sha-*`
release tags accumulated until the 24 GB server disk filled. Retention now runs
before each pull and after a healthy deployment. It removes only local image
tags in `ghcr.io/mrwells99/starfall:sha-*`, never using force or system prune.

It protects the running version, the previous successful version, the requested
release, `.last-tag`, both public client-feed versions, and **every image still
referenced by a container**, including stopped containers. Same-version retries
preserve the rollback record. Unknown/malformed state or mixed running releases
skip cleanup. Cleanup failure is reported but does not trigger a server rollback.
The root-owned record is `/var/lib/starfall-image-retention/state.json`.

Client downloads, volumes, repository sources and registry images are untouched.
Retaining a local image makes rollback fast; its matching client archives remain
in `/opt/starfall/downloads`. Containers that still reference much older images
can keep extra images on disk intentionally. Client archives are not pruned by
this image policy; monitor that separate directory as releases accumulate.

**Existing server — one-time activation after deploying these files:**

```bash
sudo bash /opt/starfall/deploy/install-retention.sh
```

CI ships the installer and helper to the deploy folder. Root must run the
installer once because the deploy account intentionally cannot rewrite its
privileged wrapper. No SSH key change or new sudo permission is needed. The
installer copies the helper into `/usr/local/libexec/starfall-image-retention`,
adds the two hooks to `/usr/local/bin/starfall-deploy`, and keeps its original
as `starfall-deploy.before-retention`. Re-running it is idempotent; unfamiliar
wrapper layouts are rejected before rewriting. It does not immediately remove
images or restart services. Fresh `create-deploy-user.sh` setup installs the hooks
and helper automatically. Later helper code changes also require a reviewed root
reinstall; CI never executes a deploy-writable cleanup script as root.

Rollback protection is captured before pulling and advanced only after health
checks. The retained previous version is not overwritten when the same release
is retried. The existing server/HTTPS rollback flow continues to work.

Local validation: all 24 release/retention tests pass. The trimmed image reports
950 MB local Docker disk usage (359 MB content) and passes the dedicated-server
health check with a read-only filesystem, no capabilities, and no external
network access. Runtime assets/import cache remain present; authoring folders
are absent. No production cleanup or deployment was performed during validation.

## How to roll back

Every build is an immutable tag, so rollback is a redeploy of an older one.

**Preferred — re-run the workflow against a known-good tag.** This takes the
same path as a normal deploy, including the health gate and matching desktop
update manifests. Choose a tag that has retained Windows and Linux releases; tags from
before Linux distribution are not eligible for this paired rollback:

```bash
gh workflow run deploy.yml --ref main -f tag=sha-1a2b3c4
```

Find candidate tags in the GHCR package page, or:

```bash
gh api "/users/<owner>/packages/container/starfall/versions" \
  --jq '.[].metadata.container.tags[]' | head -20
```

**Immediate — on the droplet, when CI is unavailable or you need it now:**

```bash
ssh deploy@play.leafmods.com
cd /opt/starfall
cat .last-tag                      # the tag this deploy replaced
python3 publish_windows.py verify --tag sha-1a2b3c4
python3 publish_windows.py verify --platform linux --tag sha-1a2b3c4
sed -i 's|^STARFALL_TAG=.*|STARFALL_TAG=sha-1a2b3c4|' .env
sudo /usr/local/bin/starfall-deploy
python3 publish_windows.py promote --tag sha-1a2b3c4
python3 publish_windows.py promote --platform linux --tag sha-1a2b3c4
```

A rollback done this way is invisible to CI. The next push to `main` will
deploy forward again — so revert the offending commit too, or you will ship the
same break twice.

### The client-version trap

`Config.VERSION` is compiled into both client and server, and the server hard
rejects mismatched clients. Rolling the server back to a build with a different
`VERSION` will disconnect everyone on the current client with a version error.
That is the handshake working correctly. Desktop players should close the game
and reopen the launcher after rollback to install the matching retained client.
Linux developers must check out the matching source revision. Check whether `VERSION` differs between the two
tags before rolling back during a session.

CI emits a warning when `scripts/` changes without a `VERSION` bump.

---

## Sizing

Dedicated servers retain 60 Hz physics and 20 Hz snapshots. Their frame loop is
capped at physics frequency, actors keep collision capsules without loading models,
and HUD/animation/local combat-effect updates are skipped. Menu controls are still
constructed once to support the shared session lifecycle.

A short local Linux comparison (same Godot 4.5.1, seeded six-bot workload) measured:

| Workload | Before CPU | After CPU | Before RSS | After RSS |
| --- | --- | --- | --- | --- |
| Idle queue | 6.8% | 1.8% | 164.7 MiB | 129.8 MiB |
| Six bots fighting | 92.8% | 7.8% | 169.3 MiB | 130.3 MiB |

CPU is percent of one logical core; RSS is peak sampled resident process memory.
These are six-second local samples, not production capacity guarantees. Run
`python tools/measure_server.py` on Linux with Godot installed to repeat the idle
and six-bot workloads on a free UDP port (default 27944; override with `--port`).
It launches temporary servers and terminates only those processes. The benchmark
keeps bot HP full and excludes real client/network load. After deployment, sample
`docker stats --no-stream`, `vmstat 1 30`, and `free -h` during simultaneous matches
and world activity to decide whether hardware still needs upgrading.

`.env` sets per-container ceilings (`STARFALL_CPU_LIMIT=0.75`,
`STARFALL_MEM_LIMIT=512M`). These are limits, not reserved capacity or a guarantee
against contention. Three containers each using their memory ceiling would exceed
a 1 GB host. Stable occupied swap alone does not demonstrate active swapping;
check `vmstat`'s `si`/`so`, CPU idle time, and match responsiveness under load.

If you need more concurrent private lobbies, add a port to `Config.LOBBY_PORTS`,
a port to `.env`, a service to `docker-compose.yml`, and a firewall rule — all
four, or clients will probe a port that nothing answers.

---

## Security review

Findings from reviewing this design, most important first.

### Addressed here

**The deploy user is not in the `docker` group.** Docker group membership is
root-equivalent — any member can `docker run -v /:/host` and write to the host
filesystem. Instead the account gets passwordless sudo for exactly two
root-owned wrapper scripts that take no meaningful arguments. Sudoers contains
no wildcards; a wildcard would let the deploy user pass arbitrary flags to
`docker`, which is close to handing over root.

**Host key pinning.** The workflow writes `DEPLOY_SSH_KNOWN_HOSTS` and uses
`StrictHostKeyChecking=yes`. The common shortcut — `StrictHostKeyChecking=no` —
accepts whatever key answers, which means a DNS or BGP hijack silently receives
your deploy key.

**Containers run unprivileged and read-only.** UID 10001, `cap_drop: ALL`,
`no-new-privileges`, read-only root filesystem, and a 64 MB `noexec,nosuid`
tmpfs for the one directory Godot writes to. The image needs no capabilities:
it binds a high UDP port, not a privileged one.

**Supply chain.** The Godot download is checksum-verified against the official
`SHA512-SUMS.txt` in both the Dockerfile and CI; a tampered or truncated
download fails the build rather than shipping. Images are built with provenance
attestation and an SBOM.

**Log caps.** Set in both `daemon.json` and compose, so a crash-looping
container cannot fill the droplet's disk — the failure mode that turns one
broken service into a dead host.

**Least-privilege CI.** Workflow permissions default to `contents: read`; only
the build job gets `packages: write`. The deploy tag is validated against a
character allowlist before it reaches a shell.

**No secrets in the image or `.env`.** The server has no database, no API keys,
no credentials. `.env` is configuration only, and `.env` is gitignored.

### Recommendations — not done, worth doing

1. **Pin GitHub Actions to commit SHAs, not tags.** `actions/checkout@v4` is a
   mutable ref; whoever controls that tag controls what runs with your secrets.
   Convert with:
   ```bash
   gh api /repos/actions/checkout/git/ref/tags/v4 --jq .object.sha
   ```
   I left version tags in place rather than write SHAs I could not verify at
   authoring time. Pin them before this handles anything sensitive.

2. **The game server has no authentication.** Anyone who can reach the ports can
   connect and play; the version handshake is a compatibility check, not access
   control. That is fine for a friends' server and is a real problem the moment
   it isn't. Options, cheapest first: firewall to known IPs; a shared join
   secret in the `register_player` RPC; real accounts.

3. **No rate limiting on connections.** ENet will happily accept a flood of
   connection attempts, and several processes on one vCPU is not much to exhaust.
   Consider `firewalld`/nftables rate limits on the game ports, and a DigitalOcean
   cloud firewall in front of the droplet.

4. **Restrict SSH.** Disable password authentication and root login
   (`PermitRootLogin no`, `PasswordAuthentication no` in `sshd_config`), and put
   the DO cloud firewall in front of port 22 restricted to your own IPs.
   `bootstrap.sh` deliberately does not edit `sshd_config` — locking yourself out
   of a fresh droplet is worse than the risk it removes. Do it by hand, with a
   second session open.

5. **Rotate the deploy key** on any suspicion, and whenever someone leaves the
   project. It is the single credential with server access.

6. **Consider rootless Docker** or Podman for the final containment step. The
   containers are hardened, but the daemon still runs as root. This is a real
   change in operational model, not a flag — worth it only if the threat model
   justifies it.

7. **Unattended security updates.** `dnf install dnf-automatic` and enable
   `dnf-automatic-install.timer`. Nothing here patches the host.

8. **Back up nothing, deliberately.** Matches are ephemeral and the server holds
   no persistent state. If persistent identities or stats are ever added, this
   line stops being true and needs revisiting.
