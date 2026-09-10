"""Build Outlaw directly on the verified Model Forge v2 rig. Staged outputs only."""
import bpy, math, json, hashlib, random, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'artifacts/outlaw-forge-v2'
SEED=STAGE/'seed'
OUT=STAGE/'candidate'
OUT.mkdir(parents=True,exist_ok=True)
random.seed(91)
bpy.ops.wm.open_mainfile(filepath=str(SEED/'art_source/fulcrum_ual/fulcrum_ual.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['Fulcrum_UAL_Rig']; rig.name='Outlaw_UAL_Rig'
mannequin=bpy.data.objects['Fulcrum_UAL_Undersuit']; mannequin.name='Outlaw_UAL_Undersuit'
for obj in list(bpy.data.objects):
    if obj not in [rig,mannequin]: bpy.data.objects.remove(obj,do_unlink=True)
for track in rig.animation_data.nla_tracks: track.mute=True
rig.animation_data.action=None
for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
core=json.loads((SEED/'art_source/fulcrum_ual/recipe.json').read_text())['core_rest_matrices']
parts=[]

def mat(name,color,metal=0,rough=.5,emit=0):
    m=bpy.data.materials.new('Outlaw_'+name); m.use_nodes=True; m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
    return m
leather=mat('WeatheredDuster',(.07,.052,.036),0,.78)
steel=mat('BlackenedCelestialSteel',(.085,.095,.11),.8,.42)
brass=mat('WornBrass',(.32,.23,.11),.78,.4)
silver=mat('MachinedSilver',(.26,.29,.32),.85,.3)
black=mat('JointUndersuit',(.018,.023,.029),.28,.58)
gold=mat('StarOptics',(.95,.54,.12),.2,.3,2.3)
blue=mat('CondensedStarlight',(.19,.54,.95),.3,.28,2)
red=mat('BowieCrimsonEtching',(.45,.02,.03),.45,.34,.7)
glass=mat('ReactorGlass',(.05,.12,.20),.55,.19)
# Same portable 1024px image-map production method as the frozen recipe.
N=1024; v,u=np.mgrid[0:1:complex(N),0:1:complex(N)]
rng=np.random.default_rng(191); grain=rng.uniform(-1,1,(N,N))
cloud=np.clip(.5+.045*np.sin(u*31+np.sin(v*19))*np.cos(v*29)+grain*.17,0,1)
scuff=np.zeros((N,N))
for _ in range(380):
    x,y=rng.integers(12,N-55,2);length=int(rng.integers(5,44))
    for d in range(length):scuff[y+d//5,x+d]=.15*math.sin(math.pi*d/length)
def image(name,rgb,noncolor=False):
    data=np.ones((N,N,4),dtype=np.float32);data[:,:,:3]=rgb
    im=bpy.data.images.new('Outlaw '+name,width=N,height=N)
    if noncolor:im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(np.clip(data,0,1).ravel());im.filepath_raw=str(OUT/('outlaw_'+name+'.png'))
    im.file_format='PNG';im.save();im.pack();return im
def bind(m,im,slot):
    n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=im
    m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs[slot])
rgb=np.dstack([.055+cloud*.08+scuff,.037+cloud*.052+scuff*.72,.024+cloud*.04+scuff*.5])
bind(leather,image('duster',rgb),'Base Color')
rgb=np.dstack([.12+cloud*.07+scuff,.135+cloud*.07+scuff,.155+cloud*.07+scuff])
bind(steel,image('steel',rgb),'Base Color')
rough=image('roughness',np.repeat((.46+.25*cloud-scuff*.25)[:,:,None],3,axis=2),True)
bind(steel,rough,'Roughness')
h=.3*np.sin(u*2600)*np.sin(v*2300)+grain*.25
gy,gx=np.gradient(h);normal=np.dstack([-gx*.24,-gy*.24,np.ones((N,N))]);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
normal=image('micro_normal',normal*.5+.5,True)
for m in [leather,steel,black]:
    nt=m.node_tree;n=nt.nodes.new('ShaderNodeTexImage');n.image=normal
    nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.35
    nt.links.new(n.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
mannequin.data.materials.clear();mannequin.data.materials.append(black)
for p in mannequin.data.polygons:p.material_index=0;p.use_smooth=True

def mesh(name,verts,faces,material,weights,uvs=None,smooth=True):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(material)
    for p in me.polygons:p.use_smooth=smooth
    uv=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            idx=me.loops[li].vertex_index;co=me.vertices[idx].co
            uv.data[li].uv=uvs[idx] if uvs else (co.x*2+co.y,co.z*2+co.y)
    for i in range(len(verts)):
        ws=weights[i] if isinstance(weights,list) else weights
        total=sum(ws.values())
        for bn,w in ws.items():
            if w>0:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([i],w/total,'REPLACE')
    ob.parent=rig;mod=ob.modifiers.new('Preset deformation','ARMATURE');mod.object=rig
    parts.append(ob);return ob
def surface(name,fn,nu,nv,material,weight,thickness=0):
    verts=[];weights=[];uv=[];faces=[]
    for j in range(nv+1):
        for i in range(nu+1):
            a=i/nu;b=j/nv;p=fn(a,b);verts.append(p);uv.append((a,b));weights.append(weight(a,b,p) if callable(weight) else weight)
    for j in range(nv):
        for i in range(nu):
            k=j*(nu+1)+i;faces.append((k,k+1,k+nu+2,k+nu+1))
    ob=mesh(name,verts,faces,material,weights,uv)
    if thickness:
        mod=ob.modifiers.new('Garment thickness','SOLIDIFY');mod.thickness=thickness
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
def ellipsoid(name,c,r,m,bn):
    return surface(name,lambda a,b:(c[0]+r[0]*math.sin(math.pi*b)*math.cos(math.tau*a),c[1]+r[1]*math.sin(math.pi*b)*math.sin(math.tau*a),c[2]+r[2]*math.cos(math.pi*b)),24,14,m,{bn:1})

def armor_shell(name,c,r,m,bn,axis='Z'):
    # Fabricated eight-sided shells with broad faces and a narrow rolled bevel.
    # Coordinates fit the unchanged mannequin; the body/rig are never resized.
    c=Vector(c);verts=[];faces=[];steps=[(-1,.87),(-.87,1),(.73,1),(1,.90)];sides=16
    for height,radius in steps:
        for i in range(sides):
            a=math.tau*(i+.5)/sides
            q=Vector((r[0]*radius*math.cos(a),r[1]*radius*math.sin(a),r[2]*height))
            if axis=='X':q=Vector((q.z,q.y,q.x))
            verts.append(c+q)
    for row in range(3):
        for i in range(sides):faces.append((row*sides+i,row*sides+(i+1)%sides,(row+1)*sides+(i+1)%sides,(row+1)*sides+i))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple(range(3*sides,4*sides))])
    ob=mesh(name,verts,faces,m,{bn:1},smooth=True)
    for p in ob.data.polygons:
        if p.index>=3*sides:p.use_smooth=False
    mod=ob.modifiers.new('Plate edge radii','BEVEL');mod.width=.002;mod.segments=2
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
def tube(name,points,r,m,bn,sides=8):
    verts=[];faces=[]
    for i,pt in enumerate(points):
        p=Vector(pt);d=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
        x=d.cross(Vector((0,1,0)))
        if x.length<.01:x=d.cross(Vector((1,0,0)))
        x.normalize();y=d.cross(x)
        for j in range(sides):verts.append(p+r*(x*math.cos(math.tau*j/sides)+y*math.sin(math.tau*j/sides)))
    for i in range(len(points)-1):
        for j in range(sides):
            k=i*sides+j;l=i*sides+(j+1)%sides;faces.append((k,l,l+sides,k+sides))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))]
    return mesh(name,verts,faces,m,{bn:1})
