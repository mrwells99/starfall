# Outlaw — Starforged Drifter

Playable first pass, September 9, 2026. Built from the approved Outlaw concept and Starfall Model Forge v2. The robot wears blackened steel, brass, a weathered duster and cowboy hat, with amber optics, a blue celestial revolver and a crimson-etched Bowie knife. The owner requested the knife at **150% of its first-pass size** and a real closed-hand grip. It is held across the left palm in a reverse grip, with the blade clear of the torso; the right hand holds the revolver.

## Kit

| Default key | Ability | Current behavior |
| --- | --- | --- |
| 1 | Starshot | 8 damage; 0.7s stationary cast; 18m. Basic filler added for this first pass. |
| 2 | Severe | 15% of current target HP, rounded to an integer; 2 bleed damage each second for exactly 5 seconds. 3m melee range; 0.6s normal cast while moving; kicks cannot cancel it or apply a lockout. 4s cooldown. |
| 3 | Trickshot | Separate instant, off-GCD shot for 12 damage. Requires one unspent airborne Backflip opportunity or a flying Coin Toss. A successful hit grants one Defense Detonation stack, maximum three. |
| 4 | Backflip | High backward leap; no damage. Grants one airborne Trickshot opportunity and immunity to new crowd control and displacement until landing. 12s cooldown; off GCD. |
| 5 | Ward | Shared 5s protection reducing damage by 60%; 22s cooldown; off GCD. |
| 6 | Mend | Shared 28-HP self heal after 2s; 16s cooldown. Completing it removes attached DoTs, including Severe. |
| 7 | Roll | Up to 6m over 0.55s, following movement input including diagonals; stationary fallback follows camera heading. Stops at terrain. 10s cooldown; off GCD. Completion grants **one second for one instant Severe**; a successful Severe consumes it, while a rejected attempt leaves the remaining timer intact. Severe retains its own cooldown and GCD. |
| Shift+1 | Coin Toss | Throw a visible coin along camera heading in a 1.8s arc. A Trickshot can ricochet around cover if player-to-coin and coin-to-enemy paths both clear terrain. The coin collides with terrain and its opportunity ends on impact, timeout or successful use. |
| Shift+2 | Defense Detonation | Consume three stacks to channel three shots at one-second intervals, each dealing 10% of maximum target HP. Normal movement remains available. Kicks neither cancel it nor apply a lockout; other applicable CC can stop it. Each shot checks living target, duel permission, 18m range and LOS. |
| Shift+3 | Deadeye | Automatically mark all eligible enemies, including enemies initially behind cover or outside range. Three-second windup while restricted to walking and unable to jump. Kicks neither cancel it nor apply a lockout; other applicable CC can stop it. At completion, each marked enemy within 18m and clear LOS takes 40% maximum HP damage. No tab selection or front-facing filter. 90s cooldown spent at start. |

The final Deadeye clarification supersedes the earlier front-facing answer: everyone is acquired, and final sight range/terrain decide hits. Backflip itself never deals damage or awards resources; the separate successful Trickshot does. Both combo windows are single-use. All authoritative combat state resets at round and duel boundaries and is included in network snapshots. Shared shields, mitigation and world-duel permissions still apply.

Values explicitly requested by the owner are preserved. Unspecified ranges, cooldowns, windups and Trickshot/Starshot damage above are initial tuning choices, not settled balance. Severe's ordinary short cast makes the requested Roll instant-cast buff meaningful. Roll has one cooldown rather than Ember's two stored Blink casts.

Severe's moving cast preserves ordinary movement speed, the existing global cooldown and Roll's one-second instant follow-up. Completion still checks melee range and terrain; hard crowd control can still cancel it. Its windup retains directional locomotion, followed by the knife strike. Kick-immune casts, including Severe, Defense Detonation and Deadeye, show neutral gray fills on personal, target, focus, party and enemy cast bars. The color uses the same immunity predicate as combat and also follows temporary airborne kick immunity.

## Model and animation record

