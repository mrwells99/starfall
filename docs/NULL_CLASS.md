# Null — the Eternal Absence

Implemented locally September 11, 2026 with **Starfall Model Forge v2 + hitboxes-v1**. Select Null in the class picker. The user's ability notes replace the six proposed abilities printed on the concept sheet. “Rouge” in those notes means Null.

Null is a male, non-human rogue who has existed for as long as time. He is the only one of his kind. He wields two sentient blades and draws directly from the warp and spacetime, rather than transmuting cosmic energy. The former Hollowkin concept contributes only its living-shadow aesthetic. There is no wider species, deceased owner, or stolen-memory origin.

The approved reference is [the grey and black class sheet](../art_source/references/null-concept-v2.png). The runtime costume uses the accepted mannequin, a faceless hood, layered charcoal armor, silver edges, torn cloth, diagonal harness and two curved blades with white slit eyes. It has no Fulcrum orb or purple materials. The in-game model is a stylized interpretation of the sheet; the sheet remains the visual target.

## Abilities

**Deadeye detection:** an enemy Outlaw actively casting Deadeye detects stealthed Null using the existing half-opacity visibility, targetability and exclamation-point warning. Detection is observer-specific, not a global Stealth break, and ends with the cast unless ordinary proximity detection still applies. Deadeye's damage retains its existing 18m, clear-LOS and smoke checks.

| Default key | Ability | Current behavior | Range | Cooldown |
| --- | --- | --- | --- | --- |
| 1 | Temporal Strike | Instant filler; 120 damage. | 3 m | None; normal GCD |
| 2 | Backstab | Instant 245 damage; requires the rear 120° of the target. Invalid attempts spend nothing. | 3 m | **30 s** |
| 3 | Kick | Interrupt and 4-second spell lockout. Off GCD. | 3 m | 12 s |
| 4 | Nerve Lock | Instant melee stun for **4 seconds**. | 3 m | 20 s |
| 5 | Stealth | Concealment with proximity detection; details below. Off GCD. | Self | **None** |
| 6 | Haste | **50% movement speed for 6 seconds**. Off GCD. | Self | **25 s** |
| 7 | Blindside | An **unkickable 0.28 s** mobile wind-up with a gray cast bar, then teleport 1.2 m behind the target and face their direction. Preserves existing Stealth through wind-up and teleport. **Off GCD.** Requires a clear route and safe landing at completion. | 18 m | 15 s |
| Shift+1 | Vantage Point | Usable while jumping. Rise for **0.5 seconds**, then ease into a dive with both blades and accelerate toward contact; longer dives travel faster. Contact deals 220 damage and a **4-second stun/knockdown**. Brief recovery; no rebound or backflip. | 18 m | 25 s |
| Shift+2 | Regen Pot | Cleanse attached damage-over-time effects, then regenerate **336 health over 6 seconds**. Off GCD. | Self | 40 s |
| Shift+3 | Chronoshift | Press an ability's normal keybind to refresh **and immediately cast** it for **100 Essence**. Normal cast requirements apply; invalid attempts spend nothing. Reset lock is twice its cooldown, except **Stealth: 120 s**, allowing combat re-stealth. **Cannot reset Kick.** Normal out-of-combat Stealth is unaffected by its reset lock. | Self | None |
| Shift+4 | Smoke Bomb | Drop a fixed cloud. Abilities cannot cross its inside/outside boundary; both inside or both outside can interact normally. Off GCD. | 3 m radius | 30 s |
| Ctrl+1 | Trinket | Shared stun break. | Self | 120 s |

All buttons can be moved and rebound through the existing class-specific controls. The user's explicit timings and percentages are preserved. Damage values, ranges, Backstab's rear angle, Kick/Nerve Lock/Blindside/Vantage cooldowns, and auxiliary off-GCD choices are **initial tuning**, not additional user-approved balance decisions. Existing stun diminishing returns, immunities, and Trinket apply; four seconds is the full first stun.

Vantage can start on the ground or during a jump. Its rise still covers 5 meters in 0.5 seconds, but eases from 16 to 4 m/s. At dive start it captures the gap and a range-speed scale (distance / 0.4 seconds, clamped to 25–65 m/s). Actual dive speed begins at 4 m/s and smoothly approaches `range_scale * (.75 + 1.35 * closing_progress²)`, capped at 65 m/s, with exponential response 24/s. Closing progress is the fraction of the initial gap closed toward the 1m contact boundary; it cannot go backwards or exceed one. A fleeing target does not rebase the range-speed scale. Speed easing is integrated over each step, with large steps subdivided to at most 1/60s, preserving a swept capsule test per ordinary physics tick. All acceleration state is included in the existing movement snapshot/replay dictionary. This owner-requested speed tuning leaves the approved body poses, lift, range, damage, cooldown and recovery unchanged.

