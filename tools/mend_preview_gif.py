"""Package rendered source-library previews; does not modify game assets."""
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parents[1] / "artifacts/mend-library-preview"
frames = []
for path in sorted((folder / "frames").glob("*.png"))[::2]:
    with Image.open(path) as image:
        frames.append(image.convert("RGB").quantize(colors=128))
assert len(frames) == 72, "Expected six seconds of captured comparison frames"
output = folder / "candidates.gif"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=83,
               loop=0, optimize=True, disposal=2)
with Image.open(output) as check:
    assert check.n_frames == 72
    print(f"{output}: {check.n_frames} frames, {check.size}, {output.stat().st_size:,} bytes")
