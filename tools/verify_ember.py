"""Validate skin/stance in the editable Blender source and render motion samples."""
import bpy,os,json,math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'art_source','ember.blend'))
rig=bpy.data.objects['Ember_Rig'];body=bpy.data.objects['Ember_SkinnedModel'];scene=bpy.context.scene
assert len(rig.data.bones)==52
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
scene.cycles.samples=12;scene.render.resolution_x=600;scene.render.resolution_y=760
scene.camera.location=(4,-1,1.9);scene.camera.rotation_euler=(Vector((0,0,1.1))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
for name,frame in [('Walk',10),('Walk',28),('Run',7),('Run',18)]:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 scene.frame_set(frame);scene.render.filepath=os.path.join(ROOT,'artifacts','ember',name.lower()+'-%02d.png'%frame);bpy.ops.render.render(write_still=True)
with open(os.path.join(ROOT,'artifacts','ember','motion_report.json'),'w') as f:json.dump(report,f,indent=2)
print('EMBER_MOTION_VERIFIED',json.dumps(report))
