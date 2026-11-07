#!/usr/bin/env bash
# Evidence for /jig:redocument's start conditions and remap seed, on throwaway repos.
# The skill is prose an agent follows; this script runs the same jig commands its Before
# starting and Hubnode step 1 name, and applies the same tests to their output, so what the
# skill decides from survey and status is shown, not described.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/plugin/templates/jig"
T="$(mktemp -d "${TMPDIR:-/tmp}/jig-redocument.XXXXXX")"
# Outside every repo tree, so no run reads or writes the user's real jig config.
export JIG_CONFIG="$T/repos.json" XDG_CONFIG_HOME="$T/config"
trap 'rm -rf "$T"' EXIT
J="python3 .jig/jig.py"

repo() {   # a jig repo with code for two systems and nothing else
  mkdir -p "$1" && cd "$1"
  git init -q -b main && git config user.email t@t && git config user.name t
  mkdir -p .jig src/store src/render
  cp "$SRC/jig.py" "$SRC/RULES.md" "$SRC/docs-page.md" .jig/
  echo 'SCHEMA = 3' > src/store/schema.py
  echo 'def draw(): pass' > src/render/draw.py
  printf '# Agents\n\nSee .jig/RULES.md.\n' > AGENTS.md
  printf '@AGENTS.md\n' > CLAUDE.md
  git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
}

old_pages() {   # the fixture: one old page at home, one outside the docs tree, one stray
  mkdir -p docs/store docs/notes
  cat > docs/store/store.md <<'EOF'
# Store

## Now
The store keeps rows in SQLite at schema version 3.

## Rules
### 1.1 Schema changes go through a migration step
### 1.2 Add offline mode later

## Checks
- 1.1 test_migrations
- 1.2 —
EOF
  cat > docs/notes/sync.md <<'EOF'
# Sync

## Now
Sync pulls from the server, then pushes.

## Rules
### 2.1 Pull before push

## Checks
- 2.1 test_sync_order
EOF
  printf 'Ideas for later: a dark theme, maybe.\n' > docs/ideas.md
  git add -A && git commit -qm 'old docs'
}

# Before starting, as the skill words it. Prints the decision and the exact refusal string.
start() {
  if git cat-file -e main:.jig/redocument.md 2>/dev/null; then
    echo "resume: .jig/redocument.md is on trunk; refusals skipped"; return
  fi
  local survey; survey="$($J survey --json)"
  python3 - "$survey" <<'EOF' || { echo "no old-format pages: nothing to redocument"; return; }
import json, re, sys
r = json.loads(sys.argv[1])
heads = lambda p: {"Now", "Rules", "Checks"} <= set(re.findall(r"^## (\w+)", open(p).read(), re.M))
old = [e["path"] for e in r["page_contract"] if any(p.startswith("old contract") for p in e["problems"])]
old += [h["path"] for h in r["homeless"] if h["kind"] == "page" and heads(h["path"])]
sys.exit(0 if old else 1)
EOF
  local status; status="$($J status)"
  if [ "$status" != "no jobs open" ]; then
    echo "jobs open: $(echo "$status" | awk 'NR>1 {print $1}' | paste -sd, - | sed 's/,/, /g'); redocument runs on a quiet board"
    return
  fi
  echo "start: old-format pages found, board quiet"
}

# Hubnode step 1: the seed rows survey gives, before the owner's judgment in step 2.
seed() {
  python3 - "$($J survey --json)" <<'EOF'
import json, pathlib, re, sys
r = json.loads(sys.argv[1])
# In a pararepo, the grep the skill names: every cached pointer into this repo's docs.
cited = {}
if pathlib.Path(".jig/para.json").exists():
    name = json.load(open(".jig/config.json"))["name"]
    ptr = re.compile(rf"(?i:(?<![\w-]){re.escape(name)})[/:](docs/[^\s`|§]+\.md)(?:\s*§\s*([^`|]+))?")
    for f in sorted(pathlib.Path(".jig/meta-cache").rglob("*.md")):
        for m in ptr.finditer(f.read_text()):
            cited.setdefault(m[1], []).append(f"§ {m[2].strip()}" if m[2] else "(path)")
cite = lambda p: ", ".join(cited.get(p, []))
print("| Old path(s) | New path | Verb | Notes | Cited |\n|---|---|---|---|---|")
for e in r["page_contract"]:
    if any(p.startswith("old contract") for p in e["problems"]):
        print(f"| `{e['path']}` | `{e['path']}` | rewrite | old contract at home: in place, the job owns it | {cite(e['path'])} |")
# A page outside the docs tree is update's move (the skill runs /jig:update first); shown here
# as the row it becomes when update has not run yet.
for h in r["homeless"]:
    if h["kind"] == "page":
        print(f"| `{h['path']}` | `{h['to']}` | move | outside the docs tree; survey's destination — ask whether it nests as a subsystem | {cite(h['path'])} |")
for h in r["homeless"]:
    if h["kind"] == "stray" and h["path"].startswith("docs/"):
        print(f"| `{h['path']}` | — | drop | stray, {h['inbound']} inbound — owner's call: drop, or fold into a page | {cite(h['path'])} |")
EOF
}

