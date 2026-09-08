# Vanguard hammer study — 2026-09-08 stopping handoff

## Owner's direction and stop

Owner rejected the previous procedural upgrade as only marginally better. They supplied `/home/plato/Downloads/ChatGPT Image Sep 8, 2026, 01_37_56 PM.png`: realistically proportioned, dark heavy armor, mechanical joints, exposed male head, violet crystal cores and a huge two-handed hammer. They explicitly chose the hammer over sword/shield and authorized a static Blender model rendered in the arena before rigging. Do not silently replace the exposed head with a helmet.

This pass started at 72% five-hour usage. Checkpoints were 77%, 82%, then **91% after the render**. Development stopped immediately at that check under the owner's 90% rule. Only artifact inspection and these handoff notes followed. Do not redeem resets automatically.

## What exists

- `tools/build_vanguard_hammer.py`: reproducible Blender 5.2 background build. Produces layered armor, humanoid under-suit, articulated-looking joint housings, two converging arms/gripping fingers, shoulder/chest/forearm crystal clusters, boots, rough exposed head, and a large caged crystal hammer.
- `art_source/vanguard_hammer.blend`: editable unbatched Blender source, approximately 543 KiB. This is script-built geometry, **not a completed hand-sculpted character**. Source is saved before export batching.
- `art_source/.gdignore`: prevents Godot from automatically importing the Blender source and launching a Blender importer. The initial import stalled without this; it was terminated and restarted successfully. Leave this exclusion in place.
- `assets/characters/vanguard_hammer.glb`: approximately 1.9 MiB. Eight mesh instances, **78,134 triangles**. Joined per material, static and unrigged. Triangle count needs optimization before deployment; eight nodes does not prove GPU performance.
- `shaders/vanguard_forged.gdshader`: procedural metal mottling, pits/roughness variation and derivative bump. Material base colors come from the GLB.
- `shaders/vanguard_crystal.gdshader`: violet crystal material with lit emission and animated procedural Voronoi fissures. Its fragment work also needs hardware profiling.
- `tools/vanguard_hammer_review.gd`: loads the actual arena, freezes gameplay, applies material overrides to the study, rotates it to face Godot -Z, renders three angles and saves an independently loadable study scene.
- `assets/characters/vanguard_hammer_study.scn`: compressed standalone static review scene with shader overrides, approximately 2.2 MiB. This duplicates some GLB content for review convenience; choose one production representation later.

The playable champion was **not** replaced. Previous sword/shield code, arena gameplay and collision were not modified by this study. This is the agreed visual-review milestone, not an integrated character or a claim of reference-level fidelity. No new environment textures were added and the environment budget is unchanged. Character study/source files are separate assets.

## Rendered evidence and honest assessment

Successful Godot 4.5.1 Compatibility render, no script/shader errors in `/tmp/vanguard-hammer-review2.log`; same Mesa llvmpipe software renderer, **no hardware performance proof**. `git diff --check` passed. No combat tests were rerun for this isolated, unreferenced static model; previous pass tests must not be represented as tests of future hammer integration.

Viewed both front views:

- `artifacts/vanguard/hammer-study-front.png`
- `artifacts/vanguard/hammer-study-other-side.png`
- `artifacts/vanguard/hammer-study-back.png` also generated; not visually inspected at cutoff.

The hammer/crystal identity and broad silhouette are present, but **the model is still well below the supplied reference**. Do not present it as the desired major quality jump already achieved. Main visible problems:

1. Head is obviously assembled from separate primitive forms: disconnected-looking beard masses, stylized eyes/hair, no coherent facial anatomy or skin detail. It needs an actual cohesive head mesh/sculpt, not more small spheres.
2. Shoulder plates are too rounded and stacked; torso/limbs still look assembled and simplified. Need designed plate topology, sharper overlap/cutouts and more convincing anatomy/proportions.
3. Steel material looks coarse, blue and mottled in arena light. Reduce large grain and tune actual worn dark metal; avoid glitter/noise substituting for authored surface work.
4. Crystal cracks are excessively dense and bright. Larger internal fractures and calmer dark crystal areas would match the reference better and reduce shimmer.
5. Grip, wrists, stance, intersections and hammer clearance need refinement. The static arm layout is only a starting pose.

## Next work

First discuss/show this honest study if the owner has not seen it. Prioritize quality of the mesh and exposed head, not another effects layer. Refine the static result before rigging. Then retopologize/optimize, create UV/material assets if useful, establish team-color cues, rig with proper two-handed constraints, create locomotion/attack poses and integrate while preserving authoritative gameplay timing and the existing capsule. None of those later steps were completed here.

Rebuild from repository root:

```sh
blender -b --python tools/build_vanguard_hammer.py
XDG_CONFIG_HOME=/tmp/vanguard-godot-config godot --headless --path . --editor --import --quit --log-file /tmp/vanguard-hammer-import.log
xvfb-run -a -s '-screen 0 1600x1100x24' godot --path . --script tools/vanguard_hammer_review.gd --log-file /tmp/vanguard-hammer-review.log
```

Import must finish before running the review. This environment required the approved execution path for the editor import and virtual display. The successful import log is `/tmp/vanguard-hammer-import2.log`. The stale first render failed because import had not completed; do not confuse `/tmp/vanguard-hammer-review.log` with the successful `review2` log. Initial import/review processes were terminated; the existing unrelated open Godot game was left alone.

No commits, pushes or deployments. Preserve other agents' unrelated workspace modifications. See `VANGUARD_ART_HANDOFF.md` for the earlier playable procedural model and `ART_SLICE_HANDOFF.md` for completed arena work.
