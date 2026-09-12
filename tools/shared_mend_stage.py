"""Package reviews and isolate desktop/server Mend compatibility fixtures."""
from pathlib import Path
import shutil
from PIL import Image
root=Path(__file__).resolve().parents[1]
stage=root/'artifacts/shared-mend-handwork'
for version in ['451','472']:
    compat=stage/f'compat-{version}'
    for directory in ['scripts','assets/hitboxes','assets/animations']:
        shutil.copytree(root/directory,compat/directory,dirs_exist_ok=True)
    (compat/'assets/characters').mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/'assets/characters/lasso_motion.tres',compat/'assets/characters/lasso_motion.tres')
    shutil.copy2(root/'tests/shared_mend_handwork_test.gd',compat/'shared_mend_handwork_test.gd')
    (compat/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Shared Mend compatibility"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
for title in ['ember','luminary','vanguard','fulcrum']:
    directory=stage/'review'/title
    frames=[]
    for path in sorted((directory/'frames').glob('*.png'))[::2]:
        with Image.open(path) as image: frames.append(image.convert('RGB').quantize(colors=128))
    assert len(frames)==60,title
    frames[0].save(directory/'mend.gif',save_all=True,append_images=frames[1:],duration=83,loop=0,disposal=2)
print('SHARED_MEND_FIXTURES_AND_PREVIEWS_READY')
