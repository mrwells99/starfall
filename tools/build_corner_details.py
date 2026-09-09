"""Authored boundary shrine reused on opposing arena walls.

Rebuild: blender -b -noaudio --python tools/build_corner_details.py
Preview: blender -b -noaudio --python tools/build_corner_details.py -- --render
Both --render and --render-wall show the boundary shrine.

Inputs below use Godot world XYZ, converted to Blender XYZ at mesh creation.
Only four material batches ship. No collision, lights, animation or cameras.
Original pillar artwork is retained in the cover scene. These boundary-only
details stay beyond the boundary collision at X <= -17.65.
UV0 is a two-metre world tile; UV1 is uniquely packed for later light baking.
"""

import bpy
import bmesh
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/environment/corner/corner_details.glb"
SOURCE = ROOT / "assets-source/corner/corner_details.blend"
REPORT = ROOT / "assets-source/corner/corner_details.json"
PREVIEW = ROOT / "assets-source/corner/corner_details_preview.png"
random.seed(19841)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0


def convert(p):
    return Vector((p[0], -p[2], p[1]))


def material(name, color, roughness, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


MATS = {
    "Basalt": material("Corner_Basalt", (.075, .089, .098), .87),
    "Bronze": material("Corner_Bronze", (.34, .185, .065), .39, .76),
    "Limestone": material("Corner_Limestone", (.50, .427, .315), .80),
    "Ember": material("Corner_Ember", (1., .29, .055), .55, 0, 3.3),
}
PARTS = {kind: [] for kind in MATS}
BOUNDS = {"cover": [], "wall": []}
region = "cover"


def mesh(name, vertices, faces, kind, bevel=0.0, smooth=False):
    BOUNDS[region].extend(vertices)
    data = bpy.data.meshes.new(name)
    data.from_pydata([convert(p) for p in vertices], [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    data.materials.append(MATS[kind])
    if bevel:
        mod = obj.modifiers.new("Worn cast edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = bool(smooth or bevel)
    if bevel:
        mod = obj.modifiers.new("Flat architectural planes", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    colors = obj.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    shade = random.uniform(.84, 1.0)
    for color in colors.data:
        color.color = (shade, shade, shade, 1)
    PARTS[kind].append(obj)
    obj.select_set(False)
    return obj


def profile(name, outline, back, front, kind, wall=False, bevel=.008):
    # A profile in local horizontal/vertical coordinates, extruded toward the
    # viewer. Wall coordinates use horizontal=world Z and depth=world X.
    n = len(outline)
    vertices = [(depth, v, u) if wall else (u, v, depth)
                for depth in (back, front) for u, v in outline]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, vertices, faces, kind, bevel)


def block(name, p, size, kind, bevel=.008):
    x, y, z = p
    a, b, c = [value / 2 for value in size]
    outline = [(x-a,y-b), (x+a,y-b), (x+a,y+b), (x-a,y+b)]
    return profile(name, outline, z-c, z+c, kind, bevel=bevel)


def tube(name, points, radius, kind, sides=6, closed=False):
    points = [Vector(p) for p in points]
    vertices, faces = [], []
    n = len(points)
    for i, p in enumerate(points):
        a = points[(i-1) % n] if i or closed else points[0]
        b = points[(i+1) % n] if i < n-1 or closed else points[-1]
        tangent = (b-a).normalized()
        axis = Vector((0, 0, 1))
        if abs(tangent.dot(axis)) > .95:
            axis = Vector((1, 0, 0))
        side = tangent.cross(axis).normalized()
        other = tangent.cross(side).normalized()
        for j in range(sides):
            angle = math.tau * j / sides
            vertices.append(tuple(p + radius*(side*math.cos(angle) + other*math.sin(angle))))
    for i in range(n if closed else n-1):
        for j in range(sides):
            faces.append((i*sides+j, i*sides+(j+1)%sides,
                          ((i+1)%n)*sides+(j+1)%sides, ((i+1)%n)*sides+j))
    if not closed:
        faces += [tuple(range(sides-1,-1,-1)), tuple((n-1)*sides+j for j in range(sides))]
    return mesh(name, vertices, faces, kind, smooth=True)


def arc(name, center, radius, width, kind, start=0, end=math.tau, wall=False, steps=44):
    closed = abs(end-start-math.tau) < .001
    x, y, z = center
    points=[]
    for i in range(steps if closed else steps+1):
        angle=start+(end-start)*i/steps
        points.append((x, y+radius*math.sin(angle), z+radius*math.cos(angle)) if wall
                      else (x+radius*math.cos(angle), y+radius*math.sin(angle), z))
    return tube(name, points, width, kind, closed=closed)


def rosette(name, u, v, depth, radius, kind="Bronze", wall=False):
    outline=[]
    for i in range(8):
        angle=math.tau*i/8
        r=radius if i%2==0 else radius*.30
        outline.append((u+r*math.cos(angle),v+r*math.sin(angle)))
    return profile(name,outline,depth-.008,depth,kind,wall,bevel=.001)


# Pillar artwork stays entirely in the original authored cover meshes.
# This overlay now contains only boundary shrine details.

# Wall-side votive: a shallow relief at a blank boundary bay and wax candles
# resting atop the existing wall, all physically outside the playable floor.
region = "wall"
zc=13.5
outline=[]
for i in range(48):
    angle=math.tau*i/48
    radius=.59 + (.008*math.sin(i*2.6))
    outline.append((zc+radius*math.cos(angle),2.02+radius*math.sin(angle)))
profile("Boundary votive worn roundel",outline,-17.748,-17.667,"Basalt",wall=True,bevel=.006)
# A short pendant covers the original paired glowing slots in this one bay.
profile("Roundel pendant stone",[(zc-.145,1.58),(zc+.145,1.58),(zc+.145,1.20),
                                (zc,1.11),(zc-.145,1.20)],
        -17.738,-17.670,"Basalt",wall=True,bevel=.001)
tube("Pendant survey stroke",[(-17.656,1.26,zc),(-17.656,1.41,zc)],.004,"Bronze",sides=4)
for a,b in [(.07,1.71),(1.77,3.77),(3.84,6.24)]:
    arc("Votive segmented cast rim",(-17.667,2.02,zc),.52,.010,"Bronze",a,b,True,18)
arc("Votive crescent inner orbit",(-17.665,2.02,zc),.36,.007,"Bronze",.45,5.5,True,24)
rosette("Votive central guiding star",zc,2.02,-17.656,.13,"Bronze",True)
rosette("Votive ember jewel",zc,2.02,-17.654,.039,"Ember",True)
for i in range(12):
    a=math.tau*i/12
    rosette("Boundary calendar marker",zc+.443*math.cos(a),2.02+.443*math.sin(a),
            -17.658,.014,"Bronze",True)
# Top ledge stays behind the collision face; the three candle clusters break
# the wall's mechanical repetition without enlarging the collision footprint.
block("Votive wax catching shelf",(-17.92,3.225,zc),(.49,.050,1.40),"Bronze",.009)
for i,(along,back,height,radius) in enumerate([(-.46,-17.84,.30,.061),(-.29,-17.97,.17,.055),
    (-.04,-17.86,.43,.073),(.14,-18.00,.25,.062),(.35,-17.84,.21,.054),(.48,-17.98,.37,.065)]):
    base=3.25
    center=zc+along
    # Irregular candle top and drooping wax have real silhouette at close range.
    sides=12
    vertices=[]
    for layer in range(3):
        for j in range(sides):
            angle=math.tau*j/sides
            rad=radius*(1.05 if layer==0 else 1)
            y=base if layer==0 else base+height*(.87 if layer==1 else 1)+(.008*math.sin(j*2.4) if layer==2 else 0)
            vertices.append((back+rad*math.cos(angle),y,center+rad*math.sin(angle)))
    vertices.append((back,base+height-.015,center))
    faces=[tuple(range(sides-1,-1,-1))]
    for layer in range(2):
        for j in range(sides):
            faces.append((layer*sides+j,layer*sides+(j+1)%sides,(layer+1)*sides+(j+1)%sides,(layer+1)*sides+j))
    faces += [(2*sides+j,2*sides+(j+1)%sides,3*sides) for j in range(sides)]
    mesh("Uneven votive wax candle",vertices,faces,"Limestone",smooth=True)
    for j in range(2):
        angle=(i*2+j*.9)
        tube("Hardened running wax",[(back+radius*math.cos(angle),base+height-.01,center+radius*math.sin(angle)),
                                    (back+radius*1.025*math.cos(angle),base+height*.54,center+radius*1.025*math.sin(angle))],
             .009,"Limestone",sides=5)
    tube("Charred candle wick",[(back,base+height-.01,center),(back+.007,base+height+.035,center)],.005,"Basalt",sides=5)
    # A small asymmetric flame, brightest at its lower rounded body.
    verts=[]
    for layer,(y,r) in enumerate([(base+height+.016,.018),(base+height+.055,.029),(base+height+.106,.012)]):
        for j in range(8):
            a=math.tau*j/8
            verts.append((back+r*math.cos(a)+.009*layer,y,center+r*math.sin(a)))
    verts.append((back+.028,base+height+.15,center))
    faces=[]
    for layer in range(2):
        for j in range(8):
            faces.append((layer*8+j,layer*8+(j+1)%8,(layer+1)*8+(j+1)%8,(layer+1)*8+j))
    faces += [(16+j,16+(j+1)%8,24) for j in range(8)]
    mesh("Small warm votive flame",verts,faces,"Ember",smooth=True)


def bounds(points):
    return [[round(min(v[i] for v in points),4),round(max(v[i] for v in points),4)] for i in range(3)]


# Batch by material and export only the authored mesh. Stable world-space UVs
# let the runtime's corner materials replace the four texture-free defaults.
batches=[]
for kind, parts in PARTS.items():
    if not parts:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name="Corner_"+kind+"_geometry"
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    uv=obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        for li in poly.loop_indices:
            v=obj.data.vertices[obj.data.loops[li].vertex_index].co
            a,b=(v.x,v.y) if axis==2 else ((v.x,v.z) if axis==1 else (v.y,v.z))
            uv.data[li].uv=(a*.5,b*.5)
    obj.data.uv_layers.new(name="UV2",do_init=True)
    obj.data.uv_layers.active_index=1
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(72),island_margin=.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.uv_layers.active_index=0
    obj.data.uv_layers[0].active_render=True
    mod=obj.modifiers.new("Export triangles","TRIANGULATE")
    mod.keep_custom_normals=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    batches.append(obj)
OUTPUT.parent.mkdir(parents=True,exist_ok=True)
SOURCE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in batches:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format="GLB",use_selection=True,
    export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,
    export_tangents=True,export_materials="EXPORT",export_cameras=False,
    export_lights=False,export_animations=False)
triangles=sum(len(o.data.polygons) for o in batches)
assert triangles < 20000, triangles
assert max(p[0] for p in BOUNDS["wall"]) <= -17.65
report={"mesh_batches":len(batches),"triangles":triangles,"glb_bytes":OUTPUT.stat().st_size,
        "godot_xyz_bounds":{name:bounds(points) for name,points in BOUNDS.items() if points},
        "materials":[mat.name for mat in MATS.values()],"uv_tile_metres":2,
        "wall_votive_light_suggestion":[-17.1,3.58,13.5],
        "notes":"World-relative geometry; root at origin. No collision or lights. Boundary shrine only; no geometry obscures pillar artwork."}
REPORT.write_text(json.dumps(report,indent=2)+"\n")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),compress=True)
print("CORNER_DETAILS_REPORT="+json.dumps(report),flush=True)

if "--render" in sys.argv or "--render-wall" in sys.argv:
    # The source and GLB above remain clean. This studio adds the unmodified
    # original cover only for inspection of the new overlay against its frame.
    wall_preview = True
    context_asset = "sanctum_perimeter.glb" if wall_preview else "sanctum_cover.glb"
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"assets-source/sanctum_slice"/context_asset))
    for obj in bpy.context.selected_objects:
        if obj.type=="MESH":
            obj.location+=convert((-18.3,0,12) if wall_preview else (-6,0,5))
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1100
    scene.render.resolution_y=1050
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(PREVIEW.with_name("corner_wall_preview.png") if wall_preview else PREVIEW)
    scene.world.color=(.085,.095,.12)
    scene.view_settings.view_transform="AgX"
    floor=material("Preview floor only",(.04,.049,.06),.83)
    bpy.ops.mesh.primitive_plane_add(size=150)
    bpy.context.object.location.z=-.02
    bpy.context.object.data.materials.append(floor)
    target=convert((-17.8,2.6,13.5) if wall_preview else (-6,2,5))
    for name,pos,energy,color,size in [
        ("Warm inspection key",(-2,7,12),1500,(1,.77,.50),5),
        ("Cool sky bounce",(-11,5,6),950,(.41,.61,1),5),
        ("Upper soft rim",(-3,8,1),850,(.67,.78,1),3)]:
        data=bpy.data.lights.new(name,"AREA")
        data.energy=energy;data.color=color;data.shape="DISK";data.size=size
        obj=bpy.data.objects.new(name,data)
        bpy.context.collection.objects.link(obj)
        obj.location=convert(pos)+ (convert((-10,0,8.5)) if wall_preview else Vector((0,0,0)))
        obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    data=bpy.data.cameras.new("Preview Camera")
    cam=bpy.data.objects.new("Preview Camera",data)
    bpy.context.collection.objects.link(cam)
    cam.location=convert((-11.5,4.8,16.8) if wall_preview else (-1.0,6.0,13.5))
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=4.2 if wall_preview else 6.5
    scene.camera=cam
    bpy.ops.render.render(write_still=True)