echo "== fixture: old page at home, old page in docs/notes/, a stray"
repo "$T/fixture" && old_pages
echo "-- jig survey"; $J survey
echo "-- before starting"; start
echo "-- remap seed (step 1), proposed to the owner as the step 2 table"; seed

echo; echo "== refusal: no old-format pages"
repo "$T/clean"
mkdir -p docs/store && printf '# Store\n\nThe store keeps rows in SQLite.\n\n## Schema\n\nVersion 3.\n' > docs/store/store.md
git add -A && git commit -qm docs
start

echo; echo "== refusal: another job open"
cd "$T/fixture" && $J open feature --spec "an unrelated feature" --owns src/render/draw.py >/dev/null 2>&1
git add -A && git commit -qm 'open feature'
$J status; start

echo; echo "== resume: the remap is on trunk and the run's own job is open"
repo "$T/resume" && old_pages
printf '## Sources\n\n| Old path(s) | New path | Verb | Notes |\n|---|---|---|---|\n| `docs/store/store.md` | `docs/store/store.md` | rewrite | |\n' > .jig/redocument.md
git add -A && git commit -qm 'redocument: remap'
$J open store --spec "redocument: docs/store/store.md" --owns docs/store/store.md >/dev/null 2>&1
git add -A && git commit -qm 'open store'
$J status; start

echo; echo "== resume: every page rewritten in place, before cleanup"
printf '# Store\n\nThe store keeps rows in SQLite.\n\n## Schema\n\nVersion 3.\n' > docs/store/store.md
printf '# Sync\n\nSync pulls, then pushes.\n\n## Order\n\nPull first.\n' > docs/notes/sync.md
python3 - <<'EOF'
import json; p = ".jig/jobs.json"; json.dump({}, open(p, "w"))
EOF
git add -A && git commit -qm 'store and sync merged (simulated)'
$J survey | grep -q 'old contract' && echo "survey: old-contract pages remain" || echo "survey: no old-contract page left"
start

echo; echo "== pararepo: a metarepo decision cites the store page's Rules heading"
repo "$T/hm" && $J init --meta --name hm >/dev/null
printf '| D-001 | the store rule (`app/docs/store/store.md § Rules`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
git add -A && git commit -qm meta-init && $J release >/dev/null
repo "$T/app" && old_pages
$J init --para hm --location "$T/hm" --contract 'docs/store/**' >/dev/null && git add -A && git commit -qm 'init --para'
echo "-- the cache grep"; grep -rniE '(^|[^[:alnum:]_-])app[/:]docs/' .jig/meta-cache/
echo "-- remap seed, with Cited"; seed
echo "-- at approval: the pointers spec and its proposal"
mkdir -p .jig/specs
printf '# redocument: pointers\n\n- docs/store/store.md § Rules → docs/store/store.md § ___\n' > .jig/specs/redocument-pointers.md
$J propose .jig/specs/redocument-pointers.md redocument-pointers | head -1
meta="$(sed -n 's/^- \(meta: .*\)$/\1/p' .jig/specs/redocument-pointers.md)"
printf '# redocument: docs/store/store.md\n\n## Decisions\n- %s\n- cited: docs/store/store.md § Rules\n' "$meta" > .jig/specs/redocument-store.md
git add -A && git commit -qm 'redocument: remap, pointers proposal'
$J open store --spec .jig/specs/redocument-store.md --owns docs/store/store.md >/dev/null 2>&1
git add -A && git commit -qm 'open store'
cd .git/jig/worktrees/store
printf '# Store\n\nThe store keeps rows in SQLite.\n\n## Schema\n\nSchema changes go through a migration step.\n' > docs/store/store.md
echo "-- the page rewrite alone: the job's spec on trunk answers P2"
git add -A && git commit -qm 'store: page contract' && echo "committed: P2 answered by $meta"
