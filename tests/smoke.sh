#!/usr/bin/env bash
# End-to-end check of the rules in a throwaway repo: one job in a worktree, the hooks
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
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && chmod +x .jig/scripts/*.sh
mkdir -p docs/alpha src
printf 'x=1\n' > src/a.py
printf '# A\n\n## 28 Alpha\ntext\n\n## 29 Beta\ntext\n' > docs/alpha/alpha.md
git add -A && git commit -qm init
$J init >/dev/null
python3 - <<'EOF'
import json; b = json.load(open('.jig/config.json'))
b['reserve'] = {'section': {'pattern': r'^## (\d+) ', 'files': ['docs/**']}}
json.dump(b, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board
$J open L1 --spec t --owns 'src/**' 'docs/**' --reserve section >/dev/null
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

# The marker is built from a variable, so this file carries no workaround comment of its own.
W="WORK""AROUND:"
msg="R7: a trailing # comment with the marker is refused"
printf 'x = 1  # %s y\n' "$W" >> src/a.py; git add -A; expect_refuse git commit -qm t; undo
msg="R7: a /* comment with the marker is refused"
printf '/* %s y */\n' "$W" > src/b.c; git add -A; expect_refuse git commit -qm t; undo
msg="R7: a block comment's continuation line with the marker is refused"
printf '/*\n * %s y\n */\n' "$W" > src/b.c; git add -A; expect_refuse git commit -qm t; undo
msg="R7: the marker in a string is accepted"
printf 'msg = "adds a WORKAROUND: comment"\n' > src/s.py; git add -A; expect_pass git commit -qm t
msg="R7: ; before a string with the marker is accepted"
printf 'a(); log("WORKAROUND: x")\n' > src/s.js; git add -A; expect_pass git commit -qm t
msg="R7: // in a URL before a string with the marker is accepted"
printf 'u = "http://h"; s = "WORKAROUND: y"\n' > src/u.py; git add -A; expect_pass git commit -qm t
msg="R7: jig's own R7 message line, outside the exempt checker, is accepted"
grep 'R7 the diff adds' "$P/jig/jig.py" > src/check.py; git add -A; expect_pass git commit -qm t

msg="R7: WORKAROUND: in code without a ledger row is refused"
printf '# %s x\n' "$W" >> src/a.py; git add -A; expect_refuse git commit -qm py
msg="R7: the refusal says where the row goes, and that the first row creates the ledger"
out=$(git commit -qm py 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'R7 .*\.jig/ledgers/WORKAROUNDS.md is not staged: add its row there in this commit (the first row creates'" "$out"

msg="R7: the first row creates the ledger from the plugin's template, and the commit is accepted"
mkdir -p .jig/ledgers && cp "$P/ledgers/WORKAROUNDS.md" .jig/ledgers/ && printf '| 2026-10-29 | src/a.py | x | t | t | t [seen] | t |\n' >> .jig/ledgers/WORKAROUNDS.md
git add -A; expect_pass git commit -qm py
git reset -q --hard HEAD~1

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

msg="gate does not refuse a job behind trunk"
( cd "$T" && printf 'r\n' > r.txt && git add -A && git commit -qm trunk5 )
out=$(cd "$T" && $J gate L1 2>&1); if echo "$out" | grep -q behind; then bad "$msg"; else ok "$msg"; fi

msg="fold-in: a change to .jig/jig.py is the tool's, not unowned code"
printf '# job edit\n' >> .jig/jig.py; printf 'x=7\n' > src/a.py; git add -A; git commit -qm tool
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1
note=$(cat .jig/handoffs/L1-*.md 2>/dev/null)
if echo "$note" | grep -q 'UNOWNED src/a.py' && ! echo "$note" | grep -q 'UNOWNED .jig/jig.py'
then ok "$msg"; else bad "$msg"; fi

I="$T/init"
mkdir -p "$I" && cd "$I" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" .
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="init: root holds only AGENTS.md, CLAUDE.md and .jig/"
expect_pass test "$(ls -A | grep -v '^\.git$' | LC_ALL=C sort | tr '\n' ' ')" = ".jig AGENTS.md CLAUDE.md "

msg="init: .jig/ holds jig.py, RULES.md, config.json, jobs.json, the four scripts and staging/.gitignore, nothing else"
expect_pass test "$(find .jig -type f | LC_ALL=C sort | tr '\n' ' ')" = ".jig/RULES.md .jig/config.json .jig/jig.py .jig/jobs.json .jig/scripts/check.sh .jig/scripts/format.sh .jig/scripts/release.sh .jig/scripts/setup.sh .jig/staging/.gitignore "

msg="init: the spec template and both ledgers stay in the plugin until first use"
expect_pass sh -c "test ! -e .jig/specs -a ! -e .jig/ledgers -a ! -e '$P/jig/specs' -a ! -e '$P/jig/ledgers' && test -f '$P/specs/_template.md' -a -f '$P/ledgers/WORKAROUNDS.md' -a -f '$P/ledgers/DEFERRED.md'"

msg="init: the hooks run trunk's .jig/jig.py"
expect_pass grep -q 'git show main:.jig/jig.py' .git/hooks/pre-commit

msg="plugin hook: the Stop hook runs .jig/scripts/check.sh before an older layout's"
mkdir -p jig/scripts scripts && printf '#!/bin/sh\necho old\n' > jig/scripts/check.sh && printf '#!/bin/sh\necho root\n' > scripts/check.sh
cp .jig/scripts/check.sh "$T/check.keep" && printf '#!/bin/sh\necho dot\n' > .jig/scripts/check.sh && chmod +x jig/scripts/check.sh scripts/check.sh .jig/scripts/check.sh
expect_pass test "$(CLAUDE_PROJECT_DIR="$I" bash "$P/../scripts/check.sh")" = dot
cp "$T/check.keep" .jig/scripts/check.sh && rm -r jig scripts
msg="plugin hook: every .sh in the plugin is tracked executable, and every hook command runs through bash"
expect_pass sh -c "test -z \"\$(git -C '$P/..' ls-files -s -- '*.sh' | grep '^100644')\" && ! grep '\"command\"' '$P/../hooks/hooks.json' | grep -vq '\"command\": \"bash '"
msg="plugin hook: a failing .jig/scripts/check.sh blocks the stop (exit 2), even with its executable bit lost"
cp .jig/scripts/check.sh "$T/check.keep" && printf '#!/bin/sh\necho failed >&2; exit 2\n' > .jig/scripts/check.sh && chmod -x .jig/scripts/check.sh
CLAUDE_PROJECT_DIR="$I" bash "$P/../scripts/check.sh" 2>/dev/null; rc=$?
expect_pass test "$rc" = 2
cp "$T/check.keep" .jig/scripts/check.sh && chmod +x .jig/scripts/check.sh

msg="survey: a fresh init is missing no piece, and doesn't ask for the lazy files"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))['present']
assert all(r.values()) and not any('_template' in k or 'ledgers' in k for k in r), r"

msg="init: the repo's docs/ is common on a new board"
expect_pass python3 -c "import json,sys; sys.exit('docs/**' not in json.load(open('.jig/config.json'))['common'])"

msg="open: a job's worktree lives in .git/jig/worktrees and trunk stays clean"
$J open L2 --spec t --owns 'docs/**' >/dev/null && git add -A && git commit -qm "open L2"
expect_pass test -d .git/jig/worktrees/L2 -a -z "$(git status --porcelain)"

msg="survey: a fresh init has no homeless files and no source counted from .jig/"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [] and r['src_count'] == 0, (r['homeless'], r['src_count'])"

msg="survey: Doc homes lists docs/ and .jig/specs/, and not the tool folders"
homes=$(python3 .jig/jig.py survey | grep '^Doc homes: ')
expect_pass sh -c "echo \"\$0\" | grep -qF '; docs/ = ' && echo \"\$0\" | grep -qF '; .jig/specs/ = ' && ! echo \"\$0\" | grep -qF '; .jig/ = ' && ! echo \"\$0\" | grep -qF '.claude/skills/ = '" "$homes"
msg="survey: a handoff note in .jig/ is a tool's record, not a homeless document"
mkdir -p .jig/handoffs && printf '# Handoff\n' > .jig/handoffs/x-2026-01-01.md && git add -A && git commit -qm note
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [], r['homeless']"

