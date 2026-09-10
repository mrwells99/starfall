"""The Godot runner must reject runtime errors even with a passing summary."""
from pathlib import Path
import os
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
bash = "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else shutil.which("bash")
cases = [
    ("clean", "print('Probe: 1 passed / 1 total')", 0),
    ("script error", "print('SCRIPT ERROR: simulated'); print('Probe: 1 passed / 1 total')", 1),
    ("engine error", "print('ERROR: simulated'); print('Probe: 1 passed / 1 total')", 1),
    ("stderr error", "import sys; print('SCRIPT ERROR: simulated', file=sys.stderr); print('Probe: 1 passed / 1 total')", 1),
    ("missing summary", "print('started')", 1),
    ("failed assertion", "print('Probe: 0 passed / 1 total')", 1),
    ("nonzero exit", "print('Probe: 1 passed / 1 total'); raise SystemExit(2)", 2),
    ("warning", "print('WARNING: simulated'); print('Probe: 1 passed / 1 total')", 0),
]
for name, source, expected in cases:
    result = subprocess.run([bash, "tests/check_suite.sh", "Probe", sys.executable, "-c", source], cwd=root, capture_output=True, text=True)
    assert result.returncode == expected, (name, result.returncode, result.stdout, result.stderr)
print(f"Suite runner checks: {len(cases)} passed / {len(cases)} total")
