# Null attack variation v3

Temporal Strike now uses a 0.44-second forward jab from Quaternius `Punch_Jab`.
Backstab uses a 0.52-second committed blade cut from `Sword_Attack`, cropped to
one strike. These are new library-derived attacks, replacing the shared reduced
`Punch_Cross` overlay. Entries capture the displayed upper-body pose, the torso
turn is restrained, the support hand stays close, and recovery eases into the
current movement or Stealth pose.

`tools/build_null_strike_library.gd` extracts the 13 upper-body curves at 60 Hz
from the verified CC0 Standard library into `assets/animations/null_strikes_v3.tres`.
Shoulder curves use skeleton-space orientation to preserve forward attack
direction without transplanting the library's hip turn. `null_strike_pose.gd`
applies the same resource and transitions to client and server skeletons.
The existing Blender source, GLB, 35 embedded clips and compact server rig are
unchanged; these two variations live in the separate animation layer.

No damage, range, cooldown or hit timing changes. The validation also fixed the
ground-shadow mesh being allocated in Null's pose-only server presenter, and
updated stale 100-HP/12-damage expectations in the aimed-combat test for the
already-established 1,500-HP/120-damage balance.

Revision evidence and SHA-256 rollback maps are in `artifacts/null-strikes-v3/`.
`before/null_art.gd` is the exact pre-variation presenter, including the current
Stealth, Haste and Regen effects. Restore only the attack-related hunks if later
work changes the file; do not overwrite subsequent user changes. Keep the
pose-only ground-shadow guard when reverting the animation.

Reviewed actual three-quarter/side animation frames and front/side hitboxes.
The new motions remain subject to the user's playtest and can be reverted.
