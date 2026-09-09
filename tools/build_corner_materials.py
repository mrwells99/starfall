"""Bake the Sanctum quality-corner material set from periodic Blender graphs.

Usage: blender -b --factory-startup -noaudio --python tools/build_corner_materials.py

Four metres per repeat; 1024px; no photographic sources or baked lighting.
The UV torus keeps the Blender 4D noise fields seamless. Tangent normals are
derived from a physical, metre-valued height field rather than arbitrary RGB.
"""
import bpy
import hashlib
import json
import math
import struct
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/environment/corner/textures"
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 1024
METRES = 4.0
REPORT = {}
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1
scene.render.bake.margin = 0
scene.view_settings.view_transform = "Standard"
bpy.ops.mesh.primitive_plane_add(size=METRES)
plane = bpy.context.object


def write_png(path, pixels):
    """Write exact 8-bit maps, with no color conversion on scalar channels."""
    values = np.rint(np.clip(pixels, 0, 1) * 255).astype(np.uint8)
    channels = 1 if values.ndim == 2 else values.shape[-1]
    color_type = {1: 0, 3: 2, 4: 6}[channels]
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(
            ">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + row.tobytes() for row in values)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def save_map(kind, role, field):
    # Periodic material evaluation is exact; sampling and quantization can add
    # a one-value disagreement, so constrain both repeated endpoint texels.
    field[0] = field[-1] = (field[0] + field[-1]) * .5
    field[:, 0] = field[:, -1] = (field[:, 0] + field[:, -1]) * .5
    if role == "normal":
        unit_normal = field * 2 - 1
        unit_normal /= np.linalg.norm(unit_normal, axis=-1, keepdims=True)
        field = unit_normal * .5 + .5
    filename = f"{kind}_{role}.png"
    path = OUT / filename
    write_png(path, field)
    resource = f"res://assets/environment/corner/textures/{filename}"
    imported = f"res://.godot/imported/{filename}-{hashlib.md5(resource.encode()).hexdigest()}.ctex"
    path.with_suffix(".png.import").write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="{imported}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{resource}"
dest_files=["{imported}"]

[params]

compress/mode=0
compress/high_quality=true
compress/lossy_quality=0.7
compress/normal_map={1 if role == 'normal' else 0}
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/normal_map_invert_y=false
process/size_limit=0
detect_3d/compress_to=0
''')
    REPORT[f"{kind}_{role}"] = {
        "size": SIZE, "coverage_metres": METRES, "seamless": True,
        "mipmaps": True, "range": [float(field.min()), float(field.max())],
        "max_opposite_edge_error": float(max(np.abs(field[0] - field[-1]).max(),
                                             np.abs(field[:, 0] - field[:, -1]).max())),
        "bytes": path.stat().st_size,
        "encoding": "sRGB" if role == "albedo" else "linear",
    }
    print("CORNER_MAP", filename, REPORT[f"{kind}_{role}"], flush=True)


for kind in ("floor", "basalt", "bronze"):
    material = bpy.data.materials.new("Corner_" + kind)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    def node(name):
        return nodes.new(name)
    def connect(value, socket):
        if isinstance(value, (int, float)):
            socket.default_value = value
        else:
            links.new(value, socket)
    def calc(op, a, b=None):
        n = node("ShaderNodeMath")
        n.operation = op
        connect(a, n.inputs[0])
        if b is not None:
            connect(b, n.inputs[1])
        return n.outputs[0]
    def add(a, b): return calc("ADD", a, b)
    def mul(a, b): return calc("MULTIPLY", a, b)
    def sub(a, b): return calc("SUBTRACT", a, b)
    def clamp(a): return calc("MINIMUM", calc("MAXIMUM", a, 0), 1)
    def band(a, lo, hi): return clamp(mul(sub(a, lo), 1 / (hi - lo)))
    def lerp(a, b, t): return add(a, mul(sub(b, a), t))
    uv = node("ShaderNodeTexCoord")
    separate = node("ShaderNodeSeparateXYZ")
    links.new(uv.outputs["UV"], separate.inputs[0])
    angles = [mul(mul(sub(separate.outputs[axis], .5 / SIZE), SIZE / (SIZE - 1)),
                  math.tau) for axis in ("X", "Y")]
    torus = node("ShaderNodeCombineXYZ")
    links.new(calc("COSINE", angles[0]), torus.inputs["X"])
    links.new(calc("SINE", angles[0]), torus.inputs["Y"])
    links.new(calc("COSINE", angles[1]), torus.inputs["Z"])
    w = calc("SINE", angles[1])
    def noise(scale, detail=2.5, rough=.62, offset=0):
        n = node("ShaderNodeTexNoise")
        n.noise_dimensions = "4D"
        links.new(torus.outputs[0], n.inputs["Vector"])
        links.new(add(w, offset), n.inputs["W"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        return n.outputs["Fac"]
    def color_ramp(factor, stops):
        n = node("ShaderNodeValToRGB")
        links.new(factor, n.inputs[0])
        ramp = n.color_ramp
        for index, (position, color) in enumerate(stops):
            element = ramp.elements[index] if index < 2 else ramp.elements.new(position)
            element.position = position
            element.color = (*color, 1)
        return n.outputs["Color"]
    def blend(a, b, factor):
        n = node("ShaderNodeMixRGB")
        n.blend_type = "MIX"
        links.new(factor, n.inputs[0])
        for socket, value in ((n.inputs[1], a), (n.inputs[2], b)):
            if isinstance(value, tuple): socket.default_value = (*value, 1)
            else: links.new(value, socket)
        return n.outputs[0]

    broad = noise(.9, 2, .55, 1.4)
    mineral = noise(8.0, 3, .68, 3.7)
    grain = noise(58.0, 2, .7, 7.3)
    fine = noise(190.0, 1, .58, 11.0)
    pits = band(noise(94, 1, .6, 17), .64, .77)

    if kind == "floor":
        # Soft warm sedimentary stone, occasional calcite, shallow open pores.
        # Large cracks and slab joints belong to geometry, never this tile.
        color = color_ramp(add(mul(broad, .76), mul(mineral, .24)), [
            (.2, (.153, .137, .107)), (.8, (.294, .267, .215))])
        fossils = mul(band(mineral, .58, .70), band(grain, .53, .68))
        color = blend(color, (.37, .343, .289), mul(fossils, .38))
        color = blend(color, (.108, .091, .066), mul(pits, .46))
        height = sub(add(mul(mineral, .0040), mul(grain, .00060)), mul(pits, .00135))
        height = add(height, mul(fine, .00013))
        roughness = clamp(add(add(.735, mul(mineral, .13)), mul(pits, .12)))
        metal = 0.0
    elif kind == "basalt":
        # Dark blue-neutral volcanic stone, tiny quartz-rich grains and sparse
        # shallow weathering; no glossy blue plastic or thick crack web.
        color = color_ramp(add(mul(broad, .67), mul(mineral, .33)), [
            (.20, (.023, .028, .035)), (.80, (.086, .096, .108))])
        crystals = band(grain, .62, .76)
        color = blend(color, (.17, .18, .18), mul(crystals, .43))
        color = blend(color, (.018, .021, .024), mul(pits, .45))
        height = sub(add(mul(mineral, .0032), mul(grain, .00075)), mul(pits, .0018))
        height = add(height, mul(fine, .00020))
        roughness = clamp(sub(add(.81, mul(mineral, .10)), mul(crystals, .18)))
        metal = 0.0
    else:
        # Cast bronze with broad uneven oxidation. Oxide changes metallic and
        # roughness response along with color; it is not green metallic paint.
        weather = add(mul(broad, .69), mul(mineral, .31))
        patina = band(weather, .50, .635)
        clean = color_ramp(add(mul(broad, .4), mul(grain, .6)), [
            (.2, (.21, .107, .034)), (.8, (.45, .263, .092))])
        oxide = color_ramp(mineral, [
            (.25, (.022, .049, .037)), (.75, (.075, .137, .103))])
        color = blend(clean, oxide, patina)
        roughness = lerp(add(.35, mul(grain, .17)), add(.76, mul(fine, .15)), patina)
        metal = lerp(.95, .055, patina)
        height = add(add(mul(mineral, .0011), mul(grain, .00017)), mul(patina, .00020))
        height = sub(height, mul(pits, .00038))

    emission = node("ShaderNodeEmission")
    output = node("ShaderNodeOutputMaterial")
    target = node("ShaderNodeTexImage")
    links.new(emission.outputs[0], output.inputs["Surface"])
    plane.data.materials.clear()
    plane.data.materials.append(material)
    for role, field in (("albedo", color), ("roughness", roughness),
                        ("height", height), ("metallic", metal)):
        if role == "metallic" and kind != "bronze":
            continue
        image = bpy.data.images.new(f"{kind}_{role}", SIZE, SIZE, alpha=False, float_buffer=True)
        image.colorspace_settings.name = "Non-Color"
        target.image = image
        nodes.active = target
        for previous in list(emission.inputs["Color"].links):
            links.remove(previous)
        links.new(field, emission.inputs["Color"])
        bpy.ops.object.bake(type="EMIT", margin=0, use_clear=True)
        # Blender stores rows bottom-to-top; PNG and Godot texture UV use the
        # opposite row order. Derive normals in Blender's UV convention first.
        pixels = np.array(image.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)
        data = pixels[:, :, :3] if role == "albedo" else pixels[:, :, 0]
        if role == "height":
            dx = (np.roll(data, -1, axis=1) - np.roll(data, 1, axis=1)) / (2 * METRES / SIZE)
            dy = (np.roll(data, -1, axis=0) - np.roll(data, 1, axis=0)) / (2 * METRES / SIZE)
            normal = np.stack((-dx, -dy, np.ones_like(data)), axis=-1)
            normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
            save_map(kind, "normal", (normal * .5 + .5)[::-1].copy())
        else:
            if role == "albedo":
                data = np.where(data <= .0031308, data * 12.92,
                                1.055 * np.power(np.maximum(data, 0), 1 / 2.4) - .055)
            save_map(kind, role, data[::-1].copy())
        bpy.data.images.remove(image)

(OUT / "material_manifest.json").write_text(json.dumps(REPORT, indent=2) + "\n")
print("CORNER_MATERIALS_DONE", flush=True)
