# Starfall Model Forge v2 — accepted procedure

## Authority and deliverable

The owner approved Fulcrum through **r008** and selected this as the default for all future class models on 2026-09-09. They explicitly excluded the reverted r006 and r007 changes. Use this procedure, the frozen source archive, runtime contract, feedback ledger and new class reference together. New explicit owner instructions take precedence. The old Character Forge v1 anatomy/gait and zero-blend defaults are historical, not the template for new characters.

Deliver an actual editable **Blender** character, packed materials, deformation rig, integrated equipment, named animations, skinned **GLB**, working **Godot** presenter and interactive review. Use installed Blender/bpy; a generated picture is not the model. Smooth continuous preset anatomy, shaped armor and articulated hands replace the old blocky procedural-body approach.

The reference determines costume, silhouette, palette, ornaments, head treatment and weapon. Fulcrum's purple armor, sealed mask and gravity orb are class identity, not mandatory equipment for every future class. Preserve the production method and accepted animation. Remove hidden head/hair geometry when a sealed hood or helmet would otherwise clip; an exposed-face reference remains a separate design choice. Text describing abilities in reference art does not authorize implementing gameplay.

Installation of the requested class is reversible by default; preview first if specifically requested. Keep visible Blender/Godot work on the owner's second monitor. Do not alter other classes, game physics/combat, commit/push or deploy merely to package or install a character.

## Frozen source and preparation

Run `tools/model_forge_snapshot.py --verify` first. It checks ordered archive parts, their combined ZIP, every member hash, the compressed contract and frozen workflow files. It pins the accepted arm-layer hash and rejects reverted-revision paths. Do not repair a damaged baseline by silently replacing it with live files.

Extract to a new empty staging directory with `--extract`. The project-relative layout allows an isolated Fulcrum control rebuild. Exact preserved inputs and outputs include:

- `art_source/fulcrum.blend`: approved editable final model.
- `art_source/fulcrum_ual/fulcrum_ual.blend`: matching fitted source.
- `art_source/fulcrum_ual/costume_source.blend`: immutable approved costume/weapon before fitting. Never replace it with an already fitted output.
- `art_source/fulcrum_ual/AnimationLibrary_Godot_Standard.glb`, `QUATERNIUS_LICENSE.txt`, `recipe.json`: actual downloaded mannequin/library, supplied CC0 license, input hashes, core rest matrices and clip mappings.
- `assets/characters/fulcrum.glb`, `fulcrum*.png` and import metadata: approved game export and textures.
- `tools/build_fulcrum_ual.py`: final fitter, source-motion baking, directional body turns and export.
- `scripts/fulcrum_art.gd`, `fulcrum_jump_pose.gd`, `fulcrum_pose_blend.gd`: all three are required for the accepted behavior.

The original `build_fulcrum.py`, `fulcrum_details.py` and `fulcrum_weapon.py` preserve costume/material construction and orbital equipment. Their old intermediate body and seven-clip gait are **not** the final v2 standard. For exact Fulcrum reproduction, use the immutable costume input and final UAL fitter. For another class, author reference-specific costume against preset landmarks and retain the actual mannequin anatomy.

Start a class record from `new_character.template.json`. Record slug, reference, silhouette, materials, face treatment, equipment/grips, baseline archive hash, tool versions, stage/source/export/runtime paths and intentional exceptions. Inspect current project instructions/status. Back up each changed path with SHA-256, including manual Blender edits; record new paths. Audit every hardcoded class/output/source name in adapted builders and runtimes. Use isolated, class-specific staging. Selected archived game scripts are integration context, not permission to overwrite newer gameplay. The snapshot is not a complete game checkout.

## Anatomy and costume fitting

Use the actual Quaternius Standard mannequin: **53 core bones**, unchanged rest matrices, parents and proportions. Retained mannequin vertices remain unchanged; the mannequin supplies the undersuit and articulated fingers. Fulcrum removes only the covered head. Its **83 total bones** include 30 costume/weapon controls; other equipment may need a different number of extras. Extra controls must not change core rest anatomy or invent a new gait.

Fit costume to actual joint landmarks and head envelope, preserving costume UVs/materials/details. glTF bone tails are importer display heuristics, not anatomical endpoints. In the accepted fitter, the head envelope ends at Blender Z **1.8291782140731812**. The old costume-group mapping is in the preserved recipe.

For exact Fulcrum costume fitting, the builder uses radial factors .84 for limbs, .76 for pelvis/spine/chest, .88 for neck/head and costume-root scaling (.8,.9,.9). These are costume adjustments, not mannequin scales or mandatory factors for a differently shaped outfit. New designs still fit the same mannequin rather than reshaping the mannequin to fit armor.

