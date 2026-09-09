"""Fulcrum: original smooth skinned astral mage. Run with Blender 5.2 --background --python."""
import bpy, math, os, json, random
import numpy as np
from mathutils import Vector, Matrix
from math import sin, cos, pi, sqrt
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','characters'); SOURCE=os.path.join(ROOT,'art_source')
REVIEW=os.path.join(ROOT,'artifacts','fulcrum')
for p in (OUT,SOURCE,REVIEW): os.makedirs(p,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
random.seed(41)

def mat(name,col,metal=0,rough=.5,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1)
 p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emit: p.inputs['Emission Color'].default_value=(*col,1); p.inputs['Emission Strength'].default_value=emit
 return m
cloth=mat('Fulcrum_RivenVioletCloth',(.06,.032,.10),0,.87)
leather=mat('Fulcrum_BlackLeather',(.012,.013,.019),.06,.72)
armor=mat('Fulcrum_BlackenedGunmetal',(.030,.032,.043),.72,.43)
gold=mat('Fulcrum_MutedBronze',(.18,.13,.09),.75,.54)
edge=mat('Fulcrum_WeatheredPewter',(.11,.105,.118),.76,.49)
void=mat('Fulcrum_AbsoluteVoid',(.0003,.0002,.0007),0,1)
fire=mat('Fulcrum_GravityLight',(.25,.035,.56),.12,.45,1.5)
star=mat('Fulcrum_PaleSingularity',(.69,.35,1),.15,.35,2.3)
team=mat('Fulcrum_TeamInlay',(.17,.55,.7),.35,.4)
maskmat=mat('Fulcrum_SealedObsidianMask',(.015,.017,.026),.66,.31)
darkcloth=mat('Fulcrum_AshenMantle',(.025,.022,.034),0,.93)
lining=mat('Fulcrum_HoodLining',(.004,.003,.008),0,1)
# Original woven cloth texture: faded violet warp, irregular grain and abrasion.
N=1024
v,u=np.mgrid[0:1:complex(N),0:1:complex(N)]
rng=np.random.default_rng(83);noise=np.zeros((N,N))
for k in range(18):
 a,b=rng.uniform(3,180,2);noise+=np.sin(u*a+np.sin(v*b*.7)*.8+rng.uniform(0,6.28))*np.cos(v*b)/(k+5)
cloud=np.clip(.5+noise*.35,0,1)
weave=(np.sin(u*3200)*np.sin(v*3200))*.014
abrade=np.exp(-v*14)*(.3+cloud*.7)+np.exp(-np.minimum(u,1-u)*70)*.18
tex=np.zeros((N,N,4),dtype=np.float32);tex[:,:,3]=1
tex[:,:,0]=.09+cloud*.12+weave+abrade*.045
tex[:,:,1]=.055+cloud*.065+weave*.65+abrade*.027
tex[:,:,2]=.15+cloud*.15+weave+abrade*.037
im=bpy.data.images.new('Fulcrum worn violet weave',width=N,height=N)
im.pixels.foreach_set(np.clip(tex,0,1).ravel());im.filepath_raw=os.path.join(OUT,'fulcrum_weave.png');im.file_format='PNG';im.save();im.pack()
nt=cloth.node_tree;tx=nt.nodes.new('ShaderNodeTexImage');tx.image=im
nt.links.new(tx.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color'])
# Portable image-based microdetail, packed in .blend and embedded in GLB.
def texture_image(name,data,filename,noncolor=False):
 image=bpy.data.images.new(name,width=N,height=N)
 if noncolor:image.colorspace_settings.name='Non-Color'
 image.pixels.foreach_set(np.clip(data,0,1).astype(np.float32).ravel())
 image.filepath_raw=os.path.join(OUT,filename);image.file_format='PNG';image.save();image.pack();return image

def rgb_image(rgb):
 result=np.ones((N,N,4),dtype=np.float32);result[:,:,:3]=rgb;return result

def bind_texture(material,image,input_name):
 nt=material.node_tree;node=nt.nodes.new('ShaderNodeTexImage');node.image=image
 nt.links.new(node.outputs['Color'],nt.nodes.get('Principled BSDF').inputs[input_name])
 return node
# Slight woven normal relief remains visible under changing game lights.
grain=rng.uniform(-1,1,(N,N))
height=.34*np.sin(u*1900)+.25*np.sin(v*1900)+grain*.07
gy,gx=np.gradient(height)
norm=np.dstack((-gx*.32,-gy*.32,np.ones((N,N))))
norm/=np.linalg.norm(norm,axis=2)[:,:,None]
normal_image=texture_image('Fulcrum fabric micro weave',rgb_image(norm*.5+.5),'fulcrum_fabric_normal.png',True)
for m in [cloth,darkcloth,leather]:
 nt=m.node_tree;t=nt.nodes.new('ShaderNodeTexImage');t.image=normal_image;nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.42 if m!=leather else .19
 nt.links.new(t.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
# Ashen black cloth has its own faded, non-starfield surface.
rgb=np.zeros((N,N,3),dtype=np.float32)
rgb[:,:,0]=.045+cloud*.045+weave*.45;rgb[:,:,1]=.043+cloud*.041+weave*.45;rgb[:,:,2]=.060+cloud*.055+weave*.45
ash=texture_image('Fulcrum ash woven fabric',rgb_image(rgb),'fulcrum_ash.png')
bind_texture(darkcloth,ash,'Base Color')
# Fine oxide mottling and sparse engraved scuffs are baked to a PBR color/roughness pair.
oxide=.5+.5*np.sin(u*31+np.sin(v*27))*np.cos(v*19+u*11)
scuffs=np.zeros((N,N))
for k in range(280):
 x,y=rng.integers(8,N-35,2);length=int(rng.integers(3,26))
 for d in range(length):
  yy=min(N-1,y+d//4);xx=min(N-1,x+d)
  scuffs[yy,xx]+=rng.uniform(.045,.14)*(sin(pi*d/length)**.5)
rgb=np.zeros((N,N,3),dtype=np.float32)
for c,val in enumerate([.099,.107,.126]):rgb[:,:,c]=val+oxide*.037+grain*.008+scuffs*.65
metal_image=texture_image('Fulcrum rubbed black steel',rgb_image(rgb),'fulcrum_steel.png')
bind_texture(armor,metal_image,'Base Color')
rough=.42+.16*oxide+grain*.015-scuffs*.25
rough_image=texture_image('Fulcrum steel roughness',rgb_image(np.repeat(rough[:,:,None],3,axis=2)),'fulcrum_steel_roughness.png',True)
bind_texture(armor,rough_image,'Roughness')
for m in [lining,void]:m.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0

# Skeleton is authored in metres; Blender -Y faces forward.
ad=bpy.data.armatures.new('Fulcrum_Skeleton');rig=bpy.data.objects.new('Fulcrum_Rig',ad);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
 e=ad.edit_bones.new(name);e.head=a;e.tail=b
 if parent:e.parent=ad.edit_bones[parent]
 return e
bone('root',(0,0,0),(0,0,.2));bone('pelvis',(0,0,1.02),(0,0,1.18),'root')
bone('spine',(0,0,1.18),(0,0,1.42),'pelvis');bone('chest',(0,0,1.42),(0,0,1.59),'spine')
bone('neck',(0,0,1.59),(0,0,1.7),'chest');bone('head',(0,0,1.7),(0,0,2.0),'neck')
for side,s in [('L',1),('R',-1)]:
 bone('thigh.'+side,(s*.145,0,1.04),(s*.145,-.015,.57),'pelvis')
 bone('shin.'+side,(s*.145,-.015,.57),(s*.145,0,.14),'thigh.'+side)
 bone('foot.'+side,(s*.145,0,.14),(s*.145,-.17,.065),'shin.'+side)
 bone('toe.'+side,(s*.145,-.17,.065),(s*.145,-.27,.065),'foot.'+side)
 bone('clavicle.'+side,(s*.045,0,1.53),(s*.31,0,1.53),'chest')
 bone('upper_arm.'+side,(s*.31,0,1.53),(s*.43,-.01,1.22),'clavicle.'+side)
 bone('forearm.'+side,(s*.43,-.01,1.22),(s*.47,-.025,.96),'upper_arm.'+side)
 bone('hand.'+side,(s*.47,-.025,.96),(s*.48,-.035,.845),'forearm.'+side)
 for i in range(5):
  x=s*(.44+i*.023)
  if i==4:bone('finger4.'+side,(s*.431,-.035,.915),(s*.399,-.087,.845),'hand.'+side)
  else:bone('finger%d.%s'%(i,side),(x,-.035,.854),(x,-.081,.854-[.088,.108,.10,.077][i]),'hand.'+side)
for i in range(10):
 a=2*pi*i/10
 bone('robe%d'%i,(.22*sin(a),.16*cos(a),1.04),(.31*sin(a),.24*cos(a),.57),'pelvis')
 bone('hem%d'%i,(.31*sin(a),.24*cos(a),.57),(.43*sin(a),.32*cos(a),.16),'robe%d'%i)
for i in range(3):
 x=(i-1)*.16
 bone('mantle%d'%i,(x,.18,1.50),(x*1.6,.28,.87),'chest')
 bone('mantle_tip%d'%i,(x*1.6,.28,.87),(x*2.1,.43,.18),'mantle%d'%i)
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
parts=[]
def mesh(name,verts,faces,material,weights,uvs=None):
 if uvs is None:
  coords=np.array(verts);span=np.ptp(coords,axis=0);axis=int(np.argmax(span));other=2 if axis!=2 else 0
  if span[other]<.001:other=1
  uvs=[((float(p[axis])-float(coords[:,axis].min()))/max(.001,float(span[axis])),(float(p[other])-float(coords[:,other].min()))/max(.001,float(span[other]))) for p in verts]
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(material)
 for p in me.polygons:p.use_smooth=True
 if uvs:
  lay=me.uv_layers.new(name='UVMap')
  for p in me.polygons:
   for li in p.loop_indices:lay.data[li].uv=uvs[me.loops[li].vertex_index]
 for idx,ws in enumerate(weights if isinstance(weights,list) else [weights]*len(verts)):
  for bn,w in ws.items():
   if w>0:
    g=ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn);g.add([idx],w,'REPLACE')
 parts.append(ob);return ob

def surface(name,fn,nu,nv,material,weight):
 vs=[];ws=[];uv=[];fs=[]
 for j in range(nv+1):
  for i in range(nu+1):
   u=i/nu;v=j/nv;p=fn(u,v);vs.append(p);uv.append((u,v));ws.append(weight(u,v,p) if callable(weight) else weight)
 for j in range(nv):
  for i in range(nu):
   k=j*(nu+1)+i;fs.append((k,k+1,k+nu+2,k+nu+1))
 return mesh(name,vs,fs,material,ws,uv)

def tube(name,points,radius,material,bn,sides=8):
 vs=[];fs=[]
 for i,p in enumerate(points):
  p=Vector(p);d=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
  d.normalize();q=d.cross(Vector((0,1,0)))
  if q.length<.01:q=d.cross(Vector((1,0,0)))
  q.normalize();r=d.cross(q)
  rad=radius(i/(len(points)-1)) if callable(radius) else radius
  for k in range(sides):vs.append(p+rad*(q*cos(2*pi*k/sides)+r*sin(2*pi*k/sides)))
 for i in range(len(points)-1):
  for k in range(sides):
   a=i*sides+k;b=i*sides+(k+1)%sides;fs.append((a,b,b+sides,a+sides))
 return mesh(name,vs,fs,material,{bn:1})

def ellipse(name,c,scale,material,bn,nu=24,nv=14):
 return surface(name,lambda u,v:(c[0]+scale[0]*sin(pi*v)*cos(2*pi*u),c[1]+scale[1]*sin(pi*v)*sin(2*pi*u),c[2]+scale[2]*cos(pi*v)),nu,nv,material,{bn:1})

def ring(name,c,rx,rz,material,bn,r=.007):
 return tube(name,[(c[0]+rx*sin(i*2*pi/64),c[1],c[2]+rz*cos(i*2*pi/64)) for i in range(65)],r,material,bn)

def body_weight(u,v,p):
 z=p[2]
 if z<1.17:return {'pelvis':1}
 if z<1.38:
  t=(z-1.17)/.21;return {'spine':1-t,'chest':t}
 return {'chest':1}
# Class-specific costume, mask and torn mantle; no facial/hair geometry.
exec(compile(open(os.path.join(ROOT,'tools','fulcrum_details.py'),encoding='utf-8').read(),'fulcrum_details.py','exec'))

# Merge to one skinned mesh with material surfaces, preserving all vertex weights.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='Fulcrum_SkinnedModel'
# Recalculate outward normals and attach deformation after the mesh is complete.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
mod=body.modifiers.new('Fulcrum skeletal deformation','ARMATURE');mod.object=rig;body.parent=rig
# Analytic two-bone leg solve; foot targets stay on the ground during stance.
scene=bpy.context.scene;scene.render.fps=30
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
def aim(name,target):
 p=rig.pose.bones[name];rest=ad.bones[name]
 head=p.head.copy();direction=Vector(target)-head
 current=p.matrix.to_quaternion();delta=(current@Vector((0,1,0))).rotation_difference(direction.normalized())
 m=(delta@current).to_matrix().to_4x4();m.translation=head;p.matrix=m
 bpy.context.view_layer.update()
def keypose(frame):
 for p in rig.pose.bones:
  p.keyframe_insert('location',frame=frame,group=p.name);p.keyframe_insert('rotation_quaternion',frame=frame,group=p.name)
def reset():
 for p in rig.pose.bones:p.location=(0,0,0);p.rotation_quaternion=(1,0,0,0);p.scale=(1,1,1)
def rot(name,x=0,y=0,z=0):
 from mathutils import Euler
 rig.pose.bones[name].rotation_quaternion=Euler((x,y,z)).to_quaternion()
clips={}
for clip,frames in [('Idle',60),('Walk',36),('Run',22),('WalkBackward',40),('StrafeLeft',34),('StrafeRight',34),('Cast',48)]:
 rig.animation_data_create();rig.animation_data.action=None
 action=bpy.data.actions.new(clip);rig.animation_data.action=action;action.use_fake_user=True
 for frame in range(frames+1):
  reset();ph=frame/frames*2*pi;moving=clip not in ['Idle','Cast'];running=clip=='Run';back=clip=='WalkBackward';strafe=clip.startswith('Strafe');amp=.54 if running else .215;stance=.38 if running else .6
  bob=(.016 if running else .009)*(1-cos(ph*2)) if moving else .004*sin(ph)
  rig.pose.bones['pelvis'].location=(.012*sin(ph) if moving else 0,bob-(.20 if running else (.04 if moving else 0)),0)
  rot('spine',.13 if running else .008, .045*sin(ph) if moving else .009*sin(ph))
  rot('chest',0,-.06*sin(ph) if moving else 0,.018*sin(ph))
  rot('head',-.018, .018*sin(ph),-.012*sin(ph))
  bpy.context.view_layer.update()
  for side,s in [('L',1),('R',-1)]:
   q=(frame/frames+(0 if s==1 else .5))%1
   # Stance moves front-to-back linearly; swing uses eased return plus toe clearance.
   if q<stance:forward=amp*(1-2*q/stance);lift=0
   else:
    t=(q-stance)/(1-stance);forward=-amp+2*amp*(t*t*(3-2*t));lift=(.17 if running else .072)*sin(pi*t)
   if back:forward=-forward
   foot=Vector((s*.145,-forward,.14+lift))
   if strafe:foot.x+=(forward*(1 if clip=='StrafeLeft' else -1));foot.y=0
   hip=rig.pose.bones['thigh.'+side].head.copy();d=foot-hip;dist=min(d.length,.893);axis=d.normalized();L1=ad.bones['thigh.'+side].length;L2=ad.bones['shin.'+side].length
   along=(L1*L1-L2*L2+dist*dist)/(2*dist);height=sqrt(max(0,L1*L1-along*along))
   bend=Vector((0,-1,0));bend=(bend-axis*bend.dot(axis)).normalized();knee=hip+axis*along+bend*height
   if moving:
    aim('thigh.'+side,knee);aim('shin.'+side,foot)
    aim('foot.'+side,rig.pose.bones['foot.'+side].head+Vector((0,-.17,-.075+lift*.45)))
   swing=sin(ph+(0 if s==1 else pi))
   rot('upper_arm.'+side,(-(.62 if running else .36)*swing if moving else -.07),0,s*.035)
   rot('forearm.'+side,(-.72 if running else -.13)-(max(0,swing)*.23 if moving else .025*sin(ph)),0,0)
   rot('hand.'+side,.06,s*.85,0)
   for i in range(5):rot('finger%d.%s'%(i,side),(-.65 if running else -.22)+.04*sin(ph+.3*i),0,0)
   if clip=='Cast':
    rot('upper_arm.'+side,-1.05-.06*sin(ph),s*.12,s*.25);rot('forearm.'+side,-.55,0,0);rot('hand.'+side,-.25,0,0)
  for i in range(10):
   a=2*pi*i/10
   if moving:rig.pose.bones['robe%d'%i].location=ad.bones['robe%d'%i].matrix_local.to_3x3().inverted()@Vector((0,0,.17 if running else .027))
   rot('robe%d'%i,(.10 if moving else .025)*sin(ph-.5+sin(a))+.025,(.035 if moving else .01)*cos(ph+a),.018*sin(ph+a))
   rot('hem%d'%i,(.14 if moving else .04)*sin(ph-1+sin(a))+.035,.022*cos(ph+a),0)
  for i in range(3):
   rot('mantle%d'%i,-.035+(.055 if moving else .017)*sin(ph-.7+i*.5),.012*sin(ph+i),.018*sin(ph+i))
   rot('mantle_tip%d'%i,-.04+(.10 if moving else .03)*sin(ph-1.3+i*.5),.018*sin(ph+i),.018*sin(ph-1+i))
  keypose(frame+1)
 # NLA tracks export as independent named looping clips.
 rig.animation_data.action=None
 tr=rig.animation_data.nla_tracks.new();tr.name=clip;strip=tr.strips.new(clip,1,action);strip.action_frame_start=1;strip.action_frame_end=frames+1
 tr.mute=True;clips[clip]=frames/30
# Export selected geometry and rig only. No lights or review stage in the game asset.
for tr in rig.animation_data.nla_tracks:tr.mute=False
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
scene.frame_start=1;scene.frame_end=37;scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=os.path.join(REVIEW,'base_fulcrum.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_apply=False)
for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!='Walk'
# Save a useful source workspace with walk active and a neutral studio for inspection.
world=bpy.data.worlds.new('Fulcrum studio');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.10,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35
studio=bpy.data.collections.new('REVIEW_ONLY');scene.collection.children.link(studio)
def studio_obj(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 studio.objects.link(o)
def light(name,loc,power,color,size):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
 o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.1))-o.location).to_track_quat('-Z','Y').to_euler()
light('Neutral key',(3,-4,5),780,(.88,.9,1),4)
light('Soft fill',(-3,-2,2.6),450,(.79,.83,1),3)
light('Violet rim',(1,3,3),390,(.52,.34,.79),2)
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Studio ground';floor.data.materials.append(mat('Studio slate',(.017,.023,.036),.1,.68));studio_obj(floor)
bpy.ops.object.camera_add(location=(3.0,-5.8,2.5));cam=bpy.context.object;studio_obj(cam);cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.7;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=850;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
# Keep Blender's viewport centered on the rig, in material mode.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_distance=3.4;area.spaces.active.region_3d.view_location=(0,0,1.12)
   area.spaces.active.shading.type='MATERIAL'
   area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
   area.spaces.active.overlay.show_overlays=False
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(REVIEW,'base_fulcrum.blend'))
scene.render.filepath=os.path.join(REVIEW,'front.png');scene.frame_set(1);bpy.ops.render.render(write_still=True)
cam.location=(-3,5,2.4);cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=os.path.join(REVIEW,'back.png');bpy.ops.render.render(write_still=True)
report={'design':'sealed angular mask, hood, black articulated armor and torn violet mantle','material_surfaces':len(body.data.materials),'vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'bones':len(ad.bones),'clips_seconds':clips,'source':'art_source/fulcrum.blend','asset':'assets/characters/fulcrum.glb'}
with open(os.path.join(REVIEW,'build_report.json'),'w') as f:json.dump(report,f,indent=2)
print('FULCRUM_BASE_BUILT',json.dumps(report))
# The weapon stage preserves the base mesh/materials and adapts only the carrying arm.
import runpy
runpy.run_path(os.path.join(ROOT,'tools','fulcrum_weapon.py'),run_name='__main__')
