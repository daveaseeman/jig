#!/usr/bin/env bash
# End-to-end check of the rules in a throwaway repo: one lane in a worktree, the hooks
# installed from the template. Every case prints PASS or the refusal it expected.
set -u
T=$(mktemp -d "${TMPDIR:-/tmp}/jig-smoke.XXXXXX")
P="$(cd "$(dirname "$0")/.." && pwd)/plugin/templates"
J="python3 jig/jig.py"
fail=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=1; }
expect_pass() { if "$@" >/dev/null 2>&1; then ok "$msg"; else bad "$msg"; fi; }
expect_refuse() { if "$@" >/dev/null 2>&1; then bad "$msg (was accepted)"; else ok "$msg"; fi; }
undo() { git reset -q; git checkout -q -- .; git clean -fdq; }

cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && chmod +x jig/scripts/*.sh
mkdir -p docs/systems src
printf 'x=1\n' > src/a.py
printf '# A\n\n## 28 Alpha\ntext\n\n## 29 Beta\ntext\n' > docs/systems/a.md
git add -A && git commit -qm init
$J init >/dev/null
python3 - <<'EOF'
import json; b = json.load(open('jig/lanes.json'))
b['reserve'] = {'section': {'next': 29, 'pattern': r'^## (\d+) ', 'files': ['docs/systems/**']}}
json.dump(b, open('jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board
$J open L1 --brief t --owns 'src/**' 'docs/systems/**' --reserve section >/dev/null
git add -A && git commit -qm "open L1"
cd .git/jig/worktrees/L1

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

msg="fold-in: a change to jig/jig.py is the tool's, not unowned code"
printf '# lane edit\n' >> jig/jig.py; printf 'x=7\n' > src/a.py; git add -A; git commit -qm tool
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1
note=$(cat jig/handoffs/L1-*.md 2>/dev/null)
if echo "$note" | grep -q 'UNOWNED src/a.py' && ! echo "$note" | grep -q 'UNOWNED jig/jig.py'
then ok "$msg"; else bad "$msg"; fi

I="$T/init"
mkdir -p "$I" && cd "$I" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" .
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="init: root holds only AGENTS.md, CLAUDE.md and jig/"
expect_pass test "$(ls -A | grep -v '^\.git$' | tr '\n' ' ')" = "AGENTS.md CLAUDE.md jig "

msg="init: the repo's docs/ is common on a new board"
expect_pass python3 -c "import json,sys; sys.exit('docs/**' not in json.load(open('jig/lanes.json'))['common'])"

msg="open: a lane's worktree lives in .git/jig/worktrees and trunk stays clean"
$J open L2 --brief t --owns 'docs/**' >/dev/null && git add -A && git commit -qm "open L2"
expect_pass test -d .git/jig/worktrees/L2 -a -z "$(git status --porcelain)"

msg="survey: a fresh init has no homeless files and no source counted from jig/"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', 'jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [] and r['src_count'] == 0, (r['homeless'], r['src_count'])"

msg="survey: lists docs/ and jig/ as homes"
homes=$(python3 jig/jig.py survey | grep '^Homes: ')
expect_pass test -n "$(echo "$homes" | grep -F '; docs/ = ')" -a -n "$(echo "$homes" | grep -F '; jig/ = ')"

H="$T/hardware"
mkdir -p "$H" && cd "$H" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs/hardware docs/systems main
printf '# Devkit\n' > docs/hardware/devkit.md && printf '# GPIO\n' > docs/systems/gpio.md
printf 'int led = 48;\n' > main/app.c && printf 'CONFIG_ESPTOOLPY_FLASHSIZE_8MB=y\n' > sdkconfig
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="survey: names a board page no docmap entry covers"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', 'jig/jig.py', 'survey', '--json']))
assert r['boards_unmapped'] == ['docs/hardware/devkit.md'], r['boards_unmapped']"

# The system page comes first, so a docmap that stops at the first match hides the board page.
python3 - <<'EOF'
import json; b = json.load(open('jig/lanes.json'))
b['docmap'] = {'docs/systems/gpio.md': ['main/**'],
               'docs/hardware/devkit.md': ['main/**', 'sdkconfig*']}
json.dump(b, open('jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm docmap
msg="survey: a board page docmap names is not listed"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', 'jig/jig.py', 'survey', '--json']))
assert r['boards_unmapped'] == [], r['boards_unmapped']"

msg="reading-list: a file covered by a system page and a board page lists both"
out=$($J reading-list main/app.c)
expect_pass test -n "$(echo "$out" | grep -F docs/systems/gpio.md)" -a -n "$(echo "$out" | grep -F docs/hardware/devkit.md)"

$J open H1 --brief t --owns 'main/**' >/dev/null && $J open H2 --brief t --owns 'sdkconfig*' >/dev/null
git add -A && git commit -qm "open H1 H2"
cd .git/jig/worktrees/H1 && printf 'int led = 2;\n' > main/app.c && git add -A && git commit -qm led
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1; git add -A && git commit -qm note
msg="fold-in: changing a board's code asks about its board page and its system page"
expect_pass sh -c "grep -q -- '- \[ \] docs/hardware/devkit.md' jig/handoffs/H1-*.md && grep -q -- '- \[ \] docs/systems/gpio.md' jig/handoffs/H1-*.md"
sed -i.bak 's|- \[ \] docs/systems/gpio.md — updated / no change because ___|- [x] docs/systems/gpio.md — no change because the pin is board wiring|' jig/handoffs/H1-*.md
rm -f jig/handoffs/*.bak && git add -A && git commit -qm "answer gpio"
msg="gate: refuses while the board page's fold-in line is unanswered"
expect_refuse sh -c "cd '$H' && $J gate H1"
sed -i.bak 's|- \[ \] docs/hardware/devkit.md — updated / no change because ___|- [x] docs/hardware/devkit.md — updated: LED on GPIO 2|' jig/handoffs/H1-*.md
rm -f jig/handoffs/*.bak && git add -A && git commit -qm "answer devkit"
msg="gate: passes once the board page's line is answered"
expect_pass sh -c "cd '$H' && $J gate H1"

cd "$H/.git/jig/worktrees/H2" && printf 'CONFIG_ESPTOOLPY_FLASHSIZE_16MB=y\n' > sdkconfig && git add -A && git commit -qm flash
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1
msg="fold-in: changing only a board's config file asks about its board page"
expect_pass grep -q -- '- \[ \] docs/hardware/devkit.md' jig/handoffs/H2-*.md

S="$T/survey"
mkdir -p "$S" && cd "$S" && git init -q -b main && git config user.email t@t && git config user.name t
mkdir -p jig src/widgets plugin/skills/x
cp "$P/jig/jig.py" jig/
printf '# W\n' > src/widgets/README.md && printf '# X\n' > plugin/skills/x/SKILL.md
git add -A && git commit -qm init && $J init --no-hooks >/dev/null

msg="init: a new board has an empty payload"
expect_pass python3 -c "import json,sys; sys.exit(json.load(open('jig/lanes.json'))['payload'] != [])"

msg="payload: survey skips declared globs, still flags the stray README"
python3 - <<'EOF'
import json; b = json.load(open('jig/lanes.json'))
b['payload'] = ['plugin/**']
json.dump(b, open('jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board   # survey reads trunk's board, not the working tree
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', 'jig/jig.py', 'survey', '--json']))
homeless = [e['path'] for e in r['homeless']]
assert r['payload'] == ['plugin/**'], r['payload']
assert 'src/widgets/README.md' in homeless and 'plugin/skills/x/SKILL.md' not in homeless, homeless
assert r['payload_unmatched'] == [], r['payload_unmatched']"

msg="payload: a directory-style glob that matches nothing is named"
python3 - <<'EOF'
import json; b = json.load(open('jig/lanes.json'))
b['payload'] = ['plugin/']
json.dump(b, open('jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board2
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', 'jig/jig.py', 'survey', '--json']))
assert r['payload_unmatched'] == ['plugin/'], r['payload_unmatched']"

rm -rf "$T"
exit $fail
