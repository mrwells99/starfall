"""Seal the runtime-only Outlaw Mend revision with measured evidence and rollback."""
from pathlib import Path
import hashlib, json, math, re

root = Path(__file__).resolve().parents[1]
stage = root/'artifacts/outlaw-mend-handwork'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path, value): path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')
def evidence(path): return {'path':path.relative_to(root).as_posix(), 'sha256':sha(path)}
record = read(stage/'forge-record.json')
contract = read(root/'art_source/workflows/starfall-model-forge-v2/extensions/hitboxes-v1/contract.json')
record.update(class_display_name='Outlaw',stage_directory='artifacts/outlaw-mend-handwork',reference_paths=['artifacts/mend-standing-living-preview/standing-handwork.gif'])
record['inputs'].update(costume_source='art_source/outlaw_ual/outlaw.blend',costume_sha256=sha(root/'art_source/outlaw_ual/outlaw.blend'))
record['inputs']['library'] = evidence(root/'art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb')
assert record['inputs']['library']['sha256'] == record['inputs']['library_sha256']
record['intentional_exceptions'].update(reason='User-approved standing hand-work study installed only for Outlaw Mend. Core rest anatomy, original 36 animations, source Blender/GLB, compact rig, hitbox dimensions and gameplay unchanged. Additional runtime clip uses original hand-work and breathing idle with adjusted arms and neck/head. Weapons temporarily scale out of view.',core_motion_bones=['53 source bones in new Mend clip only; existing clips unchanged'],new_equipment_controls=[])
record['tools'].update(godot_version='4.7.2 desktop and 4.5.1 server',renderer='Compatibility at 24 FPS on secondary display')
record['deliverables'].update(builder='tools/build_outlaw_mend.gd',editable_blend='art_source/outlaw_ual/outlaw.blend',glb='assets/characters/outlaw.glb',runtime_modules=['scripts/outlaw_art.gd','scripts/outlaw_equipment.gd','scripts/outlaw_mend_animation.gd'],viewer='tools/outlaw_mend_review.gd',companions=['assets/animations/outlaw_mend.tres','tools/mend_standing_preview.gd'])
record['validation'].update(source_checks='Frozen v2 77-file baseline and 91-file hitbox extension verified; library hash matches frozen source.',animation_contract='Original embedded clips and core rest matrices untouched; additional derived clip sampled at 30 FPS with closing loop keys.',skin_checks='Existing model and normalized skin unchanged.',materials_export='Existing materials and textures unchanged.',weapon_grip='Open authored hand-work during Mend; native grips and hand-parented weapon scales restore after finish/cancel.',godot_tests=[evidence(stage/(name+'.log')) for name in ['pose','server','combat','mend','presentation']],visual_review='Inspected actual Outlaw front/side model during Mend, idle, recovery and corresponding body volumes. No owner playtest acceptance claimed.',limitations=['New clip is an external Godot AnimationLibrary; it is not baked into the source Blender file.', 'Existing garment controls retain their last base pose during Mend.'])
box=record['hitboxes']
pose_log=(stage/'pose.log').read_text(encoding='utf-8-sig')
maximum=float(re.search(r'Maximum body endpoint difference: ([0-9.eE+-]+) meters',pose_log).group(1))
box.update(profile='standard',radii_m=contract['body']['radii_m']['standard'],fit_adjustments='Unchanged standard fit.',source_sha256=sha(root/'assets/characters/outlaw.glb'),rig_sha256=sha(root/'assets/hitboxes/outlaw_rig.scn'),definitions_sha256=sha(root/'scripts/body_hitboxes.gd'),maximum_pose_error_m=maximum,checked_poses=contract['validation']['common_poses']+['roll','backflip','mend','mend cancellation','mend stun'],special_moves=['mend'])
box['tests']={key:evidence(stage/(key+'.log')) for key in ['pose','server','combat']}
samples=[read(path) for path in sorted((stage/'server-compat').glob('pose-*.json'))]
assert len(samples)==2 and len(samples[0])==len(samples[1])==480
error=max(math.dist(a,b) for x,y in zip(*samples) for a,b in zip(x,y))
assert error < .0005
logs=[(stage/f'compat-{version}.log').read_text(encoding='utf-8-sig') for version in ['451','472']]
assert all('88 passed / 88 total' in log and not re.search(r'^ERROR:|SCRIPT ERROR:',log,re.M) for log in logs)
(stage/'compatibility.log').write_text('\n'.join(logs)+f'Cross-engine maximum endpoint difference: {error} meters\n',encoding='utf-8')
box['server_compatibility']={'engine_version':'4.5.1 and 4.7.2','actual_pose_verified':True,'evidence':evidence(stage/'compatibility.log')}
box['review']={'front_side':evidence(stage/'review/idle.png'),'special_moves':{'mend':evidence(stage/'review/mend-60.png')},'reviewed':True,'notes':'Actual installed presenter, front and side. Padded body capsules follow bent neck, forearms, hands and standing body; hat brim, coat and weapons excluded. Inspected 2-second cast and recovery frames.'}
before={path:sha(stage/'before'/Path(path).name) for path in ['scripts/outlaw_art.gd','scripts/outlaw_equipment.gd','tests/hitbox_pose_test.gd','tests/outlaw_presentation_test.gd']}
added=['scripts/outlaw_mend_animation.gd','assets/animations/outlaw_mend.tres','tools/build_outlaw_mend.gd','tools/outlaw_mend_review.gd','tools/outlaw_mend_stage.py','tools/outlaw_mend_record.py','tests/outlaw_mend_test.gd','docs/OUTLAW_MEND_HANDWORK.md']
write(stage/'before/manifest.json',before)
write(stage/'installed-manifest.json',{path:sha(root/path) for path in list(before)+added})
record['installation'].update(before_manifest='artifacts/outlaw-mend-handwork/before/manifest.json',installed_manifest='artifacts/outlaw-mend-handwork/installed-manifest.json',new_paths=added,owner_feedback='Approved study for Outlaw Mend playtest; awaiting in-game feedback.',rollback='Restore backed-up files only if installed hashes match. Otherwise revert only Mend-specific hunks, retaining subsequent user edits. No GLB/rig rollback needed.')
write(stage/'forge-record.json',record)
print('OUTLAW_MEND_RECORD_READY; cross-engine maximum error',error)
