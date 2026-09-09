"""Luminary: original smooth skinned celestial healer; shared Ember locomotion timing. Run with Blender 5.2 --background --python."""
import bpy, math, os, json, random
import numpy as np
from mathutils import Vector, Matrix
from math import sin, cos, pi, sqrt
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','characters'); SOURCE=os.path.join(ROOT,'art_source')
REVIEW=os.path.join(ROOT,'artifacts','luminary')
for p in (OUT,SOURCE,REVIEW): os.makedirs(p,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
random.seed(41)

def mat(name,col,metal=0,rough=.5,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1)
 p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emit: p.inputs['Emission Color'].default_value=(*col,1); p.inputs['Emission Strength'].default_value=emit
 return m
cloth=mat('Luminary_NebulaSilk',(.06,.045,.09),0,.82)
leather=mat('Luminary_BlackLeather',(.019,.023,.033),.12,.55)
armor=mat('Luminary_IvoryEnamel',(.68,.64,.54),.42,.36)
gold=mat('Luminary_AntiqueBronze',(.40,.26,.105),.74,.42)
edge=mat('Luminary_EngravedGold',(.65,.44,.19),.72,.35)
void=mat('Luminary_FaceVoid',(.002,.003,.009),0,.98)
fire=mat('Luminary_LivingCinder',(.55,.65,1),.2,.35,.65)
star=mat('Luminary_Starlight',(.65,.71,1),.15,.27,.45)
team=mat('Luminary_TeamInlay',(.17,.55,.7),.35,.4)
navy=mat('Luminary_MidnightVelvet',(.018,.026,.065),0,.82)
celestial=mat('Luminary_CelestialGlass',(.12,.19,.43),.45,.17,.5)
# Authored UV texture, packed into the editable source and GLB.
N=1024
v,u=np.mgrid[0:1:complex(N),0:1:complex(N)]
noise=np.zeros((N,N)); rng=np.random.default_rng(41)
for k in range(15):
 a,b=rng.uniform(2,80,2); phase=rng.uniform(0,6.28)
 noise+=np.sin(u*a+np.sin(v*b*.6)*1.5+phase)*np.cos(v*b+u*a*.3)/(k+3)
cloud=np.clip((noise+.4)*.5,0,1)
neb=np.exp(-((u-.5-.18*np.sin(v*14))/.22)**2)*cloud
hem=np.exp(-v*23)*(0.4+0.6*cloud)
tex=np.zeros((N,N,4),dtype=np.float32);tex[:,:,3]=1
tex[:,:,0]=.70+cloud*.027+neb*.016
tex[:,:,1]=.66+cloud*.027+neb*.016
tex[:,:,2]=.57+cloud*.034+neb*.023
weave=(np.sin(u*3200)*np.sin(v*3200))*.003
tex[:,:,:3]+=weave[:,:,None]
for k in range(0):
 x,y=rng.integers(2,N-2,2); val=rng.uniform(.12,.8)
 tex[y,x,:3]=[val*.78,val*.86,val]
 if k<80: tex[y-1:y+2,x,:3]+=.13;tex[y,x-1:x+2,:3]+=.13
im=bpy.data.images.new('Luminary woven astral silk',width=N,height=N)
im.pixels.foreach_set(np.clip(tex,0,1).ravel());im.filepath_raw=os.path.join(OUT,'luminary_silk.png');im.file_format='PNG';im.save();im.pack()
nt=cloth.node_tree;t=nt.nodes.new('ShaderNodeTexImage');t.image=im
nt.links.new(t.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color'])
# A second packed texture supplies the navy cape and luminous staff sphere.
night=tex.copy();night[:,:,0]=.018+cloud*.025+neb*.15;night[:,:,1]=.023+cloud*.035+neb*.16;night[:,:,2]=.05+cloud*.055+neb*.3
for k in range(650):
 x,y=rng.integers(2,N-2,2);val=rng.uniform(.18,.85);night[y,x,:3]=(val*.8,val*.87,val)
ni=bpy.data.images.new('Luminary star field',width=N,height=N);ni.pixels.foreach_set(np.clip(night,0,1).ravel());ni.filepath_raw=os.path.join(OUT,'luminary_celestial.png');ni.file_format='PNG';ni.save();ni.pack()
for material in (navy,celestial):
 nt=material.node_tree;node=nt.nodes.new('ShaderNodeTexImage');node.image=ni;nt.links.new(node.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color'])
# Skeleton is authored in metres; Blender -Y faces forward.
ad=bpy.data.armatures.new('Luminary_Skeleton');rig=bpy.data.objects.new('Luminary_Rig',ad);bpy.context.collection.objects.link(rig)
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
# Luminary adds staff and cape controls without changing the inherited leg rig.
bone('staff',(-.477,-.035,.888),(-.477,-.035,1.138),'hand.R')
for i in range(3):
 bone('cape%d'%i,((i-1)*.23,.19,1.51),((i-1)*.35,.31,.85),'chest')
 bone('cape_tip%d'%i,((i-1)*.35,.31,.85),((i-1)*.47,.43,.21),'cape%d'%i)
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
parts=[]
def mesh(name,verts,faces,material,weights,uvs=None):
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
# Continuous tailored torso with actual circumference and modeled cloth folds.
def torso_fn(u,v):
 z=1.02+v*.56;w=np.interp(v,[0,.25,.65,.85,1],[.20,.173,.255,.26,.155]);d=np.interp(v,[0,.4,.8,1],[.15,.135,.175,.135]);a=u*2*pi
 return (w*sin(a),d*cos(a)-.02*math.exp(-((v-.67)/.19)**2)*max(0,-cos(a)),z)
surface('Tailored cuirass',torso_fn,48,24,armor,body_weight)
# Fitted sweeping enamel borders follow the cuirass surface.
for sign in [-1,1]:
 for offset in [0,.10]:
  points=[]
  for t in np.linspace(0,1,40):
   u=.5+sign*(.022+.135*t+offset*.15);v=.10+.82*t
   p=Vector(torso_fn(u,v));p.y-=.005;points.append(p)
  tube('Cuirass celestial border',points,.0055,gold,'chest')
# Supple limbs with continuous rings and two-bone weights at elbows/knees.
for side,s in [('L',1),('R',-1)]:
 def leg_fn(u,v):
  z=.14+v*.9;a=u*2*pi;rx=np.interp(v,[0,.25,.48,.7,1],[.068,.084,.08,.115,.12]);return(s*.145+rx*sin(a),.0+rx*.88*cos(a),z)
 def lw(u,v,p):
  t=max(0,min(1,(p[2]-.50)/.14));return {'shin.'+side:1-t,'thigh.'+side:t}
 surface('Anatomical leg '+side,leg_fn,24,24,leather,lw)
 def boot_fn(u,v):
  a=u*2*pi;rx=float(np.interp(v,[0,.15,.5,1],[.08,.092,.087,.064]));ry=float(np.interp(v,[0,.15,.5,1],[.173,.194,.18,.081]));cy=-.065*(1-v)
  return(s*.145+rx*sin(a),cy+ry*cos(a),.025+.18*v)
 surface('Sculpted boot '+side,boot_fn,32,12,leather,{'foot.'+side:1})
 tube('Boot welt '+side,[boot_fn(u,.08) for u in np.linspace(0,1,60)],.005,gold,'foot.'+side)
 ellipse('Boot vamp plate '+side,(s*.145,-.105,.16),(.086,.158,.052),armor,'foot.'+side)
 ellipse('Knee guard '+side,(s*.145,-.075,.57),(.088,.045,.105),armor,'shin.'+side)
 for z in [.26,.39,.52]:
  tube('Greave relief '+side,[(s*.145+.073*sin(a),-.012-.073*cos(a),z+.025*cos(a)) for a in np.linspace(-1.7,1.7,24)],.005,gold,'shin.'+side)
 def arm_fn(u,v):
  z=.95+v*.58;x=s*np.interp(v,[0,.46,1],[.47,.43,.31]);r=np.interp(v,[0,.45,.75,1],[.055,.078,.089,.108]);a=u*2*pi
  return(x+r*sin(a),-.018+r*cos(a),z)
 def aw(u,v,p):
  t=max(0,min(1,(p[2]-1.17)/.10));return {'forearm.'+side:1-t,'upper_arm.'+side:t}
 surface('Fitted ivory sleeve '+side,arm_fn,28,24,cloth,aw)
 # Sculpted bracer shell with multiple longitudinal ornamental ribs.
 for k in range(3):
  x=s*(.45+(k-1)*.031)
  tube('Bracer inlaid rib '+side,[(x,-.093-.013*sin(pi*t),.985+.205*t) for t in np.linspace(0,1,16)],.006,edge,'forearm.'+side)
 ellipse('Bracer plate '+side,(s*.46,-.075,1.085),(.069,.03,.115),armor,'forearm.'+side)
 for z in [1.0,1.18]:ring('Bracer clasp '+side,(s*.46,-.09,z),.052,.017,gold,'forearm.'+side,.006)
 ellipse('Gloved palm '+side,(s*.477,-.035,.888),(.056,.036,.077),leather,'hand.'+side)
 for i in range(4):
  x=s*(.44+i*.023);length=[.088,.108,.10,.077][i]
  pts=[(x,-.035-.046*t*t,.854-length*t) for t in np.linspace(0,1,9)]
  tube('Articulated finger '+side+str(i),pts,lambda t:.012*(1-.36*t),leather,'finger%d.%s'%(i,side),10)
  ellipse('Knuckle '+side+str(i),(x,-.068,.851),(.012,.012,.016),gold,'hand.'+side,12,8)
 tube('Thumb '+side,[(s*(.431-.032*t),-.035-.052*t,.915-.07*t) for t in np.linspace(0,1,10)],lambda t:.016-.006*t,leather,'finger4.'+side,10)
 # Three layered curved shoulder shells; no boxes or flat shaded primitive limbs.
 for j in range(3):
  cx=s*(.31+j*.035);cz=1.53-j*.069
  def pa(u,v,cx=cx,cz=cz,j=j):
   a=2*pi*u;th=v*1.5
   return(cx+(.17-j*.012)*sin(th)*sin(a),(.17-j*.016)*sin(th)*cos(a),cz+.12*cos(th)+.10*sin(th)**5*max(0,s*sin(a))**4)
  surface('Layered pauldron '+side+str(j),pa,32,10,armor,{'upper_arm.'+side:1})
  tube('Pauldron rolled rim '+side,[pa(u,1) for u in np.linspace(0,1,65)],.008,gold,'upper_arm.'+side)
 ring('Shoulder astrolabe '+side,(s*.335,-.153,1.56),.065,.065,edge,'upper_arm.'+side)
 ellipse('Shoulder luminary lens '+side,(s*.335,-.158,1.56),(.042,.021,.042),fire,'upper_arm.'+side)
# Ten overlapping ivory/navy gores with pointed ceremonial hems.
for i in range(10):
 a0=2*pi*i/10;span=.69 if i not in (4,5,6) else .55
 def robe_fn(u,v,a0=a0,span=span,i=i):
  a=a0+(u-.5)*span;t=1-v
  rad=.226+.19*t+.02*sin(u*pi*5)*t
  z=1.055-.89*t+.065*abs(2*u-1)*t**6
  return(rad*sin(a),rad*.77*cos(a)+.07*t*t*max(0,cos(a)),z-.025*t*max(0,cos(a)))
 def rw(u,v,p,i=i):
  t=max(0,min(1,(v-.35)/.4));top=max(0,(v-.85)/.15)
  return {'hem%d'%i:(1-t),'robe%d'%i:t*(1-top),'pelvis':t*top}
 surface('Layered vestment %02d'%i,robe_fn,16,24,navy if i in (0,3,7) else cloth,rw)
 # Piping follows the same bone weights as the cloth, preventing separation.
 for uu in [.035,.965]:
  ob=tube('Robe gold seam', [robe_fn(uu,v) for v in np.linspace(0,1,38)],.0048,gold,'pelvis')
  ob.vertex_groups.clear()
  for vi,vert in enumerate(ob.data.vertices):
   v=(vi//8)/37
   for bn,w in rw(uu,v,vert.co).items():
    if w>0:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([vi],w,'REPLACE')
 ob=tube('Gold embroidered hem',[robe_fn(u,.007) for u in np.linspace(0,1,32)],.0035,gold,'hem%d'%i)
# Belt and hanging celestial jewelry.
surface('Waist belt',lambda u,v:(.232*sin(u*2*pi),.168*cos(u*2*pi),1.02+v*.068),48,4,leather,{'pelvis':1})
for z in [1.026,1.08]:tube('Belt edging',[(.237*sin(a),.174*cos(a),z) for a in np.linspace(0,2*pi,70)],.006,gold,'pelvis')
ring('Solar belt setting',(0,-.181,1.06),.068,.085,gold,'pelvis',.012)
ellipse('Belt black opal',(0,-.19,1.06),(.046,.027,.062),void,'pelvis')
ring('Belt burning iris',(0,-.218,1.06),.028,.04,fire,'pelvis',.003)
for j in range(4):
 z=1.40-j*.16;bn='chest' if j<2 else 'pelvis'
 ring('Pendant setting',(0,-.193,z),.028,.04,edge,bn,.004)
 ellipse('Pendant core',(0,-.20,z),(.012,.008,.019),fire,bn,16,10)
 if j<3:tube('Pendant chain',[(.013*sin(t*pi*3),-.194,z-t*.16) for t in np.linspace(0,1,20)],.003,gold,bn,6)
# Luminary-specific hood, staff, cape and ceremonial embroidery.
exec(compile(open(os.path.join(ROOT,'tools','luminary_details.py'),encoding='utf-8-sig').read(),'luminary_details.py','exec'),globals())
# Readable but restrained team-colored shoulder inlays.
for s in [-1,1]:
 ring('Team sigil',(s*.34,-.177,1.56),.052,.052,team,'upper_arm.'+('L' if s>0 else 'R'),.0035)
# Fine chased scrollwork across curved shoulder plates and bracers.
for side,sg in [('L',1),('R',-1)]:
 for j in range(5):
  cx=sg*(.245+j*.036)
  pts=[]
  for t in np.linspace(0,1,28):
   a=t*pi*2.4;r=.005+.017*t
   pts.append((cx+r*cos(a),-.152,1.56+r*sin(a)))
  tube('Pauldron chased volute',pts,.0018,edge,'upper_arm.'+side,6)
 for j in range(3):
  pts=[]
  for t in np.linspace(0,1,32):
   a=t*2*pi;r=.005+.015*t
   pts.append((sg*.46+r*cos(a),-.108,1.035+j*.055+r*sin(a)))
  tube('Bracer chased volute',pts,.0015,gold,'forearm.'+side,6)
# Merge to one skinned mesh with material surfaces, preserving all vertex weights.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='Luminary_SkinnedModel'
# Recalculate outward normals and attach deformation after the mesh is complete.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
mod=body.modifiers.new('Luminary skeletal deformation','ARMATURE');mod.object=rig;body.parent=rig
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
   rot('cape%d'%i,-.035+(.055 if moving else .018)*sin(ph-.7+i*.5),.012*sin(ph+i),.018*sin(ph+i))
   rot('cape_tip%d'%i,-.045+(.09 if moving else .025)*sin(ph-1.3+i*.5),.018*sin(ph+i),0)
  bpy.context.view_layer.update()
  # Two-bone solve keeps the staff grip clear of the shoulder while preserving the gait.
  wrist=Vector((-.56,-.19,1.08+(.015*sin(ph) if moving else .005*sin(ph))))
  if running:wrist.z-=.12
  if clip=='Cast':wrist=Vector((-.58,-.23,1.18+.015*sin(ph)))
  shoulder=rig.pose.bones['upper_arm.R'].head.copy();axis=(wrist-shoulder).normalized();dist=(wrist-shoulder).length
  l1=ad.bones['upper_arm.R'].length;l2=ad.bones['forearm.R'].length;dist=min(dist,l1+l2-.002)
  along=(l1*l1-l2*l2+dist*dist)/(2*dist);h=sqrt(max(0,l1*l1-along*along))
  bend=Vector((-.2,.8,0));bend=(bend-axis*bend.dot(axis)).normalized()
  elbow=shoulder+axis*along+bend*h
  aim('upper_arm.R',elbow);aim('forearm.R',wrist)
  aim('hand.R',rig.pose.bones['hand.R'].head+Vector((.11,-.005,-.035)))
  for fi in range(5):rot('finger%d.R'%fi,-1.15 if fi<4 else -.65,0,0)
  bpy.context.view_layer.update();aim('staff',rig.pose.bones['staff'].head+Vector((-.045,0,1)))
  keypose(frame+1)
 # NLA tracks export as independent named looping clips.
 rig.animation_data.action=None
 tr=rig.animation_data.nla_tracks.new();tr.name=clip;strip=tr.strips.new(clip,1,action);strip.action_frame_start=1;strip.action_frame_end=frames+1
 tr.mute=True;clips[clip]=frames/30
# Export selected geometry and rig only. No lights or review stage in the game asset.
for tr in rig.animation_data.nla_tracks:tr.mute=False
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
scene.frame_start=1;scene.frame_end=37;scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'luminary.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_apply=False)
for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!='Walk'
# Save a useful source workspace with walk active and a neutral studio for inspection.
world=bpy.data.worlds.new('Luminary studio');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.10,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35
studio=bpy.data.collections.new('REVIEW_ONLY');scene.collection.children.link(studio)
def studio_obj(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 studio.objects.link(o)
def light(name,loc,power,color,size):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
 o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.1))-o.location).to_track_quat('-Z','Y').to_euler()
light('Warm key',(3,-4,5),650,(1,.81,.63),4)
light('Cool fill',(-3,-2,2.6),450,(.52,.67,1),3)
light('Moon rim',(1,3,3),650,(.55,.68,1),2)
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Studio ground';floor.data.materials.append(mat('Studio slate',(.017,.023,.036),.1,.68));studio_obj(floor)
bpy.ops.object.camera_add(location=(3.0,-6.8,2.6));cam=bpy.context.object;studio_obj(cam);cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.0;scene.camera=cam
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
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,'luminary.blend'))
scene.render.filepath=os.path.join(REVIEW,'front.png');scene.frame_set(1);bpy.ops.render.render(write_still=True)
cam.location=(-3,5,2.4);cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=os.path.join(REVIEW,'back.png');bpy.ops.render.render(write_still=True)
report={'head_design':'ivory hood with featureless recessed veil; no human face or hair geometry','vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'bones':len(ad.bones),'clips_seconds':clips,'source':'art_source/luminary.blend','asset':'assets/characters/luminary.glb'}
with open(os.path.join(REVIEW,'build_report.json'),'w') as f:json.dump(report,f,indent=2)
print('LUMINARY_BUILD_COMPLETE',json.dumps(report))