- Editable source: `art_source/outlaw_ual/outlaw.blend`; portable game model: `assets/characters/outlaw.glb`.
- Reproduction recipe, four packed image maps and completed class record: `art_source/outlaw_ual/`.
- Builder: `tools/build_outlaw.py`; source verification: `tools/verify_outlaw.py`.
- The mannequin's 53 core rest bones and all 32 accepted clips have zero deviation against the frozen v2 contract. Body vertices are unchanged. The final rig has 85 bones and 36 clips; added weapon controls parent directly to the carrying hands.
- The downloaded Universal Animation Library supplies Roll, pistol aim/fire and Sword_Attack. The sword action is mirrored for the left knife hand. There is no dedicated Backflip clip in this download: Backflip adapts reversed Roll to the physical leap duration.
- Normal locomotion retains v2's directional sectors, reversed walking at 1.15 cadence for backpedaling, 0.90 running cadence, upper-body turn, bent-elbow jump arc and short final-pose smoothing. Rejected r006/r007 jump changes remain excluded.
- Outlaw-specific layers retain the native closed fist on the fingers and apply pistol motion to the right arm or knife strikes to the left. Mobile channels retain moving legs. Roll/Backflip add a brief entry blend; their capsule movement remains authoritative.
- Cloth is bone-driven. This is a stylized procedural interpretation of the concept, not a photorealistic reproduction or a cloth-simulation asset. Extreme knife strikes and tight rolls may need additional costume clearance refinements following gameplay feedback.

`tools/outlaw_review.gd` opens the actual runtime model on screen 0 (the owner's secondary monitor), with front/back/side views and looping movement/ability demonstrations, capped at 30 FPS. `-- --outlaw-capture` saves review frames under the ignored `artifacts/outlaw-forge-v2/` directory. Visible reviews do not capture keyboard focus.

## Verification and rollback

HUD follow-up: saved action-bar positions from a larger display could hide all abilities below a smaller viewport. Unmoved bars now keep their responsive bottom anchors; off-screen custom bars recover to distinct default rows on load or resize. Ability order, keys and valid custom positions remain intact. `tests/hotbar_viewport_test.gd` reproduces the reported saved coordinates, checks all ten abilities across three viewport sizes and validates custom-layout recovery. Both headless and Forward+ runs passed 81 checks; existing layout migration passed 15 checks. Restart a running game to load the corrected HUD code.

September 10 crash follow-up: the captured Deadeye error was an invalid `WalkLeft` lookup; Forge v2's sideways walking clips are `StrafeLeft`/`StrafeRight`. Outlaw's mobile casting and weapon recovery now use those actual names. The HUD recovery also searched a typed HBox array with the saved CrowdControl VBox; its type is now checked first. Stray text and mixed indentation in the live shared presenter were repaired so fresh matches can parse it. Crash logs and pre-fix files are preserved under `artifacts/outlaw-forge-v2/crash-2026-09-10/`.

Indentation recurrence: after a later save, `model_forge_art.gd` again contained mixed tabs/spaces at line 47. The four errors in `champion_model.gd` at lines 21/23/25/29 were cascading imports of subclasses sharing that broken base. The original one-space-per-level layout was fragile under the editor's four-column tab conversion. The entire shared presenter now uses one tab per nesting level. A comparison verifies that all non-indentation text is unchanged. `tests/check_presenter_indentation.py` enforces this format, and CI directly parses `champion_model.gd` in addition to the arena. Fresh standalone parses, a normal main-scene local 3v3 startup, and a fresh editor import pass. The pre-normalization file is retained under `artifacts/outlaw-forge-v2/indent-recurrence-2026-09-10/`.

Expanded verification: 1,323 Outlaw presentation checks cover every direction at two headings during Deadeye, Detonation, walking shots and knife strikes. The complete saved-HUD fixture passes 82 checks. `tests/outlaw_local_match_test.gd` starts, casts and leaves three actual local matches (1v1 followed by two 3v3), exercising the full rendered arena at 30 FPS on screen 0 and all eight Deadeye directions; 70 checks pass in Forward+ with a read-only copy of the owner's preferences. Gameplay remains 97/97 and the other fitted-class presentation suite 973/973. The renderer still prints the pre-existing seven-texture shutdown warning, with no script or Vulkan surface errors in the passing run. The suite wrapper now rejects engine/script errors even when Godot exits zero and prints passing assertion counts; its eight synthetic checks pass.

Source validation compares 111,830 inherited bone/frame samples, mannequin vertices, normalized skin weights, UVs and packed maps. Gameplay tests cover exact tick damage, timed combo consumption, every roll direction, terrain, airborne CC, channel movement, final Deadeye sight rules and snapshot serialization. `tests/run_outlaw_network.py --test-latency` exercises real ENet host/client behavior with 75ms simulated action delay.

The pre-Outlaw text backup is `artifacts/outlaw-forge-v2/before/manifest.json`. `tools/outlaw_forge_record.py` records installed hashes and the completed v2 class record. Its `--rollback` mode first verifies installed files have not changed since recording, then restores only this pass's modified files and removes only recorded new outputs. It refuses to overwrite later edits. The approved concept sheet and frozen Forge v2 package are retained. No git commit, push, deployment or executable export is part of this installation.
