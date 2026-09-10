#!/usr/bin/env python3
"""Check CI's literal Godot summary labels without importing or rendering assets.

Follow script inheritance: champion-specific entry points can share a runner
and its printed summary. The runtime wrapper still enforces counts and exits.
"""
import argparse
from pathlib import Path
import re
import shlex
import sys

ROOT = Path(__file__).resolve().parent.parent
RUNNER = "./tests/check_suite.sh"


def summary_formats(script):
    summaries = set()
    seen = set()
    while script not in seen:
        seen.add(script)
        source = script.read_text(encoding="utf-8")
        summaries.update(re.findall(r'\bprint\(\s*"([^"\n]*passed[^"\n]*)"', source))
        parent = re.search(r'^extends\s+"res://([^"]+)"', source, re.MULTILINE)
        if not parent:
            break
        script = ROOT / parent[1]
    return summaries


def check_workflow(workflow):
    failures, count = [], 0
    # Join shell continuations before parsing each invocation, including inline
    # YAML `run:` commands. No third-party YAML package is needed on the runner.
    source = workflow.read_text(encoding="utf-8").replace("\\\n", " ")
    for line in source.splitlines():
        if RUNNER + " " not in line or line.lstrip().startswith("#"):
            continue
        count += 1
        try:
            args = shlex.split(line[line.index(RUNNER):])
            label = args[1]
            script = ROOT / args[args.index("--script") + 1]
            expected = label + ": %d passed / %d total"
            actual = summary_formats(script)
            if expected not in actual:
                failures.append(f"{script.name}: CI expects {expected!r}; script summaries: {sorted(actual)!r}")
        except (ValueError, IndexError, OSError) as error:
            failures.append(f"Cannot check suite command {line.strip()!r}: {error}")
    if not count:
        failures.append("No suite invocations found; the workflow scan needs updating.")
    for failure in failures:
        print("::error::" + failure, file=sys.stderr)
    print(f"Suite result contracts: {count} checked, {len(failures)} errors")
    return 1 if failures else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workflow", type=Path, default=ROOT / ".github/workflows/deploy.yml")
    sys.exit(check_workflow(parser.parse_args().workflow))
