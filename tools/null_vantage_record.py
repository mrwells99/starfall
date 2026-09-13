"""Seal evidence for the local, runtime-only Vantage revision (never publishes)."""
from pathlib import Path
import hashlib
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / 'artifacts/null-vantage-20260912'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

def evidence(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}

def log(path):
    text = path.read_text(encoding='utf-8-sig')
    assert not re.search(r'SCRIPT ERROR:|^ERROR:|^FAIL(?:ED)?:', text, re.M), path
    return text

record = read(STAGE / 'forge-record.json')
original = read(ROOT / 'art_source/null_ual/forge-record.json')
contract = read(ROOT / 'art_source/workflows/starfall-model-forge-v2/extensions/hitboxes-v1/contract.json')
assert sha(ROOT / 'assets/characters/null.glb') == original['hitboxes']['source_sha256']
assert sha(ROOT / 'assets/hitboxes/null_rig.scn') == original['hitboxes']['rig_sha256']
assert sha(ROOT / 'art_source/null.blend') == sha(ROOT / 'artifacts/null-forge-v2/candidate/null.blend')
logs = {}
for name in ['pose', 'server', 'combat', 'abilities', 'vantage-mechanics', 'vantage-presentation', 'general-presentation']:
    path = STAGE / (name + '.log')
    text = log(path)
    counts = re.findall(r': (\d+) passed / (\d+) total', text)
    assert counts and all(int(a) > 0 and a == b for a, b in counts), path
    logs[name] = evidence(path)
versions = sorted((STAGE / 'server-compat').glob('pose-*.json'))
assert len(versions) == 2
samples = [read(path) for path in versions]
assert len(samples[0]) == len(samples[1]) == 432
maximum = max(math.dist(a, b) for x, y in zip(*samples) for a, b in zip(x, y))
assert maximum < .0005
compat = [log(STAGE / ('compat-' + version + '.log')) for version in ['451', '472']]
assert all('failures=0' in text for text in compat)
(STAGE / 'compatibility.log').write_text('\n'.join(compat) + f'Cross-engine maximum endpoint difference: {maximum} meters\n', encoding='utf-8')
record.update(class_display_name='Null', stage_directory=STAGE.relative_to(ROOT).as_posix(), reference_paths=original['reference_paths'])
for field in ['design', 'inputs', 'tools', 'deliverables']:
    record[field] = original[field]
record['inputs']['unchanged_source_glb'] = evidence(ROOT / 'assets/characters/null.glb')
record['inputs']['unchanged_editable_blend'] = evidence(ROOT / 'art_source/null.blend')
record['intentional_exceptions']['reason'] = 'Runtime-only Vantage special layer; no rest-anatomy, mesh, material, or inherited-clip edits. User also requested airborne casting and faster long dives; ease-out rise preserves 5m/.5s.'
record['intentional_exceptions']['core_motion_bones'] = ['Vantage only: hips, spine.001, spine.002, neck, upper arms, forearms, hands, thighs, shins']
record['deliverables']['runtime_modules'] = ['scripts/null_art.gd', 'scripts/null_vantage_pose.gd', 'scripts/null_mechanics.gd']
record['deliverables']['viewer'] = 'tools/null_vantage_review.gd'
record['validation'] = {
    'source_checks': original['validation']['source_checks'],
    'animation_contract': original['validation']['animation_contract'],
    'skin_checks': 'Original skin/rest anatomy and 32 core clips unchanged: source GLB and editable Blender file are hash-identical to verified accepted assets.',
    'materials_export': 'No asset export or material changes.',
    'weapon_grip': 'Existing hand-parented blades retained; measured hand-side ordering and full server/visible endpoint parity.',
    'godot_tests': logs,
    'visual_review': 'Inspected actual front/side runtime sequence and fitted hitbox images for idle, lift, anticipation, dive and recovery. Secondary monitor0 (primary1), no focus, Compatibility renderer,30FPS.',
    'limitations': ['No human online playtest or owner aesthetic acceptance claimed.', 'Inherited cloth bones are not cloth simulation.', 'Shared instantaneous stun sway is unchanged; interruption test isolates bone pose in host space.'],
}
box = record['hitboxes']
box.update(radii_m=contract['body']['radii_m']['standard'], fit_adjustments='None: existing 19 capsules, movement capsule, padding and AIM_SCALE unchanged.',
           source_sha256=sha(ROOT / box['source_glb']), rig_sha256=sha(ROOT / box['rig']), definitions_sha256=sha(ROOT / box['definitions']),
           maximum_pose_error_m=0.0, checked_poses=contract['validation']['common_poses'] + ['lift', 'dive', 'recover'], special_moves=['lift', 'dive', 'recover'])
box['tests'] = {key: logs[key] for key in ['pose', 'server', 'combat']}
box['server_compatibility'] = {'engine_version': '4.5.1 and 4.7.2', 'actual_pose_verified': True, 'evidence': evidence(STAGE / 'compatibility.log')}
box['review'] = {'front_side': evidence(STAGE / 'review/hitboxes-0.png'),
                 'special_moves': {name: evidence(STAGE / f'review/hitboxes-{i}.png') for name, i in [('lift', 2), ('dive', 5), ('recover', 7)]},
                 'reviewed': True, 'notes': 'Body capsules follow the separated arms, pitched torso and trailing legs. Blades, hood tip and cloth remain outside damage volumes. Golden head capsule retains normal damage.'}
box['performance_notes'] = 'Bone indices are cached at build; shared pose-only rig remains mesh-free. Server guards pass; no measured server-performance improvement claimed.'
before = {p.relative_to(STAGE / 'before').as_posix(): sha(p) for folder in ['scripts', 'tests', 'docs'] for p in (STAGE / 'before' / folder).rglob('*') if p.is_file()}
new = ['scripts/null_vantage_pose.gd', 'tests/null_vantage_presentation_test.gd', 'tools/null_vantage_review.gd', 'tools/null_vantage_record.py']
new += [name + '.uid' for name in new if (ROOT / (name + '.uid')).is_file()]
write(STAGE / 'before/manifest.json', before)
write(STAGE / 'installed-manifest.json', {'changed_paths': {path: {'before_sha256': old, 'installed_sha256': sha(ROOT / path)} for path, old in before.items()}, 'new_paths': {path: sha(ROOT / path) for path in new}})
record['installation'] = {'before_manifest': 'artifacts/null-vantage-20260912/before/manifest.json', 'installed_manifest': 'artifacts/null-vantage-20260912/installed-manifest.json', 'new_paths': new,
                          'owner_feedback': 'Requested natural rise/airborne motion, non-crossed diving arms, faster long-range dives and airborne use. New visual result is pending owner review.',
                          'rollback': 'Compare installed hashes before restoring only the listed backed-up paths; remove only unchanged listed new files. Preserve all later and unrelated edits. No Git publication.'}
write(STAGE / 'forge-record.json', record)
print('NULL_VANTAGE_RECORD_READY cross-engine error', maximum, 'meters;', len(before), 'backed-up paths')
