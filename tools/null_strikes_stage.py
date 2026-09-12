"""Stage scoped attack-pose review/compatibility fixtures without touching other reviews."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / 'artifacts/null-strikes-v3'
compat = STAGE / 'server-compat'
compat.mkdir(parents=True, exist_ok=True)
shutil.copytree(ROOT/'scripts', compat/'scripts', dirs_exist_ok=True)
shutil.copytree(ROOT/'assets/hitboxes', compat/'assets/hitboxes', dirs_exist_ok=True)
shutil.copytree(ROOT/'assets/animations', compat/'assets/animations', dirs_exist_ok=True)
(compat/'assets/characters').mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT/'assets/characters/lasso_motion.tres', compat/'assets/characters/lasso_motion.tres')
fixture = (ROOT/'tests/null_server_compat.gd').read_text()
fixture = fixture.replace('"recover","stab"]', '"recover","stab","backstab"]')
fixture = fixture.replace('if state=="stab" and frame==1:actor.identity.null_action="stab";', 'if state in ["stab","backstab"] and frame==1:actor.identity.null_action=state;')
(compat/'null_server_compat.gd').write_text(fixture)
(compat/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Null attack compatibility"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
review = (ROOT/'tools/hitbox_review.gd').read_text()
review = review.replace('res://artifacts/null-forge-v2/review/', 'res://artifacts/null-strikes-v3/hitbox-review/')
review = review.replace('["stealth","lift","dive","recover","stab"]', '["stab","backstab"]')
review = review.replace('pose=="stab"', 'pose in ["stab","backstab"]')
review = review.replace('actor.identity.null_action="stab"', 'actor.identity.null_action=pose')
(STAGE/'hitbox_review.gd').write_text(review)
print('NULL_STRIKES_FIXTURES_STAGED')
