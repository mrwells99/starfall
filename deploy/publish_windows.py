#!/usr/bin/env python3
"""Verify, stage, or promote a client release. Run promote AFTER server health checks."""
import argparse
import hashlib
import json
from pathlib import Path
import os
import re
import shutil
import tempfile
import zipfile


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def names(platform):
    if platform == "linux":
        return "Starfall.x86_64", "Starfall-Linux.zip", "StarfallLauncher", ".so", "/linux"
    if platform == "windows":
        return "Starfall.exe", "Starfall-Windows.zip", "StarfallLauncher.exe", ".dll", ""
    raise ValueError("Unsupported platform")


def verify(folder, tag, platform="windows"):
    executable, archive_name, launcher_name, suffix, url_path = names(platform)
    if not re.fullmatch(r"sha-[a-f0-9]{7}", tag):
        raise ValueError("A paired client release requires an immutable sha-xxxxxxx tag")
    manifest = json.loads((folder / "manifest.json").read_text())
    build = manifest.get("build", "")
    if (manifest.get("schema") != 1 or not re.fullmatch(r"[a-f0-9]{40}", build)
            or tag != "sha-" + build[:7] or manifest.get("server_tag") != tag
            or manifest.get("url") != f"https://play.leafmods.com/downloads{url_path}/releases/{tag}/{archive_name}"):
        raise ValueError("Client does not match the server release")
    archive = folder / archive_name
    if not 0 < archive.stat().st_size <= 1 << 30 or archive.stat().st_size != manifest["size"] or digest(archive) != manifest["sha256"]:
        raise ValueError("Client archive failed verification")
    files = manifest["files"]
    if not {executable, "Starfall.pck"}.issubset(files) or not 2 <= len(files) <= 128:
        raise ValueError("Incomplete client release")
    seen = set()
    total = 0
    with zipfile.ZipFile(archive) as z:
        if len(z.infolist()) != len(files):
            raise ValueError("Unexpected archive contents")
        for entry in z.infolist():
            name = entry.filename
            if (name not in files or name.lower() in seen
                    or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,80}", name)
                    or (name not in (executable, "Starfall.pck") and not (name.endswith(suffix) if platform == "linux" else name.lower().endswith(suffix)))):
                raise ValueError("Unexpected archive filename")
            seen.add(name.lower())
            expected = files[name]
            total += entry.file_size
            if entry.file_size != expected["size"] or entry.file_size <= 0 or total > 3 << 30:
                raise ValueError("Invalid unpacked size")
            h = hashlib.sha256()
            with z.open(entry) as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b""):
                    h.update(chunk)
            if h.hexdigest() != expected["sha256"]:
                raise ValueError("Game file failed verification")
    launcher = folder / launcher_name
    expected_launcher = (folder / (launcher_name + ".sha256")).read_text().split()[0]
    if launcher.stat().st_size == 0 or digest(launcher) != expected_launcher:
        raise ValueError("Launcher failed verification")
    return manifest


def atomic_copy(source, destination):
    fd, name = tempfile.mkstemp(prefix=".publish-", dir=destination.parent)
    try:
        with os.fdopen(fd, "wb") as target, open(source, "rb") as src:
            shutil.copyfileobj(src, target)
            target.flush()
            os.fsync(target.fileno())
        os.chmod(name, 0o644)
        os.replace(name, destination)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def stage(source, root, tag, platform="windows"):
    _, archive_name, launcher_name, _, _ = names(platform)
    manifest = verify(source, tag, platform)
    releases = root / "releases"
    releases.mkdir(parents=True, exist_ok=True)
    destination = releases / tag
    if destination.exists():
        # Rerunning CI can produce different ZIP timestamps. Never replace an
        # immutable URL: reuse the already verified release for this commit.
        existing = verify(destination, tag, platform)
        if existing["build"] != manifest["build"]:
            raise ValueError("Short commit tag collision; release was not replaced")
        return
    scratch = Path(tempfile.mkdtemp(prefix=".stage-", dir=root))
    try:
        for name in ("manifest.json", archive_name, launcher_name, launcher_name + ".sha256"):
            shutil.copyfile(source / name, scratch / name)
            (scratch / name).chmod(0o644)
        scratch.chmod(0o755)
        os.rename(scratch, destination)
    finally:
        if scratch.exists():
            shutil.rmtree(scratch)


def promote(root, tag, platform="windows"):
    _, _, launcher_name, _, _ = names(platform)
    source = root / "releases" / tag
    verify(source, tag, platform)
    for name in (launcher_name, launcher_name + ".sha256"):
        atomic_copy(source / name, root / name)
    # The feed is the commit point. Readers always see a complete JSON file.
    atomic_copy(source / "manifest.json", root / "manifest.json")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("stage", "verify", "promote"))
    parser.add_argument("--root", type=Path, default=Path("/opt/starfall/downloads"))
    parser.add_argument("--source", type=Path)
    parser.add_argument("--platform", choices=("windows", "linux"), default="windows")
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()
    if args.platform == "linux":
        args.root = args.root / "linux"
    if args.action == "stage":
        if args.source is None:
            parser.error("stage requires --source")
        stage(args.source, args.root, args.tag, args.platform)
    elif args.action == "verify":
        verify(args.root / "releases" / args.tag, args.tag, args.platform)
    else:
        promote(args.root, args.tag, args.platform)
    print(f"{args.platform} release {args.tag}: {args.action} complete")
