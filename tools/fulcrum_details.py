"""Fulcrum costume geometry, executed in build_fulcrum.py's Blender context."""
# Every visible surface is skinned geometry; no hidden human face, scalp or hair.
def apply_shell(ob,thickness=.005,bevel=0):
 bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
 m=ob.modifiers.new('Forged thickness','SOLIDIFY');m.thickness=thickness;m.offset=-1
 bpy.ops.object.modifier_apply(modifier=m.name)
 if bevel:
  m=ob.modifiers.new('Polished plate edges','BEVEL');m.width=bevel;m.segments=3
  bpy.ops.object.modifier_apply(modifier=m.name)
 return ob

def plate(name,outline,material,bn,ridge=.014,rim=False):
 # Convex plated shield with a shallow sculpted central ridge and beveled perimeter.
 vs=[Vector(p) for p in outline];c=sum(vs,Vector())/len(vs);c+=Vector(ridge) if isinstance(ridge,tuple) else Vector((0,-ridge,0))
 n=len(vs);vs.append(c);fs=[(i,(i+1)%n,n) for i in range(n)]
 ob=mesh(name,vs,fs,material,{bn:1});apply_shell(ob,.008,.002)
 if rim:tube(name+' worn edge',outline+[outline[0]],.0028,edge,bn,6)
 return ob

