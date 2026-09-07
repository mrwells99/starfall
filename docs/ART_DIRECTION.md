# Art Direction — established source of truth

_Established visual direction. Ideas and exploration are labeled. Aesthetics have deliberately been deferred — see [`DECISIONS.md`](DECISIONS.md)._

## Theme — Cosmic Gladiators (established 2026-09-07)

**Fighters from different worlds and universes are summoned to compete in an ancient cosmic arena.** This is the established fiction and visual theme for Ringfall. It is set by the project owner — do not silently reverse or dilute it.

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

**What this does and does not settle:** it settles *what the game is about and what it looks like thematically*. It does **not** reverse the placeholder-first decision in [`DECISIONS.md`](DECISIONS.md) — no external assets, no animation system, no art pipeline until core feel is validated. New placeholder work should lean toward the theme (color, background, effect tint) rather than away from it, but building art is still not the current priority. See [`ROADMAP.md`](ROADMAP.md).

## Current state — placeholder-first

The game uses **code-generated placeholder geometry only**:

- Character capsules (radius 0.42, height 1.8) with a small forward marker box for facing.
- Billboard overhead labels for names and status.
- Simple health mesh above each character, always facing the camera.
- Cylinder mesh beams (~0.16 s lifetime) for cast/hit effects.
- Rising floating text labels (~1.1 s lifetime) for damage / heal / status events.
- Arena floor 36 × 36 with pillars at (±6, ±5) and boundary walls at ±18.
- No animations. No external models. No audio.

This is intentional. See [`DECISIONS.md`](DECISIONS.md) — core mechanics and multiplayer feel are validated first, aesthetics layer on afterward.

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

### Accent color on character forward marker

- Luminary: soft green (`#97edb1`)
- Ember / Vanguard: warm gold (`#e8be78`)

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
- Character silhouette identity beyond the capsule, and which cosmic archetype each of the three champions becomes.
- How the arena is realized — geometry of the floating platform, which celestial structures appear, what the god-observers look like.
- Animation approach (rigged / procedural / hybrid).
- Audio direction (music, SFX, VO).
- UI visual style beyond current functional dark panels — whether the HUD adopts the purple/blue cosmic palette.
- Whether the existing functional colors (team blue/red, feedback cue palette) survive contact with the cosmic palette, or get re-tuned for contrast against deep purple.

_The **theme** above is settled. Everything in this list is execution within that theme._

## Exploration

_Ideas raised but not established. Label your additions with `Proposed:` and a date so the next agent knows the state._

_(none currently)_

## Rejected directions

_(none currently)_
