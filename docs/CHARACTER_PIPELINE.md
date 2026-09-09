# Character production handoff

Latest Vanguard revision (2026-09-08): the owner supplied a new heavy crystal-armored knight reference and requested this same workflow. The live model now has a sealed T-visor crystal-crown helm, forged armor, navy embroidered tabard/cape and newly forged inset-crystal hammer. Original eight clips and 39-bone animation are preserved; six cape bones bring the total to 45. Source 123,044 triangles, six packed maps; game presentation 799/799, combat 81/81, rendered art 179/179. See [`VANGUARD_REFERENCE_REBUILD.md`](VANGUARD_REFERENCE_REBUILD.md) for current files, commands, limits and reversible backup. The older Vanguard brief is historical.

Recorded 2026-09-08 after the Ember replacement. Read this before repeating the work for another class, alongside `CONTEXT.md`, the character's art notes, and `ART_DIRECTION.md`. This is the project workflow and factual handoff. Vanguard's current helmet/hammer implementation and local tool paths are in `VANGUARD_REBUILD_BRIEF.md`. Luminary was subsequently implemented with the same process, then revised to a faceless ivory hood; its original exposed-face section is historical. Fulcrum now follows the same authored workflow; see its current section below.

## Owner's requested outcome

Use the installed Blender application and code to make a complete editable 3D character, with a deformation skeleton and complete walking animations, directly in `C:/projects/starfall`. The owner explicitly rejected blocky/voxel-looking models and rigid, janky movement. A generated picture is not the deliverable. Reference images guide the actual geometry, materials and silhouette; the animation must work in the game. "Scrap everything" was applied to the old Ember model and its presentation path, not to unrelated champions, arena work, gameplay or user edits.

The owner subsequently requested the same process for Luminary and then Fulcrum, with mostly unchanged animation and creative liberty on reference-based appearance. Preserve the approach and deliverable types, but adapt the silhouette, equipment, rig and animation to that class's supplied reference. Do not silently reuse Ember's mage costume for another class. The logging request was not visual approval. The later explicit Luminary and Fulcrum requests authorized those classes; future classes still require their own request.

## References and local environment

