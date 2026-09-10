"""Fit the existing Fulcrum costume to the unchanged Quaternius mannequin rig.
Run with Blender --background --factory-startup --python tools/build_fulcrum_ual.py.
Outputs are staged until separately reviewed/installed. Never regenerates Forge v1.
"""
import bpy, bmesh, json, math, hashlib, shutil
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'art_source/fulcrum_ual'
OUT = ROOT / 'artifacts/fulcrum-turn-r004'
SOURCE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
BACKUP = OUT / 'before'
paths = ['art_source/fulcrum.blend', 'assets/characters/fulcrum.glb', 'assets/characters/fulcrum.glb.import',
         'scripts/fulcrum_art.gd', 'tests/fulcrum_presentation_test.gd', 'tools/fulcrum_preview.gd']
if not (BACKUP / 'manifest.json').exists():
    manifest = {}
    for name in paths:
        p = ROOT / name
        if p.exists():
            dst = BACKUP / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dst)
            manifest[name] = hashlib.sha256(p.read_bytes()).hexdigest()
    (BACKUP / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
for src, dst in [(BACKUP/'art_source/fulcrum.blend', SOURCE/'costume_source.blend'),
                 (ROOT/'Godot/AnimationLibrary_Godot_Standard.glb', SOURCE/'AnimationLibrary_Godot_Standard.glb'),
                 (ROOT/'License.txt', SOURCE/'QUATERNIUS_LICENSE.txt')]:
    if not dst.exists(): shutil.copy2(src, dst)

bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'costume_source.blend'))
bpy.context.preferences.filepaths.save_version=0
old = bpy.data.objects['Fulcrum_Rig']
old.animation_data_clear()
for p in old.pose.bones: p.matrix_basis = Matrix.Identity(4)
body = bpy.data.objects['Fulcrum_SkinnedModel']
weapon = bpy.data.objects['Fulcrum_GravityWeapon']
for obj in list(bpy.data.objects):
    if obj not in [old, body, weapon]: bpy.data.objects.remove(obj, do_unlink=True)
old_bones = {b.name: {'head': b.head_local.copy(), 'tail': b.tail_local.copy(), 'matrix': b.matrix_local.copy(),
                       'parent': b.parent.name if b.parent else None} for b in old.data.bones}
for action in list(bpy.data.actions): bpy.data.actions.remove(action)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/'AnimationLibrary_Godot_Standard.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE' and o != old)
rig.name = 'Fulcrum_UAL_Rig'
mannequin = bpy.data.objects['Mannequin']
for obj in list(bpy.data.objects):
    if obj not in [old, body, weapon, rig, mannequin]: bpy.data.objects.remove(obj, do_unlink=True)
rig.animation_data_clear()
for p in rig.pose.bones: p.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
original_rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
original_parent = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
actions = {a.name: a for a in bpy.data.actions}
source_fps = bpy.context.scene.render.fps
core = list(original_rest)
mapping = {'root':'root','pelvis':'DEF-hips','spine':'DEF-spine.001','chest':'DEF-spine.003','neck':'DEF-neck','head':'DEF-head'}
for side in ['L','R']:
    for name, target in [('clavicle','shoulder'),('upper_arm','upper_arm'),('forearm','forearm'),('hand','hand'),('thigh','thigh'),('shin','shin'),('foot','foot'),('toe','toe')]:
        mapping[name+'.'+side] = 'DEF-'+target+'.'+side
    for i, finger in enumerate(['index','middle','ring','pinky']): mapping[f'finger{i}.{side}'] = f'DEF-f_{finger}.01.{side}'
    mapping['finger4.'+side] = 'DEF-thumb.01.'+side

def frame_at(a, b):
    y = (b-a).normalized()
    z = Vector((0,-1,0))
    if abs(y.dot(z)) > .95: z = Vector((0,0,1))
    x = y.cross(z).normalized()
    z = x.cross(y).normalized()
    m = Matrix((x,y,z)).transposed().to_4x4()
    m.translation = a
    return m

