"""Stage two of build_fulcrum.py: add the approved gravity weapon to the staged base."""
import bpy, math, json, ast, hashlib
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler
from math import sin, cos, pi, sqrt
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent;HERE=ROOT/'artifacts/fulcrum'
BASE=HERE/'base_fulcrum.blend'
bpy.ops.wm.open_mainfile(filepath=str(BASE))
scene=bpy.context.scene;rig=bpy.data.objects['Fulcrum_Rig'];ad=rig.data;body=bpy.data.objects['Fulcrum_SkinnedModel']
assert 'gravity.focus' not in ad.bones, 'Weapon stage requires the base source, not an already armed model'
CLIPS=[('Idle',60),('Walk',36),('Run',22),('WalkBackward',40),('StrafeLeft',34),('StrafeRight',34),('Cast',48)]
baseline={};old_names=[p.name for p in rig.pose.bones]
for name,frames in CLIPS:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 baseline[name]=[]
 for f in range(1,frames+2):
  scene.frame_set(f);baseline[name].append({p.name:p.matrix_basis.copy() for p in rig.pose.bones})
rig.animation_data_clear()
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
origin=Vector((.68,-.30,1.49))
for name,parent in [('gravity.focus','root'),('gravity.outer','gravity.focus'),('gravity.inner','gravity.focus'),('gravity.debris','gravity.focus')]:
 b=ad.edit_bones.new(name);b.head=origin;b.tail=origin+Vector((0,.12,0));b.parent=ad.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
# Execute only geometry helper definitions; never run the approved builder.
parts=[];tree=ast.parse((ROOT/'tools/build_fulcrum.py').read_text(encoding='utf-8-sig'))
helpers=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['mat','mesh','surface','tube','ellipse','ring']]
exec(compile(ast.Module(body=helpers,type_ignores=[]),'geometry_helpers','exec'))
steel=bpy.data.materials['Fulcrum_BlackenedGunmetal'];bronze=bpy.data.materials['Fulcrum_MutedBronze'];pewter=bpy.data.materials['Fulcrum_WeatheredPewter']
black=bpy.data.materials['Fulcrum_AbsoluteVoid'];violet=bpy.data.materials['Fulcrum_GravityLight']
light=bpy.data.materials.get('Fulcrum_PaleSingularity') or mat('Fulcrum_PaleSingularity',(.69,.35,1),.15,.35,2.3)
ellipse('Weapon singularity core',origin,(.077,.077,.077),black,'gravity.focus',48,28)
for j,tilt in enumerate([.24,-.67]):
 q=Quaternion(Vector((1,.4,0)).normalized(),tilt)
 pts=[origin+q@Vector((.083*cos(a),.018*sin(a),.083*sin(a))) for a in np.linspace(0,2*pi,100)]
 tube('Singularity violet event horizon',pts,.0022 if j==0 else .0014,light if j==0 else violet,'gravity.focus',8)
# Thin broken forged rails with rectangular cross-sections and violet conductors.
def band(name,radius,tilt,start,end,bn):
 q=Quaternion(Vector((1,0,.25)).normalized(),tilt);vs=[];fs=[];steps=40
 for k,a in enumerate(np.linspace(start,end,steps+1)):
  t=k/steps;w=.007*(.38+.62*sin(pi*t)**.3);depth=.0035
  for dr,dy in [(-w,-depth),(w,-depth),(w,depth),(-w,depth)]:vs.append(origin+q@Vector(((radius+dr)*cos(a),dy,(radius+dr)*sin(a))))
 for k in range(steps):
  for i in range(4):fs.append((k*4+i,k*4+(i+1)%4,(k+1)*4+(i+1)%4,(k+1)*4+i))
 fs.extend([(3,2,1,0),(steps*4,steps*4+1,steps*4+2,steps*4+3)])
 mesh(name,vs,fs,bronze,{bn:1})
 tube(name+' violet conductor',[origin+q@Vector(((radius+.008)*cos(a),-.004,(radius+.008)*sin(a))) for a in np.linspace(start+.09,end-.09,44)],.0013,violet,bn,6)
 return q