- Movement/model benchmark: https://www.youtube.com/shorts/iys7ZIJ1Xc0?feature=share — titled "World of Warcraft Comparison | Classic vs Retail #worldofwarcraft #wowclassic". Viewed in the browser; ordinary web fetch failed. This is a visual benchmark, not a source of copied game models.
- Ember reference originally supplied at `C:/Users/aidan/Downloads/75217cbc-ffd0-4a37-aa31-9581a77794ea.png`; preserved at `art_source/references/ember.png` so the handoff does not depend on Downloads.
- Workspace: `C:/projects/starfall`; PowerShell on Windows.
- Installed Blender executable: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`. Actual executed version: **5.2.1 LTS**.
- Godot console executable: `C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`. Actual version: **4.7.2 stable**. Older Linux paths and Godot versions elsewhere in the docs are historical.
- Renderer: Godot OpenGL Compatibility; rendered checks used NVIDIA GeForce RTX 5060 Ti. No multi-character GPU performance benchmark was performed.
- Blender ran its actual local Python API in background mode to build, export and render. The finished source was also opened in the interactive Blender application. Direct native mouse automation was not used.
- Filesystem writes/execution required the environment's approval mechanism. The user authorized direct project changes; any tool approval still required by a future environment must be handled by that environment. No Git commit, remote push, deployment or online publication was performed.

## Delivered files

| File | Purpose |
| --- | --- |
| `art_source/ember.blend` | Editable character, rig, material nodes, packed texture, animation actions/NLA tracks and inspection studio. |
| `art_source/references/ember.png` | Preserved user-supplied visual reference. |
| `assets/characters/ember.glb` | Actual imported game character, skin and animation clips. |
| `assets/characters/ember_nebula.png` | Generated 1024px UV fabric texture; also packed in Blender and GLB. |
| `assets/characters/ember_ember_nebula.png` | Godot-extracted embedded texture. Preserve its import metadata along with the asset. |
| `tools/build_ember.py` | Self-contained final build recipe, including all refinements. Rebuild overwrites the Ember outputs. |
| `tools/verify_ember.py` | Blender skin-weight and ankle-height checks plus rendered side-view motion samples. |
| `scripts/ember_art.gd` | Runtime model loading, material instances, clip choice, blending and actor presentation. |
| `scripts/champion_model.gd` | Dispatches Ember to its imported presentation; old Ember construction branch removed. |
| `tests/ember_presentation_test.gd` | Imported skeleton, skin, clip presence, loop closure, transitions and collision/transform checks. |
| `tests/ability_art_test.gd` | Existing rendered suite adapted to check Ember's authored Cast clip instead of its removed procedural left-arm joint. |
| `scenes/ember_preview.tscn` | Interactive model viewer scene. |
| `tools/ember_preview.gd` | Viewer studio, orbit camera, animation buttons, playback slider and capture option. |
| `docs/ART_DIRECTION.md` | Current Ember design, implementation summary, validation and limitations. |
| `docs/TECHNICAL_ARCHITECTURE.md` | Updated runtime file map. |
| `docs/CONTEXT.md` | Current work summary and next-session entry point. |

Relevant `.import` and `.gd.uid` files exist beside their resources/scripts. `art_source/.gdignore` keeps the editable sources out of Godot's resource import scan. `artifacts/` is an ignored review-output area, not the only location for any required runtime asset.

## Model and rig construction

The final source contains **69,923 vertices, 127,120 triangles, nine material surfaces, one joined skinned mesh and 52 bones**. Import can split vertices at surface/UV boundaries; these counts describe the Blender source. Godot's mesh import generates LODs. This is not a budget target for future classes: reduce geometry where it does not improve appearance.

The model uses smooth custom ring/grid surfaces and swept curves, not voxel blocks: tailored cuirass, fitted limbs, flat-soled boots, layered curved pauldrons, bracers, individual gloves/fingers, deep open hood with recessed celestial face, ten overlapping robe panels, bronze piping, pendants and halo. A generated UV texture supplies woven astral fabric, nebula variation and a warm hem; modeled star details and emissive trim add accents. Geometry and materials are original; no external character asset or image-generation deliverable was substituted.

Bone hierarchy: root, pelvis, spine, chest, neck, head; paired thighs/shins/feet/toes; paired clavicles/upper arms/forearms/hands; five finger bones per hand; ten robe roots and ten hem children. Torso and limb vertices interpolate weights around joints; armor pieces use appropriate rigid bone weights; cloth seams and ornamentation follow the same cloth weights so they do not detach.

Blender units are metres, Z up, -Y facing forward. The GLB export converts Y up, yielding +Z forward; the imported visual root rotates PI around Y to align with the game's -Z combat facing. Collision remains the actor's 0.42m-radius, 1.8m-height capsule. The larger hood/halo silhouette does not enlarge collision or become a clickable target surface.

## Animation implementation

All source clips use 30 fps and include matching first/last poses. Each action has its own named NLA track and exports using `NLA_TRACKS`. The source file is saved with only Walk unmuted, frames 1–37; Space in Blender plays it. To inspect another NLA clip, mute Walk, unmute that track and set the appropriate frame range. Studio objects are in `REVIEW_ONLY`; export selects only the character mesh and armature.

| Clip | Frames, including closing endpoint | Duration |
| --- | --- | --- |
| Idle | 1–61 | 2.0 s |
| Walk | 1–37 | 1.2 s |
| Run | 1–23 | 0.733333 s |
| WalkBackward | 1–41 | 1.333333 s |
| StrafeLeft / StrafeRight | 1–35 | 1.133333 s |
| Cast | 1–49 | 1.6 s |

The analytic two-bone leg solve supplies knee bends and planted ankle targets at 0.14m during stance. Swing uses eased horizontal return and vertical clearance. Walk uses a 60% stance fraction and lowered pelvis; Run uses a 38% stance fraction, longer stride, lower hips and more arm/elbow motion. Spine/chest counter-rotation, wrist/finger poses and delayed robe/hem motion supplement the legs. This is authored bone animation, not motion capture or live cloth simulation.

In Godot, `ember_art.gd` finds the imported `Skeleton3D` and `AnimationPlayer`, normalizes clip names, enables looping and advances animation manually from the actor's visual tick. Per-instance materials keep team inlays and damage/death presentation independent between actors.

Actual horizontal displacement determines movement, with corrections over 1m/frame discarded. Speed is exponentially smoothed. Cast takes precedence; movement above 0.12 selects directional clips; forward speed above 1.8 selects Run. Clip changes blend for 0.20 seconds. Cadence uses nominal speeds 3.88 for Run and 0.72 for the other locomotion clips, clamped to 0.55–1.9 and smoothed. These values are an Ember implementation, not universal settings for another character. Stun pauses advancement; death tilts the visual root; revive restores it. Combat transforms, network snapshots, abilities and movement speeds are untouched.

## Repeatable build and verification

Run these PowerShell commands from `C:/projects/starfall`, sequentially where outputs are dependencies. Do not run a rebuild and an import/test of that asset concurrently.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_ember.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/verify_ember.py
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/ember_presentation_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/combat_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/ability_art_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/ember_preview.tscn
```

