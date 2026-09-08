# Cosmic Sanctum full-arena upgrade — continuation notes

Updated 2026-09-08. The user resumed after changing accounts. The earlier usage stop is resolved; do not treat the old 94% reading as current. Continue checking account usage and honor their approximate 90% cutoff. No reset credit was redeemed by this agent.

## Delivered scope

The user subsequently authorized expanding the approved quality section across the full arena. The prepared scene now has four authored covers at the original centers, nine shared floor modules covering all36x36m, twelve boundary modules covering all four sides, and two authored terraces with their existing ramp dimensions. Total115 mesh instances share17 compressed mesh resources and the existing nine PBR maps. Portals, cliffs, sky, distant gods, banners and motes retain the preceding atmosphere pass.

Full-arena final checkpoint: user90% usage cutoff reached, development stopped. Geometry is integrated; map57/57, combat81/81 and world13/13 passed. Native lighting bake completed in219seconds, assigned115meshes, and saved/reimported successfully. Runtime environment totals8,327,245bytes (7.94MiB). Roughness PNGs now store the exact same red-channel scalar in lossless grayscale, removing redundant RGB data. All other maps unchanged.

The pre-bake full-arena overview and gameplay view rendered successfully and the overview was visually inspected: all four cover positions and both terraces are clear. Final baked review was launched before the cutoff with `tools/sanctum_slice_review.gd`; its log is `/tmp/sanctum-full-final-review.log`. It checks4covers/9floor modules/12wall modules/2terraces,19world physics bodies and0art bodies, then saves updated baked/unbaked and gameplay PNGs. Collect/check this log and inspect `artifacts/sanctum-slice-gameplay.png` before declaring final visual sign-off. `artifacts/sanctum-overview.png` is the full-map overview before the new lighting bake. Do not imply a physical-GPU60fps test was performed. All remaining work is final visual verification/performance assessment; no known gameplay failures.

The cover has real bevels, carved blind arches, bronze armillary relief, emissive inlay, and a broken crown. The floor has fitted flagstones, small silhouette chips, split slabs, individual stone tint variation and bronze aisle marks. The perimeter has coursed masonry, arched niches, buttresses and small emissive slots. The authored architecture uses shared modular mesh instances and have proper UVs and unique UV2.

## Runtime files

- `scripts/sanctum_slice.gd` loads `scenes/sanctum_quality_slice.tscn`, removes the scene's BakeLights before adding it, and reports whether its surrounding art loaded.
- `scripts/arena_world.gd` retains ALL authoritative collision. It conditionally omits all four old covers, all old floor slabs and wall segments, and the old terrace visual meshes. Central floor insignia, spawn marks, portal structures and atmospheric decor remain. Missing packed scene retains the old procedural visuals. Headless servers skip all artwork.
- `assets/environment/slice/meshes/` contains compressed static runtime meshes. The scene references them externally; no giant embedded mesh arrays.
- `assets/environment/slice/textures/`: nine original 512x512 PNGs, albedo/normal/roughness for basalt, floor and bronze. Four metres/tile, exact matching opposite-edge pixels, flat unlit albedo without AO/shadows/highlights. StandardMaterial3D uses UV-based tangent normals, so the legacy triplanar limitation does not apply to these authored meshes. Existing procedural art keeps its derivative height shader.
- `assets/environment/slice/lighting/`: native Godot LightmapGI data and HDR EXR atlas. Ambient occlusion/contact lighting is part of the separate lighting bake, never painted into the albedo. Directional lights bake indirect only; matching live lights still illuminate and shadow champions. Runtime stays OpenGL Compatibility.

## Authoring and rebuild

Editable `.blend` and interchange `.glb` sources live in `assets-source/sanctum_slice/`. `assets-source/.gdignore` keeps them out of normal import/export. The preparation tool reads GLBs explicitly with GLTFDocument, then saves compressed runtime meshes, avoiding duplicate shipped geometry. Do not move the GLBs back into the runtime environment directory.

