# Art Direction — established source of truth

_Established theme and current prototype art. Character designs remain an initial art pass, subject to playtest and visual review._

## Theme — Cosmic Gladiators (established 2026-09-07)

**Fighters from different worlds and universes are summoned to compete in an ancient cosmic arena.** This is the established fiction and visual theme for Starfall. It is set by the project owner — do not silently reverse or dilute it.

Space + fantasy. The arena is an ancient structure floating in space, not a building on a planet.

**Setting elements:**

- Celestial temples and massive ancient architecture.
- Floating islands / platforms.
- Black holes and nebulae in the background; a giant planet behind the arena is a canonical example.
- Ancient gods watching from enormous structures — the fighters are summoned combatants, watched.

**Champion range:** alien assassins, celestial knights, weird cosmic beasts. Champions are drawn from *different* worlds, so they do not need a shared silhouette language or a shared material palette — cross-universe variety is the point. Names stay original; no WoW/LoL assets or references.

**Visual identity:**

- Deep purples and blues as the base.
- Extremely bright magical accent colors on top of that base.
- Lots of stars, glowing weapons, cosmic effects.

**Current authorization:** The owner requested ability art and player models on 2026-09-07, superseding the earlier blanket art deferral for these areas. The owner subsequently requested the Cosmic Sanctum environment and its material/atmosphere upgrade. Audio remains separate work. The owner authorized the Blender skeletal pipeline for Ember and then Luminary on 2026-09-08; see below.

## Current implementation — first roster art pass

- **20 original painted icons cover all 21 ability slots.** Mend is shared between Ember and Vanguard. Assets and full generation prompts live in `assets/icons/abilities/`. The built-in image generation tool produced the illustrations, using Firebolt as the style anchor. Source PNGs are preserved; Godot imports at a maximum of 256 pixels with mipmaps.
- **Ember:** replaced by the Blender-authored hooded celestial mage described below. The old staff and faceted robe construction have been removed.
- **Vanguard:** Blender-authored closed visor helmet, layered dark forged armor, violet crystal clusters and a large two-handed hammer in a head-up guard. The owner rejected the exposed-face attempt; the helmet is the latest explicit direction. Current implementation and unresolved visual quality: `VANGUARD_REBUILD_BRIEF.md`.
- **Luminary:** Blender-authored hooded healer in ivory/gold armor and navy/ivory vestments, with a featureless dark opening, lunar cape, halo and carried celestial staff. No human face or hair geometry remains; see below.
- **Ember, Vanguard and Luminary use imported skinned Blender models**, dispatched by `scripts/champion_model.gd` to their dedicated presentation modules (`ember_art.gd`, `vanguard_authored.gd`, `luminary_art.gd`). The generic fallback retains procedural geometry. Vanguard includes a weapon bone and confirmed-hit hammer animation; gameplay and collision remain on the parent actor.
- Every champion retains the same radius 0.42 / height 1.8 collision capsule. Weapons, robes and ornaments are visual only. They never become clickable target surfaces.
- Hotbar artwork sits below the existing radial cooldown overlay. Keybinds, borders, focus/hover states and countdowns are rendered by Godot, not baked into textures. Tooltips retain ability names and mechanics.
- Billboard names/health/cast bars sit above the new silhouettes. The arena still uses its existing floor/pillars, beam cues and floating combat text. Audio remains absent.

These character designs are the **implemented prototype**, not a final lock on champion lore or production rendering style.

### Review and extension

Run `godot --path . --script tools/art_review.gd` in a rendering window to regenerate front/back lineup boards and the full icon atlas under `artifacts/`. Run `godot --path . --script tests/ability_art_test.gd` for art coverage, champion switching, overlay order and visual/collision separation checks.

For UI tests under Xvfb, supply a screen larger than the game window: `xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tests/ui_test.gd`. A 640×480 virtual screen clamps the cursor before it can reach the hotbar, even though the viewport screenshot is 1280×800.

Keep icons readable by silhouette at 64–92 pixels: one primary motif, dark indigo backgrounds, limited cosmic texture, strong light/dark contrast. Ember attacks use orange/magenta; Vanguard uses steel/gold; Luminary uses mint/ivory/gold. Functional abilities may cross those palettes (e.g. green Mend and blue Ward). Add future icon paths to `scripts/ability_art.gd`; art is presentation data and must not enter network snapshots or balance dictionaries.

## Ember — Blender model and locomotion (2026-09-08)

Complete production and next-class handoff: [`CHARACTER_PIPELINE.md`](CHARACTER_PIPELINE.md).

