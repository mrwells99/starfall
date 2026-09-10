# Fulcrum preset-based source package

**Approved 2026-09-09:** this model and the accepted runtime through r008 are the baseline of [Starfall Model Forge v2](../workflows/starfall-model-forge-v2/README.md), now the default for future classes. Reverted r006/r007 are excluded. Earlier experimental/pending descriptions are historical.

Experimental r001, 2026-09-09. Full design, animation mapping, validation, review controls and rollback instructions: [Fulcrum Universal Animation pass](../../docs/FULCRUM_UNIVERSAL_ANIMATION_PASS.md).

Current revision **r004** adds a baked upper-body turn to sideways and diagonal clips, following owner feedback. The current builder and verifiers stage into `artifacts/fulcrum-turn-r004/`; the r001 stage mentioned below is historical. Original inputs and mannequin rest anatomy remain unchanged. Runtime r002/r003 refinements provide the jump arm arc and movement cadence; keep the current `fulcrum_art.gd` and `fulcrum_jump_pose.gd` with this asset.

Runtime **r005** additionally requires `scripts/fulcrum_pose_blend.gd` for short final-pose transitions. This includes the jump-arm layer, preserves immediate clip selection, and is demonstrated by `tools/fulcrum_transition_review.gd`. The Blender/GLB files still contain the r004 baked clips; cross-animation smoothing is applied by the current Godot presentation code.

Runtime **r008** slightly softens only jump transitions for hips/spine/neck/head with a 0.16s blend, carrying the displayed directional takeoff pose into the original jump. Arm transitions and the authored jump poses remain intact. Keep the current `fulcrum_art.gd` and `fulcrum_pose_blend.gd`; no mesh/rig/clip rebuild accompanies this timing adjustment. r006/r007 were rejected and remain reverted. See the pass notes for validation and rollback.

| File | Role |
| --- | --- |
| `costume_source.blend` | Preserved original Fulcrum costume and gravity weapon; immutable build input |
| `AnimationLibrary_Godot_Standard.glb` | Actual supplied Quaternius mannequin, 53-bone skeleton and 46 source clips |
| `QUATERNIUS_LICENSE.txt` | Supplied CC0 license and attribution |
| `fulcrum_ual.blend` | Editable fitted candidate with 32 animation clips; also installed as `art_source/fulcrum.blend` |
| `recipe.json` | Source hashes, preserved rest matrices, clip provenance and export contract |

Run `tools/build_fulcrum_ual.py` and then `tools/verify_fulcrum_ual.py` through Blender 5.2.1 LTS as documented in the pass notes. The game GLB is staged under `artifacts/fulcrum-ual-r001/` for review before installation. Keep the input costume unchanged; replacing it with the fitted output would fit the armor a second time. The builder retains existing input copies rather than silently refreshing from another download.

The preset anatomy is unchanged; only costume fitting, supplementary cloth/orbit controls, and explicitly derived direction variants are new. The covered mannequin head is removed. The new approach is awaiting owner feedback and does not alter the frozen Character Forge v1 archive.
