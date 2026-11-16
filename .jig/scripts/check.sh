#!/usr/bin/env bash
# Two levels. With no argument this is the quick check: it runs on every stop (the hook's
# limit is 300s), and while working, beside the smoke sections a change touched. With --full
# it adds the complete suite: the check role runs that once per gate, or once per batch on
# trunk. Exit 2 blocks the agent from finishing; stderr is shown to it.
set -u

fail() { echo "check: $1" >&2; exit 2; }

# --- quick -----------------------------------------------------------------
claude plugin validate ./plugin >/dev/null 2>&1 || fail "plugin invalid (claude plugin validate ./plugin)"
python3 -m py_compile plugin/templates/jig/jig.py || fail "jig.py does not compile"
# README's "Who does what" pictures are drawn from jig.py's ROLES and FLOWS; a change to either
# without a redraw would leave the README stating old tables.
python3 scripts/roles_svg.py --check || fail "README's drawing is stale: python3 scripts/roles_svg.py, then commit assets/"

# --- complete --------------------------------------------------------------
if [ "${1:-}" = "--full" ]; then
  bash tests/smoke.sh || fail "smoke failed (bash tests/smoke.sh)"
fi

exit 0