def rows_weight(ob,rows,sides,fn):
 ob.vertex_groups.clear()
 for vi in range(len(ob.data.vertices)):
  t=(vi//sides)/max(1,rows-1)
  for bn,w in fn(t).items():
   if w>0:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([vi],w,'REPLACE')

def fixed_weights(ob,ws):
 ob.vertex_groups.clear()
 for bn,w in ws.items():
  if w>0:ob.vertex_groups.new(name=bn).add(list(range(len(ob.data.vertices))),w,'REPLACE')

def stud(name,p,bn,r=.0045):
 ellipse(name,p,(r,r*.6,r),edge,bn,10,6)

def orbit_relic(name,c,r,bn,back=False):
 c=Vector(c);face=1 if back else -1
 ring(name+' suspension ring',c,r,r,edge,bn,.005)
 ring(name+' inner bronze orbit',c+Vector((0,face*.003,0)),r*.78,r*.78,gold,bn,.0025)
 ellipse(name+' dense black core',c+Vector((0,-face*.008,0)),(r*.57,r*.33,r*.57),void,bn,28,18)
 # The outer filaments are broken arcs, not a bright solid disc.
 for a0 in [.2,3.4]:
  tube(name+' lensing arc',[(c.x+r*.69*sin(a),c.y+face*.010,c.z+r*.69*cos(a)) for a in np.linspace(a0,a0+1.7,30)],.0018,fire,bn,6)
 for k in range(4):
  a=k*pi/2
  tube(name+' index',[(c.x+r*.93*sin(a),c.y,c.z+r*.93*cos(a)),(c.x+r*1.19*sin(a),c.y,c.z+r*1.19*cos(a))],.003,gold,bn,6)
 stud(name+' pinpoint',(c.x,c.y+face*r*.34,c.z),bn,.0025)

# Lean continuous body under fitted articulated plates.
def torso_fn(u,v):
 a=u*2*pi;z=1.025+v*.56
 w=float(np.interp(v,[0,.24,.62,.82,1],[.211,.179,.244,.267,.171]))
 d=float(np.interp(v,[0,.28,.66,.85,1],[.14,.121,.157,.151,.114]))
 return(w*sin(a),d*cos(a),z)
surface('Fitted charcoal arming coat',torso_fn,48,26,leather,body_weight)
# Deliberate overlapping chevrons create the rib-cage armor silhouette.
for side,s in [('L',1),('R',-1)]:
 for j in range(5):
  z=1.14+j*.066;x0=.021;x1=.178+j*.011
  outline=[(s*x0,-.150,z+.025),(s*(x1-.022),-.132,z+.064),(s*x1,-.137,z+.027),(s*(x1-.016),-.15,z-.020),(s*.048,-.168,z-.044)]
  plate('Articulated thorax '+side+str(j),outline,armor,'chest' if j>2 else 'spine',.009,True)
 # Large clavicular shield, separate from the shoulder blade clusters.
 plate('Pectoral shield '+side,[(s*.024,-.171,1.463),(s*.16,-.143,1.565),(s*.24,-.112,1.536),(s*.212,-.155,1.431),(s*.08,-.184,1.397)],armor,'chest',.012,True)
 # Narrow violet inset traces class color without turning the cuirass into a lamp.
 tube('Clavicular amethyst inlay',[(s*.05,-.179,1.471),(s*.145,-.155,1.54),(s*.194,-.135,1.527)],.003,fire,'chest',6)
 for j in range(5):
  z=1.15+j*.069;stud('Thorax rivet',(s*(.159+j*.01),-.159,z+.01),'chest' if j>2 else 'spine',.0038)
# Central sword-shaped chest keel.
plate('Sternum gravity keel',[(0,-.182,1.54),(.03,-.177,1.472),(.024,-.186,1.38),(0,-.185,1.324),(-.024,-.186,1.38),(-.03,-.177,1.472)],maskmat,'chest',.012,True)
tube('Sternum gravity fissure',[(0,-.199,1.501),(0,-.208,1.416),(0,-.198,1.365)],.0028,fire,'chest',6)
# Flexible throat and cowl, completely covered.
ellipse('Covered throat',(0,0,1.625),(.075,.070,.050),lining,'neck')

for side,s in [('L',1),('R',-1)]:
 def leg_fn(u,v):
  z=.14+.90*v;a=2*pi*u;r=float(np.interp(v,[0,.25,.48,.7,1],[.063,.078,.077,.103,.111]))
  return(s*.145+r*sin(a),r*.88*cos(a),z)
 def lw(u,v,p):
  t=max(0,min(1,(p[2]-.50)/.14));return {'shin.'+side:1-t,'thigh.'+side:t}
 surface('Tailored leg '+side,leg_fn,28,28,leather,lw)
 def boot_fn(u,v):
  a=2*pi*u;rx=float(np.interp(v,[0,.14,.5,1],[.073,.082,.078,.061]));ry=float(np.interp(v,[0,.14,.5,1],[.168,.186,.172,.074]));cy=-.069*(1-v)
  return(s*.145+rx*sin(a),cy+ry*cos(a),.023+.18*v)
 surface('Flat soled leather boot '+side,boot_fn,36,14,leather,{'foot.'+side:1})
 tube('Boot metal welt '+side,[boot_fn(u,.07) for u in np.linspace(0,1,70)],.004,edge,'foot.'+side,6)
 # Curved instep plates follow the boot surface and expose layered joints.
 for j in range(4):
  y=-.206+j*.054;z=.09+j*.021
  plate('Overlapping sabaton '+side+str(j),[(s*.145-.061,y-.024,z),(s*.145+.061,y-.024,z),(s*.145+.067,y+.026,z+.010),(s*.145,y+.039,z+.043),(s*.145-.067,y+.026,z+.010)],armor,'foot.'+side,.010,True)
 # Long pointed greave and knee shield, with separate lames below the knee.
 for j in range(4):
  z=.24+j*.069;w=.065+(j*.002)
  outline=[(s*.145,-.103,z+.075),(s*.145+w,-.057,z+.025),(s*.145+w*.78,-.069,z-.035),(s*.145,-.115,z-.055),(s*.145-w*.78,-.069,z-.035),(s*.145-w,-.057,z+.025)]
  plate('Greave overlapping lame '+side+str(j),outline,armor,'shin.'+side,.014,True)
 plate('Pointed poleyn '+side,[(s*.145,-.116,.676),(s*.145+.086,-.077,.590),(s*.145+.07,-.085,.541),(s*.145,-.133,.505),(s*.145-.07,-.085,.541),(s*.145-.086,-.077,.590)],maskmat,'shin.'+side,.022,True)
 # Thigh pieces are lateral, leaving the front split coat free to move.
 for j in range(3):
  z=.76+j*.073;cx=s*.167
  plate('Thigh armor scale '+side+str(j),[(cx-s*.075,-.092,z+.07),(cx+s*.073,-.065,z+.043),(cx+s*.082,-.075,z-.025),(cx,-.125,z-.060),(cx-s*.071,-.108,z-.011)],armor,'thigh.'+side,.009,False)
 # Two-bone smooth sleeves under elbow/forearm plates.
 def arm_fn(u,v):
  z=.95+.58*v;x=s*float(np.interp(v,[0,.46,1],[.47,.43,.31]));r=float(np.interp(v,[0,.45,.75,1],[.051,.071,.084,.104]));a=2*pi*u
  return(x+r*sin(a),-.018+r*cos(a),z)
 def aw(u,v,p):
  t=max(0,min(1,(p[2]-1.17)/.10));return {'forearm.'+side:1-t,'upper_arm.'+side:t}
 surface('Fitted gambeson sleeve '+side,arm_fn,28,26,leather,aw)
 # Circumferential straps and embossed buckles.
 for z,cx,bn in [(1.035,s*.46,'forearm.'+side),(1.17,s*.437,'forearm.'+side),(1.31,s*.393,'upper_arm.'+side)]:
  tube('Arm leather restraint',[(cx+.074*sin(a),-.019+.071*cos(a),z) for a in np.linspace(0,2*pi,48)],.009,leather,bn)
  plate('Restraint buckle',[(cx-.018,-.095,z+.014),(cx+.018,-.095,z+.014),(cx+.018,-.095,z-.014),(cx-.018,-.095,z-.014)],gold,bn,.001,False)
 for j in range(3):
  z=1.029+j*.066;cx=s*(.466-j*.010)
  plate('Vambrace lance plate '+side+str(j),[(cx,-.097,z+.11),(cx+.061,-.055,z+.031),(cx+.05,-.077,z-.02),(cx,-.119,z-.046),(cx-.05,-.077,z-.02),(cx-.061,-.055,z+.031)],armor,'forearm.'+side,.016,True)
 tube('Vambrace violet hairline',[(s*.463,-.126,1.027),(s*.458,-.134,1.096),(s*.447,-.118,1.163)],.002,fire,'forearm.'+side,6)
 # Full glove and five individually skinned fingers.
 ellipse('Gloved palm '+side,(s*.477,-.035,.888),(.051,.034,.073),leather,'hand.'+side)
 plate('Dorsal gauntlet '+side,[(s*.477,-.071,.952),(s*(.477+.047),-.058,.894),(s*(.477+.038),-.068,.854),(s*.477,-.078,.846),(s*(.477-.038),-.068,.854),(s*(.477-.047),-.058,.894)],armor,'hand.'+side,.007,True)
 for i in range(4):
  x=s*(.44+i*.023);length=[.088,.108,.10,.077][i]
  pts=[(x,-.035-.046*t*t,.854-length*t) for t in np.linspace(0,1,10)]
  tube('Finger glove '+side+str(i),pts,lambda t:.0118*(1-.35*t),leather,'finger%d.%s'%(i,side),10)
  for t in [.12,.45,.75]:
   p=Vector((x,-.045-.046*t*t,.854-length*t))
   ellipse('Finger armored joint',p,(.011,.009,.013),armor,'finger%d.%s'%(i,side),12,8)
  stud('Knuckle rivet',(x,-.070,.851),'hand.'+side,.004)
 tube('Opposable thumb '+side,[(s*(.431-.032*t),-.035-.052*t,.915-.07*t) for t in np.linspace(0,1,10)],lambda t:.015-.005*t,leather,'finger4.'+side,10)
 # Irregular layered blade pauldrons. Each shield has surface curvature and a pointed tip.
 for j in range(3):
  for k in range(3):
   y=-.104+k*.105;cx=s*(.321+j*.061);cz=1.56-j*.061
   tip=s*(.465+j*.047+(0.025 if side=='R' else 0))
   outline=[(cx-s*.09,y-.012,cz+.060),(cx+s*.044,y-.032,cz+.034),(tip,y-.010,cz-.100-j*.025),(cx+s*.035,y+.075,cz-.039),(cx-s*.06,y+.091,cz+.026)]
   plate('Riven pauldron blade '+side+str(j)+str(k),outline,armor if j!=1 else maskmat,'upper_arm.'+side,(0,0,.022),True)
   stud('Pauldron pin',(cx,y-.03,cz+.03),'upper_arm.'+side,.0042)
 # Thin violet inset on the top cap, mostly hidden by interlocking blades.
 tube('Shoulder broken violet seam',[(s*.28,-.135,1.606),(s*.35,-.140,1.586),(s*.409,-.124,1.554)],.0027,fire,'upper_arm.'+side,6)
 tube('Team shoulder stitch',[(s*.287,-.147,1.58),(s*.325,-.155,1.557)],.0034,team,'upper_arm.'+side,6)

# Ten independently weighted split coat gores; front legs remain visible.
robe_functions={}
def robe_weights(v,i):
 t=max(0,min(1,(v-.35)/.4));top=max(0,(v-.85)/.15)
 return {'hem%d'%i:1-t,'robe%d'%i:t*(1-top),'pelvis':t*top}
for i in range(10):
 a0=2*pi*i/10;span=.61 if i not in [4,5,6] else (.21 if i==5 else .38)
 def robe_fn(u,v,i=i,a0=a0,span=span):
  t=1-v;a=a0+(u-.5)*span;radius=.225+.159*t+.014*sin(u*pi*5+i)*t
  # Deep, asymmetric tips and torn contours are geometry rather than transparency.
  short=.25 if i==5 else (.09 if i in [4,6] else 0)
  tear=(.015*sin(u*24+i)+.009*sin(u*43+i*.7))*(t**9)
  z=1.055-(.91-short)*t+(.085*abs(2*u-1)+tear)*t*t
  return(radius*sin(a),radius*.75*cos(a)+.05*t*t*max(0,cos(a)),z)
 robe_functions[i]=robe_fn
 ob=surface('Split coat gore %02d'%i,robe_fn,24,28,darkcloth if i%3 else cloth,lambda u,v,p,i=i:robe_weights(v,i))
 for uu in [.025,.975]:
  ob=tube('Frayed coat binding',[robe_fn(uu,v) for v in np.linspace(0,1,42)],.003,gold,'pelvis',6)
  rows_weight(ob,42,6,lambda v,i=i:robe_weights(v,i))
 # Sparse long ribs reinforce the armored coat without filling every panel with stars.
 if i in [1,3,7,9]:
  for j in range(4):
   v=.51+j*.105;c=Vector(robe_fn(.5,v));normal=Vector((sin(a0),cos(a0),0))
   outline=[]
   for uu,vv in [(.12,v+.035),(.85,v+.035),(.94,v-.042),(.47,v-.078),(.06,v-.034)]:
    outline.append(tuple(Vector(robe_fn(uu,vv))+normal*.008))
   pl=plate('Coat segmented armor',outline,armor,'pelvis',.004,False);fixed_weights(pl,robe_weights(v,i))
# Two long narrow violet stoles run from clavicles down either side of the open front.
for side,s in [('L',1),('R',-1)]:
 i=4 if s>0 else 6
 def stole_fn(u,v,s=s):
  t=1-v;cx=s*(.11+.13*t);w=.077-.01*t
  return(cx+(u-.5)*w,-.162-.107*t-.008*sin(u*pi*4)*sin(pi*t),1.52-1.36*t+.085*abs(2*u-1)*t*t+.018*sin(u*25)*t**8)
 def sw(v,i=i):
  z=1.52-1.36*(1-v)
  if z>=1.17:return {'chest':1}
  if z>=1.04:return {'pelvis':(1.17-z)/.13,'chest':(z-1.04)/.13}
  return robe_weights(max(0,min(1,(z-.15)/.90)),i)
 surface('Violet heretic stole '+side,stole_fn,16,44,cloth,lambda u,v,p:sw(v))
 for uu in [.04,.96]:
  ob=tube('Stole weathered binding',[stole_fn(uu,v) for v in np.linspace(0,1,60)],.0026,edge,'pelvis',6);rows_weight(ob,60,6,sw)
 # A handful of punctures/loose thread ends near the lower tips.
 for j in range(6):
  u=.15+j*.13;p=Vector(stole_fn(u,.015));ob=tube('Stole loose thread',[p,p+Vector((.004*sin(j),0,-.014-.007*(j%3)))],.0009,darkcloth,'hem%d'%i,5)

# Belts, square buckles and gravity pendants distinguish this from celestial mage jewelry.
surface('Wide utility waist belt',lambda u,v:(.228*sin(u*2*pi),.165*cos(u*2*pi),1.014+v*.077),48,5,leather,{'pelvis':1})
for z in [1.022,1.084]:tube('Belt welt',[(.232*sin(a),.169*cos(a),z) for a in np.linspace(0,2*pi,70)],.004,gold,'pelvis',6)
plate('Rectangular waist buckle',[(-.053,-.181,1.095),(.044,-.181,1.095),(.044,-.181,1.035),(-.053,-.181,1.035)],edge,'pelvis',.001,False)
plate('Buckle inset',[(-.035,-.193,1.082),(.026,-.193,1.082),(.026,-.193,1.048),(-.035,-.193,1.048)],leather,'pelvis',.001,False)
tube('Buckle tongue',[(-.004,-.201,1.042),(-.004,-.201,1.09)],.004,gold,'pelvis',6)
for s in [-1,1]:
 for j in range(3):stud('Belt iron rivet',(s*(.080+j*.031),-.172,1.056),'pelvis',.0038)
# Belt relic at one hip and a second suspended on its skinned coat panel.
orbit_relic('Hip counterweight',(.163,-.176,.995),.055,'pelvis')
tube('Relic suspension strap',[(.163,-.17,1.06),(.17,-.19,1.008)],.006,leather,'pelvis',8)
i=6;fn=robe_functions[i];c=Vector(fn(.5,.42));c.y-=.014
before=len(parts);orbit_relic('Hanging void weight',c,.043,'robe6')
for ob in parts[before:]:fixed_weights(ob,robe_weights(.42,6))
ob=tube('Void weight tether',[Vector(fn(.5,v))+Vector((0,-.015,0)) for v in np.linspace(.47,.75,30)],.003,edge,'robe6',6)
rows_weight(ob,30,6,lambda t:robe_weights(.47+.28*t,6))

# Tall hood with real hollow opening, pointed crown and dark interior shell.
def hood_fn(u,v):
 a=-2.49+u*4.98
 rx=float(np.interp(v,[0,.2,.50,.74,.91,1],[.186,.213,.199,.148,.075,.002]))
 ry=float(np.interp(v,[0,.3,.65,.88,1],[.163,.19,.162,.085,.001]))
 fold=.007*sin(a*13+v*9)*sin(pi*v)**2
 return((rx+fold)*sin(a),.025+(ry+fold)*cos(a)-.055*max(0,-cos(a))**4*sin(pi*v),1.535+.519*v+.014*cos(a*3)*sin(pi*v))
hood=surface('Pointed heretic hood',hood_fn,56,34,darkcloth,{'head':1});hood.data.materials.append(lining)
bpy.ops.object.select_all(action='DESELECT');hood.select_set(True);bpy.context.view_layer.objects.active=hood
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.flip_normals();bpy.ops.object.mode_set(mode='OBJECT')
m=hood.modifiers.new('Dark lined hood thickness','SOLIDIFY');m.thickness=.006;m.offset=-1;m.material_offset=1;m.material_offset_rim=1;bpy.ops.object.modifier_apply(modifier=m.name)
for uu in [0,1]:
 tube('Hood weathered leather edge',[hood_fn(uu,v) for v in np.linspace(0,1,65)],.0056,leather,'head',8)
 tube('Hood fine bronze seam',[Vector(hood_fn(uu,v))+Vector((0,-.006,0)) for v in np.linspace(0,1,65)],.0022,gold,'head',6)
 for j in range(8):
  v=.10+j*.102;p=Vector(hood_fn(uu,v));p.y-=.005
  tube('Hood seam stitch',[p+Vector((-.003,0,-.004)),p+Vector((.003,0,.004))],.0011,edge,'head',5)
# Violet band cut on the crown flanks, kept outside the sealed mask.
for side,s in [('L',1),('R',-1)]:
 uc=.06 if s<0 else .94
 def bias_fn(u,v,uc=uc):
  hu=uc+(u-.5)*.055;hv=.12+.87*v;a=-2.49+hu*4.98
  return Vector(hood_fn(hu,hv))+Vector((sin(a),cos(a),0))*.005
 surface('Hood violet bias '+side,bias_fn,8,28,cloth,{'head':1})
for j in range(5):
 pts=[(.184*sin(a),.150*cos(a)-.009,1.577-j*.020+.028*cos(a)+.01*sin(2*a+j*.3)) for a in np.linspace(0,2*pi,70)]
 tube('Heavy wrapped throat cowl',pts,.017,darkcloth if j%2 else cloth,'head',10)
# A solid metal mask, long angular proportions; no eyeballs or facial anatomy behind it.
mask_outline=[(0,-.124,1.995),(.080,-.113,1.938),(.097,-.105,1.849),(.064,-.114,1.739),(0,-.143,1.661),(-.064,-.114,1.739),(-.097,-.105,1.849),(-.080,-.113,1.938)]
plate('Sealed angular mask',mask_outline,maskmat,'head',.045,True)
# Complete the mask with closed sides/back that extend into the hood.
back_outline=[(x*.91,.056,z) for x,y,z in mask_outline]
vs=mask_outline+back_outline+[(0,.081,1.825)];n=len(mask_outline)
fs=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]+[(n+i,n+(i+1)%n,2*n) for i in range(n)]
mesh('Closed mask side shell',vs,fs,maskmat,{'head':1})
# Beveled cheek planes resemble forged facets rather than human facial features.
for s in [-1,1]:
 plate('Mask lateral forged plane',[(s*.010,-.166,1.931),(s*.076,-.127,1.909),(s*.079,-.125,1.833),(s*.013,-.178,1.774)],armor,'head',.003,False)
 plate('Mask tapered lower facet',[(s*.013,-.179,1.774),(s*.072,-.126,1.814),(s*.051,-.137,1.73),(s*.007,-.158,1.681)],maskmat,'head',.007,False)
 tube('Mask broken transverse seam',[(s*.018,-.187,1.822),(s*.046,-.162,1.851),(s*.074,-.132,1.864)],.0018,fire,'head',6)
