# Charge and Fulcrum combat update — September 9, 2026

## Fulcrum

- Successful Inward grants four seconds to use one instant, off-GCD Collapse. Collapse's own 18-second cooldown remains.
- A landed Collapse grants four seconds to use one instant Graviton. Graviton keeps its normal global cooldown.
- Using a buff consumes it; expiry removes it. Another qualifying cast refreshes four seconds without stacking. Failed attempts neither spend nor refresh the remaining window.
- `identity.instant_collapse` and `identity.instant_graviton` now store seconds instead of booleans. Authoritative ticking, casting, bots, aura countdowns and hotbar highlights share these fields. Snapshots carry exact remaining time. Identity resets clear both.
- Horizon and the direct Anchor stun are removed from play and the ability library. Their internal slots 2 and 3 are reserved as `unavailable`, so existing bindings for every other ability and class stay at the same indices. Both old slots are blank; direct requests cannot cast them. Gravity Anchor remains available because it powers the displacement and Collapse mechanics.
- Inward and Outward cancel the target's current cast only when the capsule actually moves. Displacement resistance or zero movement does not interrupt. Cancellation adds no school lockout and does not refund the target's GCD.
- Heavy Orbit remains a 6m radius around the anchor. Inward/Outward use a 9m anchor-relative reach, derived as `HEAVY_ORBIT_RADIUS * 1.5`. Their existing 18m caster-to-target cap and caster-to-anchor limit remain. Travel distance remains up to 8m.

## Vanguard Charge

Charge roots the target immediately on acceptance for up to 3 seconds, using the existing root immunity and diminishing returns rules. Vanguard then travels continuously at 32m/s and stops in melee range, dealing the existing 6 damage once on arrival. Its 12-second cooldown and off-GCD behavior remain.

Initial validation still checks target, range, facing, LOS and caster control. A safe route is also required before cooldown or root is spent. After acceptance, LOS, range and facing are not revalidated. Input, jump requests, other casts and later control do not overwrite the committed route. Target death, disappearance or loss of world-duel permission releases the charger without applying delayed damage.

`scripts/vanguard_charge.gd` first tries a direct ground-following capsule route. Detours reuse the arena navigation grid and ramp entrances, testing candidate path segments against actual collision. Blocked edges are removed and the search tries another route. Travel sweeps the capsule each step, leaves a small clearance after contact, and replans after a collision or target displacement. No teleport through walls or terrain is used. Unreachable targets are rejected before acceptance; a temporarily blocked in-flight route waits safely and retries while the target remains valid.

The remaining route and target are included in combatant snapshots. Movement prediction can replay the same collision-safe travel without applying root or damage. Ordinary animation remains unchanged outside Charge; during the rush, fast displacement uses locomotion instead of being mistaken for a teleport or jump. The frozen Model Forge v2 package is unchanged.

## Validation

- `tests/fulcrum_meditation_test.gd`: four-second boundaries, consumption, refresh, failed casts, missed Collapse, restored cast/GCD behavior, independent replicated timers, aura/hotbar expiry, Horizon retirement, displacement interrupts, range boundaries, and previous Meditation/DoT behavior.
- `tests/vanguard_charge_test.gd`: immediate root, multiple travel frames, delayed single impact, initial LOS rejection, target movement behind cover, new/thin obstacles, a long physics frame, both terrace ramps in both directions, unreachable targets, death/duel cleanup, and isolated client route replay. Every travel sample checks capsule overlap.
- `tests/run_charge_network.py --test-latency`: real host/client ENet, 75ms one-way artificial delay, replicated root, target displacement behind a pillar, continued visible travel and exactly one impact.
- The shared combat, class identity, range, HUD, ability-library and character presentation suites cover surrounding behavior.

Final local results: Fulcrum 166/166, Charge 352/352, shared combat 82/82, class identity 89/89, spell range 71/71, team HUD 108/108, ability library 46/46, model presentation 973/973 and rendered ability art 193/193. The delayed ENet host/client check passed with 55/58 observed travel samples. The Forward+ movement review ran on the secondary monitor. The focused Charge suite recorded a peak simulation tick of 4.36ms on this machine; this is not a full-match frame-time benchmark. Godot's rendered tests reported an existing texture-resource cleanup warning on exit.

Generate the player-facing ability reference with `tools/class_reference.gd`. Local code and docs are updated; no commit, push, exported build or server deployment is included.