def ring(name,c,rx,rz,m,bn,r=.004):
    return tube(name,[(c[0]+rx*math.sin(math.tau*i/64),c[1],c[2]+rz*math.cos(math.tau*i/64)) for i in range(65)],r,m,bn)
def star(name,c,size,m,bn):
    pts=[]
    for i in range(17):
        a=math.tau*i/16;s=size if i%2==0 else size*.25
        if i%4==2:s*=.65
        pts.append((c[0]+math.sin(a)*s,c[1],c[2]+math.cos(a)*s))
    return mesh(name,[(c[0],c[1]-.003,c[2])]+pts,[(0,i+1,i+2) for i in range(16)],m,{bn:1},smooth=False)
def panel(name,points,m,bn,thickness=.006):
    n=len(points);verts=points+[(x,y+thickness,z) for x,y,z in points]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh(name,verts,faces,m,{bn:1},smooth=False)
    mod=ob.modifiers.new('Forged bevel','BEVEL');mod.width=.003;mod.segments=2
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
# Fitted mechanical torso, waistcoat and front-open split duster.
surface('Tailored cuirass foundation',lambda u,v:((.155+.065*math.sin(v*math.pi*.8))*math.sin(math.tau*u),(.154+.02*math.sin(v*math.pi))*math.cos(math.tau*u),1.025+.435*v),64,20,leather,
        lambda u,v,p:{'DEF-spine.001':max(0,1-v*2),'DEF-spine.002':1-abs(v*2-1),'DEF-spine.003':max(0,v*2-1)},.007)
