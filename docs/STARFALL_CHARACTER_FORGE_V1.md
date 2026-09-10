# Starfall Character Forge — Version 1

**Named workflow:** Starfall Character Forge v1  
**Invocation:** “Use Starfall Character Forge v1 for [class] with this reference.”  
**Reusable skill:** `$starfall-character-forge`  
**Frozen checkpoint:** 2026-09-08, after the crystal-armored Vanguard delivery.  
**Project:** `C:/projects/starfall`.

This is the historical character-production procedure. **[Starfall Model Forge v2](STARFALL_MODEL_FORGE_V2.md) is the approved default for new work.** Use v1 only when explicitly requested. The detailed recipes, exact delivered files, original references, and animation contracts are archived with it. Read this file and verify the archive before starting; do not reconstruct the process from conversation memory.

## Contents

1. Fixed outcome and scope
2. Frozen package and reproducibility
3. Baseline choice and current class differences
4. Preparation and reversible staging
5. Modeling, costume, face and weapon rules
6. Materials, UVs and portable textures
7. Rig and animation contracts
8. Blender export and source setup
9. Godot integration and responsiveness
10. Verification and visual review
11. Delivery and logging
12. Recovery, versioning and known limits
13. Commands and new-class record

## 1. Fixed outcome and scope

The owner wants a complete, smooth, non-voxel 3D character built with the installed Blender application and code. Deliver the actual editable model, textures/materials, skeletal rig, walking animations, integrated equipment and working project asset. A concept illustration, screenshot, generated image, capability statement or unfinished plan does not satisfy this request.

The supplied class artwork controls visual identity. Creative liberty is allowed for modeling decisions that serve the reference and playable silhouette. Animation should stay mostly the same as the selected established baseline. “Same workflow” means the same source/build/export/review/integration process and delivery standard; it does not mean putting every class in Ember's robe, adding Vanguard's hammer to every class, or importing existing commercial game models.

The video originally linked by the owner, `https://www.youtube.com/shorts/iys7ZIJ1Xc0?feature=share`, is a benchmark for complete models and fluid movement, not a source of assets. Its historical inspection is recorded in `CHARACTER_PIPELINE.md`. No copy of the video is included. Use the actual archived models and clips for reproducibility; if making a new claim about the video, inspect it then rather than assuming access from this record.

Stay within the requested character's presentation. Preserve combat rules, actor collision, network snapshots, movement speeds, targeting, IDs, mechanics, unrelated characters and other working-tree edits. Ability panels on reference sheets are visual context, not automatic instructions to implement all those attacks. A project-folder installation is not a Git commit, remote push, deployment or publication.

## 2. Frozen package and reproducibility

Package: `art_source/workflows/starfall-character-forge-v1/`.

| File | Purpose |
| --- | --- |
| `starfall-character-forge-v1.tar.xz` | Losslessly recompressed sources, GLBs, references, maps/import metadata, builders, viewers, verification code, shared integration context, logs and original workflow. All 309 internal files retain their original bytes and project-relative paths. |
| `manifest.json` | Unchanged original file checksums, sizes and environment fingerprint; its ZIP name/hash describe the original container for provenance. |
| `storage.json` | Current tar.xz and compressed-contract checksums, archive size, original manifest checksum and compression details. |
| `contracts.json.xz` | Losslessly compressed animation record from all four final Blender files: rig hierarchy/rest transforms, mesh counts/material names, skin-weight errors, named clips, frame ranges and every bone's evaluated basis matrix at every authored frame. The archive also contains its original uncompressed copy. |

The archive is a character workflow/source snapshot, not a full backup of the complete arena, all game assets, installed applications or the computer. Shared game code is included as integration context, not permission to replace the live project's current gameplay. `art_source/.gdignore` excludes it from Godot import. Keep the entire package together when copying it to another machine, along with the current `tools/character_forge_snapshot.py` recovery helper.

**Local storage only (owner request, 2026-09-09):** the entire v1 folder is ignored by Git and removed from the current index. It is no longer included in normal future commits or clones. Copy the folder separately for backup or use on another computer. Earlier commits and their original Git LFS objects are historical and were not rewritten. The current compressed package needs only standard Python; no LFS download or external archiver is required. The original ZIP was replaced after complete checksum and recovery verification; archived source bytes and animation data are unchanged.

