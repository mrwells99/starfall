"""Verify anatomy against the actual library, plus skinning and source motion."""
import bpy, json, math
from pathlib import Path
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'art_source/fulcrum_ual'
OUT=ROOT/'artifacts/fulcrum-turn-r004'
recipe=json.loads((SOURCE/'recipe.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE/'AnimationLibrary_Godot_Standard.glb'))
original=next(o for o in bpy.data.objects if o.type=='ARMATURE')
original.animation_data_clear()
rest={b.name:(b.matrix_local.copy(),b.parent.name if b.parent else None) for b in original.data.bones}
body=bpy.data.objects['Mannequin']
tree=KDTree(len(body.data.vertices))
for v in body.data.vertices: tree.insert(v.co,v.index)
tree.balance()
expected={}
for label, spec in recipe['animations'].items():
    if spec['heading_degrees'] or spec['reversed']: continue
    a=bpy.data.actions[spec['source']]; original.animation_data_create(); original.animation_data.action=a
    if a.slots: original.animation_data.action_slot=a.slots[0]
    poses=[]
    for t in [0,.25,.5,.75,1]:
        f=a.frame_range[0]+(a.frame_range[1]-a.frame_range[0])*t
        bpy.context.scene.frame_set(int(f),subframe=f-int(f))
        poses.append({p.name:p.matrix.copy() for p in original.pose.bones})
    expected[label]=poses
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'fulcrum_ual.blend'))
rig=bpy.data.objects['Fulcrum_UAL_Rig']
failures=[]
rest_error=max(abs(x) for n,(m,p) in rest.items() for row in (rig.data.bones[n].matrix_local-m) for x in row)
assert rest_error<1e-6
assert all((rig.data.bones[n].parent.name if rig.data.bones[n].parent else None)==p for n,(m,p) in rest.items())
undersuit=bpy.data.objects['Fulcrum_UAL_Undersuit']
body_error=max(tree.find(v.co)[2] for v in undersuit.data.vertices)
assert body_error<1e-6
skin_error=0.0
for ob in [o for o in bpy.data.objects if o.type=='MESH']:
    assert len(ob.data.uv_layers)>0
    for v in ob.data.vertices:
        weights=[g.weight for g in v.groups if ob.vertex_groups[g.group].name in rig.data.bones]
        assert weights and all(math.isfinite(x) for x in v.co)
        skin_error=max(skin_error,abs(sum(weights)-1))
assert skin_error<1e-4
motion_error=0.0
clip_errors={}
for label,poses in expected.items():
    clip_error=0.0
    for track in rig.animation_data.nla_tracks: track.mute=track.name!=label
    track=next(t for t in rig.animation_data.nla_tracks if t.name==label)
    strip=track.strips[0]
    for t,expected_pose in zip([0,.25,.5,.75,1],poses):
        f=strip.frame_start+(strip.frame_end-strip.frame_start)*t
        bpy.context.scene.frame_set(int(f),subframe=f-int(f))
        clip_error=max(clip_error,max(abs(x) for n,m in expected_pose.items() for row in (rig.pose.bones[n].matrix-m) for x in row))
    clip_errors[label]=clip_error
    motion_error=max(motion_error,clip_error)
print('SOURCE_MOTION_ERRORS',clip_errors)
# Different sampling frequencies introduce interpolation error between baked keys.
assert motion_error<1e-4, motion_error
result={'passed':True,'core_bones':len(rest),'total_bones':len(rig.data.bones),'preset_rest_max_error':rest_error,
        'preset_body_vertex_max_error_metres':body_error,'skin_weight_max_error':skin_error,
        'source_motion_max_matrix_component_error':motion_error,'source_motion_clips':list(expected),
        'notes':['Directional clips intentionally rotate lower-body heading or reverse source time.',
                 'Covered mannequin head removed; retained preset body vertices are unchanged.',
                 'Costume cloth and weapon controls are additional and are not anatomical edits.']}
(OUT/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('FULCRUM_UAL_VERIFIED',json.dumps(result))
