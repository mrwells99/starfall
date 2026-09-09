"""Luminary-specific geometry, executed by build_luminary.py in its builder context."""
# The hood replaces the entire face, scalp, ears, hair and exposed neck.
# No concealed human head is retained beneath it.
lining=mat('Luminary_HoodLining',(.008,.011,.024),0,1.0)
shadow=mat('Luminary_FeaturelessShadow',(.001,.0015,.004),0,1.0)
for material in (lining,shadow):
 material.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0

def hood_fn(u,v):
 a=-2.46+u*4.92;z=1.55+v*.55
 rx=float(np.interp(v,[0,.2,.52,.76,1],[.218,.235,.222,.152,.004]))
 ry=float(np.interp(v,[0,.3,.65,1],[.183,.208,.174,.004]))
 return(rx*sin(a),.035+ry*cos(a),z+.009*sin(a*3)*sin(pi*v))
hood=surface('Ivory sanctuary hood',hood_fn,56,32,cloth,{'head':1})
hood.data.materials.append(lining)
bpy.ops.object.select_all(action='DESELECT');hood.select_set(True);bpy.context.view_layer.objects.active=hood
# The parameterized hood's initial winding is inward; reverse before thickening.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.flip_normals();bpy.ops.object.mode_set(mode='OBJECT')
shell=hood.modifiers.new('Lined cloth thickness','SOLIDIFY');shell.thickness=.006;shell.offset=-1;shell.material_offset=1;shell.material_offset_rim=1
bpy.ops.object.modifier_apply(modifier=shell.name)
# Recessed dark cloth closes the opening without eyes, nose, mouth or head-shaped relief.
surface('Featureless recessed veil',lambda u,v:((2*u-1)*abs(hood_fn(0,v)[0])*.98,hood_fn(0,v)[1]+.045,1.55+.55*v),36,34,shadow,{'head':1})
for uu in [0,1]:
 for off,rad in [(0,.0065),(.012,.0028)]:
  tube('Hood gold binding',[Vector(hood_fn(uu,v))+Vector((0,-off,0)) for v in np.linspace(0,1,60)],rad,gold,'head')
# Ivory cowl conceals the neck and joins the hood to the armor.
for j in range(5):
 tube('Sanctuary cowl fold',[(.205*sin(a),.174*cos(a),1.57-j*.018+.027*cos(a)) for a in np.linspace(0,2*pi,65)],.014,cloth,'head')
tube('Cowl lower braid',[(.207*sin(a),.177*cos(a),1.493+.027*cos(a)) for a in np.linspace(0,2*pi,65)],.004,gold,'head')
# Lunar embroidery sits on the outside of the hood, never in the dark opening.
for sign in [-1,1]:
 for j in range(3):
  center=.29+j*.16
  pts=[]
  for a in np.linspace(.4,5.6,36):
   v=center+.022*cos(a);u=(.08 if sign<0 else .92)+.018*sin(a)
   q=Vector(hood_fn(u,v));q.y-=.004;pts.append(q)
  tube('Hood crescent embroidery',pts,.0022,gold,'head',6)
# Luminary's celestial halo remains outside the hood silhouette.
for rx,rz,rad in [(.283,.337,.005),(.263,.317,.003)]:ring('Sanctuary halo',(0,.215,1.855),rx,rz,gold,'head',rad)
for k in range(8):
 a=2*pi*k/8;x=.28*sin(a);z=1.855+.334*cos(a)
 tube('Halo ray',[(x*.97,.215,1.855+(z-1.855)*.97),(x*1.16,.215,1.855+(z-1.855)*1.16)],lambda t:.0045*(1-t)+.0005,edge,'head',8)
# Long weighted cape: navy center, ivory side panels; delayed motion is added to the shared gait.
def cape_weights(v,i):
 if v>.75:return {'chest':(v-.75)/.25,'cape%d'%i:1-(v-.75)/.25}
 t=max(0,min(1,(v-.24)/.40));return {'cape%d'%i:t,'cape_tip%d'%i:1-t}
