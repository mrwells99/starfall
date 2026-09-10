#!/usr/bin/env bash
# Run a Godot test script and verify every check passed.
#
#   tests/check_suite.sh "<label>" <godot args...>
#
# Suites print "<label>: N passed / M total" and exit non-zero on failure, so
# both are enforced here. Deliberately compares N against M rather than against
# a literal: a hardcoded count turns every new assertion into a CI failure,
# which is exactly what happened when the UI suite grew from 64 checks to 73.

set -euo pipefail

label="$1"
shift

out="$(mktemp)"
trap 'rm -f "${out}"' EXIT

# Preserve Godot's exit status through the pipe.
set +e
"$@" 2>&1 | tee "${out}"
status="${PIPESTATUS[0]}"
set -e

# Godot can return zero and still print a passing assertion count after a
# script aborts inside a callback. Runtime errors must invalidate that result.
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:)' "${out}"; then
    echo "::error::${label} logged an engine or script error." >&2
    exit 1
fi

line="$(grep -oE "${label}: [0-9]+ passed / [0-9]+ total" "${out}" | tail -1 || true)"
if [[ -z "${line}" ]]; then
    echo "::error::${label} never reported a result — the suite did not run to completion." >&2
    exit 1
fi

passed="$(echo "${line}" | grep -oE '[0-9]+' | head -1)"
total="$(echo "${line}" | grep -oE '[0-9]+' | tail -1)"
if [[ "${passed}" != "${total}" ]]; then
    echo "::error::${line}" >&2
    exit 1
fi
if [[ "${status}" -ne 0 ]]; then
    echo "::error::${label} reported all checks passing but exited ${status}." >&2
    exit "${status}"
fi
echo "${line}"
