"""Crystal war helm, tabard, cape and armor detail for the current Vanguard reference."""
def reassigned(ob,weights):
 ob.vertex_groups.clear()
 for bn,w in weights.items():
  if w>0:ob.vertex_groups.new(name=bn).add(list(range(len(ob.data.vertices))),w,'REPLACE')
def row_weights(ob,count,sides,fn):
 ob.vertex_groups.clear()
 for vi in range(len(ob.data.vertices)):
  v=(vi//sides)/(count-1)
  for bn,w in fn(v).items():
   if w>0:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([vi],w,'REPLACE')
def star_glyph(c,r,bn,material=edge):
 c=Vector(c);pts=[c+Vector((r*sin(k*pi/4)*(1 if k%2==0 else .21),0,r*cos(k*pi/4)*(1 if k%2==0 else .21))) for k in range(9)]
 return tube('Eight pointed celestial compass',pts,.0024,material,bn,6)
def cloth_weights(v,i):
 t=max(0,min(1,(v-.25)/.50));top=max(0,min(1,(v-.9)/.1))
 return {'hem%d'%i:1-t,'tabard%d'%i:t*(1-top),'pelvis':t*top}
# A long center tabard and two shorter side strips expose the articulated legs.
for i in range(3):
 def tab(u,v,i=i):
  t=1-v;length=.76 if i==1 else .63;cx=(i-1)*.115;width=.23 if i==1 else .093
  return(cx+(u-.5)*width,-.235-.035*t-.009*sin(u*pi*5)*sin(pi*t),1.075-length*t+.065*abs(2*u-1)*t*t)
 surface('Astral war tabard '+str(i),tab,16,30,cloth,lambda u,v,p,i=i:cloth_weights(v,i))
 for uu in [.06,.94]:
  ob=tube('Tabard double gold binding',[tab(uu,v) for v in np.linspace(0,1,42)],.0035,edge,'pelvis',6);row_weights(ob,42,6,lambda v,i=i:cloth_weights(v,i))
 if i==1:
  for v,r in [(.24,.053),(.59,.075)]:
   c=Vector(tab(.5,v))+Vector((0,-.006,0));start=len(parts);ring('Tabard compass ring',c,r*.65,r*.65,edge,'tabard1',.0022);star_glyph(c,r,'tabard1')
   for ob in parts[start:]:reassigned(ob,cloth_weights(v,i))
  ob=tube('Tabard longitudinal axis',[Vector(tab(.5,v))+Vector((0,-.005,0)) for v in np.linspace(.10,.94,45)],.0015,edge,'pelvis',5);row_weights(ob,45,5,lambda t:cloth_weights(.10+.84*t,i))
# Full navy cape divided into three softly overlapping animated panels.
def cape_weights(v,i):
 if v>.79:return {'chest':(v-.79)/.21,'cape%d'%i:1-(v-.79)/.21}
 t=max(0,min(1,(v-.25)/.42));return {'cape%d'%i:t,'cape_tip%d'%i:1-t}
for i in range(3):
 def cape(u,v,i=i):
  t=1-v;width=.185+.065*t;x=((i-1)+(u-.5)*1.10)*width
  return(x,.225+.245*t+.019*sin(u*pi*5+i)*sin(pi*t),1.73-1.53*t+.10*abs(2*u-1)*t*t)
 surface('Oathkeeper cape '+str(i),cape,18,36,cloth,lambda u,v,p,i=i:cape_weights(v,i))
 for uu in [.045,.955]:
  ob=tube('Cape alloy thread border',[cape(uu,v) for v in np.linspace(0,1,48)],.0038,edge,'chest',6);row_weights(ob,48,6,lambda v,i=i:cape_weights(v,i))
 if i==1:
  for v,r in [(.19,.069),(.48,.107),(.81,.050)]:
   c=Vector(cape(.5,v))+Vector((0,.006,0));start=len(parts);ring('Cape oath compass',c,r*.65,r*.65,edge,'cape1',.0024);star_glyph(c,r,'cape1')
   for ob in parts[start:]:reassigned(ob,cape_weights(v,i))
  ob=tube('Cape oath axis',[Vector(cape(.5,v))+Vector((0,.006,0)) for v in np.linspace(.07,.94,60)],.0018,edge,'chest',6);row_weights(ob,60,6,lambda t:cape_weights(.07+.87*t,i))
 for j in range(9):
  v=.13+j*.082;p=Vector(cape(.18 if i==0 else .82,v))+Vector((0,.007,0));ob=star_glyph(p,.012,'cape%d'%i);reassigned(ob,cape_weights(v,i))
# Thick rear collar and shoulder-clasps suspend the cape physically.
for s in [-1,1]:
 plate('Cape anchor clasp',[(s*.14,.237,1.765),(s*.28,.19,1.74),(s*.26,.235,1.645),(s*.14,.25,1.67)],-.022,edge,'chest',.006)
 bolts('Cape clasp rivets',[(s*.18,.255,1.70),(s*.22,.238,1.737)],'chest')
# Closed, ridged helmet with a continuous violet T opening and crystal crown.
ellipse('Flexible armored neck seal',(0,.01,1.842),(.102,.093,.105),leather,'neck',28,16)
def helm(u,v):
 a=2*pi*u;rx=float(np.interp(v,[0,.2,.55,.80,1],[.087,.135,.147,.12,.006]));ry=float(np.interp(v,[0,.25,.65,.83,1],[.090,.13,.144,.112,.006]))
 return(rx*sin(a),.014+ry*cos(a),1.86+.383*v+.011*cos(a*4)*sin(pi*v))
surface('Fully enclosed war helmet',helm,48,28,steel,{'head':1})
plate('T visor dark inset',[(-.139,-.115,2.124),(0,-.196,2.083),(.139,-.115,2.124),(.123,-.147,2.039),(.023,-.205,2.026),(0,-.209,1.886),(-.023,-.205,2.026),(-.123,-.147,2.039)],.014,void,'head',.002)
for s in [-1,1]:
 plate('Swept reinforced helm brow',[(0,-.203,2.137),(s*.077,-.163,2.182),(s*.147,-.093,2.155),(s*.153,-.113,2.107),(s*.035,-.202,2.064)],.026,steel,'head',.007)
 trimline('Brow alloy blade',[(0,-.211,2.130),(s*.085,-.167,2.17),(s*.142,-.111,2.142)],'head',.004)
 plate('Beveled helmet cheek',[(s*.032,-.208,2.044),(s*.134,-.151,2.078),(s*.147,-.09,1.995),(s*.076,-.157,1.899),(s*.009,-.215,1.873)],.028,steel,'head',.007)
 trimline('Helmet cheek edge',[(s*.13,-.155,2.046),(s*.075,-.166,1.911),(s*.014,-.221,1.886)],'head',.004)
 tube('T visor luminous crossbar',[(s*.120,-.166,2.101),(s*.065,-.195,2.077),(0,-.216,2.056)],.0044,visor,'head',8)
 for j in range(3):
  x=s*(.078+j*.015);tube('Helmet vent slit',[(x,-.17+j*.015,1.984),(x+s*.006,-.159+j*.015,2.01)],.0028,void,'head',6)
 bolts('Temple hex bolts',[(s*.131,-.127,2.142),(s*.123,-.142,2.015)],'head')
 for j in range(3):trimline('Layered nape guard',[(s*.124,.085,1.918+j*.047),(s*.056,.148,1.922+j*.047),(0,.157,1.926+j*.047)],'head',.006)
tube('T visor vertical seam',[(0,-.216,2.057),(0,-.226,1.974),(0,-.218,1.895)],.0037,visor,'head',8)
# Crystal protrudes from an angular metal crown socket, matching the reference.
for s in [-1,1]:
 plate('Crown crystal retaining blade',[(s*.012,-.16,2.16),(s*.073,-.10,2.265),(s*.061,-.015,2.295),(s*.015,-.049,2.227)],.03,edge,'head',.004)
shard('Central crystal crown',(0,-.031,2.18),(0,-.004,2.405),.050,'head')
for s in [-1,1]:shard('Lateral crown crystal',(s*.054,.011,2.198),(s*.083,.021,2.331),.030,'head')
# Additional contoured metal lames on the shoulder fronts with recessed crystal apertures.
for side,s in [('L',1),('R',-1)]:
 bn='upper_arm.'+side
 for j in range(2):
  x=s*(.407+j*.060);z=1.822-j*.076
  outline=[(x-s*.122,-.174,z+.075),(x+s*.066,-.17,z+.040),(x+s*.134,-.135,z-.074),(x+s*.039,-.205,z-.101),(x-s*.087,-.221,z-.036)]
  plate('Reinforced pauldron face '+side+str(j),outline,.027,steel,bn,.007)
  trimline('Pauldron heavy alloy rim',[(xx,yy-.008,zz) for xx,yy,zz in outline]+[Vector(outline[0])+Vector((0,-.008,0))],bn,.0045)
  shard('Pauldron crystal window '+side+str(j),(x,-.234,z-.057),(x+s*.020,-.239,z+.041),.035,bn)
 # Side rib bearings and overlapping belly connection hardware.
 for z,r in [(1.445,.068),(1.22,.059)]:
  c=(s*(.262 if z>1.3 else .233),-.175,z)
  ellipse('Circular armored bearing',c,(r,.035,r),leather,'chest' if z>1.3 else 'spine',24,12)
  ring('Bearing alloy retainer',(c[0],c[1]-.028,c[2]),r*.83,r*.83,edge,'chest' if z>1.3 else 'spine',.005)
  ring('Bearing inner race',(c[0],c[1]-.035,c[2]),r*.55,r*.55,steel,'chest' if z>1.3 else 'spine',.006)
 # Bracer dorsal plates follow the original resting forearm frame.
 b=ad.bones['forearm.'+side];axis=(b.tail_local-b.head_local).normalized();front=Vector((0,-1,0));front=(front-axis*front.dot(axis)).normalized();sideaxis=axis.cross(front).normalized()
 for j in range(3):
  c=b.head_local.lerp(b.tail_local,.22+j*.21)+front*.104
  outline=[c+sideaxis*.073-axis*.044,c+sideaxis*.056+axis*.05,c-axis*.0+axis*.077,c-sideaxis*.056+axis*.05,c-sideaxis*.073-axis*.044]
  plate('Layered gauntlet dorsal armor',outline,.012,steel,'forearm.'+side,.005)
 # Clear, modest team inlays are separate from the navy cape/tabard palette.
 tube('Team shoulder badge',[(s*.335,-.243,1.823),(s*.363,-.244,1.803),(s*.389,-.235,1.815)],.0032,team,bn,6)
# Large chest resolve crystal, a shallow shield faceted over the existing socket.
outline=[(0,-.297,1.729),(.074,-.268,1.641),(.051,-.277,1.53),(0,-.304,1.472),(-.051,-.277,1.53),(-.074,-.268,1.641)]
center=Vector((0,-.33,1.624));ob=mesh('Resolve core shield crystal',outline+[center],[(i,(i+1)%6,6) for i in range(6)],crystal,{'chest':1})
for p in ob.data.polygons:p.use_smooth=False
trimline('Resolve core heavy setting',[(x,y-.003,z) for x,y,z in outline]+[outline[0]],'chest',.005)
for s in [-1,1]:
 tube('Resolve core clamp',[(s*.051,-.291,1.55),(s*.071,-.279,1.594)],.0065,edge,'chest',8)
