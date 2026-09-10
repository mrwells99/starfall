# Starfall Model Forge v2 — current default

The owner approved the accumulated Fulcrum model/preset/texture/weapon/animation workflow through r008 on 2026-09-09 and requested it for future classes. **r006 and r007 were reverted and are excluded.**

Start with [the active workflow](../art_source/workflows/starfall-model-forge-v2/CURRENT.md). It combines the original [model procedure](../art_source/workflows/starfall-model-forge-v2/WORKFLOW.md) with the required [hitbox finishing step](../art_source/workflows/starfall-model-forge-v2/extensions/hitboxes-v1/WORKFLOW.md), approved 2026-09-10. Every future class includes 19 fitted animated body volumes, a compact server rig, pose/resource checks and actual front/side hitbox pictures. Class-specific movement gets matching pose checks and pictures.

Verify both frozen packages with `python tools/model_forge_hitbox_snapshot.py --verify`. Use its `--new-record SLUG --record PATH` command to start the extended class record, then `--check-record PATH` before delivery alongside the original art checks. The original 77-file Fulcrum snapshot stays unchanged; **v2 + hitboxes-v1** is the current default. The extension preserves the accepted fit profiles, exact working tools, reference rigs, pictures and evidence for recovery. It does not enable a new playable aimed ability.

Invoke “Use Starfall Model Forge v2 for [class] with this reference,” or `$starfall-character-forge`. New identity follows its reference; anatomy and accepted animation follow v2. Character Forge v1 stays preserved as a compressed local historical backup.

The owner subsequently requested conversion of every other class. **[Ember, Luminary and Vanguard now use v2](CLASS_MODEL_FORGE_V2_ROLLOUT.md)**, with their original identities and explicit staff/hammer grip adaptations. The frozen Fulcrum package remains unchanged; the linked record covers installed files, checks and rollback.
