# Vanguard hammer study — 2026-09-08 handoff

## Owner's direction

Owner rejected the earlier procedural upgrade and the first character-plus-hammer
study as only marginally better than the placeholder. Reference:
`/home/plato/Downloads/ChatGPT Image Sep 8, 2026, 01_37_56 PM.png` — realistically
proportioned dark heavy armor, exposed male head, mechanical joints, violet
crystal cores, oversized two-handed hammer. Owner explicitly authorized
building the weapon first as a standalone review asset before rebuilding the
character around it.

## Current stage: **Stage 1 (hammer only) — OWNER-APPROVED, locked**

Owner accepted the hammer as of this checkpoint and authorized moving on to
Stage 2 (torso/shoulders). Design direction confirmed against
`artifacts/vanguard/vanguard-design.png` (the full-character cosmic gladiator
reference: exposed male head, dark hex-plate mechanical armor with violet
crystal cores across chest/shoulders/limbs, jagged crystal shoulder spikes,
mechanical joints, boots, hero proportions but grounded).

## What exists (Stage 1)

- `tools/build_vanguard_hammer_weapon.py` — Blender 5.x background script for
  the standalone hammer. Uses boolean-cut apertures through the housing so
  the crystal wells actually READ from the striking-face angle rather than
  being buried in solid metal. Head is elongated (0.90 × 0.46 × 0.60) so the
  silhouette reads as a maul rather than a cube. Adds a `crystal_chunk`
  helper that subdivides + jitters a box to give faceted internal geometry
  (boundary vertices pinned so the block still fills its aperture).
- `tools/vanguard_hammer_weapon_review.gd` — loads the actual arena, freezes
  gameplay, applies the crystal + forged shaders as overrides on the hammer
  (with hammer-specific parameters), and renders six angles. Yaws the hammer
  per-shot so each face of interest faces a fixed observing camera; avoids
  fighting the glTF Y-up axis remap. Rejects `--headless`.
- `art_source/vanguard_hammer_weapon.blend` — editable Blender source,
  ~200 KiB. Script-built geometry; edits made here are erased on the next
  script rebuild.
- `assets/characters/vanguard_hammer_weapon.glb` — exported and imported.
  **5 mesh instances, 18,714 triangles** after the lozenge/facet/cage pass.
  Head is a wide-and-short crystal LOZENGE (1.1 x 0.44 x 0.44 m) built as a
  subdivided cube cast to sphere at factor 0.4 (keeps the elongation),
  then decimated to ~14% and dissolve-decimated at 5 deg so the surface
  reads as clear angular crystal facets rather than a smooth egg. Two
  dark cage rings hug the ovoid — one equatorial, one meridian — scaled
  per-axis via a new `oval_ring` helper so they wrap the actual elliptical
  body instead of ballooning outward. Radiating crystal wing shards
  unchanged. Only the haft, its grip collars, pommel disk and head-to-haft
  yoke are metal.
- `shaders/vanguard_crystal.gdshader` — updated with three uniforms
  (`cell_scale`, `emission_boost`, `fissure_softness`). Defaults preserve
  the previous character study's tight-veining look; hammer review overrides
  set larger facets (cell_scale=3.5) and stronger emission (boost=2.6) to
  push past the 1.35 bloom threshold from inside the metal housing.
- `shaders/vanguard_forged.gdshader` — added `pit_frequency`,
  `mottle_frequency`, `wear_strength` uniforms. Defaults preserve prior
  behavior; hammer review overrides use lower-frequency noise (pit=42,
  mottle=12, wear=0.6) so the metal doesn't pixelate at close range.

The earlier full-character study (`art_source/vanguard_hammer.blend`,
`assets/characters/vanguard_hammer.glb`, `tools/build_vanguard_hammer.py`,
`tools/vanguard_hammer_review.gd`, `hammer-study-*.png`) is intentionally
untouched. It is out of scope for Stage 1 review.

The playable Vanguard model is unchanged; combat rules, arena, collision,
timing and networking were not modified.

## Rendered evidence

Rendered in the real arena with lighting, freeze-on-load, no gameplay
mutation. Renderer is still **Mesa llvmpipe software**; no hardware
performance proof.

- `artifacts/vanguard/hammer-weapon-close-face.png` — striking face from
  eye height.
- `artifacts/vanguard/hammer-weapon-three-quarter.png` — hero angle showing
  bolted frame, crystal panel and top spike together.
- `artifacts/vanguard/hammer-weapon-side.png` — side-window slit face.
- `artifacts/vanguard/hammer-weapon-back-face.png` — opposing striking face
  (both crystal wells lit; this is the best confirmation the geometry works).
- `artifacts/vanguard/hammer-weapon-gameplay.png` — wider arena camera.
- `artifacts/vanguard/hammer-weapon-top.png` — top-down showing the crown:
  main spike + two flanking teeth + capstone shaping.

## Honest visual assessment

Improvements from the previous study:

