# Cosmic Sanctum — graphics handoff

Updated 2026-09-08. This is the current state, superseding earlier usage-stop snapshots.

## Approved full-arena rollout

Visible sun: `cosmic_sky.gdshader` now draws a large pale-gold stellar disc and corona, with angular radius 0.12 radians (13.75° diameter). `arena_sky.gd` supplies the shadow-casting `PaleStarlight.global_basis.z` as its direction: approximately (-0.457526, 0.669131, 0.585606), 42° elevation. This is the direction toward the source, opposite the light’s local -Z rays. No second light or shadow rotation was introduced. The disc is composited after sky grading and excluded from the sky radiance bake to avoid duplicating the existing directional lighting. Native Forward+ captures were inspected from inside the arena; the supplied direction matched the actual key light to dot product >0.99999. Review images: `artifacts/sanctum-sun-from-arena.png`, `artifacts/sanctum-sun-sky.png`.

Latest palette refinement: High remains the default. The owner requested slightly less bronze and no spray-painted purple stone patches visible from the arena. Authored bronze now uses a subtle cool tint (`e8efff`) and metallic multiplier 0.9; procedural bronze is desaturated by 16%, with a small matching adjustment to distant trim. Random emissive masks were removed entirely from both arena stone and floating-debris shaders, independent of graphics mode. Dark rock now uses a neutral slate tint. Deliberate portal runes, banners, sky and all four pillar armillaries remain. Native Forward+ rendered verification passed: 99 upgraded surfaces, 115 retained bake assignments, 19 world bodies, original artwork on every pillar, no script/shader errors.

The owner approved extending the corner treatment across the map, specifically retaining the original artwork on every pillar. The upgrade now covers all 27 authored modules: four covers, nine floor sections, twelve walls and two terraces. It replaces 99 material surfaces while preserving all 16 original luminous inlay surfaces. The pillar-covering star-chart overlay was removed from the Blender builder and regenerated GLB; all four original armillaries are unobstructed. The floor no longer fades back to the old corner-only material. Two opposing boundary shrines reuse one 5,824-triangle GLB, with two warm lights and one arena-wide reflection probe.

Forward+ and High lighting now start by default. Restart the game after updating. `--sanctum-base` disables the High effects; `--sanctum-original` also restores original arena materials for comparison. `--rendering-method gl_compatibility` explicitly selects Compatibility; unsupported High effects remain guarded by the actual renderer. All 115 existing lightmap bindings and 19 collision bodies remain intact. The full-map native Forward+ review passed with 99 upgraded surfaces, all four original pillar inlays present, boundary-only overlay bounds, 115 baked assignments and 19 collision bodies. Map checks passed 57/57. The earlier corner study below is historical; its narrower scope and optional-default statements are superseded by this approved rollout.

## Latest corner benchmark and renderer study

The owner subsequently authorized a polished southwest corner and an investigation of Forward+ while deferring characters. This trial is implemented locally in `scripts/sanctum_corner.gd`, called by the existing authored arena loader. It overrides22 surfaces across `Cover_1`, `Floor_6`, `Perimeter_15`, `Perimeter_17` and `Terrace_19`. New stone weathering uses `shaders/sanctum_corner_stone.gdshader`; the floor fades to its original material over2m at its module boundary. New floor/basalt/bronze maps are1024px, freshly baked, seamless and mipmapped. The older nine512px maps now also have mipmaps enabled.

`assets/environment/corner/corner_details.glb` adds a star-chart plaque, bronze repairs, a boundary medallion and six votives in four mesh/material batches (11,380triangles,884,056bytes). Detail UV scale is corrected at runtime to match the existing4m repeats. A shadowed warm light at(-17.1,3.58,13.5) and one once-updated, box-projected reflection probe give the bronze a local response. New details use no baked GI; the existing115 bake assignments, key lights and19 world physics bodies remain intact. Changed material reflectance has not been rebaked into indirect color; rebake after the trial's art direction is approved for expansion.