def reweight_by_rows(ob,rows,sides,fn):
 ob.vertex_groups.clear()
 for vi in range(len(ob.data.vertices)):
  v=(vi//sides)/max(1,rows-1)
  for bn,w in fn(v).items():
   if w>0:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([vi],w,'REPLACE')
for i in range(3):
 def cape_fn(u,v,i=i):
  t=1-v;spread=.17+.13*t
  x=((i-1)+(u-.5)*1.09)*spread
  y=.19+.24*t+.019*sin(u*pi*4)*t
  z=1.51-1.30*t+.18*abs(u-.5)*2*t*t
  return(x,y,z)
 surface('Royal cape '+str(i),cape_fn,16,30,navy if i==1 else cloth,lambda u,v,p,i=i:cape_weights(v,i))
 for uu in [.035,.965]:
  ob=tube('Cape gold selvedge',[cape_fn(uu,v) for v in np.linspace(0,1,40)],.004,gold,'chest')
  reweight_by_rows(ob,40,8,lambda v,i=i:cape_weights(v,i))
 # Woven constellations and lunar phases on the navy center train.
 if i==1:
  for j in range(7):
   v=.12+j*.095;c=Vector(cape_fn(.5,v))+Vector((0,.004,0));bn='cape1' if v>.45 else 'cape_tip1'
   if j in [1,4]:
    pts=[c+Vector((.04*sin(a),0,.04*cos(a))) for a in np.linspace(.4,5.6,42)]
    ob=tube('Cape crescent',pts,.0038,gold,bn)
   else:
    pts=[c+Vector((.035*sin(k*pi/4)*(1 if k%2==0 else .22),0,.05*cos(k*pi/4)*(1 if k%2==0 else .22))) for k in range(9)]
    ob=tube('Cape star',pts,.0023,edge,bn,6)
   ob.vertex_groups.clear()
   for b,w in cape_weights(v,i).items():
    if w>0:ob.vertex_groups.new(name=b).add(list(range(len(ob.data.vertices))),w,'REPLACE')
# Front ceremonial tabard with lunar embroidery, separated from the moving legs.
def tabard_fn(u,v):
 t=1-v;width=.17-.025*t
 return((u-.5)*width,-.184-.16*t-.008*sin(u*pi*4),1.08-.86*t+.055*abs(u-.5)*2*t)
def tabard_weight(v):
 t=max(0,min(1,(v-.35)/.4));top=max(0,(v-.85)/.15)
 return {'hem5':1-t,'robe5':t*(1-top),'pelvis':t*top}
surface('Ivory lunar tabard',tabard_fn,18,30,cloth,lambda u,v,p:tabard_weight(v))
for uu in [.07,.93]:
 ob=tube('Tabard braid',[tabard_fn(uu,v) for v in np.linspace(0,1,38)],.0035,gold,'pelvis');reweight_by_rows(ob,38,8,tabard_weight)
for j in range(7):
 v=.16+j*.103;c=Vector(tabard_fn(.5,v))+Vector((0,-.003,0));r=.018 if j%2 else .027
 if j in [1,4]:pts=[c+Vector((r*sin(a),0,r*cos(a))) for a in np.linspace(.45,5.5,35)]
 else:pts=[c+Vector((r*sin(k*pi/4)*(1 if k%2==0 else .24),0,r*cos(k*pi/4)*(1 if k%2==0 else .24))) for k in range(9)]
 ob=tube('Tabard lunar embroidery',pts,.002,gold,'pelvis',6);ob.vertex_groups.clear()
 for b,w in tabard_weight(v).items():
  if w>0:ob.vertex_groups.new(name=b).add(list(range(len(ob.data.vertices))),w,'REPLACE')
# Back clasp and chest sunburst.
for c,bn in [((0,.22,1.44),'chest'),((0,-.196,1.40),'chest'),((0,-.208,1.06),'pelvis')]:
 ring('Astral medallion rim',c,.051,.059,gold,bn,.006)
 ellipse('Medallion moonstone',(c[0],c[1]+(.008 if c[1]>0 else -.008),c[2]),(.032,.014,.038),star,bn,24,16)
 for a in np.linspace(0,2*pi,9)[:-1]:
  tube('Medallion ray',[(c[0]+.04*sin(a),c[1],c[2]+.048*cos(a)),(c[0]+.073*sin(a),c[1],c[2]+.08*cos(a))],.0028,edge,bn,6)
# Right-hand staff: bone attachment is baked upright relative to the moving grip.
bn='staff';sx=-.477;sy=-.065
staff_start=len(parts)
tube('Ebon staff shaft',[(sx,sy,.23),(sx,sy,1.86)],.014,leather,bn,16)
for z in np.linspace(.3,1.83,11):
 tube('Staff ferrule',[(sx+.019*sin(a),sy+.019*cos(a),z) for a in np.linspace(0,2*pi,33)],.003,gold,bn,6)
for z in [.86,.94,1.01]:
 tube('Grip winding',[(sx+.018*sin(a),sy+.018*cos(a),z+a*.002) for a in np.linspace(0,pi*8,60)],.0025,gold,bn,6)
orb=Vector((sx,sy,2.015))
ellipse('Staff celestial sphere',orb,(.098,.098,.098),celestial,bn,40,24)
# Surface tracery and embedded stars give the staff lens a celestial interior.
for j in range(3):
 points=[]
 for t in np.linspace(0,1,70):
  a=t*pi*3.1+j*2*pi/3;rad=.01+.075*t
  points.append(orb+Vector((rad*cos(a),-sqrt(max(0,.099**2-rad**2))-.001,rad*sin(a))))
 tube('Orb star current',points,.0013,star,bn,6)
for j in range(12):
 x=random.uniform(-.065,.065);z=random.uniform(-.065,.065);y=-sqrt(max(.001,.098**2-x*x-z*z))-.003
 ellipse('Orb constellation',orb+Vector((x,y,z)),(.0018,.0018,.0018),star,bn,8,6)
for j in range(3):
 a=j*pi/3;pts=[]
 for t in np.linspace(0,2*pi,65):pts.append(orb+Vector((.14*sin(t)*cos(a),.14*sin(t)*sin(a),.19*cos(t))))
 tube('Armillary cage',pts,.0055,gold,bn,8)
for s in [-1,1]:
 tube('Staff lance',[(sx,sy,2.015+s*.10),(sx,sy,2.015+s*.27)],lambda t:.014*(1-t)+.001,edge,bn,10)
for j in range(4):
 a=j*pi*.5
 tube('Staff compass point',[orb+Vector((.12*sin(a),.12*cos(a),0)),orb+Vector((.20*sin(a),.20*cos(a),0))],lambda t:.009*(1-t)+.001,edge,bn,8)
# A short ivory streamer hangs from the staff crown.
def streamer(u,v):
 t=1-v;return(sx+.105+(u-.5)*.062+.03*sin(t*6),sy+.045+.05*t,1.91-.52*t+.022*abs(u-.5))
surface('Staff ribbon',streamer,8,20,cloth,{bn:1})
for uu in [.07,.93]:tube('Staff ribbon edge',[streamer(uu,v) for v in np.linspace(0,1,28)],.0025,gold,bn,6)
# Utility relics on the belt, away from joint bends.
for s in [-1,1]:
 x=s*.225
 tube('Belt chain',[(x+s*.035*sin(t*pi),-.11,.99-t*.14) for t in np.linspace(0,1,30)],.003,gold,'pelvis',6)
 ellipse('Reliquary vial',(x+s*.025,-.113,.79),(.022,.024,.07),celestial,'pelvis',20,14)
 for z in [.73,.85]:ring('Vial cap',(x+s*.025,-.113,z),.023,.012,gold,'pelvis',.004)
