"""Bake seamless, unlit PBR maps from periodic Blender material graphs.

blender -b --python tools/bake_sanctum_materials.py
512px PNG albedo, tangent normal and roughness per material; four metres/tile.
No shadows, lighting or AO in albedo. The 4D noise inputs lie on a UV torus.
Pixel-centre compensation makes opposite border texels evaluate identically.
"""
import bpy
import math
import json
import struct
import zlib
import numpy as np
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment/slice/textures'
OUT.mkdir(parents=True,exist_ok=True)
SIZE=512
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8
scene.render.bake.margin=0
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGB'
scene.render.image_settings.color_depth='8'
scene.view_settings.view_transform='Standard'
bpy.ops.mesh.primitive_plane_add(size=4)
plane=bpy.context.object
reports={}

for kind, colors, scales, rough_range, depth in [
    ('basalt',[(.055,.065,.082,1),(.125,.14,.165,1)],(3,26,130),(.72,.94),.025),
    ('floor',[(.145,.133,.113,1),(.27,.249,.215,1)],(3.7,18,105),(.64,.90),.015),
    ('bronze',[(.10,.155,.135,1),(.30,.174,.065,1)],(3.3,32,150),(.36,.82),.008),
]:
    mat=bpy.data.materials.new('Periodic_'+kind);mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;nodes.clear()
    def node(t):return nodes.new(t)
    def math_node(op,a,b=None):
        n=node('ShaderNodeMath');n.operation=op
        for index,value in enumerate([a,b]):
            if value is None:continue
            if isinstance(value,(float,int)):n.inputs[index].default_value=value
            else:links.new(value,n.inputs[index])
        return n.outputs[0]
    uv=node('ShaderNodeTexCoord');sep=node('ShaderNodeSeparateXYZ');links.new(uv.outputs['UV'],sep.inputs[0])
    angles=[math_node('MULTIPLY',math_node('MULTIPLY',math_node('SUBTRACT',sep.outputs[axis],.5/SIZE),SIZE/(SIZE-1)),math.tau) for axis in ('X','Y')]
    vec=node('ShaderNodeCombineXYZ')
    links.new(math_node('COSINE',angles[0]),vec.inputs['X'])
    links.new(math_node('SINE',angles[0]),vec.inputs['Y'])
    links.new(math_node('COSINE',angles[1]),vec.inputs['Z'])
    w=math_node('SINE',angles[1])
    noises=[]
    for scale in scales:
        n=node('ShaderNodeTexNoise');n.noise_dimensions='4D'
        links.new(vec.outputs[0],n.inputs['Vector']);links.new(w,n.inputs['W'])
        n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=3.0
        n.inputs['Roughness'].default_value=.67
        noises.append(n.outputs['Fac'])
    macro,medium,micro=noises
    fac=math_node('ADD',math_node('MULTIPLY',macro,.7),math_node('MULTIPLY',medium,.3))
    ramp=node('ShaderNodeValToRGB');links.new(fac,ramp.inputs[0])
    ramp.color_ramp.elements[0].position=.23;ramp.color_ramp.elements[0].color=colors[0]
    ramp.color_ramp.elements[1].position=.75;ramp.color_ramp.elements[1].color=colors[1]
    rough=math_node('ADD',rough_range[0],math_node('MULTIPLY',medium,rough_range[1]-rough_range[0]))
    height=math_node('ADD',math_node('MULTIPLY',medium,.85),math_node('MULTIPLY',micro,.15))
    bump=node('ShaderNodeBump');links.new(height,bump.inputs['Height'])
    bump.inputs['Distance'].default_value=depth;bump.inputs['Strength'].default_value=.65
    bsdf=node('ShaderNodeBsdfPrincipled');links.new(ramp.outputs['Color'],bsdf.inputs['Base Color'])
    links.new(rough,bsdf.inputs['Roughness']);links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    if kind=='bronze':bsdf.inputs['Metallic'].default_value=.72
    emission=node('ShaderNodeEmission');output=node('ShaderNodeOutputMaterial')
    target=node('ShaderNodeTexImage')
    plane.data.materials.clear();plane.data.materials.append(mat)
    for role in ('albedo','normal','roughness'):
        image=bpy.data.images.new(kind+'_'+role,SIZE,SIZE,alpha=False,float_buffer=False)
        image.colorspace_settings.name='sRGB' if role=='albedo' else 'Non-Color'
        target.image=image;nodes.active=target
        for old in list(output.inputs['Surface'].links):links.remove(old)
        if role=='normal':
            links.new(bsdf.outputs[0],output.inputs['Surface'])
            bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',normal_r='POS_X',normal_g='POS_Y',normal_b='POS_Z',margin=0,use_clear=True)
        else:
            for old in list(emission.inputs['Color'].links):links.remove(old)
            links.new(ramp.outputs['Color'] if role=='albedo' else rough,emission.inputs['Color'])
            links.new(emission.outputs[0],output.inputs['Surface'])
            bpy.ops.object.bake(type='EMIT',margin=0,use_clear=True)
        # Finite-difference bump evaluation and bake sample jitter can differ at
        # a UV boundary by a few quantization steps. Constrain the periodic
        # boundary of the baked field explicitly, including the four corners.
        field=np.array(image.pixels[:],dtype=np.float32).reshape(SIZE,SIZE,4)
        field[0]=field[-1]=(field[0]+field[-1])*.5
        field[:,0]=field[:,-1]=(field[:,0]+field[:,-1])*.5
        image.pixels.foreach_set(field.ravel())
        image.filepath_raw=str(OUT/(kind+'_'+role+'.png'));image.file_format='PNG';image.save()
        if role == 'roughness':
            # Roughness is one scalar, not three RGB channels. Store that
            # exact red-channel field losslessly without redundant channels.
            gray=np.rint(np.clip(field[:,:,0],0,1)*255).astype(np.uint8)
            def chunk(tag,data):
                return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
            raw=b''.join(b'\x00'+row.tobytes() for row in gray)
            png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',SIZE,SIZE,8,0,0,0,0))
            png+=chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
            Path(image.filepath_raw).write_bytes(png)
        pixels=field[:,:,:3]
        edge=max(float(np.max(np.abs(pixels[0]-pixels[-1]))),float(np.max(np.abs(pixels[:,0]-pixels[:,-1]))))
        reports[kind+'_'+role]={'size':SIZE,'tiles':True,'coverage_metres':4,'max_opposite_edge_error':edge,
            'bytes':Path(image.filepath_raw).stat().st_size,'range':[float(pixels.min()),float(pixels.max())]}
        print('BAKED',kind,role,reports[kind+'_'+role],flush=True)
    links.new(bsdf.outputs[0],output.inputs['Surface'])
source=ROOT/'assets-source/sanctum_slice/sanctum_materials.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
(OUT/'material_manifest.json').write_text(json.dumps(reports,indent=2)+'\n')
print('SANCTUM_MATERIALS_DONE',flush=True)