`scenes/sanctum_corner_preview.tscn` loads the actual arena with its menu hidden and simulation/input disabled. It offers independent corner and High lighting toggles, four camera positions, drag orbit and wheel zoom. Run with `godot --path . --rendering-method forward_plus res://scenes/sanctum_corner_preview.tscn`; on this Linux host, use `--display-driver wayland --audio-driver Dummy` for the working native GPU path. Compatibility can run the same scene, with High unavailable. The normal game remains Compatibility by default; `godot --path . --rendering-method forward_plus -- --sanctum-high` tries High in gameplay. `--sanctum-original` removes the corner upgrade for controlled comparisons.

High (`scripts/sanctum_graphics.gd`) is explicitly experimental and checks the actual renderer after fallback. It adds SSAO radius0.65/intensity1.35, SSIL radius2/intensity0.35,2xMSAA, volumetric fog density0.004/length64, reduced bloom, calibrated procedural mineral emission and a calmer background. It preserves the baked key/indirect profile. SDFGI and SSR remain deferred: this fixed map already has a bake and mostly rough materials. Exact hardware results, the concurrent-game caveat, observed full-match hitches and memory cost are in `FORWARD_PLUS_ASSESSMENT.md`.

The new trial's PNGs add7.69MiB of source assets, plus the relief GLB. Current environment source files total17,323,210bytes (16.52MiB), excluding `.import`/`.uid`; the earlier8MiB total below is the historical pre-corner baseline. The uncompressed new texture image payload with mipmaps is about29.3MiB, distinct from both PNG disk size and complete engine VRAM. Keep source quality for this comparison; test VRAM compression before broad rollout. Builders: `tools/build_corner_materials.py` and `tools/build_corner_details.py`; notes/manifests live beside their textures and in `assets-source/corner/`.

Rendered verification uses `tools/sanctum_corner_review.gd`. It checks22 affected surfaces,115 retained lightmap assignments,19 world bodies,0 art bodies, and all new assets. It writes per-renderer before/materials/High/stonework/shrine/arena captures under `artifacts/corner-*`. Native rendered checks passed on both Compatibility and Forward+ with no runtime script/shader errors. The interactive viewer, camera choices and comparison switches also passed functional review under both Xvfb/Compatibility and native Wayland/Forward+. The first native viewer startup stalled before renderer initialization; a bounded retry passed. The actual High art captures were successfully rendered natively by the corner review script. Map 57/57 and world 13/13 passed in this pass. Use native Wayland for GPU evidence; headless checks only cover logic. The rest of this document records the retained base arena and its original bake workflow.

## Authorized work and status

The user approved extending the authored architecture over the whole arena, then approved two further upgrades: lighting contrast and the surrounding landscape. Both are implemented. Final baked-render reviews passed and the gameplay, lane and landscape images were visually inspected. Both requested upgrades are complete. See the verification section and logs below. No commit or deployment was requested.

The user's rule persists: monitor account usage, stop development around 90%, and document current work for the next agent. Usage is shared across tasks and the user has switched accounts during this conversation. Always query the live meter rather than relying on an old reading. No reset credit was redeemed by this agent.

## Current visuals

The full playable architecture uses four carved covers, nine floor modules, twelve wall modules and two terraces, sharing 17 compressed mesh resources across 115 mesh instances. The geometry includes bevels, blind arches, bronze ornament, emissive inlay, fitted/split flagstones and worn stone variation. Proper UVs and UV2 support normal maps and baked indirect lighting. All four covers retain their original orientation and collision.

The lighting pass has a shared profile in `scripts/sanctum_lighting.gd`: ambient energy 0.24, cool key 1.12, subdued violet fill 0.12, cool rim 0.17, exposure 1.04. Four short-range warm lights are placed at existing side shrines (x±17.25,z±9,y1.65), with no shadows. Existing central votive and gateway lights remain. Runtime and bake use the same profile. Directional and new votive lights bake indirect only; live lighting still responds to champions. Native LightmapGI was rebaked for all 115 meshes using two bounces and the low sampling preset. Review for noise before increasing sample counts; the previous heavier process was terminated before producing output.

