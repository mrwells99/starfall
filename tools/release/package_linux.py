#!/usr/bin/env python3
"""Package the Linux x86-64 game and its single-file launcher."""
import argparse
from pathlib import Path
import re
from package_windows import package

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", type=Path, default=Path("build/linux"))
    parser.add_argument("--launcher", type=Path, default=Path("build/StarfallLauncher"))
    parser.add_argument("--output", type=Path, default=Path("build/release-linux"))
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    version = re.search(r'^const VERSION\s*:?=\s*"([^"]+)"', Path("scripts/config.gd").read_text(), re.M).group(1)
    result = package(args.export, args.launcher, args.output, args.build, version, "linux")
    print(f"Packaged Linux {result['version']} ({result['server_tag']}): {result['size'] // 1024 // 1024} MB")