H="$T/hardware"
mkdir -p "$H" && cd "$H" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs/hardware docs/gpio main
printf '# Devkit\n' > docs/hardware/devkit.md && printf '# GPIO\n' > docs/gpio/gpio.md
printf 'int led = 48;\n' > main/app.c && printf 'CONFIG_ESPTOOLPY_FLASHSIZE_8MB=y\n' > sdkconfig
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="survey: names a board page no docmap entry covers"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['boards_unmapped'] == ['docs/hardware/devkit.md'], r['boards_unmapped']"

# The system page comes first, so a docmap that stops at the first match hides the board page.
python3 - <<'EOF'
import json; b = json.load(open('.jig/config.json'))
b['docmap'] = {'docs/gpio/gpio.md': ['main/**'],
               'docs/hardware/devkit.md': ['main/**', 'sdkconfig*']}
json.dump(b, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm docmap
msg="survey: a board page docmap names is not listed"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['boards_unmapped'] == [], r['boards_unmapped']"

msg="reading-list: a file covered by a system page and a board page lists both"
out=$($J reading-list main/app.c)
expect_pass test -n "$(echo "$out" | grep -F docs/gpio/gpio.md)" -a -n "$(echo "$out" | grep -F docs/hardware/devkit.md)"

$J open H1 --spec t --owns 'main/**' >/dev/null && $J open H2 --spec t --owns 'sdkconfig*' >/dev/null
git add -A && git commit -qm "open H1 H2"
cd .git/jig/worktrees/H1 && printf 'int led = 2;\n' > main/app.c && git add -A && git commit -qm led
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1; git add -A && git commit -qm note
msg="fold-in: changing a board's code asks about its board page and its system page"
expect_pass sh -c "grep -q -- '- \[ \] docs/hardware/devkit.md' .jig/handoffs/H1-*.md && grep -q -- '- \[ \] docs/gpio/gpio.md' .jig/handoffs/H1-*.md"
sed -i.bak 's|- \[ \] docs/gpio/gpio.md — updated / no change because ___|- [x] docs/gpio/gpio.md — no change because the pin is board wiring|' .jig/handoffs/H1-*.md
rm -f .jig/handoffs/*.bak && git add -A && git commit -qm "answer gpio"
msg="gate: refuses while the board page's fold-in line is unanswered"
expect_refuse sh -c "cd '$H' && $J gate H1"
sed -i.bak 's|- \[ \] docs/hardware/devkit.md — updated / no change because ___|- [x] docs/hardware/devkit.md — updated: LED on GPIO 2|' .jig/handoffs/H1-*.md
rm -f .jig/handoffs/*.bak && git add -A && git commit -qm "answer devkit"
msg="gate: passes once the board page's line is answered"
expect_pass sh -c "cd '$H' && $J gate H1"

cd "$H/.git/jig/worktrees/H2" && printf 'CONFIG_ESPTOOLPY_FLASHSIZE_16MB=y\n' > sdkconfig && git add -A && git commit -qm flash
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1
msg="fold-in: changing only a board's config file asks about its board page"
expect_pass grep -q -- '- \[ \] docs/hardware/devkit.md' .jig/handoffs/H2-*.md

S="$T/survey"
mkdir -p "$S" && cd "$S" && git init -q -b main && git config user.email t@t && git config user.name t
mkdir -p .jig src/widgets plugin/skills/x
cp "$P/jig/jig.py" .jig/
printf '# W\n' > src/widgets/README.md && printf '# X\n' > plugin/skills/x/SKILL.md
git add -A && git commit -qm init && $J init --no-hooks >/dev/null

msg="init: a new config has an empty not_docs"
expect_pass python3 -c "import json,sys; sys.exit(json.load(open('.jig/config.json'))['not_docs'] != [])"

msg="not_docs: survey skips declared globs, still flags the stray README"
python3 - <<'EOF'
import json; b = json.load(open('.jig/config.json'))
b['not_docs'] = ['plugin/**']
json.dump(b, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board   # survey reads trunk's board, not the working tree
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
homeless = [e['path'] for e in r['homeless']]
assert r['not_docs'] == ['plugin/**'], r['not_docs']
assert 'src/widgets/README.md' in homeless and 'plugin/skills/x/SKILL.md' not in homeless, homeless
assert r['not_docs_unmatched'] == [], r['not_docs_unmatched']"

msg="not_docs: a directory-style glob that matches nothing is named"
python3 - <<'EOF'
import json; b = json.load(open('.jig/config.json'))
b['not_docs'] = ['plugin/']
json.dump(b, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm board2
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['not_docs_unmatched'] == ['plugin/'], r['not_docs_unmatched']"


# ---------------------------------------------------------------- update
# Old layouts are rebuilt from this repo's own history, so the smoke test needs a full clone.
R="$(cd "$(dirname "$P")/.." && pwd)"
UP="python3 $P/jig/jig.py update"     # the plugin's copy, as the update skill runs it
code() { "$@" >/dev/null 2>&1; echo $?; }
snap() { git status --porcelain; find .git -type f | sort | xargs shasum 2>/dev/null; }

# old <dir> <commit> <style>: a repo set up the way that commit's init skill says, with a
# reserve counter on docs/**, a docmap page, a merged job, and a script of the repo's own.
# Styles: dot = eaec973's .jig/ with specs/, ledgers/, scripts/ at root; aidev = the same as
# ai-dev renamed it; jig = 62c8d9f's jig/ holding docs too; jig2 = 0.2.x's jig/, docs at root.
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
  elif [ "$style" = jig2 ]; then
    cp $t/AGENTS.md $t/CLAUDE.md . && cp -r $t/jig jig && mkdir -p docs && printf '# Docs\n' > docs/README.md
    tool=jig; docs=docs; specs=jig/specs
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
new = json.load(open(".jig/config.json"))
before = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", "HEAD"], text=True).split()
after = subprocess.check_output(["git", "ls-files"], text=True).split()
def lists(b):
    out = [b.get(k) or [] for k in ("common", "append_files", ("payload" if "payload" in b else "not_docs"))]
    out += [v.get("files") or [] for v in (b.get("reserve") or {}).values()]
    out += [list(b.get("docmap", {}))] + list(b.get("docmap", {}).values())
    return out
dead_before = {g for l in lists(old) for g in l if not any(j.matches(f, [g]) for f in before)}
for l in lists(new):
    for g in l:
        assert any(j.matches(f, [g]) for f in after) or g in dead_before, g
# A folder that moved out from under a broad glob is still covered (jig/** held jig/docs/).
moved = [l.split("\t")[1:] for l in subprocess.check_output(["git", "diff", "--cached", "-M", "--name-status"], text=True).splitlines() if l.startswith("R100")]
for o, n in moved:
    if o.startswith(("jig/", "specs/", "ledgers/", ".aidev/")):
        for lo, ln in zip(lists(old), lists(new)):
            assert not j.matches(o, lo) or j.matches(n, ln), (o, n, ln)
# The merged job is history: the config holds no jobs and the open jobs file starts empty.
assert "lanes" not in new and "log" not in new and json.load(open(".jig/jobs.json")) == {}, new
'

for layout in "eaec973 dot" "66a044c dot" "62c8d9f jig" "eaec973 aidev" "5d955a2 jig2"; do
  set -- $layout; c=$1; style=$2; name="$c-$style"
  old "$T/up-$name" $c $style
  board=$(git ls-files | grep 'lanes.json$')
  had_setup=$(git ls-files | grep 'scripts/setup.sh$')

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
allowed = {'$board', '.jig/config.json', '.jig/jobs.json', '.aidev/aidev.py', 'jig/jig.py', '.jig/jig.py',
           '.aidev/RULES.md', 'jig/RULES.md', '.jig/RULES.md', '.gitignore', '.jig/scripts/setup.sh', '.jig/scripts/release.sh', '.jig/staging/.gitignore'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or set(paths) <= allowed, line"

  msg="update $name: every board glob that matched before still matches"
  expect_pass python3 -c "$GLOBS" "$P/jig/jig.py" "$board"

  msg="update $name: hooks read trunk's .jig/jig.py and none was kept as .local; .git/jig/enabled, no .git/aidev, no old ignore line"
  expect_pass sh -c "grep -q 'git show main:.jig/jig.py' .git/hooks/pre-commit && ! ls .git/hooks/*.local && test -f .git/jig/enabled && test ! -e .git/aidev && ! grep -q worktrees .gitignore"

  msg="update $name: nothing tracked is left in jig/, .aidev/, specs/ or ledgers/; the config is stamped 8, with release.sh added"
  expect_pass sh -c "test -z \"\$(git ls-files jig .aidev specs ledgers .jig/lanes.json)\" && ! grep -q payload .jig/config.json && grep -q '\"version\": 8' .jig/config.json && git ls-files --error-unmatch .jig/scripts/release.sh"

  if [ -n "$had_setup" ]; then
    msg="update $name: its setup.sh moves to .jig/scripts/ untouched"
    expect_pass sh -c "git diff --cached --name-status | grep -q '^R100.jig/scripts/setup.sh.\.jig/scripts/setup.sh'"
  else
    msg="update $name: a repo without setup.sh gets the template's, staged, and the post-merge hook"
    expect_pass sh -c "cmp -s .jig/scripts/setup.sh '$P/jig/scripts/setup.sh' && test -x .jig/scripts/setup.sh && git diff --cached --name-status | grep -q '^A.\.jig/scripts/setup.sh' && grep -q 'hook post-merge' .git/hooks/post-merge"
  fi

  git ls-files > "$T/$name.paths"
  python3 -c "import json; print(sorted(json.load(open('.jig/config.json'))))" > "$T/$name.keys"

  msg="update $name: a second --apply is up to date and changes nothing"
  before=$(git status --porcelain); out=$($UP --apply 2>&1); after=$(git status --porcelain)
  expect_pass test "$out" = "up to date" -a "$before" = "$after"

  if [ "$style" = dot ]; then          # see the update skill, step 3
    msg="update $name: trunk's old checker refuses the update commit on R7 alone"
    err=$(git commit -qm update 2>&1)
    expect_pass sh -c "echo \"\$0\" | grep -q '^jig: R7 ' && ! echo \"\$0\" | grep -v '^jig: R7 ' | grep -q ." "$err"
    git commit -q --no-verify -m update
  else
    msg="update $name: the update commits with the hooks on"
    expect_pass git commit -qm update
  fi

  msg="update $name: after the commit, survey finds no homeless files"
  expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [], r['homeless']"
done

msg="update: all five old layouts end with the same tracked paths and board keys"
expect_pass sh -c "cd '$T' && for n in 66a044c-dot 62c8d9f-jig eaec973-aidev 5d955a2-jig2; do cmp -s eaec973-dot.paths \$n.paths && cmp -s eaec973-dot.keys \$n.keys || exit 1; done"

msg="update: a 0.2.x repo's untracked staged files and meta-cache move to .jig/, and the cache's ignore line follows"
old "$T/up-staged" 5d955a2 jig2
printf 'jig/meta-cache/\n' >> .gitignore && git commit -qam ignore
printf -- '---\nstaged: true\n---\nx\n' > jig/staging/pending.md && mkdir -p jig/meta-cache && printf 'v0.1\n' > jig/meta-cache/PIN
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | grep -q 'move the untracked files in jig/staging/ to .jig/staging/' && test -f .jig/staging/pending.md -a -f .jig/meta-cache/PIN -a ! -e jig && grep -qx '.jig/meta-cache/' .gitignore && ! grep -qx 'jig/meta-cache/' .gitignore && test -z \"\$(git status --porcelain --untracked-files=all | grep -v '^[RAMD] ')\"" "$out"

msg="update: same stamp, different jig.py and RULES.md: both replaced, hooks rewritten, nothing moves, the repo's setup.sh kept byte for byte"
cd "$T/up-eaec973-dot"
printf '# local edit\n' >> .jig/jig.py && printf 'local edit\n' >> .jig/RULES.md && printf 'uv sync\n' >> .jig/scripts/setup.sh
git commit -qam edit && cp .jig/scripts/setup.sh "$T/setup.mine"
rm .git/hooks/pre-push
$UP --apply >/dev/null 2>&1
expect_pass sh -c "test \"\$(git diff --cached --name-status | sort)\" = \"\$(printf 'M\t.jig/RULES.md\nM\t.jig/jig.py')\" && test -f .git/hooks/pre-push && cmp -s .jig/scripts/setup.sh '$T/setup.mine'"
git commit -qm tools

msg="update: once the board is current at .jig/, a root specs/, scripts/check.sh and a jig/ folder are the repo's own"
mkdir -p specs jig/specs && printf '# spec\n' > specs/api.md && printf 'echo mine\n' > scripts/check.sh
printf '# mine\n' > jig/specs/x.md && printf '{"lanes": {}}\n' > jig/lanes.json.example
git add -A && git commit -qm own
expect_pass test "$($UP 2>&1)" = "up to date"
git reset -q --hard HEAD~1

msg="update: a board stamped above this jig refuses"
python3 -c "import json; b = json.load(open('.jig/config.json')); b['version'] = 99; json.dump(b, open('.jig/config.json', 'w'))"
git commit -qam ahead
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'repo is ahead; update the plugin'" "$out"
git reset -q --hard HEAD~1

msg="update: an up-to-date repo says so even with a worktree open"
git worktree add -q --detach "$T/up-extra0" HEAD 2>/dev/null
expect_pass test "$($UP 2>&1)" = "up to date"
git worktree remove --force "$T/up-extra0"
printf '# behind\n' >> .jig/jig.py && git commit -qam behind   # the refusals below need a plan

msg="update: an open job refuses, naming it"
printf '{"live": {"state": "building"}}\n' > .jig/jobs.json
git commit -qam live
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'jobs are open: live'" "$out"
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
mkdir -p jig && cp .jig/config.json jig/lanes.json && git add -A && git commit -qm two
before=$(snap); out=$($UP --apply 2>&1); rc=$?; after=$(snap)
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'two boards, .jig/config.json and jig/lanes.json' && test \"\$1\" = \"\$2\"" "$out" "$before" "$after"

msg="update blocked: no board names the board-like JSON and the foreign hooks"
N="$T/up-none"; mkdir -p "$N/.other" && cd "$N" && git init -q -b main
printf '{"lanes": {}}\n' > .other/lanes.json && git add -A && git -c user.email=t@t -c user.name=t commit -qm init
printf '#!/bin/sh\nexit 0\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'board-like JSON: .other/lanes.json' && echo \"\$0\" | grep -q \"a hook jig didn't write: pre-commit\"" "$out"

old "$T/up-warn" 62c8d9f jig
printf 'notes\n' > jig/notes.txt && mkdir -p tools && printf 'BOARD = "jig/lanes.json"\n' > tools/paths.py
mkdir -p .jig/specs && printf '# new\n' > .jig/specs/new.md
python3 -c "import json; b = json.load(open('jig/lanes.json')); b['extra'] = 1; json.dump(b, open('jig/lanes.json', 'w'))"
git add -A && git commit -qm warn
out=$($UP 2>&1); rc=$?
msg="update warning: an extra file in jig/ is named, and the dry run exits 1"
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q 'jig/notes.txt is at an old path'" "$out"
msg="update warning: a board key jig doesn't know is named"
expect_pass sh -c "echo \"\$0\" | grep -q 'board key .extra. is not one jig knows'" "$out"
msg="update warning: a .py file that names jig/lanes.json is named, with its line"
expect_pass sh -c "echo \"\$0\" | grep -q 'tools/paths.py names a path jig moved' && echo \"\$0\" | grep -q '1: BOARD = \"jig/lanes.json\"'" "$out"
msg="update warning: jig/specs/ and .jig/specs/ both exist, so neither moves"
expect_pass sh -c "echo \"\$0\" | grep -q 'jig/specs/ and .jig/specs/ both exist'" "$out"
msg="update warning: --apply proceeds; the extra file, both specs folders and the unknown key stay"
rc=$(code $UP --apply)
expect_pass sh -c "test $rc = 0 && test -f jig/notes.txt && test -f jig/specs/_template.md && test -f .jig/specs/new.md && grep -q '\"extra\"' .jig/config.json"


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
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q '.jig/scripts/check.sh FAILED (exit 2)' && test -f docs/HARDWARE.md && test -f .claude/skills/_skill-template/SKILL.md && git diff --cached --name-status | grep -q 'R100.*\.jig/specs/_template.md'" "$out"

cd "$T/up-warn" && git commit -qm applied
msg="update: after --apply, a kept warning still reads up to date, exit 0"
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | head -1 | grep -qx 'up to date'" "$out"

# Every generation, from the made-up repos in tests/fixtures/: each ends with the same jig
# paths and board keys, and every file it doesn't remove moves byte for byte.
FX="$R/tests/fixtures"
fixture() {  # fixture <generation>: a fresh repo from tests/fixtures/<generation>, committed
  mkdir -p "$T/fx-$1" && cp -R "$FX/$1/repo/." "$T/fx-$1/" && cd "$T/fx-$1"
  git init -q -b main && git config user.email t@t && git config user.name t
  git add -A && git commit -qm init && cp -R "$FX/$1/git/." .git/
}
for gen in claude-lane ai-dev jig-0.2 dot-jig-v7; do
  fixture $gen
  if [ $gen = claude-lane ]; then
    msg="update $gen: a counter with no pattern and files refuses, naming it"
    out=$($UP 2>&1); rc=$?
    expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'without a pattern and files: section'" "$out"
    python3 - <<'EOF'
import json; p = '.claude/claude-lane/manifests/board.json'; b = json.load(open(p))
b['reserve'] = {'section': {'pattern': r'^## (\d+) ', 'files': ['docs/**']}}
json.dump(b, open(p, 'w'), indent=2)
EOF
    git commit -qam "board: the counter's pattern"
  fi

  msg="update $gen: the dry run changes nothing, and lists every removal before applying"
  before=$(snap); out=$($UP 2>&1); after=$(snap)
  removed=$(echo "$out" | sed -n '/^Removed:/,/^$/p' | sed -n 's/^  \([^ ]*\) .*/\1/p')
  case $gen in
    claude-lane) want=".claude/claude-lane/LANES.md .claude/claude-lane/claude-lane.py .claude/claude-lane/README.md .claude/claude-lane/install-hooks.sh board: board:";;
    ai-dev) want=".aidev/aidev.py .aidev/RULES.md docs/REVIEW_LEDGER.md";;
    *) want="board:";;
  esac
  expect_pass sh -c "test \"\$1\" = \"\$2\" && for w in \$3; do echo \"\$0\" | grep -qF \"  \$w\" || exit 1; done" "$out" "$before" "$after" "$want"
  if [ $gen = claude-lane ]; then
    msg="update $gen: the dry run names the merged board entry and claude-lane's own key it drops"
    expect_pass sh -c "echo \"\$0\" | grep -q 'board: lanes.old (merged)' && echo \"\$0\" | grep -q 'board: .seen.'" "$out"
  fi

  msg="update $gen: --apply moves every file it keeps byte for byte, and removes only what the dry run listed"
  board=$(git ls-files | grep -E '(lanes|board)\.json$'); $UP --apply >/dev/null 2>&1
  expect_pass python3 -c "