The ordinary depth fog starts 22 m from the camera and reaches its endpoint at 205 m, using a blue-violet tint. Bloom threshold remains 1.35. No SSAO, SSIL, SDFGI, volumetric fog or screen-space reflections were introduced; runtime remains Godot 4.5.1 OpenGL Compatibility.

`scripts/sanctum_landscape.gd` adds a broad hanging island foundation, six large layered cliff formations, broken causeways, nine ruined sanctuaries with fractured apses and partial celestial rings, and receding shelves. Far islands were reduced from48 to24 clusters, and near decorative spikes from36 to12, leaving space for the larger forms. The new landscape has six render batches /19,116 triangles, with no collision, no navigation and no extra shadow passes. Its cliff shader reuses existing slate with triplanar mapping, restrained strata and derivative height relief. Three faint animated mist sheets below the island are ordinary transparent surfaces, not volumetric fog. No new texture assets were added.

## Runtime files

- `scripts/arena_world.gd`: authoritative collision plus remaining procedural ornament; loads authored architecture through `scripts/sanctum_slice.gd`. Dedicated headless servers return before building art.
- `scenes/sanctum_quality_slice.tscn`: full authored arena, despite its historical filename. `full_arena` metadata prevents loading an obsolete partial scene. Runtime removes its BakeLights before adding it, avoiding doubled lighting.
- `scripts/arena_sky.gd`: sky, depth fog, live lights, distant islands and landscape entry point.
- `scripts/sanctum_lighting.gd`: shared live/baked lighting configuration.
- `scripts/sanctum_landscape.gd`, `shaders/sanctum_cliff.gdshader`, `shaders/sanctum_abyss_mist.gdshader`: exterior landscape and subtle mist motion.
- `assets/environment/slice/meshes/`: compressed runtime meshes, external scene resources.
- `assets/environment/slice/textures/`: nine 512x512 seamless PNGs, albedo/normal/roughness for basalt, floor and bronze. Albedo contains no baked lighting or AO. Normal maps are tangent-space for authored UV meshes. Roughness is lossless single-channel grayscale. Exact opposite-edge pixels match. Coverage is approximately 4 m; floor modules compress their longitudinal axis 12/14 to tile the 36 m arena.
- `assets/environment/slice/lighting/`: native `.lmbake` and HDR EXR atlas. Lighting belongs here, not in albedo.

## Budget and verification

Final review: both tools exited 0 with no runtime script/shader errors. The architectural inventory remains 4 covers, 9 floor modules, 12 perimeter modules and 2 terraces; 19 physics bodies in the world and zero beneath the art. All 115 lightmap assignments are present. Both teams’ lanes, the final baked gameplay view and the exterior landscape view were visually inspected. Full-match HUD-hidden frame: 1,708 draw calls on llvmpipe, compared with 1,705 in the prior review; this is not a hardware performance benchmark. Final usage checkpoint was 69%, safely below the user’s cutoff.

Current runtime environment files total 8,373,829 bytes, just below 8 MiB (8,388,608 bytes). Textures plus lightmap total 6,670,805 bytes. This count excludes tiny `.import`/`.uid` metadata and ignored authoring sources. There is very little remaining headroom; recheck after every bake. The new landscape uses code and existing textures. It creates geometry at load time, so disk budget does not measure its GPU memory.

Passed after this pass: map 57/57, combat 81/81, world 13/13. Landscape verification checks every vertex: none lies within |x|<18,|z|<18,y>−0.5. The hanging foundation may occupy space below the floor, but no new visual geometry enters playable airspace. All landscape children are meshes with shadow casting disabled.

Production bake completed in 140.545 seconds, assigned 115 meshes, and reimported successfully. Its isolated project/log is `/tmp/sanctum_bake_u4z4bdlc`. The first heavier interrupted attempt is `/tmp/sanctum_bake_4313l7ne` and is not a valid bake. The editor may emit internal list-erase/import warnings after a bake; success must be established by resource assignments and actual runtime rendering, not merely exit status.

