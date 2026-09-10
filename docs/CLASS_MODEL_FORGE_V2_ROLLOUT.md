# Ember, Luminary and Vanguard — Model Forge v2

The owner requested v2 for every remaining class on 2026-09-09. All three are installed in the project with editable Blender sources, packed original textures, skinned GLBs and the approved directional/casting/jump presenter. Fulcrum and the frozen v2 package remain the reference. No gameplay, travel speeds, collision, network protocol, Git publication or deployment changed.

| Class | Core / total bones | Clips | Triangles | Identity and equipment |
| --- | --- | --- | --- | --- |
| Ember | 53 / 73 | 32 | 138,722 | Existing bronze, dark armor, celestial face, hood/halo and burning astral robe; unarmed |
| Luminary | 53 / 80 | 32 | 162,078 | Existing ivory/gold hood, featureless interior, no exposed face or hair, celestial cape and staff |
| Vanguard | 53 / 66 | 33 | 130,910 | Existing dark plate, violet crystals, sealed visor, tabard/cape and two-handed crystal hammer |

The actual Quaternius Standard mannequin supplies unchanged body proportions, retained body vertices and all 53 core rest transforms. Original costume geometry is fitted to those landmarks; the covered mannequin head and old single-joint finger geometry are removed. Existing material surfaces, UVs and packed texture bytes are retained. Godot may re-encode extracted texture containers during import.

## Accepted animation and intentional grip exceptions

All classes use the 32 v2 clips, eight movement sectors, reversed walking in every backward sector, 1.15 backpedal cadence, 0.90 run/sprint cadence, the approved small side/diagonal torso turn, short final-pose transitions, bent-elbow velocity-based jump arms, and 0.16-second torso/head easing at jump boundaries. Neither reverted jump experiment is included.

Ember matches every frozen core-motion sample exactly. Luminary keeps the source idle's closed right fingers around the staff; the other 38 core bones match the frozen motion exactly. The staff follows the final right-hand pose and stays upright. Vanguard records the minimum carrying-arm/finger exception for both hands; its remaining 17 core bones, rest anatomy and 32-clip timing match the frozen reference. Its additional 0.8-second Strike uses the supplied Sword_Attack source and a fitted hammer sweep, retaining the established confirmed-hit response, shield rings, recoil and material flash.

Vanguard's rigid weapon is corrected for the jump layer before final-pose blending; the two-hand grip solve runs after blending. This ordering keeps a new clip's attachment offset from causing a visible first-frame snap. Joint indices and lengths are cached, and reach projection exits once the grip is reachable. The solver never changes actor velocity, transforms or bone lengths.

## Durable sources and commands

- Editable models: `art_source/ember.blend`, `art_source/luminary.blend`, `art_source/vanguard.blend`.
- Game models: corresponding files under `assets/characters/`.
- Original immutable costume inputs, class records and recipes: `art_source/ember_ual/`, `luminary_ual/`, `vanguard_ual/`.
- Verified library and CC0 license: `art_source/model_forge_v2/`.
- Staged builder: `tools/build_model_forge_class.py`; equipment companion: `tools/model_forge_equipment.py`.
- Shared presenter: `scripts/model_forge_art.gd`, `model_forge_jump_pose.gd`, `model_forge_pose_blend.gd`, `model_forge_equipment.gd`. The existing class presenter files select their assets and retain Vanguard's class effects.
- Runtime review: `tools/model_forge_review.gd`. It switches classes and views, pauses, and exercises walking, running, diagonals, backpedaling, jump/landing, casts and rapid reversals. Older raw-clip viewers do not reproduce the runtime jump/transition layers.

Run from `C:/projects/starfall`, substituting the class slug:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --threads 2 --python tools/build_model_forge_class.py -- --class ember
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --threads 2 --python tools/verify_model_forge_class.py -- --class ember
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --screen 0 --position '-1050,60' --resolution '1000x900' --max-fps 30 --script tools/model_forge_review.gd
```

The builder stages into `artifacts/forge-v2-all-classes/<class>/` and checks input hashes before use. It does not automatically overwrite installed models. Require `MODEL_FORGE_CLASS_BUILD_COMPLETE` and `MODEL_FORGE_CLASS_VERIFIED`; Blender can return zero after a Python exception. Do not run the historical `build_ember.py`, `build_luminary.py` or `build_vanguard.py` over these fitted models to reproduce v2.

## Validation and review

- Core rest error and retained mannequin-vertex error: **zero** for all three.
- Frozen motion comparison: **zero error** across 111,830 Ember, 80,180 Luminary and 35,870 Vanguard core bone/frame samples outside the named grip exceptions, including half frames.
- Maximum skin-weight error: below **1.8e-7**; all vertices have valid finite weights and UVs.
- All original packed-image checksums retained.
- Class presentation, casting, eight-way motion, final weapon grips, tiny-frame reversal and staff-finger checks: **972/972**.
- Shared jump-arm/cadence checks: **68/68**; pose transitions: **152/152**.
- Physical jump momentum: **35/35**; combat: **81/81**; unchanged Fulcrum presentation: **203/203**.
- Rendered arena ability-art integration: **195/195**. Its old immediate-Cast expectation now accepts the v2 CastEnter anticipation for every class.
- Actual Godot Compatibility review captured front/back/side, opposing walk/run phases, backpedal, side running, casts, jump apex and Vanguard Strike. Results and logs: `artifacts/forge-v2-all-classes/`.

Tools: Blender 5.2.1 LTS, Godot 4.7.2 stable, NVIDIA GeForce RTX 5060 Ti, driver 616.64, OpenGL Compatibility. Visible review uses the secondary monitor at 30 FPS. These are presentation checks, not an uncontended performance benchmark while the owner plays another game.

Preserved limitations: stylized existing costumes, no terrain foot IK or real-time cloth collision. Legs can emerge through the loose robe panels in extreme motion; the package does not claim collision-free cloth. Owner visual feedback on this conversion is still pending.

## Reversible installation

Before copies and SHA-256 records are at `artifacts/forge-v2-all-classes/before/manifest.json`. `installed_manifest.json` in the parent task folder records the actual installed files and their hashes; each class record links both manifests. These local backups are ignored by Git.

Before reverting, compare live files with the installed hashes to detect later edits. Restore only the desired class's original Blender/GLB, presenter and presentation test from `before/`, then reimport. Keep the shared v2 presenter modules while any converted class uses them. Restore shared notes and the ability-art expectation selectively; do not replace unrelated later project work. The original textures remain backed up as well. No automatic rollback or wholesale project restoration was performed.
