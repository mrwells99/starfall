# Forward+ and environment quality assessment

Verified on 2026-09-08 with Godot 4.5.1 stable (`f62fdbde1`).

**Subsequent owner-approved rollout:** the owner approved the visual treatment across the full arena. Forward+ High is now the project default, with Compatibility available. This supersedes the optional-only recommendation below; the original measurements and concurrent-host limitations remain unchanged. Pillar artwork was restored as requested. See `ART_SLICE_HANDOFF.md`.

**Forward+ is technically viable on this host and worth an optional High graphics path.** It successfully renders the existing arena on a physical AMD Radeon RX 7800 XT. Keep Compatibility as the default during the corner trial: a trustworthy full-combat frame budget still needs an uncontended host run before a default switch.

## 2026-09-09 follow-up: isolated arena optimization

The owner reports smooth gameplay at the defaults (60 FPS, 100% 3D resolution), with RX 7800 XT utilization reduced from roughly 75% to 30% by the earlier settings changes. Those percentages are owner observations, not measurements from this test. The owner closed the editor/game for this follow-up. Native process checks found no other Godot instances and GPU busy was 4–5% before testing. Desktop/compositor activity remains; clocks were not locked. This is a short test on one GPU, not a minimum-hardware certification.

Shipped 48 index-only LOD levels across 16 of the 17 authored arena mesh resources; the remaining 12-triangle recess needs none. Full-detail packed vertices, normals, indices, UVs/UV2 and lightmap sizes are preserved. Runtime architecture uses `lod_bias = 0.5`; collision, character assets, textures, effects and 100% rendering scale remain intact. Compressed meshes grow by about 0.36 MiB. The stone shader also skips a third noise calculation on horizontal surfaces where its runoff contribution is exactly zero. Experimental position-only shadow meshes caused a visible shadow regression and were discarded.

Godot 4.5.1 / native Wayland / Forward+ / RX 7800 XT / actual **1920×1080**, Balanced, scale 1.0, focused 60 FPS. Four serialized six-player local match samples ran in **before / after / after / before** order. Baseline strips only the new arena LOD indices and restores the previous stone shader. Each run warms for 60 physics ticks and samples the next 360; HP is held full. This includes animation, effects, UI and combat, but short seeded runs do not cover every combat state or shader compilation path.

| Six-player sample | GPU mean | GPU p95 | Frame mean | Frame p95 |
| --- | ---: | ---: | ---: | ---: |
| Before 1 | 3.696 ms | 3.720 ms | 16.758 ms | 16.789 ms |
| After 1 | 3.565 ms | 3.589 ms | 16.666 ms | 16.682 ms |
| After 2 | 3.567 ms | 3.591 ms | 16.666 ms | 16.673 ms |
| Before 2 | 3.696 ms | 3.720 ms | 16.666 ms | 16.672 ms |

Mean GPU time fell **3.5%** in these samples. This is not a prediction that utilization will fall from 30% to a particular number. Maximum frame times ranged from 21.9 to 66.1 ms across runs, so this is also not a claim of hitch-free play in every state. Raw local output: `artifacts/arena-match-timing.log`. The fourth process printed its complete sample but needed the outer timeout during shutdown; no test processes remained afterward. The benchmark now explicitly frees its game scene before quitting.

A separate fixed-camera LOD-only comparison, with 90 warmup frames and 120 samples per variant in before/after/after/before order, measured:

| View | Before GPU mean (pair average) | After GPU mean (pair average) | Rendered primitives before → after |
| --- | ---: | ---: | ---: |
| Gameplay | 2.736 ms | 2.661 ms | 3,224,631 → 2,863,171 |
| Close | 2.764 ms | 2.760 ms | 3,328,199 → 3,174,479 |
| Overview | 2.057 ms | 1.908 ms | 2,252,325 → 1,605,081 |

Counts include renderer passes, not just unique model triangles. LOD splitting increases draw calls slightly, so triangle reductions must not be advertised as equivalent speedups. The floor shader alone saved about 1% in the gameplay view; other views showed negligible changes. Native close/gameplay/overview image pairs are under `artifacts/arena-lod-*.png`; timing records are `artifacts/arena-lod-timing.json` and `artifacts/arena-shader-timing.json`.

