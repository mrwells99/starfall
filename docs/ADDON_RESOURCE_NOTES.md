# Optional addon resources — reviewed 12 September 2026

The owner approved **all reviewed packages as ongoing local reference resources** on 12 September 2026. Consult them when their problem area comes up; this is not blanket approval to enable an addon or integrate its code. Their downloaded originals remain in place on this computer and are excluded from normal Git staging, Docker build contexts and both desktop export presets. No map, lighting, bot behavior, or aimed-ability changes were made during the reviews.

For new animation requests, follow the mandatory default [animation selection/cache workflow](ANIMATION_WORKFLOW.md): inspect the relevant libraries, preview all plausible candidates on an identity-free mannequin, obtain owner approval before live installation, and preserve rebuilt clip assets for reuse.

## Local resource registry and packaging policy

| Resource | Keep together at these local paths |
| --- | --- |
| Netfox | `addons/netfox/`, `addons/netfox.internals/` |
| RPG Animations GLB FREE | `Unarmed.glb`, `Unarmed_RM.glb`, their import metadata, `Unarmed/`, the RPG character sources/version notes and `explosive_anim_importer` helpers/links |
| Color Grading | `addons/Color grading/`, `Compositor/Color grading/`, `Compositor/General/` |
| Ezcha Network | `addons/ezcha_network/` |
| LimboAI | `addons/limboai/`, `demo/` |
| BallisticSolutions | `addons/ballistic_solutions/`, `addons/real_equation_solver/`, `addons/BallisticSolutions.Godot/` |
| Reusable animation adaptations | `local_resources/animation_cache/` — retain across tasks, not disposable artifacts |

Precise exclusions live in `.gitignore`, `.dockerignore` and `export_presets.cfg`. All newly reviewed source packages were untracked when this policy was applied; no history rewrite or index removal was needed. Other addons (notably `audio_service`) and the previously tracked Quaternius resources were deliberately left alone. Ignoring a file does not remove an older copy from Git history or stop an intentional force-add.