import subprocess, sys
removed = set(sys.argv[1].split())
jig = {'.jig/config.json', '.jig/jobs.json', '.jig/jig.py', '.jig/RULES.md', '.jig/scripts/setup.sh', '.jig/scripts/release.sh',
       '.jig/ledgers/DEFERRED.md', '.jig/staging/.gitignore', '.gitignore'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or (status == 'D' and paths[0] in removed) or paths[-1] in jig, line" "$removed $board"

  case $gen in
    ai-dev)
      msg="update $gen: REVIEW_LEDGER.md's untaken rows are DEFERRED.md; its taken rows are gone"
      expect_pass sh -c "grep -q L-001 .jig/ledgers/DEFERRED.md && grep -q L-003 .jig/ledgers/DEFERRED.md && grep -q L-005 .jig/ledgers/DEFERRED.md && ! grep -q 'L-00[24]' .jig/ledgers/DEFERRED.md && test ! -e docs/REVIEW_LEDGER.md"
      msg="update $gen: a root HARDWARE.md naming a board moves to its board page, byte for byte"
      expect_pass sh -c "git diff --cached -M --name-status | grep -q '^R100.HARDWARE.md.docs/hardware/devkit-s3.md'";;
    claude-lane)
      msg="update $gen: board.json is the board, merged entries and claude-lane's own keys gone; the folder is gone"
      expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['trunk'] == 'main' and 'lanes' not in b and 'seen' not in b and 'main' not in b and 'next' not in b['reserve']['section'], b\" && test ! -e .claude/claude-lane && git diff --cached -M --name-status | grep -q '^R100.*old-2026-01-01.md'";;
    dot-jig-v7)
      msg="update $gen: the one-file board splits: config.json without jobs or log, an empty jobs.json, no lanes.json"
      expect_pass sh -c "python3 -c \"import json; c = json.load(open('.jig/config.json')); assert c['version'] == 8 and not {'lanes', 'log'} & set(c) and json.load(open('.jig/jobs.json')) == {}, c\" && test ! -e .jig/lanes.json && echo \"\$0\" | grep -q 'board: lanes.old (merged)' && echo \"\$0\" | grep -q 'board: log'" "$out";;
  esac

  msg="update $gen: a second update is up to date"
  expect_pass test "$($UP 2>&1)" = "up to date"

  msg="update $gen: the update commits with the hooks on, and survey then finds no homeless files"
  expect_pass sh -c "git commit -qm update && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [], r['homeless']\""
  git ls-files .jig > "$T/fx-$gen.paths"
  python3 -c "import json; print(sorted(json.load(open('.jig/config.json'))), json.load(open('.jig/jobs.json')))" > "$T/fx-$gen.keys"
