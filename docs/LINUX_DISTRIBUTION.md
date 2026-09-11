# Linux launcher and updates

Players use one **StarfallLauncher** executable for Ubuntu and Arch-family
x86-64 desktops. It is a statically linked Go executable with its interface
embedded; no AppImage/FUSE, Wine, Godot editor, or launcher runtime is required.
The Play/update panel opens in the player's default browser via `xdg-open` or
`gio open`. The downloaded Godot game runs as a native desktop application.
A desktop browser/opener and working graphics drivers are required.

## Player setup

After the first successful deployment containing Linux support, share:

`https://play.leafmods.com/downloads/linux/StarfallLauncher`

Download the file, enable **Allow executing file as program** in its properties,
and open it. Depending on the file manager, the executable permission can also
be set once with `chmod +x ~/Downloads/StarfallLauncher`. Keep that launcher file
somewhere convenient and open it for future play. No administrator access is
needed. ARM machines are not supported by this x86-64 download.

The launcher checks for updates on startup and again before Play. It verifies
downloaded archives and every extracted file, retains the previous version,
and offers **Play installed version** if an update fails. Old clients may only
be usable offline when the server has moved to a newer version. Interrupted
updates do not replace the last verified installation.

Game installations and `launcher.log` live under `$XDG_DATA_HOME/Starfall`, or
`~/.local/share/Starfall` by default. Godot's existing settings, keybinds and HUD
layout stay in its existing user data folder. The launcher updates the game;
changes to the launcher itself require downloading its file again.

Closing the panel stops an idle launcher after three minutes without contact.
**Quit launcher** exits immediately when the game is not running. While the
game runs, the launcher holds its installation lock; reopening the launcher
opens the existing panel. A fresh random token and an exact localhost address
restrict the panel's API to its local session. The listener binds only to
127.0.0.1 and rejects foreign Host/Origin headers.

## Release pipeline

The `linux` CI job runs on Ubuntu 22.04, runs launcher/updater tests with the race
detector, builds the static launcher, verifies the pinned Godot 4.5.1 downloads,
exports `Linux`, and checks native headless startup. It packages only
`Starfall.x86_64`, `Starfall.pck`, and optional `.so` files. Source, tools, and
credentials are excluded. Windows remains at its original URLs and format.

`package_linux.py` uses the shared packager. `publish_windows.py` retains its
historical name and defaults for compatibility; `--platform linux` selects the
Linux format and adds `/linux` beneath its download root. Immutable Linux
releases live at `/downloads/linux/releases/sha-xxxxxxx/`; the mutable feed is
`/downloads/linux/manifest.json`.

Deployment requires both desktop build jobs and the server build to succeed.
Both retained releases are verified before changing the server. After server
health and both public HTTPS checks pass, their feeds are promoted. A failed
deployment attempts to restore the previous server configuration and feeds.
On the first Linux deployment, rollback to the previous Windows-only release
removes the new Linux feed if necessary.

Manual rollback through the updated workflow requires a tag with **both**
retained desktop releases. Tags from before Linux distribution are rejected
before changing the server. Monitor disk use in both download trees and retain
active and rollback releases. Do not publish local dirty-checkout artifacts
under an existing production commit's immutable URL.

## Local build

```bash
python3 tools/release/install_linux_tools.py
mkdir -p build/linux
(cd launcher && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -trimpath -ldflags='-s -w' -o ../build/StarfallLauncher ./cmd/starfall)
~/starfall-godot-linux/godot --headless --path . --import
~/starfall-godot-linux/godot --headless --path . --export-release Linux build/linux/Starfall.x86_64
python3 tools/release/package_linux.py --build "$(git rev-parse HEAD)"
(cd launcher && go test -race ./...)
python3 -m unittest discover -s tools/release -p 'test_*.py' -v
```

The ZIP is a portable game alternative: extract it, make `Starfall.x86_64`
executable if necessary, and run it beside its PCK. This bypasses updates.
`--preview --no-browser` starts a local launcher panel without downloading;
`--no-browser` alone prints the panel address while checking the real feed.

## Validation and publication status — September 10, 2026

Local Linux launcher tests cover verified install, native process launch,
offline recovery, data-folder selection, and request isolation. Shared updater
tests cover download failures, rollback, repair, checksums, executable
permissions and platform separation. Fifteen packaging/promotion tests cover
both platforms. Linux and Windows launcher compilation passed. The Linux
export passed headless and real-window OpenGL startup on the Arch-family
EndeavourOS development host. A full local package → stage → promote check
passed with the actual exported game.
The browser panel was visually inspected at desktop width and checked for
narrow-screen overflow and working Quit behavior.

Ubuntu CI and testing on the friend's actual Ubuntu machine remain deployment
and hardware validation gates. These changes and local build artifacts are not
yet published; the new public download link becomes usable after deployment.
