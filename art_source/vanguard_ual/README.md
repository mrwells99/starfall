# Vanguard — Starfall Model Forge v2

The editable installed model is `art_source/vanguard.blend`. This folder preserves the immutable pre-fit costume, class record and exact fitting/animation recipe. It is not the legacy gait standard.

Use `tools/build_model_forge_class.py -- --class vanguard` through Blender, then `tools/verify_model_forge_class.py -- --class vanguard`. Builds stage under `artifacts/forge-v2-all-classes/vanguard`. The builder checks costume and supplied-library hashes and retains the preset's 53 core rest bones.

See `docs/CLASS_MODEL_FORGE_V2_ROLLOUT.md` for equipment exceptions, runtime review, checks and reversible installation. Do not overwrite `costume_source.blend` with the fitted result. V2's frozen Fulcrum archive remains the shared authority.