done
msg="update: every generation ends with the same jig paths and board keys"
expect_pass sh -c "cd '$T' && for n in ai-dev jig-0.2 dot-jig-v7; do cmp -s fx-claude-lane.paths fx-\$n.paths && cmp -s fx-claude-lane.keys fx-\$n.keys || exit 1; done"

msg="update: a root specs/ file that isn't Markdown stays, with a warning"
old "$T/up-js" eaec973 dot
printf 'it()\n' > specs/app.spec.js && git add -A && git commit -qm js
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'specs/app.spec.js is in specs/ but isn.t Markdown' && ! echo \"\$0\" | grep -q 'app.spec.js → '" "$out"

# ---------------------------------------------------------------- the board, split
B="$T/jobs"; mkdir -p "$B" && cd "$B" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs src
printf '# D\n\n## 1 One\n' > docs/d.md && printf 'x=1\n' > src/a.py
git add -A && git commit -qm init && $J init >/dev/null

msg="init: config.json holds the settings, no jobs and no log; jobs.json is empty"
expect_pass python3 -c "
import json; c = json.load(open('.jig/config.json')); j = json.load(open('.jig/jobs.json'))
assert sorted(c) == sorted(['version', 'name', 'trunk', 'common', 'append_files', 'reserve', 'docmap', 'not_docs', 'release']), c
assert c['version'] == 8 and j == {}, (c, j)"
python3 - <<'EOF'
import json; c = json.load(open('.jig/config.json'))
c['reserve'] = {'section': {'pattern': r'^## (\d+) ', 'files': ['docs/**']}, 'loose': {}}
json.dump(c, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm config

msg="open: two jobs reserving at once get max(trunk, held) + 1, never the same number"
$J open A --owns 'src/**' --reserve section >/dev/null && $J open B2 --reserve section >/dev/null
expect_pass python3 -c "import json; j = json.load(open('.jig/jobs.json')); assert j['A']['reserved'] == {'section': 2} and j['B2']['reserved'] == {'section': 3}, j"
msg="open: a record stores no branch, worktree, opened date or handoffs it can derive"
expect_pass python3 -c "import json; j = json.load(open('.jig/jobs.json')); assert not {'branch', 'worktree', 'opened', 'handoffs'} & set(j['A']), j['A']"
msg="open: only jobs.json changes; config.json is untouched"
expect_pass test -z "$(git status --porcelain -- .jig/config.json)"
msg="open: a counter without a pattern and files is refused"
expect_refuse $J open C --reserve loose
git add -A && git commit -qm "open A B2"

msg="job: prints the branch and worktree it derives, and the day it opened"
out=$(cd .git/jig/worktrees/A && $J job)
expect_pass sh -c "echo \"\$0\" | grep -q '\"branch\": \"A\"' && echo \"\$0\" | grep -q '\"worktree\": \".git/jig/worktrees/A\"' && echo \"\$0\" | grep -q '\"opened\": \"20'" "$out"

msg="open: a branch adopted under another name stores only its branch"
git branch feat && $J open F --branch feat >/dev/null && git add -A && git commit -qm "adopt feat"
expect_pass sh -c "python3 -c \"import json; r = json.load(open('.jig/jobs.json'))['F']; assert r['branch'] == 'feat' and 'worktree' not in r, r\" && cd .git/jig/worktrees/feat && $J check"
msg="open: a branch checked out elsewhere stores only its worktree, and R2 reads that, not the default"
git branch side && git worktree add -q "$T/jobs-side" side 2>/dev/null
$J open side --worktree "$T/jobs-side" >/dev/null && git add -A && git commit -qm "adopt side"
mkdir -p .git/jig/worktrees/side
expect_pass sh -c "python3 -c \"import json; r = json.load(open('.jig/jobs.json'))['side']; assert r['worktree'] == '$T/jobs-side' and 'branch' not in r, r\" && cd '$T/jobs-side' && $J check"
rmdir .git/jig/worktrees/side

cd .git/jig/worktrees/A
msg="R5: a job editing jobs.json is refused"
printf '{}\n' > .jig/jobs.json; git add -A; expect_refuse git commit -qm jobs; undo
msg="R5: a job editing config.json is refused"
printf '{}\n' > .jig/config.json; git add -A; expect_refuse git commit -qm config; undo
msg="R6: job A takes section 2, which it holds"
printf '\n## 2 Two\n' >> docs/d.md && git add -A && expect_pass git commit -qm two
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && git add -A && git commit -qm note
printf 'x=2\n' > src/a.py && git commit -qam "after the note"
msg="merge: a job whose branch moved past the commit its note names is refused"
expect_refuse sh -c "cd '$B' && $J merge A"
git reset -q --hard HEAD~1
first=$(git rev-parse HEAD)   # past the first note's commit: a merge checked against that note refuses
printf 'x=3\n' > src/a.py && git commit -qam three
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && git add -A && git commit -qm note2
printf 'x=4\n' > src/a.py && git commit -qam four
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1
sed -i.bak 's/^- \[ \] \(.*\)___/- [x] \1smoke/' ".jig/handoffs/A-$(date +%F)-3.md" && rm .jig/handoffs/*.bak
printf '# Handoff: A-x\n\nCommit: %s\n' "$first" > ".jig/handoffs/A-x-$(date +%F).md"   # job A-x's note, on A's branch
git add -A && git commit -qm note3
msg="gate: of three notes filed on one day, the gate takes the -3 note"
expect_pass sh -c "cd '$B' && $J gate A | grep -q \"from .jig/handoffs/A-$(date +%F)-3.md \""
msg="status: job A counts its own three notes, not job A-x's"
expect_pass sh -c "cd '$B' && $J status | grep -q '^  A .*handoffs:3 '"
cd "$B"
msg="open: --after naming no open job is refused, since a missing name reads as merged"
expect_refuse $J open X --after B3
msg="open: an explicit number another open job holds is refused"
expect_refuse $J open Y --reserve section=3

msg="merge: R8 refuses a job whose after has not merged"
$J open E --after B2 >/dev/null && git add -A && git commit -qm "open E"
expect_refuse $J merge E
msg="mark: merged is not a state; jig merge is how a job merges"
expect_refuse $J mark B2 merged
msg="merge: the job's entry is deleted in the merge commit itself, and trunk takes the number it held (checked against the -3 note; the first names an older commit)"
$J merge A -m "shared: none" >/dev/null 2>&1
expect_pass sh -c "test \"\$(git rev-list --parents -n1 HEAD | wc -w | tr -d ' ')\" = 3 && git show --format= --name-only HEAD | grep -qx .jig/jobs.json && ! git show HEAD:.jig/jobs.json | grep -q '\"A\"' && git log -1 --format=%B | grep -q 'shared: none' && test -z \"\$(git status --porcelain --untracked-files=no)\""
msg="open: after A merged, the next section is above trunk's 2 and B2's 3"
$J open G --reserve section >/dev/null
expect_pass python3 -c "import json; assert json.load(open('.jig/jobs.json'))['G']['reserved'] == {'section': 4}"
git add -A && git commit -qm "open G"
msg="no log: neither file has a log key, and jig log is not a command"
expect_pass sh -c "! grep -q '\"log\"' .jig/config.json .jig/jobs.json && ! $J log 2>/dev/null"

# ---------------------------------------------------------------- worktree setup
W="$T/setup"; LOG="$T/setup.log"
mkdir -p "$W" && cd "$W" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p src && printf 'x=1\n' > src/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="setup: after init, .jig/scripts/setup.sh is executable, all TODOs, and exits 0"
expect_pass sh -c "test -x .jig/scripts/setup.sh && grep -q TODO .jig/scripts/setup.sh && .jig/scripts/setup.sh"

printf '#!/bin/sh\necho "set up $(pwd -P)"\npwd -P >> "%s"\n' "$LOG" > .jig/scripts/setup.sh
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

msg="setup: jig open sets the job's worktree up once, and its stderr shows setup's output"
err=$($J open S1 --owns 'src/**' 2>&1 >/dev/null); git add -A && git commit -qm "open S1"
expect_pass sh -c "test $(lines) = 4 && echo \"\$0\" | grep -q 'set up .*S1'" "$err"

msg="setup: jig sync that resolves an append conflict itself sets the job up once"
printf '\n- trunk line\n' >> AGENTS.md && git commit -qam trunk-append
(cd .git/jig/worktrees/S1 && printf '\n- job line\n' >> AGENTS.md && git commit -qam job-append && $J sync >/dev/null 2>&1)
expect_pass test "$(lines)" = 5 -a "$(tail -1 "$LOG")" = "$(cd .git/jig/worktrees/S1 && pwd -P)"

printf '#!/bin/sh\necho broken >&2\nexit 1\n' > .jig/scripts/setup.sh && git commit -qam "setup fails"
msg="setup: a failing setup.sh fails nothing; jig open exits 0 and stderr names the script, code and checkout"
err=$($J open S2 --owns 'docs/**' 2>&1 >/dev/null); rc=$?
expect_pass sh -c "test $rc = 0 && test -d .git/jig/worktrees/S2 && grep -q '\"S2\"' .jig/jobs.json && echo \"\$0\" | grep -q '.jig/scripts/setup.sh exited 1 in .*S2'" "$err"
git add -A && git commit -qm "open S2"

msg="setup: a failing setup.sh fails nothing for a plain git worktree add either"
expect_pass git worktree add -q --detach "$T/setup-fail" HEAD

msg="setup: a checkout with no setup.sh (a commit from before it) runs nothing and prints nothing extra"
git worktree add -q --detach "$T/setup-mk" HEAD 2>/dev/null
before_none=$(cd "$T/setup-mk" && git rm -q .jig/scripts/setup.sh && git commit -qm "no setup" && git rev-parse HEAD)
n=$(lines); err=$(git worktree add -q --detach "$T/setup-none" "$before_none" 2>&1)
expect_pass sh -c "test -z \"\$0\" && test $n = \$(wc -l < '$LOG' | tr -d ' ') && test ! -e '$T/setup-none/.jig/scripts/setup.sh'" "$err"

# ---------------------------------------------------------------- metarepo
M="$T/meta"; mkdir -p "$M" && cd "$M" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && git add -A && git commit -qm "meta-init"
mrel() { $J release 2>&1; }
branch_commit() {  # branch_commit <branch> <subject>: commit what's staged on a new branch
  git switch -q -c "$1" && git commit -qm "$2"; }

msg="meta: init --meta then release tags v0.1.0, with no release.sh steps to fill, and says it's a metarepo"
out=$($J release 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '(metarepo)' && git tag | grep -qx v0.1.0 && grep -q '^## v0.1.0 — ' CHANGELOG.md" "$out"
msg="meta: the release leaves an empty ## Unreleased above its heading for the next entries"
expect_pass sh -c "grep -A2 '^## Unreleased\$' CHANGELOG.md | grep -q '^## v0.1.0 — '"
msg="meta: a second release with no entry-file change says nothing to release"
out=$(mrel); expect_pass sh -c "echo \"\$0\" | grep -q 'nothing to release'" "$out"

git switch -q -c b1
msg="meta M1: a source file outside .jig/ is refused"
printf 'x=1\n' > tool.py && git add tool.py; expect_refuse git commit -qm "D-001: tool"; git rm -q --cached tool.py; rm tool.py
msg="meta: a change to .jig/jig.py is accepted"
printf '\n' >> .jig/jig.py && git add .jig/jig.py; expect_pass git commit -qm "TOOL: jig"
msg="meta M2: a decision row without status and date is refused"
printf '| D-001 | use JSON |\n' >> DECISIONS.md && printf -- '- D-001\n' >> CHANGELOG.md && git add -A
expect_refuse git commit -qm "D-001: JSON"; git reset -q; git checkout -q -- DECISIONS.md CHANGELOG.md
m2() { printf '%s\n' "$1" >> DECISIONS.md && printf -- '- D-001\n' >> CHANGELOG.md && git add -A
  $J check --staged; local rc=$?; git reset -q; git checkout -q -- DECISIONS.md CHANGELOG.md; return $rc; }
msg="meta M2: an open question is a decision row"
expect_pass m2 '| D-001 | which wire format? | open | 2026-10-29 |'
msg="meta M2: a status with a note, and superseded by an id, are accepted"
expect_pass m2 '| D-001 | x | accepted (owner) | 2026-10-29 |'
expect_pass m2 '| D-001 | x | superseded by D-002 | 2026-10-29 |'
msg="meta M2: a Decision cell starting with a status word is not the status"
expect_refuse m2 '| D-001 | Accepted practice: radios off |  | 2026-10-29 |'
expect_refuse m2 '| D-001 | Open question: which copy? |  | 2026-10-29 |'
msg="meta M2: a status word with more letters is refused"
expect_refuse m2 '| D-001 | x | acceptedly | 2026-10-29 |'
msg="meta M2: the refusal lists all five statuses"
out=$(m2 '| D-001 | x |  | 2026-10-29 |' 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'open/proposed/accepted/superseded/rejected'" "$out"
msg="meta: init --meta's DECISIONS.md lists all five statuses"
expect_pass grep -q 'open, proposed, accepted, superseded, rejected' DECISIONS.md
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

msg="meta: release tags v0.2.0 (minor is a metarepo's default)"
expect_pass sh -c "$J release && git tag | grep -qx v0.2.0"

git switch -q -c b2 && printf '\n## grain\n' >> GLOSSARY.md && printf -- '- grain\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: grain" && git switch -q main
git merge -q --ff-only b2
git init -q --bare "$T/meta-remote.git" && git remote add origin "$T/meta-remote.git"
msg="meta: a fast-forward of an unreviewed branch: release refuses, naming the commit"
out=$(mrel); c=$(git rev-parse --short=12 HEAD)
expect_pass sh -c "echo \"\$0\" | grep -q '$c is on main without a reviewed merge'" "$out"
msg="meta: and pre-push refuses it"
expect_refuse git push -q origin main
git reset -q --hard v0.2.0

msg="meta: a tag made by hand fails the next release and pre-push, naming it"
git tag v0.3
out=$(mrel)
expect_pass sh -c "echo \"\$0\" | grep -q 'tag v0.3 was not made by jig release' && ! git push -q origin main 2>/dev/null" "$out"
git tag -d v0.3 >/dev/null

# ---------------------------------------------------------------- pararepo
export JIG_CONFIG="$T/repos.json"     # never the user's real list
MR="$T/mr"; mkdir -p "$MR" && cd "$MR" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
PR="$T/pr"; mkdir -p "$PR" && cd "$PR" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
git clone -q "$MR" mrclone

msg="para: init --para writes para.json, the AGENTS.md header, the cache, and ignores the cache"
$J init --para docs --location mrclone --contract 'api/**' >/dev/null
expect_pass sh -c "grep -q '\"pin\": \"v0.1.0\"' .jig/para.json && ! grep -q location .jig/para.json && grep -q '\"docs\"' '$T/repos.json' && grep -q 'jig:meta' AGENTS.md && test -f .jig/meta-cache/DECISIONS.md && grep -qx '.jig/meta-cache/' .gitignore && grep -qx 'mrclone/' .gitignore"
msg="para: the generated header is at most 6 lines"
expect_pass test "$(sed -n '/jig:meta —/,/jig:meta end/p' AGENTS.md | wc -l | tr -d ' ')" -le 6
git add -A && git commit -qm "para-init"

msg="release: a pararepo says so"
expect_pass sh -c "$J release 2>&1 | grep -q '(pararepo)'"

msg="para P1: a hand-edited header is refused"
sed -i.bak 's/is written only by branch/is written by anyone/' AGENTS.md && rm AGENTS.md.bak
git add -A; expect_refuse git commit -qm header; git reset -q --hard

msg="para P2: a contract-path change with no proposal or reason in a spec is refused"
printf 'y=2\n' >> api/a.py && git add -A; expect_refuse git commit -qm api
msg="para P2: with meta: none — <reason> in a staged spec it is accepted"
mkdir -p .jig/specs && printf '# x\n\n## Decisions\n- meta: none — internal refactor, no contract change\n' > .jig/specs/x.md
git add -A; expect_pass git commit -qm api

msg="para P3: git add -f of the cache is refused"
git add -f .jig/meta-cache/DECISIONS.md; expect_refuse git commit -qm cache; git reset -q
msg="para P3: staging the metarepo checkout is refused"
git add -f mrclone 2>/dev/null; expect_refuse git commit -qm clone; git reset -q

msg="para-propose: a branch on the metarepo, the id in the spec, the metarepo's main untouched"
mainbefore=$(git -C mrclone rev-parse main)
$J para-propose .jig/specs/x.md fmt >/dev/null
expect_pass sh -c "git -C mrclone rev-parse -q --verify refs/heads/propose/pr-fmt && grep -q 'meta: docs proposal propose/pr-fmt' .jig/specs/x.md && test \"\$(git -C mrclone rev-parse main)\" = '$mainbefore' && test \"\$(git -C mrclone branch --show-current)\" = main"
git add -A && git commit -qm "specs: proposal"

stage() {  # stage <file> <target> <kind> <change> <destination> [body]
  printf -- '---\nstaged: true\ntarget: %s\nkind: %s\nchange: %s\ndestination: %s\nsource: chat %s\nstatus: staged\n---\n%b' \
    "$2" "$3" "$4" "$5" "$1" "${6:-# Title\n\nbody\n}" > ".jig/staging/$1"; }
msg="para P4: a contract change waits while a file for the metarepo is staged"
stage meta-note.md docs decisions new DECISIONS.md '| D-009 | x | proposed | 2026-10-29 |\n'
printf 'z=3\n' >> api/a.py && printf -- '- meta: none — still internal\n' >> .jig/specs/x.md && git add api/a.py .jig/specs/x.md
expect_refuse git commit -qm "api: more"
python3 .jig/jig.py staging drop meta-note.md >/dev/null
msg="para P4: once it is resolved, the same commit is accepted"
expect_pass git commit -qm "api: more"

msg="para: a new worktree gets the main checkout's cache; para-propose there names the repo, not the folder"
git worktree add -q --detach "$T/pr-job" HEAD 2>/dev/null
(cd "$T/pr-job" && $J para-propose .jig/specs/x.md lanefix >/dev/null)
expect_pass sh -c "test -f '$T/pr-job/.jig/meta-cache/DECISIONS.md' && git -C mrclone rev-parse -q --verify refs/heads/propose/pr-lanefix"
git worktree remove --force "$T/pr-job"

msg="repos: works outside any git repo"
expect_pass sh -c "cd '$T' && python3 '$P/jig/jig.py' repos"

cd "$MR" && git switch -q -c d1 && printf '| D-001 | ids are numbers | accepted | 2026-10-29 |\n' >> DECISIONS.md
printf -- '- D-001\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit d1 2>/dev/null && $J release >/dev/null
cd "$PR" && printf 'D-001 is how ids work\n' > api/ids.md && git add api/ids.md && git commit -qm "api: ids" >/dev/null 2>&1
msg="para-sync: after a release it reports the change in this repo's terms and proposes the bump; the pin stays"
out=$($J para-sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'docs v0.2.0 is out' && echo \"\$0\" | grep -q 'D-001: used in api/ids.md' && echo \"\$0\" | grep -q 'meta: docs v0.1.0 → v0.2.0' && grep -q '\"pin\": \"v0.1.0\"' .jig/para.json" "$out"

msg="repos: lists each repo and flags a path that no longer exists"
mv mrclone ../mrclone-away; out=$($J repos 2>&1); mv ../mrclone-away mrclone
expect_pass sh -c "echo \"\$0\" | grep -q 'docs .*(missing)'" "$out"

msg="para-sync: offline, it reads the cache and says so"
mv mrclone ../mrclone-away; out=$($J para-sync 2>&1); mv ../mrclone-away mrclone
expect_pass sh -c "echo \"\$0\" | grep -q \"can't reach docs\" && echo \"\$0\" | grep -q 'reading the cache (v0.1'" "$out"

msg="para-sync: with defer_until in the future it prints nothing; on or after it, the full report"
python3 -c "import json; p = json.load(open('.jig/para.json')); p['defer_until'] = '2999-01-01'; json.dump(p, open('.jig/para.json', 'w'), indent=2)"
quiet=$($J para-sync 2>&1)
python3 -c "import json; p = json.load(open('.jig/para.json')); p['defer_until'] = '2000-01-01'; json.dump(p, open('.jig/para.json', 'w'), indent=2)"
loud=$($J para-sync 2>&1)
expect_pass sh -c "test -z \"\$0\" && echo \"\$1\" | grep -q 'v0.2.0 is out'" "$quiet" "$loud"
git checkout -q -- .jig/para.json
msg="update: a pararepo's generated header is left as it is (trunk's older checker would refuse a change)"
expect_pass sh -c "! python3 '$P/jig/jig.py' update | grep -q AGENTS.md"
msg="update: a metarepo's two-part tag_pattern is widened to take vX.Y.Z"
(cd "$MR" && python3 -c "import json; m = json.load(open('.jig/meta.json')); m['tag_pattern'] = r'^v\\d+\\.\\d+$'; json.dump(m, open('.jig/meta.json', 'w'), indent=2)")
expect_pass sh -c "cd '$MR' && python3 '$P/jig/jig.py' update | grep -q 'widen .jig/meta.json'"
git -C "$MR" checkout -q -- .jig/meta.json

msg="plugin: no instance names or the instance's decision prefix"
expect_refuse grep -rnE 'Maige|maige|"E-' "$P/.."

# ---------------------------------------------------------------- staging
ST="$T/st"; mkdir -p "$ST" && cd "$ST" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
stage() {
  printf -- '---\nstaged: true\ntarget: %s\nkind: %s\nchange: %s\ndestination: %s\nsource: chat %s\nstatus: staged\n---\n%b' \
    "$2" "$3" "$4" "$5" "$1" "${6:-# Title\n\nbody\n}" > ".jig/staging/$1"; }

msg="staging: init leaves .jig/staging/ with only its .gitignore, and a dropped file is untracked"
stage a.md this spec new a.md
expect_pass sh -c "test \"\$(ls -A .jig/staging)\" = \"\$(printf '.gitignore\na.md')\" && test -z \"\$(git status --porcelain)\""

msg="staging: the list names a bad header and exits 1"
printf -- '---\nstaged: true\nkind: memo\n---\nx\n' > .jig/staging/bad.md
out=$($J staging); rc=$?
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q 'no target' && echo \"\$0\" | grep -q \"kind 'memo'\"" "$out"
rm .jig/staging/bad.md

msg="staging: a new spec lands in .jig/specs/ with its Source line, and leaves staging"
$J staging resolve a.md >/dev/null
expect_pass sh -c "grep -q '^Source: chat a.md (staged as a.md)' .jig/specs/a.md && test ! -e .jig/staging/a.md"
msg="staging: a new spec whose path exists is refused"
stage a.md this spec new a.md; expect_refuse $J staging resolve a.md; rm .jig/staging/a.md

msg="staging: an update to a doc waits until the page carries the source"
mkdir -p docs/x && printf '# X\n' > docs/x/x.md && stage d.md this doc update docs/x/x.md
expect_refuse $J staging resolve d.md
printf '\nnew text (chat d.md)\n' >> docs/x/x.md
msg="staging: the session's name alone isn't provenance; the file's own mark is"
expect_refuse $J staging resolve d.md
printf 'Source: chat d.md (staged as d.md)\n' >> docs/x/x.md
msg="staging: once it does, the update resolves"
expect_pass sh -c "$J staging resolve d.md && test ! -e .jig/staging/d.md"

msg="staging: a new doc is written with a Source footer"
stage n.md this doc new docs/n/n.md; $J staging resolve n.md >/dev/null
expect_pass grep -q '^Source: chat n.md (staged as n.md)' docs/n/n.md

msg="staging: a destination outside the repo is refused"
stage e.md this doc new /tmp/jig-escape.md; expect_refuse $J staging resolve e.md
stage e.md this doc new ../escape.md; expect_refuse $J staging resolve e.md; rm .jig/staging/e.md

msg="staging: a .DS_Store is not a staged file"
: > .jig/staging/.DS_Store; expect_pass test "$($J staging)" = "nothing staged in .jig/staging"; rm .jig/staging/.DS_Store

msg="staging: a CRLF header parses"
printf -- '---\r\nstaged: true\r\ntarget: this\r\nkind: doc\r\nchange: new\r\ndestination: docs/c.md\r\nsource: chat c\r\nstatus: staged\r\n---\r\nbody\r\n' > .jig/staging/c.md
expect_pass $J staging; rm .jig/staging/c.md

msg="staging: a story waits for a spec that carries it"
stage s.md this user-story new 'a login flow'
expect_refuse $J staging resolve s.md
printf '# Login\n\nSource: chat s.md (staged as s.md)\n' > .jig/specs/login.md
msg="staging: with that spec, the story resolves"
expect_pass $J staging resolve s.md

msg="staging: decision rows append; other body lines refuse until handled"
stage r.md this decisions new docs/decisions.md '| D-001 | one | accepted | 2026-10-29 |\nand edit the glossary\n'
expect_refuse $J staging resolve r.md
stage r.md this decisions new docs/decisions.md '| D-001 | one | accepted | 2026-10-29 |\n'
expect_pass sh -c "$J staging resolve r.md && grep -q 'D-001 | one | accepted' docs/decisions.md"
msg="staging: a decision id already in the register is refused as new"
stage r.md this decisions new docs/decisions.md '| D-001 | again | accepted | 2026-10-29 |\n'
expect_refuse $J staging resolve r.md; rm .jig/staging/r.md

msg="staging: drop deletes the file and records nothing"
stage q.md this doc new docs/q.md
expect_pass sh -c "$J staging drop q.md && test ! -e .jig/staging/q.md && ! grep -q q.md .jig/config.json .jig/jobs.json && test -z \"\$(git status --porcelain -- .jig/config.json .jig/jobs.json)\""
git add -A && git commit -qm landed

stage w.md this doc new docs/w.md
msg="staging: the gate doesn't look at staging"
out=$($J gate 2>&1)
expect_pass sh -c "! echo \"\$0\" | grep -q 'waits while'" "$out"
msg="staging: pushing trunk with a file staged is accepted"
git init -q --bare "$T/st-remote.git" && git remote add origin "$T/st-remote.git"
expect_pass git push -q origin main

msg="staging: a target that isn't this repo or in repos.json is refused"
stage f.md other doc new docs/f.md
expect_refuse $J staging resolve f.md
msg="staging: a repos.json path that isn't a jig repo is refused, and nothing is written there"
mkdir -p "$T/plain" && python3 "$P/jig/jig.py" repos add other "$T/plain" >/dev/null
expect_pass sh -c "! $J staging resolve f.md 2>/dev/null && test ! -e '$T/plain/.jig'"
O="$T/other"; mkdir -p "$O/.jig" && git -C "$O" init -q -b main && python3 "$P/jig/jig.py" repos add other "$O" >/dev/null
msg="staging: listed in repos.json, it is forwarded into that repo's .jig/staging/"
expect_pass sh -c "$J staging resolve f.md && test -f '$O/.jig/staging/f.md' && test ! -e .jig/staging/f.md"
rm .jig/staging/w.md

msg="staging: a metarepo's release refuses while anything is staged; --force gets past it"
cd "$M" && stage m.md this doc new GUIDE.md
out=$($J release 2>&1); out2=$($J release --force 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'release waits while' && ! echo \"\$1\" | grep -q 'waits while'" "$out" "$out2"
rm .jig/staging/m.md
msg="staging: decisions resolved into a metarepo append the rows, write no changelog line, and print the one M3 wants"
git switch -q -c dec && stage dm.md this decisions new DECISIONS.md '| D-050 | x | open | 2026-10-30 |\n'
out=$($J staging resolve dm.md 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'add .- D-050.*CHANGELOG.md (M3)' && grep -q 'D-050' DECISIONS.md && git diff --quiet -- CHANGELOG.md" "$out"
git add -A; msg="staging: and M3 refuses that commit until the line is there"; expect_refuse git commit -qm "D-050: x"
git reset -q --hard && git switch -q main

msg="plugin: only the skills that change the repo, tag or write user config are user-only; read-only ones stay listed"
expect_pass test "$(grep -l '^disable-model-invocation: true' $P/../skills/*/SKILL.md | xargs -n1 dirname | xargs -n1 basename | sort | tr '\n' ' ')" = "adopt init release repos update "

