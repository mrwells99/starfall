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

**Current authorization:** The owner requested ability art and player models on 2026-09-07, superseding the earlier blanket art deferral for these areas. Arena/environment art, audio and a full skeletal animation pipeline remain separate work.

## Current implementation — first roster art pass

- **20 original painted icons cover all 21 ability slots.** Mend is shared between Ember and Vanguard. Assets and full generation prompts live in `assets/icons/abilities/`. The built-in image generation tool produced the illustrations, using Firebolt as the style anchor. Source PNGs are preserved; Godot imports at a maximum of 256 pixels with mipmaps.
- **Ember:** angular hood and split robes, team-colored mantle, gold ember staff and floating flame crystal.
- **Vanguard:** broad faceted plate, helmet crest, team-colored cape/tabard and kite shield, luminous astral sword.
- **Luminary:** ivory floating vestments, team-colored sashes, halo, six celestial feather ornaments, mint focus crystal and scepter.
- **Models are original in-engine meshes**, constructed by `scripts/champion_model.gd`. Procedural joint poses cover idle/walking, casting, stun and defeat; hit flashes affect the complete model. No external models, rig or AnimationTree dependency.
- Every champion retains the same radius 0.42 / height 1.8 collision capsule. Weapons, robes and ornaments are visual only. They never become clickable target surfaces.
- Hotbar artwork sits below the existing radial cooldown overlay. Keybinds, borders, focus/hover states and countdowns are rendered by Godot, not baked into textures. Tooltips retain ability names and mechanics.
- Billboard names/health/cast bars sit above the new silhouettes. The arena still uses its existing floor/pillars, beam cues and floating combat text. Audio remains absent.

These character designs are the **implemented prototype**, not a final lock on champion lore or production rendering style.

### Review and extension

Run `godot --path . --script tools/art_review.gd` in a rendering window to regenerate front/back lineup boards and the full icon atlas under `artifacts/`. Run `godot --path . --script tests/ability_art_test.gd` for art coverage, champion switching, overlay order and visual/collision separation checks.

For UI tests under Xvfb, supply a screen larger than the game window: `xvfb-run -a -s '-screen 0 1600x1000x24' godot --path . --script tests/ui_test.gd`. A 640×480 virtual screen clamps the cursor before it can reach the hotbar, even though the viewport screenshot is 1280×800.

Keep icons readable by silhouette at 64–92 pixels: one primary motif, dark indigo backgrounds, limited cosmic texture, strong light/dark contrast. Ember attacks use orange/magenta; Vanguard uses steel/gold; Luminary uses mint/ivory/gold. Functional abilities may cross those palettes (e.g. green Mend and blue Ward). Add future icon paths to `scripts/ability_art.gd`; art is presentation data and must not enter network snapshots or balance dictionaries.

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
- Vanguard: pale gold weapon/visor accents.
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

## Fulcrum — awaiting art

The control champion ships without icons or a dedicated model; it borrows a generic silhouette and its hotbar shows ability names as text. Direction when someone gets to it:

Slate and void-purple, cracked like something compressed and never fully recovered. Its abilities read as **rings, orbits and lines of force**, not projectiles — Tether should be a visible strand of bent light strung between two fighters, not a bolt that travels. Six icons needed: Collapse, Tidal Force, Horizon, Anchor, Umbra, Tether. Slot 6 is Mend, which already shares Ember and Vanguard's icon.

Keep to the 256 x 256 budget above.

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
