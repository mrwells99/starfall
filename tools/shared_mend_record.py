"""Record runtime-only Mend additions without modifying any source model."""
from pathlib import Path
import hashlib, json, math, re
import model_forge_hitbox_snapshot as forge

root=Path(__file__).resolve().parents[1]
stage=root/'artifacts/shared-mend-handwork'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value): path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def evidence(path): return {'path':path.relative_to(root).as_posix(),'sha256':sha(path)}
changed=['scripts/model_forge_art.gd','scripts/model_forge_equipment.gd','scripts/fulcrum_art.gd','tests/model_forge_presentation_test.gd','tests/fulcrum_presentation_test.gd','tools/outlaw_mend_review.gd']
added=['tests/shared_mend_handwork_test.gd','tools/shared_mend_stage.py','tools/shared_mend_record.py','docs/SHARED_MEND_HANDWORK.md']
write(stage/'before/manifest.json',{p:sha(stage/'before'/Path(p).name) for p in changed})
write(stage/'installed-manifest.json',{p:sha(root/p) for p in changed+added+['scripts/outlaw_mend_animation.gd','assets/animations/outlaw_mend.tres']})
samples=[read(next((stage/f'compat-{version}').glob('pose-*.json'))) for version in ['451','472']]
assert len(samples[0])==len(samples[1])==1344
error=max(math.dist(a,b) for x,y in zip(*samples) for a,b in zip(x,y))
assert error < .0005
logs=[(stage/f'compat-{version}.log').read_text(encoding='utf-8-sig') for version in ['451','472']]
assert all('61 passed / 61 total' in log and not re.search(r'^ERROR:|SCRIPT ERROR:',log,re.M) for log in logs)
(stage/'compatibility.log').write_text('\n'.join(logs)+f'Cross-engine endpoint maximum: {error} meters\n',encoding='utf-8')
pose_log=(stage/'pose.log').read_text(encoding='utf-8-sig')
maximum=float(re.search(r'Maximum body endpoint difference: ([0-9.eE+-]+) meters',pose_log).group(1))
contract=read(root/'art_source/workflows/starfall-model-forge-v2/extensions/hitboxes-v1/contract.json')
for title in ['Ember','Luminary','Vanguard','Fulcrum']:
    slug=title.lower()
    path=stage/f'{slug}-record.json'
    if not path.exists(): forge.new_record(slug,path.relative_to(root).as_posix())
    record=read(path)
    record.update(class_display_name=title,stage_directory=stage.relative_to(root).as_posix(),reference_paths=['artifacts/mend-standing-living-preview/standing-handwork.gif'])
    record['inputs'].update(costume_source=f'art_source/{slug}.blend',costume_sha256=sha(root/f'art_source/{slug}.blend'))
    record['inputs']['handwork_library']=evidence(root/'assets/animations/outlaw_mend.tres')
    record['intentional_exceptions'].update(reason='User requested the approved Outlaw Mend motion on all remaining Mend users. Additional runtime clip only; original models, rest anatomy, clips, materials and hitboxes unchanged. Vanguard temporarily releases/hides its weapon; Luminary retains staff grip; Fulcrum keeps its orb by the moving hand.',core_motion_bones=['New Mend clip: original source hand-work arms/fingers over original standing idle; adjusted upper arms, neck and head. Existing clip motion unchanged.'])
    record['tools'].update(godot_version='4.7.2 desktop / 4.5.1 server',renderer='Compatibility, 24 FPS, secondary monitor')
    record['deliverables'].update(builder='tools/build_outlaw_mend.gd',editable_blend=f'art_source/{slug}.blend',glb=f'assets/characters/{slug}.glb',runtime_modules=['scripts/fulcrum_art.gd'] if title=='Fulcrum' else ['scripts/model_forge_art.gd','scripts/model_forge_equipment.gd'],companions=['assets/animations/outlaw_mend.tres','scripts/outlaw_mend_animation.gd'],viewer='tools/outlaw_mend_review.gd')
    record['validation'].update(source_checks='Verified frozen 77-file baseline and 91-file extension. Existing source model and GLB not edited.',animation_contract='Original embedded clips and rest anatomy retained; additional shared runtime Mend clip.',skin_checks='Skin/bind geometry unchanged.',materials_export='Existing material resources unchanged.',weapon_grip='Vanguard two wrists restored within 0.1 mm after finish/cancel; Luminary staff follows right hand; Fulcrum orb follows left.',godot_tests=[evidence(stage/(name+'.log')) for name in ['mend','pose','server','combat','fulcrum','jump','transitions']],visual_review='Inspected actual front/side Mend poses, body-volume overlays and equipment recovery. Owner playtest feedback pending.',limitations=['Runtime AnimationLibrary addition, not a bake into the existing Blender source.', 'Costume controls retain the previous base pose during Mend.'])
    box=record['hitboxes']
    box.update(profile='standard',radii_m=contract['body']['radii_m']['standard'],fit_adjustments='Existing class fit retained.',source_sha256=sha(root/f'assets/characters/{slug}.glb'),rig_sha256=sha(root/f'assets/hitboxes/{slug}_rig.scn'),definitions_sha256=sha(root/'scripts/body_hitboxes.gd'),maximum_pose_error_m=maximum,checked_poses=contract['validation']['common_poses']+['mend','mend cancel','mend stun recovery'],special_moves=['mend'])
    # Vanguard uses the established heavy body fit.
    if title=='Vanguard': box.update(profile='heavy',radii_m=contract['body']['radii_m']['heavy'])
    box['tests']={key:evidence(stage/f'{key}.log') for key in ['pose','server','combat']}
    box['server_compatibility']={'engine_version':'4.5.1 and 4.7.2','actual_pose_verified':True,'evidence':evidence(stage/'compatibility.log')}
    box['review']={'front_side':evidence(stage/f'review/{slug}/idle.png'),'special_moves':{'mend':evidence(stage/f'review/{slug}/mend-60.png')},'reviewed':True,'notes':'Actual installed model front/side overlays during Mend; main body and hands covered, decorations/equipment excluded. Recovery captures show restored carrying pose.'}
    record['installation'].update(before_manifest='artifacts/shared-mend-handwork/before/manifest.json',installed_manifest='artifacts/shared-mend-handwork/installed-manifest.json',new_paths=added,owner_feedback='Requested installation for playtest.',rollback='Compare installed hashes then restore backed-up files. If later edits overlap, revert only shared Mend hunks; preserve Outlaw Mend, the shared visual effect, and subsequent edits.')
    write(path,record)
    forge.check_record(path.relative_to(root).as_posix())
print('SHARED_MEND_RECORDS_PASSED; cross-engine maximum',error)
