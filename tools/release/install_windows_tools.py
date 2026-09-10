#!/usr/bin/env python3
"""Install checksum-pinned Godot 4.5.1 tools for the Windows CI job."""
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = "4.5.1-stable"
HASHES = {
    "win64.exe.zip": "ab84df90ead5a888530faaabe744a27678ef7635068883900174fae37f7fc6178d033b551d88963c7dc2466580915a582bbc79aca97c19085900655761f56a27",
    "export_templates.tpz": "8a65c73541184fbcf1a7afedb37c9c15ed0f3babdaafe36ff47ccc515548ac84bc7563ba5b94c253e6085b121ac608b7e03d35dfc0b2c8c690a646a8755b57e5",
}


def main():
    cache = Path.home() / "starfall-godot-windows"
    cache.mkdir(exist_ok=True)
    for suffix, expected in HASHES.items():
        archive = cache / ("Godot_v" + VERSION + "_" + suffix)
        if not archive.exists():
            partial = archive.with_suffix(".partial")
            print("Downloading", archive.name, flush=True)
            with urllib.request.urlopen(f"https://github.com/godotengine/godot/releases/download/{VERSION}/{archive.name}", timeout=60) as source, partial.open("wb") as output:
                shutil.copyfileobj(source, output)
            partial.replace(archive)
        h = hashlib.sha512()
        with archive.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        if h.hexdigest() != expected:
            archive.unlink()
            raise ValueError("Godot checksum mismatch; rerun to download again")
        with zipfile.ZipFile(archive) as z:
            if suffix == "win64.exe.zip":
                for name in (f"Godot_v{VERSION}_win64.exe", f"Godot_v{VERSION}_win64_console.exe"):
                    (cache / name).write_bytes(z.read(name))
            else:
                dest = Path(os.environ["APPDATA"]) / "Godot/export_templates/4.5.1.stable"
                dest.mkdir(parents=True, exist_ok=True)
                for name in ("windows_release_x86_64.exe", "version.txt"):
                    (dest / name).write_bytes(z.read("templates/" + name))
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as f:
            f.write(f"GODOT_WINDOWS={cache / ('Godot_v' + VERSION + '_win64_console.exe')}\n")
    print("Verified Godot editor and Windows export template", flush=True)


if __name__ == "__main__":
    main()
