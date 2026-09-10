# Fulcrum — Universal Animation Library pass r001

**Approved successor workflow, 2026-09-09:** the owner accepted r008 and selected the accumulated r001–r005 plus r008 work as the default for future classes. [Starfall Model Forge v2](STARFALL_MODEL_FORGE_V2.md) freezes the accepted sources and runtime. Reverted r006/r007 are excluded. Earlier experimental/pending wording below records history and is superseded by this approval.

Recorded 2026-09-09. Installed locally for owner review; this is an experimental successor to Fulcrum's old animation workflow, not an approved replacement for Character Forge v1 across all classes. Base commit: `921935073ec71ede5dcad7893e23ae14a97e5d6c`. No commit, push or deployment performed.

## Owner feedback revision r008 — slight jump transition smoothing

The owner reverted r006 and r007, then requested a small amount of smoothing of the existing head/torso jump animation, allowing subtle adaptation to takeoff direction. Those rejected pose/shoulder revisions remain reverted. This pass changes transition timing only: `JUMP_BODY_BLEND_SECONDS = 0.16` in `fulcrum_art.gd` applies when entering, changing or leaving a Jump clip. `fulcrum_pose_blend.gd` uses this duration for hips, three spine joints, neck and head while other joints keep their existing 0.08–0.12s transition. Including the hips keeps the torso's anchor moving coherently. The original target pose is reached on time, with no custom apex pose, height curve, joint offsets, altered shoulder motion, or persistent body filter.

Blends capture the displayed pose, including the accepted sideways/diagonal turn at takeoff, so that facing carries briefly into the jump. Existing directional clips, actor facing/motion, arm layer, cadence, bone hierarchy, Blender source and GLB are unchanged. The independently parented weapon continues following the blended hand. Ordinary non-jump transitions retain their previous duration.

Validation: **184/184 transition checks**, **69/69 jump-arm/cadence**, **203/203 presentation**. New checks verify the extra torso easing while the arm finishes on its original schedule and the unchanged target pose is reached within 160ms. A 60Hz before/after frame comparison measured maximum single-frame rotation across the six body joints: forward **17.83° → 16.60°**, left **22.86° → 17.26°**, backward diagonal **16.48° → 11.89°**. Durations 0.14/0.16/0.18s were compared; 0.16s was the smallest sampled duration that reduced the peak in all three cases. This remains deliberately modest smoothing, not elimination of all rapid authored movement or a performance benchmark.

Native Compatibility captures of the final running jump were inspected. `artifacts/fulcrum-jump-smoothing-r008/review.gd` runs forward/left/backward-diagonal jump cycles through the actual presentation on the second screen, with pause/speed controls and a 30 FPS cap. Launch with Godot `--path . --windowed --screen 0 --rendering-method gl_compatibility --script res://artifacts/fulcrum-jump-smoothing-r008/review.gd`; `-- --smooth-capture` records a short capture sequence. This optional review is not a production dependency. Before files, final hashes and frame comparison live in the same revision directory. Restore only its manifested files to undo this pass; no new production files were added. Owner visual approval is pending; Forge v1 remains frozen.

## Owner feedback revision r005 — short pose transitions

The owner likes the responsive animation selection but requested a small amount of smoothing between every animation so transitions feel believable without delaying direction changes or travel speed. This revision keeps selection immediate and blends the **final displayed skeleton pose**, after the runtime jump-arm layer. It replaces the earlier mixture of AnimationPlayer crossfades and immediate phase seeks with one transition controller, `scripts/fulcrum_pose_blend.gd`.

Transitions take **0.08 seconds into takeoff**, **0.12 seconds between locomotion clips or into/out of casting**, and **0.10 seconds for other changes**, including idle and landing. They use a smoothstep blend with a fixed endpoint, not a long trailing filter. Gait phase is retained when changing movement clips, using a deferred pose seek. If another input arrives mid-transition, the new blend begins from the current displayed pose, so rapid reversals do not restart from an older clip. All 83 skeleton bones participate, including costume and weapon orbit controls. The independently parented gravity focus follows the blended hand with a smoothly interpolated attachment offset. Stun pauses transitions alongside playback; death/revival retain their existing presentation-only host tilt behavior. The game actor's transform, facing, velocity and combat timing are untouched.

Cadence now approaches its requested rate slightly faster (exponential response 18 rather than 10) to keep speed changes responsive. The requested 0.90 running multiplier, 1.15 normal backpedal cadence, reversed walking clips, bent-elbow jump arc and r004 directional upper-body turns remain intact. This is a runtime change; no new Blender/GLB clip bake was needed. Keep `fulcrum_pose_blend.gd` alongside the current runtime scripts when reproducing the accepted behavior.