for i,z in enumerate([1.07,1.16,1.25,1.36]):
    width=[.145,.155,.18,.205][i];height=[.045,.05,.054,.078][i]
    bn=['DEF-spine.001','DEF-spine.001','DEF-spine.002','DEF-spine.003'][i]
    for side in [-1,1]:
        pts=[(side*.012,-.158,z-height),(side*(width-.02),-.140,z-height*.8),(side*width,-.126,z+height),(side*.02,-.169,z+height*.8)]
        panel('Articulated vest plate',pts,steel,bn,.012)
        tube('Vest brass piping',pts+[pts[0]],.0026,brass,bn)
        for pt in pts[1:3]:ellipsoid('Vest rivet',Vector(pt)+Vector((0,-.005,0)),(.005,.003,.005),silver,bn)
for side in [-1,1]:
    pts=[(side*.03,-.181,1.18),(side*.13,-.181,1.22),(side*.21,-.135,1.48),(side*.11,-.125,1.49)]
    panel('Duster lapel',pts,leather,'DEF-spine.003')
    tube('Lapel stitch',pts+[pts[0]],.002,brass,'DEF-spine.003')
    ring('Lapel medallion',(side*.155,-.165,1.408),.022,.025,brass,'DEF-spine.003',.002)
surface('Duster back',lambda u,v:(.20*math.sin((u-.5)*math.pi),.12+.025*math.cos((u-.5)*math.pi),1.02+v*.43),28,16,leather,
        lambda u,v,p:{'DEF-spine.001':1-v,'DEF-spine.003':v},.006)
def coat(u,v):
    angle=-2.53+5.06*u;radius=.18+.13*v
    z=.98-.78*v+(.030*math.sin(u*53)+.014*math.sin(u*137))*v**9
    return (radius*math.sin(angle),(.15+.10*v)*math.cos(angle)+.028*v*math.sin(u*67),z)
def coat_weight(u,v,p):
    angle=-2.53+5.06*u;i=round((angle%math.tau)/math.tau*10)%10;t=max(0,min(1,(v-.4)/.6))
    return {'robe'+str(i):1-t,'hem'+str(i):t}
for segment in range(8):
    lo=segment/8+.002;hi=(segment+1)/8-.002
    surface('Split celestial duster tail',lambda u,v,lo=lo,hi=hi:coat(lo+(hi-lo)*u,v),16,25,leather,
            lambda u,v,p,lo=lo,hi=hi:coat_weight(lo+(hi-lo)*u,v,p),.005)
