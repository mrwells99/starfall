"""Original Cosmic Sanctum cover kit, authored with Blender mesh operations.

Rebuild: blender -b --python tools/build_sanctum_cover.py
Add -- --render to produce artifacts/sanctum-cover-studio.png.

Dimensions are gameplay-aware: origin at ground centre, nominal cover bounds
4.4 x 3.8 x 2.8 m (Godot XYZ), ornamental footing within 4.7 x 3.3 m.
Only five joined, static mesh objects are exported. No collision, lights or
cameras. UVMap uses a consistent four-metre tile density; UV2 is uniquely
packed for a future bake. Export materials are deliberately texture-free so
the engine can share the slice's material set.
"""

import bpy
import bmesh
import math
import random
import sys
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets-source/sanctum_slice/sanctum_cover.glb"
SOURCE = ROOT / "assets-source/sanctum_slice/sanctum_cover.blend"
PREVIEW = ROOT / "artifacts/sanctum-cover-studio.png"
random.seed(8137)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
if hasattr(bpy.context.preferences.filepaths, "save_preview_images"):
    bpy.context.preferences.filepaths.save_preview_images = False
for datablock in list(bpy.data.materials):
    bpy.data.materials.remove(datablock)


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
    "Slice_Basalt": material("Slice_Basalt", (0.205, 0.219, 0.245), 0.83),
    "Slice_EdgeStone": material("Slice_EdgeStone", (0.345, 0.340, 0.323), 0.76),
    "Slice_Bronze": material("Slice_Bronze", (0.37, 0.225, 0.095), 0.39, 0.78),
    "Slice_Inlay": material("Slice_Inlay", (0.16, 0.49, 0.66), 0.28, 0.35, 2.8),
    "Slice_Recess": material("Slice_Recess", (0.075, 0.09, 0.112), 0.91),
}
PARTS = {name: [] for name in MATS}