The ordinary clip viewer uses the same transition controller. The new **`tools/fulcrum_transition_review.gd`** runs the real presentation selector through an automatic sequence of walking, jogging, sprinting, side steps, backpedal diagonals, idle, jumping, casting/recovery and rapid reversals. It inherits the second-screen review scene, provides pause/playback-speed controls, and is capped at 30 fps. Its movement signals are simulated in place for inspection; this is not a physical match benchmark. Launch it with the same Godot script invocation as other previews; add `-- --transition-capture` for beginning/middle/end captures of a direction change.

Validation: **179/179 transition checks** covering all 32 clips, visible-pose continuity, intermediate poses, bounded completion, interrupted transitions, weapon attachment, immediate direction selection, physical-transform/velocity isolation, casting, stun and takeoff. Existing suites still pass **203/203 presentation**, **69/69 jump/cadence**, and **35/35 physical jump momentum**. Native Compatibility transition captures were inspected, and the capture run completed cleanly after correcting a preview-only teardown callback. No clean GPU/frame-time benchmark was performed while the owner was gaming. Before-edit copies, installed hashes and review files are in `artifacts/fulcrum-blend-r005/`.

This feedback is recorded as the next Fulcrum preference. The owner mentioned recreating the workflow folder after this adjustment; the frozen Forge v1 and existing shared workflow standards have not been replaced yet.

## Owner feedback revision r004 — upper-body directional turn

The owner requested a slight turn from the hips upward toward sideways travel instead of a torso locked forward over sideways-running legs. This revision is baked into the actual Blender/GLB directional clips, so it is visible both in game and in the ordinary clip viewer. It preserves the r002 runtime jump-arm layer and r003 reversed-walk backpedal selection/cadence.

For all walking, jogging and sprinting side steps, the chest, shoulders, arms and head turn **20 degrees toward lateral movement**. Forward and backward diagonals use **14 degrees**, with backward diagonal upper-body heading explicitly following lateral travel rather than the reversed gait's foot-facing direction. The pelvis uses 65% of the directional leg heading, and the two intermediate spine bones share the remaining pelvis-to-chest rotation evenly. This reduces the previous pelvis-to-chest mismatch without rotating the game actor or changing facing controls. Feet and leg motion keep their prior global paths. Costume bones inherit the adjusted body pose and the independent gravity focus is baked against the revised hand position. The mannequin rest anatomy, mesh design, colors and materials remain unchanged.

All 18 clips with a left/right component were revised; straight forward/backward, idle, casting and jumping source clips are unchanged. The exported set still contains 32 clips. Both live files are updated: `art_source/fulcrum.blend` and `assets/characters/fulcrum.glb`, with the matching editable candidate under `art_source/fulcrum_ual/fulcrum_ual.blend`. Source hashes, pelvis and upper-body headings are recorded in `recipe.json`. The current build, verification and native review tools now stage into **`artifacts/fulcrum-turn-r004/`**; earlier stage paths in this document describe previous revisions. Do not install the old r001 staged GLB when rebuilding the current revision.

`tools/verify_fulcrum_turn.py` compares all 18 changed clips at five phases against the preserved prior model. Maximum leg-motion matrix-component difference is **1.34111e-6**; upper-body rotation difference from the requested turn is **1.07289e-6**; pelvis-alignment error is **4.17233e-7**; weapon-to-hand offset error is **8.68273e-7 m**. The original anatomy verifier also passes with zero rest-transform and retained-body-vertex error, and unchanged sampled source-motion error of 1.31130e-6 for the eleven original motions. These checks establish the intended pose changes and preserve the source anatomy; they are not an exhaustive garment-intersection or multiplayer-performance certification.

Godot import passed, followed by **203/203 presentation** and **69/69 jump-arm/cadence checks**. Native Compatibility side-step and diagonal captures were inspected. The live viewer can start on `RunLeft` using `-- --side-turn-review`; choose `RunRight`, either `Strafe` clip or a diagonal in its dropdown to compare. It uses the established second-screen layout. The updated editable Blender candidate was also opened with second-screen placement arguments. Prior copies and hashes are in `artifacts/fulcrum-turn-r004/before/`; installed hashes and verification reports are in the parent folder. Existing r001/r002/r003 rollback history is retained.

## Owner feedback revision r003 — walking backpedal

