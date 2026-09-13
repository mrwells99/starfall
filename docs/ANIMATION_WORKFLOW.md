# Animation selection and reusable local library

Owner-established default, 12 September 2026. This supplements Model Forge v2; it does not modify its frozen anatomy, accepted motion or hitbox contracts. A later explicit owner request can override the preview-first default for that request.

## Two paths: create new motion, or reuse approved motion

**Owner's fast-edit preference:** blanket numeric/stat adjustments and simple animation playback-speed multipliers do not require test runs. Make the scoped value change, inspect the diff and finish promptly; the owner will playtest. Do not turn simple tuning into broad regression testing, benchmarks, research, elaborate evidence packages or long preview generation. Distinguish it from changes to underlying movement/network behavior, authoritative hit timing, pose construction or transition logic; use targeted validation only where that additional scope actually requires it. Existing tests may have their expected numeric values updated without running a full suite. If a supposedly simple request exposes a concrete complication, explain it briefly instead of silently expanding the job.

**Creative quality is a separate priority:** the owner explicitly says these efficiency requests do not apply to imagining new animations. Take the time needed for strong reference selection, human body mechanics, thoughtful adaptation and convincing previews. Optimize repeated setup and reuse, not the creative care that produced the approved Null hybrid. Classify each request as new creative work, approved-work reuse, or simple tuning before choosing how much work to do.

**Shared-body default (owner clarification):** for almost all characters, the intended difference in an approved shared movement is the carried weapon. Reuse the same compatible pelvis, legs, torso, head and free-arm motion; adapt only necessary carrying-arm placement, grip, equipment/contact constraints and garment channels. Do not invent a separate personality gait or redo creative selection for each character. Preserve class-specific ability behavior, and do not apply changes to unrequested characters. Outlaw's original-B comparison uses Null's body loops with its native right gun arm/grip; Null has the refined B.

**Movement standard (latest owner selection):** current Null refined B is the reference for future requested distribution; Outlaw was comparison only. r015 keeps .31s burst smoothing and independent bounded follow-through, with a slightly tighter, right-biased horizontal foot-plant envelope at rapid-transition extremes. Ordinary movement unchanged; owner feel review pending. Reuse accepted motion and adapt weapon handling only, without automatic rollout. Current record: `local_resources/animation_cache/entries/starfall/wasd-study/ual53/r015-foot-reach/`. The exact pre-follow-through .31s helper is saved under `local_resources/animation_cache/restore-points/null-before-follow-through-2026-09-12/`.

Owner feedback after testing Null's installed r002 hybrid: “this looks amazing” and “use the same workflow when imagining something new.” The owner also requests substantially lower usage and turnaround when distributing approved work. This is a workflow preference, not authorization to modify other characters now.

- **New creative animation:** retain the successful reference-led workflow: relevant saved libraries and real-motion references, biomechanics/contact/transition reasoning, meaningful neutral candidate comparisons, owner selection, saved editable and baked results, then scoped installation. Match the quality of the approved Null hybrid; do not repeat unrelated research or load the entire library.
- **Apply an approved animation to more characters:** use a fast reuse-and-validation path, not a fresh creative project. Start with the saved approved bake and existing installer/tests. Verify target rest signatures, equipment and pose layers; share compatible core animation data, remap bindings and adapt only genuine character-specific differences. Do not copy Null's blade grip, garment tracks or stealth behavior onto other characters. No repeat source search, rebaking, full comparison movie or approval ceremony unless compatibility or a meaningful visual change requires it.
- **Keep repeated work cheap:** batch compatible targets through reusable scripts, cache calibration and engine-compatibility fixes, and render short focused checks for changed grips/transitions instead of regenerating long previews. Run shared checks once per final shared revision and required per-character checks against each actual target. Reuse hash-bound evidence only when its inputs and dependencies remain unchanged; do not claim an old test validates a changed presenter.
- **Do not trade correctness for speed:** preserve applicable visible/server pose, actual supported-engine, equipment and rollback checks. Escalate to deeper diagnosis only on a concrete failure or incompatibility. Skip unrelated test repair and speculative optimization; record baseline failures separately. An unchanged GLB does not need rebuilding merely to install a separate portable animation library.

