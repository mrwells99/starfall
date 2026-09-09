# Vanguard — current implementation and handoff

**Historical checkpoint, superseded by the owner's new reference rebuild:** see [`VANGUARD_REFERENCE_REBUILD.md`](VANGUARD_REFERENCE_REBUILD.md) for the current 45-bone model, crystal-frame hammer, cape, Windows commands, verification and rollback files. All counts, appearance notes, tool paths and usage readings below describe the preceding revision.

Updated 2026-09-08. This is the authoritative Vanguard continuation note. Read `CHARACTER_PIPELINE.md` for Ember's workflow, but use the local tools below.

## Owner direction and current result

The owner rejected the first exposed-face model and the sideways, head-down hammer carry as below Ember's quality. The latest explicit direction is a **closed helmet**, proper two-handed hammer guard, and more cohesive armor. This overrides the original reference's exposed head. The reference is preserved at `art_source/references/vanguard.png`.

The live Vanguard now loads `assets/characters/vanguard.glb` through `scripts/vanguard_authored.gd`. It has a closed angular helmet with a narrow glowing visor, layered forged plate, smaller violet shoulder clusters, a dark team tabard, and the approved hammer held head-up beside the torso. Both hands are below the head. The standalone approved hammer source remains unchanged; the character contains a scaled and posed copy.

This is a stylized procedural Blender interpretation, not a production-quality recreation of the reference. The owner has **not approved its appearance**. Do not call passing tests proof of visual quality or claim it matches Ember. Review the actual arena screenshot and movement before further changes.

## Files and reproduction

- `tools/build_vanguard.py`: self-contained Blender builder; rebuilds only Vanguard. It appends the approved hammer source read-only, applies its evaluated transforms/modifiers, builds the body and rig, exports the GLB, saves the source, and renders front/back.
- `art_source/vanguard.blend`: editable complete character with Idle enabled in NLA; studio objects are in `REVIEW_ONLY` and excluded from export.
- `assets/characters/vanguard.glb`: live skinned model, 39 bones, approximately 95,370 triangles before Godot import. Shader surfaces are shared within each actor; per-actor materials are independent. Import generates LODs. No new character textures were needed.
- `scripts/vanguard_authored.gd`: per-instance materials, manual AnimationPlayer advancement, movement/cast/strike selection, shield rings, hit recoil, damage flash, defeat/revive.
- `scripts/champion_model.gd`: dispatch and confirmed-hit presentation hook. Existing `scripts/vanguard_strike.gd` remains the visual confirmed-hit effect.
- `shaders/vanguard_forged.gdshader`, `shaders/vanguard_crystal.gdshader`: forged relief and fissure emission; added optional damage/defeat uniforms default to zero so standalone weapon reviews retain their settings.
- `tools/verify_vanguard.py`: Blender skin weights, arm reach, cycle closure and sampled boot-sole checks.
- `tests/vanguard_presentation_test.gd`: current authored model tests, replacing the obsolete procedural sword/shield assertions. A copy of the old suite is in the fallback archive.
- `scenes/vanguard_preview.tscn`, `tools/vanguard_preview.gd`: interactive orbit/zoom/clip viewer. Space pauses, buttons select clips; optional `-- --vanguard-capture` writes `artifacts/vanguard_new/godot-idle.png`.
- `tools/vanguard_review.gd`: studio team/movement/defense/attack captures plus actual arena gameplay and portrait. Outputs to `artifacts/vanguard_new/`.

Local tools are Blender 5.2.0 at `/usr/bin/blender` and Godot 4.5.1 at `/usr/local/bin/godot`. The current renderer is OpenGL Compatibility. Ember's Windows tool paths in the shared pipeline document describe its originating machine.

Run sequentially from the repository (wait for each build/import to complete):

```sh
blender -b --python tools/build_vanguard.py
blender -b --python tools/verify_vanguard.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/vanguard_presentation_test.gd
godot --headless --path . --script tests/map_test.gd
godot --headless --path . --script tests/combat_test.gd
godot --path . --script tests/ability_art_test.gd
godot --path . --script tools/vanguard_review.gd
godot --path . res://scenes/vanguard_preview.tscn
```

