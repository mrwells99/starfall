# Required v2 finishing step: fitted body hitboxes

Approved 2026-09-10 after the owner reviewed the five-class hitbox implementation and asked to bake its creation into Model Forge v2. This procedure applies to new classes and revisions of existing models that change the source GLB or pose behavior. It supplements the frozen v2 art/animation process. The character is unfinished until this step and its review are complete.

## Fit the body without changing the model

Use the same **19 mathematical capsules** defined by `scripts/body_hitboxes.gd`: pelvis, abdomen, chest, neck, head and paired shoulders, upper arms, forearms, hands, thighs, shins and feet. Their endpoints follow actual `DEF-` skeleton landmarks after the complete presenter has run. The contract records the accepted ordered radii; the frozen implementation records the exact endpoint offsets. Padding is approximately 2–4 cm around the underlying main body. Use the standard fit for ordinary costumes; the heavy fit is the reviewed Vanguard plate example, not a reason to expand every class.

Fit dimensions to the reference-specific body armor while keeping the 53 core rest bones and body proportions unchanged. Start with the approved profile; record any class-specific radii, the reason, and images demonstrating the fit. Current runtime selection uses a Vanguard name check: explicitly add a new class's profile there if needed instead of assuming that naming its record "heavy" changes runtime behavior.

Exclude hat brims, halos, hair, flowing cloth, crystal tips, orbiting props and held weapons. Cover the main armored body and articulated limbs; do not create one large robe-shaped box. Head contact is identifiable but has **normal damage**, with no headshot multiplier. Overlapping volumes resolve to one nearest hit and one damage application. Keep the existing radius 0.42 m / height 1.8 m terrain/movement capsule unchanged. The damage capsules are not extra physics bodies and must not push players or snag terrain.

## Generate the server rig from the final export

Finish the class's GLB, materials, grip, named clips and runtime motion first. Extract the final GLB with `tools/build_hitbox_rigs.gd` in an isolated current checkout. Preserve skeleton, parents, animation libraries and all nonconstant motion; remove meshes, materials, textures, lights and effect children. Only exactly constant tracks may collapse to one key. Save compressed `assets/hitboxes/CLASS_rig.scn` and its source/output hashes in `assets/hitboxes/manifest.json`. Rebuild whenever the source GLB changes, even if the change looks cosmetic.

The shared server presenter must use `scripts/hitbox_pose.gd`, inject the compact rig, and set `pose_only = true`. Reuse the same accepted animation, smoothing, jump, equipment-grip and special-move layers as the visible presenter. Do not approximate these with a separate server walk cycle. Skip visual effect allocation, retaining any pose contribution such as Vanguard's recoil. Server actors must not load the visual GLB or textures, including through script preloads. Keep the client asset cache's initial warmup and reuse across rounds.

**Version compatibility:** Godot 4.7 stores AnimationPlayer libraries differently from 4.5. Keep root metadata `hitbox_libraries` and the `character_asset_cache.restore_libraries` fallback. An apparently successful scene load can still contain no usable animation libraries on 4.5. Verify actual animation playback and body endpoints on the server version pinned in `.github/workflows/deploy.yml` (4.5.1 at approval), using an isolated import cache if the desktop version differs.

### Register each new class explicitly

The captured tools know Ember, Luminary, Fulcrum, Vanguard and Outlaw. They do not discover a sixth class automatically. As part of ordinary class integration:

- Extend the builder's `NAMES`, `hitbox_pose.SCRIPTS`, and the client cache's visual warmup list.
- Expose the new presenter's skeleton through the same `champion_model.<class>_art` access used by `combatant.setup_hitboxes`; verify any slug/display-name mapping rather than relying on accidental lowercase matching.
- Add the class to `tests/hitbox_pose_test.gd`, `tools/hitbox_review.gd`, and dedicated resource guards in `tests/server_runtime_test.gd`. Add its special poses and combat-event pose triggers when applicable.
- Check current `arena.gd` spawn, sample, event and teardown hooks against the accepted integration context. Preserve newer networking/gameplay. Do not reinstall old arena scripts from either archive.

The builder currently regenerates every class in its list. Back up all potentially changed rig/manifest paths, or add a scoped output/filter in the staging checkout and validate it. Install the model, presenter, compact rig, manifest and registrations together; never ship a new GLB with a stale server rig.

