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
mkdir -p docs/alpha src
printf 'x=1\n' > src/a.py
printf '# A\n\n## 28 Alpha\ntext\n\n## 29 Beta\ntext\n' > docs/alpha/alpha.md
git add -A && git commit -qm init
$J init >/dev/null
python3 - <<'EOF'
import json; b = json.load(open('jig/lanes.json'))
b['reserve'] = {'section': {'next': 29, 'pattern': r'^## (\d+) ', 'files': ['docs/**']}}
json.dump(b, open('jig/lanes.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board
$J open L1 --brief t --owns 'src/**' 'docs/**' --reserve section >/dev/null
git add -A && git commit -qm "open L1"
cd .git/jig/worktrees/L1

msg="R6: editing an existing heading's text takes nothing"
sed -i.bak 's/## 29 Beta/## 29 Beta renamed/' docs/alpha/alpha.md && rm docs/alpha/alpha.md.bak
git add -A; expect_pass git commit -qm e1

msg="R6: moving a page takes nothing"
mkdir -p docs/beta && git mv docs/alpha/alpha.md docs/beta/beta.md; expect_pass git commit -qm mv

msg="R6: adding ## 31 while holding 30 is refused"
printf '\n## 31 Gamma\n' >> docs/beta/beta.md; git add -A; expect_refuse git commit -qm e2; undo

msg="R6: adding ## 30 (held) is accepted"
printf '\n## 30 Delta\n' >> docs/beta/beta.md; git add -A; expect_pass git commit -qm e3

msg="R7: WORKAROUND: in Markdown is accepted"
printf 'quote WORKAROUND: here\n' >> docs/beta/beta.md; git add -A; expect_pass git commit -qm md

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
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs/hardware docs/gpio main
printf '# Devkit\n' > docs/hardware/devkit.md && printf '# GPIO\n' > docs/gpio/gpio.md
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
b['docmap'] = {'docs/gpio/gpio.md': ['main/**'],
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
expect_pass test -n "$(echo "$out" | grep -F docs/gpio/gpio.md)" -a -n "$(echo "$out" | grep -F docs/hardware/devkit.md)"

$J open H1 --brief t --owns 'main/**' >/dev/null && $J open H2 --brief t --owns 'sdkconfig*' >/dev/null
git add -A && git commit -qm "open H1 H2"
cd .git/jig/worktrees/H1 && printf 'int led = 2;\n' > main/app.c && git add -A && git commit -qm led
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1; git add -A && git commit -qm note
msg="fold-in: changing a board's code asks about its board page and its system page"
expect_pass sh -c "grep -q -- '- \[ \] docs/hardware/devkit.md' jig/handoffs/H1-*.md && grep -q -- '- \[ \] docs/gpio/gpio.md' jig/handoffs/H1-*.md"
sed -i.bak 's|- \[ \] docs/gpio/gpio.md — updated / no change because ___|- [x] docs/gpio/gpio.md — no change because the pin is board wiring|' jig/handoffs/H1-*.md
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


# ---------------------------------------------------------------- update
# Old layouts are rebuilt from this repo's own history, so the smoke test needs a full clone.
R="$(cd "$(dirname "$P")/.." && pwd)"
UP="python3 $P/jig/jig.py update"     # the plugin's copy, as the update skill runs it
code() { "$@" >/dev/null 2>&1; echo $?; }
snap() { git status --porcelain; find .git -type f | sort | xargs shasum 2>/dev/null; }

# old <dir> <commit> <style>: a repo set up the way that commit's init skill says, with a
# reserve counter on docs/**, a docmap page, a merged lane, and a script of the repo's own.
old() {
  d=$1; c=$2; style=$3
  mkdir -p "$d/.t" && git -C "$R" archive "$c" plugin/templates | tar -x -C "$d/.t"
  cd "$d" && git init -q -b main && git config user.email t@t && git config user.name t
  t=.t/plugin/templates
  printf '*.log\n' > .gitignore
  mkdir -p src scripts && printf 'x=1\n' > src/a.py && printf 'echo build\n' > scripts/build.sh
  if [ "$style" = jig ]; then
    cp $t/AGENTS.md $t/CLAUDE.md . && cp -r $t/jig jig && rm jig/docs/HARDWARE.md
    tool=jig; docs=jig/docs; specs=jig/specs
  else
    cp $t/AGENTS.md $t/CLAUDE.md . && cp -r $t/ledgers . && mkdir -p docs specs .jig
    cp $t/docs/README.md docs/ && cp $t/specs/_template.md specs/
    cp $t/scripts/check.sh $t/scripts/format.sh scripts/ && cp $t/jig/jig.py $t/jig/RULES.md .jig/
    tool=.jig; docs=docs; specs=specs
  fi
  rm -rf .t && chmod +x scripts/*.sh $tool/scripts/*.sh 2>/dev/null
  mkdir -p $docs/alpha && printf '# Alpha\n\n## 1 One\n' > $docs/alpha/alpha.md
  git add -A && git commit -qm init && python3 $tool/jig.py init >/dev/null
  python3 - "$tool" "$docs" "$specs" <<'EOF'
import json, sys
tool, docs, specs = sys.argv[1:]
b = json.load(open(f'{tool}/lanes.json'))
b['reserve'] = {'section': {'next': 1, 'pattern': r'^## (\d+) ', 'files': [f'{docs}/**']}}
b['docmap'] = {f'{docs}/alpha/alpha.md': ['src/**']}
b['lanes'] = {'old': {'branch': 'old', 'state': 'merged', 'worktree': f'{tool}/worktrees/old',
                      'owns': ['scripts/**', 'src/**'], 'shares': [f'{specs}/**']}}
json.dump(b, open(f'{tool}/lanes.json', 'w'), indent=2)
EOF
  if [ "$style" = aidev ]; then       # ai-dev: jig under its old name, the ledgers at root
    git mv .jig .aidev && git mv .aidev/jig.py .aidev/aidev.py
    git mv ledgers/WORKAROUNDS.md WORKAROUNDS.md && git mv ledgers/DEFERRED.md DEFERRED.md
    sed -i.bak -e 's|\.jig/|.aidev/|g' -e 's|"ledgers/\*\*"|"WORKAROUNDS.md", "DEFERRED.md"|g' \
      .aidev/lanes.json && rm .aidev/lanes.json.bak
    sed -i.bak 's|^\.jig/worktrees/$|.aidev/worktrees/|' .gitignore && rm .gitignore.bak
    for h in pre-commit pre-merge-commit pre-push post-checkout; do
      sed -i.bak -e 's|# jig hook|# aidev hook|' -e 's|\.jig/jig\.py|.aidev/aidev.py|' .git/hooks/$h
      rm .git/hooks/$h.bak
    done
    mv .git/jig .git/aidev
  fi
  git add -A && git commit -qm board
}

# Every glob that matched a tracked file before still matches one after; a glob that matches
# nothing now matched nothing before (CHANGELOG.md). scripts/** keeps meaning the repo's scripts.
GLOBS='
import importlib.util, json, subprocess, sys
spec = importlib.util.spec_from_file_location("j", sys.argv[1]); j = importlib.util.module_from_spec(spec); spec.loader.exec_module(j)
old = json.loads(subprocess.check_output(["git", "show", "HEAD:" + sys.argv[2]]))
new = json.load(open("jig/lanes.json"))
before = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", "HEAD"], text=True).split()
after = subprocess.check_output(["git", "ls-files"], text=True).split()
def lists(b):
    out = [b.get(k) or [] for k in ("common", "append_files", "payload")]
    out += [v.get("files") or [] for v in (b.get("reserve") or {}).values()]
    out += [list(b.get("docmap", {}))] + list(b.get("docmap", {}).values())
    out += [l.get(k) or [] for l in b.get("lanes", {}).values() for k in ("owns", "shares")]
    return out
dead_before = {g for l in lists(old) for g in l if not any(j.matches(f, [g]) for f in before)}
for l in lists(new):
    for g in l:
        assert any(j.matches(f, [g]) for f in after) or g in dead_before, g
# A folder that moved out from under a broad glob is still covered (jig/** held jig/docs/).
moved = [l.split("\t")[1:] for l in subprocess.check_output(["git", "diff", "--cached", "-M", "--name-status"], text=True).splitlines() if l.startswith("R100")]
for o, n in moved:
    if o.startswith(("jig/docs/", "specs/", "ledgers/", ".jig/handoffs/", ".aidev/handoffs/")):
        for lo, ln in zip(lists(old), lists(new)):
            assert not j.matches(o, lo) or j.matches(n, ln), (o, n, ln)
lane = new["lanes"]["old"]
assert "scripts/**" in lane["owns"] and lane["worktree"] == old["lanes"]["old"]["worktree"], lane
'

for layout in "eaec973 dot" "66a044c dot" "62c8d9f jig" "eaec973 aidev"; do
  set -- $layout; c=$1; style=$2; name="$c-$style"
  old "$T/up-$name" $c $style
  board=$(git ls-files | grep 'lanes.json$')

  msg="update $name: the dry run changes nothing and exits 0"
  before=$(snap); rc=$(code $UP); after=$(snap)
  expect_pass test "$rc" = 0 -a "$before" = "$after"

  msg="update $name: the dry run lists the moves, board edits and stale references"
  out=$($UP 2>&1)
  expect_pass sh -c "echo \"\$0\" | grep -q '^Moves' && echo \"\$0\" | grep -q '^Board:' && echo \"\$0\" | grep -q '^Stale references'" "$out"

  msg="update $name: --apply renames the repo's files, never edits them"
  $UP --apply >/dev/null 2>&1
  expect_pass python3 -c "
import subprocess
allowed = {'$board', 'jig/lanes.json', '.jig/jig.py', '.aidev/aidev.py', 'jig/jig.py',
           '.jig/RULES.md', '.aidev/RULES.md', 'jig/RULES.md', '.gitignore', 'jig/scripts/setup.sh'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or set(paths) <= allowed, line"

  msg="update $name: every board glob that matched before still matches"
  expect_pass python3 -c "$GLOBS" "$P/jig/jig.py" "$board"

  msg="update $name: hooks read trunk's jig/jig.py and none was kept as .local; .git/jig/enabled, no .git/aidev, no old ignore line"
  expect_pass sh -c "grep -q 'git show main:jig/jig.py' .git/hooks/pre-commit && ! ls .git/hooks/*.local && test -f .git/jig/enabled && test ! -e .git/aidev && ! grep -q worktrees .gitignore"

  msg="update $name: a repo without setup.sh gets the template's, staged, and the post-merge hook"
  expect_pass sh -c "cmp -s jig/scripts/setup.sh '$P/jig/scripts/setup.sh' && test -x jig/scripts/setup.sh && git diff --cached --name-status | grep -q '^A.jig/scripts/setup.sh' && grep -q 'hook post-merge' .git/hooks/post-merge"

  git ls-files > "$T/$name.paths"
  python3 -c "import json; print(sorted(json.load(open('jig/lanes.json'))))" > "$T/$name.keys"

  msg="update $name: a second --apply is up to date and changes nothing"
  before=$(git status --porcelain); out=$($UP --apply 2>&1); after=$(git status --porcelain)
  expect_pass test "$out" = "up to date" -a "$before" = "$after"

  msg="update $name: after the commit, survey finds no homeless files"
  git commit -qm update
  expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', 'jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [], r['homeless']"
done

msg="update: all four old layouts end with the same tracked paths and board keys"
expect_pass sh -c "cd '$T' && for n in 66a044c-dot 62c8d9f-jig eaec973-aidev; do cmp -s eaec973-dot.paths \$n.paths && cmp -s eaec973-dot.keys \$n.keys || exit 1; done"

msg="update: same stamp, different jig.py and RULES.md: both replaced, hooks rewritten, nothing moves, the repo's setup.sh kept byte for byte"
cd "$T/up-eaec973-dot"
printf '# local edit\n' >> jig/jig.py && printf 'local edit\n' >> jig/RULES.md && printf 'uv sync\n' >> jig/scripts/setup.sh
git commit -qam edit && cp jig/scripts/setup.sh "$T/setup.mine"
rm .git/hooks/pre-push
$UP --apply >/dev/null 2>&1
expect_pass sh -c "test \"\$(git diff --cached --name-status | sort)\" = \"\$(printf 'M\tjig/RULES.md\nM\tjig/jig.py')\" && test -f .git/hooks/pre-push && cmp -s jig/scripts/setup.sh '$T/setup.mine'"
git commit -qm tools

msg="update: once the board is in jig/, a root specs/ and scripts/check.sh are the repo's own"
mkdir -p specs && printf '# spec\n' > specs/api.md && printf 'echo mine\n' > scripts/check.sh
git add -A && git commit -qm own
expect_pass test "$($UP 2>&1)" = "up to date"
git reset -q --hard HEAD~1

msg="update: a board stamped above this jig refuses"
python3 -c "import json; b = json.load(open('jig/lanes.json')); b['version'] = 99; json.dump(b, open('jig/lanes.json', 'w'))"
git commit -qam ahead
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'repo is ahead; update the plugin'" "$out"
git reset -q --hard HEAD~1

msg="update: an up-to-date repo says so even with a worktree open"
git worktree add -q --detach "$T/up-extra0" HEAD 2>/dev/null
expect_pass test "$($UP 2>&1)" = "up to date"
git worktree remove --force "$T/up-extra0"
printf '# behind\n' >> jig/jig.py && git commit -qam behind   # the refusals below need a plan

msg="update: an open lane refuses, naming it"
python3 -c "import json; b = json.load(open('jig/lanes.json')); b['lanes']['live'] = {'state': 'building'}; json.dump(b, open('jig/lanes.json', 'w'))"
git commit -qam live
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'lanes are open: live'" "$out"
git reset -q --hard HEAD~1

msg="update: a worktree besides the main checkout refuses, naming it"
git worktree add -q --detach "$T/up-extra" HEAD
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'up-extra' && echo \"\$0\" | grep -q 'git worktree prune'" "$out"
git worktree remove "$T/up-extra"

msg="update: --apply refuses with tracked changes, and changes nothing"
printf 'x\n' >> AGENTS.md
before=$(snap); rc=$(code $UP --apply); after=$(snap)
expect_pass test "$rc" = 2 -a "$before" = "$after"
git checkout -q -- AGENTS.md

msg="update blocked: two boards are both named, and --apply changes nothing"
mkdir -p .jig && cp jig/lanes.json .jig/lanes.json && git add -A && git commit -qm two
before=$(snap); out=$($UP --apply 2>&1); rc=$?; after=$(snap)
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'two boards, jig/lanes.json and .jig/lanes.json' && test \"\$1\" = \"\$2\"" "$out" "$before" "$after"

msg="update blocked: no board names the board-like JSON and the foreign hooks"
N="$T/up-none"; mkdir -p "$N/.other" && cd "$N" && git init -q -b main
printf '{"lanes": {}}\n' > .other/lanes.json && git add -A && git -c user.email=t@t -c user.name=t commit -qm init
printf '#!/bin/sh\nexit 0\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'board-like JSON: .other/lanes.json' && echo \"\$0\" | grep -q \"a hook jig didn't write: pre-commit\"" "$out"

old "$T/up-warn" eaec973 dot
printf 'notes\n' > .jig/notes.txt && mkdir -p tools && printf 'BOARD = ".jig/lanes.json"\n' > tools/paths.py
mkdir -p jig/specs && printf '# new\n' > jig/specs/new.md
python3 -c "import json; b = json.load(open('.jig/lanes.json')); b['extra'] = 1; json.dump(b, open('.jig/lanes.json', 'w'))"
git add -A && git commit -qm warn
out=$($UP 2>&1); rc=$?
msg="update warning: an extra file in .jig/ is named, and the dry run exits 1"
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q '.jig/notes.txt is at an old path'" "$out"
msg="update warning: a board key jig doesn't know is named"
expect_pass sh -c "echo \"\$0\" | grep -q 'board key .extra. is not one jig knows'" "$out"
msg="update warning: a .py file that names .jig/lanes.json is named, with its line"
expect_pass sh -c "echo \"\$0\" | grep -q 'tools/paths.py names a path jig moved' && echo \"\$0\" | grep -q '1: BOARD = \".jig/lanes.json\"'" "$out"
msg="update warning: specs/ and jig/specs/ both exist, so neither moves"
expect_pass sh -c "echo \"\$0\" | grep -q 'specs/ and jig/specs/ both exist'" "$out"
msg="update warning: --apply proceeds; the extra file, .jig/, both specs folders and the unknown key stay"
rc=$(code $UP --apply)
expect_pass sh -c "test $rc = 0 && test -f .jig/notes.txt && test -f specs/_template.md && test -f jig/specs/new.md && grep -q '\"extra\"' jig/lanes.json"


# Firmware, as eaec973's init set it up: docs/HARDWARE.md and the blank skill template.
old "$T/up-fw" eaec973 dot
mkdir -p .claude/skills/_skill-template
git -C "$R" show eaec973:plugin/templates/docs/HARDWARE.md > docs/HARDWARE.md
git -C "$R" show eaec973:plugin/templates/skill-template/SKILL.md > .claude/skills/_skill-template/SKILL.md
printf '#!/bin/sh\nexit 2\n' > scripts/check.sh && git add -A && git commit -qm fw
out=$($UP 2>&1)
msg="update: the dry run lists docs/HARDWARE.md and the old skill template as repo files to review"
expect_pass sh -c "echo \"\$0\" | grep -q '^Repo files to review' && echo \"\$0\" | grep -q \"docs/HARDWARE.md: still the template's TODOs: remove it\" && echo \"\$0\" | grep -q '.claude/skills/_skill-template/: the old blank skill template, unchanged: remove it'" "$out"
msg="update: the dry run shows AGENTS.md against the template"
expect_pass sh -c "echo \"\$0\" | grep -q '^AGENTS.md against the template:' && echo \"\$0\" | grep -q '^  +++ AGENTS.md'" "$out"
msg="update: a HARDWARE.md that holds a board is proposed as docs/hardware/<board>.md"
sed -i.bak 's/^- MCU \/ board: TODO.*/- MCU \/ board: ESP32-S3-DevKitC-1 (N16R8)/' docs/HARDWARE.md && rm docs/HARDWARE.md.bak
git commit -qam board-page
expect_pass sh -c "$UP 2>&1 | grep -q 'rename it to docs/hardware/esp32-s3-devkitc-1.md'"
msg="update: --apply leaves the files to review alone; a failing check is reported, exits 1, undoes nothing"
out=$($UP --apply 2>&1); rc=$?
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q 'jig/scripts/check.sh FAILED (exit 2)' && test -f docs/HARDWARE.md && test -f .claude/skills/_skill-template/SKILL.md && git diff --cached --name-status | grep -q 'R100.*jig/specs/_template.md'" "$out"

cd "$T/up-warn" && git commit -qm applied
msg="update: after --apply, a kept warning still reads up to date, exit 0"
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | head -1 | grep -qx 'up to date'" "$out"

msg="update: a root specs/ file that isn't Markdown stays, with a warning"
old "$T/up-js" eaec973 dot
printf 'it()\n' > specs/app.spec.js && git add -A && git commit -qm js
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'specs/app.spec.js is in specs/ but isn.t Markdown' && ! echo \"\$0\" | grep -q 'app.spec.js → '" "$out"

# ---------------------------------------------------------------- worktree setup
W="$T/setup"; LOG="$T/setup.log"
mkdir -p "$W" && cd "$W" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p src && printf 'x=1\n' > src/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="setup: after init, jig/scripts/setup.sh is executable, all TODOs, and exits 0"
expect_pass sh -c "test -x jig/scripts/setup.sh && grep -q TODO jig/scripts/setup.sh && jig/scripts/setup.sh"

printf '#!/bin/sh\necho "set up $(pwd -P)"\npwd -P >> "%s"\n' "$LOG" > jig/scripts/setup.sh
git commit -qam "setup logs" && : > "$LOG"
lines() { wc -l < "$LOG" | tr -d ' '; }

msg="setup: a plain git worktree add --detach sets the new worktree up once"
git worktree add -q --detach "$T/setup-plain" HEAD 2>/dev/null
expect_pass test "$(lines)" = 1 -a "$(tail -1 "$LOG")" = "$(cd "$T/setup-plain" && pwd -P)"

msg="setup: git switch in an existing checkout runs nothing"
(cd "$T/setup-plain" && git switch -q -c side 2>/dev/null)
expect_pass test "$(lines)" = 1

msg="setup: a fast-forward merge sets up the checkout that merged, once"
(cd "$T/setup-plain" && printf 'y=1\n' > src/b.py && git add -A && git commit -qm b)
git merge -q --ff-only side 2>/dev/null
expect_pass test "$(lines)" = 2 -a "$(tail -1 "$LOG")" = "$(pwd -P)"

msg="setup: a true merge sets it up once; already up to date runs nothing"
(cd "$T/setup-plain" && printf 'z=1\n' > src/c.py && git add -A && git commit -qm c)
printf 'w=1\n' > src/d.py && git add -A && git commit -qm d
git merge -q --no-edit side 2>/dev/null; n=$(lines)
git merge -q side 2>/dev/null
expect_pass test "$n" = 3 -a "$(lines)" = 3
git worktree remove --force "$T/setup-plain"

msg="setup: jig open sets the lane's worktree up once, and its stderr shows setup's output"
err=$($J open S1 --owns 'src/**' 2>&1 >/dev/null); git add -A && git commit -qm "open S1"
expect_pass sh -c "test $(lines) = 4 && echo \"\$0\" | grep -q 'set up .*S1'" "$err"

msg="setup: jig sync that resolves an append conflict itself sets the lane up once"
printf '\n- trunk line\n' >> AGENTS.md && git commit -qam trunk-append
(cd .git/jig/worktrees/S1 && printf '\n- lane line\n' >> AGENTS.md && git commit -qam lane-append && $J sync >/dev/null 2>&1)
expect_pass test "$(lines)" = 5 -a "$(tail -1 "$LOG")" = "$(cd .git/jig/worktrees/S1 && pwd -P)"

printf '#!/bin/sh\necho broken >&2\nexit 1\n' > jig/scripts/setup.sh && git commit -qam "setup fails"
msg="setup: a failing setup.sh fails nothing; jig open exits 0 and stderr names the script, code and checkout"
err=$($J open S2 --owns 'docs/**' 2>&1 >/dev/null); rc=$?
expect_pass sh -c "test $rc = 0 && test -d .git/jig/worktrees/S2 && grep -q '\"S2\"' jig/lanes.json && echo \"\$0\" | grep -q 'jig/scripts/setup.sh exited 1 in .*S2'" "$err"
git add -A && git commit -qm "open S2"

msg="setup: a failing setup.sh fails nothing for a plain git worktree add either"
expect_pass git worktree add -q --detach "$T/setup-fail" HEAD

msg="setup: a checkout with no setup.sh (a commit from before it) runs nothing and prints nothing extra"
git worktree add -q --detach "$T/setup-mk" HEAD 2>/dev/null
before_none=$(cd "$T/setup-mk" && git rm -q jig/scripts/setup.sh && git commit -qm "no setup" && git rev-parse HEAD)
n=$(lines); err=$(git worktree add -q --detach "$T/setup-none" "$before_none" 2>&1)
expect_pass sh -c "test -z \"\$0\" && test $n = \$(wc -l < '$LOG' | tr -d ' ') && test ! -e '$T/setup-none/jig/scripts/setup.sh'" "$err"

# ---------------------------------------------------------------- metarepo
M="$T/meta"; mkdir -p "$M" && cd "$M" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init >/dev/null && $J meta-init --name docs >/dev/null && git add -A && git commit -qm "meta-init"
mrel() { $J meta-release 2>&1; }
branch_commit() {  # branch_commit <branch> <subject>: commit what's staged on a new branch
  git switch -q -c "$1" && git commit -qm "$2"; }

msg="meta: meta-init then meta-release tags v0.1"
expect_pass sh -c "$J meta-release && git tag | grep -qx v0.1 && grep -q '^## v0.1 — ' CHANGELOG.md"
msg="meta: a second meta-release with no entry-file change says nothing to release"
out=$(mrel); expect_pass sh -c "echo \"\$0\" | grep -q 'nothing to release'" "$out"

git switch -q -c b1
msg="meta M1: a source file outside jig/ is refused"
printf 'x=1\n' > tool.py && git add tool.py; expect_refuse git commit -qm "D-001: tool"; git rm -q --cached tool.py; rm tool.py
msg="meta: a change to jig/jig.py is accepted"
printf '\n' >> jig/jig.py && git add jig/jig.py; expect_pass git commit -qm "TOOL: jig"
msg="meta M2: a decision row without status and date is refused"
printf '| D-001 | use JSON |\n' >> DECISIONS.md && printf -- '- D-001\n' >> CHANGELOG.md && git add -A
expect_refuse git commit -qm "D-001: JSON"; git reset -q; git checkout -q -- DECISIONS.md CHANGELOG.md
msg="meta M3: an entry file changed without CHANGELOG.md is refused"
printf '| D-001 | use JSON | accepted | 2026-10-29 |\n' >> DECISIONS.md && git add -A
expect_refuse git commit -qm "D-001: JSON"
msg="meta M6: a subject without an id prefix is refused"
printf -- '- D-001 JSON\n' >> CHANGELOG.md && git add -A
expect_refuse git commit -qm "use json"
msg="meta: an id-prefixed decision with status, date and changelog is accepted"
expect_pass git commit -qm "D-001: config is JSON"
git switch -q main

msg="meta M4: a direct commit on main is refused"
printf '\n## mote\n' >> GLOSSARY.md && printf -- '- mote\n' >> CHANGELOG.md && git add -A
expect_refuse git commit -qm "GLOSSARY: mote"; git reset -q --hard

msg="meta M5: a --no-ff merge of an unreviewed branch is refused"
expect_refuse git merge -q --no-ff --no-edit b1; git merge --abort 2>/dev/null
msg="meta: the same merge once the branch is reviewed is accepted"
git switch -q b1 && $J reviewed >/dev/null && git switch -q main
expect_pass git merge -q --no-ff --no-edit b1
msg="meta: a git pull of a reviewed branch into main is accepted"
git switch -q -c b3 && printf '\n## seam\n' >> GLOSSARY.md && printf -- '- seam\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: seam" && $J reviewed >/dev/null && git switch -q main
expect_pass git pull -q --no-ff --no-edit . b3

msg="meta: meta-release tags v0.2"
expect_pass sh -c "$J meta-release && git tag | grep -qx v0.2"

git switch -q -c b2 && printf '\n## grain\n' >> GLOSSARY.md && printf -- '- grain\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: grain" && git switch -q main
git merge -q --ff-only b2
git init -q --bare "$T/meta-remote.git" && git remote add origin "$T/meta-remote.git"
msg="meta: a fast-forward of an unreviewed branch: meta-release refuses, naming the commit"
out=$(mrel); c=$(git rev-parse --short=12 HEAD)
expect_pass sh -c "echo \"\$0\" | grep -q '$c is on main without a reviewed merge'" "$out"
msg="meta: and pre-push refuses it"
expect_refuse git push -q origin main
git reset -q --hard v0.2

msg="meta: a tag made by hand fails the next meta-release and pre-push, naming it"
git tag v0.3
out=$(mrel)
expect_pass sh -c "echo \"\$0\" | grep -q 'tag v0.3 was not made by meta-release' && ! git push -q origin main 2>/dev/null" "$out"
git tag -d v0.3 >/dev/null

# ---------------------------------------------------------------- pararepo
export JIG_CONFIG="$T/repos.json"     # never the user's real list
MR="$T/mr"; mkdir -p "$MR" && cd "$MR" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init >/dev/null && $J meta-init --name docs >/dev/null && git add -A && git commit -qm meta-init && $J meta-release >/dev/null
PR="$T/pr"; mkdir -p "$PR" && cd "$PR" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
git clone -q "$MR" mrclone

msg="para: para-init writes para.json, the AGENTS.md header, the cache, and ignores the cache"
$J para-init --meta docs --location mrclone --contract 'api/**' >/dev/null
expect_pass sh -c "grep -q '\"pin\": \"v0.1\"' jig/para.json && ! grep -q location jig/para.json && grep -q '\"docs\"' '$T/repos.json' && grep -q 'jig:meta' AGENTS.md && test -f jig/meta-cache/DECISIONS.md && grep -qx 'jig/meta-cache/' .gitignore && grep -qx 'mrclone/' .gitignore"
msg="para: the generated header is at most 6 lines"
expect_pass test "$(sed -n '/jig:meta —/,/jig:meta end/p' AGENTS.md | wc -l | tr -d ' ')" -le 6
git add -A && git commit -qm "para-init"

msg="para P1: a hand-edited header is refused"
sed -i.bak 's/is written only by branch/is written by anyone/' AGENTS.md && rm AGENTS.md.bak
git add -A; expect_refuse git commit -qm header; git reset -q --hard

msg="para P2: a contract-path change with no proposal or reason in a spec is refused"
printf 'y=2\n' >> api/a.py && git add -A; expect_refuse git commit -qm api
msg="para P2: with meta: none — <reason> in a staged spec it is accepted"
printf '# x\n\n## Decisions\n- meta: none — internal refactor, no contract change\n' > jig/specs/x.md
git add -A; expect_pass git commit -qm api

msg="para P3: git add -f of the cache is refused"
git add -f jig/meta-cache/DECISIONS.md; expect_refuse git commit -qm cache; git reset -q
msg="para P3: staging the metarepo checkout is refused"
git add -f mrclone 2>/dev/null; expect_refuse git commit -qm clone; git reset -q

msg="para-propose: a branch on the metarepo, the id in the spec, the metarepo's main untouched"
mainbefore=$(git -C mrclone rev-parse main)
$J para-propose jig/specs/x.md fmt >/dev/null
expect_pass sh -c "git -C mrclone rev-parse -q --verify refs/heads/propose/pr-fmt && grep -q 'meta: docs proposal propose/pr-fmt' jig/specs/x.md && test \"\$(git -C mrclone rev-parse main)\" = '$mainbefore' && test \"\$(git -C mrclone branch --show-current)\" = main"
git add -A && git commit -qm "specs: proposal"

msg="para: a new worktree gets the main checkout's cache; para-propose there names the repo, not the folder"
git worktree add -q --detach "$T/pr-lane" HEAD 2>/dev/null
(cd "$T/pr-lane" && $J para-propose jig/specs/x.md lanefix >/dev/null)
expect_pass sh -c "test -f '$T/pr-lane/jig/meta-cache/DECISIONS.md' && git -C mrclone rev-parse -q --verify refs/heads/propose/pr-lanefix"
git worktree remove --force "$T/pr-lane"

msg="repos: works outside any git repo"
expect_pass sh -c "cd '$T' && python3 '$P/jig/jig.py' repos"

cd "$MR" && git switch -q -c d1 && printf '| D-001 | ids are numbers | accepted | 2026-10-29 |\n' >> DECISIONS.md
printf -- '- D-001\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit d1 2>/dev/null && $J meta-release >/dev/null
cd "$PR" && printf 'D-001 is how ids work\n' > api/ids.md && git add api/ids.md && git commit -qm "api: ids" >/dev/null 2>&1
msg="para-sync: after a release it reports the change in this repo's terms and proposes the bump; the pin stays"
out=$($J para-sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'docs v0.2 is out' && echo \"\$0\" | grep -q 'D-001: used in api/ids.md' && echo \"\$0\" | grep -q 'meta: docs v0.1 → v0.2' && grep -q '\"pin\": \"v0.1\"' jig/para.json" "$out"

msg="repos: lists each repo and flags a path that no longer exists"
mv mrclone ../mrclone-away; out=$($J repos 2>&1); mv ../mrclone-away mrclone
expect_pass sh -c "echo \"\$0\" | grep -q 'docs .*(missing)'" "$out"

msg="para-sync: offline, it reads the cache and says so"
mv mrclone ../mrclone-away; out=$($J para-sync 2>&1); mv ../mrclone-away mrclone
expect_pass sh -c "echo \"\$0\" | grep -q \"can't reach docs\" && echo \"\$0\" | grep -q 'reading the cache (v0.1'" "$out"

msg="para-sync: with defer_until in the future it prints nothing; on or after it, the full report"
python3 -c "import json; p = json.load(open('jig/para.json')); p['defer_until'] = '2999-01-01'; json.dump(p, open('jig/para.json', 'w'), indent=2)"
quiet=$($J para-sync 2>&1)
python3 -c "import json; p = json.load(open('jig/para.json')); p['defer_until'] = '2000-01-01'; json.dump(p, open('jig/para.json', 'w'), indent=2)"
loud=$($J para-sync 2>&1)
expect_pass sh -c "test -z \"\$0\" && echo \"\$1\" | grep -q 'v0.2 is out'" "$quiet" "$loud"

msg="plugin: no instance names or the instance's decision prefix"
expect_refuse grep -rnE 'Maige|maige|"E-' "$P/.."

rm -rf "$T"
exit $fail