for u0 in [.06,.30,.5,.70,.94]:
    angle=-2.53+5.06*u0;i=round((angle%math.tau)/math.tau*10)%10
    tangent=Vector((math.cos(angle),-math.sin(angle),0));normal=Vector((math.sin(angle),math.cos(angle),0))
    for v0,size in [(.26,.020),(.48,.032),(.67,.017)]:
        pt=Vector(coat(u0,v0))+normal*.007
        ob=star('Duster constellation embroidery',(0,0,0),size,brass,('hem' if v0>.6 else 'robe')+str(i))
        for vert in ob.data.vertices:vert.co=pt+tangent*vert.co.x-normal*vert.co.y+Vector((0,0,vert.co.z))
for u0 in [.01,.13,.25,.37,.50,.63,.75,.87,.99]:
    pts=[coat(u0,v/30) for v in range(31)];i=round(((-2.53+5.06*u0)%math.tau)/math.tau*10)%10
    # Embroidery inherits the exact garment weights at every vertex.
    ob=tube('Constellation seam',[(p[0]*1.012,p[1]*1.012,p[2]) for p in pts],.0017,brass,'robe'+str(i))
    for vertex in ob.data.vertices:
        t=max(0,min(1,((.98-vertex.co.z)/.78-.4)/.6))
        for g in ob.vertex_groups:g.remove([vertex.index])
        for bn,w in [('robe'+str(i),1-t),('hem'+str(i),t)]:
            if w:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([vertex.index],w,'REPLACE')
for z in [.98,1.01]:
    surface('Gun belt',lambda u,v:(.18*math.sin(math.tau*u),.133*math.cos(math.tau*u),z+v*.032),48,2,leather,{'DEF-hips':1},.005)
