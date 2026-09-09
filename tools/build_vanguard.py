"""Vanguard: complete original armored warrior, Blender source + skinned GLB.
Run: blender -b --python tools/build_vanguard.py. Does not modify Ember or the approved hammer.
"""
import bpy, math, os, json, random
import numpy as np
from mathutils import Vector, Matrix, Euler
from math import sin, cos, pi, sqrt
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','characters'); SOURCE=os.path.join(ROOT,'art_source'); REVIEW=os.path.join(ROOT,'artifacts','vanguard_rebuild_20260908')
for p in (OUT,SOURCE,REVIEW): os.makedirs(p,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
random.seed(91)
def mat(name,col,metal=0,rough=.5,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1)
 p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emit: p.inputs['Emission Color'].default_value=(*col,1); p.inputs['Emission Strength'].default_value=emit
 return m
steel=mat('Vanguard_VoidSteelPBR',(.038,.044,.057),.76,.44)
edge=mat('Vanguard_CelestialAlloyPBR',(.25,.205,.145),.8,.46)
leather=mat('Vanguard_JointLeather',(.015,.018,.024),.08,.74)
crystal=mat('Vanguard_AmethystPBR',(.16,.012,.42),.30,.27,1.6)
team=mat('Vanguard_TeamInlay',(.13,.35,.6),.3,.55)
visor=mat('Vanguard_Visor',(.35,.025,.84),.05,.35,2.6)
cloth=mat('Vanguard_AstralCloth',(.02,.025,.052),0,.88)
void=mat('Vanguard_SealedVisorShadow',(.001,.001,.003),0,1)
exec(compile(open(os.path.join(ROOT,'tools','vanguard_materials.py'),encoding='utf-8').read(),'vanguard_materials.py','exec'))
parts=[]
ad=bpy.data.armatures.new('Vanguard_Skeleton');rig=bpy.data.objects.new('Vanguard_Rig',ad);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
 e=ad.edit_bones.new(name);e.head=a;e.tail=b
 if parent:e.parent=ad.edit_bones[parent]
 return e
bone('root',(0,0,0),(0,0,.2));bone('pelvis',(0,0,1.05),(0,0,1.19),'root')
bone('spine',(0,0,1.19),(0,0,1.47),'pelvis');bone('chest',(0,0,1.47),(0,0,1.76),'spine')
bone('neck',(0,0,1.76),(0,0,1.93),'chest');bone('head',(0,0,1.93),(0,0,2.20),'neck')
# Weapon rest axis lies across the front, both palms centered on the shaft.
WH=Vector((.74,-.40,2.10)); WD=Vector((.64,0,.76837491)).normalized()
GRIPS={'L':WH-WD*.68,'R':WH-WD*1.01}
for side,s in [('L',1),('R',-1)]:
 bone('thigh.'+side,(s*.185,0,1.06),(s*.185,-.018,.57),'pelvis')
 bone('shin.'+side,(s*.185,-.018,.57),(s*.185,0,.14),'thigh.'+side)
 bone('foot.'+side,(s*.185,0,.14),(s*.185,-.19,.065),'shin.'+side)
 bone('toe.'+side,(s*.185,-.19,.065),(s*.185,-.29,.065),'foot.'+side)
 shoulder=Vector((s*.39,0,1.74));grip=GRIPS[side];wrist=grip+Vector((s*.015,.065,.015))
 delta=wrist-shoulder;axis=delta.normalized();dist=delta.length
 along=(.39**2-.38**2+dist**2)/(2*dist);height=sqrt(max(0,.39**2-along**2))
 pole=Vector((s,.10,-.35));pole=(pole-axis*pole.dot(axis)).normalized();elbow=shoulder+axis*along+pole*height
 bone('clavicle.'+side,(s*.045,0,1.72),shoulder,'chest')
 bone('upper_arm.'+side,shoulder,elbow,'clavicle.'+side)
 bone('forearm.'+side,elbow,wrist,'upper_arm.'+side)
 bone('hand.'+side,wrist,grip,'forearm.'+side)
 for i in range(5):bone('finger%d.%s'%(i,side),grip+WD*((i-2)*.022),grip+WD*((i-2)*.022)+Vector((0,-.04,-.018)),'hand.'+side)
bone('weapon',WH,WH+WD*.4,'root')
for i in range(3):
 bone('tabard%d'%i,((i-1)*.095,-.16,1.05),((i-1)*.10,-.19,.72),'pelvis')
 bone('hem%d'%i,((i-1)*.10,-.19,.72),((i-1)*.11,-.21,.48),'tabard%d'%i)
for i in range(3):
 x=(i-1)*.18
 bone('cape%d'%i,(x,.205,1.72),(x*1.5,.32,1.00),'chest')
 bone('cape_tip%d'%i,(x*1.5,.32,1.00),(x*1.9,.41,.16),'cape%d'%i)
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
def mesh(name,verts,faces,material,weights,uvs=None):
 if uvs is None:
  coords=np.array(verts);span=np.ptp(coords,axis=0);axes=np.argsort(span)[-2:]
  uvs=[tuple((float(p[a])-float(coords[:,a].min()))/max(.0001,float(span[a])) for a in axes) for p in verts]
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

# Plate patches have thickness, beveled perimeters and physically overlapping layers.
def plate(name,outline,depth,material,bn,bevel=.008):
 vs=[tuple(p) for p in outline]+[(p[0],p[1]+depth,p[2]) for p in outline];n=len(outline)
 fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 ob=mesh(name,vs,fs,material,{bn:1})
 bpy.context.view_layer.objects.active=ob
 mod=ob.modifiers.new('Forged bevel','BEVEL');mod.width=bevel;mod.segments=3
 bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=ob.modifiers.new('Plate normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return ob

def shard(name,base,tip,r,bn):
 a=Vector(base);d=Vector(tip)-a;axis=d.normalized();x=axis.cross(Vector((0,1,0))).normalized();y=axis.cross(x)
 vs=[]
 for t,rr in [(0,.75),(.22,1),(.70,.70)]:
  for k in range(6):vs.append(a+d*t+r*rr*(x*cos(k*pi/3)+y*sin(k*pi/3)))
 vs.append(Vector(tip));fs=[]
 for j in range(2):
  for k in range(6):fs.append((j*6+k,j*6+(k+1)%6,(j+1)*6+(k+1)%6,(j+1)*6+k))
 for k in range(6):fs.append((12+k,12+(k+1)%6,18))
 fs.append(tuple(range(5,-1,-1)))
 ob=mesh(name,vs,fs,crystal,{bn:1})
 for p in ob.data.polygons:p.use_smooth=False
 return ob

def limb(name,a,b,r1,r2,bn,material=leather):
 a=Vector(a);b=Vector(b);d=b-a;axis=d.normalized();x=axis.cross(Vector((0,1,0))).normalized();y=axis.cross(x)
 return surface(name,lambda u,v:a+d*v+(r1*(1-v)+r2*v)*(1+.065*sin(v*pi*12))*(x*cos(u*2*pi)+y*sin(u*2*pi)),24,16,material,{bn:1})
def bolts(name,points,bn):
 for p in points:ellipse(name,p,(.010,.006,.010),edge,bn,8,6)
def trimline(name,points,bn,r=.005):return tube(name,points,r,edge,bn,8)
# Continuous shaped torso, tapering at the waist; a ribbed flexible abdomen below.
def torso(u,v):
 a=u*2*pi;z=1.07+v*.70;w=np.interp(v,[0,.25,.65,.85,1],[.235,.23,.335,.335,.20]);d=np.interp(v,[0,.3,.7,1],[.155,.155,.205,.16])
 return(w*sin(a),d*cos(a),z)
def tw(u,v,p):
 t=max(0,min(1,(p[2]-1.2)/.25));return {'spine':1-t,'chest':t}
surface('Sealed cuirass foundation',torso,48,24,leather,tw)
for j in range(5):
 z=1.13+j*.052
 plate('Articulated abdominal lame', [(-.23,-.175,z+.055),(-.19,-.205,z), (0,-.22,z-.018),(.19,-.205,z),(.23,-.175,z+.055),(0,-.226,z+.07)],.025,steel,'spine')
 trimline('Lame worn lip',[(-.19,-.211,z),(0,-.228,z-.018),(.19,-.211,z)],'spine',.004)
for side,s in [('L',1),('R',-1)]:
 outline=[(s*.035,-.215,1.70),(s*.21,-.198,1.78),(s*.335,-.15,1.67),(s*.32,-.20,1.46),(s*.13,-.241,1.40),(s*.035,-.245,1.50)]
 plate('Swept breastplate '+side,outline,.05,steel,'chest',.013)
 trimline('Breastplate bevel '+side,[(x,y-.006,z) for x,y,z in outline[:3]],'chest',.009)
 bolts('Cuirass fastener',[(s*.25,-.214,1.68),(s*.265,-.231,1.48),(s*.09,-.247,1.52)],'chest')
 for j in range(3):
  z=1.34+j*.095
  pts=[(s*(.205+.025*sin(pi*t)),-.18+.08*t,z+.055*t) for t in np.linspace(0,1,18)]
  tube('Rib conduit',pts,.016,leather,'chest')
  for p in pts[::3]:ellipse('Conduit clasp',p,(.019,.013,.013),edge,'chest',10,6)
 # Raised gorget stays below the jaw.
 plate('Raised collar '+side,[(s*.08,-.135,1.78),(s*.12,-.08,1.85),(s*.235,-.08,1.81),(s*.26,-.14,1.73)],.045,steel,'chest')
 # Layered pauldrons are broad sculpted shells, not balls.
 for j in range(3):
  cx=s*(.40+j*.062);cz=1.78-j*.048
  def pa(u,v,cx=cx,cz=cz,j=j):
   a=u*2*pi;th=.12+v*1.37
   return(cx+(.235-j*.025)*sin(th)*sin(a),(.225-j*.020)*sin(th)*cos(a),cz+.135*cos(th)+.02*cos(a*3)*v)
  surface('Forged shoulder shell '+side+str(j),pa,36,12,steel,{'upper_arm.'+side:1})
  trimline('Pauldron thick edging',[pa(u,1) for u in np.linspace(0,1,65)],'upper_arm.'+side,.005)
  bolts('Shoulder rivet',[Vector(pa(u,.93))+Vector((0,-.004,0)) for u in [.3,.4,.5,.6,.7]],'upper_arm.'+side)
 for j in range(3):
  x=s*(.33+j*.085);z=1.855-.022*j
  shard('Crown crystal '+side+str(j),(x,.04,z),(x+s*(.025+j*.012),.025, z+[.13,.24,.18][j]),.045 if j!=1 else .060,'upper_arm.'+side)
 ring('Shoulder locking ring',(s*.445,-.222,1.765),.063,.063,edge,'upper_arm.'+side,.005)
 shard('Shoulder inset',(s*.445,-.239,1.71),(s*.445,-.249,1.82),.032,'upper_arm.'+side)
 # Sleeves and fitted armor follow actual bone axes and keep elbow gaps.
 for bn,ra,rb in [('upper_arm',.108,.086),('forearm',.089,.066)]:
  b=ad.bones[bn+'.'+side];limb('Flexible '+bn+side,b.head_local,b.tail_local,ra,rb,bn+'.'+side)
  a=b.head_local.lerp(b.tail_local,.14);c=b.head_local.lerp(b.tail_local,.86)
  limb('Armor barrel '+bn+side,a,c,ra+.019,rb+.022,bn+'.'+side,steel)
  for t in [.16,.82]:
   p=b.head_local.lerp(b.tail_local,t)
   # Axial ring generated in bone plane.
   axis=(b.tail_local-b.head_local).normalized();q=axis.cross(Vector((0,1,0))).normalized();r=axis.cross(q)
   trimline('Barrel cuff',[p+(ra*(1-t)+rb*t+.023)*(q*cos(a)+r*sin(a)) for a in np.linspace(0,2*pi,40)],bn+'.'+side,.007)
 elbow=ad.bones['forearm.'+side].head_local
 ellipse('Elbow bearing '+side,elbow,(.09,.09,.09),leather,'forearm.'+side)
 ring('Elbow concentric inset',(elbow.x,elbow.y-.089,elbow.z),.049,.049,edge,'forearm.'+side,.008)
 b=ad.bones['forearm.'+side];p=b.head_local.lerp(b.tail_local,.45)
 shard('Forearm crystal',p+Vector((0,-.09,-.065)),p+Vector((0,-.115,.095)),.038,'forearm.'+side)
 # Cupped palm and individual closed fingers wrap a 4cm radius haft.
 g=GRIPS[side];ellipse('Gauntlet palm '+side,g+Vector((0,.046,0)),(.067,.035,.064),leather,'hand.'+side)
 for i in range(4):
  center=g+WD*((i-1.5)*.027);q=WD.cross(Vector((0,1,0))).normalized();r=Vector((0,1,0))
  points=[center+.052*(q*cos(a)+r*sin(a)) for a in np.linspace(-.5,4.15,16)]
  tube('Curled finger '+side+str(i),points,.013,leather,'finger%d.%s'%(i,side),10)
  for a in [.2,1.35,2.5]:ellipse('Finger plate',center+.056*(q*cos(a)+r*sin(a)),(.016,.012,.013),steel,'finger%d.%s'%(i,side),10,6)
 tube('Opposing thumb '+side,[g+WD*.071+Vector((0,.047,0)),g+WD*.057+Vector((0,-.018,.032)),g+WD*.023+Vector((0,-.05,.01))],.019,leather,'finger4.'+side,12)
 # Legs remain separate under hanging belt armor.
 for bn,r1,r2 in [('thigh',.14,.108),('shin',.105,.077)]:
  b=ad.bones[bn+'.'+side];limb('Leg suit '+bn+side,b.head_local,b.tail_local,r1,r2,bn+'.'+side)
 x=s*.185
 for j in range(3):
  z=.78+j*.085
  plate('Thigh overlapping plate',[(x-.115,-.08,z+.11),(x+.115,-.08,z+.11),(x+.104,-.12,z),(x,-.15,z-.025),(x-.104,-.12,z)],.038,steel,'thigh.'+side)
  trimline('Thigh lip',[(x-.104,-.127,z),(x,-.155,z-.025),(x+.104,-.127,z)],'thigh.'+side,.006)
 plate('Knee shield',[(x,-.135,.695),(x+.11,-.10,.60),(x+.075,-.135,.505),(x,-.174,.475),(x-.075,-.135,.505),(x-.11,-.10,.60)],.038,steel,'shin.'+side,.011)
 shard('Knee crystal',(x,-.18,.52),(x,-.19,.63),.029,'shin.'+side)
 plate('Fluted greave',[(x-.077,-.075,.21),(x-.11,-.09,.49),(x,-.145,.52),(x+.11,-.09,.49),(x+.077,-.075,.21),(x,-.135,.17)],.04,steel,'shin.'+side)
 for off in [-.060,.060]:trimline('Greave vertical rib',[(x+off,-.108,.24),(x+off*1.12,-.137,.43),(x,-.151,.50)],'shin.'+side,.006)
 def boot(u,v):
  a=u*2*pi;rx=np.interp(v,[0,.2,.65,1],[.115,.12,.108,.077]);ry=np.interp(v,[0,.2,.65,1],[.21,.217,.185,.095]);cy=-.08*(1-v)
  return(x+rx*sin(a),cy+ry*cos(a),.018+.20*v)
 surface('Heavy flat boot '+side,boot,32,12,leather,{'foot.'+side:1})
 for v in [.09,.23]:trimline('Boot sole band',[boot(u,v) for u in np.linspace(0,1,49)],'foot.'+side,.007)
 for j in range(3):
  cy=-.19+j*.066
  def sabaton(u,v):return(x+.111*cos(pi*u),cy-.038+v*.086,.11+j*.015+.071*sin(pi*u)+.012*v)
  surface('Curved articulated sabaton',sabaton,16,4,steel,{'foot.'+side:1})
  trimline('Sabaton rolled leading edge',[sabaton(u,0) for u in np.linspace(0,1,24)],'foot.'+side,.004)
# Sternum crystal in a recessed dark frame and gold retaining points.
plate('Sternum setting',[(0,-.252,1.74),(.071,-.25,1.63),(0,-.259,1.46),(-.071,-.25,1.63)],.05,edge,'chest')
shard('Sternum amethyst',(0,-.275,1.49),(0,-.28,1.71),.045,'chest')
# Belt, two hip shields and divided cloth tabard and restrained back insignia.
surface('Belt',lambda u,v:(.25*sin(u*2*pi),.178*cos(u*2*pi),1.045+.08*v),48,5,leather,{'pelvis':1})
ring('Belt lock',(0,-.20,1.09),.064,.056,edge,'pelvis',.012)
shard('Belt core',(0,-.215,1.056),(0,-.22,1.12),.022,'pelvis')
for s in [-1,1]:
 plate('Hip tasset',[(s*.22,-.13,1.11),(s*.35,-.08,1.01),(s*.31,-.14,.79),(s*.20,-.20,.84),(s*.15,-.19,1.03)],.04,steel,'pelvis',.01)
# Back plate, six lamellar sections, power reservoir and only small violet apertures.
plate('Dorsal cuirass',[(-.28,.165,1.69),(0,.20,1.77),(.28,.165,1.69),(.25,.20,1.41),(0,.218,1.34),(-.25,.20,1.41)],-.038,steel,'chest')
for z in [1.41,1.49,1.57,1.65]:trimline('Dorsal spine',[(0,.235,z),(0,.239,z+.054)],'chest',.018)
for s in [-1,1]:
 trimline('Team back chevron',[(s*.065,.232,1.65),(s*.20,.205,1.58),(s*.09,.239,1.43)],'chest',.008)
 shard('Back power slit',(s*.115,.227,1.46),(s*.16,.213,1.61),.018,'chest')
exec(compile(open(os.path.join(ROOT,'tools','vanguard_details.py'),encoding='utf-8').read(),'vanguard_details.py','exec'))
# Inset rib work across each breastplate, kept below the leading bevel.
for sg in [-1,1]:
 for j in range(3):
  trimline('Recessed breast channels',[(sg*(.11+j*.045),-.252+j*.009,1.48),(sg*(.18+j*.036),-.236+j*.014,1.56),(sg*(.16+j*.035),-.224+j*.015,1.67)],'chest',.002)
# Forge the reference hammer onto the existing animated haft and grip coordinates.
# The separate, older weapon source remains untouched.
exec(compile(open(os.path.join(ROOT,'tools','vanguard_weapon.py'),encoding='utf-8').read(),'vanguard_weapon.py','exec'))
# Merge material surfaces and deform with the skeleton.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='Vanguard_SkinnedModel'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
mod=body.modifiers.new('Vanguard skeletal deformation','ARMATURE');mod.object=rig;body.parent=rig
scene=bpy.context.scene;scene.render.fps=30
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
def reset():
 for p in rig.pose.bones:p.location=(0,0,0);p.rotation_quaternion=(1,0,0,0);p.scale=(1,1,1)
def rot(name,x=0,y=0,z=0):rig.pose.bones[name].rotation_quaternion=Euler((x,y,z)).to_quaternion()
def aim(name,target):
 p=rig.pose.bones[name];head=p.head.copy();cur=p.matrix.to_quaternion();d=Vector(target)-head
 q=(cur@Vector((0,1,0))).rotation_difference(d.normalized())@cur
 m=q.to_matrix().to_4x4();m.translation=head;p.matrix=m;bpy.context.view_layer.update()
def solve(first,second,target,pole):
 h=rig.pose.bones[first].head.copy();d=Vector(target)-h;axis=d.normalized();a=ad.bones[first].length;b=ad.bones[second].length;dist=min(d.length,a+b-.0001)
 along=(a*a-b*b+dist*dist)/(2*dist);height=sqrt(max(0,a*a-along*along));bend=Vector(pole);bend=(bend-axis*bend.dot(axis)).normalized()
 aim(first,h+axis*along+bend*height);aim(second,target)
clips={};grip_errors=[]
for clip,frames in [('Idle',60),('Walk',36),('Run',24),('WalkBackward',40),('StrafeLeft',36),('StrafeRight',36),('Cast',48),('Strike',24)]:
 rig.animation_data_create();rig.animation_data.action=None;action=bpy.data.actions.new(clip);rig.animation_data.action=action;action.use_fake_user=True
 for frame in range(frames+1):
  reset();t=frame/frames;ph=t*2*pi;moving=clip in ['Walk','Run','WalkBackward','StrafeLeft','StrafeRight'];running=clip=='Run'
  bob=(.013*(1-cos(ph*2)) if moving else .003*sin(ph))
  rig.pose.bones['pelvis'].location=(.009*sin(ph) if moving else 0,bob-(.17 if running else .035 if moving else .015),0)
  rot('spine',.08 if running else .015, .025*sin(ph) if moving else .007*sin(ph))
  rot('chest',0,-.035*sin(ph) if moving else 0,.01*sin(ph));rot('head',-.02,.015*sin(ph),0)
  bpy.context.view_layer.update()
  for side,sg in [('L',1),('R',-1)]:
   if moving:
    q=(t+(0 if sg==1 else .5))%1;stance=.42 if running else .62;amp=.46 if running else .20
    if q<stance:forward=amp*(1-2*q/stance);lift=0
    else:
     v=(q-stance)/(1-stance);forward=-amp+2*amp*(v*v*(3-2*v));lift=(.12 if running else .065)*sin(pi*v)
    if clip=='WalkBackward':forward=-forward
    foot=Vector((sg*.185,-forward,.14+lift))
    if clip.startswith('Strafe'):foot.x+=forward*(1 if clip=='StrafeLeft' else -1);foot.y=0
    solve('thigh.'+side,'shin.'+side,foot,(0,-1,0))
    aim('foot.'+side,rig.pose.bones['foot.'+side].head+Vector((0,-.19,-.075+lift*.20)))
  # Both wrist targets derive from one animated weapon matrix. No hand/haft drift.
  turn=0.;lift=.012*sin(ph);push=0.
  if moving:turn=.024*sin(ph);lift=bob*.6
  if clip=='Cast':lift=.12*sin(pi*t)**2;turn=-.12*sin(pi*t)**2
  if clip=='Strike':
   # Short wind-up, forceful diagonal sweep and eased return; visual event only.
   keys=[0,.18,.34,.60,1];turn=float(np.interp(t,keys,[0,-.45,.66,.18,0]));lift=float(np.interp(t,keys,[0,.13,-.10,-.03,0]));push=float(np.interp(t,keys,[0,.06,-.16,-.04,0]))
  pivot=Vector((0,-.43,1.4));Q=Euler((0,turn,0)).to_matrix().to_4x4()
  X=Matrix.Translation(pivot+Vector((0,push,lift)))@Q@Matrix.Translation(-pivot)
  # Project the whole weapon into both arm reach spheres, preserving a rigid grip.
  for iteration in range(18):
   for side in ['L','R']:
    shoulder=rig.pose.bones['upper_arm.'+side].head
    target=X@ad.bones['hand.'+side].head_local
    reach=ad.bones['upper_arm.'+side].length+ad.bones['forearm.'+side].length-.012
    delta=target-shoulder
    if delta.length>reach:X.translation-=delta.normalized()*(delta.length-reach)
  wp=rig.pose.bones['weapon'];wp.matrix=X@ad.bones['weapon'].matrix_local;bpy.context.view_layer.update()
  for side,sg in [('L',1),('R',-1)]:
   b='hand.'+side;target=X@ad.bones[b].head_local
   solve('upper_arm.'+side,'forearm.'+side,target,(sg,-.25,-.15))
   hand=rig.pose.bones[b];m=X@ad.bones[b].matrix_local;hand.matrix=m;bpy.context.view_layer.update()
   grip_errors.append((hand.tail-(X@GRIPS[side])).length)
  for i in range(3):
   rot('tabard%d'%i,.08*sin(ph-.5+i*.2) if moving else .018*sin(ph+i),0,0)
   rot('hem%d'%i,.12*sin(ph-1+i*.2) if moving else .027*sin(ph-.4+i),0,0)
  for i in range(3):
   rot('cape%d'%i,-.035+(.055 if moving else .016)*sin(ph-.6+i*.35),.012*sin(ph+i),.009*sin(ph+i))
   rot('cape_tip%d'%i,-.035+(.10 if moving else .028)*sin(ph-1.2+i*.35),.018*sin(ph+i),.016*sin(ph+i))
  for p in rig.pose.bones:
   p.keyframe_insert('location',frame=frame+1,group=p.name);p.keyframe_insert('rotation_quaternion',frame=frame+1,group=p.name)
 rig.animation_data.action=None;tr=rig.animation_data.nla_tracks.new();tr.name=clip;st=tr.strips.new(clip,1,action);st.action_frame_start=1;st.action_frame_end=frames+1;tr.mute=True;clips[clip]=frames/30
for tr in rig.animation_data.nla_tracks:tr.mute=False
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
scene.frame_start=1;scene.frame_end=37;scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'vanguard.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_apply=False)
for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!='Walk'
# Inspection studio is excluded from export. Packed source opens ready for viewing.
world=bpy.data.worlds.new('Vanguard studio');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.07,.08,.12,1);world.node_tree.nodes['Background'].inputs[1].default_value=.4
studio=bpy.data.collections.new('REVIEW_ONLY');scene.collection.children.link(studio)
def studio_obj(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 studio.objects.link(o)
def light(name,loc,power,color,size):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
 o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.1))-o.location).to_track_quat('-Z','Y').to_euler()
