#!/usr/bin/env bash
# Plugin hook, on SessionStart (startup, resume, compact). Prints one line naming this
# session's jig node (its role skill is loaded on assignment), so a session that loses its skill to compaction is told again: a role
# read once at the start is gone by the time the session drifts. Prints nothing where there
# is no hubnode or subnode work: no .jig/, or no open job and nothing staged. Reads only;
# always exits 0, so it can never stop a session from starting.
set -u
cat >/dev/null 2>&1   # the event's JSON: the role is the same for every source
repo="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$repo" 2>/dev/null || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -d "$top/.jig" ] || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main=$(dirname "$common")
branch=$(git branch --show-current 2>/dev/null)
python3 - "$top" "$main" "$branch" <<'PY' 2>/dev/null
import json, os, subprocess, sys
top, main, branch = sys.argv[1:]

def show(path):
    p = subprocess.run(["git", "-C", main, "show", f"{trunk}:{path}"], capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else ""

try:
    trunk = json.load(open(os.path.join(main, ".jig", "config.json"))).get("trunk", "main")
except Exception:
    trunk = "main"
# The board as trunk has it: that is the one every rule reads.
try:
    jobs = json.loads(show(".jig/jobs.json") or "{}")
except ValueError:
    jobs = {}
if os.path.realpath(top) != os.path.realpath(main):
    for name, job in jobs.items():
        if (job or {}).get("branch", name) == branch:
            print(f"jig: this session is the subnode for job {name}. Run /jig:subnode before anything else.")
            break
    sys.exit(0)
staging = os.path.join(main, ".jig", "staging")
staged = [f for f in (os.listdir(staging) if os.path.isdir(staging) else []) if not f.startswith(".")]
if jobs or staged:
    print("jig: this is the trunk checkout, with " + " and ".join(
        filter(None, [f"{len(jobs)} open job{'s' if len(jobs) != 1 else ''}" if jobs else "",
                      f"{len(staged)} staged file{'s' if len(staged) != 1 else ''}" if staged else ""]))
          + ": this session is the hubnode. Run /jig:hubnode before anything else.")
PY
exit 0