The viewer offers clip buttons, mouse-drag orbit, scroll zoom, Space pause and a playback-speed slider. Add `-- --ember-capture` to save a Godot walk screenshot and quit. Screenshots are verification aids; the Blender file and integrated animated GLB are the deliverables.

Verified results on the final asset:

- Blender: all 69,923 source vertices have normalized bone weights. Maximum sampled stance ankle-height error is below 0.000001m for Walk, Run, WalkBackward and both strafes. This checks the authored ankle target, not world-space foot slip or terrain contact.
- Godot Ember presentation: **761/761**. Includes imported clips, first/last bone-pose closure, walking/strafe/backward/cast/idle transitions, defeat/revive and unchanged actor collision/transform.
- Combat regression: **81/81**.
- Rendered ability/art regression: **91/91** on the actual Compatibility renderer.
- Total reported game checks: **933**. Many are per-bone loop checks, not independent quality judgments.
- Visual inspection: front/back studio renders; side-view Walk frames 10/28 and Run frames 7/18; a real Godot viewer render. Initial refinements addressed clean-looking surfaces, subdued fabric, shoulder openings, leg reach, run stride, wrist/thumb poses and rounded boot soles.

Review outputs live in `artifacts/ember/`: `build_report.json`, `motion_report.json`, `front.png`, `back.png`, `walk-10.png`, `walk-28.png`, `run-07.png`, `run-18.png`, and `godot-walk.png`. Intermediate refinement scripts, an older `.blend1` backup and a viewport-preparation script were moved there; they are historical, and the final build script already incorporates their changes. The Godot capture predates the last boot/wrist refinement; regenerate it before citing it as the exact final appearance.

## Important limitations and lessons

The delivered model is still a simpler, smoother, stylized interpretation below the supplied reference's production surface detail. The user has not stated visual approval. Do not call passing tests proof of reference-quality art.

There is no terrain IK, live cloth collision simulation, authored jump clip, dedicated death clip, or newly implemented spell VFX from the reference sheet. High-speed backwards/sideways movement may slide because cadence is capped; preserve gameplay speed when improving this with directional stride warping. Material damage flash does not replace the base texture. Multi-character GPU profiling and high-quality optimization remain pending.

