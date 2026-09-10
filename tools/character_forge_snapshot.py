"""Freeze once, verify, or recover Starfall Character Forge v1.
Create: blender -b --python tools/character_forge_snapshot.py -- --create
Verify: python tools/character_forge_snapshot.py --verify (or --compare-live)
Recover: python tools/character_forge_snapshot.py --extract EMPTY_DIRECTORY
Recovery never overwrites files. The current local-only package uses tar.xz;
the original manifest and every frozen member retain their original bytes.
"""
import argparse, hashlib, json, lzma, pathlib, platform, subprocess, sys, tarfile, zipfile
from datetime import datetime, timezone
ROOT = pathlib.Path(__file__).resolve().parent.parent
DEST = ROOT / 'art_source/workflows/starfall-character-forge-v1'
ARCHIVE = DEST / 'starfall-character-forge-v1.zip'
CLASSES = ('ember', 'luminary', 'fulcrum', 'vanguard')
GODOT = pathlib.Path('C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def dump(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')

def capture_contracts():
    import bpy, numpy
    result = {'schema': 1, 'matrix_layout': 'row-major 16 floats; Blender bone matrix_basis',
              'units': 'metres', 'up': 'Z', 'forward': '-Y', 'classes': {}}
    for slug in CLASSES:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art_source' / (slug + '.blend')))
        rig = bpy.data.objects[slug.title() + '_Rig']
        scene = bpy.context.scene
        flatten = lambda matrix: [float(v) for row in matrix for v in row]
        bones = {b.name: {'parent': b.parent.name if b.parent else None,
                          'deform': b.use_deform, 'head': list(b.head_local),
                          'tail': list(b.tail_local), 'rest_matrix': flatten(b.matrix_local)}
                 for b in rig.data.bones}
        meshes = {}
        for ob in scene.objects:
            if ob.type != 'MESH' or not any(m.type == 'ARMATURE' and m.object == rig for m in ob.modifiers):
                continue
            meshes[ob.name] = {'vertices': len(ob.data.vertices),
                              'triangles': sum(len(p.vertices) - 2 for p in ob.data.polygons),
                              'materials': [m.name for m in ob.data.materials],
                              'uv_layers': [uv.name for uv in ob.data.uv_layers],
                              'groups': [g.name for g in ob.vertex_groups],
                              'max_weight_error': max(abs(sum(g.weight for g in v.groups)-1) for v in ob.data.vertices)}
        clips = {}
        for track in rig.animation_data.nla_tracks:
            for other in rig.animation_data.nla_tracks:
                other.mute = other != track
            assert len(track.strips) == 1, track.name
            strip = track.strips[0]
            frames = {}
            for frame in range(int(strip.frame_start), int(strip.frame_end) + 1):
                scene.frame_set(frame)
                frames[str(frame)] = {p.name: flatten(p.matrix_basis) for p in rig.pose.bones}
            clips[track.name] = {'first': strip.frame_start, 'last': strip.frame_end,
                                 'seconds': (strip.frame_end-strip.frame_start)/(scene.render.fps/scene.render.fps_base),
                                 'bone_frames': frames}
        result['classes'][slug] = {'fps': scene.render.fps, 'fps_base': scene.render.fps_base,
                                  'bones': bones, 'meshes': meshes, 'clips': clips}
        print('Captured', slug, len(bones), 'bones;', len(clips), 'clips', flush=True)
    environment = {'captured_utc': datetime.now(timezone.utc).isoformat(),
                   'platform': platform.platform(), 'python': sys.version,
                   'numpy': numpy.__version__, 'blender': bpy.app.version_string,
                   'blender_build_hash': bpy.app.build_hash.decode(),
                   'blender_executable': bpy.app.binary_path,
                   'blender_executable_sha256': sha(pathlib.Path(bpy.app.binary_path)),
                   'godot_executable': str(GODOT), 'godot_executable_sha256': sha(GODOT),
                   'godot_version': subprocess.check_output([str(GODOT), '--version'], text=True).strip(),
                   'review_renderer': 'OpenGL Compatibility; NVIDIA RTX 5060 Ti; driver 616.64 (recorded review)'}
    return result, environment

