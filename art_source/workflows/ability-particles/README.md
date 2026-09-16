# Ability particle workflow — Ember r001

A reusable, Git-visible **local test** of downloaded flame textures, character motion and authoritative combat. It runs from a normal checkout without the multi-gigabyte reference library. The library remains optional authoring input. Owner visual acceptance and balance tuning are separate from automated validation; nothing here publishes a build.

## Start here

From the repository root:

```sh
python tools/motion_resources.py doctor
python art_source/workflows/ability-particles/assets.py
godot --headless --path . --log-file /tmp/ember-check.log --script tests/ember_particle_abilities_test.gd
godot --path . --log-file /tmp/ember-review.log --script tools/ember_particle_review.gd
```

Play normally with Ember to test controls. Fire Barrier occupies the old Ward slot (5); Ash uses the next free Ember slot (normally Shift+6). Existing customized bindings are preserved. Press Ash again to recall early.

For a 30 fps recording of only the preview window on Linux/X11, run `python tools/record_ember_review.py`. This requires FFmpeg and `xwininfo`; the result is `artifacts/ember-particles/ember-review.mp4`.

The native review cycles through eight effects, including a cornered Ash route. Add `--fixed-fps 30` before `--script` and `-- --capture` after the script path for a reproducible image sequence sampled at 7.5 fps. Output is local under `artifacts/ember-particles/`. Fixed-rate/capture runs are **not performance measurements**.

```sh
ffmpeg -framerate 7.5 -i artifacts/ember-particles/frame-%05d.png -c:v libx264 -pix_fmt yuv420p -movflags +faststart artifacts/ember-particles/ember-review.mp4
```

## What to reuse

| Layer | Location | Contract |
| --- | --- | --- |
| Inputs and rights | `sources.json`, runtime `assets/effects/ember/ATTRIBUTION.md` | Eight pinned CC0 texture files, original bytes, author/source/license/checksum records. Six Kenney flame/fire/smoke/scorch/spark shapes plus two Golgotha fireball views. Side fireball and spark are available alternatives, not active effects. |
| Flame batch | `scripts/ability_flame.gd`, `shaders/ability_flame.gdshader` | Retained MultiMesh quads; texture silhouettes, coherent orange/red/yellow palette, local variation and soft opacity ramps. Solar Flare uses white-hot highlights. |
| Ember composition | `scripts/ember_effects.gd` | Local render clocks, reusable effect pool, ring/trail/barrier, ground heating, projectile trail, statue/ghost/ash return. Render nodes never decide hits. |
| Gameplay | `scripts/ember_mechanics.gd`, `scripts/arena.gd` | Authority owns movement, collision, damage, control, durations and the sampled Ash route. |
| Skate body motion | `scripts/ember_skate_pose.gd` | Editable procedural hop/push/glide layer on the existing rig, also used by the compact server rig. This is not a claimed retargeted mocap clip. |
| Evidence and repeatability | `tests/ember_particle_abilities_test.gd`, `tests/run_ember_particle_network.py`, `tools/ember_particle_review.gd` | Mechanics, real delayed multiplayer, native visual review. See `VALIDATION.md`. |

## Author the next character

1. Write down the mechanical shape, timings, target visibility and animation phases first. Specify which unspecified numbers are provisional. Preserve authority and existing ability slots where possible.
2. Search the local shelf for body mechanics (preparation, contact, recovery), then look for suitable effect textures from a clearly licensed provider. Keep original bytes and notices. Record actual source URLs and SHA-256 before use; a failed download is not an installed asset.
3. Stage complete packs in ignored `downloads/` or `local_resources/`. Promote only the selected, redistributable subset. `assets.py --fetch-missing` can restore this pinned subset; it verifies hashes and refuses to overwrite changed files.
4. Compose layers: preparation/heat, primary flame silhouette, supporting sparks/smoke, recovery. Use texture masks for fire rather than opaque circles. Match hue in the shader; preserve bright detail instead of clipping a fireball into a white disk.
5. Follow Mend/regen's continuity principle: locally advance presentation between snapshots. Ember's common ramp is 0.16s in / 0.30s out, with a short event tail. Body skating blends in over 0.14s and releases over 0.24s. Visibility restrictions override fading immediately.
6. Keep gameplay and presentation separate. Send cast events and compact state, not particle positions, geometry or animation frames. Seed variation locally. Give each effect a bounded pool, a death/reset path and a reduced-effects option. Ground trail samples are gameplay history, not particles.
7. Preview from owner and enemy views in the real renderer. Check bright detail, readable safe areas, walls, occlusion, fades, interrupted casts, early recall, death and next round. A headless pass cannot approve appearance or frame rate.
8. Run focused mechanics, delayed ENet, pose parity and dedicated-server checks. Compare uncaptured native runs on the same hardware/settings. Record measured limits honestly, retain candidates and user feedback, then update the class docs.

## Ember choices for this experiment

- **Burning Wake:** outer radius stays 5m (10m diameter), inner safe radius 3m, duration 5s. The annulus deals 60 damage/sec, up from 40, and retains 45% slow. Root distance determines the annulus; height tolerance is 2m. The 3m hole is a provisional design choice.
- **Ash:** up to 6s invulnerable, enemy-invisible spirit; +50% normal movement speed. Start statue crumbles locally. Recast recalls early. At recall, movement freezes for 0.65s and visible ash follows the recorded route before the body reforms. Invulnerability ends at recall, including early recall. No other abilities during either phase. Provisional 90s cooldown, off GCD. Existing stun/root/slow effects clear on entry; entry still obeys the normal cast-eligibility gate, so this is not a universal stun-break Trinket.
- **Fire Barrier:** renamed/re-skinned Ward in the same slot: 60% damage reduction for 5s, 22s cooldown. It is damage reduction, not a new absorb-health pool.
- **Cinderstep:** 3s steerable skate, +80% speed, costs 20 Heat, 18s cooldown. Each traversed segment lasts 5s, retains 3m width, 40 damage/sec and 45% slow. Root/stun ends skating; already-laid flames remain. The 3s skate duration is provisional. No instant teleport or forced straight-line dash.
- **Kindle:** the downloaded fireball travels cosmetically for about 0.30s with a fading flame tail. Damage retains the original cast-completion timing; it is not a new collision projectile.
- **Flashpoint:** brief target ignition. **Supernova:** progressively heated ground during the 2.2s cast, then a fire eruption. **Solar Flare:** brief white-hot flame cone; retains its existing incapacitate and targeting rules.

## Networking and concealment

The renderer advances every local frame. Authority replicates ability timers/serials, compact trail samples and phase changes; one-shot events start local visuals. Cinder trail coordinates and remaining lifetime are quantized to 1cm/10ms **for presentation only**; authoritative hit geometry is full precision. Matching client/server code is required for the added compact Ember state.

During Ash spirit form, enemy snapshots substitute the entry location/yaw and zero velocity, and do not contain the live return route. Enemy targeting, nameplates, team markers and the spirit model/aura are suppressed. Teammates and the owner can see the ghost. The route is released on recall, when reformation is visible and vulnerable. A listen-server host necessarily owns authoritative state; concealment is a normal client guarantee.

## Git and packaging

This directory, helper tools, runtime scripts, selected textures, icons and class documentation are intentionally trackable. `.gdignore` keeps authoring documents out of Godot's import scan; it does not affect Git. Imported libraries, source archives, caches, diagnostics, preview frames and generated videos remain ignored. Docker/export filters also exclude the flattened imports. No commit, push or deployment is part of this workflow.

Read `LINUX.md`, `CONVERSATION.md`, `sources.json` and `VALIDATION.md` alongside this file.