Validation: mesh integrity **248/248**, map **57/57**, combat **81/81**, and native close/gameplay/overview visual comparisons passed.

Reproduce fixed-camera LOD timing using `godot --path . --display-driver wayland --audio-driver Dummy --script tools/arena_lod_review.gd -- --timing`. For active samples use `tools/local_match_benchmark.gd`; `--bench-no-arena-lods` removes the new indices in memory, and `--bench-shader-before=/absolute/path/to/baseline.gdshader` optionally restores a saved baseline shader. The review accepts `--shader-before=/absolute/path` to isolate shader changes. Always inspect actual resolution/focus/cap and verify no competing game/editor before interpreting results.

## Performance evidence correction: concurrent host workload

**The active-match timings below were collected while an independent editor and game were running on the same host. They cannot establish the game's intrinsic frame rate or identify a CPU/renderer bottleneck.** Late native host inspection at approximately 21:10 found `godot project.godot` (PID 664913, elapsed about 23 minutes) and a separately running game launched with `--remote-debug tcp://127.0.0.1:6007 --editor-pid 664913 --scene res://arena.tscn` (PID 668106, elapsed about 19 minutes, roughly 80% CPU). The latter started around 20:51, before the active samples from roughly 20:53 onward. No unrelated process was stopped.

Only this task's test launches were serialized; that did **not** make the host idle or GPU access exclusive. Earlier references to exclusive access, combat CPU bottlenecks or failure to reach a stable 60 FPS must be read with this correction. The static samples around 20:49 appear to predate the second game, but the editor was already present and host idleness was not recorded. Treat those timings as short observations too, not a controlled renderer speedup claim.

The renderer/device identity, successful rendering and screenshots remain valid. Timing distributions and monitors are preserved for transparency, but host contention, asynchronous compilation and differing combat states prevent causal conclusions. **Stable 60 FPS is unverified, not disproven.** Run no further performance trial until host idleness can be established without interfering with the user's other work.

## What the machine actually supports

The restricted command environment exposes no `/dev/dri`, and its `vulkaninfo` sees no usable GPU. Authorized host execution reports a **discrete Radeon RX 7800 XT (RADV NAVI32), Vulkan 1.4.354, Mesa RADV 26.1.7**. OpenGL on the same card is 4.6, Mesa radeonsi 26.1.7.

Forward+ under **Xvfb** still fails: Godot reports missing DRI3 presentation support, cannot find compatible graphics/present queues, and crashes before the test script. This is a display-path limitation, not evidence that the actual machine lacks a Vulkan GPU. Native **Wayland** successfully starts `forward_plus` / `vulkan`, renders and saves a real image, and exits cleanly. The libdecor GTK warning is cosmetic in these runs.

`--headless` selects Godot's dummy renderer on this binary. It remains appropriate for logic tests but cannot validate Forward+ images or GPU performance. Use the native display for render validation. Earlier llvmpipe measurements in the art handoff remain historical software-rendering observations; they do not describe the native Wayland GPU path discovered here.

## Original map: measured renderer comparison

The two static captures used the same scene, camera at `(-0.1, 5.8, 13.6)` looking at `(-7, 1.5, 5.1)`, 58° FOV, hidden HUD and no actors. The actual capture is **2560×1440**; the initial probe requested 1280×800 before saved display settings/compositor policy overrode it. Both runs rendered the same 1,191,425 reported primitives. VSync was requested off. Each sampled 240 frames following 120 warmup frames.

| Original map | Mean frame | Median | 95th percentile | Observed FPS | Last-frame draws | Reported video memory |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Compatibility / OpenGL | 5.61 ms | 5.78 ms | 9.41 ms | 178 | 294 | 156 MiB |
| Forward+ / Vulkan | 2.65 ms | 2.40 ms | 4.68 ms | 377 | 215 | 427 MiB |

