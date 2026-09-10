"""Freeze/recover the required Forge v2 hitbox extension and check class evidence.

This is an additive package. Never rewrites the original Fulcrum snapshot or
installs archived gameplay files. Class checking covers hitboxes, not art approval.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import zipfile

import model_forge_snapshot as base

ROOT = base.ROOT
PACKAGE = base.PACKAGE / 'extensions/hitboxes-v1'
LIMIT = 32 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8') as stream:
        stream.write(json.dumps(value, indent=2, allow_nan=False)+'\n')


def member(name):
    require(isinstance(name, str) and name and '\\' not in name and ':' not in name,
            'Invalid archive path')
    path = PurePosixPath(name)
    require(not path.is_absolute() and all(p not in ('..', '.git') for p in path.parts), name)
    require(not any(token in name for token in base.REJECTED_NAMES), 'Rejected revision path: '+name)
    return Path(*path.parts)


def local(name):
    require(isinstance(name, str) and name, 'Missing project path')
    path = (ROOT / member(name)).resolve()
    require(path.is_relative_to(ROOT.resolve()), 'Path leaves project: '+name)
    return path


def sources():
    paths = {}
    def add(name, group):
        require(local(name).is_file(), 'Missing source: '+name)
        paths[name] = group
    def scripts(names, group):
        for name in names:
            add(name, group)
            if local(name+'.uid').is_file():
                add(name+'.uid', group)
    for name in ['WORKFLOW.md', 'contract.json', 'new_character.template.json']:
        add((PACKAGE/name).relative_to(ROOT).as_posix(), 'workflow')
    add((base.PACKAGE/'CURRENT.md').relative_to(ROOT).as_posix(), 'workflow')
    scripts(['scripts/body_hitboxes.gd', 'scripts/hitbox_pose.gd', 'scripts/character_asset_cache.gd',
             'tools/build_hitbox_rigs.gd', 'tools/hitbox_review.gd',
             'tools/hitbox_benchmark.gd', 'tools/hitbox_benchmark_arena.gd'], 'hitbox_source')
    scripts(['scripts/aimed_combat.gd', 'scripts/aim_reticle.gd'], 'aiming_reference_only')
    scripts(['tests/hitbox_pose_test.gd', 'tests/aimed_combat_test.gd',
             'tests/aimed_network_peer.gd', 'tests/server_runtime_test.gd'], 'validation')
    scripts(['scripts/'+name+'.gd' for name in ['arena', 'combatant', 'model_forge_art',
             'fulcrum_art', 'ember_art', 'luminary_art', 'outlaw_art', 'vanguard_authored',
             'model_forge_jump_pose', 'model_forge_pose_blend', 'model_forge_equipment',
             'fulcrum_jump_pose', 'fulcrum_pose_blend', 'outlaw_equipment', 'outlaw_mechanics',
             'vanguard_strike']],
            'integration_context_only')
    for name in ['tools/measure_hitboxes.py', 'tests/run_aimed_network.py',
                 'tests/run_ember_network.py',
                 'tools/model_forge_hitbox_snapshot.py', 'tests/check_suite.sh',
                 'docs/AIMED_COMBAT_FOUNDATION.md']:
        add(name, 'tools_and_notes')
    add('tools/skills/starfall-character-forge/SKILL.md', 'discovery')
    for path in sorted((ROOT/'assets/hitboxes').iterdir()):
        if path.is_file() and path.suffix in ('.scn', '.json'):
            add(path.relative_to(ROOT).as_posix(), 'reference_rigs')
    for name in ['ember', 'luminary', 'fulcrum', 'vanguard', 'outlaw', 'outlaw-roll', 'outlaw-backflip', 'all-classes']:
        add('artifacts/aimed-combat/review/'+name+'.png', 'review_reference')
    for name in ['benchmark-comparison.json', 'baseline-ticks.csv', 'fitted-ticks.csv',
                 'poses.log', 'combat.log', 'server-runtime.log', 'compatibility.log', 'network.log']:
        add('artifacts/aimed-combat/'+name, 'approval_evidence')
    return paths


def create():
    base.verify()
    require(not (PACKAGE/'manifest.json').exists() and not (PACKAGE/'baseline.zip').exists(),
            'Completed extension exists; use a new extension revision')
    inventory = sources()
    scratch = ROOT/'artifacts/forge-v2-hitbox-workflow'
    scratch.mkdir(parents=True, exist_ok=True)
    archive_path = scratch/'extension-build.zip'
    files = {}
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, group in sorted(inventory.items()):
            path = local(name)
            files[name] = {'sha256':sha(path), 'bytes':path.stat().st_size, 'group':group}
            archive.write(path, name)
    require(archive_path.stat().st_size < LIMIT, 'Split the extension before exceeding 32 MiB')
    with archive_path.open('rb') as source, (PACKAGE/'baseline.zip').open('xb') as output:
        shutil.copyfileobj(source, output)
    write(PACKAGE/'manifest.json', {
        'schema':1, 'extension':'hitboxes-v1', 'required':True, 'approved':'2026-09-10',
        'baseline_manifest_sha256':sha(base.PACKAGE/'manifest.json'),
        'archive':{'file':'baseline.zip', 'sha256':sha(archive_path), 'bytes':archive_path.stat().st_size},
        'files':files})
    verify(False)


def verify(check_base=True):
    if check_base:
        base.verify()
    manifest = read(PACKAGE/'manifest.json')
    require(manifest['required'] and manifest['extension'] == 'hitboxes-v1', 'Wrong extension')
    require(manifest['baseline_manifest_sha256'] == sha(base.PACKAGE/'manifest.json'), 'Base mismatch')
    record = manifest['archive']
    require(record['file'] == 'baseline.zip', 'Unexpected archive name')
    archive_path = PACKAGE/record['file']
    require(archive_path.stat().st_size == record['bytes'] < LIMIT and sha(archive_path) == record['sha256'],
            'Extension archive changed')
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)) and set(names) == set(manifest['files']), 'Inventory mismatch')
        for name, info in manifest['files'].items():
            member(name)
            require(archive.getinfo(name).file_size == info['bytes'], 'Size mismatch: '+name)
            with archive.open(name) as stream:
                require(hashlib.file_digest(stream, 'sha256').hexdigest() == info['sha256'], 'Hash mismatch: '+name)
            if info['group'] == 'workflow':
                require(local(name).is_file() and sha(local(name)) == info['sha256'], 'Frozen workflow changed: '+name)
    print('MODEL_FORGE_V2_HITBOX_EXTENSION_VERIFIED', len(manifest['files']), 'files;', record['bytes'], 'archive bytes')
    return manifest


def extract(destination):
    manifest = verify()
    target = local(destination)
    require(target != ROOT and (not target.exists() or not any(target.iterdir())), 'Use a new empty stage')
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(PACKAGE/'baseline.zip') as archive:
        for name in manifest['files']:
            path = target/member(name)
            require(path.resolve().is_relative_to(target), 'Extraction leaves stage')
            path.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(name) as source, path.open('xb') as output:
                shutil.copyfileobj(source, output)
    package_copy = target/PACKAGE.relative_to(ROOT)
    for name in ['manifest.json', 'baseline.zip']:
        shutil.copy2(PACKAGE/name, package_copy/name)
    print('MODEL_FORGE_V2_HITBOX_EXTENSION_EXTRACTED', target)


def new_record(slug, destination):
    manifest = verify()
    require(re.fullmatch('[a-z][a-z0-9_]*', slug), 'Use a lowercase class slug')
    record = read(PACKAGE/'new_character.template.json')
    record.update(class_slug=slug, baseline_manifest_sha256=sha(base.PACKAGE/'manifest.json'),
                  baseline_archive_sha256=read(base.PACKAGE/'manifest.json')['archive']['sha256'])
    record['workflow_extensions']['hitboxes-v1'] = {
        'manifest_sha256':sha(PACKAGE/'manifest.json'), 'archive_sha256':manifest['archive']['sha256'],
        'contract_sha256':sha(PACKAGE/'contract.json')}
    record['hitboxes'].update(source_glb=f'assets/characters/{slug}.glb', rig=f'assets/hitboxes/{slug}_rig.scn')
    write(local(destination), record)
    print('MODEL_FORGE_V2_CLASS_RECORD_CREATED', destination, '(completion evidence still required)')


def evidence(info):
    path = local(info.get('path'))
    require(path.is_file() and sha(path) == info.get('sha256'), 'Evidence missing/changed: '+str(path))
    return path


def clean_log(path):
    # PowerShell Tee-Object can write UTF-16; Godot --log-file writes UTF-8.
    data = path.read_bytes()
    text = data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    require(not re.search(r'SCRIPT ERROR:|^ERROR:|^FAIL(?:ED)?:', text, re.M), 'Error in '+str(path))
    return text


def check_record(destination):
    manifest = verify()
    record = read(local(destination))
    frozen = record['workflow_extensions']['hitboxes-v1']
    require(frozen == {'manifest_sha256':sha(PACKAGE/'manifest.json'),
                      'archive_sha256':manifest['archive']['sha256'],
                      'contract_sha256':sha(PACKAGE/'contract.json')}, 'Record uses another extension')
    require(record['baseline_manifest_sha256'] == sha(base.PACKAGE/'manifest.json') and
            record['baseline_archive_sha256'] == read(base.PACKAGE/'manifest.json')['archive']['sha256'],
            'Record uses another art baseline')
    box = record['hitboxes']
    contract = read(PACKAGE/'contract.json')
    require(box['required'] is True, 'Hitbox step is required')
    for key in ['source', 'rig', 'definitions']:
        name = box['source_glb'] if key == 'source' else box[key]
        require(sha(local(name)) == box[key+'_sha256'], 'Stale '+key+' hash')
    exported = read(local(box['rig_manifest']))['classes'][record['class_display_name']]
    require(exported['source_sha256'] == box['source_sha256'] and exported['rig_sha256'] == box['rig_sha256'],
            'Compact rig does not match the final model')
    radii = box['radii_m']
    require(len(radii) == 19 and all(isinstance(r, (int, float)) and not isinstance(r, bool) and
                                    math.isfinite(r) and r > 0 for r in radii), 'Need 19 finite positive radii')
    profile = contract['body']['radii_m'].get(box['profile'])
    require(profile == radii or bool(box['fit_adjustments']), 'Explain a custom fit')
    logs = {}
    for key, label in contract['validation']['required_suite_labels'].items():
        logs[key] = clean_log(evidence(box['tests'][key]))
        counts = re.findall(re.escape(label)+r': (\d+) passed / (\d+) total', logs[key])
        require(counts and all(int(a) > 0 and a == b for a,b in counts), 'Suite did not pass: '+label)
    errors = re.findall(r'Maximum body endpoint difference: ([0-9.eE+-]+) meters', logs['pose'])
    maximum = box['maximum_pose_error_m']
    require(errors and isinstance(maximum, (float, int)) and math.isfinite(maximum) and
            0 <= maximum < contract['validation']['maximum_pose_error_m'] and
            math.isclose(max(map(float, errors)), maximum, abs_tol=1e-9), 'Pose error missing/mismatched/too large')
    require(set(contract['validation']['common_poses']) <= set(box['checked_poses']), 'Common pose review incomplete')
    require(set(box['special_moves']) <= set(box['checked_poses']), 'Special-move review incomplete')
    compatibility = box['server_compatibility']
    require(compatibility['actual_pose_verified'] is True and compatibility['engine_version'], 'Server pose compatibility unverified')
    clean_log(evidence(compatibility['evidence']))
    review = box['review']
    require(review['reviewed'] is True and review['notes'], 'Inspect and describe the actual fit pictures')
    images = [review['front_side']]+[review['special_moves'][pose] for pose in box['special_moves']]
    for item in images:
        require(evidence(item).read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), 'Expected an actual PNG review')
    for field in ['before_manifest', 'installed_manifest']:
        require(local(record['installation'][field]).is_file(), 'Missing reversal record: '+field)
    print('MODEL_FORGE_V2_HITBOX_RECORD_PASSED', record['class_display_name'],
          '19 volumes; verified outputs, tests, compatibility and reviewed pictures; original art checks still required')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--create', action='store_true')
    mode.add_argument('--verify', action='store_true')
    mode.add_argument('--extract')
    mode.add_argument('--new-record')
    mode.add_argument('--check-record')
    parser.add_argument('--record')
    args = parser.parse_args()
    if args.create: create()
    elif args.verify: verify()
    elif args.extract: extract(args.extract)
    elif args.new_record:
        require(args.record, '--new-record needs --record PROJECT_RELATIVE_PATH')
        new_record(args.new_record, args.record)
    else: check_record(args.check_record)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, AssertionError) as error:
        print('MODEL_FORGE_V2_HITBOX_ERROR:', error, file=sys.stderr)
        sys.exit(1)