Reuse reference: approved Null hybrid `local_resources/animation_cache/entries/starfall/wasd-study/ual53/r002/`; installed portable clips `assets/animations/null_locomotion.res`; shared installer and focused test `scripts/null_locomotion.gd` and `tests/null_locomotion_test.gd`. Inspect current inputs before generalizing these Null-specific components. Its preview contact solver is not the installed production runtime. Existing local-source and owner-controlled Git policies remain in force.

## Before creating or replacing an animation

1. Search the available libraries and saved adaptations first: the new RPG Animations GLB FREE pack (`Unarmed.glb`, 64 clips, and `Unarmed_RM.glb`), the existing Quaternius/Model Forge library, and `local_resources/animation_cache/`. Consult the [resource notes](ADDON_RESOURCE_NOTES.md) for reviewed sources and cautions.
2. Identify **all plausible animation candidates** for the requested action, not just a few personal favorites. Include meaningful alternatives such as left/right, standing/kneeling, weapon styles, and root-motion/in-place variants when they affect the choice. If there are many, show labeled batches/contact sheets rather than silently omitting options. Explain genuine incompatibilities and distinguish supplied clips from custom adaptations.
3. Show actual animated previews on a **neutral rigged mannequin matching the game's underlying model anatomy**. No champion costume, armor, distinctive weapons, colors, magical effects, nameplates or character identity. Label the clip/action, not a champion. Use consistent camera, lighting, scale and playback information so the owner can compare motion. Do not merely recolor a fully dressed champion and call it neutral.
4. Retarget/rebuild **isolated preview copies** if necessary to make a candidate readable on the current skeleton. Preserve the source library and live models. Adaptation for a preview is allowed; installation is not. Save that work for reuse as described below.
5. Present the candidates and **wait for the owner's selection/approval before assigning an animation to a live character, replacing model animation data, or changing the in-game presenter**. A request for options or previews is not approval to install a preferred candidate. The September 12 champion-dressed six-clip preview is historical exploration, not approval and not the template for new previews.

After approval, adapt the selected animation to the actual equipment/character only as needed; preserve other accepted motions. Perform the existing reversible installation, runtime transition/attachment checks and shared visible/server hitbox validation. A neutral mannequin preview does not certify the final costume grip or server pose.

## Save rebuilt work instead of starting again

Persistent local location: `local_resources/animation_cache/`. This is **not disposable test output**. It is ignored by Git, Docker and game exports, and has a `.gdignore` to prevent automatic project imports. Do not delete it during artifact cleanup. Back it up separately from Git.

For each rebuilt/retargeted animation, retain:

- The actual reusable baked clip/animation library and editable source (for example Blender actions plus portable GLB/Godot animation data), not only a video, screenshot or recipe.
- Source pack/version, original clip name and file hash; target skeleton/rest signature and scale/orientation assumptions; tool versions and complete build/retarget recipe.
- Bone mapping, root-motion choice, timing/trimming/blending/grip edits, output names/hashes and preview files.
- A clear status: candidate, approved, superseded or rejected. Record actual owner approval separately from the agent's visual inspection; never infer it.

Look up that cache before rebuilding. Reuse a compatible saved result; if the target rig/rest pose changes, create a new version and retain the prior result. Do not reuse stale bone bindings, silently overwrite manual edits, or automatically apply one character's grip exceptions to another. Save rejected variants for reference but do not propose them as approved defaults.

The initial `recipes/rpg-unarmed-bindmap-v1/` entry preserves the existing 53-bone preview retargeter. It is a reusable **recipe**, not a baked clip library; the previous preview evaluated poses in memory. No fictitious baked assets or approvals are recorded. Future rebuilding must save the resulting clip assets as well as the recipe.

## Local sources versus shipped assets

Downloaded libraries, demos, source meshes, neutral preview rigs, render batches and the rebuild cache remain local. Only the approved, necessary runtime animation/model/compact-hitbox outputs belong in the game's normal runtime locations. Do not make the game depend on ignored source paths. If a whole addon integration later becomes necessary, explicitly review the needed dependencies and packaging exception; never force-add an entire source library just to make an export work.

The owner handles Git publication and deployment. No automatic commits, pushes or deployments.