Verify using `tools/character_forge_snapshot.py --verify`. Its `--compare-live` mode reports changed or missing live paths without changing them. Differences are expected after future development; inspect them and preserve newer work. The creation mode refuses to overwrite a completed version-1 package. Original asset bytes can be recovered exactly from the verified archive. Rebuilding can change serialization metadata, image encodings, or floating-point results across application versions; compare semantic contracts and visuals rather than claiming byte-identical regeneration. New designs also require artistic decisions, so an identical future visual result cannot be guaranteed by a text file. This package fixes the concrete starting assets and makes changes detectable.

Local tools at the checkpoint:

- Blender `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`, executed version **5.2.1 LTS**.
- Godot console `C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`, **4.7.2 stable**.
- Godot OpenGL Compatibility, NVIDIA GeForce RTX 5060 Ti, driver shown by the review as 616.64.
- Windows/PowerShell. Blender's bundled Python and NumPy perform geometry, textures and export. No external model service, downloaded mesh or image-generation model substitutes for geometry.
- `manifest.json` records executable hashes, actual build/version identifiers, Python and NumPy versions. Preserve these versions for closest reproduction; if unavailable, document the replacement and revalidate. Do not install or downgrade unrelated system software automatically.

## 3. Baseline choice and current class differences

Use the current frozen `.blend`, builders and runtime together. Old documentation contains historical states; the contracts and archived current code resolve those discrepancies.

| Baseline | Visual identity and attachments | Final source checkpoint |
| --- | --- | --- |
| Ember | Dark hood, recessed celestial face, bronze armor/halo, layered burning astral robe; unarmed casting silhouette. | 52 bones, 69,923 vertices, 127,120 triangles, 9 surfaces. |
| Luminary | Ivory/gold hood and cowl, recessed featureless dark veil, halo, long celestial cape and staff. Human face, scalp, exposed neck and hair geometry were removed. | 59 bones, 79,301 vertices, 150,476 triangles, 13 surfaces. |
| Fulcrum | Black/violet hooded armor, sealed obsidian mask, torn mantle/stoles, floating black singularity with broken orbital rails and fragments above the cupped left palm. | 62 bones, 83,958 vertices, 157,160 triangles, 17 surfaces over 2 skinned meshes; 12 unique materials. |
| Vanguard | Sealed T-visor crystal-crown helmet, dark plate, violet crystals, navy compass tabard/cape and two-handed framed crystal hammer. | 45 bones, 67,095 vertices, 123,044 triangles, 8 surfaces. |

These counts describe preserved outputs, not minimum complexity requirements or a target for every new class. Machine-read counts in `contracts.json` are authoritative if a stale note differs. Do not automatically grow every character to the most expensive baseline.

For a new mage-like class, use Ember's shared core gait and the closest relevant attachment strategy. Fulcrum demonstrates a floating weapon; Luminary demonstrates a staff. For a two-handed heavy melee class, Vanguard preserves two-handed grip and Strike. For an existing class revision, preserve that class's own baseline. Record this choice before copying files; if the requested class cannot be inferred or existing design decisions conflict, ask a focused clarification while doing independent preparation.

Required build dependencies:

- Ember: `tools/build_ember.py`.
- Luminary: `tools/build_luminary.py` executes `tools/luminary_details.py` in its builder context.
- Fulcrum: `tools/build_fulcrum.py` executes `tools/fulcrum_details.py`, saves a base to `artifacts/fulcrum/base_fulcrum.blend`, then runs `tools/fulcrum_weapon.py`. The weapon stage reads that base, adapts the carrying arm and adds four controls. It asserts that the weapon controls are absent. Never run it against an already equipped final source.
- Vanguard: `tools/build_vanguard.py` executes `tools/vanguard_materials.py`, `tools/vanguard_details.py`, then `tools/vanguard_weapon.py`. The separate `vanguard_hammer_weapon.blend` is historical standalone equipment and is not the current character builder's weapon dependency.
- Luminary/Fulcrum verification uses `art_source/ember.blend` for inherited gait comparison. Vanguard verification additionally uses the earlier Vanguard `.blend` under `artifacts/vanguard_before_reference/` when present; that baseline file is included in the archive to retain the comparison.

## 4. Preparation and reversible staging

