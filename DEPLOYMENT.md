# Deployment — Ringfall on Docker

Production deployment for the Ringfall dedicated servers: GitHub Actions builds
and tests, pushes an image to GHCR, and restarts the stack on a Rocky Linux 9
droplet over SSH.

This supersedes the source-on-droplet + systemd model, which is archived in
[`deploy/legacy-systemd/`](deploy/legacy-systemd/). **Do not run both** — they
bind the same UDP ports.

---

## What gets deployed

Six containers from one image: two public matchmaking queues and a four-slot
private-lobby pool.

| Container | UDP | Role |
| --- | --- | --- |
| `ringfall-duel` | 27840 | Duel queue (1v1) |
| `ringfall-team` | 27841 | Team queue (3v3) |
| `ringfall-lobby1..4` | 27850–27853 | Private lobbies, claimed by code |

These port numbers are **baked into the client** at build time
(`scripts/config.gd`). Changing one means changing it in `config.gd`,
`.env`, `docker-compose.yml` and the firewall — and shipping a new client.

### Build strategy, and why

The image bundles the pinned Godot binary, the project source, and a
**pre-built import cache**; it does not use Godot's export pipeline.

The repo has no `export_presets.cfg` and no external assets — all geometry is
generated at runtime — so an export would need roughly a gigabyte of export
templates to produce a `.pck` that is essentially the source already present.
Bundling gets the properties that matter in production: one immutable artifact,
no writes to the project tree at run time, no import-cache race between six
processes, and a fast start.

Revisit this if the project gains real assets (textures, audio, models), when
`.pck` packing and shipping compiled bytecode start to pay for themselves.

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
ssh-keygen -t ed25519 -N "" -C ci@ringfall -f ./ringfall_deploy
ssh-keyscan -t ed25519 play.leafmods.com
```

The public half (`ringfall_deploy.pub`) goes to `create-deploy-user.sh`; the
private half becomes `DEPLOY_SSH_KEY`; the `ssh-keyscan` output becomes
`DEPLOY_SSH_KNOWN_HOSTS`. Delete the local private key afterwards.

### Protecting the production environment

The `deploy` job runs in a GitHub Environment named `production`. Add required
reviewers and restrict it to the `main` branch in repo settings — that, not the
workflow file, is what stops an arbitrary branch from reaching the droplet.

---

## Required server setup

A $6 Rocky Linux 9 droplet is enough for six containers, though all six share
one vCPU; see [Sizing](#sizing).

```bash
# 1. Ship the deploy scripts
scp -r deploy/ root@<droplet>:/tmp/ringfall-deploy/

# 2. Read it, then run it. Takes the CI deploy key's PUBLIC half.
ssh root@<droplet> 'less /tmp/ringfall-deploy/bootstrap.sh'
ssh root@<droplet> 'bash /tmp/ringfall-deploy/bootstrap.sh "ssh-ed25519 AAAA... ci@ringfall"'
```

`bootstrap.sh` is idempotent and runs the other two scripts in order:

1. Base packages; `firewalld` enabled; UDP 27840–27841 and 27850–27853 opened.
2. [`install-docker-rocky.sh`](deploy/install-docker-rocky.sh) — Docker CE from
   Docker's own repo (removing the `podman-docker` shim), plus a daemon config
   that caps log size, enables `live-restore`, and disables the userland proxy.
3. [`create-deploy-user.sh`](deploy/create-deploy-user.sh) — the `deploy` user,
   its authorized key, and two root-owned wrapper scripts it may run via sudo.
4. `/opt/ringfall` seeded with `.env` from `.env.example`.

Then, manually:

- **DNS** — `A` record for `play.leafmods.com` → droplet IPv4.
- **Review `/opt/ringfall/.env`** — at minimum confirm `RINGFALL_IMAGE` matches
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

Push to `main`. The workflow runs tests → builds and pushes the image → SSHes in
and restarts the stack.

On the server, each deploy:

1. Receives the current `docker-compose.yml` via `scp`.
2. Rewrites **only** the `RINGFALL_TAG=` line in `/opt/ringfall/.env`, recording
   the previous value in `/opt/ringfall/.last-tag`. Everything else in `.env`
   belongs to the operator and is never overwritten.
3. Runs `sudo /usr/local/bin/ringfall-deploy`, which performs
   `docker compose pull`, `docker compose up -d --remove-orphans`, waits for all
   six containers to report healthy, prunes images older than a week, and exits
   non-zero if the stack did not come up.

Images are tagged `sha-<short commit>`, plus `latest` on `main`. Deploys always
pin the SHA tag — never `latest`, which would make "what is running?" and "roll
back to what?" unanswerable.

---

## How to verify a deployment

From CI: the run summary shows the deployed tag and `docker compose ps` output.
The deploy step fails if fewer than six containers become healthy.

From the droplet:

```bash
# Container state plus recent logs (read-only, allowed for the deploy user)
sudo /usr/local/bin/ringfall-status 50

# Six UDP listeners expected
ss -ulnp | grep 278

# What is actually running, by digest
sudo docker compose -f /opt/ringfall/docker-compose.yml images
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

## How to roll back

Every build is an immutable tag, so rollback is a redeploy of an older one.

**Preferred — re-run the workflow against a known-good tag.** This takes the
same path as a normal deploy, including the health gate:

```bash
gh workflow run deploy.yml -f tag=sha-1a2b3c4
```

Find candidate tags in the GHCR package page, or:

```bash
gh api "/users/<owner>/packages/container/ringfall/versions" \
  --jq '.[].metadata.container.tags[]' | head -20
```

**Immediate — on the droplet, when CI is unavailable or you need it now:**

```bash
ssh deploy@play.leafmods.com
cd /opt/ringfall
cat .last-tag                      # the tag this deploy replaced
sed -i 's|^RINGFALL_TAG=.*|RINGFALL_TAG=sha-1a2b3c4|' .env
sudo /usr/local/bin/ringfall-deploy
```

A rollback done this way is invisible to CI. The next push to `main` will
deploy forward again — so revert the offending commit too, or you will ship the
same break twice.

### The client-version trap

`Config.VERSION` is compiled into both client and server, and the server hard
rejects mismatched clients. Rolling the server back to a build with a different
`VERSION` will disconnect everyone on the current client with a version error.
That is the handshake working correctly, but it does mean **a rollback can look
like an outage to players**. Check whether `VERSION` differs between the two
tags before rolling back during a session.

CI emits a warning when `scripts/` changes without a `VERSION` bump.

---

## Sizing

Six Godot processes on one vCPU. Each is idle until players connect, and a
round simulates six actors at 30 Hz — light, but not free.

`.env` sets per-container ceilings (`RINGFALL_CPU_LIMIT=0.75`,
`RINGFALL_MEM_LIMIT=512M`) so one busy match cannot starve the others. On a 1 GB
droplet the memory limits are a ceiling, not a reservation; six containers each
actually using 512 MB would OOM. In practice an idle server sits far below that.
Watch `docker stats` during the first real 3v3 before assuming headroom.

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
   connection attempts, and six processes on one vCPU is not much to exhaust.
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
