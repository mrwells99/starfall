"""Class equipment on the unchanged UAL anatomy; explicit grip exceptions only."""
import math
import bpy
from mathutils import Matrix, Vector, Quaternion

STATE = {}

def prepare(slug, rig, old_bones, transforms):
    STATE.clear()
    STATE.update(slug=slug, max_grip_error=0.0, motion_exceptions=[])
    if slug == 'ember': return
    name = 'staff' if slug == 'luminary' else 'weapon'
    scale = .86 if slug == 'luminary' else .78
    # Preserve the equipment's complete geometry by one uniform rigid transform.
    old_origin = old_bones[name]['head']
    target = Vector((-.32,-.10,.92)) if slug=='luminary' else Vector((.42,-.35,1.55))
    transforms[name] = Matrix.Translation(target) @ Matrix.Diagonal((scale,scale,scale,1)) @ Matrix.Translation(-old_origin)
    STATE.update(bone=name, scale=scale)
    if slug=='luminary':
        # Reuse the supplied idle's relaxed closed hand, instead of opening the
        # staff-carrying fingers during spell gestures. All other motion stays.
        action=bpy.data.actions['Idle_Loop']
        rig.animation_data_create();rig.animation_data.action=action
        if action.slots:rig.animation_data.action_slot=action.slots[0]
        bpy.context.scene.frame_set(int(action.frame_range[0]))
        grip={p.name:list(p.rotation_quaternion) for p in rig.pose.bones if p.name.endswith('.R') and ('DEF-f_' in p.name or 'DEF-thumb' in p.name)}
        STATE['grip_rotations']=grip
        STATE['motion_exceptions']=list(grip)
        rig.animation_data_clear()
        for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
        bpy.context.view_layer.update()

def aim(rig, name, target):
    p=rig.pose.bones[name]
    m=p.matrix.copy()
    # Actual parent-to-child joint axis, not the importer-generated bone tail.
    child = 'DEF-forearm.'+name[-1] if 'upper_arm' in name else 'DEF-hand.'+name[-1]
    direction = rig.pose.bones[child].head-p.head
    q=direction.normalized().rotation_difference((target-p.head).normalized())
    result=q.to_matrix().to_4x4() @ m
    result.translation=m.translation
    p.matrix=result
    bpy.context.view_layer.update()

def solve_arm(rig, side, wrist, hand_rotation):
    first='DEF-upper_arm.'+side; second='DEF-forearm.'+side; hand='DEF-hand.'+side
    head=rig.pose.bones[first].head.copy()
    a=(rig.data.bones[second].head_local-rig.data.bones[first].head_local).length
    b=(rig.data.bones[hand].head_local-rig.data.bones[second].head_local).length
    delta=wrist-head; distance=delta.length
    assert .01 < distance < a+b, (side,distance,a+b)
    axis=delta.normalized(); along=(a*a-b*b+distance*distance)/(2*distance)
    height=math.sqrt(max(0,a*a-along*along))
    pole=Vector((1 if side=='L' else -1,.1,-.45))
    bend=(pole-axis*pole.dot(axis)).normalized()
    aim(rig, first, head+axis*along+bend*height)
    aim(rig, second, wrist)
    matrix=hand_rotation.to_matrix().to_4x4(); matrix.translation=wrist
    rig.pose.bones[hand].matrix=matrix
    bpy.context.view_layer.update()
    STATE['max_grip_error']=max(STATE['max_grip_error'],(rig.pose.bones[hand].head-wrist).length)

def pose(slug, rig, clip, phase):
    if slug=='ember': return
    if slug=='luminary':
        for name,rotation in STATE['grip_rotations'].items():
            rig.pose.bones[name].rotation_quaternion=Quaternion(rotation)
        # One-handed staff stays upright while its grip follows the source hand.
        hand=rig.pose.bones['DEF-hand.R']
        target=hand.matrix @ Vector((0,.055,.012))
        bone=rig.data.bones['staff']
        matrix=bone.matrix_local.copy(); matrix.translation=target
        rig.pose.bones['staff'].matrix=matrix
        bpy.context.view_layer.update()
        return
    # Keep the library torso/legs. A rigid two-handed carrying pose is the only
    # anatomical motion exception; its height follows the source hands on jumps.
    chest=rig.pose.bones['DEF-spine.003'].matrix.copy()
    center=chest.translation+Vector((0,-.30,-.22))
    if clip.startswith('Jump'):
        height=(rig.pose.bones['DEF-hand.L'].head.z+rig.pose.bones['DEF-hand.R'].head.z)*.5
        center.z=max(center.z,min(chest.translation.z+.20,height))
    direction=Vector((.64,0,.76837491)).normalized()
    turn=chest.to_quaternion()
    # Keep the weapon heading with the approved small directional torso turn.
    direction=turn @ rig.data.bones['DEF-spine.003'].matrix_local.to_quaternion().inverted() @ direction
    rotation=Vector((0,0,1)).rotation_difference(direction)
    if clip=='Strike':
        angle=math.sin(phase*math.pi*2)*.65
        rotation=Quaternion((1,0,0),angle) @ rotation
        direction=rotation @ Vector((0,0,1))
    wrists={}
    for side,sign in [('L',1),('R',-1)]:
        wrists[side]=center+direction*(.13*sign)+Vector((0,.055,0))
    # Translate the complete weapon into both reach spheres without changing
    # the skeleton lengths or scaling the animation.
    for iteration in range(20):
        for side in ['L','R']:
            shoulder=rig.pose.bones['DEF-upper_arm.'+side].head
            a=(rig.data.bones['DEF-forearm.'+side].head_local-rig.data.bones['DEF-upper_arm.'+side].head_local).length
            b=(rig.data.bones['DEF-hand.'+side].head_local-rig.data.bones['DEF-forearm.'+side].head_local).length
            delta=wrists[side]-shoulder; reach=(a+b)*.92
            if delta.length>reach:
                shift=delta.normalized()*(delta.length-reach)
                center-=shift
                for s in wrists: wrists[s]-=shift
    bone=rig.data.bones['weapon']
    origin=center+direction*(.845*STATE['scale'])
    base_direction=(bone.tail_local-bone.head_local).normalized()
    q=base_direction.rotation_difference(direction)
    wm=q.to_matrix().to_4x4() @ bone.matrix_local; wm.translation=origin
    rig.pose.bones['weapon'].matrix=wm
    for side in ['L','R']:
        # Orient the palm across the shaft, keeping the actual preset hand size.
        rest=rig.data.bones['DEF-hand.'+side].matrix_local.to_quaternion()
        desired=Vector((0,-1,0))
        hand_q=(rest @ Vector((0,1,0))).rotation_difference(desired) @ rest
        solve_arm(rig,side,wrists[side],hand_q)
        for name in rig.pose.bones.keys():
            if name.endswith('.'+side) and ('DEF-f_' in name or 'DEF-thumb' in name):
                rig.pose.bones[name].rotation_quaternion=Quaternion((1,0,0),1.1 if 'thumb' not in name else .45)
    STATE['motion_exceptions']=[p.name for p in rig.pose.bones if any(x in p.name for x in ['DEF-upper_arm.','DEF-forearm.','DEF-hand.','DEF-f_','DEF-thumb'])]
    bpy.context.view_layer.update()

def record():
    return dict(STATE)