The owner requested the walking gait, slightly faster and reversed, for backward movement and both backward diagonals; slowing down the jogging gait does not satisfy this direction. Actor-local backward sectors now always select `WalkBackward`, `WalkBackwardLeft` or `WalkBackwardRight`, including at buffed speeds. These existing clips are already derived from reversed `Walk_Loop`; do not reverse playback again. The original Run/Sprint backward clips remain available in the source library viewer but are no longer selected for gameplay backpedaling.

Normal backward travel remains **3.8 m/s**, while the backward walking clip plays at **1.15x** its original cadence. Slows and speed buffs scale this cadence proportionally, within the existing 0.55–2.5 playback limits. Forward and sideways jogging/sprinting retain r002's 10% slowdown. The jump-arm refinement and physical movement code are unchanged. Because direction is measured in actor-local space, turning the character preserves the correct backward diagonal selection.

The standard Fulcrum viewer applies 1.15x to the three `WalkBackward*` clips; launch with `-- --backpedal-review` to start on straight backpedaling and use the dropdown for either diagonal. The viewer remains on the second display. Validation: **203/203 Fulcrum presentation** and **69/69 jump-arm/cadence checks**, covering all eight movement sectors at walking/jogging/sprinting speeds, turned backpedal directions, normal backward cadence and unchanged physical velocity. Prior files and hashes are preserved in `artifacts/fulcrum-backpedal-r003/before/`. No model, texture, Blender or GLB changes were needed.

## Owner feedback revision r002 — jump arc and running cadence

The owner liked the first pass, then requested arms that rise with the jump, peak at the apex, return on descent, and retain visibly bent elbows. They also requested slightly slower running animation with identical movement speeds. These preferences currently apply to Fulcrum; do not silently generalize them to other classes.

`scripts/fulcrum_jump_pose.gd` now layers only the two arm chains over the existing jump clips. It captures the current arm pose at takeoff and blends toward the actual library `JumpStart` quarter pose, whose elbow bends measure approximately 51 and 72 degrees. This replaces the straighter airborne-loop arm pose. The blend follows `clamp(1 - (vertical_velocity / launch_velocity)^2, 0, 1)`: lowered near takeoff, highest at zero upward speed, then lowered during descent. The reference launch speed is the game's current 7 m/s; faster launches use their measured speed. This follows the normalized ballistic height for constant gravity. Landing releases the layer over 0.12 seconds. Casting retains its own arm pose; stun preserves the previous frozen presentation. Bones, anatomy and gameplay physics are unchanged. The independently animated gravity focus receives the same translation correction as the left hand, retaining its existing orbit.

Remote actors use vertical velocity already present in snapshots, stored separately for presentation; this never replaces the actor's physical velocity. No wire-protocol change is involved. The new motion is a runtime layer, so the original Blender/GLB clips remain intact: inspecting a raw jump clip alone will not show the layer. The dedicated `tools/fulcrum_jump_review.gd` viewer exercises the live presentation through a complete jump arc, with pause and playback-speed controls on the second display. Run it with the same Godot invocation as the review tool above, substituting this script; add `-- --capture` for the six takeoff/ascent/apex/descent/return/landing captures.

Jog and sprint playback, including all their directions, now use a **0.90 cadence multiplier** after the existing speed-to-animation mapping. Walking, spell and jump playback rates are unchanged. Actual character travel speed, jump velocity and air momentum are unchanged. The ordinary 32-clip viewer also applies this multiplier to Run/Sprint previews and labels its jumps as source clips.

Validation: **69/69 jump-arm/cadence checks**, **194/194 Fulcrum presentation**, **35/35 physical jump-momentum checks**. Checks cover increasing/decreasing arc weights, actual wrist elevation, bent elbows, original pose recovery, apex hold independent of clip time, weapon offset, remote velocity isolation, and 10% slower jogging/sprinting without altered walking/physics. Native Compatibility captures were inspected, including the bent apex and descending arms. Before-edit copies, hashes and captures are in `artifacts/fulcrum-jump-r002/`; use this revision's backup to undo only these refinements and keep the approved r001 model. Full multi-peer visual and uncontended frame-time benchmarking remain outside this revision's validation.

## Owner direction and design contract

Use the downloaded library's actual preset anatomy and animations. Fit the established Fulcrum armor to that mannequin instead of inventing another human body. Preserve the hood, sealed mask, dark layered armor, purple cloth/materials and integrated gravity weapon. Apply suitable walking, running, sideways, backward, diagonal and casting motion. Treat the earlier Forge as production guidance, with its original anatomy/gait requirements explicitly superseded for this pass. Keep Blender and visible Godot reviews on the second screen while the owner plays another game.

