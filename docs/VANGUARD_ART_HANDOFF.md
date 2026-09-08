# Vanguard visual upgrade — handoff, 2026-09-08

**Superseded visual direction:** owner found this pass marginal and requested an exposed-head crystal-armored, two-handed hammer model. See [`VANGUARD_HAMMER_STUDY.md`](VANGUARD_HAMMER_STUDY.md) for the subsequent static study and 91% stop. The code described below remains the playable version; the hammer study is not integrated.

## Current status

**The first Vanguard implementation pass is complete and reviewed.** This supersedes the earlier inspection-only stop at 93%. The owner subsequently authorized resuming; the current account reported 0% at the start and 53% at the final usage check. Development is ending at a reviewable milestone, not waiting to exhaust the allowance. Continue checking live usage in future work and honor the owner's 90% ceiling. Do not automatically redeem resets.

This is an improved procedural champion, not a finished sculpted/skinned character or a new roster-wide animation system. No combat rules, collision shapes, cooldowns, cast times, damage timing, network RPC signatures, arena layout, or environment assets were changed by this pass.

## Implemented

- `scripts/vanguard_art.gd`: isolated Vanguard construction and presentation. Layered cuirass, bevelled and crowned armor panels, overlapping shoulders, enclosed helmet, cheek guards, wrapped sword grip, tapered blade, inset kite shield, greaves and boots. Rigid geometry is batched per joint/material. Final count: **40 mesh instances, 3,596 triangles per Vanguard**, including normally hidden shield activation geometry.
- Distinct steel, brighter edges, bronze, dark leather, team-colored enamel and cloth. Two cached 128 x 128 procedural surface maps supply cloth weave and metal roughness variation; no new imported textures or environment budget usage. These are shared generated GPU textures, not PNG assets requested from the owner.
- `shaders/vanguard_cloth.gdshader`: pinned-shoulder cloth with subtle lower-cape motion, a dark hem and distance-filtered weave. The cape remains broad team-color identification from behind. Material color responds to existing flash/death state.
- Articulated knees, near-ground walking feet, restrained upper-body sway and breathing, movement-responsive cape, and recoil triggered by actual HP loss. Healing flashes do not cause damage recoil. Existing stun, casting, defeat and recovery behavior remains.
- **Iron Skin presentation:** shield sigil while the real shield timer is active; a short expanding floor seal on activation/refresh; slightly raised guard. Expiration, removal or death clears the visual. Any actual shield on Vanguard can activate this indicator, including an ally-applied shield. No full-body dome or light that obscures opponents.
- **Melee presentation:** `scripts/vanguard_strike.gd` creates a 0.2-second sword arc and small impact sparks on confirmed Vanguard damage. `scripts/arena.gd::show_event()` uses the existing reliable event for this, so clients receive the same cue. The model performs an immediate follow-through and returns to guard over 0.34 seconds. Applies to Vanguard damage events including Cleave, Crush and Charge damage; it does not distinguish those abilities visually yet. Other existing event beams remain.
- `scripts/champion_model.gd` delegates Vanguard construction/animation to the helper and exposes `present_strike()`. The obsolete Vanguard construction branch was removed. Other champions retain their existing construction path.

Instant attacks still land instantly. No fake windup was added before an already-resolved hit. A future anticipation pass needs either a ready stance driven by targeting/input or separately authorized gameplay timing changes; do not silently add a cast delay.

## Validation and review

Passed during this implementation:

- `tests/map_test.gd`: **57/57**.
- `tests/combat_test.gd`: **81/81**, without script errors after implementation fixes.
- `tests/ability_art_test.gd`: **91/91**, rendered using Compatibility.
- New `tests/vanguard_presentation_test.gd`: **274/274** after final geometry/pose changes. Covers both teams, unchanged body/capsule, no art collision, geometry limits, shield activation/persistence/removal/death, strike return to guard, actual-damage recoil versus healing, casting/respawn, a sampled full walking cycle, outward armor normals and strike cleanup. Many checks are per-frame body-transform invariants; the count is not 274 distinct behaviors.
- Sampled minimum walking foot height: approximately **-0.000074 m**, numerical-scale penetration, against a -0.035 m guard. This does not establish perfect foot planting on arbitrary slopes or stairs.
- Final review tool renders with no script/shader errors. `git diff --check` passed.