1. `blender -b --python tools/build_sanctum_cover.py` (optional `-- --render` creates the studio preview).
2. `blender -b --python tools/build_sanctum_surround.py`.
3. `blender -b --python tools/bake_sanctum_materials.py` (only when material graphs change).
4. `godot --headless --path . --editor --import --quit --log-file /tmp/sanctum-import.log`.
5. `godot --headless --path . --script tools/prepare_sanctum_slice.gd --log-file /tmp/sanctum-prepare.log`.
6. `python3 tools/bake_sanctum_slice.py --scene scenes/sanctum_quality_slice.tscn --data assets/environment/slice/lighting/sanctum.lmbake --timeout 600`.
7. Reimport, then render with the review tools below.

Preparing the scene clears its baked-light assignment; always rebake afterward. The native bake helper creates an isolated temporary editor project; source project settings and plugins are not changed. It registers the output directory before baking and preserves EXR texture-array import settings. The Godot 4.5.1 editor may emit an internal list-erase error after a successful bake; verify the bake report, all 13 mesh assignments, and actual runtime renders. Details are in SANCTUM_LIGHTING_BAKE.md.

Blender 5.2 on this host emits unrelated bundled-addon and thumbnail warnings and can hang in audio shutdown after output files are already saved. Check the explicit DONE markers and files before stopping a completed process. Do not discard valid outputs based on those shutdown warnings.

## Verification and evidence

Final running review result collected at cutoff: exit0; exactly4covers,9floor modules,12perimeter modules,2terraces;19world physics bodies,0art bodies;115lightmap assignments. No runtime script/shader errors. Baked/unbaked/gameplay captures saved; their final images were not visually inspected after the90% stop. HUD-hidden full-match frame reports1705draw calls on llvmpipe. Next agent should inspect the saved final gameplay image and profile physical hardware before further detail work.

Historical first-section delivery verification (superseded by full-arena checkpoint above): completed after compacting the runtime meshes and the final bake: both review tools exited0 with no runtime script/shader errors. Actual runtime environment assets total8,141,401bytes (7.76MiB), including6,575,352texture/lightmap bytes. Final account usage reading was54% five-hour /8% weekly; no cutoff reached on the resumed account. Full-game HUD capture reports1337draw calls/609365primitives including shadow passes and existing champions/UI; these are software-renderer observations, not a60fps claim.

- Map 57/57 and combat 81/81 passed after integration.
- Rendered inventory: 19 physics bodies in the world, zero under CosmicSanctum, no duplicate BakeLights in the game.
- Native production bake assigns all115 meshes. Earlier controlled baked/unbaked view changed 48.3% of pixels by more than 3/255; this is a lighting A/B, not a performance benchmark.
- All nine PBR PNGs are 512x512 and have zero opposite-edge pixel error. Roughness PNGs are now single-channel lossless; the manifest records their updated byte counts. Their manifest records dimensions, range and tile coverage.
- Runtime environment folder, including meshes, textures and lightmap, is approximately7.94MiB. Editable authoring sources are separate and ignored. Budget must be rechecked after future bakes.
- No physical-GPU 60fps result is claimed: this host uses Mesa llvmpipe software rendering.

`tools/sanctum_slice_review.gd` renders the actual arena, checks body counts, and captures `artifacts/sanctum-slice.png`, `sanctum-slice-unbaked.png`, and `sanctum-slice-gameplay.png` (HUD hidden for inspection). Run with `xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tools/sanctum_slice_review.gd --log-file /tmp/sanctum-slice-review.log`.

`tools/arena_review.gd` also captures overview, detail and the real gameplay camera with HUD. `artifacts/sanctum-cover-studio.png` is the Blender studio preview, not an in-game screenshot.

## Constraints and follow-up

Keep four cover centers (+/-6,0,+/-5), body4.4x3.8x2.8 and base4.7x0.4x3.3; floor36x36, HALF_EXTENT18, navigation-17..17; terraces |x|12.3..17.65 at1.2m, ramps between z+/-6 and+/-10; boundary0.7 thick and3 tall. Never change movement, line of sight, bot routes or colliders to suit art.

The authored construction now covers the full playable architecture. A physical-GPU profile is still required before claiming the60fps target. Further visual detail should reuse the modules and materials. Do not change gameplay or add colliders to accommodate art.

Preserve concurrent HUD, champion, aura and deployment work. Other tasks share the checkout and have committed work during this session. No commit, reset, stash or deployment was requested here.
