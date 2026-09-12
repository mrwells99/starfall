# Shared Mend hand-work

Ember, Luminary, Vanguard and Fulcrum now use the same standing hand-work clip
approved for Outlaw. Null remains on its existing Regen Pot presentation.
All five Mend users retain the green rising crosses and glow during the cast.

Entry blends over 0.22 seconds and recovery over 0.24 seconds. Completion and
cancellation return to the current standing/movement pose. Cast time, healing,
cooldowns and cancellation rules are unchanged.

Vanguard eases out of the two-handed weapon solve while the weapon scales out
of view, allowing both arms to perform the actual hand-work. Recovery restores
the weapon and both original wrist attachments. Luminary keeps the staff upright
in her right hand with a closed finger grip. Fulcrum's orb follows his left hand
through the motion and transitions.

The same presenter/animation library is installed on the visible and mesh-free
server rigs. The existing Blender models, GLBs, rest bones, original clips and
hitbox dimensions were not modified. This additional animation is a runtime
library; costume controls retain their previous base pose during its playback.

## Review and reversal

Actual front/side captures and animated previews for all four classes are under
`artifacts/shared-mend-handwork/review/<class>/`. Each folder contains `mend.gif`,
`idle.png`, `mend-45.png`, `mend-60.png`, `mend-80.png` and captured frames.

The class records and test evidence are in `artifacts/shared-mend-handwork/`.
Tests cover the actual hand-work rotations, client/server pose agreement,
Vanguard weapon/hand restoration, staff and orb attachment, cast cancellation,
stun recovery, baseline movement and combat, and Godot 4.5.1/4.7.2 compatibility.

Backups of the changed shared presenters, tests and viewer are in `before/`.
Compare `installed-manifest.json` before restoring. If later edits overlap,
revert only the new shared Mend and equipment-blend hunks. Keep Outlaw's prior
Mend installer/library and the shared Regen Pot visual effect.