def source_paths():
    paths = set()
    required = ['docs/STARFALL_CHARACTER_FORGE_V1.md', 'tools/character_forge_snapshot.py',
                'tools/skills/starfall-character-forge/SKILL.md', 'project.godot', 'arena.tscn',
                'art_source/.gdignore', 'art_source/vanguard_hammer_weapon.blend']
    for slug in CLASSES:
        required += ['art_source/' + slug + '.blend', 'art_source/references/' + slug + '.png',
                     'assets/characters/' + slug + '.glb', 'tools/build_' + slug + '.py',
                     'tools/verify_' + slug + '.py']
        paths.update((ROOT / 'assets/characters').glob(slug + '*'))
        paths.update(p for p in (ROOT / 'tools').glob('*' + slug + '*') if p.is_file())
    for rel in required:
        path = ROOT / rel
        if not path.is_file():
            raise FileNotFoundError(path)
        paths.add(path)
    for folder in ['scripts', 'shaders', 'tests', 'scenes']:
        paths.update(p for p in (ROOT / folder).rglob('*') if p.is_file())
    for name in ['CHARACTER_PIPELINE.md', 'VANGUARD_REFERENCE_REBUILD.md', 'VANGUARD_REBUILD_BRIEF.md',
                 'CONTEXT.md', 'ART_DIRECTION.md', 'TECHNICAL_ARCHITECTURE.md']:
        paths.add(ROOT / 'docs' / name)
    paths.add(ROOT / 'artifacts/vanguard_before_reference/art_source/vanguard.blend')
    for folder in ['ember', 'luminary', 'fulcrum', 'vanguard_rebuild_20260908']:
        area = ROOT / 'artifacts' / folder
        for pattern in ['*report.json', '*verification.json', 'front.png', 'back.png', 'walk*.png',
                        'run*.png', 'strike.png', 'godot-walk.png', 'godot-idle.png',
                        'godot-sanctum-portrait-review.png', 'presentation.log', 'combat.log', 'art-test.log', 'verify.log']:
            paths.update(area.glob(pattern))
    return sorted(p for p in paths if p.is_file())

def safe_member(name):
    member = pathlib.PurePosixPath(name)
    if (not name or member.is_absolute() or '..' in member.parts or ':' in name
            or '\\' in name or member.as_posix() != name):
        raise ValueError('Unsafe archive member: ' + name)
    return member

def package_info(package):
    manifest_path = package / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    storage_path = package / 'storage.json'
    if not storage_path.exists():
        storage = {'format': 'zip', 'archive': manifest['archive'],
                   'archive_sha256': manifest['archive_sha256'], 'contracts': 'contracts.json'}
    else:
        storage = json.loads(storage_path.read_text(encoding='utf-8'))
        if (storage['schema'] != 1 or storage['format'] != 'tar.xz'
                or storage['manifest_sha256'] != sha(manifest_path)
                or storage['original_archive_sha256'] != manifest['archive_sha256']):
            raise ValueError('Compressed storage metadata does not match the original manifest')
    for key in ('archive', 'contracts'):
        if len(safe_member(storage[key]).parts) != 1:
            raise ValueError('Storage files must be directly inside the package')
    archive_path = package / storage['archive']
    if sha(archive_path) != storage['archive_sha256']:
        raise ValueError('Archive SHA-256 does not match; do not use this package.')
    if 'archive_bytes' in storage and archive_path.stat().st_size != storage['archive_bytes']:
        raise ValueError('Archive size differs from storage metadata')
    return manifest, storage, archive_path

def members(archive_path, format_name):
    if format_name == 'zip':
        with zipfile.ZipFile(archive_path) as archive:
            for info in archive.infolist():
                if info.is_dir():
                    raise ValueError('Unexpected directory member: ' + info.filename)
                yield info.filename, archive.read(info)
    else:
        with tarfile.open(archive_path, 'r|xz') as archive:
            for info in archive:
                if not info.isfile():
                    raise ValueError('Only regular files are allowed: ' + info.name)
                with archive.extractfile(info) as stream:
                    yield info.name, stream.read()

