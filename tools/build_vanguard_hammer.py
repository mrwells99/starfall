"""Build the static Vanguard hammer study. Blender 5.x background script.
No combat integration: authored asset and editable source for visual approval.
Run blender -b --python tools/build_vanguard_hammer.py from repository root.
"""
import bpy, math, os
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))

def material(name,color,metal=0,rough=.5,emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    return m
steel=material('Vanguard_DarkForgedSteel',(.13,.15,.19),.8,.38)
edge=material('Vanguard_WornEdges',(.32,.34,.38),.8,.32)
rubber=material('Vanguard_JointLeather',(.025,.028,.037),.05,.82)
trim=material('Vanguard_OldTitanium',(.22,.20,.19),.75,.4)
crystal=material('Vanguard_VioletCrystal',(.32,.018,.68),.25,.25,3)
skin=material('Vanguard_Skin',(.39,.245,.175),0,.65)
hair=material('Vanguard_Hair',(.038,.027,.022),0,.92)
eye=material('Vanguard_Eyes',(.20,.25,.23),0,.4)

def finish(o,name,mat,bevel=0):
    o.name=name;o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Machined radii','BEVEL');mod.width=bevel;mod.segments=3
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    if mat not in (skin,hair,crystal):
        mod=o.modifiers.new('Weighted armor normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def ellipsoid(name,at,size,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=at)
    o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat)

def box(name,at,size,mat,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,bevel)

def link(name,a,b,r,mat,r2=None,vertices=24):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    return finish(o,name,mat,min(.012,r*.1))

def ring(name,at,major,minor,mat,axis=(0,0,1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=28,minor_segments=8,location=at,major_radius=major,minor_radius=minor)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector(axis).to_track_quat('Z','Y')
    return finish(o,name,mat)

def panel(name,at,width,height,depth,mat,lean=0):
    # Curved, raised shield section with a clipped perimeter and real rim.
    outline=[(-.35,-.5),(.35,-.5),(.5,-.28),(.5,.27),(.28,.5),(-.28,.5),(-.5,.27),(-.5,-.28)]
    vertices=[]
    for inset,y in [(1,depth*.45), (1,-depth*.28),(.90,-depth*.58)]:
        for x,z in outline:vertices.append((x*width*inset,y,z*height*inset))
    vertices.append((0,-depth*.88,0)); faces=[]
    for layer in range(2):
        for i in range(8):
            j=(i+1)%8;faces.append((layer*8+i,layer*8+j,(layer+1)*8+j,(layer+1)*8+i))
    for i in range(8):faces.append((16+i,16+(i+1)%8,24))
    faces.append(tuple(reversed(range(8))))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler.y=lean
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    # Consistent outward normals independent of hand-entered ring winding.
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    return finish(o,name,mat,.01)

def shard(name,at,radius,height,tilt=(0,0,0)):
    verts=[]
    for z,scale in [(0,.8),(height*.68,1)]:
        for i in range(6):
            a=i*math.tau/6;verts.append((math.cos(a)*radius*scale,math.sin(a)*radius*scale,z))
    verts.append((radius*.15,0,height));faces=[]
    for i in range(6):
        j=(i+1)%6;faces.extend([(i,j,6+j,6+i),(6+i,6+j,12)])
    faces.append(tuple(reversed(range(6))))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=tilt;o.data.materials.append(crystal)
    return o

# Broad, anatomical under-suit, chest cage, overlapping abdominal armor.
ellipsoid('Torso undersuit',(0,.035,1.38),(.38,.215,.39),rubber)
ellipsoid('Pelvic harness',(0,.025,.98),(.29,.20,.19),rubber)
panel('Cuirass main',(0,-.14,1.51),.73,.46,.23,steel)
for s in [-1,1]:
    panel('Pectoral wing',(s*.21,-.265,1.58),.32,.24,.075,steel,s*-.16)
    panel('Collar ridge',(s*.16,-.20,1.75),.29,.07,.065,edge,s*-.12)
    for i in range(3):panel('Abdominal overlapping lame',(s*.13,-.17,1.27-i*.09),.27,.115,.12,steel,s*.12)
    link('Chest border',(s*.35,-.20,1.68),(s*.31,-.245,1.44),.019,edge)
    for z in [1.68,1.45]:ellipsoid('Cuirass rivet',(s*.29,-.287,z),(.018,.012,.018),trim)
    for i in range(4):
        link('Flexible rib cable',(s*.29,.0,1.42-i*.07),(s*.37,-.10,1.36-i*.07),.025,rubber)
ring('Gorget',(0,0,1.80),.155,.04,steel)
panel('Crystal breast socket',(0,-.29,1.53),.18,.30,.085,edge)
shard('Exposed chest crystal',(0,-.36,1.40),.075,.25,(math.radians(10),0,0))
box('Belt',(0,-.015,1.02),(.62,.35,.10),rubber,.03)
panel('Belt clasp',(0,-.23,1.01),.14,.105,.045,trim)
for s in [-1,1]:
    panel('Hip guard',(s*.29,-.03,.99),.24,.30,.20,steel,s*-.22)
    # Long greaves and substantial sabatons; stance remains within ordinary scale.
    ellipsoid('Thigh undersuit',(s*.235,.02,.80),(.16,.16,.27),rubber)
    panel('Thigh plate',(s*.235,-.12,.81),.30,.40,.16,steel,s*-.07)
    panel('Thigh outer edge',(s*.365,-.02,.80),.085,.35,.10,edge,s*-.16)
    ellipsoid('Knee flex joint',(s*.25,-.015,.57),(.13,.125,.13),rubber)
    ring('Knee bearing',(s*.25,-.148,.58),.08,.016,trim,(0,1,0))
    panel('Knee cap',(s*.25,-.16,.58),.22,.19,.065,steel)
    ellipsoid('Calf',(s*.26,.035,.34),(.12,.14,.23),rubber)
    panel('Shin armor',(s*.26,-.10,.33),.265,.40,.16,steel,s*-.035)
    panel('Shin spine',(s*.26,-.20,.34),.055,.32,.025,edge)
    box('Sabatons',(s*.26,-.085,.095),(.30,.49,.19),steel,.045)
    box('Dark sole',(s*.26,-.085,.027),(.31,.50,.055),rubber,.014)
    for i in range(3):box('Toe articulated band',(s*.26,-.23+i*.075,.165),(.28,.045,.055),edge,.013)
    panel('Greave energy vent',(s*.33,-.175,.34),.035,.17,.015,crystal)

# Arms converge on a shared haft: deliberate two-handed static grip.
shoulders=[(-.48,.0,1.67),(.48,.0,1.67)]
elbows=[(-.55,-.10,1.25),(.54,-.12,1.27)]
hands=[(-.10,-.49,.99),(.07,-.445,1.19)]
for index,s in enumerate([-1,1]):
    shoulder=Vector(shoulders[index]); elbow=Vector(elbows[index]);hand=Vector(hands[index])
    ellipsoid('Deltoid',shoulder,(.21,.21,.22),rubber)
    link('Upper arm',shoulder,elbow,.15,steel,.125)
    for i in range(3):
        center=shoulder+Vector((s*i*.03,0,.05-i*.075))
        ellipsoid('Layered pauldron',center,(.285-i*.01,.28,.14),steel)
        panel('Pauldron front bevel',center+Vector((0,-.21,0)),.48,.105,.065,edge,s*-.15)
    for i in range(3):
        shard('Shoulder crystal crown',shoulder+Vector((s*(i-1)*.12,.03,.15)),.058,.20+(i==1)*.13,(0,s*.18,0))
    ellipsoid('Elbow joint',elbow,(.13,.13,.13),rubber)
    ring('Elbow bearing',elbow+Vector((s*.10,0,0)),.085,.022,trim,(1,0,0))
    link('Forearm vambrace',elbow,hand,.155,steel,.11)
    for fraction in [.12,.78]:
        p=elbow.lerp(hand,fraction);ring('Vambrace locking band',p,.146 if fraction<.5 else .116,.016,edge,hand-elbow)
    ellipsoid('Glove palm',hand,(.105,.085,.10),rubber)
    # Visible armored fingers wrap around the shaft instead of mitten hands.
    for i in range(4):
        p=hand+Vector(((i-1.5)*.037,-.035,0))
        link('Finger proximal',p+Vector((0,.018,.045)),p+Vector((0,-.048,.018)),.022,steel,vertices=12)
        link('Finger curl',p+Vector((0,-.048,.018)),p+Vector((0,-.034,-.025)),.021,steel,vertices=12)
    link('Thumb',hand+Vector((s*.075,.0,.04)),hand+Vector((s*.075,-.065,-.02)),.03,steel,vertices=12)
    shard('Forearm exposed crystal',elbow.lerp(hand,.42)+Vector((0,-.13,.04)),.035,.13,(0,s*.4,0))

# Exposed head: editable stylized block-in, not a finished likeness/sculpt.
ellipsoid('Neck',(0,0,1.87),(.10,.095,.145),skin)
ellipsoid('Head cranium',(0,-.01,2.025),(.125,.105,.18),skin)
ellipsoid('Squared jaw',(0,-.045,1.93),(.103,.087,.08),skin)
for s in [-1,1]:
    ellipsoid('Ear',(s*.128,-.005,2.01),(.025,.022,.049),skin)
    ellipsoid('Cheek plane',(s*.061,-.087,1.988),(.054,.030,.057),skin)
    ellipsoid('Eye socket',(s*.052,-.108,2.033),(.035,.012,.018),hair)
    ellipsoid('Eye',(s*.052,-.119,2.034),(.023,.009,.009),eye)
    brow=ellipsoid('Heavy brow',(s*.052,-.116,2.054),(.044,.016,.016),skin);brow.rotation_euler.y=s*-.2
    ellipsoid('Brow hair',(s*.055,-.126,2.064),(.04,.007,.007),hair)
ellipsoid('Nose bridge',(0,-.115,2.015),(.021,.026,.052),skin)
ellipsoid('Nose tip',(0,-.14,1.986),(.026,.021,.020),skin)
ellipsoid('Lower lip',(0,-.125,1.946),(.039,.009,.009),skin)
link('Mouth crease',(-.035,-.13,1.956),(.035,-.13,1.956),.003,hair,vertices=8)
# Short hair mass with restrained swept clumps and close-cropped beard.
ellipsoid('Hair cap',(0,.003,2.125),(.128,.104,.078),hair)
for i in range(7):
    o=ellipsoid('Swept hair lock',((i-3)*.032,-.055,2.15+math.sin(i)*.008),(.025,.075,.036),hair);o.rotation_euler.x=-.3
for s in [-1,1]:
    ellipsoid('Jaw beard',(s*.07,-.071,1.924),(.04,.052,.036),hair)
ellipsoid('Chin beard',(0,-.09,1.912),(.055,.035,.025),hair)

# Heavy two-handed warhammer: recessed luminous core, metal cage and end rings.
head=Vector((-.68,-.67,.34));top=Vector((.20,-.41,1.34));shaft=top-head
link('Hammer haft',head,top,.039,steel)
for i in range(17):
    pos=head.lerp(top,.31+i*.032)
    ring('Haft leather wrap',pos,.041,.009,rubber,shaft)
ring('Pommel',top,.052,.016,edge,shaft)
box('Hammer core',head,(.72,.43,.40),crystal,.055)
for s in [-1,1]:
    box('Hammer striking face',head+Vector((s*.41,0,0)),(.16,.52,.49),steel,.04)
    for y in [-1,1]:
        box('Hammer cage rail',head+Vector((0,y*.225,.17)),(.72,.065,.075),edge,.012)
        box('Hammer lower cage',head+Vector((0,y*.225,-.17)),(.72,.065,.075),steel,.012)
    ring('Hammer end bearing',head+Vector((s*.495,0,0)),.16,.034,edge,(1,0,0))
    link('Hammer end crystal',head+Vector((s*.49,0,0)),head+Vector((s*.51,0,0)),.115,crystal,vertices=12)
for i in range(3):shard('Hammer crystal teeth',head+Vector(((i-1)*.16,0,.19)),.047,.15+(i==1)*.07,(0,(i-1)*.3,0))

# Join by material to keep a static preview cheap, without losing editability
# in the saved source (source is saved before destructive export batching).
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art_source/vanguard_hammer.blend'),compress=True)
for mat in [steel,edge,rubber,trim,crystal,skin,hair,eye]:
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=mat.name
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/characters/vanguard_hammer.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
print('VANGUARD_STATIC_EXPORT_COMPLETE')
