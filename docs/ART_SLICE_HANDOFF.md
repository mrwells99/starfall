# Cosmic Sanctum visual-quality slice handoff — 2026-09-08

## Stop condition

User explicitly requested stopping at approximately 90% account usage and documenting progress for another agent. Usage was 24% at the start of this phase, 82% at the next check, then 94% at the last check (weekly 30%). Development stopped on discovering 94%; only existing test results and this handoff were collected afterward. No reset credit was redeemed. Check usage before resuming and respect the user's cutoff. Account usage is shared with other tasks.

## Objective and honest status

User accepted making ONE fully finished visual-quality section: one authored cover, surrounding floor, perimeter segment, and finished lighting judged from the gameplay camera. This slice is NOT finished. The major completed work is an original Blender-authored cover model, initial runtime integration, and successful proof that native Godot baked lighting works on this host with OpenGL runtime. No production light bake or dedicated texture set exists yet.

## Completed this phase

- `assets/environment/slice/sanctum_cover.glb`: original carved celestial bulwark, 35,876 triangles, exactly five mesh/material batches, 2,005,096 bytes. Names: Slice_Basalt, Slice_EdgeStone, Slice_Bronze, Slice_Inlay, Slice_Recess. Real bevels, ashlar courses, arched relief, bronze armillary ornament, luminous inlay and irregular capstones.
- `assets-source/sanctum_slice/sanctum_cover.blend`: editable source, 1,609,097 bytes. `assets-source/.gdignore` prevents the source Blender file becoming another runtime import.
- `tools/build_sanctum_cover.py`: reproducible Blender generator. Run `blender -b --python tools/build_sanctum_cover.py`; append `-- --render` for the studio preview. Blender sometimes hangs during audio shutdown after successfully saving/exporting; check outputs before stopping a completed session.
- `artifacts/sanctum-cover-studio.png`: inspected Blender studio preview. This is NOT an in-game screenshot. All five GLB batches have normals, tangents, TEXCOORD_0 at about 0.25 UV/m, and uniquely packed TEXCOORD_1 for a future lightmap.
- Bounds in Godot: X approximately [-2.3364,2.3357], Y [-0.0036,4.2301], Z [-1.6265,1.6237]. Full solid heart reaches 3.8 m; projecting base fits the existing 4.7 x 3.3 m base allowance. No collision geometry.
- `scripts/sanctum_slice.gd`: visual-only loader at (-6,0,5), static GI mode, preserves imported materials and explicitly enables lit emissive inlay. Current materials are texture-free imported PBR placeholders pending dedicated weathering/material work.
- `scripts/arena_world.gd`: creates QualitySlice and replaces ONLY procedural cover at (-6,0,5) if loading succeeds. Other three covers, all floor, perimeter, atmosphere, sky and ALL physics remain existing implementation. Dedicated headless servers return before creating art. Missing asset falls back to old cover.
- Headless Godot editor import completed successfully, no errors. Runtime visual inspection of this new integration has NOT happened yet. Existing gameplay screenshots predate this cover.

## Lighting breakthrough

Lighting agent proved native Godot editor LightmapGI bake works here, even though an initial `RenderingServer.create_local_rendering_device()` returned false. Do not conclude baking is impossible from that probe. A temporary real editor plugin pressed the Bake Lightmaps button; `LightmapGI.bake()` is not bound to GDScript.

Proof: 64x128 HDR EXR, range 0..1.17, mean RGB (0.145,0.153,0.167), lmbake assigned two meshes. Actual Compatibility rendering showed soft contact/cast shadows with sun shadows disabled. Hiding all real-time lights retained baked illumination; removing the lmbake made the meshes black. Production scene still needs UV2, static meshes and a LightmapGI node. The agent was asked to save reusable tools and `docs/SANCTUM_LIGHTING_BAKE.md`; inspect those if present. Tooling may be incomplete because the account cutoff interrupted work.

## Next work, in order