These are short rendered-loop observations on one relatively powerful GPU, not isolated GPU timings, a low-end hardware guarantee, or a full-match benchmark. The second game appears to have started later, but the editor was present and an idle host was not verified. Consequently these samples do not establish a reproducible renderer speedup. The reported allocations and changed lighting still inform the trial. No unsupported materials, missing geometry, or runtime shader errors were observed in these captures. Emissive lights, fog and background brightness differ visibly between APIs, so merely changing the renderer is not a finished art pass.

- [Compatibility original corner](../artifacts/renderer-assessment/arena-compat-baseline/capture.png) and [measurement](../artifacts/renderer-assessment/arena-compat-baseline/report.json).
- [Forward+ original corner](../artifacts/renderer-assessment/arena-forward-baseline/capture.png) and [measurement](../artifacts/renderer-assessment/arena-forward-baseline/report.json).

## Full combat must set the budget

The probe also supports an active six-bot 3v3 with all four classes, animation, spell effects, simulation and HUD. Its camera is the existing local gameplay camera. A first 15-second Forward+ sample at 2560×1440 averaged **24.97 ms / 40.0 FPS**, with median 12.26 ms and p95 108.92 ms, while the match remained active. The measured final frame had 1,003 draw calls and about 3.09 million primitives. By the capture, both Vanguards had been defeated: this is ongoing 3v3, not a controlled six-alive worst-case stress test. This contended observation does not establish whether the game can sustain 60 FPS by itself.

Host contention is a confirmed confounder. Pipeline compilation and changing combat states are additional factors, but the measurements do not isolate their contribution. Do not attribute the spikes to Forward+, combat CPU work, animation or the environment, and do not call the static corner's 377 FPS the game's frame rate. Follow-up samples recorded pipeline counters and process/physics monitors, which also reflect the contended run.

The original-map Compatibility control, also 15 seconds at 2560×1440, averaged **20.48 ms / 48.83 FPS**, median 15.34 ms, p95 48.59 ms. About 42.5% of frames exceeded 16.67 ms. It reported no new pipeline compilations during the sample, and its sampled process/physics monitors averaged 23.42/19.78 ms. Those monitors are periodically updated engine observations, not exclusive GPU timings or proof of an intrinsic simulation bottleneck under concurrent host load. Both runs remained active matches, and their moving scenes differ over time. Neither a controlled renderer ranking nor a CPU optimization priority can be established from these runs.

- [Forward+ first combat sample](../artifacts/renderer-assessment/combat-forward-baseline/report.json) and [capture](../artifacts/renderer-assessment/combat-forward-baseline/capture.png).
- [Compatibility combat control](../artifacts/renderer-assessment/combat-compat-baseline/report.json) and [capture](../artifacts/renderer-assessment/combat-compat-baseline/capture.png).

## Corner + optional High: active trial

Once the corner and High profile were integrated, two native Wayland runs used the same seeded six-bot setup, 120 warmup frames and 15-second samples, at actual 2560×1440. This task's test runs were serialized, but the independently running editor and game described above were concurrent. The original control explicitly used `--sanctum-original`; the upgraded run used `--sanctum-high`.

| Active 3v3 / Forward+ | Original control | Corner + High trial |
| --- | ---: | ---: |
| Mean rendered-loop frame | 37.91 ms | 31.90 ms |
| Median frame | 12.70 ms | 14.44 ms |
| 95th percentile frame | 163.85 ms | 165.55 ms |
| Frames above 16.67 ms | 29.3% | 31.6% |
| Sampled physics monitor | 20.69 ms | 20.90 ms |
| New surface pipelines reported | 24 | 32 |
| New draw pipelines reported | 0 | 16 |
| Fighters alive, start → end | 6 → 5 | 6 → 4 |
| Reported video memory | 531 MiB | 1,169 MiB |

**Do not interpret either the means or medians as a renderer speed ranking.** Concurrent host load, different combat states and pipeline compilation confound the timings. High reported a larger allocation, but its actual steady-state frame cost remains unmeasured on an idle host. This trial proves the upgraded map and effects can render during real combat on this GPU; it neither certifies nor disproves a consistent 60 FPS release setting. The enabled profile uses SSAO, SSIL, modest volumetric fog, 2× MSAA, a more restrained sky and glow, alongside the corner's authored materials, relief details, reflection probe and candle light. Subsequent material refinements should be included when uncontended profiling becomes possible.

