"""Record this Outlaw installation or safely restore its pre-installation files."""
import argparse,hashlib,json,platform,shutil,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'artifacts/outlaw-forge-v2';SOURCE=ROOT/'art_source/outlaw_ual'
INSTALL=SOURCE/'installation.json';RECORD=SOURCE/'forge-record.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(p):return p.relative_to(ROOT).as_posix()
def test_summary(name):
 text=(STAGE/name).read_text(encoding='utf-8-sig')
 matches=re.findall(r'checks: (\d+) passed / (\d+) total',text)
 if not matches or 'ERROR:' in text or matches[-1][0]!=matches[-1][1]:raise RuntimeError('Test did not pass: '+name)
 return '/'.join(matches[-1])
def checked(name):
 p=(ROOT/name).resolve()
 if not p.is_relative_to(ROOT.resolve()):raise RuntimeError('Path outside project: '+name)
 return p
CHANGED=['scripts/'+n+'.gd' for n in ['arena','kits','combatant','class_mechanics','crowd_control','auras','resource_meter','thin_resource_bar','champion_introduction','champion_model','movement_prediction','ability_art']]+[
 'tests/class_identity_test.gd','tests/resource_meter_test.gd','tests/nameplate_test.gd','tests/ability_art_test.gd','tests/check_suite.sh','scripts/model_forge_art.gd','scripts/arena_frame_details.gd',
 'tools/class_reference.gd','docs/CONTEXT.md','docs/TECHNICAL_ARCHITECTURE.md','docs/GAME_DESIGN.md','docs/CLASS_ABILITIES.md','.github/workflows/deploy.yml']
NEW=['scripts/'+n+'.gd' for n in ['outlaw_mechanics','outlaw_art','outlaw_equipment','outlaw_effects']]+[
 'tests/outlaw_abilities_test.gd','tests/outlaw_presentation_test.gd','tests/outlaw_network_peer.gd','tests/run_outlaw_network.py','tests/hotbar_viewport_test.gd','tests/outlaw_local_match_test.gd','tests/check_suite_runner_test.py','tests/check_presenter_indentation.py','tests/cast_bar_test.gd',
 'tools/build_outlaw.py','tools/verify_outlaw.py','tools/outlaw_review.gd','tools/outlaw_icon_review.gd','tools/build_outlaw_icons.py',
 'docs/OUTLAW_CLASS.md','assets/characters/outlaw.glb','assets/characters/outlaw.glb.import']
