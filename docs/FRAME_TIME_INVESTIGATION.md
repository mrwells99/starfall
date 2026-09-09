# Ability-impact frame stalls: measurements and fix

Recorded 2026-09-09 on the owner's Windows computer. The requested native 3v3 benchmark reproduced severe stalls around ability impacts. Replaying the same actions in a second round did **not** remove the recurring stalls. Two changes to Vanguard presentation removed them in the measured production-fix run.

## Result

| Game state | Round | Active frames | Median | 95th percentile | 99th percentile | Worst frame | Frames >50 ms | Frames >100 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Original | 1 | 2,084 | 16.62 ms | 18.97 ms | 154.70 ms | **864.18 ms** | **55** | 41 |
| Original, identical replay | 2 | 2,103 | 16.62 ms | 18.48 ms | 149.48 ms | **157.30 ms** | **54** | 39 |
| Production fix | 1 | 2,392 | 16.66 ms | 17.68 ms | 18.39 ms | **23.72 ms** | **0** | 0 |
| Production fix, identical replay | 2 | 2,400 | 16.66 ms | 17.52 ms | 18.20 ms | **20.05 ms** | **0** | 0 |

Both fixed rounds also had zero frames above 33.333 ms. All four rounds were focused throughout active measurement. The fixed run used normal production effects, with no diagnostic effect suppression. It reproduced the original **586 ordered cast/resolve/impact events per round**, including simulation ticks, participants and damage/healing text; there were zero replay acceptance errors. These are results for this recorded workload, not a guarantee that every future frame or machine will meet this bound.

![Individual frame intervals before and after the fix](../artifacts/frame-capture/frame-times.png)

The original worst frame lasted 0.864 seconds. No active baseline frame exceeded one second, so a literal zero-FPS sample was not reproduced. The game's smoothed FPS display can obscure the individual intervals that make the game feel frozen.

## Machine and game identity

| Item | Recorded value |
|---|---|
| Game | Starfall **0.11.0** |
| Baseline revision | `cb8f0118f550d27df8fccf6d8397a001f6c0cc16` plus existing local scene/import/project edits |
| Fixed revision | Same checkout, with local `vanguard_authored.gd` and `vanguard_strike.gd` changes; no release/version or network protocol change |
| Engine | Godot **4.7.2-stable official**, `ed1daf0bf001b61586d9930840f2f1394092c079` |
| Rendering backend | **Forward+ / Vulkan 1.4.351** |
| GPU | **NVIDIA GeForce RTX 5060 Ti** |
| NVIDIA driver | **616.64**, Windows version `32.0.16.1664`, driver date 2026-08-23 |
| CPU | **AMD Ryzen 7 7700X**, 8 cores / 16 logical processors |
| Actual window and viewport | **2560 × 1440**, fullscreen, 100% 3D scale |
| Graphics / pacing | Balanced, 60 FPS cap, VSync enabled, approximately 200 Hz display |
| OS | Windows 11 Home, `10.0.26200` |

The editor was closed before capture. No other Godot or Blender process was present at the initial check; NVIDIA reported 0% GPU use at that check. Other desktop processes and GPU clock states were not continuously controlled. Hardware evidence is in [`hardware.json`](../artifacts/frame-capture/hardware.json). The baseline's eight preexisting local edits are listed there and were preserved.

## Which events freeze?

**108 of the 109 baseline frames longer than 50 ms overlap logged impact events.** A single frame can contain several abilities, so an overlap is not proof that every listed ability independently caused that entire stall. The complete frame-by-frame attribution, including overlapping calls and the preceding 50 ms of context, is in [`forward-baseline/hitches.csv`](../artifacts/frame-capture/forward-baseline/hitches.csv); raw event timestamps are in the adjacent `events.json`.

Representative identical events in the original two rounds:

| Event | Simulation tick / time | Round 1 nearby frame | Round 2 nearby frame | Interpretation |
|---|---|---:|---:|---|
| Vanguard Charge impact | 33 / 0.550 s | 864.183 ms | 87.092 ms | Large first-use cost diminishes, but repeated impact-resource stall remains; Stasis start and Disrupt also occur in the first frame |
| Entropy tick hitting Vanguard | 160 / 2.667 s | 156.891 ms | 149.669 ms | Repeated victim hit-flash stall |
| Stasis resolution hitting Vanguard | 336 / 5.600 s | 161.085 ms | 155.913 ms | Repeated victim hit-flash stall |
| Vanguard Sundering Blow | 454 / 7.567 s | 82.646 ms | 87.468 ms | Repeated hammer-impact resource stall |
| Graviton tick hitting Vanguard | 729 / 12.150 s | 155.531 ms | 150.881 ms | Repeated victim hit-flash stall; another target event occurs nearby |

