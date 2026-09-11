#!/usr/bin/env python3
"""Install checksum-pinned Godot 4.5.1 Linux editor and export template."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile
from install_windows_tools import VERSION, HASHES

LINUX_HASH = "5bccbed65a94b82c7c319fdb15719ee8113a6e503976cc54e16f1c61fe95f3d74e5e40b8449b5bb89ff7f424574c20af01a4f5ef08b389e4dc338b245185b0b9"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path.home() / "starfall-godot-linux")
    args = parser.parse_args()
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    for suffix, expected in (("linux.x86_64.zip", LINUX_HASH), ("export_templates.tpz", HASHES["export_templates.tpz"])):
        archive = cache / f"Godot_v{VERSION}_{suffix}"
        if not archive.exists():
            partial = archive.with_suffix(".partial")
            print("Downloading", archive.name, flush=True)
            with urllib.request.urlopen(f"https://github.com/godotengine/godot/releases/download/{VERSION}/{archive.name}", timeout=60) as src, partial.open("wb") as out:
                shutil.copyfileobj(src, out)
            partial.replace(archive)
        h = hashlib.sha512()
        with archive.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        if h.hexdigest() != expected:
            archive.unlink()
            raise ValueError("Godot checksum mismatch; rerun to download again")
        with zipfile.ZipFile(archive) as z:
            if suffix == "linux.x86_64.zip":
                editor = cache / "godot"
                editor.write_bytes(z.read(f"Godot_v{VERSION}_linux.x86_64"))
                editor.chmod(0o755)
            else:
                data = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
                dest = data / "godot/export_templates/4.5.1.stable"
                dest.mkdir(parents=True, exist_ok=True)
                for name in ("linux_release.x86_64", "version.txt"):
                    (dest / name).write_bytes(z.read("templates/" + name))
                (dest / "linux_release.x86_64").chmod(0o755)
    if os.environ.get("GITHUB_PATH"):
        with open(os.environ["GITHUB_PATH"], "a") as f:
            f.write(str(cache) + "\n")
    print("Verified Godot editor and Linux export template", flush=True)

if __name__ == "__main__":
    main()