Do not blindly rerun the generator over manual edits to `ember.blend`: it recreates and overwrites its own output. Save manual refinements separately or integrate them into the build recipe first. Do not copy this script to a next class without changing all source/output names and reviewing anatomy, equipment, cloth and attachment requirements.

Windows pitfalls encountered: source line endings included CRLF; naive global text replacement matched nested `if` statements and caused a parse error. The error was corrected and final checks pass. Prefer contextual patches and verify the resulting script. A `--quit-after` frame limit can terminate a test before it prints completion; the full combat suite was rerun without that limit. Require its explicit final pass count, not just exit code zero. Use the Godot console executable for reliable logs.

The working tree already had user changes to `project.godot` and numerous existing import files before this work began. Do not revert, overwrite or commit unrelated changes. Git reported dubious repository ownership; read commands used the per-command `-c safe.directory=C:/projects/starfall` override rather than changing global configuration. No new branch or commit was created. Check fresh status before the next task.

## Starting the next class

1. Read the new user request and reference, then check that class's existing asset/art notes. Preserve unrelated finished work, including Ember.
2. Reuse the local Blender-to-GLB workflow and test patterns, while authoring the new class's anatomy, silhouette, materials, rig and motion to fit its reference.
3. Produce separately named editable source, runtime asset, reproducible builder, verifier and viewer. Keep inspection pictures separate from the requested deliverable.
4. Integrate the new class through a dedicated presentation module and remove only its superseded model branch. Retain actor/collision/UI contracts and gameplay/network behavior.
5. Inspect geometry and several animation phases in Blender and the actual game renderer. Check skin weights, loop closure, movement transitions and combat/art regressions after the final import.
6. Record limitations honestly, update current context and art notes, and open the real editable/animated result for the owner. Do not require a remote Git push or deployment merely because the user requested changes in the project folder.

## Fulcrum — authored gravity heretic (2026-09-08)

**Current status:** the refined editable source and integrated game asset have passed final verification. The actual `art_source/fulcrum.blend` was opened in the installed Blender application. The owner explicitly approved the model, colors and textures, then approved integration of the separately previewed gravity weapon. The pre-weapon version is backed up for restoration.

The owner supplied `C:/Users/aidan/Downloads/Fulcrum__The_Gravity_Heretic.png` and requested the same Blender workflow, creative liberty for the appearance and mostly unchanged animation. The exact reference is preserved at `art_source/references/fulcrum.png`. The character is original geometry built in local Blender, with a sealed angular obsidian mask, pointed dark hood, black articulated armor, jagged layered pauldrons, violet hanging stoles, a split long coat, torn three-part mantle, articulated gloves and boots, orbit-shaped relics, and a floating singularity weapon above the left palm. Its broken bronze orbital rails counterrotate around a black core with violet light and suspended fragments. There is no human facial anatomy, scalp or hair hidden beneath the hood. Narrow violet seams and black cores supply the gravity motif without adopting Ember's fire or Luminary's ivory costume.

### Files and source dependencies

