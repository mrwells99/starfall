"""Blender-authored floor and perimeter for the first Cosmic Sanctum art slice.

blender -b --python tools/build_sanctum_surround.py
Geometry is decorative. Godot axes: floor origin (-6,0,7), wall(-18.3,0,6.5).
No cameras, lights, collision shapes or textures are embedded in exported GLBs.
"""
import bpy
import bmesh
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/environment/slice'
random.seed(731)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
MATS = {}
for name, color, rough, metal in [
    ('Floor', (.20,.19,.175),.84,0), ('Basalt',(.13,.15,.18),.87,0),
    ('EdgeStone',(.29,.275,.24),.76,0), ('Bronze',(.30,.18,.07),.4,.72),
    ('Recess',(.045,.055,.07),.97,0), ('Inlay',(.18,.45,.65),.3,0)]:
    mat=bpy.data.materials.new('Slice_'+name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    MATS[name]=mat

def mesh(name, verts, faces, kind, bevel=.015):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    obj.data.materials.append(MATS[kind])
    if bevel:
        mod=obj.modifiers.new('Worn stone arris','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for p in data.polygons:p.use_smooth=True
        mod=obj.modifiers.new('Architectural normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # Individual blocks age differently without allocating extra materials or
    # storing lighting in the albedo. All vertices of a block share its tint.
    colors=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    shade=random.uniform(.74,1.02) if kind=='Floor' else random.uniform(.88,1.0)
    for value in colors.data:value.color=(shade,shade,shade,1)
    obj.select_set(False)
    return obj

def prism(name, outline, bottom, top, kind, bevel=.015):
    n=len(outline)
    verts=[(x,y,z) for z in (bottom,top) for x,y in outline]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,kind,bevel)

def box(name, pos, size, kind, bevel=.02):
    x,y,z=pos; a,b,c=[v/2 for v in size]
    return prism(name,[(x-a,y-b),(x+a,y-b),(x+a,y+b),(x-a,y+b)],z-c,z+c,kind,bevel)

def uv_and_export(name, objects):
    batches=[]
    groups={kind:[o for o in objects if o.data.materials[0] == MATS[kind]] for kind in MATS}
    for kind in MATS:
        parts=groups[kind]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts:obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        obj=bpy.context.object;obj.name=kind+'_geometry'
        bpy.context.scene.cursor.location=(0,0,0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        uv=obj.data.uv_layers.new(name='UVMap')
        for p in obj.data.polygons:
            axis=max(range(3),key=lambda i:abs(p.normal[i]))
            for li in p.loop_indices:
                v=obj.matrix_world @ obj.data.vertices[obj.data.loops[li].vertex_index].co
                a,b=(v.x,v.y) if axis==2 else ((v.x,v.z) if axis==1 else (v.y,v.z))
                uv.data[li].uv=(a*.25,b*.25)
        obj.data.uv_layers.new(name='UV2',do_init=True)
        obj.data.uv_layers.active_index=1
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(72),island_margin=.006)
        bpy.ops.object.mode_set(mode='OBJECT')
        obj.data.uv_layers.active_index=0;obj.data.uv_layers[0].active_render=True
        mod=obj.modifiers.new('Export triangles','TRIANGULATE');mod.keep_custom_normals=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        batches.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in batches:obj.select_set(True)
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,
        export_tangents=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    print(name,'triangles',sum(len(o.data.polygons) for o in batches),'batches',len(batches),flush=True)
    return batches

# Flat, tightly fitted flagstones: outline chips are actual silhouettes, not
# black lines painted on the albedo. Tops stay within 8mm of collision floor.
floor=[]
floor.append(box('Dark mortar bed',(0,0,-.092),(12,14,.18),'Recess',0))
for row in range(10):
    lo=-7+row*1.4; hi=lo+1.4
    cuts=[-6]
    x=-6+(1.0 if row%2 else 1.9)
    while x<5.8:
        cuts.append(x);x+=random.uniform(1.5,2.4)
    cuts.append(6)
    for a,b in zip(cuts,cuts[1:]):
        a+=.012;b-=.012;y0=lo+.012;y1=hi-.012
        c=random.uniform(.035,.085)
        outline=[(a+c,y0),(b-c*.7,y0),(b,y0+c),(b,y1-c*.8),
                 (b-c,y1),(a+c*.7,y1),(a,y1-c),(a,y0+c)]
        if (row+len(floor))%7==0 and b-a>.8:
            # A broken slab retains its flat top and footprint. Two fitted
            # pieces expose a narrow zigzag joint to the real mortar below.
            mid=(a+b)*.5
            path=[(mid-.13,y0),(mid+.09,(y0+y1)*.5),(mid-.04,y1)]
            left=[(a+c,y0),path[0],(path[1][0]-.014,path[1][1]),path[2],(a+c,y1),(a,y1-c),(a,y0+c)]
            right=[(path[0][0]+.014,y0),(b-c,y0),(b,y0+c),(b,y1-c),(b-c,y1),
                   (path[2][0]+.014,y1),(path[1][0]+.014,path[1][1])]
            floor.append(prism('Split flagstone left',left,-.085,.008,'Floor',.008))
            floor.append(prism('Split flagstone right',right,-.085,.008,'Floor',.008))
        else:
            floor.append(prism('Hand fitted flagstone',outline,-.085,.008,'Floor',.018))
# Quiet bronze border on the outer aisle, with interrupted engraved markers.
for x in (-5.55,-5.32):
    floor.append(box('Aisle metal fillet',(x,0,.008),(.022,13.8,.012),'Bronze',.003))
for y in (-5.6,-2.8,0,2.8,5.6):
    floor.append(prism('Aisle compass', [(-5.435,y-.16),(-5.36,y),(-5.435,y+.16),(-5.51,y)],.005,.015,'Bronze',.002))
floor_batches=uv_and_export('sanctum_floor',floor)
for obj in floor_batches:obj.hide_set(True);obj.hide_render=True

# Twelve metres of an ancient retaining wall. Inward X never exceeds .625,
# which places the masonry beyond the gameplay wall's inner face (-17.65).
wall=[]
wall.append(box('Continuous boundary heart',(-.12,0,1.51),(1.02,12.08,3.02),'Recess',.015))
for row in range(5):
    z=.15+row*.58
    cuts=[-6.04]+[-5.3+1.52*i+(0 if row%2 else .73) for i in range(8)]+[6.04]
    cuts=sorted(set(max(-6.04,min(6.04,v)) for v in cuts))
    for a,b in zip(cuts,cuts[1:]):
        if b-a<.15:continue
        wall.append(box('Wall ashlar',(.38,(a+b)/2,z+.27),(.46,b-a-.018,.554),'Basalt',.025))
wall.append(box('Lower continuous moulding',(.06,0,.16),(1.11,12.08,.26),'EdgeStone',.025))
wall.append(box('Upper architrave',(.07,0,3.10),(1.09,12.08,.22),'EdgeStone',.035))
wall.append(box('Bronze wall string',(.617,0,2.98),(.012,12.0,.027),'Bronze',.003))
for bay in (-4.5,-1.5,1.5,4.5):
    # Arched blind recess and segmented voussoirs on the inward-facing plane.
    radius=.70;spring=1.99
    profile=[(bay-radius,.58),(bay+radius,.58),(bay+radius,spring)]
    profile += [(bay+radius*math.cos(t),spring+radius*math.sin(t)) for t in [i*math.pi/24 for i in range(1,25)]]
    profile.append((bay-radius,.58))
    n=len(profile)
    verts=[(x,y,z) for x in (.599,.616) for y,z in profile]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    wall.append(mesh('Blind arch cavity',verts,faces,'Recess',.003))
    for i in range(11):
        t0=i*math.pi/11+.011;t1=(i+1)*math.pi/11-.011
        contour=[(bay+r*math.cos(t),spring+r*math.sin(t)) for r,t in [(radius,t0),(radius+.16,t0),(radius+.16,t1),(radius,t1)]]
        n=4;verts=[(x,y,z) for x in (.42,.622) for y,z in contour]
        faces=[(3,2,1,0),(4,5,6,7)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
        wall.append(mesh('Carved arch stone',verts,faces,'EdgeStone',.012))
    for side in (-1,1):
        wall.append(box('Arch jamb',(.50,bay+side*.78,1.28),(.23,.15,1.4),'EdgeStone',.015))
    wall.append(box('Niche sill',(.49,bay,.60),(.25,1.75,.12),'EdgeStone',.015))
    # Two vertical luminous cuts, small enough to remain accents in gameplay.
    for y in (bay-.08,bay+.08):
        wall.append(box('Votive energy slot',(.624,y,1.5),(.007,.018,.54),'Inlay',.002))
for y in (-5.95,-3,0,3,5.95):
    h=random.uniform(3.85,4.5)
    wall.append(box('Engaged buttress',(-.15,y,1.92),(1.42,.47,3.84),'Basalt',.045))
    wall.append(box('Buttress foot',(-.20,y,.27),(1.52,.68,.5),'EdgeStone',.035))
    wall.append(box('Column capital',(-.20,y,3.4),(1.50,.65,.19),'EdgeStone',.035))
    for k in range(2):
        wall.append(box('Broken crest',(-.35+k*.45,y,3.8+(h-3.8)/2),(.43,.43,h-3.8),'Basalt',.035))
wall_batches=uv_and_export('sanctum_perimeter',wall)
# Save authoring scene with floor visible and perimeter offset only in viewport;
# exported GLBs retain their local origins for deterministic placement.
for obj in floor_batches:obj.hide_set(False);obj.hide_render=False
source=ROOT/'assets-source/sanctum_slice/sanctum_surround.blend'
source.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
print('SANCTUM_SURROUND_DONE',flush=True)