def endpoint(name):
    b = rig.data.bones[name]
    # glTF bone tails are importer display heuristics, not anatomical landmarks.
    # Use the actual preset head envelope for the hood/mask fit.
    if name == 'DEF-head': return Vector((b.head_local.x,b.head_local.y,1.8291782140731812))
    endpoints = {'DEF-hips':'DEF-spine.001','DEF-spine.001':'DEF-spine.003','DEF-spine.003':'DEF-neck','DEF-neck':'DEF-head'}
    for s in ['L','R']:
        for a,c in [('shoulder','upper_arm'),('upper_arm','forearm'),('forearm','hand'),('hand','f_middle.01'),('thigh','shin'),('shin','foot'),('foot','toe')]:
            endpoints['DEF-'+a+'.'+s]='DEF-'+c+'.'+s
    return rig.data.bones[endpoints[name]].head_local if name in endpoints else b.tail_local

transforms = {}
for name, old_b in old_bones.items():
    if name in mapping:
        target = rig.data.bones[mapping[name]]
        a, b = target.head_local, endpoint(mapping[name])
        scale = (b-a).length / max((old_b['tail']-old_b['head']).length, .001)
        radial = .84 if any(k in name for k in ['arm','thigh','shin','hand']) else .88
        if name in ['pelvis','spine','chest','neck','head']:
            radial = .76 if name in ['pelvis','spine','chest'] else .88
        if name == 'root':
            transforms[name] = Matrix.Diagonal((.8,.9,.9,1))
        else:
            transforms[name] = frame_at(a,b) @ Matrix.Diagonal((radial,scale,radial,1)) @ frame_at(old_b['head'],old_b['tail']).inverted()
    else:
        transforms[name] = Matrix.Diagonal((.8,.9,.9,1))

# Class-specific cloth and orbital controls extend the library skeleton. Its
# original bones, hierarchy, proportions and bind matrices remain untouched.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
extras = [n for n in old_bones if n not in mapping]
for name in extras:
    src = old_bones[name]
    b = rig.data.edit_bones.new(name)
    b.head = transforms[name] @ src['head']; b.tail = transforms[name] @ src['tail']
    parent = src['parent']; b.parent = rig.data.edit_bones[mapping.get(parent,parent)]
bpy.ops.object.mode_set(mode='OBJECT')
for name in core:
    assert max(abs(v) for row in (rig.data.bones[name].matrix_local-original_rest[name]) for v in row) < 1e-6

# The supplied mannequin itself supplies the undersuit and articulated fingers.
# Remove only the covered head geometry, preserving the existing sealed mask.
bm = bmesh.new(); bm.from_mesh(mannequin.data); layer = bm.verts.layers.deform.active
head_groups = {g.index for g in mannequin.vertex_groups if g.name == 'DEF-head'}
bmesh.ops.delete(bm, geom=[v for v in bm.verts if any(v[layer].get(i,0)>.1 for i in head_groups)], context='VERTS')
bm.to_mesh(mannequin.data); bm.free()
mannequin.name='Fulcrum_UAL_Undersuit'
mannequin.data.materials.clear(); mannequin.data.materials.append(bpy.data.materials['Fulcrum_BlackLeather'])
for p in mannequin.data.polygons: p.material_index=0; p.use_smooth=True

# Refit the existing costume, preserving UVs, materials and decorative topology.
for obj in [body,weapon]:
    for v in obj.data.vertices:
        co = obj.matrix_world @ v.co
        weights = [(obj.vertex_groups[g.group].name,g.weight) for g in v.groups if g.weight>0]
        result = Vector((0,0,0)); total=sum(w for n,w in weights)
        for n,w in weights: result += (transforms[n] @ co) * (w/total)
        v.co=result
        if obj == body and co.z < .14: v.co.z=max(.004,v.co.z)
    obj.matrix_world=Matrix.Identity(4)
    for group in obj.vertex_groups:
        if group.name in mapping: group.name=mapping[group.name]
    obj.parent=rig; obj.matrix_parent_inverse=Matrix.Identity(4)
    for mod in obj.modifiers:
        if mod.type=='ARMATURE': mod.object=rig

