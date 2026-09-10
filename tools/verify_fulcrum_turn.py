"""Compare the revised directional poses with the accepted pre-turn animation."""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'artifacts/fulcrum-turn-r004'
recipe=json.loads((ROOT/'art_source/fulcrum_ual/recipe.json').read_text(encoding='utf-8'))
labels=[n for n,s in recipe['animations'].items() if s['heading_degrees']]
phases=[0,.25,.5,.75,1]
def sample(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    rig=bpy.data.objects['Fulcrum_UAL_Rig']
    result={}
    for label in labels:
        for track in rig.animation_data.nla_tracks: track.mute=track.name!=label
        strip=next(t for t in rig.animation_data.nla_tracks if t.name==label).strips[0]
        poses=[]
        for t in phases:
            frame=strip.frame_start+(strip.frame_end-strip.frame_start)*t
            bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
            poses.append({p.name:p.matrix.copy() for p in rig.pose.bones})
        result[label]=poses
    return result
old=sample(OUT/'before/art_source/fulcrum.blend')
new=sample(ROOT/'art_source/fulcrum_ual/fulcrum_ual.blend')
leg_error=0.0; upper_error=0.0; pelvis_error=0.0; weapon_error=0.0
headings={}
for label in labels:
    spec=recipe['animations'][label]
    travel_left=label.endswith('Left')
    degrees=(20 if abs(spec['heading_degrees'])==90 else 14)*(1 if travel_left else -1)
    expected=Matrix.Rotation(math.radians(degrees),4,'Z')
    pelvis=Matrix.Rotation(math.radians(-.35*spec['heading_degrees']),4,'Z')
    for a,b in zip(old[label],new[label]):
        for name in a:
            if any(part in name for part in ['DEF-thigh','DEF-shin','DEF-foot','DEF-toe']):
                leg_error=max(leg_error,max(abs(x) for row in (b[name]-a[name]) for x in row))
        for name in ['DEF-spine.003','DEF-head','DEF-upper_arm.L','DEF-upper_arm.R','DEF-hand.L','DEF-hand.R']:
            upper_error=max(upper_error,max(abs(x) for row in (b[name]-expected@a[name]) for x in row))
        pelvis_error=max(pelvis_error,max(abs(x) for row in (b['DEF-hips']-pelvis@a['DEF-hips']) for x in row))
        weapon_error=max(weapon_error,(b['gravity.focus'].translation-b['DEF-hand.L'].translation-Vector((.24,-.055,.22))).length)
    headings[label]=degrees
assert leg_error<1e-5,leg_error
assert upper_error<1e-5,upper_error
assert pelvis_error<1e-5,pelvis_error
assert weapon_error<1e-5,weapon_error
result={'passed':True,'directional_clips':len(labels),'phases_per_clip':len(phases),'leg_motion_max_component_error':leg_error,
        'upper_body_turn_max_component_error':upper_error,'pelvis_alignment_max_component_error':pelvis_error,
        'weapon_to_hand_offset_max_error_m':weapon_error,'upper_body_headings':headings}
(OUT/'turn-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('FULCRUM_DIRECTIONAL_TURN_VERIFIED',json.dumps(result))
