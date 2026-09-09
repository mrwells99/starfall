"""Check Fulcrum skin, inherited gait, and mantle motion in the Blender source."""
import json
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, 'artifacts', 'fulcrum')
CLIPS = [('Idle', 60), ('Walk', 36), ('Run', 22), ('WalkBackward', 40),
         ('StrafeLeft', 34), ('StrafeRight', 34), ('Cast', 48)]
SHARED = ['root', 'pelvis', 'spine', 'chest', 'neck', 'head'] + [
    bone + '.' + side for bone in ['thigh', 'shin', 'foot', 'toe']
    for side in ['L', 'R']]
MANTLE = ['mantle' + str(i) for i in range(3)] + [
    'mantle_tip' + str(i) for i in range(3)]


def activate(rig, clip):
    assert any(track.name == clip for track in rig.animation_data.nla_tracks), clip
    for track in rig.animation_data.nla_tracks:
        track.mute = track.name != clip


def matrix_values(bone):
    return [value for row in bone.matrix_basis for value in row]


# Compare evaluated channels to Ember; names alone do not establish gait parity.
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, 'art_source', 'ember.blend'))
ember = bpy.data.objects['Ember_Rig']
baseline = {}
for name, frames in CLIPS:
    activate(ember, name)
    for frame in [1, frames // 3 + 1, 2 * frames // 3 + 1, frames + 1]:
        bpy.context.scene.frame_set(frame)
        for bone in SHARED:
            baseline[(name, frame, bone)] = matrix_values(ember.pose.bones[bone])

bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, 'art_source', 'fulcrum.blend'))
rig = bpy.data.objects['Fulcrum_Rig']
body = bpy.data.objects['Fulcrum_SkinnedModel']
scene = bpy.context.scene
os.makedirs(OUTPUT, exist_ok=True)
assert len(rig.data.bones) == 62
weapon = bpy.data.objects['Fulcrum_GravityWeapon']
assert all(abs(sum(g.weight for g in v.groups) - 1) < 0.0001 for v in weapon.data.vertices)
assert any(m.type == 'ARMATURE' and m.object == rig for m in weapon.modifiers)
for name in ['gravity.focus', 'gravity.outer', 'gravity.inner', 'gravity.debris']:
    assert name in rig.data.bones and name in weapon.vertex_groups
assert not any('hair' in bone.name.lower() for bone in rig.data.bones)
for bone in MANTLE:
    assert bone in rig.data.bones, bone
for material in body.data.materials:
    assert not any(word in material.name.lower() for word in
                   ['skin', 'hair', 'lash', 'iris', 'lip', 'eyewhite']), material.name
assert any(material.name == 'Fulcrum_SealedObsidianMask'
           for material in body.data.materials)
assert any(modifier.type == 'ARMATURE' and modifier.object == rig
           for modifier in body.modifiers), 'Mesh must deform with the rig'
bad = [vertex.index for vertex in body.data.vertices
       if abs(sum(group.weight for group in vertex.groups) - 1) > 0.0001]
assert not bad, 'Unnormalized or unweighted vertices'
used_groups = {group.group for vertex in body.data.vertices for group in vertex.groups
               if group.weight > 0}
assert all(body.vertex_groups[index].name in rig.data.bones for index in used_groups)
for bone in MANTLE:
    assert bone in [body.vertex_groups[index].name for index in used_groups], bone

report = {'weighted_vertices': len(body.data.vertices) + len(weapon.data.vertices), 'weapon_vertices': len(weapon.data.vertices), 'bones': len(rig.data.bones),
          'stance_max_error_m': {}, 'clip_loop_max_matrix_error': {},
          'mantle_walk_max_angle_radians': {}}
for name, frames in CLIPS:
    activate(rig, name)
    track = next(track for track in rig.animation_data.nla_tracks if track.name == name)
    assert len(track.strips) == 1, name
    strip = track.strips[0]
    assert abs(strip.frame_start - 1) < 0.0001, name
    assert abs(strip.frame_end - (frames + 1)) < 0.0001, name
    scene.frame_set(1)
    start = {bone.name: matrix_values(bone) for bone in rig.pose.bones}
    scene.frame_set(frames + 1)
    error = max(abs(a - b) for bone in rig.pose.bones
                for a, b in zip(start[bone.name], matrix_values(bone)))
    report['clip_loop_max_matrix_error'][name] = error
    assert error < 0.00001, (name, error)

for name, frames, stance in [('Walk', 36, .6), ('Run', 22, .38),
                             ('WalkBackward', 40, .6), ('StrafeLeft', 34, .6),
                             ('StrafeRight', 34, .6)]:
    activate(rig, name)
    errors = []
    for frame in range(frames):
        scene.frame_set(frame + 1)
        for side, offset in [('L', 0), ('R', .5)]:
            phase = (frame / frames + offset) % 1
            if phase < stance:
                errors.append(abs(rig.pose.bones['foot.' + side].head.z - .14))
    report['stance_max_error_m'][name] = max(errors)
    assert max(errors) < .02, (name, max(errors))

maximum_parity_error = 0.0
for (name, frame, bone), values in baseline.items():
    activate(rig, name)
    scene.frame_set(frame)
    maximum_parity_error = max(maximum_parity_error, max(
        abs(actual - expected) for actual, expected in
        zip(matrix_values(rig.pose.bones[bone]), values)))
assert maximum_parity_error < 0.00001, maximum_parity_error
report['inherited_gait_max_error'] = maximum_parity_error
report['inherited_gait_samples'] = len(baseline)

activate(rig, 'Walk')
scene.frame_set(1)
initial = {name: rig.pose.bones[name].matrix_basis.to_quaternion() for name in MANTLE}
for name in MANTLE:
    angles = []
    for frame in range(2, 37):
        scene.frame_set(frame)
        current = rig.pose.bones[name].matrix_basis.to_quaternion()
        angle = initial[name].rotation_difference(current).angle
        angles.append(min(angle, abs(2 * 3.141592653589793 - angle)))
    report['mantle_walk_max_angle_radians'][name] = max(angles)
    assert max(angles) > .002, ('Static mantle bone', name)

scene.cycles.samples = 12
scene.render.resolution_x = 600
scene.render.resolution_y = 760
scene.camera.location = (4, -1, 1.9)
scene.camera.rotation_euler = (Vector((0, 0, 1.1)) - scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
for name, frame in [('Walk', 10), ('Walk', 28), ('Run', 7), ('Run', 18)]:
    activate(rig, name)
    scene.frame_set(frame)
    scene.render.filepath = os.path.join(OUTPUT, name.lower() + '-%02d.png' % frame)
    bpy.ops.render.render(write_still=True)
with open(os.path.join(OUTPUT, 'motion_report.json'), 'w') as output:
    json.dump(report, output, indent=2)
print('FULCRUM_MOTION_VERIFIED', json.dumps(report))
