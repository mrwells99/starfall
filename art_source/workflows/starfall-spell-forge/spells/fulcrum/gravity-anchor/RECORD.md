# Fulcrum — Gravity Anchor

## Identity and status

- Revision: r001, 2026-09-10; Spell Forge draft 0.1.
- Installed locally. Owner visual acceptance: **not reviewed**. No accepted revision yet.
- Owner request: start with the actual Gravity Anchor model and animation before other Fulcrum effects.
- Engine: Godot 4.5.1; editable asset generated in Blender 5.2.0. This is a freestanding effect with no character rig changes.

## Mechanics and timing contract

The existing 0.6-second cast places the anchor up to 10m ahead, swept against walls and projected onto terrain. It lasts 20 seconds. No cast, movement, damage, collision, targeting, resource, cooldown or replication rules changed.

Presentation reads `identity.anchor_pos`, `anchor_left`, `orbit`, casting state and HP. A successful placement becomes visible immediately, scales from 20% to full size over 0.42 seconds, then gently bobs by 0.045m. Interrupted or invalid casts produce no new placement. Replacement resets the appearance (including replacement at the same position when the timer increases). Expiry, consumption and death hide the entire effect immediately; actor/round teardown frees it. No persistent remnants imply an active field after termination.

The original boundary remains 1m at idle and 6m during Heavy Orbit or the Collapse cast. The physical relic never expands with the range indicator. ALLY/ENEMY and the remaining duration stay visible above the model. Reduced effects shows the full-size stationary relic and boundary.

## Artistic recipe — proposed, not approved

Faceted obsidian core, broken violet alloy gyroscope rings, luminous inlays/ticks, three pointed orbiting shards, and a broken ground seal. Approximately 1.5m across and 1.7m high above the marker origin. No particles, lights, transparent volumes, camera movement or audio are added to gameplay.

Two tilted rings rotate in opposite directions at one turn per 12 seconds. Core rotation runs at half speed, shard crown at quarter speed. The editable Blender scene contains a 12-second motion segment; runtime uses continuous procedural transforms of the authored pieces. Source animation is excluded from GLB export to avoid competing animation controllers. Ring orientation is preserved from the import, and animation time belongs to each instance independently.

Four shared opaque materials, five mesh objects, 2,131 source polygons, approximately 190KB GLB. Imported immutable geometry/materials are shared; only instance transforms change. All variants are created on initial Fulcrum presentation, before placement, and shadow casting is disabled. First visible draw is not assumed to be warmed by hidden allocation.

## Sources and reproducibility

- Generator: `tools/build_gravity_anchor.py`; run `blender --background --python tools/build_gravity_anchor.py`.
- Editable source: `art_source/spells/fulcrum/gravity_anchor/gravity_anchor.blend`.
- Runtime asset: `assets/effects/gravity_anchor.glb` and its Godot import settings.
- Presentation: `scripts/gravity_anchor_effect.gd`; integrated by `scripts/class_mechanics.gd`.
- Review: `tools/gravity_anchor_review.gd`. `-- --studio --capture` captures a deterministic six-second, 10fps motion sequence; `-- --still` captures six characters and both teams' anchors in the arena. No camera controls/settings are written by the review script.
- Review evidence: `artifacts/spell-forge/fulcrum/gravity-anchor/r001/`: `studio.png`, `gameplay.png`, `gravity-anchor-r001.mp4`, `motion/`, `source_hashes.json`.
- Studio uses a separate light/background to inspect the actual runtime geometry and transforms; it is not evidence of normal gameplay lighting or timing. The filmic/glow studio environment is not installed into gameplay.

## Validation

- Gravity Anchor presentation: 20/20; class identity: 102/102; Fulcrum Meditation: 173/173. These include concurrent independence, static reduced-effects mode, range/model separation, interrupted Collapse warning, same-location replacement, caster movement/death, expiry, and round teardown.
- Native review ran on an AMD Radeon RX 7800 XT using Compatibility; early virtual-display attempts used llvmpipe and stalled. Still views inspected; sampled deterministic animation capture includes placement, idle and termination. The capture compresses the timer's 20-second life to show termination after 5.5 seconds, without modifying live duration.
- Benchmark overrides had outdated method signatures. `tools/frame_time_arena.gd` now forwards the existing optional camera yaw argument. `--anchor-probe` in `tools/frame_time_benchmark.gd` keeps six fighters while forcing anchor placement at tick 1 and Heavy Orbit at tick 180 in both five-second rounds.
- Baseline and candidate raw frame intervals, events, settings/hardware, pipeline counts, round identifiers and focus flags are retained under `baseline/` and `candidate/`. Existing driver/project caches retained. CPU wall intervals are not presentation latency; asynchronous GPU timing is separate.
- **Performance comparison is inconclusive:** baseline had 578 focused/60-cap frames and 40 unfocused/15-cap frames; candidate had only 7 focused/60-cap frames and 188 unfocused/15-cap frames. Background-cap intervals must not be used for foreground performance claims. All-frame distributions and threshold counts are preserved in `performance_summary.json`, not treated as an anchor regression or pass. A controlled foreground Forward+ run is still needed, including first placement and repeated rounds. No production performance sign-off.

## Installation and rollback

Existing-file backups are in `artifacts/spell-forge/fulcrum/gravity-anchor/r001/backup/`: original `scripts/class_mechanics.gd`, `frame_time_arena.gd`, and `frame_time_benchmark.gd`. Restore only the GravityMarker presentation block and its preload to reverse the gameplay integration, preserving any later unrelated edits. The two benchmark changes are diagnostic only and can be reversed independently. New files are the generator, editable Blender source, GLB/import settings, presentation script/UID, review tool, test, and this record. No commit, push, deployment, shared visual-standard approval, or character-archive change was performed.
