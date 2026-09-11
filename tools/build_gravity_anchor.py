"""Blender source generator for Gravity Anchor r001. No character assets touched."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal=0.0, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metal
    node.inputs['Roughness'].default_value = .32
    node.inputs['Emission Color'].default_value = (*color, 1)
    node.inputs['Emission Strength'].default_value = glow
    return mat

obsidian = material('Obsidian', (.025, .015, .06), .65)
metal = material('Ancient violet alloy', (.15, .095, .23), .75)
edge = material('Violet inlay', (.46, .13, .95), .2, 2.5)
light = material('Pale core rim', (.73, .48, 1), .1, 3.0)

def empty(name, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    return obj

def arc(name, parent, radius, width, depth, begin, end, mat):
    verts, faces = [], []
    steps = max(8, int((end - begin) / 5))
    for i in range(steps + 1):
        a = math.radians(begin + (end-begin)*i/steps)
        for r, z in [(radius-width/2, -depth/2), (radius+width/2, -depth/2),
                     (radius+width/2, depth/2), (radius-width/2, depth/2)]:
            verts.append((r*math.cos(a), r*math.sin(a), z))
    for i in range(steps):
        for j in range(4):
            faces.append((4*i+j, 4*i+(j+1)%4, 4*(i+1)+(j+1)%4, 4*(i+1)+j))
    faces.extend([(3, 2, 1, 0), tuple(4*steps+j for j in range(4))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj

def join_children(parent, name):
    bpy.ops.object.select_all(action='DESELECT')
    children = [o for o in parent.children if o.type == 'MESH']
    for obj in children: obj.select_set(True)
    bpy.context.view_layer.objects.active = children[0]
    bpy.ops.object.join()
    children[0].name = name

outer = empty('RotorOuter', (0, 0, 1.0))
inner = empty('RotorInner', (0, 0, 1.0))
outer.rotation_euler = (math.radians(66), math.radians(18), 0)
inner.rotation_euler = (math.radians(-42), math.radians(32), .5)
for parent, radius in [(outer, .70), (inner, .51)]:
    for i in range(3):
        a = i*120+12
        arc('Broken alloy ring', parent, radius, .085, .06, a, a+91, metal)
        arc('Inset luminous edge', parent, radius-.032, .018, .067, a+5, a+84, edge)
        for j in range(3):
            arc('Etched tick', parent, radius+.005, .065, .069, a+16+j*23, a+18+j*23, light)
    join_children(parent, parent.name+'Mesh')

core = empty('Core', (0, 0, 1))
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=.245)
obj = bpy.context.object
obj.name = 'Faceted singularity'
obj.parent = core
obj.location = (0, 0, 0)
obj.data.materials.append(obsidian)
arc('Core equator', core, .26, .024, .027, 0, 360, light)
join_children(core, 'CoreMesh')

crown = empty('ShardCrown')
for i in range(3):
    a = i*math.tau/3
    x, y = .51*math.cos(a), .51*math.sin(a)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=.105, radius2=0, depth=.39,
                                   location=(x,y,.24), rotation=(0,0,a))
    obj = bpy.context.object
    obj.parent = crown
    obj.data.materials.append(metal)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=.048, location=(x,y,.45))
    obj = bpy.context.object
    obj.parent = crown
    obj.data.materials.append(edge)
join_children(crown, 'ShardCrownMesh')

base = empty('Footprint')
for i in range(3):
    arc('Ground seal', base, .64, .025, .015, i*120+4, i*120+109, edge)
join_children(base, 'FootprintMesh')

# Save a loop in the editable Blender scene. Runtime uses the same rotations
# procedurally so activation/replacement and reduced-effects stay state-driven.
bpy.context.scene.render.fps = 30
bpy.context.scene.frame_end = 361
for obj, axis, turns in [(outer, 2, 1), (inner, 2, -1), (core, 2, -.5), (crown, 2, .25)]:
    obj.keyframe_insert(data_path='rotation_euler', frame=1, index=axis)
    obj.rotation_euler[axis] += math.tau*turns
    obj.keyframe_insert(data_path='rotation_euler', frame=361, index=axis)
    action = obj.animation_data.action
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for point in curve.keyframe_points: point.interpolation = 'LINEAR'
bpy.context.scene.frame_set(1)
source = ROOT/'art_source/spells/fulcrum/gravity_anchor/gravity_anchor.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/effects/gravity_anchor.glb'),
    export_format='GLB', export_animations=False, export_cameras=False, export_lights=False)
print('GRAVITY_ANCHOR_EXPORTED', sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'))