The bake helper was improved to read freshly saved EXR pixels instead of cached texture-array layers when reporting image statistics; syntax check passes. That statistics-only improvement was made while the completed bake ran in its already-copied temporary project, so the current report uses the previous helper. Do not treat its cached peak/mean as a fresh source-image measurement. This does not affect the saved atlas or scene bindings.

The measurements above used Xvfb/llvmpipe and did not verify physical-GPU 60 FPS. A subsequent 2026-09-08 investigation discovered the native Wayland path to this host's Radeon RX 7800 XT and successfully rendered both Compatibility and Forward+. See [FORWARD_PLUS_ASSESSMENT.md](FORWARD_PLUS_ASSESSMENT.md) for actual-GPU measurements and the outstanding full-combat frame budget. New landscape contributes six batches and no shadow passes; removing old decorative clusters offsets part of its cost. Full-game draw counts also include the existing champions, HUD and shadow passes.

## Rebuild workflow

Editable `.blend`/`.glb` files live in `assets-source/sanctum_slice/`, ignored by Godot via `.gdignore`. Preparation reads those GLBs explicitly using GLTFDocument and saves compressed runtime meshes. Do not move authoring GLBs into the runtime environment folder; that duplicates shipped geometry.

1. Only if geometry changes: `blender -b --python tools/build_sanctum_cover.py` and/or `blender -b --python tools/build_sanctum_surround.py`.
2. Only if material graphs change: `blender -b --python tools/bake_sanctum_materials.py`.
3. `godot --headless --path . --editor --import --quit --log-file /tmp/sanctum-import.log`.
4. `godot --headless --path . --script tools/prepare_sanctum_slice.gd --log-file /tmp/sanctum-prepare.log`.
5. `python3 tools/bake_sanctum_slice.py --scene scenes/sanctum_quality_slice.tscn --data assets/environment/slice/lighting/sanctum.lmbake --timeout 600`.
6. Reimport, run rendered checks, inspect gameplay images and verify the disk budget.

Preparing the scene clears its bake assignment; always rebake afterward. Changing `sanctum_lighting.gd` requires preparation and rebaking to keep indirect light consistent. Landscape-only changes need no bake because the exterior geometry does not cast shadows or participate in GI. The isolated bake launcher leaves the real project settings and editor plugins unchanged.

Blender 5.2 on this host can emit unrelated addon/thumbnail warnings and hang during audio shutdown after saving. Check explicit DONE markers and files before stopping a completed process.

## Render review

Run with `xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script TOOL --log-file /tmp/NAME.log`:

- `tools/sanctum_slice_review.gd`: checks 4 covers / 9 floors / 12 walls / 2 terraces, 19 world bodies, 0 art bodies, no duplicate baking lights, then saves baked/unbaked closeups and HUD-hidden gameplay.
- `tools/landscape_review.gd`: checks landscape bounds and no shadow passes, then saves `artifacts/sanctum-landscape.png`, `sanctum-lanes-north.png`, `sanctum-lanes-south.png`.
- `tools/arena_review.gd`: full overview/detail and actual gameplay camera with HUD.

Final logs for this pass: `/tmp/landscape-baked-gameplay-review.log`, `/tmp/landscape-baked-lanes-review.log`. Earlier landscape bounds test passed 6 batches / 19,116 triangles / 57,348 vertices. Existing before-lighting gameplay screenshot was copied to `/tmp/sanctum-lighting-before.png`. Studio preview `sanctum-cover-studio.png` is Blender, not gameplay.

## Gameplay constraints and handoff rules

Keep floor 36x36, HALF_EXTENT 18, nav −17..17; four cover centers(±6,0,±5), body 4.4x3.8x2.8 and base 4.7x0.4x3.3; terraces |x|12.3..17.65 at 1.2 m, ramps between z±6 and±10; boundary 0.7 thick / 3 tall. Keep all 19 original physics bodies. Never change movement, bot routes, LOS or spell blocking to suit decoration.

Preserve concurrent HUD, champion, aura and deployment work. Other tasks share this checkout and have committed work during the session. No commit, reset, stash or deployment is authorized by this art request. Next substantial work should be driven by actual gameplay review and a physical-GPU profile rather than adding detail indiscriminately.
