# Null — Vantage Point

## Identity and status

- Spell identifier: `vantage`; record slug `vantage-point`; wind revision r001, 2026-09-12; Spell Forge draft 0.1.
- **B / Fast slipstream approved and installed locally.** The owner chose “i choose B” on 2026-09-12 after the saved r001 neutral comparison. [Feedback SF-001](../../../FEEDBACK.md#sf-001--2026-09-12--vantage-point-wind-b). A and C are unselected, not deleted or approved.
- Original candidate names: A — Natural airflow; B — Fast slipstream; C — Turbulent wake. The r001 comparison and all source hashes remain preserved; runtime uses B with production visibility/cleanup safeguards.
- Working local checkout, not published. Wind smoke checks passed on Godot 4.7.2 and 4.5.1. Rendered comparison is a separate preview, not a gameplay performance sign-off.
- Existing Vantage body poses, character models, equipment and live animation assignments are unchanged by this wind work. The comparison uses the neutral Quaternius source mannequin without Null's character identity, from `art_source/fulcrum_ual/AnimationLibrary_Godot_Standard.glb`.

## Mechanics and timing contract

The wind must follow the existing ability state. It must not introduce movement, damage, stun, hit areas, collision, targeting, resource changes, network authority or extra cast delay.

| Phase | Gameplay trigger / duration | Character motion | Proposed wind | Cancellation / end |
|---|---|---|---|---|
| Lift | Successful Vantage activation; 0.5 seconds | Existing eased 5m lift; already usable while jumping | Air wisps rise beside the body and open near the apex | Hide and clear on cancellation or invalid state |
| Dive | Lift completes; chase ends on contact, obstruction, interruption or 2-second limit | Existing target-directed accelerating dive, described below | Direction-aligned wake grows with actual dive speed | Clear when dive ends without valid recovery |
| Impact | Existing authoritative contact test | Existing impact pose; no VFX-driven displacement | Brief outward airflow transition | Never cause a second hit or imply an extra hit area |
| Recovery | Existing 0.18-second recovery | Existing recovery pose | Wisps dissipate | Wind reaches zero opacity by recovery end; defensive candidate expiry at 0.22 seconds |
| Idle / cleanup | No active Vantage phase | Existing locomotion | None | Reset all per-instance state on cancellation, death and round teardown |

- Existing mechanics to preserve: effective range 18m, cooldown 25 seconds, authoritative damage 220 and stun 4 seconds. Existing movement, facing, target validity, swept collision and interruption rules remain authoritative.
- The earlier speed tuning is already live **separately from the wind preview**: dive entry is 4m/s; base speed is `clamp(initial_distance / 0.4, 25, 65)`; desired speed is `min(65, base_speed * (0.75 + 1.35 * progress²))`. Progress is monotonic against the fixed initial dive distance, so retreating targets do not rebase it. Speed approaches the goal at response 24/s, with analytically integrated travel and substeps no larger than 1/60 second. The speed cap remains 65m/s, contact distance 1m, recovery 0.18 seconds and chase limit 2 seconds.
- No additional mechanics changes are approved or implied by choosing a wind style.

## Artistic recipe — approved B

- All three options use thin, softly fading pale gray-blue wind ribbons, not a character model replacement. Natural airflow is restrained; Fast slipstream is longer and denser; Turbulent wake is wider and more curled.
- Current editable candidate uses three retained MultiMesh nodes with 18 allocated wisps; styles activate 12, 18 and 16 respectively. Three tapered ribbon meshes and one unshaded alpha material are shared; transforms, colors, phase blends and seed state belong to each effect instance. No added lights, shadow casting, GI, particle systems or custom shaders.
- Phase-relative curves follow lift, travel direction, speed and recovery. Deterministic seed values vary the wisps without runtime randomness. The effect anchors at the feet and converts the world-space travel direction into its local orientation. Soft tapered ribbon half-width is .040m; exact per-phase/style settings are retained in the hashed editable source.
- Runtime defaults to B / style 1, using the approved geometry and lift/dive/recovery formulas without body or weapon changes. Each visible Null allocates the effect during model setup; compact server/pose-only actors skip it entirely. A top-level node follows actor feet, with world-space airflow direction. Dive speed reads replicated `dive_current_speed` when available; other phases use presentation velocity with an authoritative velocity fallback. Phase time shares the existing smooth snapshot animation clock.
- Observer-local policy hides and clears the effect immediately for stealthed opponents, including proximity-detected opponents and the character's fade transition. Owners/allies multiply the wind's per-instance opacity by the model's current stealth opacity. No shared material opacity changes. Reduced-effects mode disables the decorative wind; missing phase, death, stun and root clear it, and actor teardown frees the retained nodes.
- Approval SF-001 is specific to Vantage Point B. It does not establish shared palette, trail, timing or density standards for other spells.

## Sources and reproducibility

All paths below are relative to the repository root.

- Installed reusable procedural asset: `scripts/null_vantage_wind.gd`; presenter integration: `scripts/null_art.gd`; local reduced-effects option passed at the existing observer update in `scripts/arena.gd`. Runtime depends on no ignored library/cache/preview paths. Original preview asset: `artifacts/null-vantage-wind-20260912/vantage_wind.gd`. There are **no newly baked animation clips**; the wind is implemented by editable code.
- Preview viewer: `artifacts/null-vantage-wind-20260912/viewer.gd`; isolated existing-motion snapshots: `motion_snapshot.gd`, `pose_snapshot.gd` and `blend_snapshot.gd` in that same directory. These snapshots support the comparison and do not replace live scripts.
- Smoke suite: `artifacts/null-vantage-wind-20260912/wind_test.gd`. Run the selected Godot console with `--headless --path . --script artifacts/null-vantage-wind-20260912/wind_test.gd`.
- Comparison artifact: `artifacts/null-vantage-wind-20260912/wind-candidates.gif`, generated through the viewer and `package_preview.py`: 168 frames, seven seconds, neutral 1200×700, 24 FPS at **0.65× playback**. Slowed playback is for review; it does not change live ability timing. Native capture used Godot 4.7.2 Compatibility/OpenGL 3.3, 4× MSAA, NVIDIA RTX 5060 Ti / driver 616.64. Final capture completed without errors; rise, dive and recovery frames were inspected.
- Populated persistent cache: `local_resources/animation_cache/entries/vantage-wind/neutral-mannequin/r001/`. It holds the actual effect, isolated motion helpers, runnable viewer/test/packaging scripts, preview, logs and `metadata.json`. Cached code is not used by live gameplay. The cached smoke suite passes 482/482; all six recorded asset hashes match. Local resource audit passes 1881/1881 over 826 retained local files, including this cache.
- r001 effect SHA-256: `94737379bbf33bf6514cbd6d9e804e220d13cf19b328c0252327f5a5062e45ae`; reviewed GIF: `f3ba1a35f12dc7602062a79c2c3165a97ba11ed4d794a74a41659669d50bb409`. Source mannequin, 53-bone rest signature, viewer and helper hashes are in cached `metadata.json` with the regeneration recipe.
- Meshes and material are prepared when the candidate is constructed and retained; phase updates change per-instance transforms and colors. `clear()` / `reset()` hide the effect and zero its state. Hidden allocation is not proof that the first visible draw is warmed.

## Validation record

- Wind candidate smoke: **482/482 on Godot 4.7.2 and 482/482 on Godot 4.5.1**. Logs: `artifacts/null-vantage-wind-20260912/wind-test-4.7.2.log` and `wind-test-4.5.1.log`.
- Covered all three styles through lift/dive/recovery, finite transforms, bounded opacity and conservative extent, expiry, immediate cancellation, zero-direction fallback, rotated-parent direction, non-finite input and reuse of the same mesh/node resources. These are isolated candidate checks, not full live integration tests.
- Installation regressions: `tests/null_vantage_wind_test.gd` passes **71/71 headless and 85/85 native Compatibility**, using actual visible/compact actors. Headless buffer checks use retained CPU state because Godot's dummy renderer does not expose actual MultiMesh GPU buffers; the extra 14 native checks read submitted transforms/colors after render frames, including owner/enemy stealth and reveal. Logs and before/after records: `artifacts/null-vantage-wind-install-20260912/`.
- Exact approved B motion preservation: 810/810 comparisons against the cached original B across three headings and all phases (per-wisp transforms, alpha and visibility). Promoted component in an isolated Godot 4.5.1 project: 482/482. A separate direct 4.5.1 full-checkout test was invalid due to the pre-existing LimboAI minimum-engine and mixed-version imported-animation issues; it is explicitly not counted as passing. No addon/import changes were made to address it.
- Re-run with this installation: abilities 153/153, Vantage presentation 52/52, hitbox pose 145/145 with 0m endpoint error, aimed combat 41/41 and dedicated runtime 67/67. An independent read-only review found no actionable runtime issues. Existing model GLBs, skeleton layers, movement/collision and spell mechanics remain unchanged.
- Separately completed speed/mechanics regressions: Null abilities 153/153; Vantage speed 133/133; presentation 52/52; hitbox pose 145/145 with 0m observed error; aimed combat 41/41; dedicated server 67/67. Evidence and limitations: `artifacts/null-vantage-speed-20260912/result.json`. These results do not validate wind visibility or rendering cost.
- Existing speed tests cover ground/air starts, moving targets, snapshot replay, variable frame steps, contact, walls and interruptions. Body-pose validation remains separate from the new wind's visual acceptance.
- Native 3v3 actual-arena check: two Nulls cast Vantage twice per nine-second round, two fresh rounds per run, with Vanguard/Luminary healing effects overlapping. Eight Vantage casts per run and lift/dive/recovery draws were verified; baseline/candidate/repeat-control combat-event signatures match. Actual-model images `render/candidate/motion-001.png`, `motion-004.png`, `motion-006.png`, `motion-008.png` show rise/apex/dive/impact. No production model, scenery or input changes were made by the benchmark.
- Environment: Godot 4.7.2, Forward+/Vulkan, Ryzen 7 7700X, RTX 5060 Ti / driver 616.64, Balanced, actual 1200×694 viewport, 1.0 render scale, forced 30 FPS, secondary monitor, existing driver/project caches retained. Baseline and repeat-control were OS-unfocused; candidate was OS-focused despite the same NO_FOCUS request. **This is not a matched-focus performance certification or a 60 FPS guarantee.** Hide-only control isolates new wind drawing, not total wind CPU-update cost. GPU timings are asynchronous, and there was no cold-cache test.
- Baseline first/repeat median/p95/p99/worst milliseconds: `33.307/34.493/35.903/47.783`, `33.352/34.538/35.225/38.865`. Candidate: `33.312/34.318/35.518/43.348`, `33.295/34.714/35.718/39.237`. Repeat-control: `33.319/34.351/36.120/42.161`, `33.307/34.530/35.352/35.708`. All rounds have 269 measured frames; counts above 33.333ms are baseline 132/137, candidate 131/130, control 132/126; all have zero over 50 or 100ms. With a 30 FPS cap, roughly 33.333ms intervals are expected.
- First actual wind draw: tick 81, 35.356ms, one additional draw/specialization pipeline; no new wind pipeline increments on repeat. First Vantage-window worst: candidate 36.528ms versus baseline 36.549ms and repeat-control 36.046ms. Largest first-round frames in each run occur at the earlier healing start (tick 61), not wind. No new persistent wind-correlated hitch was observed under these limited conditions. Raw frames/events/focus/pipeline data and analysis are retained in `artifacts/null-vantage-wind-install-20260912/render/{baseline,candidate,control-repeat}/` and `render/comparison.json`. Loading boundaries are retained separately from measured combat.
- Limits: no human online playtest or universal first-cast guarantee. Native arena shutdown reports the same seven Texture RID leaks in both controls and candidate; no script errors occurred during capture. This shared exit warning was not addressed by the wind change. Headless gameplay/visibility checks, native buffer checks and visual acceptance are separate from the limited frame-time comparison.

## Feedback and revision history

| Revision / date | What changed | Feedback IDs | Review status | Sources |
|---|---|---|---|---|
| r001 / 2026-09-12 | Three procedural wind alternatives around the existing Vantage motion; neutral mannequin comparison | SF-001 | B selected; A/C retained unselected | `artifacts/null-vantage-wind-20260912/` and persistent cache above |
| r001 B installation / 2026-09-12 | Promote approved B, add observer/reduced-effects/cleanup integration without changing its motion | SF-001 | Installed locally; technical results recorded separately | `scripts/null_vantage_wind.gd`, `artifacts/null-vantage-wind-install-20260912/` |

Record the owner's choice and specific keep/change requests against the final reviewed capture and source hashes. Do not mark an alternative accepted based only on passing smoke tests.

## Installation and rollback

- Installed 2026-09-12: new `scripts/null_vantage_wind.gd`; changes to `scripts/null_art.gd` and `scripts/arena.gd`; new `tests/null_vantage_wind_test.gd`. No model or bone-animation assignments changed. The only arena change supplies the existing reduced-effects option to Null's visibility update.
- New documentation path: `art_source/workflows/starfall-spell-forge/spells/null/vantage-point/RECORD.md`; index entry added to the sibling spell index. The index's pre-edit copy is `artifacts/null-vantage-wind-20260912/before/spell-record-index/README.md`, SHA-256 `fd092a3ea555d4fa6e40d55cdb3eea163196d9ad95c034bc87a7ed0c0306a5ce`.
- Installation before-copies and exact SHA-256 hashes: `artifacts/null-vantage-wind-install-20260912/before-manifest.json`, preserving all prior uncommitted work. To undo only the wind, restore the backed-up Null presenter and arena file only after checking for later edits, remove the new wind script/test and update this approval/install status. Do not restore the entire repository or revert prior speed/character work. Original preview and populated persistent cache must survive artifact cleanup; rejecting/revising a live wind install does not delete reusable source.
- Earlier live speed tuning has a separate rollback record and backups in `artifacts/null-vantage-speed-20260912/`; do not reverse it as part of rejecting a wind option.
- No shared standards changed, no character archive altered, and no commit, push or deployment performed.
- Next step: receive any owner feedback on the installed B in actual gameplay. Publication remains the owner's action. Installation hashes, test results and rollback references are in `artifacts/null-vantage-wind-install-20260912/result.json`.