msg="plugin: no skill description holds angle brackets (the desktop app reads them as XML tags)"
expect_refuse grep -lE '^description:.*[<>]' $P/../skills/*/SKILL.md $P/skills/*/SKILL.md

# ---------------------------------------------------------------- release
RL="$T/rl"; mkdir -p "$RL" && cd "$RL" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && printf 'dist/\n' > .gitignore && printf '0.0.0\n' > VERSION && git add -A && git commit -qm init
$J init >/dev/null && git add -A && git commit -qm board
board() { python3 -c "import json,sys; b=json.load(open('.jig/config.json')); $1; json.dump(b, open('.jig/config.json','w'), indent=2)"; }
msg="release: an undefined protocol refuses and points to /jig:release, naming the kind"
out=$($J release --version 1.0.0 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'jig release: rl (repo)' && echo \"\$0\" | grep -q \"isn't defined (.jig/scripts/release.sh still holds the template's TODO).*/jig:release\" && ! git tag | grep -q ." "$out"
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
git add -A && git commit -qm "release.sh: no steps yet"
msg="release: no artifacts named on the board refuses too"
out=$($J release --version 1.0.0 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'release.artifacts is empty'" "$out"
printf 'printf "%%s\\n" "$version" > VERSION\nmkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release'] = {'artifacts': ['dist/app-*.zip']}"
git add -A && git commit -qm "release protocol"
msg="release: a dirty tree refuses"
printf 'x\n' >> VERSION; expect_refuse $J release --version 1.0.0; git checkout -q -- VERSION
msg="release: a failing check.sh refuses, and release.sh never runs"
cp .jig/scripts/check.sh "$T/rl-check.sh"; sed -i.bak 's/^exit 0$/exit 4/' .jig/scripts/check.sh && rm .jig/scripts/check.sh.bak; git add -A && git commit -qm "check: broken"
out=$($J release --version 1.0.0 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'check.sh exited 4' && test ! -e dist && ! git tag | grep -q ." "$out"
cp "$T/rl-check.sh" .jig/scripts/check.sh; git add -A && git commit -qm "check: fixed"
msg="release: the first needs --version"
out=$($J release 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'no v\* tag yet'" "$out"
msg="release: --version 1.0.0 runs the script, commits what it changed, tags v1.0.0, prints the artifact"
out=$($J release --version 1.0.0 2>&1)
expect_pass sh -c "git tag | grep -qx v1.0.0 && test \"\$(git show v1.0.0:VERSION)\" = 1.0.0 && test \"\$(git log -1 --format=%s v1.0.0)\" = 'release v1.0.0' && echo \"\$0\" | grep -q 'dist/app-1.0.0.zip' && test -z \"\$(git status --porcelain)\"" "$out"
msg="release: patch is the default; --minor and --major bump their part"
expect_pass sh -c "$J release >/dev/null && $J release --minor >/dev/null && $J release --major >/dev/null && git tag | grep -qx v1.0.1 && git tag | grep -qx v1.1.0 && git tag | grep -qx v2.0.0"
msg="release: refused while a file is staged, listing it"
mkdir -p .jig/staging && printf -- '---\nstaged: true\n---\nx\n' > .jig/staging/s.md
out=$($J release 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'release waits while 1 file.*s.md' && ! git tag | grep -qx v2.0.1" "$out"
msg="release: --force releases anyway and names the staged file in the release commit"
expect_pass sh -c "$J release --force >/dev/null && git log -1 --format=%B v2.0.1 | grep -q 'left unresolved: s.md'"
rm .jig/staging/s.md
msg="release: a failing release.sh tags nothing and puts the tracked files back"
cp .jig/scripts/release.sh "$T/rl-release.sh"; printf 'exit 3\n' >> .jig/scripts/release.sh; git add -A && git commit -qm "release: broken"
out=$($J release 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'release.sh exited 3' && ! git tag | grep -qx v2.0.2 && test \"\$(cat VERSION)\" = 2.0.1 && test -z \"\$(git status --porcelain)\"" "$out"
cp "$T/rl-release.sh" .jig/scripts/release.sh; git add -A && git commit -qm "release: fixed"
msg="release: an artifact glob that matches nothing tags nothing"
board "b['release']['artifacts'].append('dist/*.dmg')"; git add -A && git commit -qm "release: dmg"
out=$($J release 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'this release made no file matching dist/\*.dmg' && ! git tag | grep -qx v2.0.2" "$out"
msg="release: last release's build left in dist/ doesn't count as this one's"
cp .jig/scripts/release.sh "$T/rl-release.sh"; sed -i.bak '/dist\/app-/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
board "b['release']['artifacts'] = ['dist/app-*.zip']"; git add -A && git commit -qm "release: no build"
out=$($J release 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'this release made no file matching dist/app-\*.zip' && ! git tag | grep -qx v2.0.2" "$out"
cp "$T/rl-release.sh" .jig/scripts/release.sh; git add -A && git commit -qm "release: build again"
msg="release: run from a subfolder, a refusal still puts every tracked file back"
mkdir -p sub && board "b['release']['artifacts'].append('dist/*.dmg')"; git add -A && git commit -qm "release: dmg again"
(cd sub && python3 ../.jig/jig.py release >/dev/null 2>&1)
expect_pass sh -c "test -z \"\$(git status --porcelain)\" && ! git tag | grep -qx v2.0.2"
msg="release: run from a subfolder, a release commits every tracked change"
board "b['release']['artifacts'] = ['dist/app-*.zip']"; git add -A && git commit -qm "release: zip only"
(cd sub && python3 ../.jig/jig.py release >/dev/null 2>&1)
expect_pass sh -c "git tag | grep -qx v2.0.2 && test \"\$(git show v2.0.2:VERSION)\" = 2.0.2 && test -z \"\$(git status --porcelain)\""
msg="release: off trunk it refuses"
git switch -q -c side && expect_refuse $J release; git switch -q main

# ---------------------------------------------------------------- repos
export JIG_CONFIG="$T/repos-cmd.json"
RP="$T/rp"; mkdir -p "$RP" && cd "$RP" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && git add -A && git commit -qm init && $J init >/dev/null
msg="repos add repo: this folder, under its own name and path"
$J repos add repo >/dev/null
expect_pass python3 -c "import json; e = json.load(open('$JIG_CONFIG'))['rp']; assert e['kind'] == 'repo' and e['path'].endswith('/rp'), e"
msg="repos add meta: the kind is recorded, and it says init --meta hasn't run"
expect_pass sh -c "$J repos add meta | grep -q 'not a metarepo yet' && python3 -c \"import json; assert json.load(open('$JIG_CONFIG'))['rp']['kind'] == 'meta'\""
msg="repos rename: this folder's entry gets the new name; the old one is gone"
$J repos rename tools >/dev/null
expect_pass python3 -c "import json; r = json.load(open('$JIG_CONFIG')); assert 'tools' in r and 'rp' not in r, r"
msg="repos rename: the repo's own name still finds it"
expect_pass python3 -c "
import importlib.util, sys; s = importlib.util.spec_from_file_location('j', '.jig/jig.py'); j = importlib.util.module_from_spec(s); s.loader.exec_module(j)
assert j.repo_path('rp') is not None and j.repo_path('tools') is not None"
msg="repos: the list marks this folder"
expect_pass sh -c "$J repos | grep -q 'tools .*← here'"

rm -rf "$T"
exit $fail
