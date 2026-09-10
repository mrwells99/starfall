#!/usr/bin/env python3
"""Package an exported Windows client; contains no repository credentials."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

DOWNLOADS = "https://play.leafmods.com/downloads"


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def package(export, launcher, output, build, version):
    if not re.fullmatch(r"[a-f0-9]{40}", build):
        raise ValueError("Build must be the full Git commit SHA")
    if not version or len(version) > 64:
        raise ValueError("Invalid version")
    files = sorted(p for p in export.iterdir() if p.name in ("Starfall.exe", "Starfall.pck") or p.suffix.lower() == ".dll")
    if not {"Starfall.exe", "Starfall.pck"}.issubset({p.name for p in files}):
        raise ValueError("Export must contain Starfall.exe and Starfall.pck")
    if not launcher.is_file() or launcher.stat().st_size == 0:
        raise ValueError("Build StarfallLauncher.exe first")
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "Starfall-Windows.zip"
    entries = {}
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for file in files:
            if file.is_symlink() or not file.is_file() or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,80}", file.name):
                raise ValueError("Unexpected export file")
            size = file.stat().st_size
            if not size:
                raise ValueError("Empty export file")
            entries[file.name] = {"size": size, "sha256": digest(file)}
            z.write(file, file.name)
    if archive.stat().st_size > 1 << 30 or sum(f["size"] for f in entries.values()) > 3 << 30:
        raise ValueError("Release exceeds launcher size limits")
    tag = "sha-" + build[:7]
    manifest = dict(schema=1, build=build, version=version, server_tag=tag,
                    url=f"{DOWNLOADS}/releases/{tag}/Starfall-Windows.zip",
                    sha256=digest(archive), size=archive.stat().st_size, files=entries)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(launcher, output / "StarfallLauncher.exe")
    # Transport verification for the first launcher download, not a signature.
    (output / "StarfallLauncher.exe.sha256").write_text(digest(output / "StarfallLauncher.exe") + "  StarfallLauncher.exe\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", type=Path, default=Path("build/windows"))
    parser.add_argument("--launcher", type=Path, default=Path("build/StarfallLauncher.exe"))
    parser.add_argument("--output", type=Path, default=Path("build/release"))
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    config = Path("scripts/config.gd").read_text()
    version = re.search(r'^const VERSION\s*:?=\s*"([^"]+)"', config, re.M).group(1)
    result = package(args.export, args.launcher, args.output, args.build, version)
    print(f"Packaged Windows {result['version']} ({result['server_tag']}): {result['size'] // 1024 // 1024} MB")