On this host, headless tools need a writable log/config location (`XDG_CONFIG_HOME=/tmp/starfall-config`, `--log-file /tmp/...`). Rendered checks use Xvfb with a 1400x1000 or larger display. The sandbox cannot create display sockets; local rendered runs required approved elevated execution. Blender reports a pre-existing optional extension `cattrs` failure and thumbnail-cache write warning, but core build/export/render and the explicit verifier complete successfully.

## Animation and gameplay contracts

Clips: Idle (2s), Walk (1.2s), Run (0.8s), WalkBackward (1.333s), StrafeLeft/Right (1.2s), Cast (1.6s), Strike (0.8s). All cycles close; Strike plays as a one-shot. Bones include pelvis/spine/chest/neck/head, paired leg/foot/toe and arm/hand/finger chains, six cloth bones, and a weapon bone.

An analytic leg solve supplies stance and swing. Both wrist targets derive from a single weapon transform. The weapon path is projected into both arms' reach spheres before solving the elbows, preventing a disconnected wrist at the peak of the swing. No runtime weapon collider or authoritative combat animation event was added.

Confirmed damage starts the presentation response immediately at 0.16s into Strike. Combat timing, cooldowns, hit validation, networking, team IDs, targeting and the 0.42m radius / 1.8m actor capsule are unchanged. Shield effects follow `actor.shield`; recoil follows HP loss rather than healing flashes. Ember's assets and scripts are unchanged.

Remaining limitations: no terrain IK, authored death/jump clips, mocap, cloth collision or six-character hardware GPU benchmark. Extreme side/back speeds can outpace the bounded clip cadence. The reach solve checks wrist contact, not exhaustive armor self-intersection. The head/armor proportions and hammer silhouette still require owner visual judgment. Do not continue polishing indefinitely without comparing against Ember in the same lighting.

## Cleanup and recovery

Old studies are out of the active source/asset folders. Local recoverable archives:

- `artifacts/archive/vanguard_rejected_2026-09-08.zip`: 60 rejected study/source/render/handoff files. Every archived file was SHA-256 checked against its original before removing the active copy; the ZIP includes `ARCHIVE_MANIFEST.json`.
- `artifacts/archive/vanguard_procedural_fallback_2026-09-08.zip`: previous playable sword/shield presentation, cloth shader, review tool and old test suite. Superseded script/shader originals were byte-verified before removal. The review tool remains active, adapted to the new model.

Archives are intentionally local and ignored by Git, preventing a 51MB historical render bundle from entering repository history or game exports. Extract into a temporary directory and selectively restore original relative paths; do not unpack everything into the live project. Share the archives separately only if another machine needs rejected work.

Approved standalone weapon files remain active: `art_source/vanguard_hammer_weapon.blend`, `assets/characters/vanguard_hammer_weapon.glb`, `tools/build_vanguard_hammer_weapon.py`, `tools/vanguard_hammer_weapon_review.gd`. Do not rebuild those merely to rebuild the character. Existing unrelated changes to `project.godot` and Ember import metadata were preserved. No commit, push or deployment was performed.

## Validation checkpoint

Helmet/guard revision: Vanguard presentation **679/679**, map **57/57**, combat **81/81**. Blender: normalized weights (max error 0.00000018), closed cycles, maximum sampled wrist gap below 0.000001m, sampled moving boot soles at or above 0.01799m. These measurements do not establish world-space foot slip or visual approval. Final import has no script/shader errors. Final Vanguard presentation: **679/679**; unchanged Ember presentation: **761/761**; rendered ability/art regression: **91/91**. `git diff --check` is clean. Actual final arena portrait, gameplay view and motion/defense/strike frames were rendered and inspected in Compatibility on llvmpipe software rendering, so these runs do not establish hardware GPU frame rate.

Owner rule: stop at **90% five-hour usage**, write actual completed/unfinished work, and hand off. Do not redeem account resets without authorization.

Final usage checkpoint: **89% five-hour usage**. Development stopped here under the owner’s 90% rule. No further model edits planned this window. Remaining work is owner visual review and any subsequent geometry/material refinement, plus hardware performance and movement-quality assessment described above. The final viewer capture may finish after this checkpoint; the arena portrait and regression checks are already complete.