light('Neutral key',(3,-4,5),780,(.94,.91,.87),4);light('Cool fill',(-3,-2,3),440,(.73,.79,1),3);light('Violet rim',(1,3,3.5),420,(.54,.33,.84),2)
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Studio floor';floor.data.materials.append(mat('Studio slate',(.022,.028,.04),.1,.6));studio_obj(floor)
bpy.ops.object.camera_add(location=(3,-6,2.6));cam=bpy.context.object;studio_obj(cam);cam.rotation_euler=(Vector((0,0,1.16))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.10;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_distance=3.8;area.spaces.active.region_3d.view_location=(0,0,1.13);area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
   area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,'vanguard.blend'))
scene.frame_set(1);scene.render.filepath=os.path.join(REVIEW,'front.png');bpy.ops.render.render(write_still=True)
cam.location=(-3,6,2.5);cam.rotation_euler=(Vector((0,0,1.16))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=os.path.join(REVIEW,'back.png');bpy.ops.render.render(write_still=True)
report={'material_surfaces':len(body.data.materials),'vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'bones':len(ad.bones),'clips':clips,'max_hand_grip_error':max(grip_errors),'weight_error':max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices)}
with open(os.path.join(REVIEW,'build_report.json'),'w') as f:json.dump(report,f,indent=2)
print('VANGUARD_BUILD_COMPLETE',json.dumps(report))
