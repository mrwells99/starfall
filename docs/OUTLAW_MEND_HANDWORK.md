# Outlaw Mend hand-work playtest

Outlaw's existing two-second Mend now uses the approved standing hand-work study:
Fixing_Kneeling arms and fingers, an animated Idle_Loop standing body, and a
30-degree downward gaze split across the neck and head. The hand-work cycle is
5.208 seconds with two idle cycles; Mend plays its first two seconds, without
changing heal amount, cast time, cooldown, movement/cancellation rules or networking.

The new portable animation is installed by the same Outlaw presenter on visible
and mesh-free server rigs. Entry blends over 0.22 seconds and exit over 0.24 seconds
from the displayed pose. Completing or canceling Mend returns to idle/movement,
without playing the unrelated generic projectile-release motion. Weapon geometry
scales out of view over 0.20 seconds to free the animated fingers, then returns on
exit. Existing attacks, locomotion and other characters retain their animations.

This is an additional runtime animation library, not an edit to the existing
Blender model or embedded GLB clips. The existing cloth motion is retained.

## Verification and rollback

Evidence and the installed animation preview are in
`artifacts/outlaw-mend-handwork/`. The record contains source/output hashes,
client/server endpoint comparisons, 4.5.1/4.7.2 compatibility evidence and actual
front/side body-hitbox renders. No server deployment is implied.

Backups of the changed presenter, equipment helper and tests are in that folder's
`before/` directory. Compare the installed manifest before restoring anything:
restore only the Mend-related changes if subsequent edits overlap. Remove the
new Mend library/installer only after removing their presenter reference. The
previous mannequin previews remain intact.
