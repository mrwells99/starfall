# Windows launcher and updates

Players download **StarfallLauncher.exe**, put it somewhere convenient, and open
it. It installs the Windows game under `%LOCALAPPDATA%\Starfall`, checks for an
update on startup and before Play, then launches the game. No Godot editor,
GitHub account, administrator access, or separate runtime is required.

The intended sharing link, **after the first successful deployment**, is:

`https://play.leafmods.com/downloads/StarfallLauncher.exe`

The source repository can become private without changing this link. The Linux
server serves only exported client files. The downloads are public; this is
not an invite-only download system. Linux players also have a single-file launcher and a separate update feed; see
[Linux distribution](LINUX_DISTRIBUTION.md).

## First deployment on the existing server

The download service is part of `docker-compose.yml` and starts through the
normal server deployment. CI uses its existing server connection to upload the
Windows builds and web configuration; a separate SSH connection from the
developer's PC is not required. Port 80 redirects visitors to HTTPS on port 443.
Both the launcher and subsequent game downloads come from this same server.

1. Confirm `play.leafmods.com` points directly to the game server and TCP 80/443
   are available. If another web server already owns those ports, integrate the
   `/downloads/` route with it instead of starting a second listener.
2. If the server still needs Python or its web ports opened, run
   `sudo bash /opt/starfall/deploy/enable-downloads.sh` on the server once.
   The helper is shipped with the web configuration by the normal deployment;
   it is also available as `deploy/enable-downloads.sh` in a full checkout.
   It installs Python 3, creates `/opt/starfall/downloads`, and opens HTTP/HTTPS
   in the host firewall. Also allow inbound TCP 80/443 in the cloud firewall.
   The existing UDP game ports stay as configured.
3. Push the reviewed changes to `main` (or rerun deployment after opening the
   firewall if the first attempt could not reach HTTPS). The existing deployment secrets are
   sufficient: no new GitHub token is embedded in the launcher or game.
4. The Windows job tests the updater, builds the launcher, exports the game,
   and checks startup of both real Windows executables. It runs alongside the
   existing test job. Godot tools/templates are cached after the first build.
5. CI uploads the client, starts the servers and the Caddy download service,
   checks server health and public HTTPS, then promotes the matching update
   manifest. Share the launcher link only after that deployment succeeds.

Caddy keeps its certificates in Docker volumes. Do not remove those volumes
when restarting containers. It serves static files from a read-only bind mount
and never mounts the source checkout. Fresh-server bootstrap includes the
download preparation; existing servers use the smaller helper above.

## What an update does

- The manifest identifies the full source commit, user-visible version, paired
  server image tag, download size, and SHA-256 checksums of the ZIP and its files.
- The launcher accepts HTTPS downloads from the configured host, checks the
  archive and each extracted file, then switches its installation record
  atomically. Updates use a fresh folder; they do not overwrite a running game.
- A failed download, extraction, or state write keeps the current installation.
  Corrupt installed files can be repaired with Retry. A verified installed game
  remains explicitly playable when the update service is unavailable; an old
  build may be unable to connect to an updated server.
- The current and previous game folders are kept. Older launcher-owned version
  folders are removed after successful updates. Godot's existing `user://`
  settings folder and application name are unchanged, preserving settings,
  keybinds and HUD placement.
- A failed server/HTTPS deployment attempts to restore the prior server tag and
  configuration; its Windows feed is not promoted. CI reports a failed rollback
  if the previous server cannot be restored.

The launcher itself is a small, separate executable. This first version updates
the **game**, not its own executable. If we later change the launcher protocol,
players download a newer launcher from the same link. The Windows binaries are
currently unsigned; Windows may show an unknown-publisher prompt. Signing can
be added once a signing identity is available.

## Rollback

Use the existing manual deployment workflow with a retained `sha-xxxxxxx` tag.
CI checks that both desktop archives exist **before** changing the server, then
promotes that tag's manifest after health checks. Launchers can reuse their
verified previous installation. The updated workflow rejects releases predating Linux distribution because
they do not have both paired archives; any emergency server-only
rollback needs separate operator coordination with players.

Retained server downloads are deliberately not automatically deleted: deleting
one can break rollback or a download in progress. Monitor disk usage under
`/opt/starfall/downloads/releases`. The incoming upload folder is reused each
deployment. When pruning manually, retain the active and rollback releases.

## Local build and checks

Use Godot **4.5.1** with its Windows x86-64 release export template and Go 1.24+:

```bash
mkdir -p build/windows
(cd launcher && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build \
  -trimpath -ldflags='-s -w -H windowsgui' \
  -o ../build/StarfallLauncher.exe ./cmd/starfall)
godot --headless --path . --export-release 'Windows Desktop' build/windows/Starfall.exe
python3 tools/release/package_windows.py --build "$(git rev-parse HEAD)"
(cd launcher && go test ./updater)
python3 -m unittest discover -s tools/release -p 'test_*.py' -v
```

`build/release/Starfall-Windows.zip` is also a portable game: extract the whole
ZIP and run `Starfall.exe`. Running it directly does **not** check for updates.
Local builds from an uncommitted checkout are previews, not published releases;
CI rebuilds from the actual commit before deployment. Do not manually publish a
dirty local build using an existing production commit's immutable download URL.

Launcher diagnostics: `%LOCALAPPDATA%\Starfall\launcher.log`. Godot's own game
logs remain under its existing user data directory. `--smoke-test` on the
launcher checks native window/control creation without downloading anything.

## Verification in this workspace

Updater scenarios passed on Linux (including the race detector) and as a
Windows test binary under Wine: first install, no-op updates, rollback reuse,
settings preservation, bad/truncated/oversized downloads, cancellation, HTTP
failure, malformed archives, traversal, duplicate entries, symlinks, file
checksums, repair, state-write failure, and old-version cleanup. Seven packaging
and promotion tests passed. The exported Windows game passed headless startup and clean exit under Wine;
the launcher passed native window creation and clean exit under Wine. A rendered
120-frame Wine/llvmpipe check exceeded its 60-second limit, so that run is not a
rendered pass. A follow-up two-frame 640×360 rendered Windows startup check
passed and exited cleanly under the same Wine/llvmpipe environment. The download service configuration validated in Caddy 2.11.4; six isolated
HTTP checks passed for health, stable download headers, immutable ZIP headers,
and hidden/missing-file rejection. Native Windows CI remains the platform
gate; Wine is not a substitute for testing on a friend's Windows PC.
