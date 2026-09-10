# Spell production and revision workflow

## 1. Recover the current contract

Read this Forge, shared standards, relevant feedback, the spell's record, and the current class/ability code. Inspect project instructions and local modifications. Current live mechanics are authoritative; historical examples are not permission to restore old gameplay code.

Record the class, spell identifier, current implementation, cast/channel duration, release/impact events, target/range/AoE rules, effect duration and relevant equipment attachments. Record current game/engine versions. Preserve combat authority, damage, resource generation, cooldowns, GCD, collision and networking unless the owner requests a mechanics change. Audio remains outside this workflow unless the owner explicitly changes that scope.

## 2. Define the effect and revision

Copy `templates/SPELL_RECORD.md` into `spells/<class>/<spell>/RECORD.md`. Give each iteration a revision such as `r001`. State what is changing and which accepted traits must be preserved. Identify candidate shared components; inspect their current code before reuse.

Describe anticipation, release/travel, impact, persistence and recovery separately. Map them to authoritative gameplay events and character pose/weapon sockets. Instant casts must remain immediate; cosmetic anticipation must not delay accepted gameplay. Telegraphs must truthfully represent existing area/range rules. Preserve walking, facing and animation blending where the mechanics allow movement.

Class colors, shapes and motion should follow the current class reference and the owner's feedback. Do not invent a global color, duration, camera-shake or bloom standard before one has been established.

## 3. Build reversibly

Use real game meshes, materials, particles, skeletal motion and code as appropriate. Use Blender when the requested effect needs authored geometry or skeletal animation. The deliverable is a working animated effect, with editable sources and implementation references.

Back up only paths being replaced, preserving their relative paths and hashes; record newly created paths too. Use a distinct staging/preview scene when preview-before-install was requested. Follow existing authorization for reversible project installation; do not add an extra permission step by default. A local install does not authorize a commit, push or deployment.

Prepare shader/material combinations before combat. Retain reusable geometry and material templates, isolate mutable per-effect state, and define interruption and cleanup behavior. Use the performance safeguards in `STANDARDS.md`.

## 4. Review actual motion

Show anticipation through cleanup in Godot at the normal gameplay camera and closer detail when needed. Include movement, simultaneous spells, both teams and the existing environment. A still image can supplement motion review but cannot establish animation timing or fluidity.

Record the exact revision shown and save a reproducible preview setup or capture path. Test cancellation, interrupted casts, invalid/dead targets, repeated hits, overlapping effects, caster death and round reset where applicable. Verify position/orientation and that visual changes do not move the combat body.

## 5. Check performance and behavior

Use the current native rendered 3v3 benchmark and repeat the same actions in a second round. Ensure the new spell and any new material variant actually appear in the measured scenario; the existing 29-ability capture does not automatically cover future work. Extend the deterministic scenario when needed and record the change.

Save individual frame intervals, event timestamps, first/repeated-use results, focus flags, runtime pipeline counters, game/engine revision, backend, driver, CPU/GPU, actual resolution, render scale, preset and cap. Keep baseline and candidate conditions comparable. Do not substitute average FPS or headless performance for native rendering measurements.

Investigate event-correlated regressions, including first-use stalls. Record budget exceptions and evidence instead of declaring a pass from an average. Run relevant behavior/presentation tests; check concurrent effect independence and cleanup for new reusable components.

## 6. Capture feedback and update the template

Append to `FEEDBACK.md`: spell/revision, owner's words, liked traits, requested changes, scope, interpretation and implementation outcome. Keep earlier feedback. If feedback conflicts with an earlier preference, record which decision it supersedes and its scope.

Revise the spell while retaining accepted traits. Update `STANDARDS.md` only for supported shared preferences, linking the feedback entry. Add a component to `library/README.md` only after it exists and its behavior/performance are verified. Record visual acceptance separately from technical validation and installation.

## 7. Deliver and preserve

Update the spell record and index with exact files, hashes or revision, timing/settings, validation results, feedback status and rollback instructions. Update the Forge changelog when the workflow/template changes. Report what is implemented, what was measured and any unresolved issue. Preserve unrelated project edits and the frozen Character Forge archive.