panel('Belt buckle',[(-.043,-.149,.976),(.043,-.149,.976),(.043,-.149,1.039),(-.043,-.149,1.039)],brass,'DEF-hips')
panel('Belt buckle inset',[(-.032,-.157,.987),(.032,-.157,.987),(.032,-.157,1.028),(-.032,-.157,1.028)],steel,'DEF-hips')
star('Buckle compass',(0,-.163,1.008),.019,silver,'DEF-hips')
# Arms and legs follow the preset's real joint landmarks without scaling it.
for side,sign in [('L',1),('R',-1)]:
    for first,last,radius in [('upper_arm','forearm',.068),('forearm','hand',.056)]:
        bn='DEF-'+first+'.'+side;a=rig.data.bones[bn].head_local;b=rig.data.bones['DEF-'+last+'.'+side].head_local
        d=b-a
        tube('Joint actuator',[a+d*.08,b-d*.08],radius*.52,silver,bn,16)
        for k in range(3):
            c=a+d*(.23+k*.23)
            armor_shell('Arm armor segment',c,(.074,.071,.054) if first=='upper_arm' else (.060,.061,.052),steel,bn,'X')
            tube('Arm copper rib',[c+Vector((0,-radius,-.035)),c+Vector((0,-radius,.035))],.003,brass,bn)
            for zoff in [-.039,.039]:
                ellipsoid('Arm plate rivet',c+Vector((0,-radius-.004,zoff)),(.006,.003,.006),silver,bn)
        ellipsoid('Joint pivot',a,(.065,.059,.062),black,bn)
        ring('Joint bearing',(a.x,a.y-.059,a.z),.027,.027,brass,bn)
    shoulder=rig.data.bones['DEF-upper_arm.'+side].head_local
    for tier in range(3):
        c=shoulder+Vector((sign*(.024+tier*.038),0,.018-tier*.012))
        def mantle(u,v,c=c,tier=tier):
            a=math.pi*u
            return (c.x+sign*(v-.5)*.056,c.y+.11*math.cos(a),c.z+(.082-tier*.007)*math.sin(a))
        surface('Overlapping shoulder leather and steel',mantle,24,4,leather if tier==0 else steel,{'DEF-upper_arm.'+side:1},.006)
        tube('Shoulder scallop brass edge',[mantle(i/24,1) for i in range(25)],.003,brass,'DEF-upper_arm.'+side)
    for k in range(2):
        pts=[(shoulder.x+sign*(.01+k*.03),shoulder.y-.088,shoulder.z+.074),(shoulder.x+sign*(.10+k*.02),shoulder.y-.07,shoulder.z+.035),(shoulder.x+sign*(.115+k*.02),shoulder.y-.064,shoulder.z-.018)]
        tube('Shoulder mantle piping',pts,.003,brass,'DEF-shoulder.'+side)
    for joint,next_joint,radius in [('thigh','shin',.08),('shin','foot',.065)]:
        bn='DEF-'+joint+'.'+side;a=rig.data.bones[bn].head_local;b=rig.data.bones['DEF-'+next_joint+'.'+side].head_local
        tube('Leg actuator',[a+(b-a)*.13,b-(b-a)*.14],radius*.43,silver,bn,16)
        for k in range(3):
            c=a+(b-a)*(.22+k*.235)
            armor_shell('Leg segmented armor',c,(radius,.086 if joint=='thigh' else .074,.081),steel,bn)
            panel('Greave raised bevel',[(c.x-radius*.65,c.y-.081,c.z+.053),(c.x+radius*.65,c.y-.081,c.z+.053),(c.x+radius*.5,c.y-.084,c.z-.05),(c.x,c.y-.096,c.z-.073),(c.x-radius*.5,c.y-.084,c.z-.05)],silver,bn)
        ellipsoid('Knee or hip housing',a,(radius*.84,.064,.057),black,bn)
        ring('Leg bearing',(a.x,a.y-.067,a.z),.028,.028,brass,bn)
    foot='DEF-foot.'+side;x=sign*.089
    armor_shell('Armored cowboy boot',(x,-.07,.069),(.073,.161,.055),leather,foot)
    armor_shell('Silver toe cap',(x,-.167,.052),(.074,.069,.031),steel,foot)
    tube('Boot welt',[(x+.075*math.sin(math.tau*i/48),-.084+.16*math.cos(math.tau*i/48),.024) for i in range(49)],.004,brass,foot)
    tube('Spur mount',[(x,.077,.079),(x,.114,.079)],.009,brass,foot)
    star('Star spur',(x,.12,.08),.027,brass,foot)
    armor_shell('Holster' if sign<0 else 'Bowie sheath',(sign*.183,-.078,.845),(.043,.052,.147),leather,'DEF-hips')
# Neck, robotic face, optics, and a genuinely shaped cowboy hat.
for i in range(4):
    ellipsoid('Neck servo collar',(0,.002,1.51+i*.024),(.065,.061,.013),silver if i%2 else black,'DEF-neck')
surface('High duster collar',lambda u,v:(.092*math.sin(math.tau*u),.091*math.cos(math.tau*u),1.482+.068*v),48,4,leather,{'DEF-neck':1},.006)
tube('High collar seam',[(.094*math.sin(math.tau*i/64),.094*math.cos(math.tau*i/64),1.552) for i in range(65)],.0025,brass,'DEF-neck')
ellipsoid('Robot cranium',(0,.001,1.709),(.104,.094,.122),steel,'DEF-head')
panel('Faceted mechanical face',[(-.088,-.072,1.766),(-.05,-.117,1.792),(.05,-.117,1.792),(.088,-.072,1.766),(.076,-.088,1.669),(.037,-.12,1.617),(-.037,-.12,1.617),(-.076,-.088,1.669)],steel,'DEF-head',.02)
for sign in [-1,1]:
    panel('Cheek guard',[(sign*.084,-.10,1.745),(sign*.069,-.132,1.722),(sign*.035,-.14,1.641),(sign*.025,-.127,1.623)],silver,'DEF-head')
    ellipsoid('Amber optic',(sign*.046,-.13,1.747),(.018,.01,.012),gold,'DEF-head')
    ring('Optic bearing',(sign*.046,-.139,1.747),.022,.018,brass,'DEF-head',.0025)
    tube('Jaw seam',[(sign*.018,-.142,1.71),(sign*.025,-.142,1.635)],.003,brass,'DEF-head')
