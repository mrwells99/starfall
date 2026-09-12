"""Validate saved evidence and seal the local Null Forge/rollback record."""
from pathlib import Path
import hashlib,json,math,re,sys
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'artifacts/null-forge-v2'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,data):(ROOT/p).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def evidence(p):return {'path':p,'sha256':sha(ROOT/p)}
def log(p):
 s=(ROOT/p).read_text(encoding='utf-8-sig')
 assert not re.search(r'SCRIPT ERROR:|^ERROR:|^FAIL(?:ED)?:',s,re.M),p
 return s
record=read('artifacts/null-forge-v2/forge-record.json')
contract=read('art_source/workflows/starfall-model-forge-v2/extensions/hitboxes-v1/contract.json')
verification=read('artifacts/null-forge-v2/verification.json')
assert verification['passed']
assert sha(ROOT/'art_source/null.blend')==sha(STAGE/'candidate/null.blend')
assert sha(ROOT/'assets/characters/null.glb')==sha(STAGE/'candidate/null.glb')
logs={}
for key in ['abilities','pose','server','combat','general-combat','outlaw-abilities','outlaw-lasso','world','class-identity','hud','icons','camera','introduction']:
 path=f'artifacts/null-forge-v2/{key}.log';s=log(path)
 counts=re.findall(r'([\w ]+ checks): (\d+) passed / (\d+) total',s)
 assert counts and all(int(a)>0 and a==b for _,a,b in counts),path
 logs[key]={**evidence(path),'result':counts[-1]}
for key in ['network-owner-latency','network-observer-latency','aimed-network']:
 path=f'artifacts/null-forge-v2/{key}.log';s=log(path)
 assert 'HOST PASS' in s and 'CLIENT PASS' in s,path
 logs[key]=evidence(path)
compat=[]
for version in ['451','472']:
 path=f'artifacts/null-forge-v2/server-compat-{version}.log'
 s=log(path);assert 'failures=0' in s and 'clips=35' in s and 'samples=432' in s
 compat.append(s)
samples=[json.loads(p.read_text(encoding='utf-8')) for p in sorted((STAGE/'server-compat').glob('pose-*.json'))]
assert len(samples)==2
error=max(math.dist(a,b) for frame_a,frame_b in zip(*samples) for a,b in zip(frame_a,frame_b))
assert error<.0005,error
(STAGE/'server-compatibility.log').write_text('\n'.join(compat)+f'Cross-engine maximum endpoint difference: {error} meters\n',encoding='utf-8')
record.update(class_display_name='Null',reference_paths=['art_source/references/null-concept-v2.png'],stage_directory='artifacts/null-forge-v2')
record['design']={'silhouette':['faceless pointed hood','fitted rogue armor','short ragged tails','two blades'],
 'armor_and_clothing':['layered black cuirass','segmented arm and leg plates','torn mantle','diagonal harness'],
 'palette':['black','charcoal','graphite','cold silver','white blade eyes'],
 'material_roles':['woven cloth','rough dark leather','rubbed black steel','polished silver edge','luminous white slit'],
 'face_and_hair_treatment':'Featureless recessed shadow; no human face or hair','weapon':'Two asymmetric curved sentient blades','carrying_hands':['left','right']}
record['inputs'].update(costume_source='artifacts/null-forge-v2/seed/art_source/fulcrum_ual/fulcrum_ual.blend',costume_sha256=sha(STAGE/'seed/art_source/fulcrum_ual/fulcrum_ual.blend'))
record['inputs']['construction_helper']=evidence('art_source/null_ual/construction.py')
record['inputs']['reference_sha256']=sha(ROOT/'art_source/references/null-concept-v2.png')
record['intentional_exceptions'].update(reason='No inherited core-motion or anatomy exceptions. Extra class clips and hand-parented equipment only.',new_equipment_controls=['null.blade.L','null.blade.R'],texture_palette_recipe_changes=['Five fresh packed neutral maps; texture seed 311','Removed orb, metallic mask and central stole; refitted ragged tails','Additional native KnifeStrike, StealthIdle, StealthWalk clips'])
record['tools']={'blender_version':'5.2.1 LTS','godot_version':'4.7.2 desktop; 4.5.1 server compatibility','renderer':'gl_compatibility','python_version':sys.version.split()[0],'seeds':{'textures':311}}
record['deliverables']={'builder':'tools/build_null.py','companions':['art_source/null_ual/construction.py','art_source/null_ual/recipe.json','tools/verify_null.py','tools/null_compat_stage.py','tools/null_record.py'],
 'editable_blend':'art_source/null.blend','packed_textures':[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'art_source/null_ual').glob('*.png'))],
 'glb':'assets/characters/null.glb','runtime_modules':['scripts/null_art.gd','scripts/null_equipment.gd','scripts/null_mechanics.gd'],'viewer':'tools/null_review.gd'}
