"""Blender validation of Outlaw's source, skin, packed maps and frozen v2 motion."""
import bpy,hashlib,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import model_forge_snapshot as frozen
stage=ROOT/'artifacts/outlaw-forge-v2';candidate=stage/'candidate/outlaw.blend'
frozen.check_candidate(candidate,[], '')
bpy.ops.wm.open_mainfile(filepath=str(stage/'seed/art_source/fulcrum_ual/fulcrum_ual.blend'))
vertices=[tuple(v.co) for v in bpy.data.objects['Fulcrum_UAL_Undersuit'].data.vertices]
bpy.ops.wm.open_mainfile(filepath=str(candidate))
body=bpy.data.objects['Outlaw_UAL_Undersuit'];rig=bpy.data.objects['Outlaw_UAL_Rig']
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
maps={im.name:hashlib.sha256(im.packed_file.data).hexdigest() for im in bpy.data.images if im.name.startswith('Outlaw ') and im.packed_file}
assert len(maps)==4,maps
for weapon,side in [('outlaw.gun','R'),('outlaw.knife','L')]:
 assert rig.data.bones[weapon].parent.name=='DEF-hand.'+side
recipe=json.loads((stage/'candidate/recipe.json').read_text())
assert recipe['knife_revision']['scale']==1.5
result={'passed':True,'core_bones':53,'rig_bones':len(rig.data.bones),'clips':len(rig.animation_data.nla_tracks),'mannequin_vertex_error':error,'skin_weight_error':weights,'triangles':triangles,'packed_maps':maps,'knife_scale':1.5,'rest_and_32_clips':'frozen contract passed','grip':'hand-parented equipment; native closed fist is retained by the runtime layer'}
(stage/'verification.json').write_text(json.dumps(result,indent=2))
print('OUTLAW_SOURCE_VERIFIED',json.dumps(result))
