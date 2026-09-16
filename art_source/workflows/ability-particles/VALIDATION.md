# Ember r001 validation — September 16, 2026

Status: installed local experiment; owner visual/balance approval pending. No commit, push, client release or server deployment.

## Automated checks

Actual Godot 4.5.1 results:

| Check | Result |
| --- | --- |
| New Ember mechanics, concealment, fades, local clocks, snapshot round-trip and pool bounds | 53/53 |
| Existing Ember abilities | 80/80 |
| Ember Model Forge presentation | 261/261 |
| All-class identity regression | 125/125 |
| Visible/compact server hitbox poses, including skate and release | 155/155; maximum endpoint difference 0.000000477m |
| Deadeye/stealth regression | 9/9 |
| Saved per-character controls | 19/19 |
| September balance regression | 21/21 |
| Dedicated runtime, compact rigs and no server render models | 67/67 |

Total: **790 assertions passed** across these suites. New and existing Ember real-ENet host/client tests both pass with 75ms injected delivery delay. The new test verifies live owner movement, enemy position masking and hidden model, trail replication, immunity, early recall, route arrival and restored normal state. Latest peak compressed snapshot payload in that six-character/two-Ember fixture: **1,292 bytes**, without an MTU warning. The older network fixture still prints its preexisting ObjectDB shutdown-leak warning; the new fixture drains delayed timers and exits cleanly.

A synthetic six-maximum-trail snapshot is 25,808 bytes before compression, under the 65,536-byte decoder limit; it compresses to 1,836 bytes even with identical paths. **This stress case exceeds a single ENet MTU and may fragment.** Mixed gameplay is not proof that six simultaneous maximum paths are loss-proof. A future large-scale pass should move persistent trail history to a reliable change stream or measure bounded path simplification; cosmetic particle frames must never be networked.

Portable Linux adapter: **5/5 tests** for flattened/nested layout, Windows mapping, manifest-relative video paths, path containment and workflow naming. Original shelf verification checked **78 manifest videos**, all sizes/checksums matching. The imported source inventory ran successfully: 4,492 file records, 26 skate filename matches, no parse errors. These are file/metadata counts, not unique approved motions.

All eight pinned texture files pass the source manifest's SHA-256 verification. Git checks confirm the imported libraries remain ignored while the workflow, tools and runtime assets are visible. Scoped diff whitespace checks pass; unrelated preexisting Spell Forge CRLF changes were preserved.

## Actual renderer review

Native Forward+ on AMD Radeon RX 7800 XT (RADV), 1280×800. Inspected ring/safe center, Kindle trajectory/tail, brief ignition, heated-ground warning, eruption, white flare, barrier, skate trail, owner ghost with entry statue, return path and reappearance. Corrected an inherited spawn-transform offset and disabled physics interpolation on locally animated particle batches. Native review logs have no script/shader errors after correction.

The repeatable native review tool and optional Linux recording helper are tracked. The completed native recording is 35s, 1280×800, 30 fps (1,050 frames); sampled frames confirm the intended preview window and Ash reformation. Local images/video are under `artifacts/ember-particles/`, not Git. The older PNG sequence is sampled at 7.5 fps; the X11 recording helper captures the preview window at 30 fps. Neither capture mode is a performance benchmark.

## Frame-time observations and limits

Two uncaptured rounds each, effect rendering on versus off, 60 FPS cap, VSync on, retained shader caches, six actor scene with one Ember compositor exercised. The control disables this compositor's updates/draws but retains setup and gameplay; it is **not** a pre-change checkout. Most frames were unfocused although the tool kept its 60 FPS cap, so these are not foreground performance qualification results. Wall intervals include pacing; isolated GPU times were not collected.

| Rendering | Round | Median ms | p95 ms | p99 ms | Worst ms | Frames >33 / >50 / >100ms |
| --- | --- | --- | --- | --- | --- | --- |
| Effects on | 1 | 16.66 | 19.15 | 20.45 | 191.57 | 1 / 1 / 1 |
| Effects on | 2 | 16.68 | 19.43 | 20.95 | 166.62 | 1 / 1 / 1 |
| Effects off | 1 | 16.67 | 19.27 | 20.77 | 159.81 | 1 / 1 / 1 |
| Effects off | 2 | 16.64 | 19.25 | 20.63 | 168.89 | 1 / 1 / 1 |

The long frames occur at scene/round setup. Excluding the first 400ms of each round, worst observed intervals are 24.03/27.43ms with effects, and 27.14/24.90ms without. These controls do not isolate preparation cost, and the first draw may include pipeline work. No claim of hitch-free loading or universal 60 FPS is made. The final trail pool was enlarged from 192 to 288 capacity to cover all 96 gameplay samples; this review's visible trail count stayed below 192. Six simultaneous full stacks and other GPUs remain unmeasured.

Machine-readable summary: `frame-time-summary.json`. Raw local logs and source/tool evidence: `diagnostics/ember-particles-r001/`; raw frame intervals: `artifacts/ember-particles/benchmark-on/` and `benchmark-off/`. Existing cold-setup cost and pathological trail bandwidth are follow-up measurement targets, not hidden successes.

## Commands

```sh
godot --headless --path . --log-file /tmp/ember-tests.log --script tests/ember_particle_abilities_test.gd
python tests/run_ember_particle_network.py --test-latency
python tests/run_ember_network.py --test-latency
godot --headless --path . --log-file /tmp/ember-poses.log --script tests/hitbox_pose_test.gd
godot --headless --path . --log-file /tmp/server-runtime.log --script tests/server_runtime_test.gd -- --dedicated
python tests/test_motion_resources.py
python art_source/workflows/ability-particles/assets.py
godot --path . --log-file /tmp/ember-benchmark.log --script tools/ember_particle_review.gd -- --benchmark
godot --path . --log-file /tmp/ember-control.log --script tools/ember_particle_review.gd -- --benchmark --effects-off
```

Run native measurements separately from encoding, importers and test suites. Keep all frames, focus flags and round boundaries; report outliers as well as averages.
