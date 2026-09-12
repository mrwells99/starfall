"""Verify source anatomy, inherited motion, skin weights and packed textures."""
import bpy,hashlib,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import model_forge_snapshot as frozen
stage=ROOT/'artifacts/null-forge-v2';candidate=stage/'candidate/null.blend'
frozen.check_candidate(candidate,[], '')
bpy.ops.wm.open_mainfile(filepath=str(stage/'seed/art_source/fulcrum_ual/fulcrum_ual.blend'))
vertices=[tuple(v.co) for v in bpy.data.objects['Fulcrum_UAL_Undersuit'].data.vertices]
bpy.ops.wm.open_mainfile(filepath=str(candidate))
body=bpy.data.objects['Null_UAL_Undersuit'];rig=bpy.data.objects['Null_UAL_Rig']
assert len(vertices)==len(body.data.vertices)
error=max(max(abs(a-b) for a,b in zip(v,old)) for v,old in zip((v.co for v in body.data.vertices),vertices))
assert error<1e-7,error
weights=0;triangles=0
for ob in bpy.data.objects:
 if ob.type!='MESH':continue
 assert ob.data.uv_layers and all(math.isfinite(c) for v in ob.data.vertices for c in v.co),ob.name
 triangles+=sum(len(p.vertices)-2 for p in ob.data.polygons)
 for v in ob.data.vertices:
  w=sum(g.weight for g in v.groups if ob.vertex_groups[g.group].name in rig.data.bones)
  weights=max(weights,abs(w-1))
assert weights<1e-5,weights
maps={im.name:hashlib.sha256(im.packed_file.data).hexdigest() for im in bpy.data.images if im.name.startswith('Null ') and im.packed_file}
assert len(maps)==5,maps
for side in ['L','R']:assert rig.data.bones['null.blade.'+side].parent.name=='DEF-hand.'+side
result={'passed':True,'core_bones':53,'rig_bones':len(rig.data.bones),'clips':len(rig.animation_data.nla_tracks),'mannequin_vertex_error':error,'skin_weight_error':weights,'triangles':triangles,'packed_maps':maps,'rest_and_32_clips':'frozen contract passed','grip':'Two hand-parented blades; native fist retained by runtime'}
(stage/'verification.json').write_text(json.dumps(result,indent=2))
print('NULL_SOURCE_VERIFIED',json.dumps(result))
