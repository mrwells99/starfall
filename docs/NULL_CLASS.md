# Null — the Eternal Absence

Implemented locally September 11, 2026 with **Starfall Model Forge v2 + hitboxes-v1**. Select Null in the class picker. The user's ability notes replace the six proposed abilities printed on the concept sheet. “Rouge” in those notes means Null.

Null is a male, non-human rogue who has existed for as long as time. He is the only one of his kind. He wields two sentient blades and draws directly from the warp and spacetime, rather than transmuting cosmic energy. The former Hollowkin concept contributes only its living-shadow aesthetic. There is no wider species, deceased owner, or stolen-memory origin.

The approved reference is [the grey and black class sheet](../art_source/references/null-concept-v2.png). The runtime costume uses the accepted mannequin, a faceless hood, layered charcoal armor, silver edges, torn cloth, diagonal harness and two curved blades with white slit eyes. It has no Fulcrum orb or purple materials. The in-game model is a stylized interpretation of the sheet; the sheet remains the visual target.

## Abilities

| Default key | Ability | Current behavior | Range | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Stab | Instant filler; 12 damage. | 3 m | None; normal GCD |
| 2 | Backstab | Instant 35 damage; requires the rear 120° of the target. Invalid attempts spend nothing. | 3 m | **30 s** |
| 3 | Kick | Interrupt and 4-second spell lockout. Off GCD. | 3 m | 12 s |
| 4 | Nerve Lock | Instant melee stun for **4 seconds**. | 3 m | 20 s |
| 5 | Stealth | Concealment with proximity detection; details below. Off GCD. | Self | **None** |
| 6 | Haste | **50% movement speed for 6 seconds**. Off GCD. | Self | **25 s** |
| 7 | Blindside | Instantly teleport 1.2 m behind the target and face their direction. **Off GCD.** Requires a clear route and safe landing. | 18 m | 15 s |
| Shift+1 | Vantage Point | Rise vertically for **0.5 seconds**, then dive with both blades. Contact deals 22 damage and a **4-second stun/knockdown**. Brief recovery; no rebound or backflip. | 18 m | 25 s |
| Ctrl+1 | Trinket | Shared stun break. | Self | 120 s |

All buttons can be moved and rebound through the existing class-specific controls. The user's explicit timings and percentages are preserved. Damage values, ranges, Backstab's rear angle, Kick/Nerve Lock/Blindside/Vantage cooldowns, and auxiliary off-GCD choices are **initial tuning**, not additional user-approved balance decisions. Existing stun diminishing returns, immunities, and Trinket apply; four seconds is the full first stun.

Vantage rises at 10 m/s for 0.5 seconds, then tracks its target at 25 m/s until contact. A swept movement capsule prevents crossing terrain. Death, control, lost target or blocked movement cancels the move. Recovery lasts 0.18 seconds, followed by normal ground/air movement. Damage occurs once on server-confirmed contact. The victim uses a shortened knockdown transition with no Outlaw rebound or long recovery. Motion reference: the jump/dive near 12 seconds in [Death From Above animation](https://www.youtube.com/watch?v=6dBBNWlKVg8).

## Stealth and combat

- Null sees his own model at 50% opacity and uses crouched idle/walking animation. Allies also see the faded model.
- Enemies initially see no model and cannot target him. Each enemy must stay within **3.5 m for 0.7 continuous seconds**, with line of sight, to detect him. Leaving range or losing sight resets that enemy's detection.
- A detecting enemy sees Null at 50% opacity with no overhead nameplate, health bar, target/focus health frame, or enemy roster health bar. An exclamation mark appears over Null while detected. Null sees this warning if any enemy detects him.
- Entering Stealth clears hostile selection and cancels enemy casts aimed at Null. It suspends mandatory targeting in 1v1 and World duels. Detection allows manual Tab selection; detection itself does not reselect him. Revealing restores normal automatic duel targeting.
- Attacking, using an aimed ability, being attacked, or taking damage breaks Stealth. Area control also reveals him. Failed validation does not spend an ability or break concealment.
- Both **attacking and being directly targeted** start/reset the **10-second combat timer**, as clarified by the user. Stealth is unavailable while that timer is positive.
- DoT and bleed ticks reveal Null but do **not** refresh the combat timer. He can re-enter Stealth between ticks when otherwise out of combat.
- The authority decides concealment, detection, targeting, combat timers, damage and movement. Clients display the replicated state and predict movement; client visibility does not authorize attacks.

## Source, review and verification

- Editable packed Blender source: [null.blend](../art_source/null.blend).
- Runtime model: [null.glb](../assets/characters/null.glb); portable mesh-free server rig: [null_rig.scn](../assets/hitboxes/null_rig.scn).
- Recipe, textures and completion record: [null_ual](../art_source/null_ual/).
- Builder: `tools/build_null.py`; source check: `tools/verify_null.py`; interactive model review: `tools/null_review.gd`.
- Live reviews are capped at 30 FPS on the secondary monitor. `--capture` writes the actual runtime model poses under `artifacts/null-forge-v2/model-review/`. `tools/hitbox_review.gd -- --class=null` writes front/side and special-move hitbox pictures under `artifacts/null-forge-v2/review/`.
- The frozen source check preserves 53 core rest bones and 32 accepted motions exactly; three added clips support knife strikes and crouching. The packed model includes five texture maps and two hand-parented blade controls.
- All 19 body capsules follow the same final pose on the visible and server rigs, including stealth, lift, dive, recovery and strikes. Weapons and flowing cloth are excluded. Normal head damage and the existing movement capsule are preserved. The project's pre-existing enlarged aiming transform remains in force.
- Evidence, complete test logs, source/rig hashes, actual older-engine animation playback, visual limits, and installation hashes are recorded in `art_source/null_ual/forge-record.json`. Automated fixtures cover owner and opponent views over local ENet with 75 ms simulated latency. They are not a claim of production deployment or human online acceptance.

Known visual limits: cloth follows the inherited garment rig rather than cloth simulation, and may look rigid during the brief inverted dive. Crouched movement uses a native forward crouch clip across movement directions. The procedural armor and blades simplify the concept's fine engraving and ragged layering. No cinematic warp VFX or final damage rotation has been added; Null's melee attacks do not inherit generic cosmic beams.

## Rebuild and rollback

Verify both frozen packages, then extract Model Forge v2 to the empty `artifacts/null-forge-v2/seed` folder with `tools/model_forge_snapshot.py --extract`. `tools/build_null.py` reads that recovered source and writes isolated candidates. Verify candidates before installation. Copy the Blender source, GLB, recipe and texture maps together, import with the desktop engine, then run `tools/build_hitbox_rigs.gd -- --class=null` to regenerate only Null's server rig. Keep the complete presenter/kit/authority integration with its matching assets. Re-run the recorded checks; tool-version differences can change output bytes.

Before-edit copies and SHA-256 hashes are in `artifacts/null-forge-v2/before/manifest.json`; the matching installed inventory is `artifacts/null-forge-v2/installed-manifest.json`. Restore only listed changed paths from their before copies and remove only listed new paths after verifying their current hashes still match the installation. Preserve any later edits. The prior concept archive is excluded from model rollback. Nothing was published or deployed.