The High capture was visually checked: the ground cues, fighter silhouettes, health/cast displays and ability icons remain readable. The ordinary gameplay camera may show foreground perimeter decoration when a bot backs toward the boundary; these shots are match evidence, while the parent's fixed corner images are the material/lighting comparison.

- [Original Forward+ active control](../artifacts/renderer-assessment/combat-forward-warm/report.json) and [capture](../artifacts/renderer-assessment/combat-forward-warm/capture.png).
- [Corner + High active trial](../artifacts/renderer-assessment/combat-forward-high/report.json) and [capture](../artifacts/renderer-assessment/combat-forward-high/capture.png).

Recommendation: keep High optional and finish the map art review. Before making performance-driven changes, obtain an uncontended run, record other host processes and device load, prewarm every ability effect and compare equivalent combat states. Then distinguish rendering from local simulation cost and, if useful, compare a client connected to a dedicated server. Current evidence supports the graphics path's viability; it does not yet identify a performance bottleneck. Texture resolution should still be selected for visible material detail, not treated as a frame-time remedy.

## Upgrade priorities

For the map's fixed architecture, continue using its existing baked indirect light and add authored surface variation, convincing roughness/normal detail, material contrast and restrained practical lights. Baked lighting suits static scenes and can retain low runtime cost on both renderers; changing the global lighting profile requires rebaking. [Godot 4.5 LightmapGI](https://docs.godotengine.org/en/4.5/tutorials/3d/global_illumination/using_lightmap_gi.html)

For the optional High profile, prioritize subtle SSAO/SSIL for contact and bounce, antialiasing and careful atmospheric separation. A local reflection probe is useful for bronze/material response. Volumetric fog is available but must leave silhouettes and ground telegraphs readable. Defer SDFGI and screen-space reflections until a visible need justifies their cost; the current map is static and is mostly rough stone. This ordering is an art/performance recommendation, not a claim that all these effects have passed combat profiling.

Forward+ supports SSAO, SSIL, volumetric fog, SDFGI, screen-space reflections and TAA; Compatibility does not. Both support 3D MSAA, reflection probes and displaying baked lightmaps. Godot 4.5 can automatically fall back to Compatibility when its RenderingDevice backend is unavailable, although the Xvfb crash observed here prevents treating fallback as universally reliable. Web exports still require Compatibility. [Godot 4.5 renderer comparison](https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html)

Higher resolution helps only where authored detail survives the gameplay camera. Going from 512² to 1024² adds four times as many texels, and 2048² adds sixteen times as many, before compression/mipmaps. Use targeted materials on nearby floor/cover/walls, preserve mipmaps and anisotropic filtering, and inspect grazing angles. Upscaling existing pixels cannot create the wear, mineral variation and roughness structure currently missing.

## Reproduce without changing project defaults

`tools/renderer_probe.gd` writes the actual renderer, driver, adapter, captured resolution, frame distribution and screenshot. It returns nonzero if the requested renderer silently falls back. It does not change `project.godot`, materials, or saved keybinds.

```sh
godot --path . --display-driver wayland --audio-driver Dummy \
  --rendering-method forward_plus --script res://tools/renderer_probe.gd -- \
  --expect=forward_plus --warmup=120 --samples=240 \
  --output=/tmp/starfall-renderer-corner
```

For Compatibility use `--rendering-method gl_compatibility --expect=gl_compatibility`. Add `--minimal` to isolate renderer startup. Add `--combat --duration=15 --warmup=240 --samples=300` for the active six-bot scenario. The optional `--sanctum-high` project flag can be appended after `--` once the High profile is integrated. `--sanctum-original` disables the corner treatment for an original-map control. The host may require approval to access the actual graphics device/display; do not substitute dummy/headless or Xvfb measurements for the native GPU run. Before performance use, verify host idleness and save a process/device-load snapshot; do not stop unrelated user processes to obtain it. The probe itself cannot certify exclusive host access.