The table's nearby-frame metric is the maximum of the frame ending at/after event completion and the following two frames, to include deferred rendering work. It is explicitly a correlation window. `analysis.json` also retains direct call durations and exact overlapping frame events.

Other overlapping impact names include Kindle, Oathbreaker, Flashpoint, Stitchlight, Supernova, Falling Star, Disrupt, Absolution, Iron Skin, Last Light and Sanctuary. Healing/guard events can share a stalled frame with damage. The evidence points to **Vanguard being hit, and Vanguard's outgoing hammer damage**, rather than all those ability implementations independently being slow.

One **271.553 ms** baseline frame at round 1 tick 11 has no overlapping or preceding-50-ms ability event and no pipeline counter increment. Its cause remains **unattributed**. It occurred early, did not recur in the identical second round, and was absent from the fixed run. It must not be counted as a proven ability or shader stall.

## Isolation and cause

Six two-round captures were completed: **12 rounds and 24,937 raw rendered frame records**, including startup, boundaries and marked unfocused intervals. Each pair used the same combat workload. Controls were run before changing production files.

| Capture | Change | Focus qualification | Frames >50 ms, R1 / R2 | What it established |
|---|---|---|---|---|
| `forward-baseline` | None | Both fully focused | 55 / 54 | Stalls survive identical second-round actions |
| `forward-no-beams` | Suppress impact beams | Both fully focused | 54 / 54 | Beams are not the recurring cause |
| `forward-no-flash` | Suppress character hit flashes | Partial focus; exclude background intervals | 13 / 2 in focused portions only | Large ~150 ms stalls disappear; Vanguard's smaller outgoing-impact stalls remain |
| `forward-stable-emission` | Keep emission feature enabled; change energy only; profile hammer FX | R1 interrupted; R2 fully focused | R1 not used / 15 | Preserving visible flashes still removes the larger stalls |
| `forward-retained-vfx` | Stable emission plus retained hammer material | Both fully focused | 1 / 0 | Repeated hammer stalls disappear; only first use remains |
| `forward-production-fix` | Actual fixed game, including loading-time prewarm | Both fully focused | 0 / 0 | No >33.333 ms gameplay intervals with normal effects enabled |

Partial controls are not comparable full-match totals. In the no-flash run, focused portions cover approximately 29.93 / 7.35 seconds. Lost focus invokes the game's intended 15 FPS background cap, producing ~67 ms intervals unrelated to combat. Those intervals remain in the raw data and are excluded from focused conclusions. The final diagnostic and production capture pause simulation when unfocused; neither actually lost focus during its active rounds.

### 1. Hit flashes changed Vanguard's shader features during combat

`vanguard_authored.gd` previously toggled `StandardMaterial3D.emission_enabled` on impact and off on recovery for normally non-emissive surfaces. Repeating damage/recovery repeatedly changed material shader configurations across the character's surfaces. The original rounds each incurred **528 surface** pipeline increments and **188 / 186 draw** increments. Suppressing flashes, or leaving the feature enabled with zero energy between flashes, removed the recurring ~150 ms stalls.

The fix enables emission once when constructing Vanguard's materials. Normally dark materials use zero energy; authored luminous materials retain their original energy. Hit flashes still use white emission at energy 2, and defeat still dims authored emission. Runtime changes affect parameter values without switching that shader feature.

### 2. Every hammer impact recreated its material/shader resources

`vanguard_strike.gd` previously constructed a fresh material and arc/spark meshes per confirmed damage event, then discarded them when the 0.2-second effect ended. Profiling isolated approximately **65–70 ms in material assignment/associated rendering preparation**, not the arc math: vertices took about 0.04 ms, normal generation about 0.006 ms, and mesh commit about 0.04 ms. Expanded probes measured **69.727 ms** on first material assignment, versus **0.016 ms median / 0.024 ms maximum** after retention in the second diagnostic round. Attaching the prepared arc node itself was about 0.004 ms.

The fix retains a material template and both meshes across impacts and rounds. Each impact duplicates the template for independent tint/fading, shares immutable meshes, and retains its original shape, placement and animation timing. Two hidden mesh/material instances are prepared during character loading, moving first-use preparation out of combat. Damage calculations, targeting, cooldowns, networking and attack animation selection are unchanged.

