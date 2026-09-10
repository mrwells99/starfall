"""Verify fitted classes against the frozen v2 core, mannequin, and source maps."""
import argparse, bpy, hashlib, json, math, pathlib, sys
sys.dont_write_bytecode=True
from mathutils.kdtree import KDTree
ROOT=pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
import model_forge_snapshot as frozen
parser=argparse.ArgumentParser()
parser.add_argument('--class',dest='slug',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
slug=args.slug
source=ROOT/f'art_source/{slug}_ual'
area=ROOT/f'artifacts/forge-v2-all-classes/{slug}'
recipe=json.loads((source/'recipe.json').read_text())
allowed=recipe['equipment']['motion_exceptions']
frozen.check_candidate(area/(slug+'.blend'),allowed,('Right fingers retain the supplied idle grip around the staff' if slug=='luminary' else 'Minimum two-handed hammer grip; source torso/legs/timing preserved') if allowed else '')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art_source/model_forge_v2/AnimationLibrary_Godot_Standard.glb'))
body=bpy.data.objects['Mannequin']
tree=KDTree(len(body.data.vertices))
for v in body.data.vertices: tree.insert(v.co,v.index)
tree.balance()
bpy.ops.wm.open_mainfile(filepath=str(source/'costume_source.blend'))
original_images={i.name:hashlib.sha256(i.packed_file.data).hexdigest() for i in bpy.data.images if i.packed_file}
bpy.ops.wm.open_mainfile(filepath=str(area/(slug+'.blend')))
rig=bpy.data.objects[slug.title()+'_UAL_Rig']
mannequin=bpy.data.objects[slug.title()+'_UAL_Undersuit']
error=max(tree.find(v.co)[2] for v in mannequin.data.vertices)
assert error<1e-6,error
weight_error=0.;triangles=0;materials=[]
for obj in bpy.data.objects:
 if obj.type!='MESH':continue
 assert obj.data.uv_layers,obj.name
 triangles+=sum(len(p.vertices)-2 for p in obj.data.polygons)
 materials += [m.name for m in obj.data.materials]
 for vertex in obj.data.vertices:
  assert all(math.isfinite(c) for c in vertex.co)
  weights=[g.weight for g in vertex.groups if obj.vertex_groups[g.group].name in rig.data.bones]
  assert weights,obj.name
  weight_error=max(weight_error,abs(sum(weights)-1))
assert weight_error<1e-4,weight_error
for image in bpy.data.images:
 if image.name in original_images:
  assert image.packed_file and hashlib.sha256(image.packed_file.data).hexdigest()==original_images[image.name],image.name
assert not any('hair' in n.lower() or 'eyewhite' in n.lower() for n in materials)
report={'passed':True,'class':slug,'core_bones':53,'total_bones':len(rig.data.bones),'clips':len(rig.animation_data.nla_tracks),
 'mannequin_vertex_max_error':error,'skin_weight_max_error':weight_error,'triangles':triangles,'materials':sorted(set(materials)),
 'preserved_packed_image_hashes':original_images,'equipment':recipe['equipment'],'v2_core_contract_passed':True}
(area/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('MODEL_FORGE_CLASS_VERIFIED',json.dumps(report),flush=True)
