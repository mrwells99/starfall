# Art Direction — established source of truth

_Established visual direction. Ideas and exploration are labeled. Aesthetics have deliberately been deferred — see [`DECISIONS.md`](DECISIONS.md)._

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

Dark near-black clear color (`#0a0f17`) for high contrast against character silhouettes.

## What is NOT decided

_Open. Do not silently promote:_

- Overall art style (stylized / realistic / abstract).
- Character silhouette identity beyond the capsule.
- Environment aesthetic beyond the current arena.
- Animation approach (rigged / procedural / hybrid).
- Audio direction (music, SFX, VO).
- UI visual style beyond current functional dark panels.
- Whether to keep the current color scheme or replace it.

## Exploration

_Ideas raised but not established. Label your additions with `Proposed:` and a date so the next agent knows the state._

_(none currently)_

## Rejected directions

_(none currently)_