A swept movement capsule prevents crossing terrain. Death, control, lost target or blocked movement cancels the move; the dive retains its 2-second chase limit. Recovery lasts 0.18 seconds, followed by normal ground/air movement. Damage occurs once on server-confirmed contact. The Vantage-only presentation layer adds a bent-elbow airborne guard, forward anticipation, separated blades and subtle torso/limb motion; ordinary jumps and source animation clips are unchanged. Client and compact server hitbox rigs use the same final poses. The victim uses a shortened knockdown transition with no Outlaw rebound or long recovery.

## Stealth and combat

### Smoke Bomb — initial playable version, September 13

Smoke lasts 6 seconds in a finite 3m-radius volume centered at the cast position (actor-root distance, matching existing radius-based abilities). The owner reduced its original 5m radius and visual dimensions by 40% and slightly darkened its smoke. Duration and cooldown remain unchanged; no ability was replaced. The rule applies equally to Null, teammates and opponents. Target selection and physical line-of-sight queries remain unchanged: a ray passing through smoke between two outside actors is still valid. Each overlapping cloud checks membership separately.

Direct casts validate before spending and again at completion. Area damage/control, ground-field ticks, secondary healing, Deadeye, aimed hits and Detonation also filter recipients. Vantage and Lasso recheck when their effects land; ordinary movement is not blocked. Attached DoTs/bleeds continue and smoke is not a cleanse. A refreshed recast replaces that Null's cloud; expiry, death and round/duel reset remove it. Chronoshift works normally (60s reset lock for this 30s ability). Smoke is a self utility and does not independently break Stealth; the fixed cloud is visible to everyone and does not follow its owner.

Cloud position/lifetime use the existing identity snapshots, with no new RPC or hitbox-tracking mode. Client-only retained smoke billboards have no colliders, lights or shadows; reduced-effects mode keeps the boundary ring. Matching updated clients/server are required. No publication performed.

### Attack selection — September 13

Owner retained smoothed **H (low turning strike)** for Backstab and restored **original Temporal Strike**. Nerve Lock's existing presentation is unchanged. `null_strike_pose.gd` uses the legacy bank for Temporal Strike and `null_backstab_h.res` for Backstab. H retains its .56s presentation with mild baked curve smoothing, .105s entry and .20s recovery. Existing moving lower body, twin-blade grip, gameplay hit timing and source GLB remain unchanged. All ten source-led choices and J's trial remain saved locally; do not reinstall J without a new request.

Local attack evidence/rollback: `local_resources/animation_cache/entries/starfall/strike-study/ual53/hj-smooth-v1/`. Smoke evidence/rollback: `local_resources/animation_cache/entries/starfall/null-smoke-bomb/r001/`.

### Concealment

- Null sees his own model at 50% opacity and uses crouched idle/walking animation. Allies also see the faded model.
- Enemies initially see no model and cannot target him. Each enemy must stay within **3.5 m for 0.7 continuous seconds**, with line of sight, to detect him. Leaving range or losing sight resets that enemy's detection.
- A detecting enemy sees Null at 50% opacity with no overhead nameplate, health bar, target/focus health frame, or enemy roster health bar. An exclamation mark appears over Null while detected. Null sees this warning if any enemy detects him.
- Entering Stealth clears hostile selection and cancels enemy casts aimed at Null. It suspends mandatory targeting in 1v1 and World duels. Detection allows manual Tab selection; detection itself does not reselect him. Revealing restores normal automatic duel targeting.
- Attacking, using an aimed ability, being attacked, or taking damage breaks Stealth. Blindside preserves existing Stealth; its combat flagging is unchanged. Area control also reveals him. Failed validation does not spend an ability or break concealment.
- Both **attacking and being directly targeted** start/reset the **8-second combat timer**. Stealth is unavailable while that timer is positive.
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

Known visual limits: cloth follows the inherited garment rig rather than cloth simulation, and may look rigid during the brief inverted dive. The approved hybrid now supplies eight directional low-stance gaits; its upper-body motion retains the current crouch performance, phase-aligned to the new legs. The procedural armor and blades simplify the concept's fine engraving and ragged layering. No cinematic warp VFX or final damage rotation has been added; Null's melee attacks do not inherit generic cosmic beams.

## Approved movement hybrid — September 12

**Latest idle timing:** an additional 15% speed-up is applied through `null_ready.gd`'s `PLAYBACK_SCALE = 1.15` (about 9.074 seconds per loop). Only normal idle timing and its corresponding phase samples change; the selected baked pose/sway and all other animations remain intact. Simple tuning: no new previews or test runs requested.

**Ordinary idle, September 13:** owner selected K+ for Null only. `scripts/null_ready.gd` installs `assets/animations/null_ready.res` through the existing visible/compact presenter: the same stance with smooth breathing and continuous weight transfer, 15% faster and 20% wider laterally than preview K. Its 10.4348-second loop and baked idle transition features are separate from the shared movement library. Other characters, stealth idle/movement, all travel loops, refined B smoothing, equipment and abilities remain unchanged. Local choice, previews and rollback: `local_resources/animation_cache/entries/starfall/null-idle/ual53/r003/install/`.