Rendering used **Mesa llvmpipe software rendering** with Godot 4.5.1 Compatibility. A real GPU 60 fps benchmark has **not** been performed. Glow materials use lit emission above the existing 1.35 threshold; no reliance on unshaded albedo as an emission source. Do not infer hardware performance from these screenshots or headless timings.

Review artifacts in `artifacts/vanguard/`:

- `sanctum-portrait.png`: close view in actual arena lighting, Iron Skin active.
- `gameplay.png`: actual gameplay camera for scale and team readability.
- `front.png`, `back.png`: both team colors under the Sanctum directional/ambient profile on a neutral stage (not the full arena sky/reflection setup).
- `iron-skin-and-strike.png`, `strike-effect.png`: pose/effect states. The latter pauses the stage tween for capture; this pause is only in the review tool.
- `motion-00.png` through `motion-07.png`: deterministic movement samples.
- `before.png`, `before-back.png`: copies of the pre-existing roster review boards saved before editing, not newly rendered baseline captures.

`artifacts/champion-lineup.png` and `champion-lineup-back.png` are refreshed by the existing roster review tool.

Reproduce checks (always give Godot an explicit writable log path in this environment):

```sh
godot --headless --path . --script tests/vanguard_presentation_test.gd --log-file /tmp/vanguard-presentation.log
godot --headless --path . --script tests/combat_test.gd --log-file /tmp/vanguard-combat.log
godot --headless --path . --script tests/map_test.gd --log-file /tmp/vanguard-map.log
xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tests/ability_art_test.gd --log-file /tmp/vanguard-art.log
xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tools/vanguard_review.gd --log-file /tmp/vanguard-review.log
xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tools/art_review.gd --log-file /tmp/roster-review.log
```

The virtual display requires the approved display execution path here; sandboxed X11 failed. No user-facing gameplay settings were changed for the captures.

## Next work, in order

1. Playtest this pass on hardware at real game distance, on both teams, during a busy 3v3 fight. Measure GPU time and draw calls with and without champion/effect rendering. Check forward/backward/sideways movement and ramps. This pass has simple procedural gait, not directional locomotion blending or foot IK.
2. Decide on the next quality jump: authored curved/sculpted armor and a proper rig with elbow/wrist articulation, directional locomotion and weapon-specific clips. The current body is still stylized procedural geometry. Avoid promising it is equivalent to authored production character art.
3. Distinguish Cleave, Crush, Bash/Pummel and Charge presentation using explicit ability identification. Current reliable damage events carry text/source/victim/color but no ability ID. Any added protocol field needs version/compatibility review. No new network field was introduced here.
4. Add further weapon-contact timing and recovery variety while preserving authoritative instant-hit timing. Character recoil currently follows HP snapshots rather than a dedicated hit-direction event.
5. Apply the approved quality target to Ember and Luminary (and inspect Fulcrum's current art needs) only after the Vanguard result is assessed. Those roster upgrades are not implemented by this pass.

## Existing arena work and shared-workspace cautions

`ART_SLICE_HANDOFF.md` remains the complete arena handoff. It covers authored shared cover/floor/wall/terrace geometry, the lighting bake, external cliffs/foundations, broken approaches, distant sanctuaries and subtle non-volumetric mist. The prior environment budget was 8,373,829 bytes, almost the 8 MiB ceiling; this champion pass adds no files to that budget. Real GPU performance remains unverified there too.

Preserve the 36 x 36 footprint, four LOS-blocking covers at (±6, 0, ±5), cover dimensions 4.4 x 3.8 x 2.8, terrace/ramp layout and boundary walls. No new playable-area colliders. Godot remains `gl_compatibility`; no Forward+-only rendering features.

The workspace already contained unrelated uncommitted arena, HUD and combatant edits. This pass changed only the Vanguard helper/model hook, the small `show_event()` presentation branch, its cloth shader, tests/review tooling, review artifacts and handoff/context documentation. Do not reset or claim ownership of other diffs in `scripts/arena.gd`, `scripts/combatant.gd`, `tests/ui_test.gd`, environment scenes/assets, or HUD artifacts. No commit, push or deployment was performed.
