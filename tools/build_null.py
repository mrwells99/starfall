"""Null costume, sentient twin blades and extra clips on the frozen v2 anatomy.
Produces isolated candidates; never modifies the accepted baseline or another class.
"""
import bpy,bmesh,math,json,hashlib,sys,random
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'artifacts/null-forge-v2';SEED=STAGE/'seed';OUT=STAGE/'candidate'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SEED/'art_source/fulcrum_ual/fulcrum_ual.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['Fulcrum_UAL_Rig'];rig.name='Null_UAL_Rig'
body=bpy.data.objects['Fulcrum_SkinnedModel'];body.name='Null_SkinnedModel'
mannequin=bpy.data.objects['Fulcrum_UAL_Undersuit'];mannequin.name='Null_UAL_Undersuit'
for obj in list(bpy.data.objects):
    if obj not in [rig,body,mannequin]:bpy.data.objects.remove(obj,do_unlink=True)
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
core=json.loads((SEED/'art_source/fulcrum_ual/recipe.json').read_text())['core_rest_matrices']
# Rework the reference-derived tailored armor: no sealed mask, orb, gravity
# lighting, priestly central stole or full skirt. Preserve fitting and UV detail.
bm=bmesh.new();bm.from_mesh(body.data)
remove=[]
for f in bm.faces:
    c=f.calc_center_median()
    if c.z>1.5 and f.material_index in [1,2,3,4,6,7,10]:remove.append(f)
    elif f.material_index==4:remove.append(f)
    elif f.material_index in [8,6] and c.z<.9 and c.y<-.12 and abs(c.x)<.055:remove.append(f)
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()
for v in body.data.vertices:
    ws={body.vertex_groups[g.group].name:g.weight for g in v.groups}
    cloth=sum(w for n,w in ws.items() if n.startswith(('robe','hem','mantle')))
    if cloth>.8 and v.co.z<.75:
        v.co.z=.75-(.75-v.co.z)*.68
        v.co.x*=.94
# Replace every source palette map with portable neutral graphite/ash textures.
N=1024;vv,uu=np.mgrid[0:1:complex(N),0:1:complex(N)]
rng=np.random.default_rng(311);grain=rng.uniform(-1,1,(N,N))
for im in list(bpy.data.images):
    if not im.name.startswith('Fulcrum '):continue
    oldname=im.name
    data=np.empty(N*N*4,dtype=np.float32);im.pixels.foreach_get(data);data=data.reshape((N,N,4))
    if 'normal' not in oldname and 'micro' not in oldname and 'roughness' not in oldname:
        grey=data[:,:,:3].mean(axis=2)
        if 'violet' in oldname:grey=np.clip(.055+grey*.52+grain*.009,.02,.32)
        elif 'ash' in oldname:grey=np.clip(.07+grey*.55,.025,.40)
        else:grey=np.clip(.07+grey*.66,.04,.48)
        data[:,:,:3]=grey[:,:,None]
    # Fresh image datablocks prevent the original packed PNG buffer from being
    # exported after a pixel edit. Retain linear data for roughness and normals.
    replacement=bpy.data.images.new(oldname.replace('Fulcrum','Null').replace('violet','charcoal'),width=N,height=N)
    replacement.colorspace_settings.name=im.colorspace_settings.name
    replacement.pixels.foreach_set(data.ravel())
    replacement.filepath_raw=str(OUT/(replacement.name.lower().replace(' ','_')+'.png'));replacement.file_format='PNG';replacement.save();replacement.pack()
    for material in bpy.data.materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type=='TEX_IMAGE' and node.image==im:node.image=replacement
    bpy.data.images.remove(im)
for m in bpy.data.materials:
    old=m.name;m.name=old.replace('Fulcrum','Null').replace('RivenViolet','RivenCharcoal')
    if not m.use_nodes:continue
    p=m.node_tree.nodes.get('Principled BSDF')
    if p is None:continue
    color=list(p.inputs['Base Color'].default_value);grey=sum(color[:3])/3
    if 'Bronze' in old or 'Pewter' in old:grey=.32 if 'Pewter' in old else .23
    if 'GravityLight' in old:grey=.18
    p.inputs['Base Color'].default_value=(grey,grey,grey,1);m.diffuse_color=(grey,grey,grey,1)
    p.inputs['Emission Strength'].default_value=0
    p.inputs['Emission Color'].default_value=(1,1,1,1)
