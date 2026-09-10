# Shared standards — draft 0.1

## Established technical safeguards

These carry forward the measured [Vanguard rendering fix](../../../docs/FRAME_TIME_INVESTIGATION.md). They are engineering constraints, not claims that the owner has approved a new spell's appearance.

- Configure shader features during resource preparation. Change parameters such as tint, alpha and emission energy during combat; avoid repeatedly switching features such as emission or transparency modes on impacts.
- Retain material templates and reusable geometry across short-lived effects and rounds. Prepare the needed mesh/material variants during loading, with hidden instances or an appropriate validated warmup strategy. Verify the first actual draw; hidden warmup is not a guarantee that every pipeline is ready.
- Share immutable resources. Keep per-instance fade, tint and animation state independent so one spell cannot alter another. Pool objects where profiling justifies it; fully reset pooled state before reuse.
- Avoid resource loading, shader creation, mesh construction and file writes in the impact path where practical. Measure allocations and overdraw before choosing an optimization.
- Give every transient effect a finite lifetime. Handle cancellation, target removal and round teardown. Persistent effects must terminate when their associated gameplay state ends.
- Presentation follows combat events. Do not delay an instant cast, apply extra damage, change hit areas, add collision, or alter an existing network contract as a side effect of visual work.
- Preserve inherited locomotion and equipment alignment. Do not recreate or overwrite a character to add a spell effect.

## Starting measurement policy

- Reference target: 60 FPS gives a 16.67 ms frame budget. Record actual settings and hardware; this is not a universal hardware guarantee.
- Report median, p95, p99, worst frame, and counts above 33.333, 50 and 100 ms for first and repeated rounds. Preserve every measured frame and its event context.
- Treat new spell-correlated frames over 33.333 ms as investigation triggers; include smaller consistent regressions too. Compare to the same-machine baseline rather than silently accepting a new hitch because mean FPS remains high.
- Retain focus flags and exclude background-cap intervals from foreground conclusions. Label load/round boundaries and retain them in raw data. Say whether shader caches were retained or cleared.
- Preserve honest limits: asynchronous GPU timing is separate from CPU frame-end intervals; event overlap alone does not identify a unique cause. Test controls when attribution is uncertain.

The prior fixed 3v3 result was 23.72 / 20.05 ms worst frames on its documented setup. That is historical evidence, not a preapproved performance budget for every new effect. The current benchmark entry point is `tools/frame_time_benchmark.gd`, with `tools/analyze_frame_capture.py` for per-frame analysis.

## Visual preferences awaiting the first spell review

No shared artistic defaults have been accepted yet. Establish these from actual reviewed animations:

| Aspect | Current status |
|---|---|
| Class palette and signature shapes | Follow current class reference; spell-specific decisions pending |
| Cast/release/impact/recovery timing | Fit live mechanics; stylistic timing pending |
| Motion curves, acceleration and trails | Pending |
| Impact size, particle density and persistence | Pending |
| Brightness, bloom and screen coverage | Pending |
| Ally/enemy readability and AoE edges | Preserve existing distinction; new visual language pending |
| Camera movement and screen effects | Pending; do not add automatically |

When adding an accepted rule, include its feedback ID, scope, example spell/revision and any exceptions. Preserve spell-specific variation unless the owner asks for uniformity in that aspect.