The fitted costume retains the original mesh details, UVs and materials. The mannequin supplies the undersuit and articulated fingers; its covered head is removed so no face or hair shows through the sealed mask. The original costume's curled single-bone fingers are replaced by the preset fingers. The hood is fitted using the mannequin's actual head envelope, not the arbitrary tail length of an imported head bone. The gravity orb, broken orbit rails and debris remain, following the left hand with separate orbit motion.

## Preset provenance and preserved anatomy

The supplied `Godot/AnimationLibrary_Godot_Standard.glb` is Quaternius Universal Animation Library Standard: 46 source animations and 53 bones. The supplied CC0 license is preserved alongside the source copy. Unity and Unreal downloads were left untouched. The source SHA-256 and all core rest matrices are in `art_source/fulcrum_ual/recipe.json`.

All 53 preset bone rest transforms and parent relationships remain unchanged. Retained mannequin body vertex coordinates remain unchanged. Thirty additional controls deform only the costume, cloak and gravity weapon, giving 83 bones total. Armor fitting uses bone landmarks and costume-only scaling. No independent anatomical redesign, procedural replacement gait, or alterations to the original mannequin's proportions are used.

The saved Blender verification compares the candidate against a fresh import of the actual library. Maximum rest transform error: **0**. Retained mannequin vertex error: **0 m**. Maximum normalized skin-weight error: **1.78814e-7**. Maximum sampled source pose matrix-component error: **1.31130e-6** across all 53 bones, 11 source clips and five phases per clip. These metrics verify anatomy and source-pose preservation; they do not certify collision-free cloth or every interpolated pose.

## Animation selection

Thirty-two exported clips comprise eleven selected source motions and twenty-one derived directional variants. The Standard download has no native strafe, backward or diagonal clips; do not describe these adaptations as additional library presets.

| Game clip(s) | Library source | Treatment |
| --- | --- | --- |
| Idle | Idle_Loop | Source motion |
| Walk | Walk_Loop | Source motion; preferred over Formal Walk for this armored caster |
| Run | Jog_Fwd_Loop | Source motion |
| Sprint | Sprint_Loop | Source motion; used at normal full forward game speed |
| WalkBackward, StrafeLeft/Right, WalkForwardLeft/Right, WalkBackwardLeft/Right | Walk_Loop | Seven directional variants |
| RunBackward/Left/Right/ForwardLeft/ForwardRight/BackwardLeft/BackwardRight | Jog_Fwd_Loop | Seven directional variants |
| SprintBackward/Left/Right/ForwardLeft/ForwardRight/BackwardLeft/BackwardRight | Sprint_Loop | Seven directional variants |
| CastEnter | Spell_Simple_Enter | One-shot anticipation |
| Cast | Spell_Simple_Idle_Loop | Sustained casting loop |
| CastRelease | Spell_Simple_Shoot | One-shot release |
| CastExit | Spell_Simple_Exit | Recovery or interrupted-cast exit |
| JumpStart | Jump_Start | One-shot takeoff |
| JumpLoop | Jump_Loop | Airborne loop |
| JumpLand | Jump_Land | One-shot landing |

Directional variants turn lower-body heading by 45 or 90 degrees while tapering rotation through the spine and retaining upper-body facing. Backward variants reverse the source cycle; backward diagonals also rotate heading. The original anatomy is preserved. These are practical adaptations for owner review, not separately authored lateral mocap.

Source poses are baked at 30 fps with linear interpolation and closing loop endpoints. Default Bezier interpolation caused measurable source-pose drift and was removed. Added cloth motion is modest follow-through; weapon orbit controls are independent of anatomical clips. The exact source mappings, durations and loop flags are recorded in the recipe.

## Runtime behavior

`scripts/fulcrum_art.gd` selects eight actor-local movement sectors. Speeds above 1.8 m/s select jog; above 5.5 m/s select sprint. Existing gameplay speed is 6.5 m/s forward and 3.8 m/s backward. Cadence follows measured speed, and directional changes preserve cycle phase with a 0.07-second blend. Other transitions blend over 0.10 seconds. The game actor controls movement and facing; clips are in place and never drive collision or velocity.

Casting enters the spell loop, releases on completion, and recovers. An interrupted cast exits without a release gesture. Existing cooldown/GCD changes trigger stationary instant-cast gestures, including off-GCD actions with a cooldown change. Moving locomotion takes precedence over cosmetic instant-cast recovery. There is no independent moving upper-body casting layer in this revision.

Takeoff, apex, descent and landing have separate handling. Remote actors interpolate positions without running local floor-contact physics: `combatant.receive()` retains the existing snapshot's grounded value for presentation, and local simulation clears that cosmetic override. No new snapshot fields, RPCs or gameplay rules are introduced. Stun pauses playback; impact, death and revival presentation remain. The gameplay capsule stays 0.42 m radius and 1.8 m height.

