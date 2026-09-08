#!/usr/bin/env python3
"""Bake a prepared static slice in an isolated Godot editor project.

Example:
    python tools/bake_sanctum_slice.py --scene scenes/sanctum_quality_slice.tscn \
        --data assets/environment/sanctum_slice/lighting/sanctum.lmbake

The input scene must contain static MeshInstance3D nodes with UV2 and a
LightmapGI sibling, plus its intended baking lights. Light bake mode Dynamic
keeps direct lighting/shadows live and bakes indirect only. Static stores both.
The project's runtime renderer and editor plugin list are never changed.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene", required=True, help="Project-relative prepared .tscn")
    parser.add_argument("--data", required=True, help="Project-relative output .lmbake")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--no-xvfb", action="store_true", help="Use the existing display")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    scene = Path(args.scene.removeprefix("res://"))
    data = Path(args.data.removeprefix("res://"))
    for path in (scene, data):
        if path.is_absolute() or ".." in path.parts:
            parser.error("Scene and data must stay inside the project.")
    if scene.suffix != ".tscn" or not (project / scene).is_file():
        parser.error("Scene must be an existing .tscn file.")
    if data.suffix != ".lmbake":
        parser.error("Data must have the .lmbake extension.")

    stage = Path(tempfile.mkdtemp(prefix="sanctum_bake_"))
    print(f"Temporary bake project: {stage}", flush=True)
    # Preserve res:// paths but isolate imports, plugin state and intermediate data.
    # Only project content is copied; caches, repository internals and artifacts stay out.
    for child in project.iterdir():
        if child.name.startswith(".") or child.name in {"artifacts", "docs", "tools", "assets-source"}:
            continue
        if child.is_dir():
            shutil.copytree(child, stage / child.name, ignore=shutil.ignore_patterns("*.import", "__pycache__"))
        elif child.suffix in {".tscn", ".tres", ".gd", ".gdshader", ".gdshaderinc"}:
            shutil.copy2(child, stage / child.name)
    plugin = stage / "addons" / "sanctum_bake"
    plugin.mkdir(parents=True, exist_ok=True)
    shutil.copy2(project / "tools" / "bake_sanctum_slice.gd", plugin / "plugin.gd")
    (plugin / "plugin.cfg").write_text(
        '[plugin]\nname="Sanctum isolated bake"\n'
        'description="Temporary native lightmap bake"\nauthor="Starfall"\n'
        'version="1.0"\nscript="plugin.gd"\n'
    )
    # Keep quality-related project settings while giving the stage its own plugin.
    config = (project / "project.godot").read_text()
    if "[editor_plugins]" in config:
        import re
        config = re.sub(r"(?ms)^\[editor_plugins\].*?(?=^\[|\Z)", "", config)
    config += '\n[editor_plugins]\nenabled=PackedStringArray("res://addons/sanctum_bake/plugin.cfg")\n'
    (stage / "project.godot").write_text(config)
    env = os.environ.copy()
    env["SANCTUM_BAKE_SCENE"] = "res://" + scene.as_posix()
    env["SANCTUM_BAKE_DATA"] = "res://" + data.as_posix()
    cmd = [args.godot, "--editor", "--path", str(stage), "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--display-driver", "x11", "--log-file", str(stage / "godot.log")]
    if not args.no_xvfb:
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24"] + cmd
    log_path = stage / "bake.log"
    try:
        with log_path.open("w") as log:
            result = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        raise SystemExit(f"Bake timed out. No project outputs changed. Inspect {log_path}")
    report_path = stage / "sanctum_bake_report.json"
    if result.returncode or not report_path.is_file():
        raise SystemExit(f"Bake failed. No project outputs changed. Inspect {log_path}")
    report = json.loads(report_path.read_text())
    if not report.get("ok"):
        raise SystemExit(f"Bake failed: {report.get('error')}. Inspect {log_path}")
    baked_data = stage / data
    outputs = sorted(baked_data.parent.glob(data.stem + "*"))
    outputs = [p for p in outputs if p.is_file() and p.suffix in {".lmbake", ".exr", ".png", ".import"}]
    if not any(p.suffix == ".exr" for p in outputs):
        raise SystemExit(f"No EXR atlas was generated. No project outputs changed. Inspect {log_path}")
    for source in outputs + [stage / scene]:
        destination = project / source.relative_to(stage)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        print(f"Saved {destination.relative_to(project)} ({destination.stat().st_size:,} bytes)")
    report_destination = (project / data).with_suffix(".bake.json")
    report_destination.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print(f"Native editor log retained at {log_path}")


if __name__ == "__main__":
    main()