1. Check account usage. Read this file, ART_DIRECTION.md and current git status. Preserve concurrent HUD/settings/aura work; other tasks have committed shared changes previously. Do not reset or discard uncommitted files.
2. Run actual rendering and inspect the new cover from the gameplay camera. `xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tools/arena_review.gd --log-file /tmp/sanctum-slice-review.log`. GUI rendering may need the already approved escalation prefix. It rewrites overview/detail/gameplay PNGs under artifacts. Check no script or shader errors. Specifically inspect emissive inlay and collision silhouette.
3. Finish authored floor patch world X[-12,0], Z[0,14] around the cover, intended floor GLB origin (-6,0,7). Skip old 2 m floor tiles at centers x[-11,-1], z[1,13] when patch loads. Keep visible floor within ~0.02 m of y0, no colliders. Root has NOT written floor/perimeter generator yet.
4. Finish authored west perimeter section, intended origin (-18,0,6), roughly z0..12. Match visible wall at least 3m high; keep decorative projections outside the playable area. Carefully replace overlapping old wall/pillar visual spans. Do not change authoritative wall collision.
5. Create purpose-built floor/basalt/bronze textures, flat albedo without baked light, UV-based normal and roughness maps. Suggested Blender procedural bake workflow (not implemented): periodic 4D noise on toroidal UV coordinates for seamless all-four-edge maps; EMIT bake for unlit albedo/roughness, tangent NORMAL bake for normal maps. Max1024 PNG, mostly512 where adequate. Validate all four wrap edges programmatically. Keep combined environment texture budget under8MB. Existing slate is512x512,520746bytes. UV2 separate for lighting. No new texture request has been sent to user.
6. Assemble stable named packed slice scene with imported meshes, shared materials, UV2 and LightmapGI. Use proven native editor bake workflow. Keep game on gl_compatibility. Compare baked and unbaked captures. Do not imply test bake is already production lighting.
7. Review actual player view, refine material scale, edge highlights/contact shadows and restrained emissions. Finish this section before spreading it to the whole arena.
8. Run map and combat tests, verify19StaticBody3D world bodies and0 beneath art, inspect draw calls and texture budget. llvmpipe is software rendering; cannot establish modest-hardware60fps from it.

## Constraints that must remain intact

36x36 floor, HALF_EXTENT18, navigation -17..17. Four cover centers (+/-6,0,+/-5), body4.4x3.8x2.8, base4.7x0.4x3.3; all must block spells/LOS. Side terraces |x|12.3..17.65, y1.2, z[-6,6], ramps down to y0 at z+/-10. Boundary thickness0.7, height3. No added colliders or obscure sightlines in gameplay footprint. Never change movement/nav/combat to suit decoration.

Runtime Godot4.5.1 OpenGL Compatibility. No SSAO/SSIL/SDFGI/volumetric fog/SSR. Bloom works in actual build with threshold1.35; unshaded albedo alone does not bloom. Custom unshaded+EMISSION previously rendered incorrectly here: use lit materials with true emission. CPU/GPU bake is separate from runtime renderer. Existing ordinary depth fog and sky movement already work.

## Existing prior-pass changes to preserve

Before this phase the repo already had modified arena screenshots, docs/ART_DIRECTION.md, docs/CONTEXT.md and shaders/arena_stone.gdshader (grain multiplier1.7 fixed saturation). Five procedural stone treatments and derivative triplanar relief, banners/motes/debris, distant watching gods and sky animation were previously implemented. User still considered that overall art primitive, which prompted this authored slice. Do not present the prior shader pass as the completed quality jump.

## Verification logs

- Import: `/tmp/sanctum-slice-import.log`, exit0.
- Map test launched: `godot --headless --path . --script tests/map_test.gd --log-file /tmp/sanctum-slice-map.log`.
- Combat test launched: `godot --headless --path . --script tests/combat_test.gd --log-file /tmp/sanctum-slice-combat.log`.
- Prior phase passed57map/65combat. Latest final counts are appended below if collected before handoff. Headless tests skip artwork, so they cannot replace visual validation of the new cover.

Final collected results: **57/57 map, 81/81 combat, both exit0.** Combat suite has grown through concurrent work. No runtime image of the new cover was captured before the cutoff.

Lighting helper final status: `tools/bake_sanctum_slice.gd`, `tools/bake_sanctum_slice.py`, and `docs/SANCTUM_LIGHTING_BAKE.md` saved. Python syntax passes. Updated reusable plugin has NOT been runtime-verified: its last attempt failed to start X11 before loading Godot script. Smoke-test helper before production; the earlier native proof and A/B are verified independently. A generated `tools/__pycache__/` is untracked and is not a deliverable.