1. Read this workflow, manifest/contracts, the relevant current class section, actual builder and runtime, and project instructions. Verify frozen ZIP integrity before using it. Inspect the user reference rather than relying on its filename or embedded text. Preserve a copy under `art_source/references/<class>.png`.
2. Inspect fresh project status and class dispatch. Record existing unrelated modifications. For Git ownership checks use a per-command `-c safe.directory=C:/projects/starfall`, not a global ownership/config change.
3. Record the baseline class, its clip durations/rig and the allowed changes: appearance, equipment, cloth controls, carrying arm if required. Preserve all other inherited animation channels. Choose a unique lowercase class slug and class-specific paths.
4. Back up every existing path to be overwritten at its original relative path inside `artifacts/<class>_before_<revision>/`. Include source, GLB, reference, import metadata, maps that will change, build companions, runtime, tests, viewers and affected documentation. Record SHA-256 and absence of newly created paths. Include manual `.blend` edits; a generator overwrites its output.
5. Default to a reversible installation, as in the delivered workflow. If the user asks to inspect before integration, build/export under a staging root and use a dedicated preview; defer changes to live asset paths/dispatch until authorized. Do not impose another approval round when the user already authorized integration or accepted a rollback copy.
6. For a new class, copy/adapt required files into class-specific paths; review every hardcoded source/output/reference name, node name, material prefix, staged base path and companion import. Never blindly replace the class name throughout unrelated files or rerun a baseline builder against the baseline's live paths.

## 5. Modeling, costume, face and weapon rules

Translate the reference into a written silhouette checklist: head/hood/helmet, shoulder mass, torso taper, armor layering, glove articulation, separate legs/boots, cloth length and cuts, major emblems, palette, crystal/light accents, and equipment. Build complete front, side and back geometry; the output must hold up when orbiting and walking.

Use smooth custom mesh grids/rings, tailored swept surfaces and curves, beveled thick plates and deliberately faceted crystal shards. Preserve continuous underlying anatomy or armored joint coverage, correct surface winding, overlapping joints and flat boot soles. Avoid voxel/block assembly, disconnected wrists, unsupported floating armor, broad concave nonplanar n-gons that triangulate into spikes, and unexplained large intersections. Curved sabaton patches replaced malformed pointed toe polygons in Vanguard.

Separate cloth, dark joint leather, worn metal, warm alloy, crystal, team inlay and emission roles. Keep fingers/gloves articulated around actual grip coordinates. Weight armor rigidly to the correct bone; interpolate organic/flexible joints. Model trim, rivets, embroidered motifs and hanging relics to follow the same weights as their supporting panel, preventing detached decorations.

Face rules are class-specific. Preserve the final Luminary hood/featureless veil and remove hair/face geometry rather than merely hiding it beneath a hood. Fulcrum's sealed mask has no human face/hair underneath. Vanguard has a helmet and T seam, not an Ember hood. Ember's recessed cosmic face treatment is its own design. For a future class use its explicit direction; do not assume all faces must be removed solely because Luminary's were.

Weapon treatment is part of the full model. Match the supplied weapon silhouette and placement, preserve existing approved body geometry/materials for weapon-only revisions, and add an attachment/bone strategy appropriate to the object. For rigid two-handed weapons drive both hand targets from one weapon transform, constrain that transform to reachable arm space, and verify both contacts throughout all clips. For a staff keep the shaft inside the closed grip. For floating weapons attach a focus to the palm, use separate orbit controls for moving pieces, and keep their motion looped. No weapon collider or damage timing change follows from a cosmetic mesh addition.

Vanguard's current hammer uses rest head `WH=(0.74,-0.40,2.10)`, normalized direction `WD=(0.64,0,0.76837491)` and grips `WH-WD*0.68` / `WH-WD*1.01`. Its new rectangular metal frame and inset crystal windows replaced the character's previous oversized purple spiked mallet without changing the existing grip/weapon animation. Reuse that binding method only for suitable equipment; do not reintroduce the old mallet by appending its standalone source.

## 6. Materials, UVs and portable textures

Build actual Blender materials and UV maps; do not rely on a beauty-render-only shader that disappears in GLB. Use Principled BSDF with direct image connections for base color, roughness, normal and crystal emission. Explicitly assign UVs: suitable longitudinal grids for cloth/limbs and coherent local mapping for plates and crystals. Normalize skin weights independently of UV seams. Use shared surfaces where reasonable and independent material instances per actor at runtime.

The latest Vanguard baseline has six 1024px maps: steel color, steel roughness, celestial alloy color, cloth color, woven normal and fractured amethyst. The maps use seeded NumPy patterns, scuffs/pits, woven gradients and warped Voronoi crystal fractures. Keep deterministic seeds from the chosen builder; record new class-specific seeds if different. Vanguard uses Python seed 91 and NumPy seed 928. Earlier mage builders use Python 41; Ember/Luminary texture seed 41 and Fulcrum texture seed 83. Exact recipes are archived, not approximate prose specifications.