- Silhouette is a bright glowing crystal LOZENGE with angular flat facets
  and wing shards radiating outward — no metal shell around the head.
  Direction confirmed by owner after iterating away from (a) a boxy metal
  frame the owner found distracting and (b) a symmetric egg shape that
  read as too spherical. Current head is wider on the striking axis than
  tall (1.1 x 0.44 x 0.44 m) with chunky decimated facets and two thin
  dark cage rings wrapping the ovoid. Only the haft, grip collars, pommel
  disk and head-to-haft yoke remain metal. Inspired by (not copied from)
  `artifacts/vanguard/reference.jpg`.
- The metal housing is real dark forged plate; the crystal wells are
  visibly INSIDE bolted metal apertures rather than the whole head being a
  crystal block with steel end caps (that was inverted from reference).
- Each striking face has a bolted rectangular frame with visible corner hex
  bolts, matching the reference bolted-plate look.
- Metal noise no longer pixelates at close range.
- Top crystal spike is a single centered element with two small flanking
  teeth instead of a busy cluster.
- Side windows glow through framed channels so the head reads as lit from
  the front/back as well as the striking faces.
- Haft is substantially thicker with visible metal collars top/mid/pommel
  and grip wrap segments, ending in a bolted pommel disk with an embedded
  crystal seed.

Remaining defects visible in the renders:

1. **Close-face lighting asymmetry.** From the close-face camera, the lower
   crystal well reads darker than the upper — the arena's directional light
   biases toward the upper aperture. Both wells are present and both are lit
   from other angles (see `back-face.png` and `top.png`). Not a geometry
   bug; a lighting/pose issue that a proper carry pose (with the hammer
   held forward instead of vertical) may resolve.
2. **Crystal facet definition.** The shader's cell-noise fissures are
   visible but read as generic glow, not as clear angular facets like the
   reference. Achieving that likely needs authored per-shard geometry or a
   sharper voronoi shader with hand-placed facet planes.
3. **Metal is still procedurally shaded**, no authored PBR maps. It reads
   as forged steel but lacks the reference's tight bevel + micro-scratch
   detail. This is what a proper substance/hand-painted pass would replace.
4. **Boolean apertures produce small artefacts** near the cut edges at the
   FLOAT solver setting; the frame plates cover most of these. Switching
   to MANIFOLD solver may clean this up further.
5. **Scale in `gameplay.png`** reads small because the character is absent.
   Do not judge weapon scale from this render; that check belongs after
   the character is rebuilt.

The hammer is now clearly closer to the reference direction than the prior
study. It is not yet reference-level authored art and the review should be
about whether the direction warrants proceeding to Stage 2, not whether the
result is final.

## Reproduce

Run from repository root:

```sh
blender -b --python tools/build_vanguard_hammer_weapon.py
XDG_CONFIG_HOME=/tmp/vanguard-godot-config godot --headless --path . --editor \
  --import --quit --log-file /tmp/vanguard-hammer-weapon-import.log
xvfb-run -a -s '-screen 0 1600x1100x24' godot --path . \
  --script tools/vanguard_hammer_weapon_review.gd \
  --log-file /tmp/vanguard-hammer-weapon-review.log
```

The import step must finish before the review runs. The virtual display is
required in this environment because sandboxed X11 fails. Godot 4.5.1
Compatibility (OpenGL) — no Forward+-only features used.

## Next work in priority order

1. **Owner visual review of Stage 1.** Decide whether the direction is
   accepted before spending on the character.
2. If accepted, address the close-face lighting asymmetry either by giving
   the review scene a fill light on the striking face or by presenting the
   hammer at a carry angle (the character-integrated pose will do this
   naturally).
3. Optional: switch boolean solver from FLOAT to MANIFOLD; add a
   small chamfer to the aperture inner edge in Blender to catch light on
   the cut.
4. Stage 2: torso and shoulders around the accepted weapon.
5. Stages 3–7 per the original plan; do not skip forward.

## Tests

No combat / networking tests were re-run. This pass changed:

- Two shaders (both preserving their previous defaults so existing users
  render identically).
- A new build script.
- A new review script.
- A new .glb + .glb.import + .blend under `art_source/` and
  `assets/characters/`.

`tests/check_references.py` was not invoked; no committed file was changed
to point at these new assets. Verify before committing that no test
expects the previous crystal shader's hard-coded values.

## Usage / stop discipline

I cannot read this environment's account usage — no visible signal. Owner
should monitor 90% ceiling. This pass stops now at a natural checkpoint
(Stage 1 complete, handoff written) rather than continuing into Stage 2.
No commits, pushes or deployments. No resets redeemed. The 2026-09-08
prior stop at 91% is recorded in the previous section of this file's
history.

See `VANGUARD_ART_HANDOFF.md` for the earlier playable procedural model
and `ART_SLICE_HANDOFF.md` for completed arena work. Preserve unrelated
uncommitted diffs in the shared workspace.
