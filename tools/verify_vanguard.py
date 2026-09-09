"""Validate exported-source weights, grip reach, loop closure and foot contact."""
import bpy,os,json,math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'artifacts/vanguard_rebuild_20260908')
os.makedirs(OUT,exist_ok=True)
# Preserve the preceding Vanguard's complete core animation, including two-handed grip.
baseline_path=os.path.join(ROOT,'artifacts/vanguard_before_reference/art_source/vanguard.blend')
baseline={}
if os.path.exists(baseline_path):
 bpy.ops.wm.open_mainfile(filepath=baseline_path)
 old=bpy.data.objects['Vanguard_Rig']
 for tr in old.animation_data.nla_tracks:
  for other in old.animation_data.nla_tracks:other.mute=other!=tr
  for frame in range(1,int(tr.strips[0].frame_end)+1):
   bpy.context.scene.frame_set(frame)
   for p in old.pose.bones:baseline[(tr.name,frame,p.name)]=[v for row in p.matrix_basis for v in row]
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art_source/vanguard.blend'))
rig=bpy.data.objects['Vanguard_Rig'];body=bpy.data.objects['Vanguard_SkinnedModel'];scene=bpy.context.scene
report={'weight_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),'clips':{}}
assert len(rig.data.bones)==45
assert len(body.data.uv_layers)>0
assert all(not any(word in m.name.lower() for word in ['hair','skin','eye','lip']) for m in body.data.materials)
assert all(im.packed_file is not None for im in bpy.data.images if im.name.startswith('Vanguard '))
assert len([im for im in bpy.data.images if im.name.startswith('Vanguard ')])==6
parity=0.;grip=0.;cape_motion={}
for i in range(3):
 for name in ['cape%d'%i,'cape_tip%d'%i]:
  group=body.vertex_groups[name].index
  assert any(any(g.group==group and g.weight>0 for g in v.groups) for v in body.data.vertices),name
for tr in rig.animation_data.nla_tracks:
 for other in rig.animation_data.nla_tracks:other.mute=other!=tr
 end=int(tr.strips[0].frame_end);max_wrist_gap=0.;min_sole=10.;max_loop=0.
 scene.frame_set(1);first={p.name:p.matrix.copy() for p in rig.pose.bones}
 weapon_rest=rig.data.bones['weapon'].matrix_local.inverted()
 for f in range(1,end+1):
  scene.frame_set(f)
  for p in rig.pose.bones:
   key=(tr.name,f,p.name)
   if key in baseline:parity=max(parity,max(abs(a-b) for a,b in zip(baseline[key],[v for row in p.matrix_basis for v in row])))
  weapon_transform=rig.pose.bones['weapon'].matrix@weapon_rest
  for side in ['L','R']:
   grip=max(grip,(rig.pose.bones['hand.'+side].tail-weapon_transform@rig.data.bones['hand.'+side].tail_local).length)
   max_wrist_gap=max(max_wrist_gap,(rig.pose.bones['forearm.'+side].tail-rig.pose.bones['hand.'+side].head).length)
   if tr.name in ['Walk','Run','WalkBackward','StrafeLeft','StrafeRight']:
    bone=rig.pose.bones['foot.'+side];mat=bone.matrix@bone.bone.matrix_local.inverted()
    for p in [(0,-.27,.018),(0,.11,.018)]:min_sole=min(min_sole,(mat@Vector((p[0]+(.185 if side=='L' else -.185),p[1],p[2]))).z)
 scene.frame_set(end)
 for p in rig.pose.bones:max_loop=max(max_loop,(p.matrix.translation-first[p.name].translation).length,p.matrix.to_quaternion().rotation_difference(first[p.name].to_quaternion()).angle)
 report['clips'][tr.name]={'max_wrist_gap_m':max_wrist_gap,'min_sampled_sole_m':min_sole if min_sole<10 else None,'loop_error':max_loop}
 if tr.name=='Walk':
  scene.frame_set(19)
  for name in ['cape%d'%i for i in range(3)]+['cape_tip%d'%i for i in range(3)]:
   cape_motion[name]=rig.pose.bones[name].matrix.to_quaternion().rotation_difference(first[name].to_quaternion()).angle
   assert cape_motion[name]>.003
assert all(c['min_sampled_sole_m'] is None or c['min_sampled_sole_m'] >= -.005 for c in report['clips'].values()),report
assert report['weight_error']<.0001
assert all(c['max_wrist_gap_m']<.025 for c in report['clips'].values()),report
assert all(c['loop_error']<.002 for c in report['clips'].values()),report
assert grip<.00001,grip
assert parity<.00001,parity
report.update({'baseline_bone_frame_samples':len(baseline),'baseline_max_channel_error':parity if baseline else None,'max_weapon_grip_error_m':grip,'cape_walk_motion_radians':cape_motion})
with open(os.path.join(OUT,'verification.json'),'w') as f:json.dump(report,f,indent=2)
print('VANGUARD_VERIFIED',json.dumps(report))
# Inspect moving poses in the same studio as the static model.
scene.cycles.samples=20
for clip,frame in [('Walk',10),('Run',7),('Strike',13)]:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=clip
 scene.frame_set(frame);scene.render.filepath=os.path.join(OUT,clip.lower()+'.png');bpy.ops.render.render(write_still=True)