# The narrow violet gravity fault is a mechanical seam, with an intentional kink.
tube('Mask axial gravity fracture',[(0,-.134,1.978),(.002,-.171,1.924),(-.002,-.191,1.85),(.006,-.193,1.802),(0,-.174,1.724),(0,-.153,1.685)],.0027,fire,'head',8)
plate('Mask central black blade',[(.007,-.193,1.83),(.023,-.174,1.765),(.006,-.165,1.684),(.002,-.181,1.757)],maskmat,'head',.002,False)

# Three split, ragged mantle tails with real missing patches and delayed bone motion.
def mantle_weights(v,i):
 if v>.77:return {'chest':(v-.77)/.23,'mantle%d'%i:1-(v-.77)/.23}
 t=max(0,min(1,(v-.23)/.43));return {'mantle%d'%i:t,'mantle_tip%d'%i:1-t}
for i in range(3):
 def mantle_fn(u,v,i=i):
  t=1-v;spread=.176+.147*t
  x=((i-1)+(u-.5)*1.13)*spread+.019*sin(t*6+i)*t
  y=.182+.250*t+.024*sin(u*pi*4+i)*sin(pi*t)
  rag=.024*sin(u*19+i)+.015*sin(u*41+i*.4)
  z=1.515-1.34*t+(.10*abs(2*u-1)+rag)*t**7+(.06 if i==1 else 0)*t
  return(x,y,z)
 nu=28;nv=42;vs=[];ws=[];uvs=[];fs=[]
 for j in range(nv+1):
  for k in range(nu+1):
   u=k/nu;v=j/nv;vs.append(mantle_fn(u,v));ws.append(mantle_weights(v,i));uvs.append((u,v))
 holes=[(.19,.18,.055,.07),(.74,.34,.043,.064),(.45,.09,.055,.037),(.88,.62,.025,.036)]
 for j in range(nv):
  for k in range(nu):
   u=(k+.5)/nu;v=(j+.5)/nv
   torn=any(((u-hu)/rx)**2+((v-hv)/ry)**2<1 for hu,hv,rx,ry in holes)
   if not torn:
    a=j*(nu+1)+k;fs.append((a,a+1,a+nu+2,a+nu+1))
 # Project internal hole boundaries onto ragged tear contours to avoid square grid edges.
 from collections import Counter
 counts=Counter(tuple(sorted((f[k],f[(k+1)%4]))) for f in fs for k in range(4))
 boundary={idx for e,count in counts.items() if count==1 for idx in e}
 for idx in boundary:
  u,v=uvs[idx]
  if min(u,v,1-u,1-v)<.0001:continue
  hu,hv,rx,ry=min(holes,key=lambda h:((u-h[0])/h[2])**2+((v-h[1])/h[3])**2)
  a=math.atan2((v-hv)/ry,(u-hu)/rx);r=1+.13*sin(a*7+i)
  u=hu+rx*cos(a)*r;v=hv+ry*sin(a)*r
  vs[idx]=mantle_fn(u,v);uvs[idx]=(u,v);ws[idx]=mantle_weights(v,i)
 ob=mesh('Torn mantle tail '+str(i),vs,fs,cloth if i==1 else darkcloth,ws,uvs)
 for uu in [.015,.985]:
  ob=tube('Mantle old bronze binding',[mantle_fn(uu,v) for v in np.linspace(0,1,58)],.0024,gold,'chest',6);rows_weight(ob,58,6,lambda v,i=i:mantle_weights(v,i))
 # Sparse ladder stitching, a vertical stripe and ragged thread ends.
 if i==1:
  for j in range(8):
   v=.3+j*.076;p=Vector(mantle_fn(.5,v))+Vector((0,.006,0))
   before=len(parts);ring('Back mantle gravity mark',p,.024,.026,gold,'mantle1',.0017)
   tube('Back mantle gravity axis',[p+Vector((0,0,-.039)),p+Vector((0,0,.038))],.0015,edge,'mantle1',6)
   for ob in parts[before:]:fixed_weights(ob,mantle_weights(v,i))
 for j in range(10):
  u=.06+j*.096;p=Vector(mantle_fn(u,0));ob=tube('Mantle thread',[p,p+Vector((.008*sin(j),.008,-.015-.006*(j%4)))],.0009,darkcloth,'mantle_tip%d'%i,5)
# Back machine: compact orbital harness rather than a halo around the head.
orbit_relic('Back gravity regulator',(0,.219,1.439),.111,'chest',True)
for s in [-1,1]:
 tube('Regulator leather shoulder strap',[(s*.078,.196,1.48),(s*.172,.141,1.546),(s*.198,.015,1.573),(s*.184,-.113,1.521)],.018,leather,'chest',10)
 for j in range(3):
  z=1.37-j*.046;stud('Back harness pin',(s*.066,.229,z),'chest',.004)
# Engraved orbit arcs on selected armor plates and a few impact scratches.
for side,s in [('L',1),('R',-1)]:
 for j in range(3):
  x=s*(.300+j*.031);z=1.594-j*.034
  tube('Pauldron concentric engraving',[(x+.024*sin(a),-.146,z+.018*cos(a)) for a in np.linspace(.5,4.5,30)],.0014,gold,'upper_arm.'+side,5)

