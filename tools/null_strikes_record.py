"""Seal this runtime-only Null attack revision and its exact rollback evidence."""
from pathlib import Path
import hashlib, json, math, re

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT/'artifacts/null-strikes-v3'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path, value): path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')
def evidence(path): return {'path':path.relative_to(ROOT).as_posix(), 'sha256':sha(path)}

record = read(STAGE/'forge-record.json')
contract = read(ROOT/'art_source/workflows/starfall-model-forge-v2/extensions/hitboxes-v1/contract.json')
record.update(class_display_name='Null', stage_directory='artifacts/null-strikes-v3')
record['inputs']['costume_source'] = 'art_source/null.blend'
record['inputs']['costume_sha256'] = sha(ROOT/'art_source/null.blend')
record['inputs']['library'] = evidence(ROOT/'art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb')
record['intentional_exceptions']['reason'] = 'User requested fresh Temporal Strike and Backstab variations. Runtime-only upper-body jab/cut layer; existing Blender, visual GLB, compact rig, materials, rest anatomy and 35 embedded clips are unchanged.'
record['intentional_exceptions']['core_motion_bones'] = ['DEF-spine.001','DEF-spine.002','DEF-spine.003','DEF-neck','DEF-head'] + [f'DEF-{part}.{side}' for side in ['L','R'] for part in ['shoulder','upper_arm','forearm','hand']]
record['tools'].update(godot_version='4.7.2 desktop and 4.5.1 compatibility', renderer='Forward+ animation review; Compatibility hitbox review')
record['deliverables'].update(builder='tools/build_null_strike_library.gd', editable_blend='art_source/null.blend', glb='assets/characters/null.glb', runtime_modules=['scripts/null_art.gd','scripts/null_strike_pose.gd'], viewer='tools/null_strikes_review.gd', companions=['assets/animations/null_strikes_v3.tres'])
record['validation'].update(visual_review='Reviewed three-quarter and side animation frames plus actual front/side body volumes through both attacks. Blades follow hands; legs retain current gait. Captured-pose entry and smooth recovery. No owner acceptance claimed.', limitations=['New upper-body motions are a separate extracted AnimationLibrary and runtime layer, not baked into the existing Blender actions.', 'Cloth retains the existing baked motion.'])
box = record['hitboxes']
box.update(profile='standard', radii_m=contract['body']['radii_m']['standard'], fit_adjustments='Existing standard fit unchanged; runtime attacks use the same animator on visible and server rigs.', source_sha256=sha(ROOT/'assets/characters/null.glb'), rig_sha256=sha(ROOT/'assets/hitboxes/null_rig.scn'), definitions_sha256=sha(ROOT/'scripts/body_hitboxes.gd'), maximum_pose_error_m=0.0, checked_poses=contract['validation']['common_poses']+['stealth','lift','dive','stab','backstab'], special_moves=['stab','backstab'])
box['tests'] = {key:evidence(STAGE/f'{key}.log') for key in ['pose','server','combat']}
samples = [read(path) for path in sorted((STAGE/'server-compat').glob('pose-*.json'))]
assert len(samples)==2 and len(samples[0])==len(samples[1])==480
error = max(math.dist(a,b) for x,y in zip(*samples) for a,b in zip(x,y))
assert error < .0005
logs = [(STAGE/f'compat-{version}.log').read_text(encoding='utf-8-sig') for version in ['451','472']]
assert all('failures=0' in log and not re.search(r'^ERROR:|SCRIPT ERROR:',log,re.M) for log in logs)
(STAGE/'compatibility.log').write_text('\n'.join(logs)+f'Cross-engine maximum endpoint difference: {error} meters\n',encoding='utf-8')
box['server_compatibility'] = {'engine_version':'4.5.1 and 4.7.2', 'actual_pose_verified':True, 'evidence':evidence(STAGE/'compatibility.log')}
box['review'] = {'front_side':evidence(STAGE/'hitbox-review/null.png'), 'special_moves':{pose:evidence(STAGE/f'hitbox-review/null-{pose}.png') for pose in box['special_moves']}, 'reviewed':True, 'notes':'Actual model front/side overlays cover main-body limbs during the jab and cut; weapons and cloth remain excluded. The same upper-body module drives all 38 server and client endpoints.'}
before = {'scripts/null_art.gd':sha(STAGE/'before/null_art.gd'), 'tests/hitbox_pose_test.gd':sha(STAGE/'before/hitbox_pose_test.gd'), 'tests/aimed_combat_test.gd':sha(STAGE/'before/aimed_combat_test.gd')}
write(STAGE/'before/manifest.json', before)
added = ['scripts/null_strike_pose.gd','assets/animations/null_strikes_v3.tres','tools/build_null_strike_library.gd','tools/null_strikes_review.gd','tools/null_strikes_stage.py','tools/null_strikes_record.py','docs/NULL_STRIKE_VARIATION.md']
write(STAGE/'installed-manifest.json', {path:sha(ROOT/path) for path in list(before)+added})
record['installation'].update(before_manifest='artifacts/null-strikes-v3/before/manifest.json', installed_manifest='artifacts/null-strikes-v3/installed-manifest.json', new_paths=added, owner_feedback='New variation requested; awaiting user playtest.', rollback='Compare installed hashes before restoring the three backed-up files. To revert only the animation after later changes, restore only the attack layer/build/apply hunks from before/null_art.gd, preserving all Stealth, Haste, Regen and subsequent edits. Keep the server ground-shadow guard.')
write(STAGE/'forge-record.json', record)
print('NULL_STRIKES_RECORD_READY; cross-engine error', error)
