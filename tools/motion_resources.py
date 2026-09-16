"""Portable entry point for the imported MotionLab shelf and metadata inventory.

Original sources/catalogues remain local and unchanged. No assets are downloaded.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import sys
import types

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_NAMES = ('animation_cache', 'animation_references', 'animation_sources', 'animation_tools',
                  'diagnostics', 'fulcrum-redesign', 'merge_backups', 'workflow_backups', 'workflow_tools', 'workflows')


def resource(name: str, root: Path = ROOT) -> Path:
    for candidate in (root / 'local_resources' / name, root / name):
        if candidate.exists():
            return candidate
    return root / 'local_resources' / name


def motionlab(root: Path = ROOT) -> Path:
    for name in ('starforge-motionlab', 'starfall-motion-lab'):
        candidate = root / 'art_source/workflows' / name
        if candidate.is_dir():
            return candidate
    raise FileNotFoundError('Copy the shared MotionLab folder into art_source/workflows/starforge-motionlab first.')


def local_path(root: Path, value: str, base: Path | None = None) -> Path:
    """Resolve inherited Windows/project paths without accepting paths outside root."""
    if not value or '://' in value:
        raise ValueError('Expected a local file path')
    value = value.replace('\\', '/')
    parts = value.split('/')
    if 'local_resources' in parts:
        parts = parts[parts.index('local_resources') + 1:]
        if not parts or parts[0] not in RESOURCE_NAMES:
            raise ValueError(f'Unknown resource directory: {value}')
        path = resource(parts[0], root).joinpath(*parts[1:])
    elif re.match(r'^[A-Za-z]:/', value):
        anchor = next((i for i, part in enumerate(parts) if part in (*RESOURCE_NAMES, 'art_source')), None)
        if anchor is None:
            raise ValueError(f'Unmapped Windows path: {value}')
        path = root.joinpath(*parts[anchor:])
    else:
        path = Path(value)
        if not path.is_absolute():
            path = (base or root) / path
    path = path.resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f'Path outside project: {value}')
    return path


def shelf_module(root: Path = ROOT):
    guide = motionlab(root)
    source_path = guide / 'tools/reference_shelf.py'
    source = source_path.read_text(encoding='utf-8-sig')
    source = source.replace('root / "local_resources/animation_sources/final-pass"',
                            'resource("animation_sources", root) / "final-pass"')
    source = source.replace('root / "art_source/workflows/starfall-motion-lab"', 'motionlab(root)')
    source = source.replace('r["local_path"].replace("\\\\", "/").casefold()',
                            'str(checked_local(root, r["local_path"])).casefold()')
    module = types.ModuleType('portable_reference_shelf')
    module.__file__ = str(source_path)
    module.resource, module.motionlab = resource, motionlab
    exec(compile(source, str(source_path), 'exec'), module.__dict__)
    module.checked_local = local_path
    module.VIDEO_MANIFEST = str(resource('animation_references', root) / 'stunts-final/manifest.json')
    module.HTML = module.HTML.replace('<option value="1">1× (file speed)</option>',
                                     '<option value="1">1× (file speed)</option><option value="2">2×</option>')
    module.HTML = module.HTML.replace('open it in Kinovea', 'open it in a Linux media player or make an FFmpeg review proxy')
    return module


def doctor() -> dict:
    report = {'platform': sys.platform, 'root': str(ROOT), 'resources': {}, 'tools': {}}
    for name in RESOURCE_NAMES:
        path = resource(name)
        report['resources'][name] = {'path': str(path), 'present': path.exists()}
    for name in ('godot', 'blender', 'ffmpeg', 'ffprobe'):
        executable = shutil.which(os.environ.get(name.upper(), name))
        row = {'path': executable, 'present': executable is not None}
        if executable:
            flag = '-version' if name.startswith('ff') else '--version'
            result = subprocess.run([executable, flag], capture_output=True, text=True, timeout=20)
            row['version'] = (result.stdout or result.stderr).splitlines()[0]
            row['exit_code'] = result.returncode
        report['tools'][name] = row
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('doctor', 'shelf', 'inventory'))
    args, rest = parser.parse_known_args()
    if args.command == 'doctor':
        print(json.dumps(doctor(), indent=2))
    elif args.command == 'shelf':
        module = shelf_module()
        sys.argv = [module.__file__, '--root', str(ROOT), *rest]
        module.main()
    else:
        path = motionlab() / 'tools/inventory_motion.py'
        sys.argv = [str(path), '--source', str(resource('animation_sources')), *rest]
        runpy.run_path(str(path), run_name='__main__')


if __name__ == '__main__':
    main()
