# Outlaw — editable Model Forge v2 source

`outlaw.blend` is the complete skinned character and equipment with packed textures. `recipe.json` records deterministic generation parameters and source clip selection. `forge-record.json` applies the shared v2 class-record schema; `installation.json` stores installed hashes and rollback ownership.

1. Verify the frozen package with `tools/model_forge_snapshot.py --verify` using the Python executable recorded in the Forge v2 workflow.
2. If absent, extract that package into the empty directory `artifacts/outlaw-forge-v2/seed`.
3. Run Blender in the background with `--threads 2 --python tools/build_outlaw.py`. Outputs stage under `artifacts/outlaw-forge-v2/candidate`.
4. Validate using Blender `--background --threads 2 --python tools/verify_outlaw.py` before copying the new candidate into the project.
5. Keep `outlaw.blend` here, its GLB at `assets/characters/outlaw.glb`, and its four image maps here. Blender and GLB also embed the maps.
6. Reimport Godot, run the Outlaw ability/presentation/network suites, and review `tools/outlaw_review.gd` on the secondary monitor.
7. Placeholder icon sources are editable SVG files under `assets/icons/abilities/outlaw`; their deterministic original drawing script is `tools/build_outlaw_icons.py`.

The actual mannequin/library and its CC0 attribution are retained under `art_source/model_forge_v2/`. The old workflow package is unchanged. The Bowie knife is 1.5 times the initial size and uses a closed left-hand reverse grip. New equipment and costume details are class-specific; the preset anatomy and all 32 inherited source motions are unchanged. No r006/r007 jump reconstruction is included.

The pre-installation backup is deliberately separate under `artifacts/outlaw-forge-v2/before`. Preserve it while this installation may need to be reverted. `tools/outlaw_forge_record.py --check-rollback` checks recoverability without changing files; `--rollback` restores this pass only if no later edits would be lost. Installation records are retained for audit.
