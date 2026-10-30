#!/usr/bin/env bash
# Stop gate. Exit 2 blocks the agent from finishing; stderr is shown to it.
# Fill in build/test. Keep it FAST — it runs on every stop, and the hook that calls it
# times out (300s by default). A full suite that takes minutes belongs at the handoff,
# where `jig gate` runs it against the named commit. Put the quick signals here:
# lint, type-check, unit tests, doc checks.
set -u

fail() { echo "check: $1" >&2; exit 2; }

# --- build ---------------------------------------------------------------
claude plugin validate ./plugin >/dev/null 2>&1 || fail "plugin invalid (claude plugin validate ./plugin)"

# --- test ----------------------------------------------------------------
# The full suite (tests/smoke.sh) takes minutes, so it runs at the gate, not here.
python3 -m py_compile plugin/templates/jig/jig.py || fail "jig.py does not compile"

exit 0