def checked_members(manifest, storage, archive_path):
    expected, seen = manifest['files'], set()
    for name, data in members(archive_path, storage['format']):
        safe_member(name)
        if name not in expected or name in seen:
            raise ValueError('Unexpected or duplicate archive member: ' + name)
        record = expected[name]
        if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
            raise ValueError('Archive file mismatch: ' + name)
        seen.add(name)
        yield name, data
    if seen != set(expected):
        raise ValueError('Archive member list differs from manifest')

def verify(compare=False, package=DEST):
    manifest, storage, archive_path = package_info(package)
    for _ in checked_members(manifest, storage, archive_path):
        pass
    expected = manifest['files']
    contract_rel = (DEST / 'contracts.json').relative_to(ROOT).as_posix()
    contract_path = package / storage['contracts']
    if storage['format'] == 'tar.xz':
        if sha(contract_path) != storage['contracts_sha256']:
            raise ValueError('Compressed contracts checksum mismatch')
        with lzma.open(contract_path, 'rb') as stream:
            contract_sha = hashlib.file_digest(stream, 'sha256').hexdigest()
    else:
        contract_sha = sha(contract_path)
    if contract_sha != expected[contract_rel]['sha256']:
        raise ValueError('External contracts differ from their frozen archived copy')
    print('FORGE_V1_VERIFIED', len(expected), 'files;', archive_path.stat().st_size, 'archive bytes')
    if compare:
        changes = []
        for rel, record in expected.items():
            if rel == contract_rel:
                continue  # Package contracts were checked above, including compressed storage.
            path = ROOT / rel
            if not path.is_file():
                changes.append({'path': rel, 'state': 'missing'})
            elif sha(path) != record['sha256']:
                changes.append({'path': rel, 'state': 'changed'})
        print(json.dumps({'live_differences': changes, 'count': len(changes)}, indent=2))
    return manifest

def extract(destination, package=DEST):
    destination = destination.resolve()
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise FileExistsError('Recovery requires an empty directory: ' + str(destination))
    verify(package=package)  # Fully validate before creating any recovered files.
    manifest, storage, archive_path = package_info(package)
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in checked_members(manifest, storage, archive_path):
        target = destination.joinpath(*safe_member(name).parts)
        if not target.resolve().is_relative_to(destination):
            raise ValueError('Recovery target escapes destination: ' + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
    print('FORGE_V1_EXTRACTED', len(manifest['files']), 'files to', destination)

def create():
    for path in [ARCHIVE, DEST / 'manifest.json', DEST / 'contracts.json']:
        if path.exists():
            raise FileExistsError('Version 1 exists or creation was interrupted; inspect before proceeding: ' + str(path))
    files = source_paths()
    before = {p: sha(p) for p in files}
    contracts, environment = capture_contracts()
    DEST.mkdir(parents=True, exist_ok=True)
    dump(DEST / 'contracts.json', contracts)
    files.append(DEST / 'contracts.json')
    records = {}
    with zipfile.ZipFile(ARCHIVE, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            rel = path.relative_to(ROOT).as_posix()
            data = path.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            if path in before and digest != before[path]:
                raise RuntimeError('Live file changed during capture: ' + rel)
            archive.writestr(rel, data)
            records[rel] = {'sha256': digest, 'bytes': len(data)}
    manifest = {'schema': 1, 'name': 'Starfall Character Forge', 'version': 1,
                'archive': ARCHIVE.name, 'archive_sha256': sha(ARCHIVE), 'environment': environment,
                'scope': 'Four current characters, references, maps/imports, builders, animation contracts, shared integration code, tests and review evidence; not a full game/application backup.',
                'files': records}
    dump(DEST / 'manifest.json', manifest)
    verify(compare=True)

if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--create', action='store_true')
    group.add_argument('--verify', action='store_true')
    group.add_argument('--compare-live', action='store_true')
    group.add_argument('--extract', type=pathlib.Path, metavar='EMPTY_DIRECTORY')
    parser.add_argument('--package', type=pathlib.Path, default=DEST,
                        help='Read a package copied to another location (not for --create).')
    mode = parser.parse_args(args)
    if mode.create:
        if mode.package.resolve() != DEST.resolve():
            parser.error('--package cannot relocate historical creation')
        create()
    elif mode.extract is not None:
        extract(mode.extract, package=mode.package)
    else:
        verify(compare=mode.compare_live, package=mode.package)
