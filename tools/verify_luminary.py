"""Validate skin/stance in the editable Blender source and render motion samples."""
import bpy,os,json,math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Verify inherited gait channels against Ember, not just nominal clip names.
shared=['root','pelvis','spine','chest','neck','head']+[b+'.'+side for b in ['thigh','shin','foot','toe'] for side in ['L','R']]
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art_source','ember.blend'))
e=bpy.data.objects['Ember_Rig'];baseline={}
for name,frames in [('Idle',60),('Walk',36),('Run',22),('WalkBackward',40),('StrafeLeft',34),('StrafeRight',34),('Cast',48)]:
 for tr in e.animation_data.nla_tracks:tr.mute=tr.name!=name
 for f in [1,frames//3+1,2*frames//3+1,frames+1]:
  bpy.context.scene.frame_set(f)
  for b in shared:baseline[(name,f,b)]=[v for row in e.pose.bones[b].matrix_basis for v in row]
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art_source','luminary.blend'))
rig=bpy.data.objects['Luminary_Rig'];body=bpy.data.objects['Luminary_SkinnedModel'];scene=bpy.context.scene
assert len(rig.data.bones)==59
assert not any('hair' in b.name.lower() for b in rig.data.bones), 'Hair controls must be removed'
for m in body.data.materials:
 assert not any(word in m.name.lower() for word in ['skin','hair','lash','iris','lip','eyewhite']),m.name
assert any(m.name=='Luminary_FeaturelessShadow' for m in body.data.materials)
bad=[v.index for v in body.data.vertices if abs(sum(g.weight for g in v.groups)-1)>0.0001]
assert not bad, 'Unnormalized or unweighted vertices'
report={'weighted_vertices':len(body.data.vertices),'stance_max_error_m':{}}
for name,frames,stance in [('Walk',36,.6),('Run',22,.38),('WalkBackward',40,.6),('StrafeLeft',34,.6),('StrafeRight',34,.6)]:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 errors=[]
 for f in range(frames):
  scene.frame_set(f+1)
  for side,s in [('L',1),('R',-1)]:
   q=(f/frames+(0 if s==1 else .5))%1
   if q<stance:errors.append(abs(rig.pose.bones['foot.'+side].head.z-.14))
 report['stance_max_error_m'][name]=max(errors)
 assert max(errors)<.02,(name,max(errors))
maximum_parity_error=0.0
for (name,f,b),values in baseline.items():
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 scene.frame_set(f)
 actual=[v for row in rig.pose.bones[b].matrix_basis for v in row]
 maximum_parity_error=max(maximum_parity_error,max(abs(a-bb) for a,bb in zip(actual,values)))
assert maximum_parity_error<0.00001,maximum_parity_error
report['inherited_gait_max_error']=maximum_parity_error
report['inherited_gait_samples']=len(baseline)
scene.cycles.samples=12;scene.render.resolution_x=600;scene.render.resolution_y=760
scene.camera.location=(4,-1,1.9);scene.camera.rotation_euler=(Vector((0,0,1.1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
for name,frame in [('Walk',10),('Walk',28),('Run',7),('Run',18)]:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 scene.frame_set(frame);scene.render.filepath=os.path.join(ROOT,'artifacts','luminary',name.lower()+'-%02d.png'%frame);bpy.ops.render.render(write_still=True)
with open(os.path.join(ROOT,'artifacts','luminary','motion_report.json'),'w') as f:json.dump(report,f,indent=2)
print('LUMINARY_MOTION_VERIFIED',json.dumps(report))
