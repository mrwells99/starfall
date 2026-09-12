"""Stage the mesh-free Mend compatibility fixture and package its review."""
from pathlib import Path
import shutil
from PIL import Image

root = Path(__file__).resolve().parents[1]
stage = root / 'artifacts/outlaw-mend-handwork'
compat = stage / 'server-compat'
compat.mkdir(parents=True, exist_ok=True)
for directory in ['scripts', 'assets/hitboxes', 'assets/animations']:
    shutil.copytree(root/directory, compat/directory, dirs_exist_ok=True)
(compat/'assets/characters').mkdir(parents=True, exist_ok=True)
shutil.copy2(root/'assets/characters/lasso_motion.tres', compat/'assets/characters/lasso_motion.tres')
shutil.copy2(root/'tests/outlaw_mend_test.gd', compat/'outlaw_mend_test.gd')
(compat/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Outlaw Mend compatibility"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
frames = []
for path in sorted((stage/'review/frames').glob('*.png'))[::2]:
    with Image.open(path) as image:
        frames.append(image.convert('RGB').quantize(colors=128))
assert len(frames) == 60
output = stage/'review/outlaw-mend.gif'
frames[0].save(output, save_all=True, append_images=frames[1:], duration=83, loop=0, disposal=2)
print('OUTLAW_MEND_STAGED', compat, output)