parts=[]
# The shared construction helpers create beveled skinned surfaces, UVs and
# normalized weights. They do not import another class's geometry or costume.
exec((ROOT/'art_source/null_ual/construction.py').read_text(encoding='utf-8'))
def mat(name,color,metal=0,rough=.5,emit=0):
    m=bpy.data.materials.new('Null_'+name);m.use_nodes=True;m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
    return m
black=mat('FacelessVoid',(.001,.001,.001),0,1)
silver=mat('BladeSilver',(.38,.39,.40),.85,.25)
mirror=mat('LivingBlackMirror',(.018,.019,.020),.85,.18)
white=mat('SentientWhiteEye',(.9,.94,1),.2,.25,2.0)
leather=bpy.data.materials['Null_BlackLeather']
# A recessed unlit shadow surface; there are no human facial features.
ellipsoid('Featureless depth inside hood',(0,-.045,1.655),(.087,.035,.13),black,'DEF-head')
black.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0
# Distinct narrow harness across the cuirass with silver stitchwork.
pts=[(-.15,-.147,1.42),(-.095,-.172,1.42),(.135,-.174,1.04),(.08,-.175,1.02)]
panel('Diagonal blade harness',pts,leather,'DEF-spine.002',.008)
for edge in [(pts[0],pts[3]),(pts[1],pts[2])]:tube('Silver harness stitch',edge,.0018,silver,'DEF-spine.002')
# Each blade is a true child of its corresponding hand; closed native fists
# remain unchanged in the frozen motion and are held by the runtime grip layer.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side in ['L','R']:
    hand=rig.data.edit_bones['DEF-hand.'+side];b=rig.data.edit_bones.new('null.blade.'+side)
    b.matrix=hand.matrix.copy();b.length=.1;b.parent=hand
bpy.ops.object.mode_set(mode='OBJECT')
for side in ['L','R']:
    start=len(parts);bn='null.blade.'+side
    # Author in a convenient vertical blade frame, then place across the palm.
    tube('Wrapped sentient blade grip',[(0,0,-.07),(0,0,.065)],.015,leather,bn,16)
    for z in np.linspace(-.065,.055,10):ring('Grip silver binding',(0,0,float(z)),.016,.003,silver,bn,.0016)
    length=.43 if side=='L' else .40
    pts=[(-.035,-.012,.07),(.04,-.012,.09),(.061,-.012,.20),(.035,-.012,.32),(-.07,-.012,length),(-.027,-.012,.27)]
    panel('Curved black mirror blade '+side,pts,mirror,bn,.024)
    tube('Razor white cutting edge '+side,[pts[1],pts[2],pts[3],pts[4]],.0022,white,bn,8)
    tube('Curving silver guard '+side,[(-.071,0,.038),(-.045,0,.087),(0,0,.08),(.058,0,.085),(.075,0,.14)],.007,silver,bn,12)
    # Almond eye with a vertical luminous slit and metal eyelids.
    ellipsoid('Living eye socket '+side,(0,-.025,.124),(.034,.009,.044),mirror,bn)
    for sign in [-1,1]:tube('Sentient silver eyelid '+side,[(.032*math.sin(math.pi*t),-.034,.124+sign*.044*math.cos(math.pi*t)) for t in np.linspace(0,1,24)],.0025,silver,bn)
    tube('Sentient slit pupil '+side,[(0,-.038,.091),(0,-.041,.124),(0,-.038,.155)],.0025,white,bn,8)
    hand_matrix=rig.data.bones['DEF-hand.'+side].matrix_local
    sign=1 if side=='L' else -1
    for ob in parts[start:]:
        for v in ob.data.vertices:
            x,y,z=v.co
            v.co=hand_matrix@Vector((sign*(.030+y),.107+x,-z))