| File | Purpose |
| --- | --- |
| `art_source/fulcrum.blend` | Editable mesh, rig, materials, packed textures, seven actions/NLA tracks and inspection studio. Walk is active at 30 fps, frames 1–37. |
| `art_source/references/fulcrum.png` | Preserved user reference. |
| `assets/characters/fulcrum.glb` | Skinned runtime model and animation clips. |
| `assets/characters/fulcrum_weave.png` | Violet woven cloth color texture. |
| `assets/characters/fulcrum_ash.png` | Ashen dark cloth color texture. |
| `assets/characters/fulcrum_fabric_normal.png` | Woven material microdetail shared by cloth and leather. |
| `assets/characters/fulcrum_steel.png` | Rubbed black steel color texture. |
| `assets/characters/fulcrum_steel_roughness.png` | Steel roughness texture. |
| `tools/build_fulcrum.py` | Main builder: skeleton, material/texture authoring, shared gait, export and review rendering. |
| `tools/fulcrum_details.py` | Required companion executed inside the builder context; authors Fulcrum's costume, mask, armor, mantle and relic geometry. |
| `tools/fulcrum_weapon.py` | Required second build stage: reads the staged base, adds the weapon and carrying-arm pose, then exports the final source and GLB. |
| `tools/verify_fulcrum.py` | Source weights, stance height, all-clip loop closure, moving mantle controls and inherited gait parity checks; renders side-view motion samples. |
| `scripts/fulcrum_art.gd` | Dedicated runtime presentation with immediate displacement-based locomotion/idle transitions, 0.12-second entry to Cast and independent actor materials. |
| `scripts/champion_model.gd` | Dispatches Fulcrum to its imported presentation alongside Ember, Luminary and Vanguard. |
| `tests/fulcrum_presentation_test.gd` | Imported mesh, skin, rig and clips; loop endpoints, movement/cast transitions, secondary controls, material instances and collision/transform contracts. |
| `scenes/fulcrum_preview.tscn` | Interactive animation viewer. |
| `tools/fulcrum_preview.gd` | Viewer controls, lighting and `--fulcrum-capture` support. |

All five original textures are 1024px, packed in Blender and embedded in the GLB. Keep Godot's extracted `fulcrum_*` textures and relevant `.import` metadata beside the asset; the importer may combine channels. The `REVIEW_ONLY` studio is excluded from export by selection. Final source: **83,958 vertices / 157,160 triangles / 17 material surfaces across two skinned meshes / 62 bones**. Twelve unique materials are shared across the meshes. The approved body retains 76,126 vertices and 11 surfaces; the weapon adds 7,832 vertices and six surfaces. The `.blend` is 9,480,337 bytes and the GLB is 10,530,164 bytes at verification. Import may split source vertices at UV or surface boundaries. Rebuilding overwrites this class's `.blend` and `.glb`: integrate manual edits into all three durable source scripts before rerunning them.

### Rig, motion and integration

The skeleton has **62 bones**: Ember's 52 shared controls plus `mantle0`, `mantle1`, `mantle2` and `mantle_tip0`, `mantle_tip1`, `mantle_tip2`, plus `gravity.focus`, `gravity.outer`, `gravity.inner` and `gravity.debris`. The mask and hood follow the head. Three mantle roots and their tips add delayed motion; the front coat and stoles follow shared robe weights. Armor and attached details follow their relevant body or cloth controls. There are no hair controls or carried staff.

The seven clips and durations match the table in this handoff: Idle, Walk, Run, WalkBackward, StrafeLeft, StrafeRight and Cast. The core two-bone leg solve, stance targets, torso rhythm, arm motion and directional cadence are inherited from Ember. The mantle controls extend the shared motion. The equipped version adapts the left upper arm, forearm, hand and fingers into an open, upward-cupped carrying pose; the other approved body channels are preserved to floating-point precision. The focus follows the palm while the rails and fragments orbit independently in every clip. The verifier compares 392 shared body/gait matrices against `art_source/ember.blend`; do not remove that source dependency when reproducing parity checks.

`fulcrum_art.gd` follows the current Ember responsiveness: measured displacement speed selects locomotion directly, and transitions into locomotion/Idle have zero crossfade. Entering Cast uses 0.12 seconds. Cadence remains smoothed and bounded, and displacement corrections over one metre per frame are discarded. This preserves the later movement work recorded in `CONTEXT.md`; the old shared 0.20-second transition description is historical for Ember and still applies to Luminary, not this Fulcrum module.

The runtime explicitly selects `Fulcrum_SkinnedModel` for the existing torso contract even when the weapon imports first. It retains the established import-facing correction, team inlays, Cast override, stun pause, damage flash, defeat tilt and revive reset. Animation advances manually from the visual tick. Actor collision, targeting, movement speeds, mechanics, network state and existing spell VFX are unchanged. The reference sheet's ability illustrations guide this character's visual identity; they are not new ability implementations.

