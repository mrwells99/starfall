---
name: starfall-character-forge
description: Build or revise Starfall class models with Starfall Model Forge v2, including accepted mannequin anatomy, Blender materials and equipment, directional animations, fitted animated body hitboxes, lightweight server rigs, and reversible Godot installation.
---

# Starfall Model Forge v2 — current default

Use **C:/projects/starfall/art_source/workflows/starfall-model-forge-v2/** for future Starfall character/model requests. The owner approved the accumulated Fulcrum workflow through r008 and explicitly excluded reverted r006/r007. “Starfall Model Forge,” “Character Forge,” and “same workflow as Fulcrum” now mean v2 unless the owner explicitly requests a historical version.

Start with the package's CURRENT.md, then read README.md, WORKFLOW.md, runtime_contract.json, feedback.json and extensions/hitboxes-v1/WORKFLOW.md. The active standard is **v2 + hitboxes-v1**, explicitly requested by the owner on 2026-09-10. Verify both packages with tools/model_forge_hitbox_snapshot.py --verify. Read source and recipe from the verified snapshots, not unrelated current experiments. The full guides include tool paths, recovery, accepted settings, testing and second-monitor review.

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
- Every completed class includes 19 slightly padded, bone-following main-body hitboxes and a compact mesh-free server rig extracted from its final GLB. Preserve movement collision, normal head damage, and exclusion of cloth/ornaments/weapons. Use the same animator on client/server, including special moves. Rebuild stale rigs, register the class in builder/runtime/cache/tests/review, and preserve portable animation libraries across the desktop/server Godot versions. Follow the required extension for exact profiles and checks.
- Inspect and deliver actual front/side hitbox pictures plus relevant special-move pictures. Verify visible/server pose agreement, source/rig hashes, dedicated resource usage and shared aimed-combat regression. Adding a model does not authorize a playable aimed ability or combat rebalance.
- Start the extended class record with tools/model_forge_hitbox_snapshot.py --new-record SLUG --record PROJECT_RELATIVE_PATH. Record final paths, input hashes, deliberate differences, checks, visual limits and rollback; run its --check-record gate before delivery alongside original art checks. Do not promise byte-identical regeneration across tools or identical new-class artwork from prose alone.

V2 with its required hitbox extension is the shared default for new work; do not automatically convert unrelated existing classes. Keep v1 and the original v2 snapshot unchanged. The owner's request to bake hitboxes into v2 is recorded as the separately frozen hitboxes-v1 extension; future shared refinements need an explicit revision. Only when the owner explicitly requests v1, use docs/STARFALL_CHARACTER_FORGE_V1.md and verify it with tools/character_forge_snapshot.py --verify.