# Join original refitted costume and class-specific details into one mesh.
bpy.ops.object.select_all(action='DESELECT')
for ob in [body]+parts:ob.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
# Additional source-native attack/crouch animations never replace the 32 v2 clips.
existing=set(bpy.data.actions);before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(SEED/'art_source/fulcrum_ual/AnimationLibrary_Godot_Standard.glb'))
source_rig=next(o for o in bpy.data.objects if o not in before and o.type=='ARMATURE')
source_actions={a.name:a for a in bpy.data.actions if a not in existing}
print('NULL_AVAILABLE_SOURCE_CLIPS',list(source_actions),flush=True)
# Sword_Attack reads poorly with Null's reverse-gripped pair. Punch_Cross gives
# both blades a compact, committed cross-cut without touching the v2 base clips.
extra_clips={'KnifeStrike':'Punch_Cross'}
for label,words in [('StealthIdle',['crouch','idle']),('StealthWalk',['crouch','fwd'])]:
    names=[n for n in source_actions if all(w in n.lower() for w in words)]
    if not names and label=='StealthWalk':names=[n for n in source_actions if 'crouch' in n.lower() and 'walk' in n.lower()]
    if names:extra_clips[label]=names[0]
scene=bpy.context.scene;extra_samples={}
for label,name in extra_clips.items():
    act=source_actions[name];source_rig.animation_data_create();source_rig.animation_data.action=act
    if act.slots:source_rig.animation_data.action_slot=act.slots[0]
    start,end=act.frame_range;frames=[]
    for i in range(round(end-start)+1):
        scene.frame_set(round(start)+i)
        frames.append({n:source_rig.pose.bones[n].matrix_basis.copy() for n in core})
    extra_samples[label]=frames
for ob in list(bpy.data.objects):
    if ob not in before:bpy.data.objects.remove(ob,do_unlink=True)
for act in list(bpy.data.actions):
    if act not in existing:bpy.data.actions.remove(act)
for label,frames in extra_samples.items():
    act=bpy.data.actions.new(label);rig.animation_data.action=act
    for i,frame in enumerate(frames):
        for n,matrix in frame.items():
            p=rig.pose.bones[n];p.rotation_mode='QUATERNION';p.matrix_basis=matrix
            if n=='root':p.location=Vector((0,0,0))
            for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(prop,frame=i+1,group=n)
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=label
    strip=track.strips.new(label,1,act);strip.action_frame_end=len(frames);track.mute=True
for track in rig.animation_data.nla_tracks:track.mute=track.name!='Idle'
scene.frame_start=1;scene.frame_end=76;scene.frame_set(1)
for m in list(bpy.data.materials):
    if m.users==0:bpy.data.materials.remove(m)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
            area.spaces.active.region_3d.view_location=Vector((0,0,1));area.spaces.active.region_3d.view_distance=3.3
bpy.ops.object.select_all(action='DESELECT')
for ob in [rig,body,mannequin]:ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'null.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'null.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_apply=False)
record={'class':'Null','workflow':'Starfall Model Forge v2 + hitboxes-v1','core_rest_matrices':core,'core_motion_exceptions':[],
 'source_sha256':hashlib.sha256((SEED/'art_source/fulcrum_ual/fulcrum_ual.blend').read_bytes()).hexdigest(),
 'design':'Reference-fitted layered charcoal armor, open faceless hood, shortened torn tails, silver harness, two asymmetric curved sentient blades; no gravity weapon or mask',
 'palette':'Neutral black, charcoal and graphite with silver edges and white blade eyes','texture_seed':311,
 'grips':'Two hand-parented reverse grips; native idle fist applied by shared visible/server runtime',
 'extras':extra_clips,'clips':[t.name for t in rig.animation_data.nla_tracks],'blender':bpy.app.version_string}
(OUT/'recipe.json').write_text(json.dumps(record,indent=2))
print('NULL_BUILD_COMPLETE',len(body.data.vertices),'costume vertices',len(rig.data.bones),'bones',len(record['clips']),'clips',flush=True)
