# Linux setup and imported animation workflow

The friend's `local_resources` bundle is flattened in this checkout: `animation_sources/`, `animation_references/`, `animation_cache/`, etc. The actual motion workflow is `art_source/workflows/starforge-motionlab/`; older catalogue code expects `starfall-motion-lab` and Windows paths.

`tools/motion_resources.py` accepts both layouts. It adapts the imported reference shelf in memory, resolves Windows `local_resources` paths against this checkout, preserves path containment, and leaves the source catalogues/scripts unchanged. Do not create fake `C:` directories or edit every historical path. The original bundle remains optional and ignored by Git.

```sh
python tools/motion_resources.py doctor
python tools/motion_resources.py shelf --query skate
python tools/motion_resources.py shelf --verify-media --html diagnostics/motion-shelf.html
python tools/motion_resources.py inventory --query skate --output diagnostics/motion-inventory.json
```

Output parents must exist; the original shelf/inventory refuse to replace an existing output. The generated shelf adds 2× playback. Inventory labels describe candidate files, not retargeted/approved animation. The Haley Tuffles pack includes SkateFigureStance and several grind/transition takes; those are useful candidates, not proof of a continuous skating stride. Ember r001 instead ships an editable procedural pose layer.

## Native tools

Validated on this machine: Godot **4.5.1**, Blender **5.2.1 LTS**, FFmpeg/FFprobe **9.0.1**, Python 3. Already installed native executables are used; bundled Windows `.exe` files are not required. The doctor reports exact paths and versions. Override discovery with `GODOT`, `BLENDER`, `FFMPEG` or `FFPROBE` executable paths on another computer.

For a fresh Linux machine, obtain Linux builds from [Blender](https://www.blender.org/download/), [Godot](https://godotengine.org/download/linux/) and [FFmpeg](https://ffmpeg.org/download.html), or the distribution's packages. Use the project's supported Godot version. No Wine dependency is introduced.

Run Blender authoring scripts with a clean session and automatic embedded script execution disabled:

```sh
blender --background --factory-startup --disable-autoexec --python path/to/reviewed_authoring_script.py -- script_arguments
```

An actual Ember GLB import and staged export succeeded on this installation, preserving a 73-bone armature. The distribution's optional MeshOptimizer bridge was missing; ordinary uncompressed GLB export still succeeded. Existing Model Forge Python scripts use `Path(__file__)`-relative project paths and run with Linux Blender. Do not overwrite shipped GLBs just to test the toolchain.

Replace the bundled Windows video-review executable with the browser reference shelf and Linux FFmpeg/FFprobe. Preserve originals and label derived review proxies. For an unsupported source codec:

```sh
ffprobe -v error -show_format -show_streams input-video
ffmpeg -i input-video -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart diagnostics/review-proxy.mp4
```

The particle workflow itself needs only Godot to play; Blender is for optional body/mesh authoring. The source bundle and its old Windows tools are never runtime dependencies.