### Rebuild and review

Run sequentially from `C:/projects/starfall` so import and tests use the completed asset:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_fulcrum.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/verify_fulcrum.py
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/fulcrum_presentation_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/combat_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/ability_art_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/fulcrum_preview.tscn
```

The viewer provides clip buttons, drag orbit, scroll zoom, Space pause and playback speed. Add `-- --fulcrum-capture` to capture and quit. Review outputs belong in ignored `artifacts/fulcrum/`: `build_report.json`, `motion_report.json`, `front.png`, `back.png`, `walk-10.png`, `walk-28.png`, `run-07.png`, `run-18.png` and `godot-walk.png`. These are inspection aids; the editable animated Blender source and integrated game asset remain the deliverables.

Final verification after approved weapon integration:

- Blender verified normalized skin weights on all **83,958 vertices**, **62 bones**, seven closing clip poses with maximum matrix error below **1.75e-7**, and stance ankle-height error below **2.83e-7 m**.
- **392 inherited core-gait matrices match Ember within 1.79e-7** after pose rebaking. All six weighted mantle controls move during Walk, with sampled maxima approximately 0.067–0.199 radians.
- Final Godot import exited successfully; **Fulcrum presentation 1,068/1,068**, **combat 81/81**, and **rendered ability/art 179/179** passed on the final runtime module. Total: **1,328 game checks**. Fourteen added assertions check one-frame starts, stops and direction changes plus immediate imported-pose equality, detecting unintended locomotion crossfades. The art suite now covers the expanded class kits, so its count differs from the older Ember and Luminary runs.
- Front/back studio renders, Walk frames 10/28, Run frames 7/18 and a real Godot viewer capture were inspected from the same final asset. Final refinements closed the mask shell into the hood, corrected hood-binding placement and replaced rectangular mantle cutouts with irregular tear contours.

The source stance check measures authored ankle targets, not world-space foot slip or terrain contact. Many game assertions are per-bone loop checks; they are not independent assessments of visual quality.

The owner approved this stylized interpretation of the reference. Bone-driven cloth has no live collision simulation; terrain foot IK, dedicated jump/death clips, high-speed backward/sideways stride correction and multi-character GPU/LOD profiling remain open. Test counts establish functional checks, not reference-quality artistry. Changes are saved directly into the project folder; this request does not require a Git commit, remote push or deployment.

### Weapon preview, preservation and undo

The owner initially requested review before integration or a way to revert, and subsequently explicitly authorized merging the weapon. The separate study remains at `artifacts/fulcrum_weapon_review/fulcrum_weapon_preview.blend`, with a standalone comparison viewer. Live integration occurred only after that authorization. No Git merge, commit or remote push was performed.

`artifacts/fulcrum_before_weapon/` preserves the approved pre-weapon `.blend`, `.glb`, import metadata, build files, presentation/verifier/tests and documentation, at their original relative paths. `original_manifest.json` records their SHA-256 values; `installed_manifest.json` records the equipped state for safe comparison before a future restore. Newer unrelated edits must be preserved when restoring.

The complete command `build_fulcrum.py` first writes the base to `artifacts/fulcrum/base_fulcrum.blend`, then invokes `fulcrum_weapon.py` to produce the live equipped outputs. Do not run the weapon stage against an already equipped source; it asserts the absence of the new controls. All three source scripts are required. Hand-maintained changes should be folded into the appropriate stage before rebuilding.

`approved_body_preservation.json` records exact equality of the body vertex coordinates, topology, material assignments, surface settings and packed texture images against the backup. Rebuilding introduced only a maximum UV rounding difference of 1.1921e-7, below 0.00013 texel at 1024px. Existing locomotion/robe/other-arm channels differ by at most 2.683e-7 from the approved base; only the left carrying arm and new weapon controls are intentionally changed. Weapon skin weights, exported orbit motion and all clip loops pass. This is a cosmetic weapon, with no new collider, damage rules or ability behavior.

## Luminary current hood revision — 2026-09-08

**Current authority:** after the initial Luminary delivery, the owner asked for an Ember-like hood in Luminary's style, no facial features, no protruding hair, and removal of hair if needed. The current files implement that request. Do not recreate the historical face/hair when rebuilding.

The face/head surface, eyeballs, lids, brows, lashes, nose/nostrils, lips, ears, scalp, exposed neck and all silver hair locks were removed from `tools/luminary_details.py`. Two hair bones and their animation channels were removed from the main builder. This is geometry removal, not visibility toggling or covering an existing human head. The remaining 59-bone rig preserves the other animation channels.

The replacement is an ivory outer hood with 6mm shell thickness, dark lining, double gold binding, lunar embroidery, ivory cowl, repositioned celestial halo and a recessed dark cloth veil shaped to the opening. The veil has no eyes or other facial relief. The whole hood is weighted to the head. Initial inward surface winding caused the lining to face outward; the final builder reverses winding before adding thickness and sizes the veil from the hood opening, preventing it from covering the border.

All existing Luminary source/runtime paths and build commands remain applicable. The source now has **79,301 vertices / 150,476 triangles / 13 surfaces / 59 bones**. Historical source counts, byte sizes and hair-control descriptions below are obsolete for the current asset. Rebuild still requires both `build_luminary.py` and `luminary_details.py`; verifier still uses Ember for parity. The staff grip, cape motion, seven clip durations and gameplay integration are unchanged.

Final post-revision checks: **865/865 Luminary**, **81/81 combat**, **91/91 rendered art**. Fewer per-bone loop assertions reflect the removed hair bones, not dropped animation coverage. Blender verified normalized weights on all 79,301 vertices, absent hair controls/facial materials, stance ankle errors below 0.000001m and zero difference across 392 sampled core-gait matrices. Front/back, walk/run side samples and the final Godot capture were visually inspected after correcting the shell. Review outputs in `artifacts/luminary/` now show the hooded version.

Remaining limitations concern ornament/fabric fidelity, non-simulated cape motion, high-speed backward/sideways foot sliding and pending GPU/LOD profiling. Facial or hair refinement is no longer a pending task: their removal was requested. No new spell VFX, gameplay changes, Git commit or remote push were part of this revision.

## Luminary initial exposed-face version — historical, superseded by hood revision

The user supplied `C:/Users/aidan/Downloads/f4d5374a-7a27-4216-95e6-eb923ad93a90.png` and explicitly asked for the exact same workflow/process, mostly the same animations, and a Luminary-specific appearance with creative liberty. The reference is preserved at `art_source/references/luminary.png`. It informed a new exposed female face, silver hair, ivory/gold plate, lunar tabard and cape, celestial halo and carried staff. The character geometry is original and the result remains stylized rather than matching the reference's production detail.

### Files and source dependencies

- `art_source/luminary.blend`: editable source, Walk active, 30 fps, frames 1–37, inspection studio in `REVIEW_ONLY`.
- `assets/characters/luminary.glb`: imported game asset, 8,846,492 bytes at final verification.
- `assets/characters/luminary_silk.png` and `luminary_celestial.png`: packed 1024px textures. Godot also extracts `luminary_luminary_silk.png` and `luminary_luminary_celestial.png`; preserve relevant import metadata.
- `tools/build_luminary.py`: full class build orchestration, inherited gait generation, export and studio rendering. It executes the required companion `tools/luminary_details.py`, which builds the face, hair, cape, tabard, lunar ornaments, relics and staff in the builder context. Both files are required to reproduce the source. This is not an instruction to rerun the intermediate preparation scripts.
- `scripts/luminary_art.gd`: dedicated runtime presentation, copied from Ember with its own asset path; same displacement-based clip selection, 0.20-second blending and cadence limits.
- `scripts/champion_model.gd`: early Luminary build/animation dispatch. The older generic geometry remains for the fallback champion, but Luminary no longer uses it. Ember's asset, builder and presentation module were not modified.
- `tools/verify_luminary.py`: verifies its source rig/weights/stance, compares sampled core gait to `art_source/ember.blend`, and renders side-view walk/run samples. Requires both source files for the parity comparison.
- `tests/luminary_presentation_test.gd`: imported skeleton/skin/clips/loop endpoints, attachment-bone presence, runtime transitions and preserved collision/transform.
- `tests/ability_art_test.gd`: accepts either Luminary's or Ember's authored Cast clip when checking a skinned champion; other champions retain the procedural arm check.
- `scenes/luminary_preview.tscn` / `tools/luminary_preview.gd`: orbit viewer and clip controls. Default distance 4.6m and target height 1.22m keep the staff in view; the studio uses lower, cooler lighting for ivory armor.

### What stayed the same and what changed

The final source has 114,991 vertices, 216,098 triangles, 19 material surfaces, one joined skinned mesh and 61 bones. The 52-bone Ember hierarchy is retained and nine controls are added: staff, hair.L/R, cape0/1/2 and cape_tip0/1/2. The original core leg/root/body animation code and all seven clip durations remain the same. The gait comparison samples root, pelvis, spine, chest, neck, head and both thigh/shin/foot/toe chains at four frames per clip (392 bone-frame matrices), with zero local matrix difference.

Luminary's staff-side arm uses an additional two-bone solve to keep the hand and pole clear of the shoulder, and the staff bone counter-rotates to remain mostly upright. The grip is baked into every clip; it is not a runtime attachment script or collider. The free arm retains the shared gesture/swing pattern. Hair and cape use small delayed oscillations. These differences are intentional adaptations permitted by the user's instruction that animations stay mostly the same.

Design refinements during inspection narrowed the initially broad cape, added pointed cape ends and a central navy lunar strip, closed more of the scalp, smoothed hair-lock paths, narrowed the eye aperture, subdued fabric color variation and added staff-lens tracery. The final Godot preview was recaptured after fixing its initially cropped staff and overly bright ivory lighting. Do not characterize the exposed face or hair as final production-quality art.

### Commands and verified results

Run from `C:/projects/starfall`, using the same local executables listed above:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_luminary.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/verify_luminary.py
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/luminary_presentation_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/ember_presentation_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/combat_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/ability_art_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/luminary_preview.tscn
```