**Color conversion pitfall:** use `bpy.data.images.new(..., float_buffer=True)` when writing linear color arrays as in `vanguard_materials.py`. Set roughness/normal maps to Non-Color before assignment. Save PNG, pack the image, and verify the exported image/imported material. Earlier byte-buffer generation made the game much darker than the in-memory Blender render. The final Vanguard float-buffer implementation fixes that. Do not silently rewrite preserved older classes merely to adopt this correction; apply the working recipe to new work and compare in both renderers.

Keep emission restrained enough to preserve crystal fractures and readable metal silhouettes. Separate small team accents from the class's defining palette. Do not replace the authored maps through obsolete shader-name matching. With texture-backed white albedo multipliers, a white damage flash multiplier alone changes nothing; add temporary emission and restore original emission/enabled/energy values as in Vanguard, with per-actor isolation checks.

Retain packed images in `.blend` and embedded images in GLB. Preserve generated PNGs, Godot-extracted `<class>_<texture>.png`, their `.import` files and script `.gd.uid` metadata. No runtime dependency may exist only inside ignored `artifacts/`.

## 7. Rig and animation contracts

Blender units: metres, Z up, -Y forward. Root stays at origin. Shared hierarchy uses root → pelvis → spine → chest → neck → head, paired thigh/shin/foot/toe chains, clavicle/upper-arm/forearm/hand chains, finger controls, then class-specific cloth/equipment controls. Read exact rest matrices and names from `contracts.json`; do not eyeball them from the screenshot.

Each used vertex group must map to a real deform bone. Every exported vertex is weighted and weights sum to one within `1e-4`. Attach cloth ornamentation with identical local weight functions. Extend the baseline with new cloth/weapon controls without inserting transforms that silently disturb inherited rest poses. Save a bone mapping and record all intentional carrying-arm changes.

All clips are authored at 30 fps with a closing endpoint. Each action has a named NLA track. Duration is `(last_frame-first_frame)/30`, not frame count divided by 30.

| Clip | Ember / Luminary / Fulcrum | Vanguard |
| --- | --- | --- |
| Idle | 1–61, 2s | 1–61, 2s |
| Walk | 1–37, 1.2s | 1–37, 1.2s |
| Run | 1–23, 0.733333s | 1–25, 0.8s |
| WalkBackward | 1–41, 1.333333s | 1–41, 1.333333s |
| StrafeLeft / StrafeRight | 1–35, 1.133333s | 1–37, 1.2s |
| Cast | 1–49, 1.6s | 1–49, 1.6s |
| Strike | Not present | 1–25, 0.8s; runtime one-shot |

The mage core gait uses an analytic two-bone leg solve, stance ankle targets at 0.14m, eased swing return/clearance, 60% walk stance and 38% run stance, lowered pelvis, spine/chest counter-motion, and delayed robe/hem motion. Preserve the full recipe and timing; matching clip names alone is insufficient. Vanguard has its own heavy gait and analytic two-hand weapon solve. Its original 39 controls remained unchanged, with six cape controls added, verified over 12,168 original bone/frame samples.

Compare inherited core animation against the frozen chosen baseline at each authored keyframe. Compare `matrix_basis` with maximum absolute component tolerance `1e-5`; verify rest matrices, parent names and clip ranges separately. Permit changes only on recorded equipment/carrying/secondary controls. Also sample between keys and transitions visually; frame checks do not establish interpolation quality by themselves. For different proportions explicitly retarget while preserving timing and stance logic, then test contact; do not claim numerical parity for intentional retargeting.

## 8. Blender export and source setup

Use the installed Blender executable in background mode with the durable builder. Temporary refinement experiments can live in `artifacts/`, but incorporate every final correction into the builder/companions before completion. Rebuild from those scripts to ensure the delivered source is reproducible; do not leave a manual patch as an undocumented dependency.

Join/organize material surfaces, correct normals, attach Armature modifiers and retain required UVs. Export only selected character meshes and rig: GLB, skins, animations, `export_animation_mode='NLA_TRACKS'`, Y-up conversion, no studio objects. Current recipes use `export_apply=False`. Match the chosen recipe unless a tested change requires otherwise.

Create the studio separately under `REVIEW_ONLY`. Save source with only Walk unmuted at 30 fps, frames 1–37; set an unclipped material viewport, sensible camera and selected rig/model. Packed source should open ready for inspection. Front/back studio renders and moving poses are review evidence. Keep lights/camera/floor out of the game asset. Open the final file in interactive Blender after checks, not only the background process.

