#!/usr/bin/env python3
"""Every res:// path a committed file references must itself be committed.

Two agents working in the same repository will sooner or later commit a file
that preloads a script the other has not committed yet. Godot only discovers
that at load time, so the symptom is the whole game failing to parse with a
message naming a file that exists perfectly well on the author's machine — and
it only shows up in CI or on someone else's clone.

Checks tracked files only: work in progress is allowed to reference anything.
"""
import pathlib
import re
import subprocess
import sys

SUFFIXES = (".gd", ".tscn", ".gdshader", ".gdshaderinc", ".tres", ".scn", ".cfg")
SCAN = ("*.gd", "*.tscn", "*.gdshader", "*.gdshaderinc", "project.godot")


def tracked_files() -> set:
    out = subprocess.check_output(["git", "ls-files"], text=True)
    return {line for line in out.splitlines() if line}


def main() -> int:
    tracked = tracked_files()
    listing = subprocess.check_output(["git", "ls-files", *SCAN], text=True)
    missing = {}
    startup_errors = []
    for name in listing.splitlines():
        if not name:
            continue
        try:
            text = pathlib.Path(name).read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if name == "project.godot":
            section = ""
            for line in text.splitlines():
                line = line.strip()
                if line.startswith("["):
                    section = line
                elif section == "[autoload]" and line and not line.startswith(";"):
                    match = re.fullmatch(r'([^=]+)="\*?(res://[^"\n]+)"', line)
                    if not match:
                        startup_errors.append(
                            "project.godot autoload must use a committed res:// path: " + line
                        )
                    elif match[2][6:] not in tracked:
                        missing.setdefault(match[2][6:], set()).add(name)
        for ref in re.findall(r'res://([A-Za-z0-9_/.\-]+)', text):
            # Only resources that must exist to load. Output paths a tool writes
            # to, and bare directories, are not dependencies.
            if not ref.endswith(SUFFIXES) or ref in tracked:
                continue
            missing.setdefault(ref, set()).add(name)

    if not missing and not startup_errors:
        print("All referenced resources are committed.")
        return 0

    for error in startup_errors:
        print(error)
    print("Committed files reference resources that are NOT committed:\n")
    for ref in sorted(missing):
        on_disk = "present locally" if pathlib.Path(ref).exists() else "MISSING entirely"
        print("  res://%s  (%s)" % (ref, on_disk))
        for user in sorted(missing[ref]):
            print("      referenced by %s" % user)
    print("\nEither commit them, or drop the reference. A clean clone cannot load this.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