The owner explicitly rejected Ember's faceted construction and rigid limb swings. The new original model follows the supplied reference's open hood, dark tailored armor, antique bronze borders, articulated gloves, split astral robes, burning hems and celestial halo. The linked WoW Classic/Retail comparison was viewed as a model and movement quality reference; no game assets were copied.

- Editable source: `art_source/ember.blend`, saved with the Walk NLA track active, 30 fps, frames 1–37. Other named NLA tracks are muted for inspection. The `REVIEW_ONLY` collection contains a studio and is excluded from the game export by selection.
- Runtime asset: `assets/characters/ember.glb`, one smooth skinned mesh, nine material surfaces and a 52-bone skeleton. Packed 1024px astral fabric texture; Godot also extracts its embedded texture during import. Approximately 127k source triangles; Godot generates import LODs.
- Clips: Idle, Walk, Run, WalkBackward, StrafeLeft, StrafeRight and Cast. Leg poses use an analytic two-bone solve, grounded stance targets, toe clearance and eased swing return. Robe bones provide delayed secondary motion. All clips close their first/last poses.
- `scripts/ember_art.gd` chooses direction from actual displacement, blends clips over 0.2 seconds, smooths cadence, and retains casting, stun, damage flash, defeat and revive presentation. A 180-degree import correction aligns Blender -Y with the game's -Z facing. Team color is confined to shoulder inlays. Combat transforms, capsules, targeting and network state are unchanged.
- Review: open `scenes/ember_preview.tscn` and run the scene. Buttons select clips, drag rotates the camera, scroll zooms, Space pauses, and the slider changes playback speed. Rebuild with Blender `--background --python tools/build_ember.py`; verify source skin/stance with `tools/verify_ember.py`, then import in Godot and run `tests/ember_presentation_test.gd`.

Validation: Blender verified all 69,923 vertices have normalized skin weights and sampled stance ankles remain within 0.000001 m of their authored target height. Godot passed 761/761 Ember presentation checks, 81/81 combat checks and 91/91 rendered ability/art checks. Blender motion samples and a real Godot render were visually inspected. These checks validate deformation and integration, not a claim of reference-quality artistry.

This is a complete original rigged model and authored movement implementation, but remains a stylized interpretation below the supplied image's production surface detail. Armor is smoother and simpler, cloth uses bone animation rather than cloth collision simulation, and there is no terrain foot IK. Extreme backward/sideways travel can slide because cadence is capped; future stride warping should preserve gameplay speed. The reference's spell-effect illustrations are not new ability implementations. Further visual approval and multi-character GPU profiling remain open.

## Luminary — hooded Blender model and shared locomotion (2026-09-08)

The owner requested Ember's workflow and mostly unchanged animation with Luminary's ivory/gold reference, then explicitly replaced the exposed face and hair with a hood similar to Ember's. The current model has an ivory silk hood with gold binding and lunar embroidery, a dark lining, featureless recessed veil, layered cowl and halo. The actual face, eyes, eyebrows, nose, mouth, ears, exposed neck, scalp, hair meshes and hair controls have been removed. There are no concealed human facial features beneath the hood.

The remaining model retains layered ivory armor, gloves, lunar tabard, navy/ivory cape, relics and carried celestial staff. Source: `art_source/luminary.blend`; runtime: `assets/characters/luminary.glb`; viewer: `scenes/luminary_preview.tscn`. The saved source plays Walk at 30 fps, frames 1–37. Current source counts: 79,301 vertices, 150,476 triangles, 13 material surfaces and 59 bones. The lined hood has actual shell thickness and moves with the head; the cowl conceals the neck opening.

Idle, Walk, Run, WalkBackward, StrafeLeft, StrafeRight and Cast keep the original durations and core gait. The staff-side arm and cape still have their class-specific motion. `tools/build_luminary.py` requires `tools/luminary_details.py`; `tools/verify_luminary.py` verifies weights, ankle targets, absence of hair controls/facial materials and gait parity against the Ember source.

Post-hood verification: all 79,301 vertices have normalized weights; sampled stance ankle-height error below 0.000001m; 392 sampled core matrices identical to Ember. Godot passed Luminary 865/865, combat 81/81 and rendered art 91/91. Corrected front/back studio, walk/run samples and a final Godot viewer capture were inspected. The first shell attempt exposed its dark lining outward; reversing surface winding before solidification corrected that in the current asset.

