# Reusable effect library

This is an index for components extracted from working, validated spells. No generic projectile, beam, AoE or shield framework is implemented by this folder yet. Add components when actual spell work establishes a useful shared pattern.

| Component | Actual runtime/source path | Revision | Supported parameters / events | Preparation and cleanup | Verified spells / tests |
|---|---|---|---|---|---|

Existing engineering example: [`scripts/vanguard_strike.gd`](../../../../scripts/vanguard_strike.gd) retains mesh/material resources and isolates each strike's tint and fade. [`scripts/vanguard_authored.gd`](../../../../scripts/vanguard_authored.gd) keeps emission features stable and requests loading-time preparation. These are current implementation references, not frozen reusable APIs or newly approved spell styles. Read their current versions before adapting them.

Candidates to evaluate as needed: cast glows, projectiles, beams, impacts, ground areas, shields and persistent debuffs. Record instance independence, overlapping-use behavior, interruption/reset cleanup and first/repeated-use frame results before listing a component as validated.
