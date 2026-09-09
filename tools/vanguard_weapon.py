"""Forged resolve hammer, built in haft-local coordinates then rigidly bound to weapon."""
weapon_start=len(parts)
def hammer_box(name,c,size,material,bevel=.009):
 x,y,z=c;w,d,h=[s/2 for s in size]
 return plate(name,[(x-w,y-d,z-h),(x+w,y-d,z-h),(x+w,y-d,z+h),(x-w,y-d,z+h)],d*2,material,'weapon',bevel)

# Metal skeleton around a recessed violet heart; broad steel striking faces.
hammer_box('Hammer load bearing core',(0,0,0),(.52,.27,.33),steel,.018)
for s in [-1,1]:
 hammer_box('Hammer forged striking cap',(s*.274,0,0),(.104,.326,.391),steel,.018)
 hammer_box('Hammer cap alloy collar',(s*.217,0,0),(.032,.306,.367),edge,.005)
 for y in [-.154,.154]:
  hammer_box('Hammer inset fractured crystal',(s*.113,y,0),(.151,.018,.249),crystal,.009)
  for z in [-.150,.150]:hammer_box('Hammer crystal protective rail',(s*.11,y,z),(.19,.044,.046),steel,.005)
  for x in [s*.032,s*.191]:hammer_box('Hammer crystal retaining stile',(x,y,0),(.024,.040,.28),edge,.004)
  for x in [s*.027,s*.199]:
   for z in [-.145,.145]:ellipse('Hammer peened rivet',(x,y*1.17,z),(.009,.006,.009),edge,'weapon',8,6)
 # Closed striking ends feature a metal reinforcing cross, no projecting crystal spikes.
 for z in [-.10,.10]:hammer_box('Striking face band',(s*.332,0,z),(.012,.27,.035),edge,.003)
for y in [-.191,.191]:
 ellipse('Hammer bearing socket',(0,y,0),(.085,.022,.085),steel,'weapon',24,12)
 ring('Hammer alloy bearing',(0,y*1.12,0),.063,.063,edge,'weapon',.007)
 ellipse('Hammer resolve core lens',(0,y*1.14,0),(.045,.009,.045),crystal,'weapon',24,12)
 star_glyph((0,y*1.21,0),.045,'weapon')
tube('Hammer continuous metal haft',[(0,0,-1.25),(0,0,.23)],.033,steel,'weapon',16)
for z in [-1.20,-1.12,-.82,-.48,-.28,-.20,.21]:
 tube('Haft locking ferrule',[(0,0,z-.015),(0,0,z+.015)],.047,edge,'weapon',16)
for lo,hi in [(-1.11,-.84),(-.80,-.49)]:
 tube('Leather bound hammer grip',[(0,0,lo),(0,0,hi)],.040,leather,'weapon',16)
 turns=8;points=[(.041*cos(t*turns*2*pi),.041*sin(t*turns*2*pi),lo+t*(hi-lo)) for t in np.linspace(0,1,120)]
 tube('Raised grip winding',points,.0025,edge,'weapon',5)
ellipse('Hammer pommel',(0,0,-1.25),(.053,.053,.058),steel,'weapon',20,12)
hammer_box('Hammer neck armor',(0,0,-.27),(.11,.11,.14),steel,.008)
for s in [-1,1]:
 tube('Hammer neck buttress',[(s*.11,0,-.16),(s*.065,0,-.24),(s*.05,0,-.35)],.017,edge,'weapon',8)
weapon_rotation=Vector((0,0,1)).rotation_difference(WD).to_matrix().to_4x4()
for ob in parts[weapon_start:]:ob.data.transform(Matrix.Translation(WH)@weapon_rotation)