**Current transition choice:** Null refined B remains the movement standard via `scripts/null_living_art.gd` on both rigs. The .31s burst smoothing and r014 independent bounded carry remain. r015 adds a right-biased soft horizontal planting envelope only during rapid interruptions: nominal L .48m / R .46m, .04m shoulder, .08s entry and final .10s release into authored stride. Actual follow-through also respects this envelope. Ordinary loops/transitions, upper-body life, sources, equipment, travel and abilities stay unchanged. Both actual engine versions pass reach/feedback/parity checks. The owner explicitly approved this result and requested the all-character rollout, installed September 13 without changing Null. Record/rollback: `local_resources/animation_cache/entries/starfall/wasd-study/ual53/r015-foot-reach/`; weapon-adapted distribution: `local_resources/animation_cache/entries/starfall/shared-movement/ual53/r001/`. Explicit pre-follow-through restore point retained locally.

The owner approved “okay apply the hybrid to null.” The locally installed `assets/animations/null_locomotion.res` contains 26 portable loops: eight normal, eight slower, eight low-stance directions, and two idles. It combines the approved remake's pelvis/legs with Null's existing upper-body style and captured blade grip; current non-core garment/equipment motion is preserved. `scripts/null_locomotion.gd` installs the same library for visible and compact server presenters, with cached path remapping and cadence fitted to measured movement, walking, slows and Haste. The ordinary production jump, pose-blend, strike, Vantage and equipment pipeline remains in use—not the preview's mesh-assisted contact solver.

Physics, movement speed, collision, ability events and stealth visibility are unchanged. Stealth pose transitions remain 0.38 seconds in / 0.52 seconds out; opacity timing remains 0.48 / 0.52 seconds. The source GLB and compact rig are unchanged. Matching client/server builds containing this presenter and library are required for pose agreement. Local approval, rollback, renders and validation live under `local_resources/animation_cache/entries/starfall/wasd-study/ual53/r002/install/`; final baseline comparison is complete: the existing ENet fixture fails its outdated instant-opacity assertion on both presenters; full ENet pass is not claimed. No Git publication or deployment was performed.

## Rebuild and rollback

Verify both frozen packages, then extract Model Forge v2 to the empty `artifacts/null-forge-v2/seed` folder with `tools/model_forge_snapshot.py --extract`. `tools/build_null.py` reads that recovered source and writes isolated candidates. Verify candidates before installation. Copy the Blender source, GLB, recipe and texture maps together, import with the desktop engine, then run `tools/build_hitbox_rigs.gd -- --class=null` to regenerate only Null's server rig. Keep the complete presenter/kit/authority integration with its matching assets. Re-run the recorded checks; tool-version differences can change output bytes.

Before-edit copies and SHA-256 hashes are in `artifacts/null-forge-v2/before/manifest.json`; the matching installed inventory is `artifacts/null-forge-v2/installed-manifest.json`. Restore only listed changed paths from their before copies and remove only listed new paths after verifying their current hashes still match the installation. Preserve any later edits. The prior concept archive is excluded from model rollback. Nothing was published or deployed.

### Current ordinary jump — September 13

Null uses the selected omni-jump B body and softer airborne feet, with the subsequently approved Arm B counterbalance and rightward torso correction. Right/right-diagonal jumps now mirror the successful left jump's upper-body response; all accepted lower-body keys remain unchanged. Arms gather, counterbalance and recover through separate phases. This is a portable 18-clip normal/stealth bank, shared by visible and compact server presenters through `null_jump_art.gd`; actor travel, gravity, movement speed, ability timing and ground movement/idle are unchanged. Outlaw keeps the original B comparison. Arm A and the prior Null bank remain saved locally for fast reversal. Installation record: `local_resources/animation_cache/entries/starfall/omni-jump/ual53/r003-arms/install/class-record.json`.

Current ordinary jumps: all six characters now use the approved Null Living balance B body motion, .28s takeoff/.38s moving/.54s idle landing smoothing and contact-ended long-fall life. Only carrying arms/fingers and final weapon attachment differ (Outlaw gun right, Luminary staff right, Fulcrum orb left, Vanguard two-handed hammer; Ember unarmed). Null's stealth torso/head directional rotation is reduced by 80% toward its existing standing-low flight pose; normal jumps, lower-body keys, ground locomotion, K+ idle, gameplay and source GLBs are unchanged. New Subtle continuity A and original r003 Arm A remain saved for Null. Local rollout/rollback and class records: `local_resources/animation_cache/entries/starfall/shared-jump/ual53/living-b-v1/`.

Historical elbow-only and boundary revisions remain saved under r005-elbow-fall/ and boundary-smoothing-v1/; the Living balance record above supersedes their presenter settings.