for x in [-.011,0,.011]:tube('Mouth grille',[(x,-.137,1.701),(x,-.139,1.642)],.0025,black,'DEF-head')
def brim(u,v):
    a=math.tau*u;rx=.109+.205*v;ry=.091+.15*v
    return (rx*math.cos(a),ry*math.sin(a),1.817+.048*v*v*math.cos(a)**4-.012*v*max(0,-math.sin(a)))
surface('Curved cowboy hat brim',brim,96,8,leather,{'DEF-head':1},.006)
tube('Hat brim worn binding',[brim(i/96,1) for i in range(97)],.003,brass,'DEF-head')
surface('Pinched crown',lambda u,v:((.106-.025*v)*math.cos(math.tau*u),(.09-.015*v)*math.sin(math.tau*u),1.821+.148*v-.018*v**4*math.cos(math.tau*u)**2),64,12,leather,{'DEF-head':1},.006)
surface('Creased hat crown top',lambda u,v:((.081*v)*math.cos(math.tau*u),(.075*v)*math.sin(math.tau*u),1.969-.018*math.cos(math.tau*u)**2-.012*(1-v)),64,6,leather,{'DEF-head':1},.004)
tube('Hatband',[(.109*math.cos(math.tau*i/64),.095*math.sin(math.tau*i/64),1.844) for i in range(65)],.009,black,'DEF-head')
star('Hat star pin',(.057,-.081,1.883),.025,brass,'DEF-head')
# Reactor has nested metal collars and fine radial circuitry, not a flat decal.
ellipsoid('Chest reactor glass',(0,-.183,1.375),(.059,.023,.059),glass,'DEF-spine.003')
ring('Reactor outer collar',(0,-.204,1.375),.066,.066,brass,'DEF-spine.003',.006)
ring('Reactor inner collar',(0,-.208,1.375),.050,.050,silver,'DEF-spine.003',.002)
star('Reactor star',(0,-.211,1.375),.045,blue,'DEF-spine.003')
ellipsoid('Reactor core',(0,-.216,1.375),(.012,.01,.012),gold,'DEF-spine.003')
for sign in [-1,1]:
    tube('Reactor conduit',[(sign*.055,-.185,1.39),(sign*.12,-.159,1.43),(sign*.2,-.105,1.45)],.004,brass,'DEF-spine.003')
ring('Back celestial seal',(0,.165,1.35),.07,.07,brass,'DEF-spine.003',.003)
star('Back compass',(0,.171,1.35),.09,brass,'DEF-spine.003')
for z in [1.20,1.26,1.44]:star('Back star',(0,.165,z),.013,silver,'DEF-spine.003')
# Hand-parented equipment controls. Rest and inherited core motion stay intact.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,side in [('outlaw.gun','R'),('outlaw.knife','L')]:
    b=rig.data.edit_bones.new(name);b.parent=rig.data.edit_bones['DEF-hand.'+side]
    b.head=b.parent.head;b.tail=b.head+Vector((0,-.1,0))
bpy.ops.object.mode_set(mode='OBJECT')
# Weapon geometry authored in an ergonomic palm-local frame then transformed
# by the exact preset hand bind matrix, avoiding guessed world hand positions.
def weapon_space(objects,side):
    transform=rig.data.bones['DEF-hand.'+side].matrix_local
    for ob in objects:
        for v in ob.data.vertices:v.co=transform@v.co