# Replace old single-bone curled fingers with the supplied three-joint fingers.
bm=bmesh.new(); bm.from_mesh(body.data); layer=bm.verts.layers.deform.active
finger_groups={g.index for g in body.vertex_groups if 'DEF-f_' in g.name or 'DEF-thumb' in g.name}
bmesh.ops.delete(bm,geom=[v for v in bm.verts if any(v[layer].get(i,0)>.1 for i in finger_groups)],context='VERTS')
bm.to_mesh(body.data); bm.free()
bpy.data.objects.remove(old,do_unlink=True)

plans = {'Idle':('Idle_Loop',0,False), 'Walk':('Walk_Loop',0,False), 'Run':('Jog_Fwd_Loop',0,False),
         'Sprint':('Sprint_Loop',0,False), 'CastEnter':('Spell_Simple_Enter',0,False), 'Cast':('Spell_Simple_Idle_Loop',0,False),
         'CastRelease':('Spell_Simple_Shoot',0,False), 'CastExit':('Spell_Simple_Exit',0,False),
         'JumpStart':('Jump_Start',0,False), 'JumpLoop':('Jump_Loop',0,False), 'JumpLand':('Jump_Land',0,False)}
for prefix, source in [('Walk','Walk_Loop'),('Run','Jog_Fwd_Loop'),('Sprint','Sprint_Loop')]:
    for suffix, angle, reverse in [('Backward',0,True),('Left',90,False),('Right',-90,False),
                                   ('ForwardLeft',45,False),('ForwardRight',-45,False),('BackwardLeft',-45,True),('BackwardRight',45,True)]:
        label = ('Strafe'+suffix if prefix=='Walk' and suffix in ['Left','Right'] else prefix+suffix)
        plans[label] = (source,angle,reverse)

scene=bpy.context.scene
samples={}
def upper_body_heading(angle, reverse):
    if not angle: return 0.0
    # A small visual turn toward lateral travel, including backward diagonals.
    return math.copysign(20.0 if abs(angle)==90 else 14.0, -angle if reverse else angle)
for label,(source,angle,reverse) in plans.items():
    a=actions[source]; rig.animation_data_create(); rig.animation_data.action=a
    if a.slots: rig.animation_data.action_slot=a.slots[0]
    duration=(a.frame_range[1]-a.frame_range[0])/source_fps
    count=round(duration*30)
    frames=[]
    for i in range(count+1):
        f=a.frame_range[0]+(a.frame_range[1]-a.frame_range[0])*(1-i/count if reverse else i/count)
        scene.frame_set(int(f),subframe=f-int(f))
        pose={p.name:p.matrix.copy() for p in rig.pose.bones if p.name in core}
        pelvis_heading=angle*.65
        torso_heading=upper_body_heading(angle,reverse)
        for n in core:
            if n=='root': continue
            if any(k in n for k in ['DEF-thigh','DEF-shin','DEF-foot','DEF-toe']): heading=angle
            elif n=='DEF-hips': heading=pelvis_heading
            elif n=='DEF-spine.001': heading=(2*pelvis_heading+torso_heading)/3
            elif n=='DEF-spine.002': heading=(pelvis_heading+2*torso_heading)/3
            else: heading=torso_heading
            # Keep the feet's original directional path; distribute the
            # pelvis-to-chest difference over the spine instead of locking
            # the chest/head/arms forward over a fully sideways pelvis.
            if heading: pose[n]=Matrix.Rotation(math.radians(heading),4,'Z') @ pose[n]
        frames.append(pose)
    samples[label]=(duration,frames)
