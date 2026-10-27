#!/usr/bin/env bash
# End-to-end check of the rules in a throwaway repo: one lane in a worktree, the hooks
# installed from the template. Every case prints PASS or the refusal it expected.
set -u
T=$(mktemp -d "${TMPDIR:-/tmp}/jig-smoke.XXXXXX")
P="$(cd "$(dirname "$0")/.." && pwd)/plugin/templates"
J="python3 .jig/jig.py"
fail=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=1; }
expect_pass() { if "$@" >/dev/null 2>&1; then ok "$msg"; else bad "$msg"; fi; }
expect_refuse() { if "$@" >/dev/null 2>&1; then bad "$msg (was accepted)"; else ok "$msg"; fi; }
undo() { git reset -q; git checkout -q -- .; git clean -fdq; }

cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t
mkdir -p .jig docs/systems src
cp "$P/jig/jig.py" "$P/jig/RULES.md" .jig/
cp "$P/AGENTS.md" . && cp -r "$P/ledgers" .
cp "$P/docs/README.md" docs/ && cp -r "$P/scripts" . && chmod +x scripts/*.sh
printf 'x=1\n' > src/a.py
printf '# A\n\n## 28 Alpha\ntext\n\n## 29 Beta\ntext\n' > docs/systems/a.md
git add -A && git commit -qm init
$J init >/dev/null
python3 - <<'EOF'
import json; b = json.load(open('.jig/lanes.json'))
b['reserve'] = {'section': {'next': 29, 'pattern': r'^## (\d+) ', 'files': ['docs/systems/**']}}
json.dump(b, open('.jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board
$J open L1 --brief t --owns 'src/**' 'docs/systems/**' --reserve section >/dev/null
git add -A && git commit -qm "open L1"
cd .jig/worktrees/L1

msg="R6: editing an existing heading's text takes nothing"
sed -i.bak 's/## 29 Beta/## 29 Beta renamed/' docs/systems/a.md && rm docs/systems/a.md.bak
git add -A; expect_pass git commit -qm e1

msg="R6: moving a page takes nothing"
git mv docs/systems/a.md docs/systems/b.md; expect_pass git commit -qm mv

msg="R6: adding ## 31 while holding 30 is refused"
printf '\n## 31 Gamma\n' >> docs/systems/b.md; git add -A; expect_refuse git commit -qm e2; undo

msg="R6: adding ## 30 (held) is accepted"
printf '\n## 30 Delta\n' >> docs/systems/b.md; git add -A; expect_pass git commit -qm e3

msg="R7: WORKAROUND: in Markdown is accepted"
printf 'quote WORKAROUND: here\n' >> docs/systems/b.md; git add -A; expect_pass git commit -qm md

msg="R7: WORKAROUND: in code without a ledger row is refused"
printf '# WORKAROUND: x\n' >> src/a.py; git add -A; expect_refuse git commit -qm py; undo

msg="sync: a conflicted merge of trunk can be committed"
( cd "$T" && printf 'x=2\n' > src/a.py && git add -A && git commit -qm trunk1 )
printf 'x=3\n' > src/a.py; git add -A; git commit -qm lane1
$J sync >/dev/null 2>&1
printf 'x=23\n' > src/a.py; git add -A; expect_pass git commit -qm merge1

msg="R3: an out-of-bounds edit during a merge is still refused"
( cd "$T" && printf 'y\n' > other.txt && printf 'x=100\n' > src/a.py && git add -A && git commit -qm trunk2 )
printf 'x=99\n' > src/a.py; git add -A; git commit -qm lane2
$J sync >/dev/null 2>&1
( cd "$T" && printf 'q\n' > q.txt && git add -A && git commit -qm trunk3 )   # trunk moves on mid-merge
printf 'x=1\n' > src/a.py; printf 'z\n' > other.txt; git add -A; expect_refuse git commit -qm bad
git checkout -q MERGE_HEAD -- other.txt; git add -A
msg="sync: the same merge commits once the stray edit is dropped"
expect_pass git commit -qm merge2

msg="sync: a clean merge commits automatically through pre-merge-commit"
( cd "$T" && printf 'w\n' > w.txt && git add -A && git commit -qm trunk4 )
$J sync >/dev/null 2>&1; expect_pass git log -1 --format=%s --grep="Merge branch 'main'"

msg="review marker is per branch"
$J reviewed >/dev/null; expect_pass test -f "$T/.git/jig/reviewed/L1"

msg="gate does not refuse a lane behind trunk"
( cd "$T" && printf 'r\n' > r.txt && git add -A && git commit -qm trunk5 )
out=$(cd "$T" && $J gate L1 2>&1); if echo "$out" | grep -q behind; then bad "$msg"; else ok "$msg"; fi

S="$T/survey"
mkdir -p "$S" && cd "$S" && git init -q -b main && git config user.email t@t && git config user.name t
mkdir -p .jig src/widgets plugin/skills/x
cp "$P/jig/jig.py" .jig/
printf '# W\n' > src/widgets/README.md && printf '# X\n' > plugin/skills/x/SKILL.md
git add -A && git commit -qm init && $J init --no-hooks >/dev/null

msg="init: a new board has an empty payload"
expect_pass python3 -c "import json,sys; sys.exit(json.load(open('.jig/lanes.json'))['payload'] != [])"

msg="payload: survey skips declared globs, still flags the stray README"
python3 - <<'EOF'
import json; b = json.load(open('.jig/lanes.json'))
b['payload'] = ['plugin/**']
json.dump(b, open('.jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board   # survey reads trunk's board, not the working tree
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
homeless = [e['path'] for e in r['homeless']]
assert r['payload'] == ['plugin/**'], r['payload']
assert 'src/widgets/README.md' in homeless and 'plugin/skills/x/SKILL.md' not in homeless, homeless
assert r['payload_unmatched'] == [], r['payload_unmatched']"

msg="payload: a directory-style glob that matches nothing is named"
python3 - <<'EOF'
import json; b = json.load(open('.jig/lanes.json'))
b['payload'] = ['plugin/']
json.dump(b, open('.jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board2
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['payload_unmatched'] == ['plugin/'], r['payload_unmatched']"

rm -rf "$T"
exit $fail