## Files and reproduction

- Live editable source: `art_source/fulcrum.blend`.
- Live game asset: `assets/characters/fulcrum.glb` (12,923,064 bytes).
- Preserved input costume, library, CC0 license, fitted source and recipe: `art_source/fulcrum_ual/`.
- Build: `tools/build_fulcrum_ual.py`; inspect: `tools/inspect_fulcrum_ual.py`; verify: `tools/verify_fulcrum_ual.py`.
- Runtime: `scripts/fulcrum_art.gd`, plus cosmetic ground-state handling in `scripts/combatant.gd` and `scripts/arena.gd`.
- Interactive viewer: `scenes/fulcrum_preview.tscn`, `tools/fulcrum_preview.gd`.
- Automated native review: `tools/fulcrum_ual_review.gd`.
- Tests: `tests/fulcrum_presentation_test.gd` and updated Fulcrum anticipation expectation in `tests/ability_art_test.gd`.

From the project directory, with the preserved inputs present:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 4 --python tools/build_fulcrum_ual.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 4 --python tools/verify_fulcrum_ual.py
```

Check the success markers and verification JSON, not only Blender's exit code: Blender can return zero after a Python assertion fails. The builder stages the GLB in `artifacts/fulcrum-ual-r001/fulcrum.glb` and saves `art_source/fulcrum_ual/fulcrum_ual.blend`. It does not install them automatically. Review before copying these two outputs to the live paths. Do not replace `costume_source.blend` with a later fitted output: it is the immutable input for this recipe.

Native review commands, using the installed Godot 4.7.2 executable, from the project directory:

```powershell
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --windowed --screen 0 --rendering-method gl_compatibility res://scenes/fulcrum_preview.tscn
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --windowed --screen 0 --rendering-method forward_plus --script res://tools/fulcrum_ual_review.gd -- --arena
```

The viewer exposes all 32 clips, replay and speed controls. Drag to orbit, wheel to zoom and Space to pause. It is capped at 30 fps. For this machine, Godot screen **0** is the secondary 1920x1080 display to the left; screen 1 is the primary 2560x1440 display. Preview position is (1080,70) within the secondary display. Recheck indices on a different monitor arrangement. Blender was launched with its own `-p -1880 70 1050 900` placement arguments and the live source; window presence was confirmed, but automated screenshot inspection of that window timed out awaiting app permission. The Godot preview log confirms screen 0 and 32 loaded clips. No primary-screen user app was closed or moved.

## Validation and practical limits

Blender 5.2.1 LTS; Godot 4.7.2 stable. Final checks: **194/194 Fulcrum presentation**, **195/195 native Compatibility ability art**, **81/81 combat**, **35/35 jump momentum**. Class identity also passed **91/91** earlier in the pass. Headless import succeeded. Actual Forward+ arena idle, sprint and casting captures completed and were inspected; the renderer reported the pre-existing seven-texture-RID teardown warning. Compatibility review used NVIDIA RTX 5060 Ti, driver 616.64. Source-library candidate poses and fitted front/back, locomotion and casting were inspected. Verification and captures reside in `artifacts/fulcrum-ual-r001/`.

There is no clean 3v3 GPU/frame-time benchmark for this revision: the owner is playing another game and the editor remains open. Do not claim hitch elimination or reuse older Vanguard performance results as proof for this model. Full live multiplayer artistic review, exhaustive garment intersection review, terrain foot IK, real-time cloth collision and an independent moving upper-body cast layer are not completed features. Native preview and automated snapshot tests are not a multi-peer visual acceptance test. Owner acceptance of the adapted side/back steps remains pending.

## Reversible installation and workflow status

Before-install originals and SHA-256 hashes are in `artifacts/fulcrum-ual-r001/before/manifest.json`. `installed-manifest.json` in the parent directory records this pass's installed file hashes. Before rollback, verify backup hashes and compare each current file to its recorded installed hash. If a current file differs, preserve that later edit and merge deliberately rather than overwriting it. Restore only listed originals, then let Godot reimport the restored GLB. Added tools and documentation can remain as inactive history; do not reset the repository or remove the user's library downloads. Backups are local ignored artifacts and will not travel in Git; preserve them separately if transferring the project.

The frozen Character Forge v1 archive was verified: 309 files, 190,094,806 archive bytes. It remains unchanged. This pass is a candidate refinement; record the owner's specific feedback here before promoting it into a shared character workflow. No other class has been converted.