gun_start=len(parts);bn='outlaw.gun'
tube('Revolver grip',[(-.030,.101,-.062),(-.030,.117,.061)],.023,leather,bn,16)
tube('Revolver barrel',[(-.030,.17,.085),(-.030,.395,.085)],.025,steel,bn,24)
tube('Revolver bore rim',[(-.030,.388,.085),(-.030,.411,.085)],.031,silver,bn,24)
tube('Barrel energy bore',[(-.030,.41,.085),(-.030,.413,.085)],.017,blue,bn,24)
tube('Revolver cylinder',[(-.030,.102,.085),(-.030,.178,.085)],.047,steel,bn,32)
for i in range(6):
    a=math.tau*i/6;c=Vector((-.030+math.cos(a)*.032,0,.085+math.sin(a)*.032))
    tube('Star-forge chamber',[c+Vector((0,.106,0)),c+Vector((0,.173,0))],.009,blue,bn,12)
for y in [.100,.181]:tube('Cylinder brass ring',[(-.030+.046*math.cos(math.tau*i/32),y,.085+.046*math.sin(math.tau*i/32)) for i in range(33)],.004,brass,bn)
tube('Trigger guard',[(-.03,.132,.058),(-.03,.195,.047),(-.03,.2,.005),(-.03,.14,-.002),(-.03,.123,.02)],.005,brass,bn)
tube('Trigger',[(-.03,.157,.05),(-.03,.151,.02)],.004,silver,bn)
tube('Front sight',[(-.03,.376,.112),(-.03,.376,.13)],.005,silver,bn)
tube('Barrel brass rail',[(-.03,.187,.113),(-.03,.381,.113)],.003,brass,bn)
weapon_space(parts[gun_start:],'R')
knife_start=len(parts);bn='outlaw.knife'
tube('Bowie grip',[(0,.006,-.055),(0,.099,-.055)],.018,leather,bn,16)
tube('Bowie guard',[(-.055,.106,-.055),(.052,.106,-.055)],.009,brass,bn,16)
panel('Bowie clip-point blade',[(-.027,-.058,.113),(.028,-.058,.113),(.029,-.058,.27),(.008,-.058,.34),(-.03,-.058,.276)],silver,bn,.008)
# Align blade along the gripping hand's local Y, distinct from gun forward Z.
for ob in parts[knife_start+2:]:
    for vert in ob.data.vertices:vert.co=Vector((vert.co.x,vert.co.z,vert.co.y))
tube('Bowie crimson groove',[(-.009,.128,-.064),(-.009,.26,-.064),(.008,.331,-.064)],.002,red,bn)
# Owner revision: 150% size, rotated across the palm instead of along fingers.
# Handle center comes from the actual supplied idle fist's interior in hand space.
for ob in parts[knife_start:]:
    for vert in ob.data.vertices:
        x,y,z=vert.co
        vert.co=Vector((.030+(z+.055)*1.5,.107-x*1.5,-(y-.050)*1.5))
