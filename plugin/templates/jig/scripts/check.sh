#!/usr/bin/env bash
# The project's check, at two levels. Exit 2 blocks the agent from finishing; stderr is shown
# to it.
#   check.sh          the quick part: runs on every stop and while working. Keep it FAST —
#                     the stop hook that calls it times out (300s by default). Lint,
#                     type-check, unit tests, doc checks.
#   check.sh --full   the quick part, then the complete part: the full suite, slow and
#                     end-to-end tests. Only the check step runs it: once per gate, in the
#                     checkout `jig gate` prints, or once on trunk after a batch of merges.
set -u

fail() { echo "check: $1" >&2; exit 2; }
full=0; [ "${1:-}" = "--full" ] && full=1

# --- quick ---------------------------------------------------------------
echo "check: quick"
# TODO: uncomment one build and the fast tests.
# idf.py build          >/dev/null 2>&1 || fail "build failed (idf.py build)"
# npm run build         >/dev/null 2>&1 || fail "build failed"
# cargo build           >/dev/null 2>&1 || fail "build failed"
# Logic tests only; hardware checks live in skill: verify.
# npm test              >/dev/null 2>&1 || fail "tests failed"
# pytest -q -m "not slow" >/dev/null 2>&1 || fail "tests failed"
# cargo test --lib      >/dev/null 2>&1 || fail "tests failed"

# --- full ----------------------------------------------------------------
if [ "$full" = 1 ]; then
  echo "check: full"
  # TODO: the complete suite.
  # npm run test:e2e    >/dev/null 2>&1 || fail "end-to-end tests failed"
  # pytest -q           >/dev/null 2>&1 || fail "tests failed"
  # cargo test          >/dev/null 2>&1 || fail "tests failed"
  :
fi

exit 0