The hood supersedes earlier exposed-face/hair notes. Fine ornament and fabric detail remain simpler than the reference; cape motion is bone-driven without collision simulation, there is no terrain foot IK, and fast backward/sideways movement retains the inherited cadence limitation. No new spell effects were implemented. See `CHARACTER_PIPELINE.md` for the durable workflow and historical versions.

## Cosmic Sanctum — environment implementation (2026-09-08)

Latest lighting/landscape pass: a shared runtime/bake profile reduces broad ambient and fill light, preserves cool key illumination, and adds four short-range warm shrine lights. Native indirect light is rebaked for all115 architectural instances. Six large layered cliffs, hanging foundations, broken approaches and distant temple ruins now frame the arena; repeated small islands/spikes were reduced. Six new landscape batches (19,116triangles) reuse existing textures and add no collision or shadow passes. Faint moving mist consists of three transparent sheets below the island, not volumetric fog. Current environment asset budget:8,373,829bytes, just under8MiB. See `ART_SLICE_HANDOFF.md` for exact settings, verification and rebuild steps.


The arena is an original floating ruin with authored playable architecture and a procedural cosmic backdrop. The material/atmosphere pass lives in `arena_world.gd`, `arena_atmosphere.gd`, `arena_sky.gd` and their shaders. The owner subsequently approved Blender-authored architecture and baked lighting. The approved architecture now replaces all four covers, the full36x36m floor, all four boundary walls and both terraces/ramps. Reused modular meshes have real bevels, arched relief, fitted and split flagstones, bronze ornament, UV-based normal maps and native LightmapGI lighting. The portals, cliffs and atmospheric background retain their procedural construction. Editable sources are ignored under `assets-source/`; only compressed meshes ship. See `ART_SLICE_HANDOFF.md` for the complete rebuild workflow.

### Surfaces and relief

`arena_stone.gdshader` uses the existing 512 × 512 `assets/environment/sanctum_slate.png` with five surface constructions selected by `surface_kind`:

| Kind | Surface | Treatment |
| --- | --- | --- |
| 0 | Structural basalt / cover | Large slate fractures, mineral discoloration, coarse relief, rough fracture faces |
| 1 | Main floor | Worn limestone slabs, dusty edges, per-slab aging, smoother centers, shallow relief |
| 2 | Terrace and stair treads | Blue cut-stone mosaic, offset tesserae, narrow mortar, contrasting roughness |
| 3 | Trim and celestial inlay | Hammered bronze, pitted oxidized patina, metallic response |
| 4 | Foundation and dark recesses | Volcanic glass with rough cracks and sparse emissive fissure fragments |

This is shader-built material variety, not five differently tinted copies of the texture. Height is converted into a view-space surface gradient with screen derivatives of position and height. It works across triplanar projections without tangent-space normal maps, vertex displacement, or physics changes. `relief` controls strength; steep gradients are capped and subpixel detail fades with distance. `weathering` adjusts roughness. A rendered relief-on/off comparison verifies that the height field changes actual lighting.

`arena_energy.gdshader` now writes **EMISSION**, with a slow pulse and traveling current. Its default `emission_gain` is 3.4. It uses a lit spatial shader: custom `unshaded` spatial shaders did not render emission correctly in the actual 4.5.1 OpenGL probe. Small original glyphs mark both faces of all four cover blocks; broken floor arcs and terrace inscriptions stay thin and subdued. Metallic engraving remains distinct from emissive strokes. The existing 1.35 bloom threshold is retained.

### Atmosphere and visibility

`arena_atmosphere.gd` builds eight render instances: five static material batches, one cloth banner batch, a 96-instance ember MultiMesh, and an 18-instance floating-rock MultiMesh. Eight embroidered banners move at their free ends; bronze chain links hang beyond the island. Two distant seated watcher shrines occupy roughly (±47, -6, -59). Moving art uses shader time instead of per-frame GDScript. Decoration has no bodies, areas or navigation and casts no additional shadows.

The expensive sky panorama is still baked once into memory. A single distant additive shell carries faint moving currents, keeping `TIME` out of the sky shader and avoiding a per-frame radiance bake. This shell is scattered sky color below bloom, not an emissive combat effect. Conventional **depth fog** and three layers of distant crags provide atmospheric perspective. The warm key remains dominant; reduced ambient/fill light preserves relief and silhouettes. No SSAO, SSIL, SDFGI, volumetric fog or screen-space reflections are used.

### Gameplay invariants and validation

The world still has **19 collision bodies**. The entire decorative subtree has **zero collision bodies**. The 36 × 36 footprint, four 4.4 × 3.8 × 2.8 cover bodies, cover bases, terrace/ramp dimensions, boundary collision and navigation remain unchanged. The visible cover cores now match the full collision width; the earlier narrow visuals left the outer collision ends invisible.