The actual fixed capture recorded zero surface pipeline increments in both rounds, four draw/specialization increments in round 1, and zero of either in round 2. Those four first-round increments did not produce a long frame. Counter increments alone do not prove a stall; timings and the controlled comparisons supply that evidence. Godot documents why changing shader features during play can trigger pipeline compilation and why loading-time instances can help precompile them: [Godot pipeline compilation guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

This evidence supports the focused presentation changes. An attack-system rewrite would not directly address the measured shader-feature and resource-lifetime causes.

## Verification and limits

- Production Forward+ 3v3 capture: all 586 events match baseline in each round, including damage/healing text; zero replay errors; zero active frames >33.333 ms.
- Vanguard presentation: **849/849**, both native Forward+ and Compatibility. Compatibility was also run through the project's `tests/check_suite.sh` result/exit-status wrapper. This is a Windows run, not a rerun of Linux Xvfb CI.
- Combat: **81/81**. Class identity: **91/91**. Dedicated-server runtime: **27/27**, with `--dedicated --port=27189`. Ability art: **195/195** under Forward+.
- New regression assertions cover stable emission features through damage/recovery/death, original glow levels, independent concurrent effect colors/fades, shared geometry, hidden idempotent warmup, and transient effect cleanup.
- Rendered before/after front, back, flash, shield/strike and arc/spark reviews are saved in `visual-review/`. Normal armor, purple crystals, hit flashes and weapon effects were visually checked. The images are not pixel-identical: mean absolute channel differences are below 0.001 on a 0–255 scale across all five paired views (`visual-comparison.json`).
- Async GPU median was approximately **3.99 ms before**, **6.16 / 6.22 ms in the fixed capture**; fixed maximum was 7.08 / 7.02 ms. This increase is recorded, not hidden. GPU clocks/background load were not controlled, so its cause is not isolated. The retained-material diagnostic measured about 4.01 ms. The demonstrated improvement is frame pacing, not a claim of reduced steady GPU cost.
- The frame measure is monotonic CPU wall time between `RenderingServer.frame_post_draw` callbacks. It includes blocking on rendering but is **not OS presentation latency** or input-to-photon latency. GPU timing is asynchronous and should not be assigned as an exact same-frame breakdown. See [RenderingServer timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).
- Existing Godot and driver caches were retained. Round 1 means first use in that process, not a cleared-driver-cache test. Startup and round-load frames remain in raw CSV but are excluded from active-combat percentile tables.
- Each round runs 40 seconds of fixed simulation, with Fulcrum/Ember/Luminary versus Vanguard/Ember/Luminary. Incoming lethal damage is clamped to leave 1 HP so all six remain active. Round 1 records real AI decisions; round 2 replays those actions and therefore skips AI decision CPU work. It is a controlled local simulation, not a six-machine networking/latency test.
- **29 unique abilities resolved**, not every ability in every class. Percentiles use linear interpolation over sorted raw intervals. No averaged FPS was used to locate freezes.
- Godot printed a seven-texture-RID shutdown warning in baseline and fixed arena captures (also in ability-art testing). It occurs at process teardown; it was not introduced by this change. The first server-test attempt omitted its required dedicated flag and failed; the correctly configured invocation passed. Neither is evidence of an active-combat rendering failure.

## Evidence, repeatability and rollback

The local bundle is [`frame-time-evidence.zip`](../artifacts/frame-capture/frame-time-evidence.zip). It contains per-frame CSVs, event JSON, input tapes, metadata, analyses, every >50 ms frame's attribution, controls, test logs, the plot, visual comparisons, source snapshots and a SHA-256 manifest. `cross-run-verification.json` checks all 12 event sequences against the original first round. Large character assets and Python package dependencies are excluded; the game repository supplies those assets. `artifacts/` remains ignored by Git.

To repeat the fixed capture from the project folder, close the editor and keep the game focused:

```powershell
& '<path-to-Godot-console.exe>' --path C:/projects/starfall --rendering-method forward_plus --script tools/frame_time_benchmark.gd -- --capture=res://artifacts/frame-capture/new-run --seconds=40 --pause-unfocused
python tools/analyze_frame_capture.py artifacts/frame-capture/new-run
```

Preserve the resolution, Balanced preset, 100% render scale and 60 FPS cap when comparing. The harness records the actual selected settings; use a fresh output directory. `tools/frame_time_arena.gd` provides instrumentation and replay, while `tools/frame_time_strike.gd` preserves the original strike implementation with diagnostic timing probes. Its diagnostic replacement is deliberately different from the fixed production implementation. Historical controls require the original production source; simply running their flags against the fixed game does not recreate the old baseline. Keep `hitches.csv` together with `frames.csv` and `events.json` when investigating a specific event.

Only two production scripts changed. Their original copies are in `artifacts/frame-capture/baseline-source/`; exact fixed copies and a patch are in the evidence bundle. If rolling back later, reverse only these presentation changes after checking for newer edits; do not restore the whole project or the character-forge archive. All preexisting scene/import/project changes were left intact. No commit, push or deployment was performed.