## Validate motion, geometry and authority

Run through the project's `tests/check_suite.sh` wrapper, which rejects script errors even when Godot exits zero. Use actual positive result counts, not approval-era counts as quotas.

```powershell
godot --headless --path . --script tools/build_hitbox_rigs.gd
bash tests/check_suite.sh "Hitbox pose checks" godot --headless --path . --script tests/hitbox_pose_test.gd
bash tests/check_suite.sh "Server runtime checks" godot --headless --path . --script tests/server_runtime_test.gd
bash tests/check_suite.sh "Aimed combat checks" godot --headless --path . --script tests/aimed_combat_test.gd
```

Capture each suite's complete output in class-specific logs. Require no engine/script errors, finite endpoints, 19 radii/38 endpoints, source/output hash agreement, and no render meshes or character GLBs in dedicated mode. Compare visible and server capsule endpoints under identical inputs through idle, forward/side/diagonal travel, backpedaling, jump, landing, casts, recovery and interrupted transitions. Maximum endpoint error must be below **0.0005 m**; the accepted five-class sample measured 0.0 m. Include new class-specific rolls, backflips, lunges, recoil or other pose layers; additional special motions are recorded alongside the common poses. Keep the existing class's gameplay/presentation regressions.

Preserve shared ray/capsule geometry, cover blocking (including origins inside walls), friendly/protected-body blocking, single damage application, authoritative cooldown/GCD checks, request ownership/order/time limits and history invalidation at teleport/death/reset. If registrations affect networking or shared authority code changes, run `tests/run_aimed_network.py --test-latency` and the relevant class network fixture **sequentially** because their port is shared. These are local fixtures, not permission to connect to or deploy to production.

New classes inherit the server-side aiming foundation; **do not enable `aim_mode = "hitscan"` on a playable ability without a separate ability request**. Character creation does not rebalance damage, add headshots, or change existing spell targeting.

## Render the actual fit and record delivery

Use `tools/hitbox_review.gd` with Godot's Compatibility renderer, capped at 30 FPS, on the second monitor without stealing focus. At approval screen 0 was secondary; recheck the monitor layout if it changes. Capture front and side views of the final class with translucent cyan body capsules and a gold head capsule. Include a readable legend explaining normal head damage and exclusion of decorative geometry. Inspect the saved images. Add representative special-move images where applicable, such as Outlaw roll/backflip, and inspect live moving poses for clipping and delayed hitbox motion. These are actual model/geometry renders, not generated artwork.

Save a new record using `tools/model_forge_hitbox_snapshot.py --new-record`. Fill its hitbox section with ordered dimensions, profile/fit differences, source/rig/definition hashes, manifest path, test-log hashes, measured maximum pose error, reviewed pose list, pictures and review notes. The `reviewed` flag records the implementer's completed inspection; it does not invent owner approval. Attach screenshots to the final handoff. Keep model/presenter/rig rollback backups together and record added paths. Run the hitbox `--check-record` gate alongside the original Forge checks before claiming the class complete.

The archived pictures and rigs are fit examples for the five existing classes, not replacement artwork for a new one. Re-running the review tool overwrites its default pictures, so copy finished reviews to the class's own recorded directory.

## Recovery and measured limits

The extension manifest and `baseline.zip` preserve the exact hitbox geometry, builder, stripped reference rigs, shared pose integration, review/benchmark/test tools, accepted pictures and implementation notes. Full arena/combatant/presenter files are tagged **integration context only**. The original v2 archive remains the authority for anatomy and accepted base animation. Extract each archive to its own empty directory; neither extraction installs over the project. Verify before recovery. Keep each archive file below 32 MiB and do not commit transient render/test directories separately.

The accepted five compact rigs total 4,058,621 bytes. A short local Windows/Godot 4.7.2 Ryzen 7 7700X six-character comparison recorded 600 ticks per condition: mean simulation 0.691→1.223 ms, worst fitted 2.124 ms, working set 128.94→144.23 MiB. This is a reference measurement, not a fixed budget or a guarantee for the owner's 1 GB host. Re-measure with `tools/measure_hitboxes.py` when adding expensive pose logic, changing shared sampling, or materially growing rig data. Keep raw individual tick records. A normal costume-only change needs the existing resource/pose checks, not repeated speculative performance work.
