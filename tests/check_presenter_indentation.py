"""Keep the shared presenter safe when saved with Godot's tab indentation."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = root / "scripts/model_forge_art.gd"
failures = []
for number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
    if not line.strip():
        continue
    prefix = re.match(r"[ \t]*", line).group()
    if " " in prefix:
        failures.append(f"{source.name}:{number}: use tabs for every indentation level")
if failures:
    raise SystemExit("\n".join(failures))
print("Shared presenter indentation: consistent tabs")
