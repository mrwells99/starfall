"""Starfall Model Forge v2: freeze, verify, extract safely, compare motion.
Create/contracts: Blender -b --python tools/model_forge_snapshot.py -- --create
Verify/extract: Python tools/model_forge_snapshot.py --verify / --extract EMPTY_DIR
Candidate: Blender -b --python tools/model_forge_snapshot.py -- --check-candidate FILE
Never restores a package over the live game. Completed snapshots are immutable.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = ROOT / 'art_source/workflows/starfall-model-forge-v2'
WORK = ROOT / 'artifacts/model-forge-v2-creation'
PART_BYTES = 32 * 1024 * 1024
ACCEPTED_ARM_SHA = 'd61475e3486b3f1065473169c725dc91e86d3422d66f0d2d866abfcb5890fd18'
REJECTED_NAMES = ('r006', 'r007', '/reverted/', 'fulcrum_jump_torso_test', 'fulcrum_jump_body_test')

def sha(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()

def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2, allow_nan=False) + '\n', encoding='utf-8')

def safe_member(name):
    path = Path(name)
    assert not path.is_absolute() and ':' not in name and '\\' not in name
    assert all(part not in ('..', '.git') for part in path.parts), name
    assert not any(token in name for token in REJECTED_NAMES), name
    return path

def source_paths():
    groups = {}
    def add(group, relative):
        path = ROOT / relative
        if not path.is_file():
            raise FileNotFoundError(path)
        safe_member(relative)
        groups[relative] = group
    for relative in ['art_source/fulcrum.blend', 'art_source/references/fulcrum.png', 'art_source/.gdignore']:
        add('approved_model', relative)
    for path in sorted((ROOT/'art_source/fulcrum_ual').iterdir()):
        if path.is_file(): add('preset_and_costume_inputs', path.relative_to(ROOT).as_posix())
    for path in sorted((ROOT/'assets/characters').glob('fulcrum*')):
        if path.is_file(): add('approved_export_and_textures', path.relative_to(ROOT).as_posix())
    for name in ['build_fulcrum.py', 'fulcrum_details.py', 'fulcrum_weapon.py', 'build_fulcrum_ual.py',
                 'verify_fulcrum_ual.py', 'inspect_fulcrum_ual.py', 'model_forge_snapshot.py',
                 'fulcrum_preview.gd', 'fulcrum_jump_review.gd', 'fulcrum_transition_review.gd', 'fulcrum_ual_review.gd']:
        add('build_and_review', 'tools/'+name)
        if (ROOT/('tools/'+name+'.uid')).is_file(): add('build_and_review', 'tools/'+name+'.uid')
    for name in ['fulcrum_art', 'fulcrum_jump_pose', 'fulcrum_pose_blend']:
        for suffix in ['.gd', '.gd.uid']: add('accepted_runtime', 'scripts/'+name+suffix)
    for name in ['champion_model', 'combatant', 'arena', 'kits', 'auras']:
        add('integration_context_only', 'scripts/'+name+'.gd')
    for name in ['fulcrum_presentation_test', 'fulcrum_jump_pose_test', 'fulcrum_pose_blend_test', 'jump_momentum_test']:
        for suffix in ['.gd', '.gd.uid']: add('regression_tests', 'tests/'+name+suffix)
    add('build_and_review', 'scenes/fulcrum_preview.tscn')
    for name in ['CONTEXT.md', 'FULCRUM_UNIVERSAL_ANIMATION_PASS.md', 'STARFALL_MODEL_FORGE_V2.md', 'CHARACTER_PIPELINE.md']:
        add('documentation', 'docs/'+name)
    add('skill', 'tools/skills/starfall-character-forge/SKILL.md')
    add('documentation', 'art_source/workflows/README.md')
    for name in ['README.md', 'WORKFLOW.md', 'runtime_contract.json', 'feedback.json', 'new_character.template.json']:
        add('workflow', 'art_source/workflows/starfall-model-forge-v2/'+name)
    return groups

def assert_accepted_runtime():
    assert sha(ROOT/'scripts/fulcrum_jump_pose.gd') == ACCEPTED_ARM_SHA, 'Accepted arm-only layer changed'
    art = (ROOT/'scripts/fulcrum_art.gd').read_text(encoding='utf-8')
    assert 'JUMP_BODY_BLEND_SECONDS := .16' in art
    assert 'apply_body' not in art and 'body_apex_rotation' not in art
    for path in ['tests/fulcrum_jump_body_test.gd', 'tests/fulcrum_jump_torso_test.gd', 'tools/fulcrum_torso_review.gd']:
        assert not (ROOT/path).exists(), 'Rejected revision still active: '+path

def capture(path, include_surfaces=True):
    import bpy
    bpy.ops.wm.open_mainfile(filepath=str(path))
    rig = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    scene = bpy.context.scene
    flat = lambda matrix: [float(value) for row in matrix for value in row]
    bones = {b.name: {'parent': b.parent.name if b.parent else None, 'rest': flat(b.matrix_local),
                      'head': list(b.head_local), 'tail': list(b.tail_local), 'deform': b.use_deform}
             for b in rig.data.bones}
    assert rig.animation_data and rig.animation_data.nla_tracks
    clips = {}
    for track in rig.animation_data.nla_tracks:
        for other in rig.animation_data.nla_tracks: other.mute = other != track
        assert len(track.strips) == 1
        strip = track.strips[0]
        samples = {}
        # Every key and intervening half frame, so interpolation is captured.
        for tick in range(round(strip.frame_start*2), round(strip.frame_end*2)+1):
            frame = tick/2
            scene.frame_set(int(frame), subframe=frame-int(frame))
            samples[str(frame)] = {p.name: flat(p.matrix_basis) for p in rig.pose.bones}
        clips[track.name] = {'first': strip.frame_start, 'last': strip.frame_end,
                            'seconds': (strip.frame_end-strip.frame_start)/(scene.render.fps/scene.render.fps_base),
                            'frames': samples}
    result = {'rig': rig.name, 'fps': scene.render.fps, 'fps_base': scene.render.fps_base, 'bones': bones, 'clips': clips}
    if include_surfaces:
        meshes = {}
        for obj in bpy.data.objects:
            if obj.type != 'MESH' or not any(m.type=='ARMATURE' and m.object==rig for m in obj.modifiers): continue
            mesh = obj.data
            digest = hashlib.sha256()
            for v in mesh.vertices: digest.update(struct.pack('<3f', *v.co))
            for polygon in mesh.polygons:
                digest.update(struct.pack('<I', len(polygon.vertices)))
                for index in polygon.vertices: digest.update(struct.pack('<I', index))
            meshes[obj.name] = {'vertices': len(mesh.vertices), 'triangles': sum(len(p.vertices)-2 for p in mesh.polygons),
                                'geometry_sha256': digest.hexdigest(), 'materials': [m.name for m in mesh.materials],
                                'uv_layers': [uv.name for uv in mesh.uv_layers],
                                'max_weight_error': max(abs(sum(g.weight for g in v.groups)-1) for v in mesh.vertices)}
        materials = {}
        for material in bpy.data.materials:
            if not material.use_nodes: continue
            principled = next((n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED'), None)
            inputs = {}
            if principled:
                for name in ['Base Color','Metallic','Roughness','Emission Color','Emission Strength','Alpha']:
                    value = principled.inputs[name].default_value
                    inputs[name] = list(value) if hasattr(value,'__iter__') else value
            materials[material.name] = {'principled': inputs,
                'images': [n.image.name for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image],
                'links': [[l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name] for l in material.node_tree.links]}
        images = {i.name: {'size': list(i.size), 'colorspace': i.colorspace_settings.name,
                            'packed': bool(i.packed_file),
                            'packed_sha256': hashlib.sha256(i.packed_file.data).hexdigest() if i.packed_file else None}
                  for i in bpy.data.images if i.source == 'FILE'}
        result.update(meshes=meshes, materials=materials, images=images)
    return result

def create():
    import bpy
    import numpy
    assert not (PACKAGE/'manifest.json').exists(), 'Completed v2 snapshot already exists; make a new version'
    assert_accepted_runtime()
    groups = source_paths()
    WORK.mkdir(parents=True, exist_ok=True)
    contracts = capture(ROOT/'art_source/fulcrum.blend')
    recipe = json.loads((ROOT/'art_source/fulcrum_ual/recipe.json').read_text(encoding='utf-8'))
    contracts['core_bones'] = list(recipe['core_rest_matrices'])
    assert len(contracts['bones'])==83 and len(contracts['core_bones'])==53 and len(contracts['clips'])==32
    with gzip.GzipFile(filename=str(PACKAGE/'contracts.json.gz'), mode='wb', mtime=0) as output:
        output.write(json.dumps(contracts, separators=(',', ':'), allow_nan=False).encode())
    godot=Path('C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
    manifest = {'schema':2, 'name':'Starfall Model Forge v2', 'approved_revision':'Fulcrum r001-r005 + r008; r006/r007 excluded',
                'created_utc':datetime.now(timezone.utc).isoformat(), 'files': {}, 'parts': [],
                'environment': {'blender':bpy.app.version_string,'blender_build':bpy.app.build_hash.decode(),
                                'blender_executable':bpy.app.binary_path,'blender_sha256':sha(bpy.app.binary_path),
                                'python':sys.version,'numpy':numpy.__version__,'platform':platform.platform(),
                                'godot_executable':str(godot),'godot_sha256':sha(godot),
                                'godot_version':subprocess.check_output([str(godot),'--version'],text=True).strip(),
                                'review_renderer':'OpenGL Compatibility; RTX 5060 Ti; driver 616.64 (approved review)'}}
    archive = WORK/'baseline.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for relative,group in sorted(groups.items()):
            path = ROOT/relative
            manifest['files'][relative] = {'sha256':sha(path),'bytes':path.stat().st_size,'group':group}
            output.write(path,relative)
    with archive.open('rb') as source:
        index = 1
        while block := source.read(PART_BYTES):
            part = PACKAGE/('baseline.zip.%03d'%index)
            part.write_bytes(block)
            manifest['parts'].append({'file':part.name,'bytes':len(block),'sha256':sha(part)})
            index += 1
    manifest['archive'] = {'bytes':archive.stat().st_size,'sha256':sha(archive),'format':'Concatenated standard ZIP, ordered parts'}
    manifest['contracts'] = {'file':'contracts.json.gz','sha256':sha(PACKAGE/'contracts.json.gz')}
    write_json(PACKAGE/'manifest.json',manifest)
    verify()
    print('MODEL_FORGE_V2_CREATED',len(groups),'files;',len(manifest['parts']),'parts;',len(contracts['clips']),'clips')

def verified_archive():
    manifest = json.loads((PACKAGE/'manifest.json').read_text(encoding='utf-8'))
    assert sha(PACKAGE/manifest['contracts']['file'])==manifest['contracts']['sha256']
    temp = tempfile.TemporaryFile()
    combined = hashlib.sha256()
    for record in manifest['parts']:
        part = PACKAGE/record['file']
        assert part.name==record['file'] and part.stat().st_size==record['bytes'] and sha(part)==record['sha256']
        with part.open('rb') as stream:
            while block := stream.read(1024*1024): temp.write(block);combined.update(block)
    assert temp.tell()==manifest['archive']['bytes'] and combined.hexdigest()==manifest['archive']['sha256']
    temp.seek(0)
    archive = zipfile.ZipFile(temp)
    assert set(archive.namelist())==set(manifest['files'])
    for name,record in manifest['files'].items():
        safe_member(name)
        with archive.open(name) as file:
            assert hashlib.file_digest(file,'sha256').hexdigest()==record['sha256'],name
        assert archive.getinfo(name).file_size==record['bytes']
        live = ROOT/name
        if record['group']=='workflow': assert live.is_file() and sha(live)==record['sha256'], 'Frozen workflow changed: '+name
    assert manifest['files']['scripts/fulcrum_jump_pose.gd']['sha256']==ACCEPTED_ARM_SHA
    return manifest,temp,archive

def verify():
    manifest,temp,archive = verified_archive()
    archive.close();temp.close()
    print('MODEL_FORGE_V2_VERIFIED',len(manifest['files']),'files;',manifest['archive']['bytes'],'archive bytes; rejected revisions excluded')

def extract(destination):
    target = Path(destination).resolve()
    assert target!=ROOT and (not target.exists() or not any(target.iterdir())), 'Extraction requires a new empty directory'
    manifest,temp,archive = verified_archive()
    target.mkdir(parents=True,exist_ok=True)
    for name in manifest['files']:
        path = target/safe_member(name)
        assert path.resolve().is_relative_to(target)
        path.parent.mkdir(parents=True,exist_ok=True)
        with archive.open(name) as source, path.open('xb') as output: shutil.copyfileobj(source,output)
    archive.close();temp.close()
    # Keep the verification authority with a recovered source workspace.
    destination_package=target/PACKAGE.relative_to(ROOT)
    for name in ['manifest.json','contracts.json.gz']+[p['file'] for p in manifest['parts']]:
        shutil.copy2(PACKAGE/name,destination_package/name)
    print('MODEL_FORGE_V2_EXTRACTED',target)

def check_candidate(path, allowed, reason):
    assert not allowed or reason, 'Explain intentional attachment motion exceptions with --reason'
    verify()
    with gzip.open(PACKAGE/'contracts.json.gz','rt',encoding='utf-8') as file: expected=json.load(file)
    actual=capture(Path(path),include_surfaces=False)
    core=expected['core_bones']
    assert set(allowed)<=set(core),'Unknown motion exception'
    rest_error=0.0;motion_error=0.0;samples=0
    for name in core:
        assert name in actual['bones'] and actual['bones'][name]['parent']==expected['bones'][name]['parent'],name
        rest_error=max(rest_error,max(abs(a-b) for a,b in zip(actual['bones'][name]['rest'],expected['bones'][name]['rest'])))
    for label,clip in expected['clips'].items():
        assert label in actual['clips'],label
        current=actual['clips'][label]
        assert abs(current['seconds']-clip['seconds'])<1e-5 and set(current['frames'])==set(clip['frames']),label
        for frame,pose in clip['frames'].items():
            for name in core:
                if name in allowed: continue
                motion_error=max(motion_error,max(abs(a-b) for a,b in zip(pose[name],current['frames'][frame][name])))
                samples+=1
    result={'passed':rest_error<1e-6 and motion_error<1e-5,'rest_max_error':rest_error,'motion_max_error':motion_error,
            'bone_frame_samples':samples,'allowed_motion_bones':allowed,'exception_reason':reason}
    print('MODEL_FORGE_V2_CANDIDATE',json.dumps(result))
    assert result['passed'],result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    modes=parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--create',action='store_true');modes.add_argument('--verify',action='store_true')
    modes.add_argument('--extract');modes.add_argument('--check-candidate')
    parser.add_argument('--allow-motion-bone',action='append',default=[]);parser.add_argument('--reason',default='')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else None)
    if args.create:create()
    elif args.verify:verify()
    elif args.extract:extract(args.extract)
    else:check_candidate(args.check_candidate,args.allow_motion_bone,args.reason)

if __name__=='__main__':main()