for j,(rad,tilt,bn) in enumerate([(.196,.38,'gravity.outer'),(.143,-.82,'gravity.inner')]):
 for k in range(3):
  a=k*2*pi/3+.13+j*.22;q=band('Broken orbital rail '+str(j)+str(k),rad,tilt,a,a+1.56,bn)
  for aa in [a+.08,a+1.48]:
   p=origin+q@Vector((rad*cos(aa),0,rad*sin(aa)));ellipse('Rail bronze rivet',p,(.005,.004,.005),pewter,bn,12,8)
  aa=a+.77;p=origin+q@Vector((rad*cos(aa),0,rad*sin(aa)));tip=origin+q@Vector(((rad+.033)*cos(aa+.018),0,(rad+.033)*sin(aa+.018)))
  tube('Orbital tapered index',[p,tip],lambda t:.004*(1-t)+.0005,pewter,bn,6)
rng=np.random.default_rng(187)
for i in range(19):
 a=i*2*pi/19;rad=float(rng.uniform(.115,.224));p=origin+Vector((rad*cos(a),float(rng.uniform(-.055,.07)),rad*sin(a)));size=float(rng.uniform(.010,.023))
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p)
 ob=bpy.context.object;ob.name='Captured obsidian fragment %02d'%i;ob.scale=(size*.65,size*.5,size*1.4);ob.rotation_euler=(i*.6,i*.27,i*.83)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);ob.data.materials.append(steel)
 ob.vertex_groups.new(name='gravity.debris').add(list(range(len(ob.data.vertices))),1,'REPLACE');parts.append(ob)
 if i%3==0:ellipse('Suspended violet mote',p+Vector((.006,-.013,.008)),(.0025,.0025,.0025),light,'gravity.debris',10,6)
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();weapon=bpy.context.object;weapon.name='Fulcrum_GravityWeapon'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
mod=weapon.modifiers.new('Gravity weapon controls','ARMATURE');mod.object=rig;weapon.parent=rig
def aim(name,target):
 p=rig.pose.bones[name];head=p.head.copy();current=p.matrix.to_quaternion();delta=(current@Vector((0,1,0))).rotation_difference((Vector(target)-head).normalized())
 m=(delta@current).to_matrix().to_4x4();m.translation=head;p.matrix=m;bpy.context.view_layer.update()
def palm_pose(wrist):
 bn='hand.L';rest=ad.bones[bn].matrix_local.to_3x3();d0=(rest@Vector((0,1,0))).normalized();n0=Vector((0,1,0));n0=(n0-d0*n0.dot(d0)).normalized();x0=d0.cross(n0).normalized()
 d1=Vector((.94,-.17,.23)).normalized();n1=Vector((0,0,1));n1=(n1-d1*n1.dot(d1)).normalized();x1=d1.cross(n1).normalized()
 old=Matrix((x0,d0,n0)).transposed();new=Matrix((x1,d1,n1)).transposed();m=(new@old.inverted()@rest).to_4x4();m.translation=wrist;rig.pose.bones[bn].matrix=m
def key(frame):
 for p in rig.pose.bones:
  p.keyframe_insert('location',frame=frame,group=p.name);p.keyframe_insert('rotation_quaternion',frame=frame,group=p.name);p.keyframe_insert('scale',frame=frame,group=p.name)