Validation: map **57/57**, combat **81/81**, plus actual Compatibility rendering and a collider inventory. `tools/arena_review.gd` captures `artifacts/sanctum-overview.png`, `sanctum-detail.png`, and `sanctum-gameplay.png` in a fixed window. Review the player camera as well as overview art. The available renderer is Mesa llvmpipe software; rendering successfully here does **not** certify 60 FPS on a physical GPU. Environment art is batched; the full-game draw count also includes the existing champion models and HUD.

### Texture requirements and budget

**No textures need to be generated by the user.** The authored section supplies nine original 512 x 512 PNGs: albedo, normal and roughness for basalt, floor and bronze. All tile over four metres, have exact matching opposite-edge pixels, and keep lighting out of albedo. Roughness maps store a single lossless scalar channel; see the material manifest for current byte counts. The existing 512 x 512 slate remains for procedural geometry. Native baked lighting uses a separate HDR EXR atlas; it is an atlas, not a tiling surface texture. The complete runtime environment folder, including compressed meshes and lighting, is just under8MiB. Editable Blender/GLB sources are ignored outside that folder. The cached sky panorama is runtime memory, not a shipped image asset.

If a future replacement is requested, require PNG at no more than 1024 × 1024, seamless on all four edges, even neutral lighting without baked highlights, shadows or AO, orthographic coverage of approximately four metres. Check border continuity programmatically and record the intended physical tiling scale before accepting it.

## Established visual language

### Team colors — absolute (model, overhead nameplate)

- Blue = team 0
- Red = team 1

Do not flip based on viewer. Model color is **identity**.

### Team colors — relative (main health frames)

- Blue = ally of the local player
- Red = enemy of the local player

Flip based on viewer. Frame color is **presentation**.

**Do not conflate the two.**

### Character magical accents

- Luminary: mint light with ivory/gold ornaments.
- Ember: warm amber flame with gold trim.
- Vanguard: restrained violet crystal and visor accents, dark forged plate, muted team cloth.
- Facing reads from faces, weapons and posture; the old capsule marker is removed.

### Feedback cue palette

- Damage: red
- Heal: soft green (`#97edb1`)
- Interrupt, stun, immune, defeated: gold
- Ward / shield: blue
- Blink, Charge: gold or blue depending on kind

### Background

Dark near-black clear color (`#0a0f17`) for high contrast against character silhouettes. Compatible with the Cosmic Gladiators theme as-is — a deep-space skybox with stars/nebula is the intended direction when the background stops being a flat clear color.

## What is NOT decided

_Open. Do not silently promote:_

- Rendering style within the theme (stylized / painterly / semi-realistic / abstract).
- Final champion lore and production silhouettes beyond this first model pass.
- How the arena is realized — geometry of the floating platform, which celestial structures appear, what the god-observers look like.
- Production animation approach; current model poses are procedural.
- Audio direction (music, SFX, VO).
- UI visual style beyond current functional dark panels — whether the HUD adopts the purple/blue cosmic palette.
- Whether the existing functional colors (team blue/red, feedback cue palette) survive contact with the cosmic palette, or get re-tuned for contrast against deep purple.

_The **theme** above is settled. Everything in this list is execution within that theme._

## Exploration

_Ideas raised but not established. Label your additions with `Proposed:` and a date so the next agent knows the state._

_(none currently)_

## Rejected directions

_(none currently)_

## Asset budget

Ability icons ship at **256 x 256**. They display at 92 px in the hotbar, so 256 leaves headroom for hi-dpi and larger UI scales without paying for pixels nobody sees.

The generated originals were 1254 x 1254 — around 2.2 MB each, 44 MB for twenty icons. That is roughly 186x the pixels the hotbar draws, and git keeps every blob forever, so it was downscaled before the first push. Regenerate from `assets/icons/abilities/PROMPTS.md` if a higher-resolution master is ever needed, but do not commit one.

**Mipmaps must be on for anything sampled in 3D.** `sanctum_slate.png` shipped with `mipmaps/generate=false` while the stone shader asked for `filter_linear_mipmap_anisotropic`, so the floor aliased and shimmered in motion with no filtering to fall back on. Static screenshots barely show it; movement does.

**Judge texture resolution by texel density, not by the number.** The slate tiles every 4.17 world units, so at 512 it supplies ~123 texels per world unit against roughly 51 screen pixels per world unit at normal framing — oversampled about 2.4x. Resolution was not what made the floor look cheap; the missing mipmaps were. Zooming the camera fully in narrows that margin, so 512 is adequate rather than generous.

