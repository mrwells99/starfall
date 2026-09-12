"""Create a looping animation of the isolated standing-handwork study."""
from pathlib import Path
from PIL import Image
import sys

folder = Path(__file__).resolve().parents[1] / ("artifacts/mend-standing-living-preview" if "--living" in sys.argv else "artifacts/mend-standing-preview")
paths = sorted((folder / "frames").glob("*.png"))
assert len(paths) == 125, f"Expected one complete source loop, got {len(paths)}"
frames = []
for path in paths[::2]:
    with Image.open(path) as image:
        frames.append(image.convert("RGB").quantize(colors=128))
output = folder / "standing-handwork.gif"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=83,
               loop=0, optimize=True, disposal=2)
with Image.open(output) as check:
    assert check.n_frames == len(frames)
    print(f"{output}: {check.n_frames} frames, {check.size}, {output.stat().st_size:,} bytes")
