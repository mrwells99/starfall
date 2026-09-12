"""Isolate the older server engine's import cache from the desktop project."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
stage=root/'artifacts/null-forge-v2/server-compat'
stage.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'scripts',stage/'scripts',dirs_exist_ok=True)
shutil.copytree(root/'assets/hitboxes',stage/'assets/hitboxes',dirs_exist_ok=True)
(stage/'assets/characters').mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'assets/characters/lasso_motion.tres',stage/'assets/characters/lasso_motion.tres')
shutil.copy2(root/'tests/null_server_compat.gd',stage/'null_server_compat.gd')
(stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Null server compatibility"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
print(stage)