rig.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
scene.render.fps=30
all_bones=list(rig.data.bones)
for p in rig.pose.bones: p.rotation_mode='QUATERNION'
loop_names = [n for n in plans if n not in ['CastEnter','CastRelease','CastExit','JumpStart','JumpLand']]
for label,(duration,frames) in samples.items():
    action=bpy.data.actions.new(label); rig.animation_data_create(); rig.animation_data.action=action
    for i,pose in enumerate(frames):
        t=i/(len(frames)-1); phase=t*2*math.pi
        for b in all_bones:
            p=rig.pose.bones[b.name]
            if b.name in core:
                parent=b.parent
                p.matrix_basis = (b.matrix_local.inverted() @ (parent.matrix_local @ pose[parent.name].inverted() if parent else Matrix.Identity(4)) @ pose[b.name])
            else:
                p.matrix_basis=Matrix.Identity(4)
                if b.name.startswith(('robe','hem','mantle')):
                    # Costume-only follow-through; the preset body motion is intact.
                    j=extras.index(b.name); amplitude=.065 if label.startswith(('Run','Strafe')) else .035
                    p.rotation_quaternion=Quaternion((1,0,0), math.sin(phase+j*.6)*amplitude)
                if b.name=='gravity.focus':
                    palm=pose['DEF-hand.L'].translation
                    target=palm+Vector((.24,-.055,.22))
                    desired=Matrix.Translation(target)
                    p.matrix_basis=b.matrix_local.inverted() @ rig.data.bones['root'].matrix_local @ pose['root'].inverted() @ desired
                if b.name.startswith('gravity.') and b.name!='gravity.focus':
                    p.rotation_quaternion=Quaternion((0,1,0),phase*(1 if b.name=='gravity.outer' else -1))
            p.keyframe_insert('location',frame=i+1,group=b.name)
            p.keyframe_insert('rotation_quaternion',frame=i+1,group=b.name)
            p.keyframe_insert('scale',frame=i+1,group=b.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points: key.interpolation='LINEAR'
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new(); track.name=label
    strip=track.strips.new(label,1,action); strip.action_frame_start=1; strip.action_frame_end=len(frames)
    track.mute=True
for tr in rig.animation_data.nla_tracks: tr.mute=tr.name!='Walk'
scene.frame_start=1; scene.frame_end=len(samples['Walk'][1]); scene.frame_set(1)
rig.show_in_front=True
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.region_3d.view_location=Vector((0,0,.95))
            space.region_3d.view_distance=3.7
            space.region_3d.view_rotation=Quaternion((1,0,0),math.radians(85))
            space.shading.type='SOLID'; space.shading.color_type='MATERIAL'
            space.overlay.show_overlays=False
for image in bpy.data.images:
    if image.source=='FILE' and not image.packed_file:
        try: image.pack()
        except RuntimeError: pass
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,body,weapon,mannequin]: o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'fulcrum_ual.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'fulcrum.glb'),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='NLA_TRACKS',export_apply=False)
record={'library_sha256':hashlib.sha256((SOURCE/'AnimationLibrary_Godot_Standard.glb').read_bytes()).hexdigest(),
        'costume_source_sha256':hashlib.sha256((SOURCE/'costume_source.blend').read_bytes()).hexdigest(),
        'blender':bpy.app.version_string,'library_bones':len(core),'total_bones':len(all_bones),
        'core_rest_matrices':{n:[list(r) for r in original_rest[n]] for n in core},
        'directional_body_revision':'r004: pelvis 65% of leg heading; chest/head/arms 20 degrees sideways, 14 degrees diagonal toward lateral travel; distributed spine twist',
        'bone_map':mapping,'animations':{n:{'source':v[0],'heading_degrees':v[1],'upper_body_heading_degrees':upper_body_heading(v[1],v[2]),'pelvis_heading_degrees':v[1]*.65,'reversed':v[2],'seconds':samples[n][0],
            'loop':n in loop_names} for n,v in plans.items()}}
(SOURCE/'recipe.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('FULCRUM_UAL_BUILD_COMPLETE',len(all_bones),'bones',len(plans),'clips')
