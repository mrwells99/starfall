# Native lightmap bake: verified host workflow

## Verified 2026-09-08

Godot `4.5.1.stable.official.f62fdbde1` successfully baked a real two-mesh,
one-light scene in the **Compatibility editor under Xvfb** on this host. No
runtime renderer change is needed. The probe project is retained at
`/tmp/sanctum_lightmap_probe`.

The probe contains a 5×5 floor and 1×2×1 block, both BoxMesh with `add_uv2=true`
and `GI_MODE_STATIC`, plus a DirectionalLight3D using `BAKE_STATIC`. Low quality,
one bounce, no denoiser produced `probe.exr` (64×128, 15,433 bytes) and
`probe.lmbake` (2,263 bytes). The HDR atlas ranges from black to 1.17, with mean
RGB approximately (0.145, 0.153, 0.167). It contains the expected cast shadow and
contact shading.

Visual A/B verification in the Compatibility runtime:

- `/tmp/sanctum_lightmap_probe/baked_only.png`: all real-time lights hidden;
  surfaces still show baked lighting and a soft cast shadow.
- `/tmp/sanctum_lightmap_probe/no_lightmap.png`: additionally clear `light_data`;
  both meshes become black.
- `/tmp/sanctum_lightmap_probe/atlas.png`: tone-clipped preview of the HDR atlas.

**Do not infer bake support from `RenderingServer.create_local_rendering_device()`
alone.** It returned null in this probe, but the native editor bake succeeded.
The editor reports OpenGL llvmpipe. A preliminary empty lightmap placeholder
emitted a null-texture warning; the verified output itself is valid. The reusable
helper now provides a one-pixel placeholder to avoid that warning.

## Reusable tools

`tools/bake_sanctum_slice.py` copies project content to a temporary project,
enables `tools/bake_sanctum_slice.gd` as an editor plugin in that copy, invokes
the native **Bake Lightmaps** button, verifies nonblack texture data and mesh
assignments, and copies the output atlas, import configuration, lmbake and
saved scene back. It leaves the actual `project.godot` and editor plugins alone.
Native logs and intermediate files remain in the printed temporary directory.

The native `LightmapGI.bake()` method is intentionally not bound to GDScript
in Godot 4.5.1, which is why an editor helper is needed. Do not substitute a
SceneTree script calling `lightmap.bake()`.

Example once the production bake scene exists:

```sh
python3 tools/bake_sanctum_slice.py \
  --scene scenes/sanctum_quality_slice.tscn \
  --data assets/environment/slice/lighting/sanctum.lmbake
```

The launcher already invokes:

```sh
xvfb-run -a -s '-screen 0 1280x720x24' godot \
  --editor --path /tmp/sanctum_bake_<unique> \
  --rendering-method gl_compatibility --audio-driver Dummy
```

Use `--no-xvfb` on a normal desktop and `--godot /path/to/godot` to choose a
binary. The helper expects an English editor, matching this host.

## Shared lighting profile

Current live and bake settings come from `scripts/sanctum_lighting.gd`. Any change requires regenerating the prepared scene and rebaking. Current production bake uses2bounces and the low sampling preset,115mesh assignments, with live directional and short-range shrine lights set to Dynamic bake mode. Landscape remains outside the bake and casts no shadows. The helper now reads raw output EXRs for statistics to avoid measuring cached prior atlases; source-image statistics from older reports may be stale.

## Production slice status

**The production slice is now baked and integrated.** `scenes/sanctum_quality_slice.tscn` contains 115 static UV2 mesh instances, shared PBR materials and LightmapGI. The bake assigns all115meshes. Runtime removes its temporary BakeLights so direct illumination is not doubled. `tools/prepare_sanctum_slice.gd` rebuilds the scene and clears the previous bake assignment; rebake after running it. The review tool confirms 19 world bodies and zero artwork bodies.

Expanded placement: all four original covers, nine modules covering the full36x36floor, twelve boundary modules and two terraces. Runtime assets and complete authoring workflow are documented in ART_SLICE_HANDOFF.md.

Prefer a **Dynamic** bake mode for the gameplay directional light so its
direct shadows still respond to champions, while only bounced light is baked.
Static decorative lights may use Static mode. Keep runtime key-light direction,
color and energy consistent with the bake. The lightmap only covers this
quality slice; other arena geometry keeps its existing lighting.

After baking, reimport the returned EXR and scene in the real project, then
capture gameplay-camera and close-up A/B images in Compatibility. Validate
scene path bindings and champion shadows. Run map and combat tests after
integration; the lightmap process itself should add no collision or gameplay
changes. Count the atlas bytes against the requested environment asset budget.

## Primary references

- [Godot 4.5 lightmap workflow](https://docs.godotengine.org/en/4.5/tutorials/3d/global_illumination/using_lightmap_gi.html)
- [Godot 4.5.1 LightmapGI implementation](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/3d/lightmap_gi.cpp)