Use shaped surfaces, thickness, bevels and layered armor; preserve articulation and coverage at shoulders, elbows, wrists, hips, knees and ankles. Weight rigid plates to supporting bones and flexible layers across relevant joints. Decorations follow their garment weights. Every exported vertex must have finite valid weights summing to one within **1e-4**. Core bind/rest transforms agree within **1e-6**. Use extra controls for robe/mantle/hem and equipment. Check seams and intersections while moving, not only in a neutral pose.

## Materials and texturing

Fulcrum establishes the accepted surface quality: worn blackened gunmetal, muted bronze/pewter, leather, violet/ash woven cloth, dark lining, obsidian and restrained violet emission. New class colors and surface roles follow its reference. Preserve detail quality, not a universal purple palette.

Use actual UVs and portable Principled materials, image-based base color/roughness/normal detail, packed images in Blender, and embedded/exported textures in GLB. The accepted recipe contains five **1024×1024** source maps: violet weave, ash cloth, steel color, steel roughness and fabric normal. Original Python seed **41**, NumPy generator seed **83**. Record deliberate palette, seed or map changes for new classes. Roughness and normal maps are Non-Color. The compressed contract records actual image hashes/colorspaces/sizes and material values/node connections; frozen bytes are authoritative for reproducing Fulcrum.

Preserve extracted PNGs and `.import` files. Inspect the actual Godot export beside Blender: image-buffer/color-space conversions previously changed apparent darkness. Do not silently change the accepted texture-buffer method during a control rebuild. If a new recipe needs another method, record and visually verify it. Make weave, roughness and metallic highlights readable at gameplay distance, with emission low enough to retain detail.

## Source animation and direction variants

The supplied Standard library contains **46 source animations**. The accepted export has **32 clips**: eleven selected motions plus twenty-one derived variants. It has no independent native backward/strafe mocap; these are derived from the supplied walking/jogging/sprinting clips.

| Game clip | Source | Nominal duration |
| --- | --- | --- |
| Idle | Idle_Loop | 2.5s |
| Walk | Walk_Loop | 1.333333s |
| Run | Jog_Fwd_Loop | .933333s |
| Sprint | Sprint_Loop | .666667s |
| CastEnter, Cast, CastRelease, CastExit | Spell_Simple_Enter, Spell_Simple_Idle_Loop, Spell_Simple_Shoot, Spell_Simple_Exit | .533333, 2.1, .5, .433333s |
| JumpStart, JumpLoop, JumpLand | Jump_Start, Jump_Loop, Jump_Land | 1.333333, 2.5, 1.266667s |

Each Walk/Run/Sprint also has Backward, Left, Right, ForwardLeft, ForwardRight, BackwardLeft, BackwardRight. Walk's side names are **StrafeLeft/StrafeRight**. Preserve names and exact measured timing from recipe/contracts. Bake at **30 FPS**, **linear** keys and closing loop endpoints. One action/named NLA track per clip. CastEnter/Release/Exit and JumpStart/Land are one-shots; the rest loop. Clear sampled source actions so the export contains only selected clips.

Legs follow 90° side/45° diagonal heading. Pelvis follows **65%** of that heading. Chest/head/arms turn **20° sideways** or **14° diagonally** toward lateral travel; two spine stages distribute the remaining twist. Preserve foot paths. Reverse walking time for backpedaling; maintain backward-diagonal turn signs from the recipe. All 18 lateral variants receive the accepted body turn.

## Accepted Godot presentation

Use the exact three archived presenter modules, adapting class names/material hooks and attachment logic as needed. Blender -Y forward becomes glTF +Z; model rotation Y=PI aligns it to game -Z. Clips stay in place: actor physics owns collision, travel velocity and facing.

| Setting/behavior | Accepted value |
| --- | --- |
| Selection | Immediate measured horizontal displacement; movement threshold .12m/s; discard corrections over1m/frame |
| Direction | Eight actor-local sectors, including diagonals |
| Walk/jog/sprint thresholds | Jog above1.8m/s, sprint above5.5m/s |
| Backward sectors3/4/5 | Always reversed **Walk**, including normal/buffed speeds |
| Backpedal cadence | speed/3.8×**1.15**, clamp .55–2.5 |
| Other cadence | speed divided by1.35 walk /2.8 jog /4.4 sprint; jog/sprint multiplied by **.90**; clamp .55–2.5 |
| Cadence response | `1-exp(-delta*18)`; no change to travel speed |
| Normal pose transitions | Takeoff .08s; locomotion-to-locomotion or entering/leaving cast .12s; others .10s |
| Final r008 jump smoothing | At jump-clip boundaries, only hips/three spine joints/neck/head use **.16s**; other joints keep normal timing |
| Jump clip selection | JumpStart for at most .18s then JumpLoop; stationary landing transient .15s |

Capture the **displayed** pose before blending, including rapid reversals. Preserve gait phase between locomotion clips via deferred seek. Directional takeoff posture carries briefly into the unchanged jump; do not add a separate midair-facing system or a body apex target. The final r008 is only slightly longer transition easing.

