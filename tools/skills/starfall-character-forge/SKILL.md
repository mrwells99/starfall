---
name: starfall-character-forge
description: Build or revise Starfall class characters using the preserved local Blender-to-Godot character workflow, reference-specific modeling, inherited skeletal animation, integrated weapons, visual review, and reversible project installation.
---

# Starfall Character Forge — Version 1

Use the named project workflow at `C:/projects/starfall/docs/STARFALL_CHARACTER_FORGE_V1.md`. Read it before implementation. The user explicitly requested a repeatable process with the same deliverables and mostly unchanged animation, preserved for future classes.

The frozen baseline is `C:/projects/starfall/art_source/workflows/starfall-character-forge-v1/`. Read its `manifest.json` and `contracts.json` when selecting a source character; verify its ZIP with `tools/character_forge_snapshot.py --verify`. The live project may have changed since version 1. Do not overwrite it to force a match. Use archived code/assets in an isolated staging directory, preserve later edits, and report intentional differences.

## Essential contract

- Deliver an actual editable Blender model, packed materials, deformation rig, named walking/directional/cast clips, correctly attached weapon, exported skinned GLB and working Godot presentation. Use installed Blender and bpy; a generated picture is not a substitute.
- Use the new class's supplied reference for silhouette, equipment, palette and costume. Reuse the verified animation baseline, not the previous class's appearance. New-class design necessarily varies; never promise that prose alone guarantees identical artwork.
- Preserve the selected baseline's rig/rest pose, core gait and runtime responsiveness. Record the baseline and allowed attachment adaptations explicitly. Extend bones for cloth/weapon motion without casually rewriting inherited motion.
- Use the latest actual sources and frozen contracts, not historical prose: Ember/Fulcrum/Vanguard use immediate locomotion transitions; Luminary retains its older smoothing. Fulcrum has a required weapon build stage. Luminary's face and hair were removed; Vanguard uses a sealed helmet, not a mage hood.
- Back up changed paths with hashes before writing. Preview first if requested; otherwise the established reversible project installation is permitted for the requested class. A new class request does not authorize unrelated character/gameplay edits, Git publication or destructive cleanup.
- Complete source checks, game import/tests and final visual review. Keep images in the role of inspection evidence. Open the real `.blend` and interactive animation viewer. Record what was checked and what remains limited; test counts do not establish visual approval.
- Preserve version 1. Make an explicitly named later workflow version for changed standards; do not silently replace its archived files or manifest.

The full file includes commands, topology/weight/UV guidance, color-export pitfall, animation tables, tests, source dependencies, approval history, delivery requirements and recovery procedure. Its archive and machine-readable animation contracts are the reproduction authority when historical notes disagree.