record['validation']={'source_checks':evidence('artifacts/null-forge-v2/verification.json'),'animation_contract':evidence('artifacts/null-forge-v2/verify.log'),
 'skin_checks':f"Normalized finite weights; maximum error {verification['skin_weight_error']}; unchanged mannequin vertices",
 'materials_export':'Five fresh packed textures, UVs and GLB export verified; final neutral render inspected',
 'weapon_grip':'Two hand-parented reverse grips, native idle finger pose; same pose-only server attachment layer',
 'godot_tests':logs,'visual_review':'Actual runtime front/back/side, walking, running, backpedal, crouch, knife attack, lift/dive/recovery and body hitbox images inspected. Review windows use secondary screen 0, 30 FPS, no focus.',
 'limitations':['Procedural model simplifies the reference engraving and ragged layers; owner approval of this 3D interpretation is not claimed.',
 'Cloth uses inherited garment bones rather than simulation; brief inverted dive can look rigid.',
 'Stealth uses the native forward crouch clip for all travel directions.',
 'Unspecified damage/range/cooldowns remain initial tuning; no final damage rotation or cinematic warp VFX.',
 'Local ENet and isolated engine compatibility checks; no production deployment or human online test.']}
box=record['hitboxes']
box.update(profile='standard',radii_m=contract['body']['radii_m']['standard'],fit_adjustments='Standard main-body fit; excludes hood tip, flowing cloak and blades. Existing project AIM_SCALE (2,1.25,2) remains separate from this fitted profile.',
 source_sha256=sha(ROOT/box['source_glb']),rig_sha256=sha(ROOT/box['rig']),definitions_sha256=sha(ROOT/box['definitions']),
 maximum_pose_error_m=0.0,checked_poses=contract['validation']['common_poses']+['stealth','lift','dive','recover','stab'],special_moves=['stealth','lift','dive','recover','stab'])
box['tests']={key:evidence(f'artifacts/null-forge-v2/{name}.log') for key,name in [('pose','pose'),('server','server'),('combat','combat')]}
box['server_compatibility']={'engine_version':'Godot 4.5.1 stable, compared with 4.7.2','actual_pose_verified':True,'evidence':evidence('artifacts/null-forge-v2/server-compatibility.log')}
box['review']={'front_side':evidence('artifacts/null-forge-v2/review/null.png'),'special_moves':{pose:evidence(f'artifacts/null-forge-v2/review/null-{pose}.png') for pose in box['special_moves']},
 'reviewed':True,'notes':'Body capsules follow torso, limbs and head through neutral and special poses; cloth and blades remain outside. Gold head capsule has normal damage. Actual renders inspected; no owner acceptance invented.'}
box['performance_notes']=f"{(ROOT/box['rig']).stat().st_size} byte mesh-free rig vs {(ROOT/box['source_glb']).stat().st_size} byte visual GLB; 85 bones, 35 clips, 52782 retained keys. Dedicated resource guards pass. No framerate benchmark claim."
before=read('artifacts/null-forge-v2/before/manifest.json')
changed={}
for path,oldhash in before.items():
 p=ROOT/path
 if p.is_file() and sha(p)!=oldhash:changed[path]={'before_sha256':oldhash,'installed_sha256':sha(p)}
new=[]
for pattern in ['art_source/null.blend','art_source/null_ual/**/*','assets/characters/null*','assets/hitboxes/null_rig.scn','assets/icons/abilities/null/**/*','scripts/null_*','tests/null_*','tests/run_null_network.py','tools/build_null.py','tools/verify_null.py','tools/null_review.gd*','tools/null_compat_stage.py','tools/null_record.py','docs/NULL_CLASS.md']:
 for p in ROOT.glob(pattern):
  if p.is_file() and p.relative_to(ROOT).as_posix() not in before:new.append(p.relative_to(ROOT).as_posix())
# Record is itself a deliverable; omit its self-referential checksum.
new=sorted(set(new)|{'art_source/null_ual/forge-record.json'})
record['installation']={'before_manifest':'artifacts/null-forge-v2/before/manifest.json','installed_manifest':'artifacts/null-forge-v2/installed-manifest.json','new_paths':new,
 'owner_feedback':'Owner approved the concept design and supplied the grey/black sheet. Both outgoing attacks and direct incoming abilities start 10s combat. No later 3D-model feedback received.',
 'rollback':'Hash-check current installed files; restore changed paths from before; remove only listed new paths if unchanged. Preserve later work and all prior concept art.'}
write('artifacts/null-forge-v2/forge-record.json',record)
write('art_source/null_ual/forge-record.json',record)
write('artifacts/null-forge-v2/installed-manifest.json',{'changed_paths':changed,'new_paths':{path:sha(ROOT/path) for path in new if (ROOT/path).is_file()},'preserve_prior_concept_archive':True})
print('NULL_RECORD_READY',len(changed),'changed paths;',len(new),'new paths; cross-engine error',error)