def finish(obj, mat, bevel=0, segments=2, rough=0.0, smooth=False):
    """Apply real chamfers and set stable weighted face normals before batching."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel:
        mod = obj.modifiers.new("Mason's worn arris", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.affect = "EDGES"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if rough:
        # Broad faces remain broad; the chamfers carry a little stone erosion.
        for vertex in obj.data.vertices:
            vertex.co += Vector(tuple(random.uniform(-rough, rough) for _ in range(3)))
    for face in obj.data.polygons:
        face.use_smooth = smooth or bevel > 0
    if bevel:
        mod = obj.modifiers.new("Preserve carved planes", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 35
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.clear()
    obj.data.materials.append(MATS[mat])
    PARTS[mat].append(obj)
    obj.select_set(False)
    return obj


def mesh_obj(name, vertices, faces, mat, bevel=0, rough=0.0, smooth=False, segments=2):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    # Face winding is recalculated rather than assumed for custom profiles.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat, bevel, segments, rough, smooth)


def block(name, centre, size, mat="Slice_Basalt", bevel=0.035, rough=0.0, angle=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    obj.rotation_euler.z = angle
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel, 3, rough)


def profile_extrude(name, profile, y_front, y_back, mat, bevel=0.015, rough=0):
    count = len(profile)
    vertices = [(x, y_front, z) for x, z in profile] + [(x, y_back, z) for x, z in profile]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    return mesh_obj(name, vertices, faces, mat, bevel, rough)


def tube(name, points, radius, mat, sides=8, closed=False):
    vertices, faces = [], []
    length = len(points)
    points = [Vector(p) for p in points]
    for i, point in enumerate(points):
        before = points[(i - 1) % length] if i or closed else points[0]
        after = points[(i + 1) % length] if i < length - 1 or closed else points[-1]
        tangent = (after - before).normalized()
        axis = Vector((0, 1, 0))
        if abs(tangent.dot(axis)) > 0.95:
            axis = Vector((1, 0, 0))
        side = tangent.cross(axis).normalized()
        normal = tangent.cross(side).normalized()
        for j in range(sides):
            angle = j * math.tau / sides
            vertices.append(point + radius * (side * math.cos(angle) + normal * math.sin(angle)))
    for i in range(length if closed else length - 1):
        for j in range(sides):
            faces.append((i * sides + j, i * sides + (j + 1) % sides,
                          ((i + 1) % length) * sides + (j + 1) % sides,
                          ((i + 1) % length) * sides + j))
    if not closed:
        faces += [tuple(range(sides - 1, -1, -1)), tuple((length - 1) * sides + j for j in range(sides))]
    return mesh_obj(name, vertices, faces, mat, smooth=True)


def ring(name, cx, y, cz, radius, thickness, mat, start=0, end=math.tau, resolution=64):
    closed = abs(end - start - math.tau) < 0.001
    points = [(cx + radius * math.cos(start + (end - start) * i / resolution), y,
               cz + radius * math.sin(start + (end - start) * i / resolution))
              for i in range(resolution if closed else resolution + 1)]
    return tube(name, points, thickness, mat, 8, closed)


def disk(name, x, y, z, radius, depth, mat, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=(x, y, z), rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, 0.008, 2)


# A continuous full-height masonry heart keeps the visible obstruction honest.
# The shallow facing joints and recesses never imply a shoot-through opening.
block("Continuous solid cover heart", (0, 0, 2.05), (4.34, 2.70, 3.50),
      "Slice_Recess", 0.025)

# A three-stage plinth has stepped mass, an angled water table, and recessed
# shadow grooves. The two tiers give the whole object believable weight.
block("Foundation bed", (0, 0, 0.105), (4.66, 3.24, 0.21), "Slice_Basalt", 0.045, 0.008)
block("Fine lower moulding", (0, 0, 0.265), (4.56, 3.12, 0.12), "Slice_EdgeStone", 0.027)
for side in (-1, 1):
    profile_extrude("Inclined basal apron", [(-2.20, 0.32), (2.20, 0.32), (2.12, 0.55), (-2.12, 0.55)],
                    side * 1.48, side * 1.35, "Slice_EdgeStone", 0.022, 0.003)
    block("Plinth bronze string course", (0, side * 1.495, 0.332), (4.36, 0.025, 0.025),
          "Slice_Bronze", 0.004)

# Hand-arranged ashlar: wide individual stones, alternating bond, displaced
# joints and gently damaged arrises, with recessed dark mortar behind them.
courses = [(.53, 1.24, [-2.19, -.81, .65, 2.19]),
           (1.255, 2.07, [-2.19, -1.27, .30, 2.19]),
           (2.085, 2.89, [-2.19, -.57, 1.16, 2.19]),
           (2.905, 3.79, [-2.19, -1.26, .45, 2.19])]
for face in (-1, 1):
    for row, (bottom, top, cuts) in enumerate(courses):
        for j, (left, right) in enumerate(zip(cuts, cuts[1:])):
            block("Ashlar facing %s %s %s" % (face, row, j),
                  ((left + right) / 2, face * 1.205, (bottom + top) / 2),
                  (right - left - .015, .365, top - bottom),
                  "Slice_Basalt", .034 + random.random() * .009, .004)
for end in (-1, 1):
    for row, (bottom, top, _) in enumerate(courses):
        cuts = [-1.205, -.09 if row % 2 else .25, 1.205]
        for j, (near, far) in enumerate(zip(cuts, cuts[1:])):
            block("End-face coursed return", (end * 2.045, (near + far) / 2, (top + bottom) / 2),
                  (.30, far - near - .015, top - bottom), "Slice_Basalt", .032, .004)

# Six irregular capstones form a broken crown. Each has a two-dimensional
# fracture field so the silhouette is stone fracture, never a corrugated roof.
def fractured_capstone(left, right, near, far, height):
    cut = .10
    outline = [(left + cut, near), (right - cut, near), (right, near + cut),
               (right, far - cut), (right - cut, far), (left + cut, far),
               (left, far - cut), (left, near + cut)]
    base = [(x, y, 3.775) for x, y in outline]
    top = [(x + random.uniform(-.020, .020), y + random.uniform(-.020, .020),
            min(4.235, max(3.84, height + random.uniform(-.085, .085)))) for x, y in outline]
    vertices = base + top + [((left + right) / 2, (near + far) / 2, height + .018)]
    faces = [tuple(range(7, -1, -1))]
    faces += [(i, (i + 1) % 8, (i + 1) % 8 + 8, i + 8) for i in range(8)]
    faces += [(i + 8, (i + 1) % 8 + 8, 16) for i in range(8)]
    mesh_obj("Individually fractured capstone", vertices, faces, "Slice_Basalt", .021, .002)

for row, (near, far) in enumerate([(-1.355, -.115), (-.095, 1.355)]):
    cuts = [-2.17, -.89 if row == 0 else -.51, .62 if row == 0 else .93, 2.17]
    heights = [4.10, 3.96, 3.91] if row == 0 else [4.155, 4.045, 3.955]
    for index, (left, right) in enumerate(zip(cuts, cuts[1:])):
        fractured_capstone(left + .009, right - .009, near, far, heights[index])

# The worn capital frieze breaks into believable lengths and overlaps joints.
for face in (-1, 1):
    for left, right in [(-2.17, -.74), (-.715, .82), (.845, 2.17)]:
        block("Crown lower drip ledge", ((left + right) / 2, face * 1.39, 3.60),
              (right - left, .16, .115), "Slice_EdgeStone", .022, .002)
        block("Crown upper architrave", ((left + right) / 2, face * 1.382, 3.75),
              (right - left, .12, .10), "Slice_EdgeStone", .018, .002)

# Tapered six-plane buttresses carry the relief frame. Paired inner channels
# interrupt their profiles; capitols and shoes have projecting sloped faces.
for face in (-1, 1):
    for side in (-1, 1):
        cx = side * 1.66
        profile = [(cx - .29, .53), (cx + .29, .53), (cx + .25, 1.02),
                   (cx + .19, 3.34), (cx + .24, 3.49), (cx - .24, 3.49),
                   (cx - .19, 3.34), (cx - .25, 1.02)]
        profile_extrude("Tapered shrine pilaster", profile, face * 1.40, face * 1.55,
                        "Slice_EdgeStone", .035, .002)
        profile_extrude("Splayed pilaster shoe", [(cx - .34, .48), (cx + .34, .48),
                                                 (cx + .29, .81), (cx - .29, .81)],
                        face * 1.38, face * 1.62, "Slice_EdgeStone", .025, .002)
        block("Recessed pilaster channel", (cx, face * 1.565, 2.20), (.057, .018, 1.98),
              "Slice_Recess", .007)
        for z in (1.01, 3.34):
            block("Pilaster bronze collar", (cx, face * 1.565, z), (.43, .04, .045),
                  "Slice_Bronze", .008)
        profile_extrude("Pilaster capital", [(cx - .21, 3.34), (cx + .21, 3.34),
                                             (cx + .32, 3.54), (cx - .32, 3.54)],
                        face * 1.37, face * 1.62, "Slice_EdgeStone", .025)
        for z in (1.14, 3.19):
            disk("Cast anchor rosette", cx, face * 1.589, z, .054, .034, "Slice_Bronze", 12)

    # A substantial dark arched backing is intentionally shallow. It reads
    # as carved relief in a solid wall, never a traversable window or niche.
    arch_radius = 1.075
    arch_cz = 2.23
    arch = [(-arch_radius, .91), (arch_radius, .91), (arch_radius, arch_cz)]
    arch += [(math.cos(a) * arch_radius, arch_cz + math.sin(a) * arch_radius)
             for a in [math.pi * i / 32 for i in range(1, 33)]]
    profile_extrude("Blind celestial arch recess", arch, face * 1.392, face * 1.403,
                    "Slice_Recess", .005)

    # Individually wedged voussoirs, with radial joints visible at the camera.
    inner, outer = 1.06, 1.245
    for j in range(11):
        a = j * math.pi / 11 + .008
        b = (j + 1) * math.pi / 11 - .008
        profile = [(inner * math.cos(a), arch_cz + inner * math.sin(a)),
                   (outer * math.cos(a), arch_cz + outer * math.sin(a)),
                   (outer * math.cos(b), arch_cz + outer * math.sin(b)),
                   (inner * math.cos(b), arch_cz + inner * math.sin(b))]
        profile_extrude("Wedge-cut arch stone", profile, face * 1.385, face * 1.49,
                        "Slice_EdgeStone", .014, .001)
    for side in (-1, 1):
        for bottom, top in ((.88, 1.55), (1.57, 2.23)):
            block("Arch jamb", (side * 1.151, face * 1.445, (top + bottom) / 2),
                  (.185, .12, top - bottom), "Slice_EdgeStone", .02, .002)
    block("Relief sill", (0, face * 1.455, .85), (2.48, .20, .135),
          "Slice_EdgeStone", .025, .002)

    # An original armillary seal: only a narrow inner arc is magical. Bronze
    # cast rings, interrupted scale marks and a carved diamond supply relief.
    cz = 2.09
    disk("Seal recessed socket", 0, face * 1.416, cz, .78, .034, "Slice_Basalt")
    ring("Outer armillary casting", 0, face * 1.468, cz, .757, .031, "Slice_Bronze")
    ring("Inner armillary casting", 0, face * 1.46, cz, .585, .020, "Slice_Bronze")
    for j in range(24):
        a = j * math.tau / 24
        inner = .653 if j % 3 == 0 else .683
        tube("Engraved stellar scale", [(inner * math.cos(a), face * 1.458, cz + inner * math.sin(a)),
                                        (.721 * math.cos(a), face * 1.458, cz + .721 * math.sin(a))],
             .009, "Slice_Bronze", 6)
    for a, b in ((.2, 1.18), (2.57, 3.32), (4.15, 5.1)):
        ring("Restrained emissive orbit", 0, face * 1.479, cz, .532, .009,
             "Slice_Inlay", a, b, 18)
    # Elliptical orbit crosses the casting obliquely with real geometric depth.
    angle = -.59
    pts = []
    for j in range(72):
        a = j * math.tau / 72
        x, z = .945 * math.cos(a), .265 * math.sin(a)
        pts.append((x * math.cos(angle) - z * math.sin(angle),
                    face * (1.476 + .013 * math.cos(a)),
                    cz + x * math.sin(angle) + z * math.cos(angle)))
    tube("Oblique celestial orbit", pts, .019, "Slice_Bronze", 8, True)
    diamond = [(-.235, cz), (0, cz + .39), (.235, cz), (0, cz - .39)]
    profile_extrude("Carved stellar heart", diamond, face * 1.439, face * 1.505,
                    "Slice_EdgeStone", .023)
    profile_extrude("Heart bronze setting", [(0, cz - .184), (.107, cz),
                                              (0, cz + .184), (-.107, cz)],
                    face * 1.495, face * 1.527, "Slice_Bronze", .012)
    profile_extrude("Heart luminous fissure", [(0, cz - .137), (.030, cz + .016),
                                               (0, cz + .139), (-.028, cz - .012)],
                    face * 1.522, face * 1.538, "Slice_Inlay", .003)
    for x, z, radius in [(-.81, 2.96, .033), (.71, 2.93, .028), (-.84, 1.23, .024)]:
        disk("Celestial star nail", x, face * 1.422, z, radius, .020, "Slice_Bronze", 8)

    # Incomplete metal lacing and fracture splinters break mechanical symmetry.
    for j, (x, z, angle) in enumerate([(-1.04, 3.86, -.23), (.42, .63, .17), (1.95, 2.05, -.18)]):
        if face == 1 and j == 0:
            continue
        block("Historic dovetail repair", (x, face * 1.40, z), (.22, .035, .044),
              "Slice_Bronze", .007, angle=angle)

# Side walls carry shallow interlocked diamond carving, not another focal seal.
for side in (-1, 1):
    for z in (1.39, 2.56):
        pts = [(side * 2.213, -.68, z), (side * 2.213, 0, z + .39),
               (side * 2.213, .68, z), (side * 2.213, 0, z - .39)]
        tube("End-face diamond carving", pts, .017, "Slice_Bronze", 6, True)
    for y in (-.78, .78):
        tube("End-face moulding", [(side * 2.218, y, .67), (side * 2.218, y, 3.48)],
             .030, "Slice_EdgeStone", 8)


def assign_uvs(obj):
    """Explicit mesh UVs in world-metres, plus a nonoverlapping second set."""
    bpy.context.view_layer.objects.active = obj
    for existing in list(obj.data.uv_layers):
        obj.data.uv_layers.remove(existing)
    uv = obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda j: abs(n[j]))
        # Planar faces of masonry and carved details use the corresponding
        # geometric projection, stored once in UV rather than shader sampling.
        for loop_index in poly.loop_indices:
            pos = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            if axis == 2:
                a, b = pos.x, pos.y
            elif axis == 1:
                a, b = pos.x, pos.z
            else:
                a, b = pos.y, pos.z
            uv.data[loop_index].uv = (a * .25, b * .25)
    uv2 = obj.data.uv_layers.new(name="UV2", do_init=True)
    obj.data.uv_layers.active = uv2
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(72), island_margin=.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.uv_layers.active_index = 0
    obj.data.uv_layers[0].active_render = True


# Collapse all authoring components to exactly one object per material.
batches = []
for name, parts in PARTS.items():
    if not parts:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name.removeprefix("Slice_") + "_geometry"
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    assign_uvs(obj)
    # Tangent export requires triangles or quads; these custom sculptural
    # outlines contain n-gons. Triangulate once while retaining authored normals.
    mod = obj.modifiers.new("Export triangulation", "TRIANGULATE")
    mod.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    batches.append(obj)

OUT.parent.mkdir(parents=True, exist_ok=True)
SOURCE.parent.mkdir(parents=True, exist_ok=True)
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in batches:
    obj.select_set(True)
bpy.context.view_layer.objects.active = batches[0]
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                         export_yup=True, export_apply=True, export_texcoords=True,
                         export_normals=True, export_tangents=True, export_materials="EXPORT",
                         export_cameras=False, export_lights=False, export_animations=False)

triangles = 0
verts = []
for obj in batches:
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
    verts += [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
bounds = [[min(v[i] for v in verts), max(v[i] for v in verts)] for i in range(3)]
print("SANCTUM_COVER_REPORT=" + json.dumps({"mesh_batches": len(batches), "triangles": triangles,
      "blender_xyz_bounds": bounds, "glb_bytes": OUT.stat().st_size,
      "uv_channels": [list(obj.data.uv_layers.keys()) for obj in batches]}))

# Save a clean editable source before adding a presentation-only studio.
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)

if "--render" in sys.argv:
    for name in ("Slice_Basalt", "Slice_EdgeStone", "Slice_Recess"):
        mat = MATS[name]
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 28
        noise.inputs["Detail"].default_value = 3.8
        noise.inputs["Roughness"].default_value = .7
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = .27
        bump.inputs["Distance"].default_value = .034
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        ramp = nodes.new("ShaderNodeValToRGB")
        color = tuple(mat.diffuse_color[:3])
        ramp.color_ramp.elements[0].position = .22
        ramp.color_ramp.elements[0].color = (*[c * .66 for c in color], 1)
        ramp.color_ramp.elements[1].position = .82
        ramp.color_ramp.elements[1].color = (*[min(c * 1.16, 1) for c in color], 1)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW)
    scene.world.color = (.12, .14, .19)
    scene.view_settings.view_transform = "AgX"

    floor = material("Studio only", (.042, .048, .062), .82)
    bpy.ops.mesh.primitive_plane_add(size=200)
    bpy.context.object.location.z = -.018
    bpy.context.object.data.materials.append(floor)

    def light(name, location, energy, color, size):
        data = bpy.data.lights.new(name, "AREA")
        data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector((0, 0, 2)) - obj.location).to_track_quat("-Z", "Y").to_euler()

    light("Warm raking key", (2, -5, 8), 1200, (1, .80, .59), 5)
    light("Cold reflected sky", (-5, -2, 4), 750, (.41, .58, 1), 5)
    light("Thin violet rim", (3, 5, 6), 950, (.63, .38, 1), 3)
    data = bpy.data.cameras.new("Studio Camera")
    camera = bpy.data.objects.new("Studio Camera", data)
    bpy.context.collection.objects.link(camera)
    camera.location = (7.0, -9.5, 7.0)
    target = Vector((0, 0, 2))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.8
    scene.camera = camera
    bpy.ops.render.render(write_still=True)