def record():
 before=json.loads((STAGE/'before/manifest.json').read_text())
 names=set(CHANGED+NEW)
 for name in list(names):
  if name.endswith('.gd') and checked(name+'.uid').exists():names.add(name+'.uid')
 for folder in [SOURCE,ROOT/'assets/icons/abilities/outlaw']:
  names.update(relative(p) for p in folder.rglob('*') if p.is_file() and p not in [INSTALL,RECORD])
 # Godot extracts the GLB's embedded maps beside the imported scene.
 names.update(relative(p) for p in (ROOT/'assets/characters').glob('outlaw_outlaw_*.png*') if p.is_file())
 entries={}
 for name in sorted(names):
  p=checked(name)
  if not p.exists():continue
  previous=before.get(name)
  digest=sha(p)
  if previous==digest:continue
  entries[name]={'installed_sha256':digest,'bytes':p.stat().st_size,'before_sha256':previous}
 INSTALL.write_text(json.dumps({'class':'Outlaw','before_manifest':'artifacts/outlaw-forge-v2/before/manifest.json','files':entries},indent=2))
 template=ROOT/'art_source/workflows/starfall-model-forge-v2'
 frozen=json.loads((template/'manifest.json').read_text())
 result=json.loads((template/'new_character.template.json').read_text())
 recipe=json.loads((SOURCE/'recipe.json').read_text())
 verification=json.loads((STAGE/'verification.json').read_text())
 result.update({'class_slug':'outlaw','class_display_name':'Outlaw','baseline_manifest_sha256':sha(template/'manifest.json'),
  'baseline_archive_sha256':frozen['archive']['sha256'],'reference_paths':['art_source/references/outlaw-concept-v1.png'],
  'reference_sha256':sha(ROOT/'art_source/references/outlaw-concept-v1.png'),'stage_directory':relative(STAGE)})
 result['design']={'silhouette':['celestial robot','wide cowboy hat','open split duster'],
  'armor_and_clothing':['fitted blackened steel plates','joint actuators','brass-edged duster','constellation embroidery','cowboy boots and spurs'],
  'palette':['brown-black leather','black steel','weathered brass','amber optics','blue condensed starlight','crimson Bowie etching'],
  'material_roles':['base-color maps','micro-normal map','roughness map','metallic armor','emissive optics/reactor/weapon details'],
  'face_and_hair_treatment':'Mechanical faceplate and optics; no human face or hair.',
  'weapon':'Celestial revolver in right hand; 150% Bowie knife in left reverse grip across the native closed fist.',
  'carrying_hands':['DEF-hand.R','DEF-hand.L']}
 result['inputs'].update({'costume_source':'tools/build_outlaw.py','costume_sha256':sha(ROOT/'tools/build_outlaw.py'),
  'seed_blend_sha256':recipe['seed_blend_sha256'],'source_library':'art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb',
  'library_license':'art_source/model_forge_v2/QUATERNIUS_LICENSE.txt'})
 result['intentional_exceptions'].update({'reason':'No source/core motion edits. Outlaw-specific runtime grip and ability overlays only.',
  'new_equipment_controls':['outlaw.gun','outlaw.knife'],'texture_palette_recipe_changes':recipe['texture_palette'],
  'runtime_grip_bones':'All native finger/thumb joints retain the closed Idle fist around carried equipment.',
  'runtime_ability_bones':'Right shoulder/upper arm/forearm/hand use native pistol aim/fire. Left counterparts use mirrored Sword_Attack.',
  'extra_clips':recipe['extras'],'backflip':'Reversed native Roll retimed to physical leap; no dedicated backflip exists in the downloaded library.',
  'special_move_blend_seconds':{'limbs':.08,'torso_head':.16}})
 result['tools']={'blender_version':recipe['blender'],'godot_version':'4.7.2.stable.official.ed1daf0bf',
  'renderer':'Godot Compatibility and Forward+ model review; Forward+ icon/hotbar validation; RTX 5060 Ti, driver 616.64',
  'python_version':platform.python_version(),'seeds':recipe['seeds']}
 result['deliverables']={'builder':'tools/build_outlaw.py','companions':['tools/verify_outlaw.py','tools/build_outlaw_icons.py'],
  'editable_blend':'art_source/outlaw_ual/outlaw.blend','packed_textures':sorted(verification['packed_maps']),
  'glb':'assets/characters/outlaw.glb','runtime_modules':['scripts/outlaw_art.gd','scripts/outlaw_equipment.gd','scripts/outlaw_mechanics.gd','scripts/outlaw_effects.gd'],
  'viewer':'tools/outlaw_review.gd','ability_icons':'assets/icons/abilities/outlaw/'}
 result['validation'].update({'source_checks':verification,'animation_contract':'111830 samples, zero rest and source motion error, no exceptions',
  'skin_checks':verification['skin_weight_error'],'materials_export':'4 packed maps, skinned GLB with embedded materials',
  'weapon_grip':'Runtime review of Idle, run, backpedal, roll/backflip, aiming and knife strike; equipment remains parented to its hand.',
  'godot_tests':{'gameplay':test_summary('outlaw_abilities-final.log'),'presentation':test_summary('outlaw_presentation-final.log'),'hotbar_viewport':test_summary('hotbar-viewport-final.log'),'cast_bar':test_summary('cast-bar-final.log'),'rendered_local_matches':test_summary('outlaw-local-rendered.log'),'network':'Real ENet host and client passed with simulated 75ms latency','logs':'artifacts/outlaw-forge-v2/'},
  'visual_review':['front.png','back.png','side.png','three-quarter.png','run.png','backpedal.png','roll.png','backflip.png','knife-strike.png','gun-aim.png','moving-channel.png','deadeye.png','ability-icons.png'],
  'limitations':['Procedural stylized interpretation, not photorealistic concept reproduction.','Bone-driven cloth; extreme actions may need further costume clearance polish.','Unspecified combat tuning is provisional; owner-specified damage and combo rules retained.','Ability art is deliberately placeholder SVG, authored last.']})
 result['installation']={'before_manifest':relative(STAGE/'before/manifest.json'),'installed_manifest':relative(INSTALL),
  'new_paths':[n for n,e in entries.items() if e['before_sha256'] is None],
  'owner_feedback':['Bowie knife enlarged by 50%.','Hold the knife in a proper closed grip.','Backflip blocks CC while airborne.','Roll grants one-second instant Severe buff.','Cowboy/lore ability placeholders authored last.'],
  'rollback':'tools/outlaw_forge_record.py --rollback; verifies all installed hashes first; preserves later edits by refusing mismatches.'}
 RECORD.write_text(json.dumps(result,indent=2))
 print('OUTLAW_INSTALLATION_RECORDED',len(entries),'files',len(result['installation']['new_paths']),'new paths')
def rollback(check_only=False):
 data=json.loads(INSTALL.read_text());errors=[]
 for name,e in data['files'].items():
  p=checked(name)
  if not p.exists() or sha(p)!=e['installed_sha256']:errors.append(name+' changed since installation')
  if e['before_sha256']:
   original=STAGE/'before'/name
   if not original.exists() or sha(original)!=e['before_sha256']:errors.append(name+' backup missing or mismatched')
 if errors:raise RuntimeError('\n'.join(errors))
 if check_only:print('OUTLAW_ROLLBACK_CHECK_PASSED',len(data['files']),'paths; no files changed');return
 for name,e in data['files'].items():
  p=checked(name)
  if e['before_sha256']:shutil.copy2(STAGE/'before'/name,p)
  else:p.unlink()
 print('OUTLAW_ROLLED_BACK; installation/forge records retained for audit. Reimport Godot before playing.')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--rollback',action='store_true');parser.add_argument('--check-rollback',action='store_true');args=parser.parse_args()
 if args.rollback or args.check_rollback:rollback(args.check_rollback)
 else:record()