weapon_space(parts[knife_start:],'L')
# Join costume/gear into one skinned mesh with portable materials and UVs.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();costume=bpy.context.object;costume.name='Outlaw_SkinnedModel'
# Preserve all 32 frozen tracks exactly. Add source-native Roll/pistol/knife
# clips separately; they never replace the accepted locomotion/jump set.
existing=set(bpy.data.actions)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SEED/'art_source/fulcrum_ual/AnimationLibrary_Godot_Standard.glb'))
source_rig=next(o for o in bpy.data.objects if o not in before and o.type=='ARMATURE')
source_actions={a.name:a for a in bpy.data.actions if a not in existing}
extra_clips={'Roll':'Roll','GunAim':'Pistol_Aim_Neutral','GunShoot':'Pistol_Shoot','KnifeStrike':'Sword_Attack'}
scene=bpy.context.scene;fps=scene.render.fps
extra_samples={}
for label,source_name in extra_clips.items():
    act=source_actions[source_name];source_rig.animation_data_create();source_rig.animation_data.action=act
    if act.slots:source_rig.animation_data.action_slot=act.slots[0]
    frames=[]
    start,end=act.frame_range;count=round(end-start)
    for i in range(count+1):
        scene.frame_set(round(start)+i)
        frame={n:source_rig.pose.bones[n].matrix_basis.copy() for n in core}
        if label=='KnifeStrike':
            mirror=Matrix.Diagonal((-1,1,1,1));poses={}
            for n in core:
                other=n[:-1]+('R' if n.endswith('.L') else 'L') if n.endswith(('.L','.R')) else n
                src=source_rig.pose.bones[other]
                poses[n]=mirror@(src.matrix@src.bone.matrix_local.inverted())@mirror@source_rig.data.bones[n].matrix_local
            for n in core:
                bone=source_rig.data.bones[n]
                frame[n]=bone.matrix_local.inverted()@bone.parent.matrix_local@poses[bone.parent.name].inverted()@poses[n] if bone.parent and bone.parent.name in poses else poses[n]
        frames.append(frame)
    extra_samples[label]=frames
for ob in list(bpy.data.objects):
    if ob not in before:bpy.data.objects.remove(ob,do_unlink=True)
for act in list(bpy.data.actions):
    if act not in existing:bpy.data.actions.remove(act)
for label,frames in extra_samples.items():
    act=bpy.data.actions.new(label);rig.animation_data_create();rig.animation_data.action=act
    for i,frame in enumerate(frames):
        for name,matrix in frame.items():
            p=rig.pose.bones[name];p.rotation_mode='QUATERNION';p.matrix_basis=matrix
            if name=='root':p.location=Vector((0,0,0))
            for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(prop,frame=i+1,group=name)
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=label
    strip=track.strips.new(label,1,act);strip.action_frame_end=len(frames);track.mute=True
for track in rig.animation_data.nla_tracks:track.mute=track.name!='Idle'
scene.frame_start=1;scene.frame_end=76;scene.frame_set(1)
rig.show_in_front=True
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.shading.type='MATERIAL';s.overlay.show_overlays=False
            s.region_3d.view_location=Vector((0,0,1));s.region_3d.view_distance=3.7
            s.region_3d.view_rotation=Quaternion((1,0,0),math.radians(82))
# Remove old unreferenced texture blocks from portable source.
for material in list(bpy.data.materials):
    if material.users==0:bpy.data.materials.remove(material)
for im in list(bpy.data.images):
    if not im.name.startswith('Outlaw ') and im.users==0:bpy.data.images.remove(im)
bpy.ops.object.select_all(action='DESELECT')
for ob in [rig,mannequin,costume]:ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'outlaw.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'outlaw.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_apply=False)
record={'class':'Outlaw','workflow':'Starfall Model Forge v2','core_bones':53,'core_motion_exceptions':[],
        'seed_blend_sha256':hashlib.sha256((SEED/'art_source/fulcrum_ual/fulcrum_ual.blend').read_bytes()).hexdigest(),
        'core_rest_matrices':core,'blender':bpy.app.version_string,'seeds':{'python':91,'numpy':191},
        'extras':extra_clips,'equipment_controls':['outlaw.gun','outlaw.knife'],
        'knife_revision':{'scale':1.5,'grip':'Native closed idle fist, handle across palm, reverse grip with blade clear of torso','left_hand_center':[.030,.107,0]},
        'knife_attack':'Source Sword_Attack mirrored into left hand; original 32 clips untouched',
        'texture_palette':'Weathered brown-black leather, black steel, brass, gold optics, blue gun energy, crimson blade etching',
        'clips':[t.name for t in rig.animation_data.nla_tracks]}
(OUT/'recipe.json').write_text(json.dumps(record,indent=2))
print('OUTLAW_BUILD_COMPLETE',len(costume.data.vertices),'costume vertices',len(rig.data.bones),'bones',len(record['clips']),'clips',flush=True)