**Check the size of any generated art before committing it.** A texture that looks fine in isolation can carry a cost that is permanent once pushed.

## Class ability icons — 2026-09-08

Every ability in all four twelve-slot kits now has a 256px painted icon. Eight new images were generated with the built-in image tool: Gravity Anchor, Inward, Outward, Heavy Orbit, Counterweight, Collapse, Guiding Star, Supernova. Existing spell art is reused for the other new names. Mapping: `scripts/ability_art.gd`; prompts: `assets/icons/abilities/CLASS_PROMPTS.md`. Fulcrum still uses its existing generic character presentation.

Authoritative state drives ground-ring telegraphs, anchor timers, burning-field outlines, and resource/brand/star counts. These are first-pass combat-readable effects, not a new character animation production pass.

## Interface palette

Every colour the UI uses lives in one block at the top of `scripts/arena.gd` (`UI_VOID` through `UI_ROSE`), so the menu, HUD and hotbar cannot drift apart. Shape language comes from a single helper, `ui_box()` — same corner radius, same border weight, same padding everywhere.

Grounds are void-blue and slate. **Accents are rationed**: gold marks the one action a screen is actually offering, violet is arcane highlight, cyan is friendly, rose is hostile. If everything glows, nothing reads — a screen should have exactly one gold thing on it.

Text carries its own shadow because it sits over moving art, not a fixed background. Body copy is `UI_TEXT_DIM`; full-strength white is reserved for hover.

New controls should be styled through `style_button()`, `style_picker()` and `ui_box()` rather than hand-rolled `StyleBoxFlat`s, or the next redesign has to find them all again.

## Lighting and glow

The environment (`scripts/arena_sky.gd`) runs filmic tonemapping, violet distance fog, a warm key, a violet fill, and a cool back light. Bloom is on with a **high HDR threshold (1.35)** so only genuinely emissive surfaces glow and lit stone stays stone.

**Emissive means emission, not unshaded.** `material(color, glow)` and `champion_model.paint(hex, luminous)` previously only set `SHADING_MODE_UNSHADED`, which caps at the albedo value and can never cross the bloom threshold — so nothing in the game actually glowed. Both now set `emission` with an energy multiplier above 1. Anything that should read as *light* rather than as bright paint has to do the same.

Two things that look right in isolation and are wrong here:

- **`glow_bloom` above ~0.05** lifts every pixel toward the bloom pass, not just bright ones, and turns dark slate into pale lavender.
- **A `DirectionalLight3D` used as a "rim" light** lights every surface facing it, not silhouette edges. Keep the back light under ~0.25 energy or it becomes a second key and flattens the arena.

## Renderer

The project runs `gl_compatibility`, Godot's OpenGL backend. **Forward+ is the single biggest available visual upgrade** — it unlocks SSAO, SSIL, volumetric fog, SDFGI and real reflections, none of which exist on this path.

It was tested and deliberately not adopted:

- Godot does **not** fall back when Vulkan is unavailable; it hard-fails to launch. A player with a broken driver gets nothing.
- Vulkan cannot present under Xvfb (no DRI3), so CI and any headless capture must pass `--rendering-driver opengl3` — meaning automated tests would exercise a different renderer than players use.
- It therefore cannot be visually verified in this environment at all.

Flipping `renderer/rendering_method` to `forward_plus` is a one-line change. It needs a human on a machine with a GPU to judge the result and accept the support burden.

## Unique active ability artwork — 2026-09-08

The owner requested replacement of repeated icons between different abilities. Seventeen new built-in image_gen illustrations now cover Stoke, Solar Flare, Cinderstep, Burning Wake, Intercede, Hold the Line, Challenge, Earthsplitter, Unbroken, Pilgrim’s Step, Last Light, Starfall, Graviton, Horizon, Anchor, Umbra and Tether. All 45 distinct active ability names have unique file paths and image contents. Mend remains one shared ability across classes. Retired ability aliases may still point at their old art; they are outside the active kits.

Final PNGs are 256×256 with mipmap import settings. Prompts and file names: `assets/icons/abilities/UNIQUE_PROMPTS.md`. `tools/audit_ability_icons.py` verifies active coverage and duplicate image contents; the rendered art test now also rejects shared paths for different active names. Artwork and hotbar-sized contact sheets were inspected. A fresh Godot import/render remains pending due to the session’s automatic approval review credit block.