## 9. Godot integration and responsiveness

Import GLB before running presentation tests. Discover `Skeleton3D` and `AnimationPlayer`; normalize clip names, enable loops for standard clips and leave Strike one-shot. Apply visual root Y rotation PI: Blender -Y exports as glTF +Z, while combatants face -Z. Preserve the torso/mesh contract; Fulcrum selects its named body mesh even if its weapon imports first.

Use a dedicated `<class>_art.gd` or established equivalent (`vanguard_authored.gd`), dispatched from `scripts/champion_model.gd`. Update only relevant build/animate/hit hooks. Duplicate materials per actor and preserve base colors/emissions for team, flash, defeat and restoration. Advance animation manually once from the actor visual tick. Actor/global transforms must remain untouched by visual animation.

**Actual current runtime differences — do not use the older generic prose blindly:**

| Behavior | Ember / Fulcrum | Luminary | Vanguard |
| --- | --- | --- | --- |
| Speed selection | Current measured displacement | Exponential smoothing, factor `1-exp(-delta*12)` | Current measured displacement |
| Locomotion/Idle crossfade | 0s | 0.20s | 0s |
| Enter Cast | 0.12s | 0.20s | 0.12s |
| Cadence nominal Run / other | 3.88 / 0.72 | 3.88 / 0.72 | 2.74 / 0.54 |
| Cadence clamp | 0.55–1.9 | 0.55–1.9 | 0.55–2.4 |

All measure horizontal displacement, discard corrections above 1m/frame, select movement above 0.12 and forward Run above 1.8. Local lateral displacement dominates when `abs(x)>abs(z)*1.15`; positive local Z selects backward. Cadence smoothing uses `1-exp(-delta*10)`. Cast takes precedence over normal movement. Stun pauses playback, defeat tilts only the visual root, and revive resets it. Preserve the chosen current runtime, not an invented universal blend value. For new mage classes use current Ember/Fulcrum immediate responsiveness unless directed otherwise; keep Luminary's current behavior when merely reproducing Luminary.

Vanguard's confirmed-hit response starts at 0.16s into Strike, lasts 0.64s, blends in over 0.055s and uses speed scale 1 during Strike. Ward follows `actor.shield`; initial pulse lasts 0.45s; recoil follows HP loss, not healing. These are presentation contracts, not new hit-authority or combat timing logic.

## 10. Verification and visual review

Run the durable Blender verifier on the final source, then import, then class presentation tests. Run combat regression when integrating runtime/dispatch changes and the rendered art suite on the actual Compatibility renderer. Dependent operations are sequential: never import while that asset is being rebuilt. Require explicit completion/pass markers and inspect warnings/errors; zero exit alone is not proof a test finished. Do not impose `--quit-after` that cuts off a suite.

Check skin coverage/normalization, valid groups, packed maps/UVs, expected bone hierarchy and clips, start/end pose closure, inherited animation parity, wrist/weapon grip, stance clearance and weighted secondary motion. Sample moving soles; do not describe ankle-height tests as complete ground-slip or terrain-IK validation. Vanguard's current thresholds include `1e-5m` grip error, `1e-4` weight error, sampled soles above -0.005m, loop tolerance from the archived verifier and model-plus-rings below 130,000 triangles. Current actual errors are much smaller. Other class budgets remain class-specific.

Game checks cover skin import; clip timing and looping; forward, run, backward and both strafe transitions; immediate starts/stops/direction changes when applicable; cast and strike; stun pause/resume; death/revive; unchanged capsule and actor transform; no mesh collision objects; material isolation; imported texture presence; secondary motion; and any shield/recoil/flash behavior supported by the class. Compare equivalent evaluated poses, not just chosen animation strings.

Inspect front/back/side and at least two opposing Walk phases, two Run phases and a relevant cast/strike/weapon pose. In the real viewer, orbit/zoom, switch clips, pause and vary speed. Check armor/cloth seams, planted feet, gait weight, heel/toe clearance, closed hands around equipment, fingers/wrists, cape lag, face coverage, hair absence where required, crest/weapon clipping, silhouette and readable surface detail. Compare Blender and game materials; the color-conversion error was visible only in the game. Review the model under actual arena lighting and at gameplay distance, not solely a flattering studio angle. Record limitations instead of declaring tests proof of visual quality.