changed={'upper_arm.L','forearm.L','hand.L'}|{'finger%d.L'%i for i in range(5)}
parity=0.;clearance=10.;loop_errors={}
for clip,frames in CLIPS:
 rig.animation_data_create();action=bpy.data.actions.new('WeaponPreview_'+clip);rig.animation_data.action=action;action.use_fake_user=True
 for frame in range(frames+1):
  ph=2*pi*frame/frames;running=clip=='Run';casting=clip=='Cast'
  for p in rig.pose.bones:p.matrix_basis=baseline[clip][frame].get(p.name,Matrix.Identity(4))
  bpy.context.view_layer.update()
  wrist=Vector((.51,-.235,1.17+(.055 if casting else 0)-(.12 if running else 0)+.008*sin(ph)))
  shoulder=rig.pose.bones['upper_arm.L'].head.copy();d=wrist-shoulder;dist=min(d.length,.566);axis=d.normalized();l1=ad.bones['upper_arm.L'].length;l2=ad.bones['forearm.L'].length
  along=(l1*l1-l2*l2+dist*dist)/(2*dist);height=sqrt(max(0,l1*l1-along*along));bend=Vector((.5,.7,0));bend=(bend-axis*bend.dot(axis)).normalized();elbow=shoulder+axis*along+bend*height
  aim('upper_arm.L',elbow);aim('forearm.L',wrist);palm_pose(rig.pose.bones['hand.L'].head.copy())
  for i in range(5):rig.pose.bones['finger%d.L'%i].rotation_quaternion=Euler(([.42,.65,.60,.45,.14][i],.04*(i-2),.02*(i-2))).to_quaternion()
  bpy.context.view_layer.update();center=wrist+Vector((.15,-.065,.30+.012*sin(ph*2)))
  m=Matrix.Identity(4);m.translation=center;rig.pose.bones['gravity.focus'].matrix=m
  rig.pose.bones['gravity.outer'].rotation_quaternion=Euler((.06*sin(ph),ph,.13*sin(ph))).to_quaternion()
  rig.pose.bones['gravity.inner'].rotation_quaternion=Euler((.12*sin(ph),-ph,.08*cos(ph))).to_quaternion()
  rig.pose.bones['gravity.debris'].rotation_quaternion=Euler((.04*sin(ph),ph,.10*sin(ph))).to_quaternion()
  bpy.context.view_layer.update()
  for bn in old_names:
   if bn not in changed:parity=max(parity,max(abs(a-b) for ra,rb in zip(rig.pose.bones[bn].matrix_basis,baseline[clip][frame][bn]) for a,b in zip(ra,rb)))
  clearance=min(clearance,(center-rig.pose.bones['hand.L'].tail).length-.225);key(frame+1)
 rig.animation_data.action=None;tr=rig.animation_data.nla_tracks.new();tr.name=clip;strip=tr.strips.new(clip,1,action);strip.action_frame_start=1;strip.action_frame_end=frames+1;tr.mute=True
for name,frames in CLIPS:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 scene.frame_set(1);first={p.name:p.matrix_basis.copy() for p in rig.pose.bones};scene.frame_set(frames+1)
 err=max(abs(a-b) for p in rig.pose.bones for ra,rb in zip(p.matrix_basis,first[p.name]) for a,b in zip(ra,rb));loop_errors[name]=err;assert err<1e-5,(name,err)
assert parity<1e-5,parity
assert all(abs(sum(g.weight for g in v.groups)-1)<1e-5 for v in weapon.data.vertices)
for tr in rig.animation_data.nla_tracks:tr.mute=False
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);weapon.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
scene.frame_start=1;scene.frame_end=37;scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/fulcrum.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_apply=False)
for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!='Walk'
scene.frame_set(1);scene.camera.location=(2.6,-6.2,2.6);scene.camera.rotation_euler=(Vector((.15,0,1.13))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=2.75
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_location=(.16,0,1.13);area.spaces.active.region_3d.view_distance=3.5;area.spaces.active.region_3d.view_rotation=scene.camera.rotation_euler.to_quaternion()
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/fulcrum.blend'))
for name,f,out in [('Idle',1,'front.png'),('Walk',10,'weapon-walk.png'),('Run',7,'weapon-run.png'),('Cast',14,'weapon-cast.png')]:
 for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!=name
 scene.frame_set(f);scene.render.filepath=str(HERE/out);bpy.ops.render.render(write_still=True)
report={'status':'INTEGRATED - owner approved weapon','weapon_vertices':len(weapon.data.vertices),'body_vertices':len(body.data.vertices),'vertices':len(body.data.vertices)+len(weapon.data.vertices),'triangles':sum(len(p.vertices)-2 for ob in [body,weapon] for p in ob.data.polygons),'bones':len(ad.bones),'material_surfaces':len(body.data.materials)+len(weapon.data.materials),'unique_materials':len(set(m.name for ob in [body,weapon] for m in ob.data.materials)),'approved_channel_max_error':parity,'loop_max_errors':loop_errors,'palm_to_outer_radius_margin_m':clearance,'clips_seconds':dict((name,frames/30) for name,frames in CLIPS),'source':'art_source/fulcrum.blend','asset':'assets/characters/fulcrum.glb'}
(HERE/'build_report.json').write_text(json.dumps(report,indent=2));print('FULCRUM_WEAPON_INTEGRATED',json.dumps(report))
for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!='Idle'
scene.frame_set(1);scene.camera.location=(-3,5,2.4);scene.camera.rotation_euler=(Vector((.1,0,1.12))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(HERE/'back.png');bpy.ops.render.render(write_still=True)
