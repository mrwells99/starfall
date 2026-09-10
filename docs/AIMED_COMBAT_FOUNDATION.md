# Body hitboxes and aimed cooldown foundation

Implemented September 10, 2026. All five classes have 19 padded, animated main-body damage volumes. Existing abilities and the 0.42 m movement capsule retain their existing behavior. No production kit has been converted into an aimed ability.

## Fit and presentation

`scripts/body_hitboxes.gd` defines pelvis, abdomen, chest, neck, head, and paired shoulder, upper-arm, forearm, hand, thigh, shin and foot capsules. The fit is intentionally forgiving, approximately 2–4 cm around the underlying body, with larger radii for Vanguard's substantial plate. Decorative cloth, halos, crystals, hat brims and carried weapons are excluded. Head contact reports the region but has no damage multiplier. All region overlaps resolve to one nearest hit and one damage application.

The movement capsule still handles terrain. Damage volumes are mathematical capsules, not extra colliding physics bodies, so they cannot snag a character on terrain or push other players. Their endpoints follow the actual fitted skeleton, including the accepted Forge v2 jump/transition layers, Outlaw's roll/backflip and Vanguard's weapon grip. No model geometry, texture, source animation, accepted cadence or smoothing value was changed.

Visual review: `artifacts/aimed-combat/review/all-classes.png`, plus front/side sheets named `ember.png`, `luminary.png`, `fulcrum.png`, `vanguard.png`, `outlaw.png`, and Outlaw roll/backflip sheets. Cyan shows body volumes; gold shows the head. These are real Godot renders. Run `godot --path . --script tools/hitbox_review.gd` to regenerate them on the second monitor at 30 FPS.

## Lightweight server representation

`tools/build_hitbox_rigs.gd` extracts skeletons and animation tracks from the current class GLBs. Meshes, materials, textures, lights and visual children are removed. Constant tracks retain one exact key; moving tracks are not resampled. The five compressed scenes total 4,058,621 bytes. Their source and output hashes are recorded in `assets/hitboxes/manifest.json`. A metadata table preserves animation libraries across Godot 4.7's per-library storage and Godot 4.5's older dictionary storage; `character_asset_cache.restore_libraries` restores missing native libraries without duplicating them.

`scripts/hitbox_pose.gd` uses the same live animators with these stripped scenes. Vanguard skips its visual effects while retaining arm poses and recoil. A visual-only cache preserves the previous client warmup and retains loaded models across rounds; dedicated requests load and retain only the compact rigs. The old immutable Model Forge v2 archive is unchanged and its verification passes.

Whenever a class GLB changes, rebuild the compact rigs and run `tests/hitbox_pose_test.gd`. It checks source hashes and compares all body endpoints against the visible character under identical inputs. The current run checked idle, forward/side/diagonal/backward movement, jump/landing, cast/recovery, Outlaw roll/backflip, and Vanguard striking: maximum measured endpoint difference **0.0 m**. Real network animation/interpolation timing is not guaranteed to be identical to an isolated same-input comparison; the generous fit and bounded history account for normal differences, and future ability tuning still needs playtesting.

## Opt-in ability contract

To create the future cooldown ability, add `aim_mode = "hitscan"` to its normal kit dictionary. This initial contract supports **instant button presses**, positive cooldown, integer damage and a range no greater than `Kits.MAX_CAST_RANGE` (currently 18 m). Ordinary `off` controls GCD behavior. A miss spends the cooldown/GCD. No automatic fire, projectile simulation, spread, headshot bonus or cast-time aiming policy is supplied. Those are future design choices.

The existing action-bar binding routes an opted-in ability through camera-center aiming, including vertical aim. A crosshair appears only for a living local player with an opted-in ability, outside menus/edit mode. The client projects the crosshair onto the visible scene, then sends a normalized direction from the character's chest. The server derives the firing origin from its own historical chest volume; clients cannot submit origins, victims, range, damage, or cooldown values. The chest is the current generic gameplay origin, independent of cosmetic gun length; a future ability-specific muzzle rule must preserve the same cover checks.

Server validation covers sender ownership, round epoch, monotonic action sequence, finite/unit direction, motion revision, bounded time, request budget and bounded queue. Execution occurs in physics processing, rechecks phase/life/CC/casting/cooldown/GCD/lockout, and uses authoritative damage and world-duel permission. Walls stop shots, including starts inside a solid wall. Friendly/protected bodies also stop a ray without taking damage. The old tab-target route explicitly refuses opted-in abilities.