The accepted **r002 arm layer** captures the current arm pose on takeoff and blends toward the actual JumpStart quarter pose. Weight is `clamp(1-(vertical_velocity/launch_velocity)^2,0,1)`, launch reference7m/s or greater measured launch speed. Bent elbows (~51° left /72° right in the target) remain. Arms rise toward apex and lower on descent; ground releases over.12s. Casting retains its arms. Preserve these exact rotations; do not restore the rejected enlarged shoulder sweep.

Replicated grounded/vertical speed are cosmetic inputs and never overwrite physical velocity or change the network protocol. Preserve cast enter/loop/release/exit, cancellation and instant-action triggers, including existing moving-action precedence. Stun pauses presentation; death/revival retains its visual-root handling. The gravity focus follows the corrected hand through both arm and final-pose blending, preserving orbit. Another attachment must adapt those bone lookups and compensation explicitly rather than retaining invalid Fulcrum-only assumptions.

The runtime contract fixes these settings; archived GDScript fixes implementation details. Gameplay can evolve independently without restoring old game rules to match a character snapshot.

## Equipment and secondary motion

Fulcrum's weapon is a black singularity above the left palm, with broken counterrotating rings and debris. Controls: gravity.focus/outer/inner/debris. Baked focus offset from DEF-hand.L in Blender is **(.24,-.055,.22)**; runtime adds hand corrections. Preserve costume/materials during weapon-only work.

For another class use its reference equipment: staff inside the grip, two-handed weapon in both reachable hands, or a properly attached floating effect. Keep preset anatomy; record the minimum explicit carrying-arm motion exception if required. Other gait/timing stays v2. Costume-only follow-through can reuse the preserved small robe/hem/mantle motion. This does not imply real-time cloth simulation or collision-free cloth in every extreme pose.

## Rebuild, validation, review and installation

Installed tools at approval:

- Blender **5.2.1 LTS**: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`.
- Godot **4.7.2 stable**: `C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
- Python: `C:/Users/aidan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`.

Manifest records environment hashes. Do not automatically install/downgrade unrelated software. Run background Blender with two threads while the owner games.

For an extracted **Fulcrum control reproduction**, run its copied `tools/build_fulcrum_ual.py` through Blender. It reads the preserved costume/library, saves `art_source/fulcrum_ual/fulcrum_ual.blend`, and stages `artifacts/fulcrum-turn-r004/fulcrum.glb`; it does not automatically install the live source/GLB. Require `FULCRUM_UAL_BUILD_COMPLETE`, then run copied `verify_fulcrum_ual.py` and require `FULCRUM_UAL_VERIFIED`. The old costume-generation path has a mandatory separate weapon stage; do not run that against an already equipped final model.

Compare a staged new candidate to frozen core motion using this project command, replacing the example path:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --threads 2 --python tools/model_forge_snapshot.py -- --check-candidate artifacts/CLASS-STAGE/candidate.blend
```

The check compares 53 core rest bones and all32 clips at every key/half-frame. Thresholds: rest1e-6, pose matrix components1e-5. Intentional attachment exceptions use named `--allow-motion-bone` flags plus `--reason`; they never exempt rest anatomy. New costume geometry/materials still need skin/visual checks. Rebuild serialization can differ across tool versions; use semantic contracts alongside frozen hashes.

Export selected rig/skinned geometry only, GLB, NLA_TRACKS animations, no destructive application to the bind skeleton. Check UVs, normalized finite weights, textures, hierarchy, names/loops/timing, weapon grip, seam coverage and moving foot contact. Model/skin/material counts in the captured contract describe Fulcrum, not mandatory counts for another design.

After reversible install/import into a current game checkout, run current/adapted presentation, jump-arm/cadence, pose-blend and physical jump-momentum suites. Approval checkpoint: **203/203 presentation,69/69 arms/cadence,184/184 transitions,35/35 momentum**. Counts are evidence, not quotas. Test actual evaluated poses, attachment and immediate response, not only animation names. Check success markers because Blender can exit zero after a Python failure.

Review front/back/side, idle, opposing walk/run phases, backpedal/diagonals, casts, jump/landing and interrupted transitions. Use the live Godot presenter for runtime arm/blend layers; raw Blender clips do not contain those layers. Open the actual `.blend` for editable model review. Keep previews capped at30FPS and place them on the second monitor. Here Godot **screen0** is secondary1920×1080, primary is screen1; viewers use position(1080,70), size800×850. Blender's OS secondary origin is(-1920,0); prior window placement was `-p -1880 70 1050 900`. Recheck if monitors change.

Record final source/export/runtime hashes, recipe, allowed differences, validation, visual limitations and rollback map. Update class notes and current context. Preserve v2 once frozen; later approved shared changes receive a new version. Never restore r006/r007 because an old test report happened to pass.
