"""Record/check/revert this isolated hitbox task, preserving subsequent edits."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT/'artifacts/aimed-combat'
MANIFEST = STAGE/'installation.json'
CHANGED = ['.github/workflows/deploy.yml', 'scripts/arena.gd', 'scripts/combatant.gd',
           'scripts/model_forge_art.gd', 'scripts/ember_art.gd', 'scripts/luminary_art.gd',
           'scripts/fulcrum_art.gd', 'scripts/outlaw_art.gd', 'scripts/vanguard_authored.gd',
           'tests/server_runtime_test.gd']
NEW_SCRIPTS = ['scripts/aim_reticle', 'scripts/aimed_combat', 'scripts/body_hitboxes',
               'scripts/character_asset_cache', 'scripts/hitbox_pose', 'tests/aimed_combat_test',
               'tests/aimed_network_peer', 'tests/hitbox_pose_test', 'tools/build_hitbox_rigs',
               'tools/hitbox_benchmark', 'tools/hitbox_benchmark_arena', 'tools/hitbox_review']

def checked(name):
    path = (ROOT/name).resolve()
    if not path.is_relative_to(ROOT):
        raise RuntimeError('Path leaves project: '+name)
    return path

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def record():
    paths = CHANGED + [name+extension for name in NEW_SCRIPTS for extension in ['.gd','.gd.uid']]
    paths += ['tests/run_aimed_network.py', 'tools/measure_hitboxes.py', 'tools/hitbox_record.py',
              'docs/AIMED_COMBAT_FOUNDATION.md', 'assets/hitboxes/manifest.json']
    paths += ['assets/hitboxes/'+title+'_rig.scn' for title in ['ember','luminary','fulcrum','vanguard','outlaw']]
    entries = {}
    for name in paths:
        path = checked(name)
        backup = STAGE/'before'/name
        if name in CHANGED and not backup.is_file():
            raise RuntimeError('Missing original backup: '+name)
        entries[name] = {'installed_sha256': digest(path),
                         'before_sha256': digest(backup) if backup.is_file() else None,
                         'bytes': path.stat().st_size}
    MANIFEST.write_text(json.dumps({'task':'Body hitbox and aimed cooldown foundation',
                                   'files':entries},indent=2))
    print('HITBOX_INSTALLATION_RECORDED',len(entries),'paths')

def rollback(check_only):
    entries = json.loads(MANIFEST.read_text())['files']
    errors = []
    for name, info in entries.items():
        path = checked(name)
        if not path.is_file() or digest(path) != info['installed_sha256']:
            errors.append('Changed after installation: '+name)
        if info['before_sha256']:
            backup = STAGE/'before'/name
            if not backup.is_file() or digest(backup) != info['before_sha256']:
                errors.append('Backup mismatch: '+name)
    if errors:
        raise RuntimeError('\n'.join(errors))
    if check_only:
        print('HITBOX_ROLLBACK_CHECK_PASSED',len(entries),'paths; no files changed')
        return
    for name, info in entries.items():
        path = checked(name)
        if info['before_sha256']:
            shutil.copy2(STAGE/'before'/name,path)
        else:
            path.unlink()
    print('HITBOX_ROLLBACK_COMPLETE; restart the game; audit records retained')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-rollback', action='store_true')
    parser.add_argument('--rollback', action='store_true')
    args = parser.parse_args()
    if args.check_rollback or args.rollback:
        rollback(args.check_rollback)
    else:
        record()