`aimed_shot_resolved` delivers the server's result: source, sequence, origin, impact point, hit region, damage and rewind duration. The reliable authority-only result RPC drives hit confirmation; the hit marker is never confirmed from a client prediction. This is the future muzzle-flash/tracer integration point, without adding effects to current abilities.

## Lag compensation and lifecycle

The server keeps at most 20 samples per actor and at most approximately 300 ms of data, permitting a **maximum 250 ms rewind**. Packed capsule endpoints are interpolated between bracketing samples without moving live physics bodies. Death, resurrection, teleports, motion revisions, despawns and round teardown invalidate the relevant history. Pending requests are capped at 32, with one queued request per actor, and cannot survive a round reset.

Snapshots carry a server sample timestamp. The client estimates the displayed scene's time with a 50 ms interpolation allowance. The server limits requested age using its own ENet RTT, a bounded scheduling allowance and the hard rewind cap. Extreme delay or a stale/future timestamp is rejected rather than allowing arbitrary historical hits. Existing terrain is static and checked at shot resolution; historical moving doors/platforms would need an additional design if introduced. Matching client/server builds are required: the existing handshake fingerprint detects the added RPCs.

## Validation and local performance

- Aimed combat: 40/40 checks, including geometry, cover, origin-in-wall, cooldown/GCD, friendly/world protection, head region, malformed/replayed requests, history invalidation, and opt-in crosshair/confirmed-hit feedback.
- Hitbox poses: 97/97; dedicated resource guard: 28/28.
- Existing combat: 82/82; Outlaw abilities: 155/155; Outlaw presentation: 1,387/1,387; shared class presentation: 973/973; repeated local Outlaw matches: 70/70.
- Real ENet dedicated server and client with 75 ms simulated delay each way: two aimed cooldown shots hit a moving target, duplicate/early presses did not deal extra damage, both peers confirmed the same 24 damage, and server character GLBs remained unloaded.
- Existing Outlaw ENet regression also passed with simulated latency: Roll, instant Severe, bleed, airborne Trickshot, resource gain and consumption agreed on both peers.
- All five compact scenes and their actual animator/body-volume setup also passed on the server's pinned Godot 4.5.1 runtime, in an isolated compatibility project. The aiming script compiled there as well.

Local Windows benchmark: Godot 4.7.2, AMD Ryzen 7 7700X, dedicated/headless (no rendered resolution). Six moving scripted actors, two-second warmup followed by **600 recorded 60 Hz ticks per condition**; 114 button attempts and 30 resolved shots in each condition. Baseline uses ordinary targeted cooldown attacks; fitted mode uses the new animated hitboxes/history/hitscan path.

| Measurement | Baseline | Fitted |
| --- | ---: | ---: |
| Mean simulation tick | 0.691 ms | 1.223 ms |
| 95th percentile | 0.995 ms | 1.576 ms |
| 99th percentile | 1.109 ms | 1.885 ms |
| Worst recorded tick | 1.165 ms | 2.124 ms |
| Peak sampled process working set | 128.94 MiB | 144.23 MiB |
| Peak sampled private memory | 77.32 MiB | 91.93 MiB |

The observed working-set increase was approximately **15.3 MiB**, and the mean tick increase **0.532 ms**. This is a short local A/B comparison, not a hosted 1 GB capacity guarantee. There were no remote clients in the timing run; background user activity was uncontrolled. OS/container memory, simultaneous instances, actual server CPU speed and networking need a separate production measurement. Initial scene setup precedes the tick sample; process memory includes startup.

Raw individual ticks: `artifacts/aimed-combat/baseline-ticks.csv` and `fitted-ticks.csv`. Summaries and logs are beside them. `tools/measure_hitboxes.py --godot PATH_TO_GODOT` reproduces the Windows process/tick comparison and measures the engine executable, not its small console launcher. CI includes the combat, pose and delayed-network tests.

## Reversal and deployment

Backups and installed hashes are recorded under `artifacts/aimed-combat/`. `python tools/hitbox_record.py --check-rollback` checks the complete reversal without changing files; `--rollback` restores only this task's paths and refuses if installed files have subsequently changed. No changes have been deployed to the hosted server or pushed to GitHub.
