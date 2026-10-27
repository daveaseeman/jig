#!/usr/bin/env bash
# Stop gate. Exit 2 blocks the agent from finishing; stderr is shown to it.
# Fill in build/test. Keep it FAST — it runs on every stop, and the hook that calls it
# times out (300s by default). A full suite that takes minutes belongs at the handoff,
# where `jig gate` runs it against the named commit. Put the quick signals here:
# lint, type-check, unit tests, doc checks.
set -u

fail() { echo "check: $1" >&2; exit 2; }

# --- build ---------------------------------------------------------------
# TODO: uncomment one
# idf.py build          >/dev/null 2>&1 || fail "build failed (idf.py build)"
# npm run build         >/dev/null 2>&1 || fail "build failed"
# cargo build           >/dev/null 2>&1 || fail "build failed"

# --- test ----------------------------------------------------------------
# TODO: uncomment one. Logic tests only; hardware checks live in skill: verify.
# npm test              >/dev/null 2>&1 || fail "tests failed"
# pytest -q             >/dev/null 2>&1 || fail "tests failed"
# cargo test            >/dev/null 2>&1 || fail "tests failed"

exit 0