Frozen last reported functional checkpoints: Vanguard 799/799 + combat 81/81 + rendered art 179/179; Fulcrum presentation 1,068/1,068; Luminary hood presentation 865/865; Ember earlier presentation 761/761. These are recorded historical results, not tests rerun during workflow archiving or required counts for a differently sized future rig. The latest source contracts are captured fresh. Add meaningful checks for new attachments rather than matching an arbitrary pass total.

## 11. Delivery and logging

Deliver `art_source/<class>.blend`, `assets/characters/<class>.glb`, source maps/import metadata, preserved reference, durable builder/companions, runtime integration, verifier/presentation tests and interactive preview. Include a record of the source baseline, permitted animation changes, exact counts, version/seed/tool settings, tests run, final renders inspected, backup path, installed hashes and remaining limitations.

Update current context, class art/architecture notes and the shared character pipeline without erasing other classes. Clearly mark superseded descriptions. Preserve a list of newly added files. Keep test/render artifacts separate from required runtime resources. Recheck changed-file scope and formatting; do not revert pre-existing `project.godot`, other-character import metadata or unrelated changes. Do not stage/commit everything as a convenience.

Open the actual `.blend` and model viewer for the owner. Say what was built, whether it is staged or installed, which animations were preserved and how to revert. Link the actual deliverables and log. Do not return a generated picture as the product, claim the owner approved unseen work or imply Git publication happened.

## 12. Recovery, versioning and known limits

Original rollback manifests record pre-change bytes; installed manifests record what this task put in place. Before restoring, compare current hashes to installed hashes to detect later edits. Restore only intended class paths, merge shared docs/dispatch selectively, reimport and retest. Leave unrelated files intact. Never unpack a whole archive over the live project without inspecting its scope. A model-only recovery can use the frozen `.blend` and GLB; exact game behavior may also need the matching presentation module and importer version.

Version 1's frozen contents are immutable by convention plus hash verification, not protected against deliberate disk deletion. The owner authorized lossless storage recompression and Git exclusion on 2026-09-09; this changes the container only. Keep an independent copy if long-term storage is needed. V2 contains the newer approved standard; do not refresh v1 from the live tree or silently update its references/animations. The archive verification command detects corruption; it does not authorize a full-project overwrite. Recover with the current helper into an empty directory and select the needed files from there; the older helper inside the archive describes the original ZIP format.

Known product limitations remain: stylized geometry simpler than the concept illustrations, no terrain foot IK, no real-time cloth collision, no dedicated jump/death clips, no mocap, potential extreme-speed backward/sideways foot sliding and no multi-character GPU benchmark. Those are not features to invent or claims to conceal. Improve them only within a later requested scope and preserve the baseline for comparison.

Prior owner usage preference was to stop at 90% of the active five-hour usage window and log completed/unfinished work, without redeeming a reset. Query a current available window rather than applying old 89% readings to a new session; unavailable data is not a usage reading. This preference does not replace actual system permissions or authorize a reset. Tool permissions may differ next session; continue authorized reversible work and handle real tool restrictions without inventing extra approval rounds.

## 13. Commands and new-class record

Archive verification uses standard Python; creation and contract capture use Blender. Command paths are literal and should be checked if the project moves.

```powershell
# Read-only archive integrity and optional live-drift check.
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' tools/character_forge_snapshot.py --verify
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' tools/character_forge_snapshot.py --compare-live

# Recover original files into an empty directory, without overwriting live work.
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' tools/character_forge_snapshot.py --extract artifacts/forge-v1-recovery

# Example complete Vanguard build; do not execute over manual edits without backup.
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python tools/build_vanguard.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python tools/verify_vanguard.py
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/vanguard_presentation_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/combat_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/ability_art_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tools/vanguard_review.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/vanguard_preview.tscn
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' art_source/vanguard.blend
```

Other classes use their corresponding builder, verifier, presentation suite and preview. Only Fulcrum's main builder automatically executes the separate staged weapon pass; do not omit its companion. Viewer flags such as `-- --vanguard-capture` capture and exit; omit them when opening the interactive viewer for the user.

For each future class, write a short implementation record with these fields before/through the work: class slug and display name; reference path; baseline archive SHA and class; tool versions; visual checklist; preserved clip/bone mapping; permitted changed controls; material maps/seeds; build dependency list; source/GLB/runtime/viewer paths; before and installed manifests; numeric checks; actual renderer; final reviewed views; known limits; integration state and user approval state. This makes deviations explicit and allows a future session to continue without guessing.
