# Vanguard reference rebuild — 2026-09-08

This is the current Vanguard handoff, superseding the earlier helmet/guard checkpoint in `VANGUARD_REBUILD_BRIEF.md`. The owner requested the same actual Blender workflow used for Ember, Luminary and Fulcrum, using the newly supplied Vanguard artwork, with creative liberty and mostly unchanged animations.

## Result and files

The rebuilt character has a fully enclosed T-visor helmet, crystal crown, dark forged armor with bronze hardware, violet resolve core, shoulder/limb crystals, navy embroidered tabard and long three-panel cape. It has no face or hair geometry. The newly modeled integrated hammer has a metal frame, broad striking caps, inset fractured crystal windows, central bearing lens and wrapped haft. It retains the original weapon bone and two-handed grip coordinates. The separate older hammer source and standalone GLB were not modified.

This is a stylized procedural 3D interpretation of the concept, with an editable rig and working animations. It does not reproduce the illustration's fine sculpted detail. The owner has not yet reviewed this new Vanguard revision; passing tests is not visual approval.

| File | Purpose |
| --- | --- |
| `art_source/references/vanguard.png` | New supplied reference, copied from `C:/Users/aidan/Downloads/Codex Image Sep 8, 2026, 08_09_37 PM.png`. |
| `art_source/vanguard.blend` | Complete editable character, packed textures, rig, eight actions and inspection studio. Opens with Walk enabled, frames 1–37. `REVIEW_ONLY` studio excluded from export. |
| `assets/characters/vanguard.glb` | Live skinned character: 67,095 source vertices, 123,044 triangles, 45 bones, eight material surfaces. Import generates LODs. |
| `tools/build_vanguard.py` | Durable rebuild/export entry point. Requires `vanguard_materials.py`, `vanguard_details.py`, `vanguard_weapon.py` in the same tools folder. |
| `assets/characters/vanguard_{steel,roughness,alloy,cloth,fabric_normal,amethyst}.png` | Six 1024px portable material maps, packed into Blender and GLB. Floating-point image storage preserves linear input values during sRGB color export. |
| `scripts/vanguard_authored.gd` | Per-actor imported PBR materials, manual animation, movement/cast/strike selection, shield rings, recoil, impact flash, defeat/revive. |
| `tools/verify_vanguard.py` | Skin weights, images, sealed materials, cape motion, cycles, soles, wrist and haft contact, optional pre-rebuild animation comparison. |
| `tests/vanguard_presentation_test.gd` | Import, clips, movement, cape, textures, per-actor isolation, shield/recoil/stun, collision and triangle budget. |
| `scenes/vanguard_preview.tscn`, `tools/vanguard_preview.gd` | Interactive model viewer: animation buttons, drag orbit, wheel zoom, Space pause and speed slider. |
| `tools/vanguard_review.gd` | Game lighting, multiple actors, movement, shield, strike and actual arena captures. |

Godot extracts GLB images as `vanguard_vanguard_*.png`; retain those and their import metadata. The character's obsolete shader substitution was removed so portable PBR maps survive into the game. Impact flashes now add emission and restore the authored values, because a white albedo multiplier alone has no effect on an already-white texture multiplier. The standalone hammer shaders remain intact.

## Reproduction

Actual local versions: Blender **5.2.1 LTS** and Godot **4.7.2** on Windows. From `C:/projects/starfall`, run sequentially:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python tools/build_vanguard.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --python tools/verify_vanguard.py
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/vanguard_presentation_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/combat_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/ability_art_test.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script tools/vanguard_review.gd
& 'C:/Users/aidan/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/vanguard_preview.tscn
```

Append `-- --vanguard-capture` to the final command to capture the viewer and exit. All current outputs are under `artifacts/vanguard_rebuild_20260908/`. Blender's NLA tracks select the other actions; enable only one track for inspection. The ignored preparation scripts and previous standalone weapon source are not build dependencies.

## Animation and gameplay contract

Eight clips retain their timings: Idle 2s, Walk 1.2s, Run 0.8s, WalkBackward 1.333s, StrafeLeft/Right 1.2s, Cast 1.6s, Strike 0.8s. Start/end poses close; runtime Strike is a one-shot. The original 39 bones preserve rest transforms and animation. Six cape controls add delayed secondary motion without changing the original legs, arms or weapon path.

Both wrists follow one weapon transform projected into the arms' reach spheres. Confirmed damage starts Strike at 0.16s into the clip. Combat timing, targeting, hit validation, networking, movement response and the 0.42m radius / 1.8m actor capsule are unchanged. Shield follows `actor.shield`; recoil follows HP loss. No authoritative animation event or weapon collider was added.

## Verification and limits

- Blender: 12,168 original bone/frame comparisons, maximum channel difference **0.0000003875**; all eight cycles close. Maximum weight error **0.0000001788**, wrist gap below **0.000000582m**, hand/weapon error below **0.000000777m**. Sampled moving soles stay at or above **0.0179997m**. All six cape controls are weighted and animate. Six images are packed.
- Vanguard presentation **799/799**, combat **81/81**, rendered ability/art **179/179**: **1,059** game assertions, including per-bone loop checks.
- Imported character plus shield/pulse rings: **124,004 triangles**, below the existing 130,000 ceiling. Rendered on OpenGL Compatibility, NVIDIA RTX 5060 Ti. This is not a multi-character performance benchmark.
- Reviewed Blender front/back, Walk, Run and Strike; the imported interactive viewer; game movement and arena captures. Screenshots are inspection evidence; the Blender model and animated GLB are the deliverables.

Practical limits: bone-driven cape has no collision simulation, no terrain foot IK, authored jump/death clips or mocap. Extreme side/back speed can exceed the bounded cadence. Sampled contact checks do not establish zero foot sliding or exhaustive armor self-intersection. The concept's spell panels were not requests for new gameplay or ability effects. Visual approval remains with the owner.

## Recovery and scope

`artifacts/vanguard_before_reference/` preserves the old model, GLB, reference, runtime, tools, tests and docs, with SHA-256 `original_manifest.json`. `installed_manifest.json` records the installed revision; `new_files.json` lists added Vanguard files. For rollback, first compare installed hashes to avoid overwriting later work, then selectively restore the original Vanguard paths and reimport in Godot. Documents contain other class work, so merge their changes selectively. Newly added maps and companions are unused by the old model and can remain temporarily.

Earlier rejected-study/fallback archives remain under `artifacts/archive/`; don't restore those wholesale. Keep the separate `vanguard_hammer_weapon.blend` and GLB intact. Other champions and unrelated working-tree changes were preserved. Work is installed in the project folder; no Git commit, push or deployment was performed.

The historical 90% five-hour usage stop rule remains. This turn's usage tool did not expose a current five-hour bucket for the active model; the old brief's 89% reading was historical. No usage reset was used.
