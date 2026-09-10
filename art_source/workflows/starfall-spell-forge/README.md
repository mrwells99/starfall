# Starfall Spell Forge

**Living workflow: draft 0.1 — created 2026-09-09.**

Use: “Use Starfall Spell Forge for [class / spell].” Start here each time, then read the spell's own record and the current game implementation.

This folder preserves how we build, review and improve actual in-game spell animations. The owner will describe what they like and dislike after seeing each animation. Record that feedback here and revise the template as patterns emerge. No new spell animation or artistic standard has been approved yet.

## Files

| File / folder | Purpose |
|---|---|
| [WORKFLOW.md](WORKFLOW.md) | Build, review, validate and install an effect |
| [STANDARDS.md](STANDARDS.md) | Technical safeguards and evolving shared visual standards |
| [FEEDBACK.md](FEEDBACK.md) | Owner feedback, its scope, and the resulting decisions |
| [CHANGELOG.md](CHANGELOG.md) | Changes to the Forge itself |
| [templates/SPELL_RECORD.md](templates/SPELL_RECORD.md) | Copy for each spell; retain revisions and exact implementation references |
| [spells/README.md](spells/README.md) | Index of spell records and their latest accepted revisions |
| [library/README.md](library/README.md) | Index of reusable components once validated |

## How the template evolves

1. Build a requested spell and show its actual motion in Godot.
2. Record the owner's feedback against the exact revision shown. Distinguish their words from our interpretation.
3. Apply feedback to that spell. Preserve aspects they liked when revising other aspects.
4. Record whether a preference applies to this spell, its class, an effect family, or all spells. If unspecified, keep it local to the reviewed spell; a possible shared rule stays a proposal.
5. Update shared standards only when the feedback supports that wider scope. Log what changed and why. Acceptance of one spell does not silently redesign older accepted spells.
6. Preserve accepted revisions and their source/build settings so later work has a concrete reference.

This is an editable working folder, unlike the frozen Character Forge v1 archive. Draft 0.1 establishes the process and performance safeguards; it does not freeze an unreviewed visual style. Written instructions alone cannot guarantee identical results: retain actual sources, settings, timing and review evidence with accepted effects.

## Related project records

- [Character Forge v1](../../../docs/STARFALL_CHARACTER_FORGE_V1.md): inherited rigs, locomotion and weapon attachments. Spell presentation coordinates with those rigs; changing spell effects does not authorize rebuilding characters or replacing their gait.
- [Frame-time investigation](../../../docs/FRAME_TIME_INVESTIGATION.md): measured impact stalls, the implemented fix, controls and limitations. Carry these later rendering safeguards forward when using older character source snapshots.
- Runtime assets and scripts belong in the game's normal asset/script locations. This folder holds the workflow and durable records; its parent `art_source/.gdignore` excludes it from Godot imports.
- Preview captures and temporary builds belong under ignored `artifacts/spell-forge/<class>/<spell>/<revision>/`. Keep accepted source and reproducible settings in versioned project paths; temporary captures alone are not a durable baseline. Do not create large archives by default.

Creating this folder does not create a Codex skill or an executable effect framework. The component library will grow from working, reviewed spells.
