---
name: starfall-character-forge
description: Build or revise Starfall class models with Starfall Model Forge v2, using the accepted Fulcrum mannequin anatomy, Blender materials and equipment, directional animations, runtime smoothing, and reversible Godot installation.
---

# Starfall Model Forge v2 — current default

Use **C:/projects/starfall/art_source/workflows/starfall-model-forge-v2/** for future Starfall character/model requests. The owner approved the accumulated Fulcrum workflow through r008 and explicitly excluded reverted r006/r007. “Starfall Model Forge,” “Character Forge,” and “same workflow as Fulcrum” now mean v2 unless the owner explicitly requests a historical version.

Read the package's README.md, WORKFLOW.md, runtime_contract.json and feedback.json before implementation. Verify with the project's tools/model_forge_snapshot.py --verify. Read source and recipe from the verified snapshot, not unrelated current experiments. The full guide includes exact tool paths, recovery, accepted settings, testing and second-monitor review.

## Essential decisions

- Produce an actual editable Blender model, packed portable materials, skinned GLB, integrated weapon, named clips and working Godot presenter. A generated image is only reference/inspection, not the deliverable.
- New class appearance follows its reference. Keep the same preset anatomy, material-production quality, animation and integration method; do not give every character Fulcrum's mask, purple armor or orb.
- Use the actual supplied Quaternius mannequin and 53 unchanged core rest bones/body proportions. Fit costume to it. Do not independently humanize or rescale the body to fit armor. Added garment/weapon controls may vary by class.
- Preserve 32 accepted source/derived clips and the current runtime contract: reversed walking for all backpedal sectors at 1.15 normal cadence, 0.90 jog/sprint cadence, 20-degree side/14-degree diagonal upper-body turn, short final-pose blends, existing bent-elbow arm arc, and 0.16-second head/torso easing only at jump boundaries.
- Exclude r006's extra shoulder/body/hip changes and r007's reconstructed upright-apex body parabola. Do not restore their code, tests or previews. r008 only softens the existing animation and carries the displayed takeoff direction briefly into it.
- The actual assets, recipes, three runtime modules, textures, and compressed bone/material/frame contracts are the reproduction authority. Use tools/model_forge_snapshot.py --extract EMPTY_STAGE to recover them without touching the live project.
- For another weapon, adapt attachment logic and minimum grip motion explicitly. Preserve core rest anatomy; record any allowed motion bones and verify all other inherited motion. Do not leave invalid gravity.focus lookups in a non-orb character.
- Back up each changed path with hashes; keep builds class-specific and isolated. Preview first when requested; otherwise use the established reversible project installation. Preserve other classes, gameplay, current user edits, and manual Blender work. No Git publication or deployment is implied.
- Verify anatomy, skin, textures, source motion and Godot behavior; review the actual model and live animations. Raw Blender clips do not show runtime arm/blend layers. Keep visible Blender/Godot reviews on the second monitor, capped at30FPS while the owner games.
- Create the class record from new_character.template.json and record final paths, input hashes, deliberate differences, checks, visual limits and rollback. Do not promise byte-identical regeneration across tools or identical new-class artwork from prose alone.

V2 is the shared default for new work; do not automatically convert other existing classes. Keep v1 and completed v2 snapshots unchanged. Future approved shared refinements receive a new version. Only when the owner explicitly requests v1, use docs/STARFALL_CHARACTER_FORGE_V1.md and verify it with tools/character_forge_snapshot.py --verify.