These local libraries are not backed up by Git; preserve a separate computer backup. Keeping them in the project does not prevent local editor discovery/import (especially LimboAI's native extension), so use isolated compatible projects for addon experiments. Newly approved runtime assets must be self-contained and must not reference ignored library/cache paths. Packaging exclusions need an explicit scoped review if a future approved integration genuinely requires an addon dependency.

Run `tools/local_resource_audit.gd` with the desktop Godot to check the exact Git/Docker rules, actual Git ignored/untracked state, retained source paths and both presets' wildcard coverage. It validates policy/configuration without building a Docker image or exporting a game; recheck real release contents when the export/dependency structure changes.

## Color Grading 1.0 — useful future art-direction tool

Downloaded editor UI: `addons/Color grading/`. Actual rendering effects: `Compositor/Color grading/ColorGrading.gd` and `LocalContrast.gd`, using `Compositor/General/BaseCompositorEffect.gd`.

**Worth keeping as a resource.** It can adjust shadows, midtones and highlights independently: tint, brightness, vibrance, the boundaries between tonal ranges, a brightness curve, and optional night-color perception/noise. LocalContrast is a separate detail/broad-contrast effect. The editor addon supplies visual controls; it is not a new lighting engine.

For a future Sanctum lighting request, useful experiments would be:

- Slightly lift dark-character midtones without washing out the sky or emissive runes.
- Keep cooler shadows and warmer light accents, reinforcing the existing violet/blue environment and gold votive lights.
- Calm oversaturated bright effects separately from dark stone and armor.
- Test very subtle local contrast for stone/armor detail, only if a side-by-side comparison justifies its GPU cost.

These are proposed uses, not settings applied or results already approved. Color grading cannot replace correct light direction, shadow quality, material roughness, baked illumination or actual rim lighting.

**Current resources to consult first:** `scripts/sanctum_lighting.gd:3–8` holds shared lighting/bake values (ambient energy .24, exposure 1.04, directional energies 1.12/.12/.17). `scripts/arena_sky.gd:28–63` already sets Filmic tonemapping, depth fog, glow, saturation 1.08 and contrast 1.02. Avoid stacking another strong contrast/saturation pass over these without a neutral comparison. Global grading also affects 3D characters, effects and nameplates, not just the map; preserve team colors, ability readability and Null's visibility cues.

**Compatibility and cost:** the effects require RenderingDevice compute/compositor support, not the Compatibility renderer. Godot supports compositor effects in Forward+ and Mobile; this project explicitly selects Compatibility for its mobile renderer path. Keep a fallback if these effects are ever adopted. The grading effect runs one full-resolution compute dispatch per view; LocalContrast builds a blur/downsample chain plus a full-resolution combine (eight dispatches at default large_radius6), with extra temporary textures. Those are graphics/client costs, not dedicated-server lag improvements. No GPU benchmark or visual A/B test was run. [Godot compositor documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html).

**Future approval checklist:** compare neutral/current/two restrained variations on the same camera; include dark Null, bright spell impacts, both teams, shadowed cover and the sky; check the actual callback stage relative to tonemapping/glow; leave night noise off initially; measure GPU frame time at target resolution; verify Compatibility fallback and export-time shader UID resolution. Keep the addon disabled/unattached until a result is approved.

Code-review caveats before integration: the inherited default stage is after transparent 3D rendering and before built-in post-processing. LocalContrast can darken already-dark detail or emissive edges because its detail calculation clamps original HDR luminance but not the blurred reference (`Local contrast.glsl:80–92`). Validate tonal-range ordering and clamp negative values before fractional powers (`Color grading.glsl:151–157,248`). Live property changes also deserve a rendering-thread safety review because setters and callbacks share mutable buffers. These are code-inferred risks, not reproduced defects; none were changed. Setting local-contrast strengths to zero still runs its passes—disable the effect itself when unwanted.

## Networking resources

See `docs/NETWORK_ADDON_REVIEW.md` for the Netfox and Ezcha code reviews, current-network comparisons, tradeoffs and local snapshot baseline. These notes do not authorize replacing the existing server-authoritative networking.

Netfox is unattached, so its scripts reference autoload singletons (`NetworkTime`, `NetworkRollback`, `NetworkPerformance`, `NetworkTimeSynchronizer`) that `project.godot` does not register. Godot's resource scan parsed them anyway and emitted roughly two hundred "Identifier ... not declared in the current scope" errors on every import/editor start. `addons/netfox/.gdignore` and `addons/netfox.internals/.gdignore` now keep the scan out of both folders (the same pattern already used for `artifacts/`, `art_source/` and `local_resources/`). The source stays on disk for reference; delete the two `.gdignore` files if Netfox is ever genuinely integrated, which still requires its own approval.

Deployment guard: do not enable Netfox editor plugins or register their autoloads in `project.godot` while their sources remain excluded. UID-only autoloads can work in a local editor cache yet fail in every clean build. `tests/check_references.py` checks project startup paths and rejects UID-only autoloads; use committed `res://` paths for any approved future autoload.

## Animation resources

The RPG Animations GLB FREE pack's 64 unarmed clips are available in `Unarmed.glb`; `Unarmed_RM.glb` supplies root-motion variants. Six sandbox-only transfers onto existing models are in `artifacts/rpg-animation-preview-20260912/combat-candidates.gif`. Source/target bind differences require retargeting; do not directly replace live clips or rebuild models. See that folder's README and unchanged-asset verification before considering a chosen clip.

## LimboAI 1.8.1 — good interface for future bot work

**Yes, a useful fit for making bot decisions easier to design, tune and debug; not a drop-in intelligence or server-performance upgrade.** The downloaded package contains native extension binaries, icons and documentation; the actual C++ implementation is not included as editable source. The accompanying `demo/ai/` contains readable GDScript tasks and behavior trees.

The strongest benefit is the visual behavior-tree editor and running-tree debugger: we could see whether a bot is trying to heal, interrupt, approach or attack, and which condition rejected a choice. Shared subtrees could hold survival/targeting rules, with separate class priorities. Blackboard variables provide a place for the chosen target, perception results and intent; authoritative cooldowns and health should still come from the existing actor, not a competing copy. Custom GDScript tasks can call existing game functions. The state-machine component is also useful, but its setup requires code; it does **not** supply a visual state-machine editor. See the installed README and [custom-task documentation](https://limboai.readthedocs.io/en/stable/behavior-trees/custom-tasks.html).

### Fit with current bots

`scripts/arena.gd:3251` currently mixes target selection, facing, line of sight, navigation and ability priorities. Class-specific decisions also live in `scripts/outlaw_mechanics.gd:264` and `scripts/class_mechanics.gd:361`. This is already working game-specific logic, not something to discard for the demo AI. The demo's flanking/pursuit tasks operate on 2D agents in pixel distances; they are design examples, not compatible 3D movement implementations.

An eventual integration should keep `try_spell` as the authority for range, stealth targetability, resources, cast restrictions and cooldowns; preserve the current navigation/collision and movement simulation. Tasks should request actions and movement intent, not set positions, apply damage, or animate server-only rigs themselves. Run decisions only on the server/offline authority, with no duplicate client bot brains or replication of whole trees/blackboards.

Useful future improvements include deliberate retreat-to-Mend, healing/cleanse priorities for Luminary, and intentional class combinations instead of simply trying the next usable slot. These would be **new balance/behavior changes**, requiring approval and tests. A reactive priority selector can let emergencies interrupt a running approach, but tree-task cancellation must not accidentally cancel or repeat an actual game cast. LimboAI explicitly distinguishes reactive selectors from selectors that retain a running branch. [Reactive-selector documentation](https://limboai.readthedocs.io/en/stable/classes/class_btdynamicselector.html).

### Performance and side effects

Ability selection is already throttled: online bots decide every .25 seconds, offline difficulty uses .85/.4/.2 seconds. Navigation routes are recomputed at most every .45 seconds. However, `bot_targets` and line-of-sight checks happen before the decision-timer early return, so active bots still perform that perception work each physics step. Caching/staggering expensive perception could reduce work; that would be our scheduling change, not a free benefit from installing LimboAI.

Use manual tree updates at the chosen decision rate, pass actual elapsed time, and retain smooth movement execution on physics ticks. The default BTPlayer mode is physics updates, so blindly moving all logic into it could increase work. Reduced perception frequency can delay target switches or obstacle reactions; urgent stun/death/stealth invalidation must remain immediate. Tree traversal, blackboard access and debugging add overhead; measure them rather than assuming native code makes custom GDScript decisions faster. [BTPlayer update modes and performance monitor](https://limboai.readthedocs.io/en/stable/classes/class_btplayer.html).

### Compatibility gate before any integration

Installed `version.txt` says **1.8.1**, whose README compatibility table requires **Godot 4.6+** for the AssetLib/GDExtension build. The desktop uses 4.7.2, but the current dedicated-server validation runtime is **4.5.1**. The extension manifest still declares a generic minimum of 4.2; that is not evidence these particular binaries support 4.5. Do not ship a bot dependency on this package to the existing server without resolving this mismatch. Use a mutually supported extension/engine combination and test actual headless exports; no engine upgrade or addon version change was performed in this review.

Suggested first experiment, only if approved: port one class's existing priorities without changing its decisions, behind a switch back to the current bot. Compare ability choices, positions, stealth handling, interrupted casts, death/respawn and CPU time at several bot counts, using `tests/lookup_bot_optimization_test.gd` as a reference. Then add smarter behaviors individually. No LimboAI bot integration or behavioral benchmark was performed here.

## BallisticSolutions 6.1.0 — useful for real projectiles, not current hitscan

Both editions are downloaded: `addons/ballistic_solutions/` is GDScript with the included `addons/real_equation_solver/` dependency; `addons/BallisticSolutions.Godot/` contains the C# DLLs and documentation. There are no references to its solver classes in the current gameplay scripts. The GDScript edition fits the existing codebase without introducing C#/a .NET engine/export requirement. These are static math helpers, not a networking or automatic collision-tracking system. [Author's overview](https://github.com/neclor/ballistic-solutions).

### Where it would and would not help

| Use | Assessment |
| --- | --- |
| Current Defense Detonation / generic aimed hitscan | No direct benefit. These resolve an instant ray against historical body hitboxes. Keep their timing, cover checks, camera validation and authority. |
| Future arrows, fireballs or lobbed grenades | Useful for initial firing velocity, travel time and moving-target interception under constant acceleration. Multiple solutions allow low/high arcs, subject to collision checks. |
| Future projectile path/landing preview | Useful displacement math, but a crosshair-chosen trajectory usually needs only simple integration, not solving a target-interception equation. Preview must use the same launch conditions as the server. |
| Future projectile-using bots | Useful leading calculation, with deliberate reaction time/error and visibility rules. Perfect lead would change difficulty; human auto-aim is a separate gameplay choice, not an optimization. |
| Server lag, rubberbanding or first-shot history readiness | Not addressed. Trajectory prediction is different from reconstructing what the shooter actually saw. |

`scripts/outlaw_aim_test.gd:183–245` starts the **.6-second pre-fire charge** when the trigger is pulled, then samples the camera ray after charging and again for each burst shot. That charge is not projectile travel time. Adding .6 seconds of target lead would change the intended aim and can make a correctly placed crosshair miss. `scripts/outlaw_detonation.gd` validates and traces those shots through `scripts/aimed_combat.gd:125`; retain the existing delayed-tracking/high-ping safeguards. The generic hitscan foundation has no shipped kit opting into its `aim_mode` flag yet; Defense Detonation uses its own live route.

The current Coin Toss already has a simple analytic arc and segment collision checks (`scripts/outlaw_mechanics.gd:230–237`). Replacing that short formula with a quartic interception solver is unnecessary. A useful related finding: the server's coin trajectory includes `coin_momentum`, captured from the thrower's velocity, but the remote displayed trajectory in `scripts/outlaw_effects.gd:116` omits it. That can disagree for a moving thrower. A future shared trajectory helper could fix this independently of BallisticSolutions. This is a code-identified presentation mismatch, not a reproduced multiplayer playtest; it was **not changed** during the review.

### Integration cautions

- The solver assumes constant acceleration. Sudden strafing, jump landing, collision, speed buffs and teleports invalidate that extrapolation. Bound the prediction horizon and do not use hidden enemies as aim-assist targets.
- The math targets a point and knows nothing about walls, pillars, other players, hitbox volume or projectile radius. Test the entire flight with swept collision/segments and accept the first collision; an endpoint alone is not proof of a clear path.
- Validate positive finite speed, nonzero finite direction, finite positive flight time and returned velocity. Handle null/NaN/empty results gracefully, constrain lifetime/range, and verify trajectory residuals. A negative speed currently logs an error but still reaches the squared-speed equation.
- Use the same acceleration, inherited shooter momentum and integration method in server simulation and visual preview. If damping must be disabled for a particular projectile, scope that setting to the projectile; do not change global physics just because the README suggests it.
- Solve once at launch or at a bounded preview/bot-decision rate. The speed solver allocates/filter/sorts polynomial roots (quadratic in the zero-relative-acceleration case, quartic otherwise). This adds work; it does not replace animated hitbox tracking. Changing instant rays into persistent projectiles introduces ongoing simulation/collision and networking costs.
- Full `BsSolution3D` results inherit `Object`, not `RefCounted`. Callers must free those result objects after use, or use the scalar/vector helper APIs when a full solution object is unnecessary. Repeatedly creating and dropping them without freeing would accumulate allocations on a long-running server.

### Isolated numerical checks and confirmed limitations

The unchanged GDScript addon was copied into a tiny diagnostic project under `artifacts/ballistic-review-20260912/`, without the game's scenes or other addons. The same smoke script completed on **Godot 4.5.1 and 4.7.2**, with 46 numerical checks passing per engine and four separately documented edge observations. Stationary/lateral targets, low/high gravity arcs, a constant-acceleration target and an unreachable receding target behaved as expected. Returned valid-flight positions differed from the target's analytical impact position by less than .000004 meters in these cases. This is not a gameplay hit-rate, physics-integration, networking, exhaustive numerical or performance test; the C# edition was not executed.

Confirmed caveats in both engines:

- `all_by_direction(RIGHT, (-10,10,0), (0,-5,0))` returns a firing velocity of **(-5,0,0)** at two seconds: it reaches the target but fires **opposite** the requested direction. The underlying equation checks collinearity, not the forward sign. A caller must reject backward solutions.
- A stationary target straight ahead, or one moving directly along that same line, produces an empty direction-based result despite many valid forward solutions. The degenerate equation needs an explicit policy such as a chosen projectile speed or flight time.
- When the target is exactly at the firing origin, the time API returns zero; the solution-list API returns a zero-time/zero-speed entry despite a requested speed of 25; the best-solution API returns null. Treat immediate overlap separately and reject nonpositive flight times before launching.

Those direction/overlap cases are why a passing smoke count must **not** be read as approval to wire every solver directly into aiming. Evidence: `project/smoke.gd`, both `smoke-*.log` files and engine-named result JSON files in the diagnostic folder. No addon bugs were patched.

Recommendation: retain this as a future projectile-design resource, not a replacement for current aimed-shot validation. No aimed ability, projectile, reticle, global physics setting, addon source or networking behavior was changed in this review.
