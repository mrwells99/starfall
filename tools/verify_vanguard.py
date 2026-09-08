"""Validate exported-source weights, grip reach, loop closure and foot contact."""
import bpy,os,json,math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art_source/vanguard.blend'))
rig=bpy.data.objects['Vanguard_Rig'];body=bpy.data.objects['Vanguard_SkinnedModel'];scene=bpy.context.scene
report={'weight_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices),'clips':{}}
for tr in rig.animation_data.nla_tracks:
 for other in rig.animation_data.nla_tracks:other.mute=other!=tr
 end=int(tr.strips[0].frame_end);max_wrist_gap=0.;min_sole=10.;max_loop=0.
 scene.frame_set(1);first={p.name:p.matrix.copy() for p in rig.pose.bones}
 for f in range(1,end+1):
  scene.frame_set(f)
  for side in ['L','R']:
   max_wrist_gap=max(max_wrist_gap,(rig.pose.bones['forearm.'+side].tail-rig.pose.bones['hand.'+side].head).length)
   if tr.name in ['Walk','Run','WalkBackward','StrafeLeft','StrafeRight']:
    bone=rig.pose.bones['foot.'+side];mat=bone.matrix@bone.bone.matrix_local.inverted()
    for p in [(0,-.27,.018),(0,.11,.018)]:min_sole=min(min_sole,(mat@Vector((p[0]+(.185 if side=='L' else -.185),p[1],p[2]))).z)
 scene.frame_set(end)
 for p in rig.pose.bones:max_loop=max(max_loop,(p.matrix.translation-first[p.name].translation).length,p.matrix.to_quaternion().rotation_difference(first[p.name].to_quaternion()).angle)
 report['clips'][tr.name]={'max_wrist_gap_m':max_wrist_gap,'min_sampled_sole_m':min_sole if min_sole<10 else None,'loop_error':max_loop}
assert all(c['min_sampled_sole_m'] is None or c['min_sampled_sole_m'] >= -.005 for c in report['clips'].values()),report
assert report['weight_error']<.0001
assert all(c['max_wrist_gap_m']<.025 for c in report['clips'].values()),report
assert all(c['loop_error']<.002 for c in report['clips'].values()),report
with open(os.path.join(ROOT,'artifacts/vanguard_new/verification.json'),'w') as f:json.dump(report,f,indent=2)
print('VANGUARD_VERIFIED',json.dumps(report))