Append `-- --luminary-capture` to the viewer command to save its rendered walk frame and quit. Controls match Ember: animation buttons, drag to orbit, scroll to zoom, Space to pause and a playback slider. Godot and Blender visual outputs are inspection evidence; the real source and animated runtime asset are the deliverables.

Final verified results: normalized skin weights on all 114,991 source vertices; maximum sampled stance ankle-height error below 0.000001m; 392 core-gait matrices identical to Ember; Luminary 893/893, Ember 761/761, combat 81/81, rendered art 91/91. The 1,826 game checks include many per-bone loop assertions and do not measure artistry. The Blender stance check does not establish ground-relative foot-slip elimination.

`artifacts/luminary/` contains build/motion reports, front/back renders, Walk 10/28 and Run 7/18 side views, and the final `godot-walk.png`. Preparation/integration/refinement scripts there are historical and ignored; the durable builder and companion already contain their changes. The working tree was clean at the start of the Luminary request. No Git commit, remote push or deployment was performed.

Remaining limitations: face/hair and ornaments are simpler than the reference, no facial animation, bone-driven cloth/hair without collision simulation, no terrain foot IK, inherited high-speed backward/sideways foot sliding, and no new spell VFX from the concept sheet. The 216k-triangle source also needs deliberate performance/LOD profiling before calling it optimized for multiple characters. Preserve the collision, targeting and server-authoritative gameplay contracts when refining any of these.
