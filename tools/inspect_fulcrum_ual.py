"""Inspect local UAL and preserved Fulcrum sources with installed Blender."""
import bpy, json
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'artifacts/fulcrum-ual-r001'
OUT.mkdir(parents=True, exist_ok=True)

def inventory():
    return {
        'fps': bpy.context.scene.render.fps,
        'rigs': [{'name': o.name, 'matrix': [list(r) for r in o.matrix_world], 'bones': [
            {'name': b.name, 'parent': b.parent.name if b.parent else None,
             'head': list(o.matrix_world @ b.head_local), 'tail': list(o.matrix_world @ b.tail_local),
             'matrix': [list(r) for r in (o.matrix_world @ b.matrix_local)]} for b in o.data.bones]} for o in bpy.data.objects if o.type == 'ARMATURE'],
        'meshes': [{'name': o.name, 'vertices': len(o.data.vertices), 'bounds': [list(o.matrix_world @ Vector(v)) for v in o.bound_box],
                    'materials': [m.name for m in o.data.materials], 'groups': [g.name for g in o.vertex_groups]} for o in bpy.data.objects if o.type == 'MESH'],
        'actions': [{'name': a.name, 'range': list(a.frame_range)} for a in bpy.data.actions]
    }

bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art_source/fulcrum.blend'))
(OUT / 'original-inventory.json').write_text(json.dumps(inventory(), indent=2), encoding='utf-8')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'Godot/AnimationLibrary_Godot_Standard.glb'))
(OUT / 'library-inventory.json').write_text(json.dumps(inventory(), indent=2), encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'library-inspection.blend'))
print('FULCRUM_UAL_INVENTORY_COMPLETE')
