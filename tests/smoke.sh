#!/usr/bin/env bash
# End-to-end check of the rules in throwaway repos: jobs in worktrees, the hooks installed
# from the template. Every case prints PASS or the refusal it expected.
#   bash tests/smoke.sh               every section, in parallel (JIG_SMOKE_JOBS, default the cores)
#   bash tests/smoke.sh <section>...  only those, for a quick rerun
#   bash tests/smoke.sh --list        the section names
# Each section runs in its own process and temp folder, so sections, and whole runs started at
# the same time, are independent. Output is printed section by section, in file order, and the
# last case proves the user's real jig config was left alone.
set -u
# Listing and hash of every file under a folder; empty when it doesn't exist.
cfg_state() { python3 - "$1" <<'PY'
import hashlib, os, sys
for d, _, fs in sorted(os.walk(sys.argv[1])):
    print(d)
    for f in sorted(fs):
        p = os.path.join(d, f); print(p, hashlib.sha256(open(p, 'rb').read()).hexdigest())
PY
}
REAL_CFG="$HOME/.config/jig"
P="$(cd "$(dirname "$0")/.." && pwd)/plugin/templates"
J="python3 .jig/jig.py"
# Old layouts are rebuilt from this repo's own history, so the smoke test needs a full clone.
R="$(cd "$(dirname "$P")/.." && pwd)"
JR="$R"                                # $R is reused as a repo by the R6 sections
UP="python3 $P/jig/jig.py update"     # the plugin's copy, as the update skill runs it
FX="$R/tests/fixtures"
fail=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; fail=1; }
expect_pass() { if "$@" >/dev/null 2>&1; then ok "$msg"; else bad "$msg"; fi; }
expect_refuse() { if "$@" >/dev/null 2>&1; then bad "$msg (was accepted)"; else ok "$msg"; fi; }
undo() { git reset -q; git checkout -q -- .; git clean -fdq; }

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
    cp $t/AGENTS.md $t/CLAUDE.md . && cp -r $t/jig jig
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
fixture() {  # fixture <generation>: a fresh repo from tests/fixtures/<generation>, committed
  mkdir -p "$T/fx-$1" && cp -R "$FX/$1/repo/." "$T/fx-$1/" && cd "$T/fx-$1"
  git init -q -b main && git config user.email t@t && git config user.name t
  git add -A && git commit -qm init && cp -R "$FX/$1/git/." .git/
}
lines() { wc -l < "$LOG" | tr -d ' '; }
mrel() { $J release 2>&1; }
branch_commit() {  # branch_commit <branch> <subject>: commit what's staged on a new branch
  git switch -q -c "$1" && git commit -qm "$2"; }
m2() { printf '%s\n' "$1" >> DECISIONS.md && printf -- '- D-001\n' >> CHANGELOG.md && git add -A
  $J check --staged; local rc=$?; git reset -q; git checkout -q -- DECISIONS.md CHANGELOG.md; return $rc; }
stage() {  # stage <file> <target> <kind> <change> <destination> [body]
  printf -- '---\nstaged: true\ntarget: %s\nkind: %s\nchange: %s\ndestination: %s\nsource: chat %s\nstatus: staged\n---\n%b' \
    "$2" "$3" "$4" "$5" "$1" "${6:-# Title\n\nbody\n}" > ".jig/staging/$1"; }
board() { python3 -c "import json,sys; b=json.load(open('.jig/config.json')); $1; json.dump(b, open('.jig/config.json','w'), indent=2)"; }
dec() { printf '| D-%s | x | accepted | 2026-10-30 |\n' "$1" >> DECISIONS.md && printf -- '- D-%s\n' "$1" >> CHANGELOG.md && git add -A; }
foldin() { sed -i.bak -e 's/^- \[ \]/- [x]/' -e 's/___/smoke/g' .jig/handoffs/*.md && rm .jig/handoffs/*.bak; }
setwf() { python3 -c "import json, sys; c = json.load(open('.jig/config.json')); c['workflow'] = json.loads(sys.argv[1]); json.dump(c, open('.jig/config.json', 'w'), indent=2)" "$1"; }
hooksnap() { find .git/hooks -type f | sort | xargs shasum 2>/dev/null; }
hrsurvey() { python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
$1"; }
ax() {  # ax <dir> [setup command]: the fixture, the setup run in it, committed
  mkdir -p "$1" && cp -R "$FX/ai-dev/repo/." "$1/" && cd "$1"
  git init -q -b main && git config user.email t@t && git config user.name t
  if [ -n "${2:-}" ]; then eval "$2"; fi
  git add -A && git commit -qm init && cp -R "$FX/ai-dev/git/." .git/
}
mkf() { for f in "$@"; do mkdir -p "$(dirname "$f")" && printf 'x\n' > "$f"; done; }
renamed() { git diff --cached -M --name-status | grep -q "^R100	$1	$2\$"; }
wt() { git -c core.hooksPath=/dev/null worktree add -q "$@" 2>/dev/null; }
pcnew() {  # pcnew <dir>: a git repo with the template copied in, nothing committed
  mkdir -p "$1" && cd "$1" && git init -q -b main && git config user.email t@t && git config user.name t
  cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" .; }
pcfold() { sed -i.bak -e 's/^- \[ \]/- [x]/' -e 's/___/smoke/g' .jig/handoffs/*.md && rm .jig/handoffs/*.bak; }
setjson() {  # setjson <file> <key> <value>
  python3 -c "import json,sys; f=sys.argv[1]; d=json.load(open(f)); d[sys.argv[2]]=sys.argv[3]; json.dump(d, open(f,'w'), indent=2)" "$@"; }
gate_ok() { out=$($J gate "$1" 2>&1); rc=$?; git worktree remove --force ".git/jig/worktrees/gate-$1" 2>/dev/null; return $rc; }
setentry() { python3 -c "import json,sys; f='.jig/meta.json'; d=json.load(open(f)); d['entry_files']=sys.argv[1:]; json.dump(d, open(f,'w'), indent=2)" "$@"; }
emerge() {  # emerge <branch> <subject> <file>...: commit the staged change on a branch, review it, merge it into main
  b=$1 s=$2; shift 2; git switch -q -c "$b" && git add -- "$@" && git commit -qm "$s" && $J reviewed >/dev/null \
    && git switch -q main && git merge -q --no-ff --no-edit "$b"; }
underhead() { python3 -c "import sys; f='CHANGELOG.md'; s=open(f).read(); open(f,'w').write(s.replace('## Unreleased\n', '## Unreleased\n'+sys.argv[1]+'\n', 1))" "$1"; }
emergejob() {  # emergejob <job> <subject>: open a job in $EM, hand it off, and merge it with --subject
  (cd "$EM" && $J open "$1" --branch "b-$1" --owns "products/$1.md" >/dev/null && git add -A && git commit -qm "TOOL: open $1" \
    && cd ".git/jig/worktrees/b-$1" && printf '# x\n' > "products/$1.md" && printf -- "- $1\n" >> CHANGELOG.md \
    && git add -A && git commit -qm "PRODUCTS: $1" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold \
    && git add -A && git commit -qm "TOOL: note $1" && cd "$EM" && $J merge "$1" --subject "$2" >/dev/null); }
sbprops() { git -C "$SM" branch --list 'propose/*' | wc -l | tr -d ' '; }
brow() { printf '| %s | DECISIONS.md § D-001: %s | api/a.py, %s (%s) | owner, 2026-11-02 | %s |\n' "$@"; }
sbland() {  # sbland <proposal branch> <term>: the metarepo writes it, merges and releases
  (cd "$SM" && git switch -q "$1" && printf '\n### %s\n' "$2" >> README.md && printf -- '- %s\n' "$2" >> CHANGELOG.md \
    && git add -A && git commit -qm "GLOSSARY: $2" && $J reviewed >/dev/null && git switch -q main \
    && git merge -q --no-ff --no-edit "$1" && $J release >/dev/null); }
sbbump() { setjson .jig/para.json pin "$1" && $J init --para >/dev/null 2>&1 && git add -A && git commit -qm "meta: sbm → $1"; }
fb() {  # fb <dir> <file> [from]: a feedback report, with a from: line when given one
  mkdir -p "$1" && printf -- '---\nstaged: true\ntarget: this\nkind: feedback\nchange: new\ndestination: a fix in jig\nsource: chat %s\n%bjig_version: abc123\nstatus: staged\n---\n# R\n' \
    "$2" "${3:+from: $3\n}" > "$1/$2"; }
fbj() { fb "$@" && sed -i.bak 's/^target: this$/target: jig/' "$1/$2" && rm "$1/$2.bak"; }

# ---------------------------------------------------------------- rules
sec_rules() {
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

msg="R3: outside a metarepo, a CHANGELOG.md the job doesn't own or share is refused"
( cd "$T" && printf '# C\n' > CHANGELOG.md && git add -A && git commit -qm trunk6 )
$J sync >/dev/null 2>&1
printf -- '- x\n' >> CHANGELOG.md; git add -A; out=$(git commit -qm cl 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'R3 CHANGELOG.md is not job L1'" "$out"

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

msg="init: .jig/ holds jig.py, RULES.md, docs-page.md, config.json, jobs.json, the five scripts and staging/.gitignore, nothing else"
expect_pass test "$(find .jig -type f | LC_ALL=C sort | tr '\n' ' ')" = ".jig/RULES.md .jig/config.json .jig/docs-page.md .jig/jig.py .jig/jobs.json .jig/scripts/check.sh .jig/scripts/format.sh .jig/scripts/publish.sh .jig/scripts/release.sh .jig/scripts/setup.sh .jig/staging/.gitignore "

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
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs/devkit docs/gpio main
printf '# Devkit\n' > docs/devkit/devkit.md && printf '# GPIO\n' > docs/gpio/gpio.md
printf 'int led = 48;\n' > main/app.c && printf 'CONFIG_ESPTOOLPY_FLASHSIZE_8MB=y\n' > sdkconfig
git add -A && git commit -qm init && $J init >/dev/null && board "b['boards'] = ['docs/devkit/devkit.md']" && git add -A && git commit -qm board

msg="survey: names a board page no docmap entry covers"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['boards_unmapped'] == ['docs/devkit/devkit.md'], r['boards_unmapped']"

# The system page comes first, so a docmap that stops at the first match hides the board page.
python3 - <<'EOF'
import json; b = json.load(open('.jig/config.json'))
b['docmap'] = {'docs/gpio/gpio.md': ['main/**'],
               'docs/devkit/devkit.md': ['main/**', 'sdkconfig*']}
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
expect_pass test -n "$(echo "$out" | grep -F docs/gpio/gpio.md)" -a -n "$(echo "$out" | grep -F docs/devkit/devkit.md)"

$J open H1 --spec t --owns 'main/**' >/dev/null && $J open H2 --spec t --owns 'sdkconfig*' >/dev/null
git add -A && git commit -qm "open H1 H2"
cd .git/jig/worktrees/H1 && printf 'int led = 2;\n' > main/app.c && git add -A && git commit -qm led
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1; git add -A && git commit -qm note
msg="fold-in: changing a board's code asks about its board page and its system page"
expect_pass sh -c "grep -q -- '- \[ \] docs/devkit/devkit.md' .jig/handoffs/H1-*.md && grep -q -- '- \[ \] docs/gpio/gpio.md' .jig/handoffs/H1-*.md"
sed -i.bak 's|- \[ \] docs/gpio/gpio.md — updated / no change because ___|- [x] docs/gpio/gpio.md — no change because the pin is board wiring|' .jig/handoffs/H1-*.md
rm -f .jig/handoffs/*.bak && git add -A && git commit -qm "answer gpio"
msg="gate: refuses while the board page's fold-in line is unanswered"
expect_refuse sh -c "cd '$H' && $J gate H1"
sed -i.bak 's|- \[ \] docs/devkit/devkit.md — updated / no change because ___|- [x] docs/devkit/devkit.md — updated: LED on GPIO 2|' .jig/handoffs/H1-*.md
rm -f .jig/handoffs/*.bak && git add -A && git commit -qm "answer devkit"
msg="gate: passes once the board page's line is answered"
expect_pass sh -c "cd '$H' && $J gate H1"

cd "$H/.git/jig/worktrees/H2" && printf 'CONFIG_ESPTOOLPY_FLASHSIZE_16MB=y\n' > sdkconfig && git add -A && git commit -qm flash
$J reviewed >/dev/null; $J handoff >/dev/null 2>&1
msg="fold-in: changing only a board's config file asks about its board page"
expect_pass grep -q -- '- \[ \] docs/devkit/devkit.md' .jig/handoffs/H2-*.md

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
}

# ---------------------------------------------------------------- update
sec_update() {
# Old layouts are rebuilt from this repo's own history, so the smoke test needs a full clone.


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
  if [ "$name" = eaec973-dot ]; then
    msg="update $name: the seeded docs/README.md is proposed for deletion as a copy of RULES.md, with the AGENTS.md line naming it"
    expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/README.md: a copy of .jig/RULES.md, which update keeps current: delete it, .*AGENTS.md:[0-9]'" "$out"
  fi

  msg="update $name: --apply renames the repo's files, never edits them"
  $UP --apply >/dev/null 2>&1
  expect_pass python3 -c "
import subprocess
allowed = {'$board', '.jig/config.json', '.jig/jobs.json', '.aidev/aidev.py', 'jig/jig.py', '.jig/jig.py',
           '.aidev/RULES.md', 'jig/RULES.md', '.jig/RULES.md', '.jig/docs-page.md', '.gitignore', '.jig/scripts/setup.sh', '.jig/scripts/release.sh', '.jig/scripts/publish.sh', '.jig/staging/.gitignore'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or set(paths) <= allowed, line"

  msg="update $name: every board glob that matched before still matches"
  expect_pass python3 -c "$GLOBS" "$P/jig/jig.py" "$board"

  msg="update $name: hooks read trunk's .jig/jig.py and none was kept as .local; .git/jig/enabled, no .git/aidev, no old ignore line"
  expect_pass sh -c "grep -q 'git show main:.jig/jig.py' .git/hooks/pre-commit && ! ls .git/hooks/*.local && test -f .git/jig/enabled && test ! -e .git/aidev && ! grep -q worktrees .gitignore"

  msg="update $name: nothing tracked is left in jig/, .aidev/, specs/ or ledgers/; the config is stamped 8, with release.sh and publish.sh added"
  expect_pass sh -c "test -z \"\$(git ls-files jig .aidev specs ledgers .jig/lanes.json)\" && ! grep -q payload .jig/config.json && grep -q '\"version\": 9' .jig/config.json && git ls-files --error-unmatch .jig/scripts/release.sh .jig/scripts/publish.sh"

  msg="update $name: publish.sh is added from the template, TODO line included, and staged"
  expect_pass sh -c "git diff --cached --name-status | grep -q '^A.\.jig/scripts/publish.sh$' && grep -q '^# TODO: publish steps\.' .jig/scripts/publish.sh && test -x .jig/scripts/publish.sh"

  if [ -n "$had_setup" ]; then
    msg="update $name: its setup.sh moves to .jig/scripts/ untouched"
    expect_pass sh -c "git diff --cached --name-status | grep -q '^R100.jig/scripts/setup.sh.\.jig/scripts/setup.sh'"
  else
    msg="update $name: a repo without setup.sh gets the template's, staged, and the post-merge hook"
    expect_pass sh -c "cmp -s .jig/scripts/setup.sh '$P/jig/scripts/setup.sh' && test -x .jig/scripts/setup.sh && git diff --cached --name-status | grep -q '^A.\.jig/scripts/setup.sh' && grep -q 'hook post-merge' .git/hooks/post-merge"
  fi

  git ls-files | grep -vx docs/README.md > "$T/$name.paths"   # 0.2.x seeded none
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

  # Every layout but 0.2.x's seeded docs/README.md, a copy of the rules that froze.
  want=$([ "$style" = jig2 ] && echo '[]' || echo "[('docs/README.md', 'copy')]")
  msg="update $name: after the commit, survey's only homeless file is the seeded docs/README.md, a copy"
  expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert [(e['path'], e['kind']) for e in r['homeless']] == $want, r['homeless']"
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
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'git worktree remove .*up-extra'" "$out"
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
msg="update: jig/specs/ beside .jig/specs/ is judged per file: _template.md moves, new.md stays"
expect_pass sh -c "echo \"\$0\" | grep -q 'jig/specs/_template.md → .jig/specs/_template.md' && ! echo \"\$0\" | grep -q 'both exist'" "$out"
msg="update warning: --apply proceeds; the extra file, .jig/specs/new.md and the unknown key stay"
rc=$(code $UP --apply)
expect_pass sh -c "test $rc = 0 && test -f jig/notes.txt && test ! -e jig/specs/_template.md && test -f .jig/specs/_template.md && test -f .jig/specs/new.md && grep -q '\"extra\"' .jig/config.json"


# Firmware, as eaec973's init set it up: docs/HARDWARE.md and the blank skill template.
old "$T/up-fw" eaec973 dot
mkdir -p .claude/skills/_skill-template
git -C "$R" show eaec973:plugin/templates/docs/HARDWARE.md > docs/HARDWARE.md
git -C "$R" show eaec973:plugin/templates/skill-template/SKILL.md > .claude/skills/_skill-template/SKILL.md
printf '#!/bin/sh\nexit 2\n' > scripts/check.sh && git add -A && git commit -qm fw
out=$($UP 2>&1)
msg="update: the dry run lists docs/HARDWARE.md and the old skill template as repo files to review"
expect_pass sh -c "echo \"\$0\" | grep -q '^Repo files to review' && echo \"\$0\" | grep -q \"docs/HARDWARE.md: still the template's TODOs: remove it\" && echo \"\$0\" | grep -q '.claude/skills/_skill-template/: the old blank skill template, unchanged: remove it'" "$out"
msg="update: no template diff; eaec973's Lanes block is proposed for replacement with the Rulebook line, by its lines"
expect_pass sh -c "! echo \"\$0\" | grep -q 'against the template' && echo \"\$0\" | grep -q '^  AGENTS.md: lines 24–28, .## Lanes (parallel sessions)., are a block jig retired: replace it, heading to the next heading, with .- Rulebook .\.jig/RULES\.md.'" "$out"
msg="update: on the run that adds .jig/scripts/setup.sh to eaec973's layout, its setup: line is proposed"
expect_pass sh -c "test ! -e .jig/scripts/setup.sh && echo \"\$0\" | grep -q '^  AGENTS.md: names no .\.jig/scripts/setup\.sh.: add under ## Commands .- setup:'" "$out"
msg="update: a docs/HARDWARE.md that holds a board is proposed as docs/<board>/<board>.md, registered in boards"
sed -i.bak 's/^- MCU \/ board: TODO.*/- MCU \/ board: ESP32-S3-DevKitC-1 (N16R8)/' docs/HARDWARE.md && rm docs/HARDWARE.md.bak
git commit -qam board-page
expect_pass sh -c "$UP 2>&1 | grep -q 'rename it to docs/esp32-s3-devkitc-1/esp32-s3-devkitc-1.md, list it under boards'"
msg="update: --apply leaves the files to review alone; a failing check is reported, exits 1, undoes nothing"
out=$($UP --apply 2>&1); rc=$?
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q '.jig/scripts/check.sh FAILED (exit 2)' && test -f docs/HARDWARE.md && test -f .claude/skills/_skill-template/SKILL.md && git diff --cached --name-status | grep -q 'R100.*\.jig/specs/_template.md'" "$out"

cd "$T/up-warn" && git commit -qm applied
msg="update: after --apply, a kept warning still reads up to date, exit 0"
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | head -1 | grep -qx 'up to date'" "$out"

# Every generation, from the made-up repos in tests/fixtures/: each ends with the same jig
# paths and board keys, and every file it doesn't remove moves byte for byte.
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
jig = {'.jig/config.json', '.jig/jobs.json', '.jig/jig.py', '.jig/RULES.md', '.jig/docs-page.md', '.jig/scripts/setup.sh', '.jig/scripts/release.sh', '.jig/scripts/publish.sh',
       '.jig/ledgers/DEFERRED.md', '.jig/staging/.gitignore', '.gitignore'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or (status == 'D' and paths[0] in removed) or paths[-1] in jig, line" "$removed $board"

  case $gen in
    ai-dev)
      msg="update $gen: REVIEW_LEDGER.md's untaken rows are DEFERRED.md; its taken rows are gone"
      expect_pass sh -c "grep -q L-001 .jig/ledgers/DEFERRED.md && grep -q L-003 .jig/ledgers/DEFERRED.md && grep -q L-005 .jig/ledgers/DEFERRED.md && ! grep -q 'L-00[24]' .jig/ledgers/DEFERRED.md && test ! -e docs/REVIEW_LEDGER.md"
      msg="update $gen: a root HARDWARE.md naming a board moves to docs/<board>/<board>.md, byte for byte, and is registered in boards"
      expect_pass sh -c "git diff --cached -M --name-status | grep -q '^R100.HARDWARE.md.docs/devkit-s3/devkit-s3.md' && python3 -c \"import json; assert json.load(open('.jig/config.json'))['boards'] == ['docs/devkit-s3/devkit-s3.md']\"";;
    claude-lane)
      msg="update $gen: board.json is the board, merged entries and claude-lane's own keys gone; the folder is gone"
      expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['trunk'] == 'main' and 'lanes' not in b and 'seen' not in b and 'main' not in b and 'next' not in b['reserve']['section'], b\" && test ! -e .claude/claude-lane && git diff --cached -M --name-status | grep -q '^R100.*old-2026-01-01.md'";;
    dot-jig-v7)
      msg="update $gen: the one-file board splits: config.json without jobs or log, an empty jobs.json, no lanes.json"
      expect_pass sh -c "python3 -c \"import json; c = json.load(open('.jig/config.json')); assert c['version'] == 9 and not {'lanes', 'log'} & set(c) and json.load(open('.jig/jobs.json')) == {}, c\" && test ! -e .jig/lanes.json && echo \"\$0\" | grep -q 'board: lanes.old (merged)' && echo \"\$0\" | grep -q 'board: log'" "$out";;
  esac

  msg="update $gen: a second update is up to date"
  expect_pass test "$($UP 2>&1)" = "up to date"

  msg="update $gen: the update commits with the hooks on, and survey then finds no homeless files"
  expect_pass sh -c "git commit -qm update && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['homeless'] == [], r['homeless']\""
  git ls-files .jig > "$T/fx-$gen.paths"
  # boards is the repo's content, not jig's layout: only ai-dev's fixture has a board.
  python3 -c "import json; print(sorted(set(json.load(open('.jig/config.json'))) - {'boards'}), json.load(open('.jig/jobs.json')))" > "$T/fx-$gen.keys"
done
msg="update: every generation ends with the same jig paths and board keys"
expect_pass sh -c "cd '$T' && for n in ai-dev jig-0.2 dot-jig-v7; do cmp -s fx-claude-lane.paths fx-\$n.paths && cmp -s fx-claude-lane.keys fx-\$n.keys || exit 1; done"

msg="update: a root specs/ file that isn't Markdown stays, with a warning"
old "$T/up-js" eaec973 dot
printf 'it()\n' > specs/app.spec.js && git add -A && git commit -qm js
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'specs/app.spec.js is in specs/ but isn.t Markdown' && ! echo \"\$0\" | grep -q 'app.spec.js → '" "$out"
}

# ---------------------------------------------------------------- the board, split
sec_board_split() {
B="$T/jobs"; mkdir -p "$B" && cd "$B" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs src
printf '# D\n\n## 1 One\n' > docs/d.md && printf 'x=1\n' > src/a.py
git add -A && git commit -qm init && $J init >/dev/null

msg="init: config.json holds the settings, no jobs and no log; jobs.json is empty"
expect_pass python3 -c "
import json; c = json.load(open('.jig/config.json')); j = json.load(open('.jig/jobs.json'))
assert sorted(c) == sorted(['version', 'name', 'trunk', 'common', 'append_files', 'reserve', 'docmap', 'not_docs', 'release', 'reference_files']), c
assert c['version'] == 9 and j == {}, (c, j)"
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
}

# ---------------------------------------------------------------- worktree setup
sec_worktree_setup() {
W="$T/setup"; LOG="$T/setup.log"
mkdir -p "$W" && cd "$W" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p src && printf 'x=1\n' > src/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="setup: after init, .jig/scripts/setup.sh is executable, all TODOs, and exits 0"
expect_pass sh -c "test -x .jig/scripts/setup.sh && grep -q TODO .jig/scripts/setup.sh && .jig/scripts/setup.sh"

printf '#!/bin/sh\necho "set up $(pwd -P)"\npwd -P >> "%s"\n' "$LOG" > .jig/scripts/setup.sh
git commit -qam "setup logs" && : > "$LOG"

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
}

# ---------------------------------------------------------------- metarepo
sec_metarepo() {
M="$T/meta"; mkdir -p "$M" && cd "$M" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && git add -A && git commit -qm "meta-init"
msg="meta: init --meta writes no GLOSSARY.md, a ## Glossary in README.md, and names README.md in entry_files"
expect_pass sh -c "test ! -e GLOSSARY.md && grep -qx '## Glossary' README.md && grep -q '\"README.md\"' .jig/meta.json"

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
git switch -q -c b4
msg="meta M3: a README.md change outside ## Glossary needs no changelog line"
perl -0pi -e 's/^## Glossary$/## Install\nrun it\n\n## Glossary/m' README.md
expect_pass git commit -qam "README: install"
msg="meta M3: a README.md change inside ## Glossary needs the changelog line"
printf '\n### rune\nx\n' >> README.md && git add -A
expect_refuse git commit -qm "GLOSSARY: rune"; git reset -q --hard && git switch -q main

msg="meta M4: a direct commit on main is refused"
printf '\n### mote\n' >> README.md && printf -- '- mote\n' >> CHANGELOG.md && git add -A
expect_refuse git commit -qm "GLOSSARY: mote"; git reset -q --hard

msg="meta M5: a --no-ff merge of an unreviewed branch is refused"
expect_refuse git merge -q --no-ff --no-edit b1; git merge --abort 2>/dev/null
msg="meta: the same merge once the branch is reviewed is accepted"
git switch -q b1 && $J reviewed >/dev/null && git switch -q main
expect_pass git merge -q --no-ff --no-edit b1
msg="meta: a git pull of a reviewed branch into main is accepted"
git switch -q -c b3 && printf '\n### seam\n' >> README.md && printf -- '- seam\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: seam" && $J reviewed >/dev/null && git switch -q main
expect_pass git pull -q --no-ff --no-edit . b3

msg="meta: release tags v0.2.0 (minor is a metarepo's default)"
expect_pass sh -c "$J release && git tag | grep -qx v0.2.0"

git switch -q -c b2 && printf '\n### grain\n' >> README.md && printf -- '- grain\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: grain" && git switch -q main
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

msg="meta R3: a job given only GLOSSARY.md commits a term with its CHANGELOG.md line"
$J open gl --branch b-gl --owns GLOSSARY.md >/dev/null && git add -A && git commit -qm "TOOL: open gl"
cd .git/jig/worktrees/b-gl && printf '\n## mote\n' >> GLOSSARY.md && printf -- '- mote\n' >> CHANGELOG.md && git add -A
expect_pass git commit -qm "GLOSSARY: mote"
msg="meta R3: the same job rewriting CHANGELOG.md is refused"
printf '\n## seam\n' >> GLOSSARY.md && printf '# Changelog\n\n## Unreleased\n- seam\n' > CHANGELOG.md && git add -A
out=$(git commit -qm "GLOSSARY: seam" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'R3 CHANGELOG.md'" "$out"
msg="meta R3: the same job deleting CHANGELOG.md is refused"
git rm -q CHANGELOG.md && printf 'x\n' > notes.txt && git add -A
out=$(git commit -qm "TOOL: notes" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'R3 CHANGELOG.md'" "$out"
cd "$M"

# A decision row and the pages citing it are one home: changing the row asks those pages.
MF="$T/meta-fold"; mkdir -p "$MF" && cd "$MF" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && setentry DECISIONS.md README.md 'pages/*.md'
mkdir -p pages notes && printf '| D-007 | x | accepted | 2026-11-01 |\n' >> DECISIONS.md
printf '# A\n\nWe keep it short, as D-007 says.\n' > pages/a.md
printf '# B\n\nSee D-0070.\n' > pages/b.md
printf '# C\n\nD-007\n' > notes/c.md
git add -A && git -c core.hooksPath=/dev/null commit -qm "meta-init"
$J open d7 --branch b-d7 --shares DECISIONS.md >/dev/null && git add -A && git commit -qm "TOOL: open d7"
cd .git/jig/worktrees/b-d7
sed -i.bak 's/^| D-007 | x |/| D-007 | y |/' DECISIONS.md && rm DECISIONS.md.bak && printf -- '- D-007 y\n' >> CHANGELOG.md
git add -A && git commit -qm "D-007: y" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/*.md)
msg="meta fold-in: a changed row asks the entry page citing it in passing, naming the id"
expect_pass grep -qx -- '- \[ \] pages/a.md — updated / no change because ___   (D-007)' "$note"
msg="meta fold-in: no line for D-0070's page, a page outside entry_files, the register or CHANGELOG.md"
expect_pass sh -c "! grep -qE 'pages/b.md|notes/c.md|DECISIONS.md|CHANGELOG.md|no code changed' '$note'"
git add -A && git commit -qm "TOOL: note d7" && cd "$MF"
msg="meta fold-in: the gate refuses the note while the line is unanswered"
expect_refuse gate_ok d7
cd .git/jig/worktrees/b-d7 && pcfold && git add -A && git commit -qm "TOOL: answer d7" && cd "$MF"
msg="meta fold-in: and passes once it is answered"
expect_pass gate_ok d7
$J open s7 --branch b-s7 --shares DECISIONS.md >/dev/null && git add -A && git commit -qm "TOOL: open s7"
cd .git/jig/worktrees/b-s7
sed -i.bak 's/^| D-007 | x | accepted |/| D-007 | x | superseded by D-012 |/' DECISIONS.md && rm DECISIONS.md.bak
printf '| D-012 | z | accepted | 2026-11-02 |\n' >> DECISIONS.md && printf -- '- D-007, D-012\n' >> CHANGELOG.md
git add -A && git commit -qm "D-007, D-012: z" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
msg="meta fold-in: a row marked superseded by asks the page citing it"
expect_pass grep -qx -- '- \[ \] pages/a.md — updated / no change because ___   (D-007)' .jig/handoffs/*.md
cd "$M"
}

# ---------------------------------------------------------------- staging
sec_staging() {
ST="$T/st"; mkdir -p "$ST" && cd "$ST" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

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

msg="staging: a feature request is listed, and its header passes"
stage fr.md this feature-request new 'export to csv' 'I want it to export the log as a csv.\n'
expect_pass sh -c "$J staging >/dev/null && $J staging | grep -q fr.md && ! $J staging | grep -qi 'not one of'"
msg="staging: a request waits for a spec that carries it, saying it resolves into a spec"
out=$($J staging resolve fr.md 2>&1)
expect_pass sh -c "! $J staging resolve fr.md 2>/dev/null && echo \"\$0\" | grep -q 'a request resolves into a spec'" "$out"
printf '# Export\n\nSource: chat fr.md (staged as fr.md): "I want it to export the log as a csv."\n' > .jig/specs/export.md
msg="staging: with that spec, the request resolves"
expect_pass sh -c "$J staging resolve fr.md && test ! -e .jig/staging/fr.md"
msg="staging: an update request naming spec A waits while only spec B carries its mark"
printf '# A\n' > .jig/specs/fra.md
stage fu.md this feature-request update .jig/specs/fra.md 'I want the export to include dates.\n'
printf '# B\n\nSource: chat fu.md (staged as fu.md)\n' > .jig/specs/frb.md
expect_refuse $J staging resolve fu.md
printf '\nSource: chat fu.md (staged as fu.md): "I want the export to include dates."\n' >> .jig/specs/fra.md
msg="staging: once spec A carries it, the update request resolves"
expect_pass sh -c "$J staging resolve fu.md && test ! -e .jig/staging/fu.md"
msg="staging: a misspelt kind is refused, naming the kinds"
stage fk.md this feature new 'x'
out=$($J staging resolve fk.md 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'feature-request' && echo \"\$0\" | grep -q 'is not one of'" "$out"; rm .jig/staging/fk.md

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

msg="plugin: only the skills that change the repo, tag, write user config or report on jig are user-only; read-only ones stay listed"
expect_pass test "$(grep -l '^disable-model-invocation: true' $P/../skills/*/SKILL.md | xargs -n1 dirname | xargs -n1 basename | sort | tr '\n' ' ')" = "adopt feedback init redocument release repos update "

msg="plugin: no skill description holds angle brackets (the desktop app reads them as XML tags)"
expect_refuse grep -lE '^description:.*[<>]' $P/../skills/*/SKILL.md $P/skills/*/SKILL.md
}

# ---------------------------------------------------------------- pararepo
sec_pararepo() {
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
msg="para release: release.sh untouched from the template and no artifacts: tags v0.1.0"
out=$($J release --version 0.1.0 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && git tag | grep -qx v0.1.0 && grep -q 'TODO: release protocol' .jig/scripts/release.sh" "$out"
msg="para release: with two Open rows it also makes the one proposal branch"
mkdir -p .jig/ledgers && cp "$P/ledgers/BUFFER.md" .jig/ledgers/BUFFER.md
for i in 1 2; do printf '| B%s | DECISIONS.md § D-001: x | api/a.py, y | owner, 2026-11-02 | Open |\n' $i >> .jig/ledgers/BUFFER.md; done
git add -A && git commit -qm "buffer: B1, B2" && $J release >/dev/null 2>&1
expect_pass sh -c "git tag | grep -qx v0.1.1 && test \$(git -C mrclone branch --list 'propose/*' | wc -l) = 1 && git -C mrclone rev-parse -q --verify refs/heads/propose/pr-buffer-v0.1.1"
paratip=$(git rev-parse HEAD)
msg="para release: pin set to main is refused, naming the pin, and tags nothing"
python3 -c "import json; p = json.load(open('.jig/para.json')); p['pin'] = 'main'; json.dump(p, open('.jig/para.json', 'w'), indent=2)"
$J init --para >/dev/null 2>&1 && git add -A && git commit -qm "pin main" >/dev/null 2>&1
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'refused: the pin main' && ! git tag | grep -qx v0.1.2" "$out"
git reset -q --hard "$paratip" && $J init --para >/dev/null 2>&1
msg="para release: a hand-edited header committed with --no-verify is refused, naming P1"
sed -i.bak 's/is written only by branch/is written by anyone/' AGENTS.md && rm AGENTS.md.bak && git commit -qam header --no-verify
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'refused: P1' && ! git tag | grep -qx v0.1.2" "$out"
git reset -q --hard "$paratip"
msg="para release: a metarepo that isn't registered is refused, naming jig repos add meta"
out=$(JIG_CONFIG="$T/none.json" $J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'refused: .*jig repos add meta' && ! git tag | grep -qx v0.1.2" "$out"
msg="para release: a tracked cache and a malformed buffer row are refused, naming P3 and P2"
git add -f .jig/meta-cache/PIN && printf '| B3 | x | y | z | Settling |\n' >> .jig/ledgers/BUFFER.md && git commit -qam cache --no-verify
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'refused: P3 .jig/meta-cache/PIN' && echo \"\$0\" | grep -q 'refused: P2 .*row B3 is Settling' && ! git tag | grep -qx v0.1.2" "$out"
msg="para release: a P3 refusal leaves the tree clean, so the next release names P3 again"
out=$($J release 2>&1)
expect_pass sh -c "test -z \"\$(git status --porcelain)\" && echo \"\$1\" | grep -q 'refused: P3' && ! echo \"\$1\" | grep -q 'commit or stash'" "" "$out"
git reset -q --hard "$paratip" && $J init --para >/dev/null 2>&1
msg="para release: a second row with an id already taken is refused, naming P2"
printf '| B1 | DECISIONS.md § D-001: twin | api/a.py | owner, 2026-11-02 | Open |\n' >> .jig/ledgers/BUFFER.md && git commit -qam twin --no-verify
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'refused: P2 .*more than one row B1' && ! git tag | grep -qx v0.1.2" "$out"
git reset -q --hard "$paratip"
msg="para release: a pin on a tag made by hand in the metarepo is refused, naming the pin"
git -C mrclone tag v0.5.0
python3 -c "import json; p = json.load(open('.jig/para.json')); p['pin'] = 'v0.5.0'; json.dump(p, open('.jig/para.json', 'w'), indent=2)"
$J init --para >/dev/null 2>&1 && git add -A && git commit -qm "pin v0.5.0" >/dev/null 2>&1
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'refused: the pin v0.5.0' && ! git tag | grep -qx v0.1.2" "$out"
git -C mrclone tag -d v0.5.0 >/dev/null && git reset -q --hard "$paratip" && $J init --para >/dev/null 2>&1

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

msg="propose: a branch on the metarepo, the id in the spec, the metarepo's main untouched"
mainbefore=$(git -C mrclone rev-parse main)
$J propose .jig/specs/x.md fmt >/dev/null
expect_pass sh -c "git -C mrclone rev-parse -q --verify refs/heads/propose/pr-fmt && grep -q 'meta: docs proposal propose/pr-fmt' .jig/specs/x.md && test \"\$(git -C mrclone rev-parse main)\" = '$mainbefore' && test \"\$(git -C mrclone branch --show-current)\" = main"
git add -A && git commit -qm "specs: proposal"

msg="para P4: a contract change waits while a file for the metarepo is staged"
stage meta-note.md docs decisions new DECISIONS.md '| D-009 | x | proposed | 2026-10-29 |\n'
printf 'z=3\n' >> api/a.py && printf -- '- meta: none — still internal\n' >> .jig/specs/x.md && git add api/a.py .jig/specs/x.md
expect_refuse git commit -qm "api: more"
python3 .jig/jig.py staging drop meta-note.md >/dev/null
msg="para P4: a file staged for the metarepo by its name in another case holds it back too"
stage upper-note.md DOCS decisions new DECISIONS.md '| D-009 | x | proposed | 2026-10-29 |\n'
expect_refuse git commit -qm "api: more"
python3 .jig/jig.py staging drop upper-note.md >/dev/null
msg="para P4: once it is resolved, the same commit is accepted"
expect_pass git commit -qm "api: more"

msg="para: a new worktree gets the main checkout's cache; propose there names the repo, not the folder"
git worktree add -q --detach "$T/pr-job" HEAD 2>/dev/null
(cd "$T/pr-job" && $J propose .jig/specs/x.md lanefix >/dev/null)
expect_pass sh -c "test -f '$T/pr-job/.jig/meta-cache/DECISIONS.md' && git -C mrclone rev-parse -q --verify refs/heads/propose/pr-lanefix"
git worktree remove --force "$T/pr-job"

msg="repos: works outside any git repo"
expect_pass sh -c "cd '$T' && python3 '$P/jig/jig.py' repos"

cd "$MR" && git switch -q -c d1 && printf '| D-001 | ids are numbers | accepted | 2026-10-29 |\n' >> DECISIONS.md
printf -- '- D-001\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit d1 2>/dev/null && $J release >/dev/null
cd "$PR" && printf 'D-001 is how ids work\n' > api/ids.md && git add api/ids.md && git commit -qm "api: ids" >/dev/null 2>&1
msg="sync on a pararepo trunk: after a release it reports the change in this repo's terms and proposes the bump; the pin stays"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'docs v0.2.0 is out' && echo \"\$0\" | grep -q 'D-001: used in api/ids.md' && echo \"\$0\" | grep -q 'meta: docs v0.1.0 → v0.2.0' && grep -q '\"pin\": \"v0.1.0\"' .jig/para.json" "$out"

msg="repos: lists each repo and flags a path that no longer exists"
mv mrclone ../mrclone-away; out=$($J repos 2>&1); mv ../mrclone-away mrclone
expect_pass sh -c "echo \"\$0\" | grep -q 'docs .*(missing)'" "$out"

msg="sync on a pararepo trunk: offline, it reads the cache and says so"
mv mrclone ../mrclone-away; out=$($J sync 2>&1); mv ../mrclone-away mrclone
expect_pass sh -c "echo \"\$0\" | grep -q \"can't reach docs\" && echo \"\$0\" | grep -q 'reading the cache (v0.1'" "$out"

msg="sync on a pararepo trunk: with defer_until in the future it prints nothing; on or after it, the full report"
python3 -c "import json; p = json.load(open('.jig/para.json')); p['defer_until'] = '2999-01-01'; json.dump(p, open('.jig/para.json', 'w'), indent=2)"
quiet=$($J sync 2>&1)
python3 -c "import json; p = json.load(open('.jig/para.json')); p['defer_until'] = '2000-01-01'; json.dump(p, open('.jig/para.json', 'w'), indent=2)"
loud=$($J sync 2>&1)
expect_pass sh -c "test -z \"\$0\" && echo \"\$1\" | grep -q 'v0.2.0 is out'" "$quiet" "$loud"
git checkout -q -- .jig/para.json
msg="update: a pararepo's generated header is left as it is (trunk's older checker would refuse a change)"
expect_pass sh -c "! python3 '$P/jig/jig.py' update | grep -q AGENTS.md"
msg="update: a metarepo's two-part tag_pattern is widened to take vX.Y.Z"
(cd "$MR" && python3 -c "import json; m = json.load(open('.jig/meta.json')); m['tag_pattern'] = r'^v\\d+\\.\\d+$'; json.dump(m, open('.jig/meta.json', 'w'), indent=2)")
expect_pass sh -c "cd '$MR' && python3 '$P/jig/jig.py' update | grep -q 'widen .jig/meta.json'"
git -C "$MR" checkout -q -- .jig/meta.json

# P2 also reads the job's own spec: the board's, as trunk has it; a one-line spec is its own text.
cd "$PR" && printf '# pj\n\n## Decisions\n- meta: docs proposal propose/pr-fmt\n' > .jig/specs/pj.md && printf '# pk\n' > .jig/specs/pk.md
git add .jig/specs && git commit -qm "specs: pj, pk" >/dev/null 2>&1
for j in pj pk; do $J open $j --spec .jig/specs/$j.md >/dev/null 2>&1; done
$J open pl --spec "meta: none — a comment's typo, no contract change" >/dev/null 2>&1
git add -A && git commit -qm "open pj, pk, pl" >/dev/null 2>&1
for j in pj pk pl; do (cd .git/jig/worktrees/$j && printf '%s=1\n' $j > api/$j.py && git add api/$j.py); done
msg="para P2: a job whose spec on trunk says meta: <name> proposal <branch> changes a contract path, no spec in the commit"
expect_pass git -C .git/jig/worktrees/pj commit -qm "api: pj"
msg="para P2: a job whose trunk spec has no meta: line, and no spec in the commit, is refused"
out=$(git -C .git/jig/worktrees/pk commit -qm "api: pk" 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^jig: P2 api/pk.py is a contract path'" "$out"
msg="para P2: the same job answers it with a spec it commits on its branch"
(cd .git/jig/worktrees/pk && printf -- '- meta: none — a rename inside the module\n' >> .jig/specs/pk.md && git add .jig/specs/pk.md)
expect_pass git -C .git/jig/worktrees/pk commit -qm "api: pk"
msg="para P2: a one-line board spec carrying meta: none — <reason> answers it"
expect_pass git -C .git/jig/worktrees/pl commit -qm "api: pl"
# The job's spec answers at the gate's scratch merge and at `jig merge` too, where no branch is the job's.
for j in pk pl pj; do (cd .git/jig/worktrees/$j && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $j" >/dev/null 2>&1); done
msg="para P2: the gate's scratch merge of a job answered by its one-line board spec passes"
expect_pass gate_ok pl
msg="para P2: jig merge of a job answered by its one-line board spec passes"
expect_pass $J merge pl
msg="para P2: the gate's scratch merge of a job answered by a spec on its branch passes"
expect_pass gate_ok pk
msg="para P2: jig merge of a job answered by a spec on its branch passes"
expect_pass $J merge pk
msg="para P2: the gate still waits for a proposal <branch> the pinned release doesn't hold"
out=$($J gate pj 2>&1); rc=$?; git worktree remove --force .git/jig/worktrees/gate-pj 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'cites proposal propose/pr-fmt, which is not in docs'" "$out"
msg="para P2: jig merge of a job answered by meta: <name> proposal <branch> in its trunk spec passes"
expect_pass $J merge pj

# meta: <name> pointers <branch>: pointer rewrites worked ahead of, no claim change. The gate
# checks the branch is real and doesn't wait for its release.
printf '# Doc\n\nThe api.\n\n## Old\n\nx\n' > api/doc.md && printf '# pp\n' > .jig/specs/pp.md
printf '# pq\n\n## Decisions\n- meta: docs pointers propose/pr-nope\n' > .jig/specs/pq.md
printf '# pr\n\n## Decisions\n- meta: other pointers propose/pr-ptr\n' > .jig/specs/pr.md
git add -A && git commit -qm "api: doc; specs pp, pq, pr" >/dev/null 2>&1
msg="propose --pointers records meta: <name> pointers <branch>"
$J propose .jig/specs/pp.md ptr --pointers >/dev/null
expect_pass sh -c "grep -qx -- '- meta: docs pointers propose/pr-ptr' .jig/specs/pp.md && git -C mrclone rev-parse -q --verify refs/heads/propose/pr-ptr"
git add -A && git commit -qm "specs: pp pointers" >/dev/null 2>&1
# A metarepo pointer into api/doc.md's heading, as the cache would hold it.
printf '| D-077 | the api doc (`pr/api/doc.md § Old`) | accepted | 2026-11-01 |\n' >> .jig/meta-cache/DECISIONS.md
$J open pp --spec .jig/specs/pp.md --owns api/doc.md >/dev/null 2>&1
for j in pq pr; do $J open $j --spec .jig/specs/$j.md >/dev/null 2>&1; done
git add -A && git commit -qm "open pp, pq, pr" >/dev/null 2>&1
(cd .git/jig/worktrees/pp && sed -i.bak 's/^## Old$/## New/' api/doc.md && rm api/doc.md.bak && printf 'pp=1\n' > api/pp.py && git add -A)
for j in pq pr; do (cd .git/jig/worktrees/$j && printf '%s=1\n' $j > api/$j.py && git add -A); done
msg="para P2: a pointers answer in the job's trunk spec covers a contract edit and a renamed cited heading"
expect_pass git -C .git/jig/worktrees/pp commit -qm "api: pp, rename Old"
for j in pq pr; do git -C .git/jig/worktrees/$j commit -qm "api: $j" >/dev/null 2>&1; done
for j in pp pq pr; do (cd .git/jig/worktrees/$j && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $j" >/dev/null 2>&1); done
msg="para gate: a pointers branch that exists passes, its proposal unreleased"
expect_pass gate_ok pp
msg="para P2: jig merge of the pointers job passes, the proposal unreleased"
expect_pass $J merge pp
msg="para gate: a pointers branch the metarepo doesn't have is refused"
out=$($J gate pq 2>&1); rc=$?; git worktree remove --force .git/jig/worktrees/gate-pq 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'pointers branch propose/pr-nope, which docs has no branch for'" "$out"
msg="para gate: a pointers answer naming another metarepo is refused"
out=$($J gate pr 2>&1); rc=$?; git worktree remove --force .git/jig/worktrees/gate-pr 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'pointers branch propose/pr-ptr on other, but this repo.s metarepo is docs'" "$out"

pnote() { (cd .git/jig/worktrees/$1 && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $1" >/dev/null 2>&1); }
msg="update: a cited heading a pointers answer covered is pending on its branch, with no BUFFER.md row offered"
pointed=$($UP 2>&1 | sed -n '/^Metarepo pointers/,/^$/p')
expect_pass sh -c "echo \"\$0\" | grep 'api/doc.md § Old' | grep -q 'pending on propose/pr-ptr' && ! echo \"\$0\" | grep 'api/doc.md' | grep -q 'BUFFER.md'" "$pointed"
msg="update: a contract file a job deleted, answered by its trunk spec, is not a Contract removal"
printf 'dead=1\n' > api/dead.py && printf '# dead\n\n- meta: none — a file to delete\n' > .jig/specs/dead.md && git add -A && git commit -qm "api: dead" >/dev/null 2>&1
$J open p1 --spec "meta: none — dead code, no contract" --owns api/dead.py >/dev/null 2>&1 && git add -A && git commit -qm "open p1" >/dev/null 2>&1
(cd .git/jig/worktrees/p1 && git rm -q api/dead.py && git commit -qm "api: drop dead" >/dev/null 2>&1); pnote p1
$J merge p1 >/dev/null 2>&1
expect_pass sh -c "test -z \"\$(git ls-files api/dead.py)\" && ! $UP 2>&1 | sed -n '/^Contract removals/,/^\$/p' | grep -q 'api/dead.py'"

# One job per merge: a job stacked on another, or an octopus, gets no job's answer.
$J open jb --spec "meta: none — jb" >/dev/null 2>&1; $J open jc --spec "jc, with no answer" >/dev/null 2>&1
$J open jd --spec "meta: none — jd" >/dev/null 2>&1
git add -A && git commit -qm "open jb jc jd" >/dev/null 2>&1; top=$(git rev-parse HEAD)
(cd .git/jig/worktrees/jc && printf 'c=1\n' > api/jc.py && git add api/jc.py && git commit -qm "api: jc" --no-verify >/dev/null 2>&1)
# --no-commit: an auto-committed merge is judged against trunk, which has the board jb lacks.
(cd .git/jig/worktrees/jb && git merge -q --no-ff --no-commit jc >/dev/null 2>&1 && git commit -q --no-edit >/dev/null 2>&1)
(cd .git/jig/worktrees/jd && printf 'd=1\n' > api/jd.py && git add api/jd.py && git commit -qm "api: jd" >/dev/null 2>&1)
git branch -q xo main && (git worktree add -q "$T/wxo" xo && cd "$T/wxo" && printf 'q=1\n' > api/xo.py && git add api/xo.py && git commit -qm "api: xo" --no-verify >/dev/null 2>&1); git worktree remove --force "$T/wxo"
msg="para P2: (setup) jb holds jc's commit, and jd and xo are each ahead of trunk"
expect_pass sh -c "git merge-base --is-ancestor jc jb && ! git merge-base --is-ancestor jd main && ! git merge-base --is-ancestor xo main"
msg="para P2: merging a job that a stacked job also holds reads its own spec, not the stacking job's"
expect_refuse git merge --no-ff --no-edit jc; git merge --abort 2>/dev/null; git reset -q --hard "$top"
msg="para P2: an octopus of an answered job and a branch with no answer gets no job's answer"
expect_refuse git merge --no-edit jd xo; git merge --abort 2>/dev/null; git reset -q --hard "$top"
msg="para P2: the answered job alone still merges on its trunk spec"
expect_pass git merge --no-ff --no-edit jd; git reset -q --hard "$top"

msg="para gate: a pointers branch merged into the metarepo and deleted, not yet released, passes"
(cd mrclone && git switch -q propose/pr-ptr && printf 'ptr\n' > ptr.md && git add -A && git commit -qm "ptr: rewrite" \
  && git switch -q main && git merge -q --no-ff --no-edit propose/pr-ptr && git branch -q -D propose/pr-ptr) >/dev/null 2>&1
$J open ps --spec "meta: docs pointers propose/pr-ptr" >/dev/null 2>&1 && $J open pu --spec "meta: docs pointers propose/pr-ptr" >/dev/null 2>&1
git add -A && git commit -qm "open ps pu" >/dev/null 2>&1
for j in ps pu; do (cd .git/jig/worktrees/$j && printf '%s=1\n' $j > api/$j.py && git add -A && git commit -qm "api: $j" >/dev/null 2>&1); pnote $j; done
expect_pass gate_ok ps
msg="sync: lists a pointers branch and its state"
expect_pass sh -c "$J sync 2>&1 | grep -q 'pointers propose/pr-ptr (.jig/specs/pp.md): merged, not released'"
msg="para gate: a pointers answer whose metarepo can't be reached is refused"
mv mrclone ../mrclone-away; out=$($J gate pu 2>&1); rc=$?; mv ../mrclone-away mrclone; git worktree remove --force .git/jig/worktrees/gate-pu 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"pointers branch propose/pr-ptr, and docs can't be reached to check it\"" "$out"

# Update once the pin holds a branch answer: a pointer still dangling is one the rewrite missed.
# `jig sync` above refilled the cache, so the pointers go back in as the cache would hold them.
printf '| D-077 | the api doc (`pr/api/doc.md § Old`) | accepted | 2026-11-01 |\n' >> .jig/meta-cache/DECISIONS.md
git -C mrclone tag v9.9.9 main
cp .jig/para.json "$T/para.keep" && setjson .jig/para.json pin v9.9.9
msg="update: a pointer still dangling once the pin holds its pointers branch gets a BUFFER.md row, naming the missed rewrite"
pointed=$($UP 2>&1 | sed -n '/^Metarepo pointers/,/^$/p')
expect_pass sh -c "echo \"\$0\" | grep 'api/doc.md § Old' | grep \"rewrite in propose/pr-ptr missed it\" | grep -q 'BUFFER.md' && ! echo \"\$0\" | grep 'api/doc.md' | grep -q 'pending on'" "$pointed"
cp "$T/para.keep" .jig/para.json; git -C mrclone tag -d v9.9.9 >/dev/null
msg="update: a pointer removal its job answered with meta: none still gets a BUFFER.md row"
printf '# None\n\nThe api.\n\n## Gone\n\nx\n' > api/none.md && printf '# none\n\n- meta: none — a page to rename\n' > .jig/specs/none.md
git add api/none.md .jig/specs/none.md && git commit -qm "api: none" >/dev/null 2>&1
$J open pn --spec "meta: none — rename inside the api docs" --owns api/none.md >/dev/null 2>&1 && git add -A && git commit -qm "open pn" >/dev/null 2>&1
printf '| D-078 | the none doc (`pr/api/none.md § Gone`) | accepted | 2026-11-01 |\n' >> .jig/meta-cache/DECISIONS.md
(cd .git/jig/worktrees/pn && sed -i.bak 's/^## Gone$/## Here/' api/none.md && rm api/none.md.bak && git add api/none.md && git commit -qm "api: rename Gone" >/dev/null 2>&1); pnote pn
$J merge pn >/dev/null 2>&1
pointed=$($UP 2>&1 | sed -n '/^Metarepo pointers/,/^$/p')
expect_pass sh -c "git log --oneline -1 | grep -q 'merge pn' && echo \"\$0\" | grep 'api/none.md § Gone' | grep -q 'BUFFER.md' && ! echo \"\$0\" | grep 'api/none.md' | grep -q 'pending on'" "$pointed"

msg="plugin: no instance names or the instance's decision prefix"
expect_refuse grep -rnE 'Maige|maige|"E-' "$P/.."
}

# ---------------------------------------------------------------- release
sec_release() {
RL="$T/rl"; mkdir -p "$RL" && cd "$RL" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && printf 'dist/\n' > .gitignore && printf '0.0.0\n' > VERSION && git add -A && git commit -qm init
$J init >/dev/null && git add -A && git commit -qm board
msg="release: an undefined protocol refuses and points to /jig:release, naming the kind"
out=$($J release --version 1.0.0 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'jig release: rl (repo)' && echo \"\$0\" | grep -q \"isn't defined (.jig/scripts/release.sh still holds the template's TODO).*/jig:release\" && ! git tag | grep -q ." "$out"
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
git add -A && git commit -qm "release.sh: no steps yet"
msg="release: no artifacts named on the board refuses too"
out=$($J release --version 1.0.0 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'release.artifacts is empty'" "$out"
printf 'printf "%%s\\n" "$version" > VERSION\nmkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release'] = {'artifacts': ['dist/app-*.zip']}"
# A step under the TODO line proves the script is skipped, not merely empty.
printf 'touch "%s"\n' "$T/rl-published" >> .jig/scripts/publish.sh
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
msg="release: publish.sh still holding its TODO line is skipped, and the push line printed"
expect_pass sh -c "test ! -e '$T/rl-published' && echo \"\$0\" | grep -q 'Push it: git push --follow-tags'" "$out"
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
msg="release: publish.sh with steps runs after the tag, given the version and the built artifacts"
cat > .jig/scripts/publish.sh <<PUB
#!/usr/bin/env bash
set -eu
git tag > "$T/rl-pub-tags"; echo "\$*" > "$T/rl-pub-args"
PUB
git add -A && git commit -qm "publish steps"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && grep -qx v2.0.3 '$T/rl-pub-tags' && test \"\$(cat '$T/rl-pub-args')\" = '2.0.3 dist/app-2.0.3.zip' && ! echo \"\$0\" | grep -q 'Push it'" "$out"
msg="release: a refused release never runs publish.sh"
rm -f "$T/rl-pub-args"; cp .jig/scripts/release.sh "$T/rl-release.sh"; printf 'exit 3\n' >> .jig/scripts/release.sh; git add -A && git commit -qm "release: broken"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && test ! -e '$T/rl-pub-args' && ! git tag | grep -qx v2.0.4" "$out"
cp "$T/rl-release.sh" .jig/scripts/release.sh; git add -A && git commit -qm "release: fixed"
msg="release: an artifact two globs match reaches publish.sh once"
board "b['release']['artifacts'].append('dist/app-*')"; git add -A && git commit -qm "release: overlapping globs"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && test \"\$(cat '$T/rl-pub-args')\" = '2.0.4 dist/app-2.0.4.zip' && test \"\$(echo \"\$0\" | grep -c 'dist/app-2.0.4.zip')\" = 1" "$out"
board "b['release']['artifacts'] = ['dist/app-*.zip']"; git add -A && git commit -qm "release: zip only"
msg="release: a publish.sh that exits 3 leaves the tag, prints a rerun command that works from anywhere, and exits 1; jig's lines come first"
printf 'exit 3\n' >> .jig/scripts/publish.sh; git add -A && git commit -qm "publish: broken"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc = 1 && git tag | grep -qx v2.0.5 && echo \"\$0\" | head -1 | grep -q '^jig release: rl' && echo \"\$0\" | grep -q 'released v2.0.5 at [0-9a-f]*, but .jig/scripts/publish.sh exited 3' && echo \"\$0\" | grep -qx '  cd [^ ]*/rl && .jig/scripts/publish.sh 2.0.5 dist/app-2.0.5.zip'" "$out"
msg="release: with publish.sh not executable, the rerun command runs it with bash"
chmod -x .jig/scripts/publish.sh; git add -A && git commit -qm "publish: not executable"
out=$(cd sub && python3 ../.jig/jig.py release 2>&1); rc=$?
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q ' && bash .jig/scripts/publish.sh 2.0.6 dist/app-2.0.6.zip\$' && (cd / && sh -c \"\$(echo \"\$0\" | tail -1)\"; test \$? = 3)" "$out"
msg="release: off trunk it refuses"
git switch -q -c side && expect_refuse $J release; git switch -q main
}

# ---------------------------------------------------------------- R6 takes and unique numbers
sec_r6_takes() {
R="$T/r6"; mkdir -p "$R" && cd "$R" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs src
printf '# D\n\n## 1 One\n\n### 1.1 First\n' > docs/d.md
printf 'SCHEMA_VERSION = 17\n' > src/storage.py && printf 'SCHEMA_VERSION = 17\n' > src/plain.py
git add -A && git commit -qm init && $J init >/dev/null
python3 - <<'EOF'
import json; c = json.load(open('.jig/config.json'))
c['reserve'] = {'section': {'pattern': r'^### (\d+)\.\d+', 'files': ['docs/**']},
                'schema': {'pattern': r'SCHEMA_VERSION\s*=\s*(\d+)', 'files': ['src/storage.py'], 'unique': True},
                'plain': {'pattern': r'SCHEMA_VERSION\s*=\s*(\d+)', 'files': ['src/plain.py']}}
json.dump(c, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm config
$J open N --owns 'src/**' --shares 'docs/**' >/dev/null && $J open S --reserve section=12 >/dev/null && git add -A && git commit -qm "open N S"
cd "$R/.git/jig/worktrees/N"
msg="R6 take: ### 1.2 under a section trunk has, with no reservation, is accepted"
printf '\n### 1.2 Second\n' >> docs/d.md; git add -A; expect_pass git commit -qm rule
msg="R6 take: a new page with ### 12.1, holding no section, is refused as taking section 12"
printf '### 12.1 New\n' > docs/n.md; git add -A
out=$($J check --staged 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'takes section 12, but this branch holds no section'" "$out"; undo
msg="R6 unique: a second SCHEMA_VERSION = 17 where trunk has one is refused as 17 already exists"
printf 'SCHEMA_VERSION = 17\n' >> src/storage.py; git add -A
out=$($J check --staged 2>&1); expect_pass sh -c "! git commit -qm dup 2>/dev/null && echo \"\$0\" | grep -q 'schema 17 already exists'" "$out"; undo
msg="R6 unique: a new number added twice is refused as appearing twice in this change"
printf 'SCHEMA_VERSION = 18\nSCHEMA_VERSION = 18\n' >> src/storage.py; git add -A
out=$($J check --staged 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'schema 18 appears twice in this change'" "$out"; undo
msg="R6 unique: without unique, the same duplicate is accepted and takes nothing"
printf 'SCHEMA_VERSION = 17\n' >> src/plain.py; git add -A; expect_pass git commit -qm dup2
cd "$R/.git/jig/worktrees/S"
msg="R6 take: holding section 12, the page with ### 12.1 is accepted"
printf '### 12.1 New\n' > docs/n.md; git add -A; expect_pass git commit -qm s12
}

# ---------------------------------------------------------------- R6 as ints, M5 in a job's flow, a decisions destination
sec_r6_ints() {
MJ="$T/metajob"; mkdir -p "$MJ" && cd "$MJ" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && git add -A && git commit -qm "meta-init"
python3 - <<'EOF'
import json; c = json.load(open('.jig/config.json'))
c['reserve'] = {'decision': {'pattern': r'^\|\s*D-(\d+)\s*\|', 'files': ['DECISIONS.md']}}
json.dump(c, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm "TOOL: decision counter"
$J open D --shares DECISIONS.md CHANGELOG.md --reserve decision=2 >/dev/null && git add -A && git commit -qm "TOOL: open D"
cd "$MJ/.git/jig/worktrees/D"
msg="R6 ints: a job holding decision 2 adds | D-002 |, and check prints ok"
dec 002; expect_pass sh -c "$J check --staged | grep -qx ok"; undo
msg="R6 ints: | D-003 | instead is refused, naming 003 and the held 2"
dec 003; out=$($J check --staged 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'R6 this change takes decision 003, but job D holds decision 2'" "$out"; undo
dec 002 && git commit -qm "D-002: x"
( cd "$MJ" && mkdir -p .jig/specs && printf '# s\n' > .jig/specs/s.md && git add -A && git commit -qm "TOOL: spec" )
msg="M5: after a .jig/-only commit on trunk, jig sync in a job commits its merge"
expect_pass sh -c "$J sync && test \"\$(git rev-list --parents -n1 HEAD | wc -w | tr -d ' ')\" = 3"
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1; foldin
git add -A && git commit -qm "HANDOFF: D"
( cd "$MJ" && printf '# t\n' > .jig/specs/t.md && git add -A && git commit -qm "TOOL: spec t" )
cd "$MJ"
msg="M5: the gate's merge of trunk in its detached scratch checkout commits"
g=.git/jig/worktrees/gate-D
expect_pass sh -c "$J gate D >/dev/null 2>&1 && test \"\$(git -C $g rev-list --parents -n1 HEAD | wc -w | tr -d ' ')\" = 3 && test -z \"\$(git -C $g branch --show-current)\""
git worktree remove --force "$g"
msg="M5: jig merge of a job whose tip is the note committed after its review succeeds, and removes the entry"
expect_pass sh -c "$J merge D >/dev/null 2>&1 && ! grep -q '\"D\"' .jig/jobs.json"
msg="M5: jig release and pre-push accept that history"
git init -q --bare "$T/metajob-remote.git" && git remote add origin "$T/metajob-remote.git"
expect_pass sh -c "$J release >/dev/null 2>&1 && git tag | grep -qx v0.1.0 && git push -q origin main 2>/dev/null"
$J open E --shares DECISIONS.md CHANGELOG.md --reserve decision=3 >/dev/null && git add -A && git commit -qm "TOOL: open E"
cd "$MJ/.git/jig/worktrees/E"
dec 003 && git commit -qm "D-003: x" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
printf -- '- D-003 more\n' >> CHANGELOG.md && git commit -qm "D-003: more" CHANGELOG.md; foldin
git add -A && git commit -qm "HANDOFF: E"
cd "$MJ"
msg="M5: content committed after the review, then a note: jig merge refuses"
expect_refuse $J merge E
msg="M5: and a plain merge of that tip is refused by M5"
out=$(git merge --no-ff --no-edit E 2>&1); git merge --abort 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q 'M5 '" "$out"
$J open F --shares DECISIONS.md CHANGELOG.md --reserve decision=4 >/dev/null && git add -A && git commit -qm "TOOL: open F"
( cd "$MJ/.git/jig/worktrees/F" && dec 004 && git commit -qm "D-004: x" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && foldin && git add -A && git commit -qm "HANDOFF: F" )
printf '# u\n' > .jig/specs/u.md && git add -A && git commit -qm "TOOL: spec u"
( cd "$MJ/.git/jig/worktrees/F" && $J sync >/dev/null 2>&1 )
msg="M5: review, then a note, then a sync of trunk: jig merge is accepted, and so is the release"
expect_pass sh -c "$J merge F >/dev/null 2>&1 && ! grep -q '\"F\"' .jig/jobs.json && $J release >/dev/null 2>&1 && git tag | grep -qx v0.2.0"

cd "$R" && mkdir -p .jig/staging
msg="staging: a decisions destination with prose after the path refuses, naming the header field"
stage dd.md this decisions new 'docs/DECISIONS.md, on branch x' '| D-009 | x | accepted | 2026-10-30 |\n'
out=$($J staging resolve dd.md 2>&1)
expect_pass sh -c "! $J staging resolve dd.md >/dev/null 2>&1 && echo \"\$0\" | grep -q 'destination:' && test ! -e DECISIONS.md" "$out"
msg="staging: destination docs/DECISIONS.md resolves there"
stage dd.md this decisions new docs/DECISIONS.md '| D-009 | x | accepted | 2026-10-30 |\n'
expect_pass sh -c "$J staging resolve dd.md && grep -q 'D-009' docs/DECISIONS.md"
msg="staging: an empty decisions destination is still refused by the header check"
stage de.md this decisions new '' '| D-010 | x | accepted | 2026-10-30 |\n'
expect_refuse $J staging resolve de.md
msg="staging: destination DECISIONS.md resolves to the root register"
stage de.md this decisions new DECISIONS.md '| D-010 | x | accepted | 2026-10-30 |\n'
expect_pass sh -c "$J staging resolve de.md && grep -q 'D-010' DECISIONS.md"
msg="staging: D-10 is the D-010 already in the register, and is refused as new"
stage de.md this decisions new DECISIONS.md '| D-10 | again | accepted | 2026-10-30 |\n'
expect_refuse $J staging resolve de.md; rm .jig/staging/de.md
}

# ---------------------------------------------------------------- merge after a sync, the gate's own scratch merge, jig reserve
sec_merge_after_sync() {
MS="$T/msync"; mkdir -p "$MS" && cd "$MS" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs
printf '# D\n\n## 1 One\n' > docs/d.md && printf '# Changelog\n' > CHANGELOG.md
git add -A && git commit -qm init && $J init >/dev/null
python3 - <<'EOF'
import json; c = json.load(open('.jig/config.json'))
c['reserve'] = {'section': {'pattern': r'^## (\d+) ', 'files': ['docs/**']}, 'loose': {}}
json.dump(c, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm config
for j in K L M; do $J open $j --shares CHANGELOG.md >/dev/null; done; git add -A && git commit -qm "open K L M"
for j in K L M; do
  ( cd "$MS/.git/jig/worktrees/$j" && printf -- '- %s\n' "$j" >> CHANGELOG.md && printf 'x=1\n' > "$j.py" && git add -A && git commit -qm "$j" \
    && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && foldin && git add -A && git commit -qm "note $j" )
done
printf -- '- trunk\n' >> CHANGELOG.md && git commit -qam "trunk appends"
msg="gate: with an append conflict between trunk and the note commit, the scratch checkout has trunk merged and no conflict, and the check is printed"
out=$($J gate K 2>&1); s=.git/jig/worktrees/gate-K
expect_pass sh -c "echo \"\$0\" | grep -q 'cd $s && ./.jig/scripts/check.sh' && test \"\$(git -C $s rev-list --parents -n1 HEAD | wc -w | tr -d ' ')\" = 3 && test -z \"\$(git -C $s status --porcelain)\" && ! grep -q '^<<<<<<<' $s/CHANGELOG.md && grep -q '^- K' $s/CHANGELOG.md && grep -q '^- trunk' $s/CHANGELOG.md" "$out"
git worktree remove --force "$s"
for j in K L M; do ( cd "$MS/.git/jig/worktrees/$j" && [ $j = M ] || $J sync >/dev/null 2>&1 ); done
( cd "$MS/.git/jig/worktrees/M" && git -c merge.conflictStyle=diff3 merge -q main >/dev/null 2>&1
  printf -- '# Changelog\n- trunk\n- M\n' > CHANGELOG.md && printf 'x=2\n' > M.py && git add -A && git commit -q --no-edit )
( cd "$MS/.git/jig/worktrees/L" && printf 'x=2\n' > L.py && git commit -qam "L after its note" )
msg="merge: a job synced after its handoff, append conflict resolved by the sync, merges with no new handoff"
expect_pass $J merge K
msg="merge: a commit of the job's own after the note refuses, naming its files"
out=$($J merge L 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'changed since .*(L.py)'" "$out"
msg="merge: a sync whose resolution adds an edit jig sync wouldn't make refuses, naming the file"
out=$($J merge M 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'changed since .*(M.py)'" "$out"

msg="reserve: jig reserve adds the next free number to an open job; a second hands out the next"
$J open R --shares 'docs/**' --reserve section >/dev/null
$J reserve R section >/dev/null && a=$(python3 -c "import json; print(json.load(open('.jig/jobs.json'))['R']['reserved']['section'])")
$J reserve R section >/dev/null && b=$(python3 -c "import json; print(json.load(open('.jig/jobs.json'))['R']['reserved']['section'])")
expect_pass test "$a|$b" = "[2, 3]|[2, 3, 4]"
git add -A && git commit -qm "reserve R"
msg="reserve: R6 accepts either number R holds on its branch"
cd "$MS/.git/jig/worktrees/R"
printf '\n## 3 Three\n' >> docs/d.md; git add -A; expect_pass git commit -qm three
printf '\n## 2 Two\n' >> docs/d.md; git add -A; expect_pass git commit -qm two
cd "$MS"
msg="reserve: a job that isn't open is refused"
expect_refuse $J reserve K section
msg="reserve: a counter with no pattern is refused"
expect_refuse $J reserve R loose
msg="reserve: open still refuses a number another job holds in a list"
expect_refuse $J open Q --reserve section=3
msg="R6: on a detached trunk, a number an open job holds is still refused (no fast-forward carries it onto trunk)"
( cd "$MS/.git/jig/worktrees/R" && $J sync >/dev/null 2>&1 )
git switch -q --detach main && printf '\n## 4 Four\n' >> docs/d.md && git add -A
expect_refuse git commit -qm four; git reset -q --hard && git switch -q main
}

# ---------------------------------------------------------------- repos
sec_repos() {
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
msg="repos: with no entry named jig, it says where tool reports wait"
expect_pass sh -c "$J repos | grep -q 'tool reports wait'"
msg="repos: rename to jig lists this folder as jig"
$J repos rename jig >/dev/null
expect_pass sh -c "$J repos | grep -q 'jig .*← here'"
msg="repos: with an entry named jig, it doesn't say reports wait in a folder"
expect_refuse sh -c "$J repos | grep -q 'tool reports wait'"
msg="repos: a repo whose own name is jig, under an alias, counts as the jig repo"
$J repos rename tools >/dev/null
JD="$T/jigdev"; mkdir -p "$JD/.jig" && echo '{"name": "jig"}' > "$JD/.jig/config.json"
$J repos add jigdev "$JD" >/dev/null
expect_refuse sh -c "$J repos | grep -q 'tool reports wait'"
}

# ---------------------------------------------------------------- workflow
sec_workflow() {
WF="$T/wf"; mkdir -p "$WF" && cd "$WF" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && chmod +x .jig/scripts/*.sh && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="workflow: prints jig's defaults, one step per line"
expect_pass sh -c "$J workflow | grep -qx 'execute: tier 2, effort 3' && $J workflow | grep -qx 'review: tier 2, effort 1'"
msg="workflow: the bug step is printed, in step order after spec"
expect_pass test "$($J workflow | cut -d: -f1 | tr '\n' ' ')" = "spec bug execute review check "
for rule in \
  '{"execute": {"tier": 1}}|workflow.execute: tier 1 is above the spec.s tier 2' \
  '{"execute": {"effort": 2}}|workflow.execute: effort 2 is not below the spec.s effort 2' \
  '{"bug": {"tier": 3}}|workflow.bug: tier 3 is below the spec.s tier 2' \
  '{"bug": {"effort": 3}}|workflow.bug: effort 3 is lower than the spec.s effort 2' \
  '{"review": {"tier": 3}}|workflow.review: tier 3 is below execute.s tier 2'; do
  setwf "${rule%%|*}"
  msg="workflow: $(echo "${rule%%|*}") is refused by jig workflow, naming the rule"
  expect_pass sh -c "! $J workflow >/dev/null 2>&1 && $J workflow 2>&1 | grep -q '${rule#*|}' && test -z \"\$($J workflow 2>/dev/null)\""
  msg="workflow: $(echo "${rule%%|*}") is refused by the commit hook"
  git add -A; expect_refuse git commit -qm wf; undo
done
setwf '{"review": {"effort": 2}}'
msg="workflow: review at effort 2 with execute at 3 is accepted: review is judged against execute, not spec"
expect_pass sh -c "$J workflow | grep -qx 'review: tier 2, effort 2'"
setwf '{"review": {"effort": 3}}'
msg="workflow: review at effort 3 with execute at 3 is accepted: review's effort has no rule"
expect_pass sh -c "$J workflow | grep -qx 'review: tier 2, effort 3'"
setwf '{"spec": {"tier": 1, "effort": 1}, "review": {"tier": 1}}'
msg="workflow: a raised spec raises a bug step left at its default, field by field"
expect_pass sh -c "$J workflow | grep -qx 'bug: tier 1, effort 1' && $J workflow | grep -qx 'spec: tier 1, effort 1'"
msg="workflow: a bug field the repo sets is kept; only the unset one follows spec"
setwf '{"spec": {"tier": 1, "effort": 1}, "review": {"tier": 1}, "bug": {"effort": 0}}'
expect_pass sh -c "$J workflow | grep -qx 'bug: tier 1, effort 0'"
setwf '{"bug": {"tier": 1, "effort": 2}}'
msg="workflow: a bug step at spec's effort and a better tier is accepted"
expect_pass sh -c "$J workflow | grep -qx 'bug: tier 1, effort 2'"
setwf '{"review": {"tier": 1, "effort": 0}}'
msg="workflow: an override that keeps the rules is accepted by the hook"
git add -A; expect_pass git commit -qm wf
msg="workflow: the accepted override is the step in effect"
expect_pass sh -c "$J workflow | grep -qx 'review: tier 1, effort 0'"

# update knows `workflow`: an optional key, read but never written by default.
python3 -c "import json; c = json.load(open('.jig/config.json')); c['version'] = 8; c['bogus'] = 1; json.dump(c, open('.jig/config.json', 'w'), indent=2)"
git add -A && git commit -qm "older config, an unknown key"
out=$($J update 2>&1)
msg="update: a board's workflow override is not called unknown"
expect_pass sh -c "! echo \"\$0\" | grep -q 'board key .workflow. is not one jig knows'" "$out"
msg="update: a truly unknown board key is still named"
expect_pass sh -c "echo \"\$0\" | grep -q 'board key .bogus. is not one jig knows'" "$out"
$J update --apply >/dev/null 2>&1
msg="update --apply leaves the workflow override unchanged"
expect_pass python3 -c "import json; assert json.load(open('.jig/config.json'))['workflow'] == {'review': {'tier': 1, 'effort': 0}}"
python3 -c "import json; c = json.load(open('.jig/config.json')); del c['workflow'], c['bogus']; c['version'] = 8; json.dump(c, open('.jig/config.json', 'w'), indent=2)"
git add -A && git commit -qm "older config, no override"
$J update --apply >/dev/null 2>&1
msg="update --apply adds no workflow key to a board without one"
expect_pass python3 -c "import json; assert 'workflow' not in json.load(open('.jig/config.json'))"
setwf '{"review": {"tier": 1, "effort": 0}}' && git add -A && git commit -qm "override back"

# Written before the bug step: four Workflow lines. It must still gate, and warn.
mkdir -p .jig/specs && printf '# t\n\n## Workflow\nspec: tier 2, effort 2\nexecute: tier 2, effort 3\nreview: tier 2, effort 1\ncheck: tier 3, effort 4\n' > .jig/specs/t.md
git add -A && git commit -qm spec && git switch -q -c g
printf 'a\n' > notes.txt && git add -A && git commit -qm one
msg="reviewed: --tier without --effort is refused"
expect_refuse $J reviewed --tier 2
$J reviewed --tier 2 --effort 2 --ran "model-x at level-y" >/dev/null && $J handoff --spec .jig/specs/t.md >/dev/null
note=".jig/handoffs/g-$(date +%F).md"
msg="handoff: the note carries the review's tier, effort and what it ran on"
expect_pass sh -c "grep -qx 'Review: tier 2, effort 2' $note && grep -qx 'Ran: model-x at level-y' $note"
sed -i.bak 's/^- \[ \]/- [x]/' "$note" && rm "$note.bak" && git add -A && git commit -qm note
msg="gate: a spec with the four pre-bug Workflow lines gates; a review at a lower effort than it asks is warned about, not refused"
out=$($J gate 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'warning: review ran at tier 2, effort 2; the spec asks for tier 2, effort 1'" "$out"
msg="gate: the branch relaxing its spec's Workflow doesn't silence the warning: trunk's copy is read"
sed -i.bak 's/review: tier 2, effort 1/review: tier 3, effort 4/' .jig/specs/t.md && rm .jig/specs/t.md.bak && git commit -qam relax
expect_pass sh -c "$J gate 2>&1 | grep -q 'warning: review ran at tier 2, effort 2'"
printf 'b\n' >> notes.txt && git commit -qam two
$J reviewed --tier 1 --effort 1 >/dev/null && $J handoff --spec .jig/specs/t.md >/dev/null
sed -i.bak 's/^- \[ \]/- [x]/' "$note" .jig/handoffs/g-$(date +%F)-2.md && rm .jig/handoffs/*.bak && git add -A && git commit -qm note2
msg="gate: a review at the spec's settings or better gives no warning"
out=$($J gate 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'from .jig/handoffs/g-.*-2.md on g' && ! echo \"\$0\" | grep -q warning" "$out"
git switch -q main
$J open k --spec .jig/specs/t.md --owns 'k/**' >/dev/null && git add -A && git commit -qm "open k"
(cd .git/jig/worktrees/k && mkdir k && printf 'x\n' > k/x.txt && git add -A && git commit -qm x \
  && $J reviewed >/dev/null && $J handoff >/dev/null && sed -i.bak 's/^- \[ \]/- [x]/' .jig/handoffs/k-*.md \
  && rm .jig/handoffs/*.bak && git add -A && git commit -qm note)
msg="gate: a note with no --spec is judged by the board's spec, and an unrecorded review is warned about"
expect_pass sh -c "$J gate k 2>&1 | grep -q 'warning: the review.s tier and effort are not recorded; the spec asks for tier 2, effort 1'"
}

# ---------------------------------------------------------------- init beside an old board
sec_init_old_board() {
# init must refuse in a repo whose board is at an older path: a second board blocks update,
# and its hooks would run a trunk .jig/jig.py that isn't there yet.
# Its own metarepo docs, listed in this section's repos.json, for the last case's init --para.
MR="$T/mr"; mkdir -p "$MR" && cd "$MR" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null && $J repos add meta >/dev/null
IJ="python3 $P/jig/jig.py"            # the plugin's copy: an old repo has no .jig/jig.py
for gen in ai-dev jig-0.2; do
  d="$T/ib-$gen"; mkdir -p "$d" && cp -R "$FX/$gen/repo/." "$d/" && cd "$d"
  git init -q -b main && git config user.email t@t && git config user.name t
  git add -A && git commit -qm init && cp -R "$FX/$gen/git/." .git/
  for form in "--para docs" "--meta" ""; do
    msg="init ${form:-(plain)} beside $gen's board refuses, names jig update, and changes nothing"
    had_jig=$(test -e .jig && echo y); before=$(hooksnap)
    out=$($IJ init $form 2>&1); rc=$?
    expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'jig update' && test -z \"\$(git status --porcelain)\" && test \"\$1\" = \"\$(find .git/hooks -type f | sort | xargs shasum 2>/dev/null)\" && test -z '$had_jig' -a ! -e .jig" "$out" "$before"
  done
  msg="init --para beside $gen's board gives the order: update, commit, then this same init again"
  out=$($IJ init --para docs --contract 'src/**' 2>&1)
  expect_pass sh -c "echo \"\$0\" | grep -q 'jig update.*commit, then run this same .jig init. again'" "$out"
  msg="install-hooks beside $gen's board refuses; the old hooks and .git/jig/ stay as they were"
  before=$(find .git/hooks .git/jig -type f 2>/dev/null | sort | xargs shasum); out=$($IJ install-hooks 2>&1); rc=$?
  expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'jig update' && test \"\$1\" = \"\$(find .git/hooks .git/jig -type f 2>/dev/null | sort | xargs shasum)\"" "$out" "$before"
  msg="survey and a board command beside $gen's board send it to update, not init or adopt"
  sv=$($IJ survey 2>&1); st=$($IJ status 2>&1)
  expect_pass sh -c "echo \"\$0\" | grep -q 'run /jig:update first, not /jig:adopt' && ! echo \"\$0\" | grep -q 'Run: jig init' && echo \"\$1\" | grep -q 'older jig.s board is at .*run /jig:update first'" "$sv" "$st"
  msg="repos add para beside $gen's board says to run jig update, then jig init --para"
  out=$($IJ repos add para --name ib-$gen 2>&1)
  expect_pass sh -c "echo \"\$0\" | grep -q 'run .jig update. there, commit, then .jig init --para' && ! echo \"\$0\" | grep -q 'not a pararepo yet'" "$out"
done
msg="init --para after update and a commit succeeds, and the next update is up to date"
$UP --apply >/dev/null 2>&1; git add -A && git commit -qm update >/dev/null 2>&1
out=$($J init --para docs --contract 'src/**' 2>&1); rc=$?     # docs: this section's metarepo
expect_pass sh -c "test $rc = 0 && test -f .jig/para.json && test \"\$($UP 2>&1)\" = 'up to date'" "$out"
}

# ---------------------------------------------------------------- ledger rows of the wrong shape
sec_ledger_rows() {
# A ledger row is cut on the pipes GitHub cuts on: \| is a literal pipe, a pipe in backticks
# is not. A row whose cell count isn't its header's is kept and named, never guessed at.
d="$T/lg"; mkdir -p "$d" && cp -R "$FX/ai-dev/repo/." "$d/" && cd "$d"
git init -q -b main && git config user.email t@t && git config user.name t
cat > docs/REVIEW_LEDGER.md <<'EOF'
# Review ledger

| id | review | finding | rank | what happened | reason |
| --- | --- | --- | --- | --- | --- |
| L-1 | a · own | name the loop | optional | taken | — |
| L-2 | a · own | split on `a|b` | optional | taken | — |
| L-3 | a · own | read a\|b as one | optional | taken | — |
| L-4 | a · own | cache it | optional | deferred | later |
EOF
git add -A && git commit -qm init && cp -R "$FX/ai-dev/git/." .git/
out=$($UP 2>&1)
msg="ledger: the dry run names the 7-cell row in Warnings, kept"
expect_pass sh -c "echo \"\$0\" | sed -n '/^Warnings:/,/^\$/p' | grep -qF 'row \`L-2\` has 7 cells, its header 6: kept, check it'" "$out"
msg="ledger: the step line counts what carries over, what is dropped, and the malformed row kept"
expect_pass sh -c "echo \"\$0\" | grep -q 'its 1 untaken row .* carry over, its 2 taken rows are dropped, 1 malformed kept'" "$out"
msg="ledger: the fold drops L-1 and L-3 (escaped pipe), and keeps L-2 and L-4"
$UP --apply >/dev/null 2>&1
expect_pass sh -c "f=.jig/ledgers/DEFERRED.md; grep -q '| L-2 ' \$f && grep -q '| L-4 ' \$f && ! grep -q '| L-1 ' \$f && ! grep -q '| L-3 ' \$f"
msg="table_cells: \\| is one cell's literal pipe; a backtick pipe splits; outer pipes go"
expect_pass python3 -c "
import importlib.util; s = importlib.util.spec_from_file_location('j', '$P/jig/jig.py'); j = importlib.util.module_from_spec(s); s.loader.exec_module(j)
assert j.table_cells(r'| a | b \| c | \`x|y\` |') == ['a', 'b | c', '\`x', 'y\`'], j.table_cells(r'| a | b \| c | \`x|y\` |')"
}

# ---------------------------------------------------------------- hardware reference files
sec_hardware() {
hwnote() { (cd ".git/jig/worktrees/$1" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $1" >/dev/null 2>&1); }
HR="$T/hwref"
mkdir -p "$HR" && cd "$HR" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p docs/watch/datasheets main
printf '# Watch\n\nA watch board. Defined from: [definition](definition.md).\n\n| PMIC | QX-100 | power | [ds](datasheets/qx-100.pdf) |\n' > docs/watch/watch.md
printf '%%PDF-fake\n' > docs/watch/datasheets/qx-100.pdf
# Shaped like a page, but datasheets/ is reserved: a note in it is a reference file.
printf '# PMIC notes\n\nNotes.\n\n## Invariants\n- x\n' > docs/watch/datasheets/qx-100-notes.md
printf '# Definition\n' > docs/watch/definition.md
printf 'png' > docs/watch/schematic.png
printf 'int led = 2;\n' > main/app.c
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="boards: a page is a board page only when boards lists it, never by its path"
expect_pass hrsurvey "assert r['boards_unmapped'] == [], r['boards_unmapped']"
board "b['boards'] = ['docs/watch/watch.md', 'docs/gone/gone.md']"
git add -A && git commit -qm boards
msg="boards: a registered board page no docmap entry names is listed, and an entry naming no page"
expect_pass hrsurvey "assert r['boards_unmapped'] == ['docs/watch/watch.md', 'docs/gone/gone.md'], r['boards_unmapped']
assert r['boards_missing'] == ['docs/gone/gone.md'], r['boards_missing']"
board "b['boards'] = ['docs/watch/watch.md']; b['docmap'] = {'docs/watch/watch.md': ['main/**']}"
git add -A && git commit -qm docmap
msg="boards: mapped, the board page is not listed"
expect_pass hrsurvey "assert r['boards_unmapped'] == [] and r['boards_missing'] == [], r"
msg="boards: update keeps a boards key without calling it unknown"
expect_pass sh -c "! $J update 2>&1 | grep -q 'board key .boards.'"

msg="datasheets: a page's own files and datasheets/ at system depth have a home; a note in datasheets/ is no page"
expect_pass hrsurvey "assert r['homeless'] == [], r['homeless']
assert not [e for e in r['page_contract'] if 'datasheets/' in e['path']], r['page_contract']"
msg="datasheets: a file in a page's folder no page links is reported, a linked one is not"
expect_pass hrsurvey "assert r['datasheets_unlinked'] == ['docs/watch/datasheets/qx-100-notes.md', 'docs/watch/schematic.png'], r['datasheets_unlinked']"

for f in rtc.pdf "imu rev b.pdf" buck.pdf "led sheet.pdf"; do printf '%%PDF-fake\n' > "docs/watch/datasheets/$f"; done
cat >> docs/watch/watch.md <<'MD'
| RTC | QX-20 | clock | [ds][rtc] |
| IMU | QX-30 | motion | [ds](<datasheets/imu rev b.pdf> "rev B") |
| Buck | QX-40 | rail | [ds](/docs/watch/datasheets/buck.pdf) |
| LED | QX-50 | status | [ds](datasheets/led sheet.pdf) |
| Schematic | | | [sch](schematic.png) |

[rtc]: datasheets/rtc.pdf
MD
git add -A && git commit -qm "more link forms"
msg="datasheets: reference-style, <angle>, root-absolute and spaced links all count as links"
expect_pass hrsurvey "assert r['datasheets_unlinked'] == ['docs/watch/datasheets/qx-100-notes.md'], r['datasheets_unlinked']
assert r['datasheets_missing'] == [], r['datasheets_missing']"

printf '| LDO | QX-7 | rail | [ds](datasheets/qx-7.pdf) |\n' >> docs/watch/watch.md
git add -A && git commit -qm "link a missing datasheet"
msg="datasheets: a page linking a datasheet that doesn't exist is reported"
expect_pass hrsurvey "assert r['datasheets_missing'] == [['docs/watch/watch.md', 'docs/watch/datasheets/qx-7.pdf']], r['datasheets_missing']"

# A subsystem's own datasheets/, and one two systems share in docs/datasheets/.
mkdir -p docs/watch/screen/datasheets docs/band docs/datasheets
printf '%%PDF-fake\n' > docs/watch/screen/datasheets/st7789.pdf
printf '# Screen\n\nThe display. [ds](datasheets/st7789.pdf)\n' > docs/watch/screen/screen.md
printf '%%PDF-fake\n' > docs/datasheets/qx-9.pdf && printf '%%PDF-fake\n' > docs/datasheets/unused.pdf
printf '# Band\n\nThe strap. [ds](../datasheets/qx-9.pdf)\n' > docs/band/band.md
printf '| Clasp | QX-9 | latch | [ds](../datasheets/qx-9.pdf) |\n' >> docs/watch/watch.md
git add -A && git commit -qm "subsystem and shared datasheets"
msg="datasheets: accepted in a subsystem's folder and at docs/datasheets/, their linked files no strays"
expect_pass hrsurvey "assert r['homeless'] == [], r['homeless']
assert r['datasheets_orphan'] == [] and r['datasheets_misplaced'] == [], r
assert r['datasheets_missing'] == [['docs/watch/watch.md', 'docs/watch/datasheets/qx-7.pdf']], r['datasheets_missing']
assert r['datasheets_unlinked'] == ['docs/datasheets/unused.pdf', 'docs/watch/datasheets/qx-100-notes.md'], r['datasheets_unlinked']"

printf 'And its clock: [ds](../watch/datasheets/rtc.pdf)\n' >> docs/band/band.md && git add -A && git commit -qm "band borrows"
msg="datasheets: a page linking another page's datasheets/ is told the shared folder it belongs in"
expect_pass hrsurvey "assert r['datasheets_misplaced'] == [['docs/band/band.md', 'docs/watch/datasheets/rtc.pdf', 'docs/datasheets/']], r['datasheets_misplaced']"
expect_pass sh -c "$J survey | grep -qF 'docs/band/band.md -> docs/watch/datasheets/rtc.pdf: move it to docs/datasheets/'"
printf '# Band\n\nThe strap. [ds](../datasheets/qx-9.pdf)\n' > docs/band/band.md && git add -A && git commit -qm "band its own"

msg="survey: a page-shaped file in another page's folder is a subsystem candidate"
printf '# Power\n\nThe rails.\n\n## Invariants\n- 3.3V — the parts are 3.3V; held by review.\n' > docs/watch/power.md
printf '# Bring-up\n' > docs/watch/bringup.md && printf '[bring-up](bringup.md)\n' >> docs/watch/watch.md
git add -A && git commit -qm "candidate"
expect_pass hrsurvey "h = {e['path']: e for e in r['homeless']}
assert list(h) == ['docs/watch/power.md'], h
assert h['docs/watch/power.md']['kind'] == 'page' and h['docs/watch/power.md']['to'] == 'docs/watch/power/power.md', h"
mkdir -p docs/watch/img && printf 'png' > docs/watch/img/scope.png && printf '![scope](img/scope.png)\n' >> docs/watch/bringup.md
git add -A && git commit -qm "a note links an image"
msg="datasheets: a file a note in the page's folder links is not unlinked"
expect_pass hrsurvey "assert 'docs/watch/img/scope.png' not in r['datasheets_unlinked'], r['datasheets_unlinked']"
msg="survey: the subsystem candidate is named as one"
expect_pass sh -c "$J survey | grep -q 'docs/watch/power.md → docs/watch/power/power.md (a subsystem candidate'"

msg="page contract: a board page is read against it like any page"
printf '\n## Invariants\n- Pins are 3.3V\n' >> docs/watch/watch.md
git add -A && git commit -qm "bare invariant"
expect_pass hrsurvey "assert 'docs/watch/watch.md' in [e['path'] for e in r['page_contract']], r['page_contract']"
msg="page contract: the board template, filled in nowhere, is on the contract"
mkdir -p docs/tmpl && cp "$P/hardware.md" docs/tmpl/tmpl.md && git add -A && git commit -qm tmpl
expect_pass hrsurvey "assert 'docs/tmpl/tmpl.md' not in [e['path'] for e in r['page_contract']], r['page_contract']"
git rm -rq docs/tmpl && git commit -qm "no tmpl"

msg="datasheets: survey's Homes line names both datasheets homes"
expect_pass sh -c "$J survey | grep '^Doc homes: ' | grep -qF 'docs/…/datasheets/ = ' && $J survey | grep '^Doc homes: ' | grep -qF '; docs/datasheets/ = '"

# The board rule: a fold-in may not answer "no page needed" for code a board page covers.
# The note's UNOWNED line was written before trunk's docmap reached the file.
$J open H3 --spec t --owns 'fw/**' >/dev/null 2>&1 && git add -A && git commit -qm "open H3"
(cd .git/jig/worktrees/H3 && mkdir -p fw && printf 'int drv;\n' > fw/drv.c && git add -A && git commit -qm drv \
  && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 \
  && sed -i.bak 's|^- \[ \] UNOWNED fw/drv.c — .*|- [x] UNOWNED fw/drv.c — no page needed because it is scratch|' .jig/handoffs/H3-*.md \
  && rm .jig/handoffs/*.bak && git add -A && git commit -qm note)
board "b['docmap']['docs/watch/watch.md'] = ['main/**', 'fw/**']"
git add -A && git commit -qm "board covers fw"
out=$($J gate H3 2>&1)
msg="board rule: the gate refuses 'no page needed' for a file a registered board page covers"
expect_pass sh -c "echo \"\$0\" | grep -q 'UNOWNED fw/drv.c .*docs/watch/watch.md is a board page covering it'" "$out"
$J open H4 --spec t --owns 'docs/watch/watch.md' >/dev/null 2>&1 && git add -A && git commit -qm "open H4"
(cd .git/jig/worktrees/H4 && git rm -q docs/watch/watch.md && git commit -qm "drop the page") && hwnote H4
msg="board gate: a branch deleting a registered board page is refused"
gate_ok H4; rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^docs/watch/watch.md is a board page .*boards lists, and this branch deletes or moves it'" "$out"
board "b['boards'] = []"
git add -A && git commit -qm "unregister"
msg="board rule: the same page, not in boards, has no such refusal; a repo with no board-build files is untouched"
expect_pass gate_ok H3

msg="reference files: init leaves reference_files unset, so /jig:hardware asks"
expect_pass python3 -c "import json; assert json.load(open('.jig/config.json'))['reference_files'] == ''"

msg="reference files: update adds reference_files to a config that lacks it, and no boards key"
python3 - <<'PY'
import json; b = json.load(open('.jig/config.json'))
del b['reference_files']; del b['boards']; b['version'] = 8
json.dump(b, open('.jig/config.json', 'w'), indent=2)
PY
git add -A && git commit -qm "older config"
expect_pass sh -c "$J update 2>&1 | grep -q 'reference_files: added' && ! $J update 2>&1 | grep -q 'boards'"

# Every board has a page: the gate refuses a board-build file no board page covers.
HG="$T/hwgate"; pcnew "$HG" && mkdir -p src && printf 'int x;\n' > src/x.c && printf 'CONFIG_A=y\n' > sdkconfig
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="board survey: a board-build file no board page covers is listed, with /jig:hardware"
expect_pass hrsurvey "assert r['boards_unpaged'] == [{'path': 'sdkconfig', 'page': ''}], r['boards_unpaged']"
expect_pass sh -c "$J survey | grep -q '^  sdkconfig: write the board.s page with /jig:hardware'"
$J open G1 --spec t --owns platformio.ini 'docs/**' >/dev/null 2>&1 && $J open G2 --spec t --owns 'sdkconfig' >/dev/null 2>&1 \
  && $J open GA --spec t --owns 'src/**' >/dev/null 2>&1 && git add -A && git commit -qm "open G1 G2 GA"
(cd .git/jig/worktrees/G1 && mkdir -p docs/prod/devkit && printf '[env:dev]\n' > platformio.ini && printf '# Prod\n\nThe product.\n' > docs/prod/prod.md \
  && printf '# Devkit\n\nThe dev board.\n' > docs/prod/devkit/devkit.md && git add -A && git commit -qm "pio and its page") && hwnote G1
(cd .git/jig/worktrees/G2 && printf 'CONFIG_A=n\n' > sdkconfig && git add -A && git commit -qm cfg) && hwnote G2
(cd .git/jig/worktrees/GA && printf 'int y;\n' > src/x.c && git add -A && git commit -qm src) && hwnote GA
msg="board gate: a branch adding platformio.ini that no board page covers is refused, naming the file and the way out"
gate_ok G1; rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^platformio.ini builds for a board no page covers: write the board.s page with /jig:hardware, list it in .*boards, and map platformio.ini to it in docmap'" "$out"
msg="board gate: a branch changing sdkconfig that no board page covers is refused"
gate_ok G2; rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^sdkconfig builds for a board no page covers'" "$out"
msg="board gate: a branch touching no board-build file passes"
expect_pass gate_ok GA
board "b['docmap'] = {'docs/prod/devkit/devkit.md': ['platformio.ini']}"
git add -A && git commit -qm "map the devkit"
msg="board gate: a page docmap maps but boards doesn't list is named, to add to boards"
gate_ok G1; rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^platformio.ini builds for a board no page covers: docmap maps platformio.ini to docs/prod/devkit/devkit.md, which .*boards doesn.t list: add it to boards'" "$out"
board "b['boards'] = ['docs/prod/devkit/devkit.md']"
git add -A && git commit -qm "register the devkit"
msg="board gate: passes once a registered board page at subsystem depth covers platformio.ini"
expect_pass gate_ok G1
msg="board gate: a job forked before the board page exists still passes once trunk registers it"
expect_pass gate_ok GA
msg="board gate: sdkconfig is still refused while no board page's docmap covers it"
gate_ok G2; rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^sdkconfig builds for a board no page covers'" "$out"

# The layout before boards were systems: survey and update say where each file goes.
HO="$T/hwold"; pcnew "$HO" && mkdir -p docs/hardware/watch docs/hardware/components/pmic docs/hardware/components/rtc docs/hardware/components/imu main
printf '# Watch\n\n- MCU / board: QX\n\n[pmic](components/pmic/qx.pdf) [imu](components/imu/qx.pdf) [rtc](components/rtc/r.pdf) [def](watch/def.md)\n' > docs/hardware/watch.md
printf '# Band\n\n[rtc](components/rtc/r.pdf)\n' > docs/hardware/band.md
printf '# Def\n' > docs/hardware/watch/def.md && printf 'x' > docs/hardware/watch/spec.pdf
printf 'x' > docs/hardware/components/pmic/qx.pdf && printf 'x' > docs/hardware/components/imu/qx.pdf && printf 'x' > docs/hardware/components/rtc/r.pdf
printf 'x' > docs/hardware/components/pmic/spec.pdf && printf 'x' > docs/hardware/watch/spec.pdf
mkdir -p docs/hardware/loose && printf '# Loose\n' > docs/hardware/loose/notes.md && printf '# Hardware\n\nThe boards.\n' > docs/hardware/hardware.md
printf 'int x;\n' > main/app.c && printf 'See docs/hardware/watch.md\n' > README.md && printf 'CONFIG_A=y\n' > sdkconfig
git add -A && git commit -qm init && $J init >/dev/null && board "b['docmap'] = {'docs/hardware/watch.md': ['main/**', 'sdkconfig']}" && git add -A && git commit -qm board
msg="old layout: survey maps each file: pages to systems, vendor PDFs and parts into datasheets/, shared ones to docs/datasheets/, collisions renamed, the rest to place by hand"
expect_pass hrsurvey "h = {e['path']: e for e in r['homeless']}
assert h['docs/hardware/watch.md']['kind'] == 'board' and h['docs/hardware/watch.md']['to'] == 'docs/watch/watch.md', h
assert not [e for e in r['homeless'] if e['kind'] == 'stray'], h
rows = {e['path']: e['to'] for e in r['old_boards']}
assert rows == {'docs/hardware/band.md': 'docs/band/band.md',
                'docs/hardware/components/imu/qx.pdf': 'docs/watch/datasheets/imu-qx.pdf',
                'docs/hardware/components/pmic/qx.pdf': 'docs/watch/datasheets/pmic-qx.pdf',
                'docs/hardware/components/rtc/r.pdf': 'docs/datasheets/r.pdf', 'docs/hardware/watch.md': 'docs/watch/watch.md',
                'docs/hardware/components/pmic/spec.pdf': 'docs/watch/datasheets/pmic-spec.pdf',
                'docs/hardware/watch/def.md': 'docs/watch/def.md', 'docs/hardware/watch/spec.pdf': 'docs/watch/datasheets/watch-spec.pdf',
                'docs/hardware/hardware.md': None, 'docs/hardware/loose/notes.md': None}, rows
why = {e['path']: e['why'] for e in r['old_boards'] if not e['to']}
assert 'index' in why['docs/hardware/hardware.md'] and 'no board page beside it' in why['docs/hardware/loose/notes.md'], why"
msg="old layout: a board-build file docmap maps to a page boards doesn't list is named, to add to boards"
expect_pass hrsurvey "assert r['boards_unpaged'] == [{'path': 'sdkconfig', 'page': 'docs/hardware/watch.md'}], r['boards_unpaged']"
out=$($J survey 2>&1)
msg="old layout: survey prints the move with its boards entry, and sends the repo to /jig:redocument"
expect_pass sh -c "echo \"\$0\" | grep -qF 'docs/hardware/watch.md → docs/watch/watch.md   + boards: docs/watch/watch.md' && echo \"\$0\" | grep -q 'old docs/hardware/ layout: run /jig:redocument' && ! echo \"\$0\" | grep -q 'never read since'" "$out"
board "b['version'] = 8" && git add -A && git commit -qm older
out=$($J update 2>&1)
msg="old layout: update lists the moves for review with the docmap key, the stale reference and the boards lines"
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/hardware/: board files in the old layout' && echo \"\$0\" | grep -qF 'git mv docs/hardware/watch.md docs/watch/watch.md' && echo \"\$0\" | grep -qF 'git mv docs/hardware/components/rtc/r.pdf docs/datasheets/r.pdf' && echo \"\$0\" | grep -qF '.jig/config.json docmap: docs/hardware/watch.md' && echo \"\$0\" | grep -qF 'README.md:1: See docs/hardware/watch.md' && echo \"\$0\" | grep -qF '.jig/config.json boards: + docs/watch/watch.md' && echo \"\$0\" | grep -q 'repoint it'" "$out"

# The reserved name, an orphan datasheets/ folder, and not_docs.
HN="$T/hwname"; pcnew "$HN" && mkdir -p docs/x/datasheets docs/datasheets docs/stuff/datasheets docs/site
printf '# X\n\nX.\n' > docs/x/x.md && printf '# D\n\nD.\n' > docs/x/datasheets/datasheets.md && printf '# D\n\nD.\n' > docs/datasheets/datasheets.md
printf 'x' > docs/stuff/datasheets/a.pdf && printf '# Site\n\nSite.\n' > docs/site/site.md && printf 'png' > docs/site/logo.png
git add -A && git commit -qm init && $J init >/dev/null && board "b['not_docs'] = ['docs/site/**']" && git add -A && git commit -qm board
msg="reserved name: a page named datasheets is reported to rename, not taken for reference files"
expect_pass hrsurvey "k = {e['path']: e['kind'] for e in r['homeless']}
assert k == {'docs/x/datasheets/datasheets.md': 'reserved', 'docs/datasheets/datasheets.md': 'reserved'}, k"
msg="reserved name: survey's text says to rename the folder"
expect_pass sh -c "$J survey | grep -q 'docs/x/datasheets/datasheets.md: a page under the reserved name datasheets/'"
msg="reserved name: a datasheets/ folder in no page's folder is reported as an orphan"
expect_pass hrsurvey "assert r['datasheets_orphan'] == ['docs/stuff/datasheets/a.pdf'], r['datasheets_orphan']"
msg="datasheets: a not_docs folder's files are not asked to be linked"
expect_pass hrsurvey "assert not [f for f in r['datasheets_unlinked'] if f.startswith('docs/site/')], r['datasheets_unlinked']"

# reference_files: ignore, with the line /jig:hardware used to write.
HI="$T/hwignore"; pcnew "$HI" && printf '*.log\ndocs/hardware/*/**/*.[pP][dD][fF]\n' > .gitignore
git add -A && git commit -qm init && $J init >/dev/null && board "b['reference_files'] = 'ignore'" && git add -A && git commit -qm board
mkdir -p docs/hardware/watch && printf 'x' > docs/hardware/watch/spec-sheet.pdf
out=$($J update 2>&1)
msg="update: the dry run lists each file the old line ignored that the new one won't"
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/hardware/watch/spec-sheet.pdf: ignored now, untracked after'" "$out"
rm -r docs/hardware
msg="update: in ignore mode, the dry run proposes the datasheets/ glob for the old docs/hardware/ one"
expect_pass sh -c "echo \"\$0\" | grep -qF '.gitignore: \`docs/hardware/*/**/*.[pP][dD][fF]\` → \`docs/**/datasheets/**/*.[pP][dD][fF]\`'" "$out"
$J update --apply >/dev/null 2>&1
msg="update: --apply rewrites that line; a PDF in any datasheets/ folder is ignored, a note and a schematic are not"
mkdir -p docs/watch/datasheets docs/prod/devkit/datasheets docs/datasheets
printf 'x' > docs/watch/datasheets/a.pdf && printf 'x' > docs/prod/devkit/datasheets/b.PDF && printf 'x' > docs/datasheets/c.pdf
printf 'x' > docs/watch/datasheets/notes.md && printf 'x' > docs/watch/schematic.pdf
expect_pass python3 -c "
lines = open('.gitignore').read().splitlines()
assert lines == ['*.log', 'docs/**/datasheets/**/*.[pP][dD][fF]'], lines
import subprocess
for f in ('docs/watch/datasheets/a.pdf', 'docs/prod/devkit/datasheets/b.PDF', 'docs/datasheets/c.pdf'):
    assert subprocess.run(['git', 'check-ignore', '-q', f]).returncode == 0, f
for f in ('docs/watch/datasheets/notes.md', 'docs/watch/schematic.pdf'):
    assert subprocess.run(['git', 'check-ignore', '-q', f]).returncode == 1, f"
rm -r docs && git add -A && git commit -qm update
msg="update: in commit mode the line is the repo's, and update leaves it"
board "b['reference_files'] = 'commit'" && printf 'docs/hardware/*/**/*.[pP][dD][fF]\n' >> .gitignore && git add -A && git commit -qm commit-mode
expect_pass test "$($J update 2>&1)" = "up to date"
msg="update: in ignore mode, a .gitignore line of the repo's own is left and listed for review"
board "b['reference_files'] = 'ignore'; b['version'] = 8" && printf '*.log\ndocs/hardware/**/*.pdf\n' > .gitignore && git add -A && git commit -qm own-line
out=$($J update 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '.gitignore: reference_files is ignore, and no line is jig.s' && ! echo \"\$0\" | grep -qF '.gitignore: \`docs/hardware'" "$out"
$J update --apply >/dev/null 2>&1
expect_pass test "$(cat .gitignore)" = "$(printf '*.log\ndocs/hardware/**/*.pdf')"
}

# ---------------------------------------------------------------- update: per file, whole subfolders, worktrees
sec_update_per_file() {
# Each repo is the ai-dev fixture plus what the case adds, set up before its first commit.

ax "$T/pf-a" "mkf specs/a.md specs/b.md .jig/specs/b.md && printf 'See [specs/b.md](specs/b.md#top).\n' > docs/notes.md
  sed -i.bak 's|\"AGENTS.md\",|\"AGENTS.md\", \"specs/**\",|' .aidev/lanes.json && rm .aidev/lanes.json.bak"
out=$($UP 2>&1)
msg="update per file: specs/b.md, also at .jig/specs/b.md, is warned once by name"
expect_pass sh -c "test \"\$(echo \"\$0\" | grep -c 'specs/b.md and .jig/specs/b.md both exist')\" = 1" "$out"
msg="update per file: a file naming specs/b.md, which stays, is not stale"
expect_pass sh -c "! echo \"\$0\" | sed -n '/^Stale references/,/^\$/p' | grep -q docs/notes.md" "$out"
$UP --apply >/dev/null 2>&1
msg="update per file: --apply moves specs/a.md, leaves specs/b.md and .jig/specs/b.md as they were"
expect_pass sh -c "$(declare -f renamed); renamed specs/a.md .jig/specs/a.md && test -f specs/b.md && git diff --quiet HEAD -- .jig/specs/b.md"
msg="update per file: common keeps specs/** beside .jig/specs/**"
expect_pass python3 -c "import json; c = json.load(open('.jig/config.json'))['common']; assert 'specs/**' in c and '.jig/specs/**' in c, c"

MIXED="mkf specs/top.md specs/app.spec.js specs/suite/README.md specs/suite/t.rs specs/unit/x.spec.js specs/deep/t.rs specs/deep/a/n.md
  printf 'Run specs/suite/t.rs\n' > docs/notes.md && printf 'Write specs/<task>.md first.\n' > docs/howto.md
  mkdir -p tools && printf 'for f in specs/*.md; do :; done\n' > tools/each.sh && printf 'specs/**/*.spec.js\n' > tools/runner.txt"
ax "$T/pf-b" "$MIXED
  sed -i.bak 's|\"AGENTS.md\",|\"AGENTS.md\", \"specs/*.spec.js\",|' .aidev/lanes.json && rm .aidev/lanes.json.bak"
out=$($UP 2>&1); rc=$?
msg="update subfolders: the dry run exits 1, warning once each that specs/suite/ and specs/deep/ move whole"
expect_pass sh -c "test $rc = 1 && test \"\$(echo \"\$0\" | grep -c 'specs/suite/ holds Markdown, so it moves whole')\" = 1 && test \"\$(echo \"\$0\" | grep -c 'specs/deep/ holds Markdown, so it moves whole')\" = 1" "$out"
msg="update subfolders: specs/app.spec.js and specs/unit/ stay, each with the non-Markdown warning"
expect_pass sh -c "echo \"\$0\" | grep -q 'specs/app.spec.js is in specs/ but isn.t Markdown' && echo \"\$0\" | grep -q 'specs/unit/x.spec.js is in specs/ but isn.t Markdown'" "$out"
msg="update subfolders: a file naming specs/suite/t.rs, which moves, is stale"
expect_pass sh -c "echo \"\$0\" | sed -n '/^Stale references/,/^\$/p' | grep -q docs/notes.md" "$out"
msg="update stale: specs/*.md and specs/<task>.md are stale though specs/ keeps files; specs/**/*.spec.js is not"
expect_pass sh -c "s=\$(echo \"\$0\" | sed -n '/^Stale references/,/^\$/p'); echo \"\$s\" | grep -q tools/each.sh && echo \"\$s\" | grep -q docs/howto.md && ! echo \"\$s\" | grep -q tools/runner.txt" "$out"
$UP --apply >/dev/null 2>&1
msg="update: a common glob over files that all stayed, specs/*.spec.js, is left as it is"
expect_pass python3 -c "import json; c = json.load(open('.jig/config.json'))['common']; assert 'specs/*.spec.js' in c and '.jig/specs/*.spec.js' not in c, c"
msg="update subfolders: top.md, all of specs/suite/ and all of specs/deep/ move R100; the rest stays"
expect_pass sh -c "$(declare -f renamed); for f in top.md suite/README.md suite/t.rs deep/t.rs deep/a/n.md; do renamed specs/\$f .jig/specs/\$f || exit 1; done; test -f specs/app.spec.js && test -f specs/unit/x.spec.js"

ax "$T/pf-c" "$MIXED; mkf .jig/specs/suite/README.md"
out=$($UP 2>&1)
msg="update subfolders: a colliding file keeps all of specs/suite/ where it is, warned once"
expect_pass sh -c "test \"\$(echo \"\$0\" | grep -c 'specs/suite/ and .jig/specs/suite/ both hold README.md')\" = 1 && ! echo \"\$0\" | grep -q '^  specs/suite/.* → ' && echo \"\$0\" | grep -q '^  specs/deep/t.rs → '" "$out"

ax "$T/pf-d" "mkf ledgers/old/README.md ledgers/old/data.csv"
$UP --apply >/dev/null 2>&1
msg="update subfolders: ledgers/old/README.md and data.csv both move under .jig/ledgers/old/"
expect_pass sh -c "$(declare -f renamed); renamed ledgers/old/README.md .jig/ledgers/old/README.md && renamed ledgers/old/data.csv .jig/ledgers/old/data.csv"

ax "$T/pf-e" "printf '#!/bin/sh\ncd \"\$(dirname \"\$0\")/..\"\nexit 0\n' > scripts/check.sh"
out=$($UP 2>&1); rc=$?
msg="update depth: a moved script that finds paths from its own folder is warned with its line; exit 1"
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q '.jig/scripts/check.sh moves from scripts/check.sh.*2: cd \"\$(dirname \"\$0\")/..\"'" "$out"
msg="update depth: no fixture's scripts raise it"
hit=""
for g in claude-lane ai-dev jig-0.2 dot-jig-v7; do
  d="$T/dp-$g"; mkdir -p "$d" && cp -R "$FX/$g/repo/." "$d/"
  (cd "$d" && git init -q -b main && git add -A && git -c user.email=t@t -c user.name=t commit -qm i \
    && $UP 2>&1 | grep -q 'from its own location') && hit="$hit $g"
done
expect_pass test -z "$hit"

ax "$T/pf-f"
before=$(snap)
mkf .jig/specs/alpha.md
out=$($UP 2>&1); rc=$?
msg="update: an untracked file where a file would move refuses the dry run, naming it"
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'untracked files where files would move: .jig/specs/alpha.md (from specs/alpha.md)'" "$out"
msg="update: --apply refuses on it and stages no rename"
rc=$(code $UP --apply)
expect_pass sh -c "test $rc = 2 && test -z \"\$(git diff --cached --name-only)\" && test -f specs/alpha.md"

ax "$T/wt-a"; wt -b l1 .aidev/worktrees/l1
cd "$T" && mv wt-a wt-a2 && cd wt-a2
out=$($UP 2>&1); rc=$?
msg="update worktrees: one moved with the repo folder gets repair, and the refusing dry run still shows the moves"
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'git worktree repair .aidev/worktrees/l1., then .git worktree remove .aidev/worktrees/l1' && echo \"\$0\" | grep -q '^Moves'" "$out"
msg="update worktrees: --apply refuses with the refusal only"
out=$($UP --apply 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && ! echo \"\$0\" | grep -q '^Moves'" "$out"
git worktree repair .aidev/worktrees/l1 >/dev/null 2>&1 && git worktree remove .aidev/worktrees/l1
msg="update worktrees: after the printed commands, update applies, commits clean, and .aidev is gone"
$UP --apply >/dev/null 2>&1
expect_pass sh -c "git commit -qm update && test -z \"\$(git status --porcelain --untracked-files=all)\" && test ! -e .aidev"

ax "$T/wt-b"; wt -b l1 .aidev/worktrees/l1
cd "$T" && mv wt-b wt-b2 && cd wt-b2
git worktree remove "$(git worktree list --porcelain | sed -n 's/^worktree //p' | sed -n 2p)" >/dev/null 2>&1
ig=$(cksum < .gitignore)
out=$($UP 2>&1)
msg="update worktrees: once remove has dropped the record, the folder is not a checkout git knows"
expect_pass sh -c "echo \"\$0\" | grep -q '.aidev/worktrees/l1 is not a checkout git knows: look, then delete it'" "$out"
msg="update worktrees: --apply exits 2 and .gitignore is unchanged"
rc=$(code $UP --apply)
expect_pass sh -c "test $rc = 2 && test \"\$(cksum < .gitignore)\" = '$ig'"

ax "$T/wt-c"; mkf .aidev/worktrees/x/f
msg="update worktrees: a folder with no .git file refuses the dry run and --apply, naming it"
out=$($UP 2>&1); rc=$?; rc2=$(code $UP --apply)
expect_pass sh -c "test $rc = 2 && test $rc2 = 2 && echo \"\$0\" | grep -q '.aidev/worktrees/x is not a checkout git knows'" "$out"

ax "$T/wt-d"; wt -b l1 "$T/wt-d-gone" && rm -rf "$T/wt-d-gone"
msg="update worktrees: one whose folder was deleted by hand gets git worktree prune"
expect_pass sh -c "$UP 2>&1 | grep -q 'wt-d-gone is gone, but git still records it: .git worktree prune.'"

# R names a scratch repo by now (the R6 section); old() archives the jig repo itself.
R="$(dirname "$(dirname "$P")")" old "$T/wt-e" eaec973 dot
mkf .jig/worktrees/y/f
msg="update worktrees: beside eaec973's board, a folder in .jig/worktrees/ refuses the same way"
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q '.jig/worktrees/y is not a checkout git knows'" "$out"

R="$(dirname "$(dirname "$P")")" old "$T/st-a" 5d955a2 jig2
mkdir -p .jig/staging && printf 'x\n' > jig/staging/pending.md && printf 'y\n' > .jig/staging/pending.md
msg="update: an untracked staged file whose .jig/staging/ destination is taken refuses the dry run and --apply"
out=$($UP 2>&1); rc=$?; rc2=$(code $UP --apply)
expect_pass sh -c "test $rc = 2 && test $rc2 = 2 && echo \"\$0\" | grep -q 'untracked files where files would move: .jig/staging/pending.md (from jig/staging/pending.md)' && test -f jig/staging/pending.md" "$out"
}

# ---------------------------------------------------------------- pararepo commands are the standard ones
sec_pararepo_commands() {
# Self-contained: its own metarepo, pararepos and repos.json.
export JIG_CONFIG="$T/pc-repos.json"

PM="$T/pm"; pcnew "$PM" && git add -A && git commit -qm init
$J init --meta --name pm >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
PL="$T/pl"; pcnew "$PL" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="sync: on trunk in a plain repo it is still refused: nothing is upstream"
out=$(cd "$PL" && $J sync 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'not on a job branch'" "$out"
msg="sync: on trunk in a metarepo it is still refused"
out=$(cd "$PM" && $J sync 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'not on a job branch'" "$out"
msg="propose: in a plain repo or a metarepo it refuses, naming jig init --para"
a=$(cd "$PL" && $J propose x.md s 2>&1); b=$(cd "$PM" && $J propose x.md s 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'jig init --para' && echo \"\$1\" | grep -q 'jig init --para'" "$a" "$b"
msg="repos add: meta without meta.json offers jig init --meta; para without para.json offers jig init --para"
a=$(cd "$PL" && $J repos add meta --name plm 2>&1); b=$(cd "$PL" && $J repos add para --name plp 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'jig init --meta' && echo \"\$1\" | grep -q 'jig init --para'" "$a" "$b"

msg="update: a metarepo with no release.sh gets one with no TODO line, and jig release runs"
PN="$T/pn"; pcnew "$PN" && git add -A && git commit -qm init
$J init --meta --name pn >/dev/null && git rm -qf .jig/scripts/release.sh && git add -A && git commit -qm meta-init
python3 "$P/jig/jig.py" update --apply >/dev/null 2>&1; git commit -qm "TOOL: update"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test -f .jig/scripts/release.sh && ! grep -q 'TODO: release protocol' .jig/scripts/release.sh && test $rc = 0 && ! echo \"\$0\" | grep -q '/jig:release'" "$out"

# A pararepo citing pm, with the metarepo's own checkout as its location: proposals land there.
PA="$T/pa"; pcnew "$PA" && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para pm --location "$PM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="para header: names jig sync and jig propose, no para- command"
expect_pass sh -c "grep -q 'jig sync' AGENTS.md && grep -q 'jig propose' AGENTS.md && ! grep -qE 'para-(init|sync|propose)' AGENTS.md"
$J open G1 --spec .jig/specs/g.md --owns 'api/**' '.jig/specs/g.md' >/dev/null
$J open G2 --spec .jig/specs/n.md --owns '.jig/specs/n.md' 'src/**' >/dev/null && git add -A && git commit -qm "open G1 G2"
GW="$PA/.git/jig/worktrees/G1"
(cd "$GW" && mkdir -p .jig/specs && printf '# g\n\n## Decisions\n' > .jig/specs/g.md && $J propose .jig/specs/g.md g >/dev/null \
  && printf 'y=2\n' >> api/a.py && git add -A && git commit -qm "api: g" && $J reviewed >/dev/null \
  && $J handoff --spec .jig/specs/g.md >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note G1")

msg="gate: a job citing an unreleased proposal is refused, naming the proposal and the pin"
out=$($J gate G1 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'propose/pa-g' && echo \"\$0\" | grep -q 'v0.1.0' && test ! -d .git/jig/worktrees/gate-G1" "$out"
git worktree remove --force .git/jig/worktrees/gate-G1 2>/dev/null

(cd "$PM" && git switch -q propose/pa-g && printf '\n### gee\n' >> README.md && printf -- '- gee\n' >> CHANGELOG.md \
  && git add -A && git commit -qm "GLOSSARY: gee" && $J reviewed >/dev/null && git switch -q main \
  && git merge -q --no-ff --no-edit propose/pa-g && $J release >/dev/null)
msg="gate: released after the pin, it is refused, saying to bump the pin"
out=$($J gate G1 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'v0.2.0' && echo \"\$0\" | grep -q 'bump the pin'" "$out"

msg="sync on a pararepo trunk: the stale-header note stays quiet while the header is current"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'pm v0.2.0 is out' && ! echo \"\$0\" | grep -q 'header is out of date'" "$out"
setjson .jig/para.json pin v0.2.0 && $J init --para >/dev/null 2>&1 && git add -A && git commit -qm "meta: pm v0.1.0 → v0.2.0"
msg="sync on a pararepo job: after trunk bumps the pin it merges trunk, and the job's cache follows, metarepo unreachable"
mv "$PM" "$T/pm-away"; (cd "$GW" && $J sync >/dev/null 2>&1); mv "$T/pm-away" "$PM"
expect_pass sh -c "head -1 '$GW/.jig/meta-cache/PIN' | grep -qx v0.2.0 && grep -q '\"pin\": \"v0.2.0\"' '$GW/.jig/para.json'"

msg="gate: a proposal in the pinned release passes"
expect_pass gate_ok G1
git -C "$PM" branch -q -d propose/pa-g
msg="gate: and still passes once the proposal branch is deleted, found by its merge commit"
expect_pass gate_ok G1
msg="sync on a pararepo trunk: a proposal whose branch was deleted after its release reads released by"
mkdir -p .jig/specs && printf '# r\n\n- meta: pm proposal propose/pa-g\n' > .jig/specs/r.md
out=$($J sync 2>&1); rm .jig/specs/r.md
expect_pass sh -c "echo \"\$0\" | grep -q 'proposal propose/pa-g (.jig/specs/r.md): released by v0.2.0'" "$out"
msg="gate: metarepo unreachable and a spec cites a proposal: refused, naming the metarepo"
mv "$PM" "$T/pm-away"; out=$($J gate G1 2>&1); rc=$?; mv "$T/pm-away" "$PM"
git worktree remove --force .git/jig/worktrees/gate-G1 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"pm can't be reached\"" "$out"

NW="$PA/.git/jig/worktrees/G2"
(cd "$NW" && mkdir -p .jig/specs src && printf '# n\n\n## Decisions\n- meta: none — internal\n' > .jig/specs/n.md \
  && printf 'z=1\n' > src/z.py && git add -A && git commit -qm "n" && $J reviewed >/dev/null \
  && $J handoff --spec .jig/specs/n.md >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note G2")
msg="gate: a meta: none spec needs no metarepo"
mv "$PM" "$T/pm-away"; gate_ok G2; rc=$?; mv "$T/pm-away" "$PM"
expect_pass test $rc = 0
(cd "$NW" && printf -- '- meta: other proposal propose/pa-x\n' >> .jig/specs/n.md && git add -A && git commit -qm "n: cites other" \
  && $J reviewed >/dev/null && $J handoff --spec .jig/specs/n.md >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note G2 again")
msg="gate: a proposal naming another metarepo than para.json's is refused as the wrong metarepo"
out=$($J gate G2 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"on other, but this repo's metarepo is pm\"" "$out"

# A spec proposed and committed on trunk, then given to a job that changes no spec.
mkdir -p .jig/specs && printf '# t\n\n## Decisions\n' > .jig/specs/t.md && $J propose .jig/specs/t.md t >/dev/null
git add .jig/specs/t.md && git commit -qm "specs: t" && $J open G3 --spec .jig/specs/t.md --owns 'lib/**' >/dev/null && git add -A && git commit -qm "open G3"
TW="$PA/.git/jig/worktrees/G3"
(cd "$TW" && mkdir -p lib && printf 'w=1\n' > lib/w.py && git add -A && git commit -qm w && $J reviewed >/dev/null \
  && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note G3")
msg="gate: a job whose board spec is on trunk and cites an unreleased proposal is refused, though its diff has no spec"
out=$($J gate G3 2>&1); rc=$?; git worktree remove --force .git/jig/worktrees/gate-G3 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'propose/pa-t'" "$out"
# The metarepo lands that proposal as a job, by `jig merge`, releases, and deletes the branch.
(cd "$PM" && $J open tj --branch propose/pa-t --owns README.md CHANGELOG.md >/dev/null && git add -A && git commit -qm "TOOL: open tj" \
  && cd .git/jig/worktrees/propose/pa-t && printf '\n### tee\n' >> README.md && printf -- '- tee\n' >> CHANGELOG.md \
  && git add -A && git commit -qm "GLOSSARY: tee" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold \
  && git add -A && git commit -qm "TOOL: note tj" && cd "$PM" && $J merge tj >/dev/null && $J release >/dev/null \
  && git worktree remove --force .git/jig/worktrees/propose/pa-t && git branch -q -D propose/pa-t)
setjson .jig/para.json pin v0.3.0 && $J init --para >/dev/null 2>&1 && git add -A && git commit -qm "meta: pm v0.2.0 → v0.3.0"
msg="gate: a proposal landed by jig merge, its branch deleted, is found by the merge's job and passes"
expect_pass sh -c "git -C '$PM' log -1 --merges --format=%s v0.3.0 | grep -qx 'merge tj' && ! git -C '$PM' rev-parse -q --verify refs/heads/propose/pa-t >/dev/null" 
gate_ok G3; rc=$?; expect_pass test $rc = 0
msg="sync on a pararepo trunk: once a later release is out, a proposal reads released by the first release that held it"
mkdir -p .jig/specs && printf '# r\n\n- meta: pm proposal propose/pa-g\n' > .jig/specs/r.md
out=$($J sync 2>&1); rm .jig/specs/r.md
expect_pass sh -c "echo \"\$0\" | grep -q 'proposal propose/pa-g (.jig/specs/r.md): released by v0.2.0'" "$out"
msg="init --para: a metarepo clone without the pinned tag still gets the header written; the cache waits, exit 0"
setjson .jig/para.json pin v9.9.9 && out=$($J init --para 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'no tag v9.9.9' && grep -q 'at \`v9.9.9\`' AGENTS.md && head -1 .jig/meta-cache/PIN | grep -qx v0.3.0" "$out"
git checkout -q -- .jig/para.json AGENTS.md

# Two-part pins: a metarepo whose first release was tagged by hand as v0.1.
TP="$T/tp"; pcnew "$TP" && git add -A && git commit -qm init && $J init --meta --name tp >/dev/null
printf '\n## v0.1 — 2026-10-01\n- first\n' >> CHANGELOG.md && git add -A && git commit -qm meta-init && git tag v0.1
PT="$T/pt"; pcnew "$PT" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para tp --location "$TP" --pin v0.1 >/dev/null && git add -A && git commit -qm "init --para"
(cd "$TP" && git switch -q -c d1 && printf '| D-001 | ids are numbers | accepted | 2026-10-29 |\n' >> DECISIONS.md \
  && printf -- '- D-001\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit d1 && $J release >/dev/null)
msg="sync: a pararepo pinned at a hand-made v0.1 sees v0.2.0, proposes the bump, and caches v0.1"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'tp v0.2.0 is out' && echo \"\$0\" | grep -q 'meta: tp v0.1 → v0.2.0' && head -1 .jig/meta-cache/PIN | grep -qx v0.1" "$out"

# Header migration: a pararepo set up by the v0.3.1 checker, before these commands moved.
PH="$T/ph"; pcnew "$PH" && git -C "$JR" show v0.3.1:plugin/templates/jig/jig.py > .jig/jig.py && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para pm --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="header migration: the fixture's header names jig para-init"
expect_pass grep -q 'jig para-init' AGENTS.md
python3 "$P/jig/jig.py" update --apply >/dev/null 2>&1
msg="header migration: the update commit is accepted, and leaves AGENTS.md alone"
expect_pass sh -c "git commit -qm update && grep -q 'jig para-init' AGENTS.md"
msg="header migration: sync on trunk says the header is out of date, naming jig init --para"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'the AGENTS.md header is out of date' && echo \"\$0\" | grep -q 'jig init --para'" "$out"
$J init --para >/dev/null 2>&1
msg="header migration: init --para changes only AGENTS.md (and para.json), and that commit is accepted"
expect_pass sh -c "test -z \"\$(git status --porcelain | grep -vE ' (AGENTS.md|.jig/para.json)\$')\" && git add -u && git commit -qm 'header'"
msg="header migration: afterwards no para- command, one jig:meta block, and sync is quiet about it"
out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(grep -cE 'para-(init|sync|propose)' AGENTS.md)\" = 0 && test \"\$(grep -c 'jig:meta —' AGENTS.md)\" = 1 && ! echo \"\$0\" | grep -q 'header is out of date'" "$out"

msg="header offline: with the metarepo gone from repos.json, init --para rewrites the header, says the cache wasn't refreshed, exits 0"
cp "$JIG_CONFIG" "$T/pc-repos.bak"
python3 -c "import json,sys; f=sys.argv[1]; d=json.load(open(f)); d.pop('pm'); json.dump(d, open(f,'w'))" "$JIG_CONFIG"
sed -i.bak 's/by `jig init --para`/by `jig para-init`/; s/`jig propose`/`jig para-propose`/g' AGENTS.md && rm AGENTS.md.bak
out=$($J init --para 2>&1); rc=$?; mv "$T/pc-repos.bak" "$JIG_CONFIG"
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'was not refreshed' && test \"\$(grep -c 'jig:meta —' AGENTS.md)\" = 1 && git diff --quiet -- AGENTS.md" "$out"
}

# ---------------------------------------------------------------- entry_files take globs; merge --subject
sec_entry_globs() {
# A metarepo whose pages are a glob, so a new page needs no meta.json edit.
EM="$T/em"; pcnew "$EM" && mkdir -p products/x && printf '# a\n' > products/a.md && printf '# b\n' > products/x/b.md && printf 'n\n' > notes.md
$J init --meta --name em >/dev/null && setentry DECISIONS.md 'products/**/*.md' && git add -A && git commit -qm meta-init && $J release >/dev/null
printf 'more\n' >> products/a.md && printf -- '- a\n' >> CHANGELOG.md
msg="entry globs: a change to products/a.md (directly under the glob's folder) releases the next minor"
emerge ea "PRODUCTS: a" products/a.md CHANGELOG.md; out=$($J release --minor 2>&1)
expect_pass sh -c "git rev-parse -q --verify refs/tags/v0.2.0 >/dev/null" "$out"
printf 'more\n' >> products/x/b.md && printf -- '- b\n' >> CHANGELOG.md
msg="entry globs: a change to products/x/b.md releases the next minor"
emerge eb "PRODUCTS: b" products/x/b.md CHANGELOG.md; $J release --minor >/dev/null 2>&1
expect_pass git rev-parse -q --verify refs/tags/v0.3.0
git switch -q -c em3
msg="entry globs: M3 refuses a change to products/a.md with no changelog line"
printf 'x\n' >> products/a.md; git add -A; expect_refuse git commit -qm "PRODUCTS: no line"; undo
msg="entry globs: M3 takes a change to notes.md, which no glob names, with no line"
printf 'x\n' >> notes.md; git add -A; expect_pass git commit -qm "NOTES: n"
# M3 judges the branch since it left trunk: a line one commit added covers the next ones.
# This branch's line goes under the heading, trunk's at the end, so the sync merges cleanly.
git switch -q main && git switch -q -c em4
printf 'y\n' >> products/a.md && underhead '- y' && git add -A && git commit -qm "PRODUCTS: y"
msg="entry globs: M3 takes a page-only commit on a branch whose earlier commit added the line"
printf 'z\n' >> products/a.md; git add -A; expect_pass git commit -qm "PRODUCTS: z"
msg="entry globs: M3 takes a DECISIONS.md-only commit on that branch"
printf '\nmore\n' >> DECISIONS.md; git add -A; expect_pass git commit -qm "DECISIONS: more"
git switch -q main && printf 'w\n' >> products/x/b.md && printf -- '- w\n' >> CHANGELOG.md
emerge em5 "PRODUCTS: w" products/x/b.md CHANGELOG.md; git switch -q em4 && git merge -q --no-edit main
msg="entry globs: after the branch merges a moved trunk, a page-only commit still passes"
printf 'v\n' >> products/a.md; git add -A; expect_pass git commit -qm "PRODUCTS: v"
msg="entry globs: M3 refuses a commit that drops the branch's only line, its page changes kept"
python3 -c "f='CHANGELOG.md'; s=open(f).read(); open(f,'w').write(s.replace('- y\n', '', 1))"
git add -A; expect_refuse git commit -qm "CHANGELOG: drop y"; undo
msg="entry globs: M3 refuses a commit that deletes CHANGELOG.md after the branch added its line"
git rm -q CHANGELOG.md; expect_refuse git commit -qm "CHANGELOG: gone"; undo
git switch -q main && git switch -q -c em6
msg="entry globs: M3 refuses CHANGELOG.md deleted alongside a page change"
printf 'u\n' >> products/a.md && git rm -q CHANGELOG.md && git add -A; expect_refuse git commit -qm "PRODUCTS: u"; undo
msg="entry globs: M3 refuses a non-ASCII page name under the glob with no line"
printf '# d\n' > "products/déjà.md"; git add -A; expect_refuse git commit -qm "PRODUCTS: déjà"; undo
# A pull of trunk's upstream into the branch moves the base, though local main stays behind.
git switch -q main && git switch -q -c emup && printf 't\n' >> products/a.md && printf -- '- t\n' >> CHANGELOG.md \
  && git add -A && git commit -qm "PRODUCTS: t" && git branch -q --set-upstream-to=emup main
git switch -q main && git switch -q -c em7 && git merge -q --ff-only emup
msg="entry globs: M3 doesn't let upstream trunk's line cover a branch that pulled it"
printf 's\n' >> products/a.md; git add -A; expect_refuse git commit -qm "PRODUCTS: s"; undo
git switch -q main && git branch -q --unset-upstream main
printf '# b top\n' > products/b.md && printf -- '- new page b\n' >> CHANGELOG.md
msg="entry globs: a new products/b.md needs no meta.json edit; the next release counts it"
emerge ec "PRODUCTS: new b" products/b.md CHANGELOG.md; $J release >/dev/null 2>&1
expect_pass sh -c "git rev-parse -q --verify refs/tags/v0.4.0 >/dev/null && git diff --quiet v0.1.0 HEAD -- .jig/meta.json"

msg="entry globs: a metarepo whose entry_files are all globs makes its first release from them"
EG="$T/eg"; pcnew "$EG" && mkdir -p products && printf '# a\n' > products/a.md
$J init --meta --name eg >/dev/null && setentry 'products/**/*.md' && git add -A && git commit -qm meta-init
out=$($J release 2>&1); expect_pass sh -c "git rev-parse -q --verify refs/tags/v0.1.0 >/dev/null" "$out"

EP="$T/ep"; pcnew "$EP" && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para em --location "$EM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="entry globs: init --para caches products/a.md and products/b.md as files, and no file named for a folder"
expect_pass sh -c "test \"\$(cd .jig/meta-cache && find . -type f | sort | tr '\n' ' ')\" = './CHANGELOG.md ./DECISIONS.md ./PIN ./products/a.md ./products/b.md ./products/x/b.md '"

# A proposal landed by `jig merge --subject`, its branch then deleted: the gate still finds it.
mkdir -p .jig/specs && printf '# t\n\n## Decisions\n' > .jig/specs/t.md && $J propose .jig/specs/t.md t >/dev/null
git add .jig/specs/t.md && git commit -qm "specs: t" && $J open E1 --spec .jig/specs/t.md --owns 'lib/**' >/dev/null && git add -A && git commit -qm "open E1"
(cd "$EP/.git/jig/worktrees/E1" && mkdir -p lib && printf 'w=1\n' > lib/w.py && git add -A && git commit -qm w && $J reviewed >/dev/null \
  && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note E1")
(cd "$EM" && $J open J --branch propose/ep-t --owns products/t.md CHANGELOG.md >/dev/null && git add -A && git commit -qm "TOOL: open J" \
  && cd .git/jig/worktrees/propose/ep-t && printf '# t\n' > products/t.md && printf -- '- t\n' >> CHANGELOG.md \
  && git add -A && git commit -qm "PRODUCTS: t" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold \
  && git add -A && git commit -qm "TOOL: note J" && cd "$EM" && $J merge J --subject "D-001, D-002" >/dev/null && $J release >/dev/null \
  && git worktree remove --force .git/jig/worktrees/propose/ep-t && git branch -q -D propose/ep-t)
msg="merge --subject: the subject is '<ids>: merge J'"
expect_pass sh -c "git -C '$EM' log -1 --merges --format=%s v0.5.0 | grep -qx 'D-001, D-002: merge J'"
setjson .jig/para.json pin v0.5.0 && $J init --para >/dev/null 2>&1 && git add -A && git commit -qm "meta: em v0.4.0 → v0.5.0"
msg="merge --subject: the gate's fallback still finds job J by its merge after its branch is deleted"
gate_ok E1; rc=$?; expect_pass test $rc = 0
msg="merge --subject: a subject that already ends in ': merge <job>' is used as given"
emergejob S1 "D-001: merge S1"; expect_pass sh -c "git -C '$EM' log -1 --merges --format=%s | grep -qx 'D-001: merge S1'"
msg="merge --subject: bare ids still get ': merge <job>' added"
emergejob S2 "D-001"; expect_pass sh -c "git -C '$EM' log -1 --merges --format=%s | grep -qx 'D-001: merge S2'"

msg="entry globs: a non-ASCII page name under the glob is counted by the release"
cd "$EG" && printf '# c\n' > "products/café.md" && printf -- '- café\n' >> CHANGELOG.md
emerge en "PRODUCTS: café" "products/café.md" CHANGELOG.md; $J release >/dev/null 2>&1
expect_pass git rev-parse -q --verify refs/tags/v0.2.0

msg="entry globs: a cited file moved out of the exact entry_files still counts for the release"
ER="$T/er"; pcnew "$ER" && $J init --meta --name er >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
git switch -q -c mv && mkdir -p docs && git mv README.md docs/README.md && printf -- '- moved\n' >> CHANGELOG.md \
  && git add -A && git commit -qm "GLOSSARY: move" && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit mv
$J release >/dev/null 2>&1; expect_pass git rev-parse -q --verify refs/tags/v0.2.0

# A glob that would reach into .jig/: jig's own files still never count.
EJ="$T/ej"; pcnew "$EJ" && printf '# p\n' > p.md
$J init --meta --name ej >/dev/null && setentry '**/*.md' && git add -A && git commit -qm meta-init && $J release >/dev/null
msg="entry globs: with '**/*.md', a .jig/ file committed on trunk needs no changelog line"
mkdir -p .jig/specs && printf '# s\n' > .jig/specs/s.md && git add -A; expect_pass git commit -qm "TOOL: spec s"
msg="entry globs: with '**/*.md', a .jig/ change alone is nothing to release"
out=$($J release 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'nothing to release'" "$out"
msg="entry globs: with '**/*.md', a pararepo's cache holds no .jig/ file"
EK="$T/ek"; pcnew "$EK" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para ej --location "$EJ" >/dev/null 2>&1
expect_pass sh -c "test -f .jig/meta-cache/p.md && test -z \"\$(find .jig/meta-cache -path '*/.jig/*')\""
}

# ---------------------------------------------------------------- report-fixes follow-up
sec_report_fixes() {
# What eight /jig:bug evaluations found around the report-born fixes. Each repo is its own.

# update: a worktree for a branch with `/` sits a level deeper than its worktrees folder.
ax "$T/fu-1"; wt -b feat/x .aidev/worktrees/feat/x && printf 'wip\n' > .aidev/worktrees/feat/x/wip.txt
cd "$T" && mv fu-1 fu-1b && cd fu-1b
out=$($UP 2>&1)
msg="update worktrees: a moved feat/x checkout gets repair then remove, and feat/ is not called a stray"
expect_pass sh -c "echo \"\$0\" | grep -q 'git worktree repair .aidev/worktrees/feat/x., then .git worktree remove .aidev/worktrees/feat/x' && ! echo \"\$0\" | grep -q 'worktrees/feat is not a checkout'" "$out"
msg="update worktrees: the advice works when followed: repair, then remove refuses the uncommitted file, which survives"
git worktree repair .aidev/worktrees/feat/x >/dev/null 2>&1; rc=$(code git worktree remove .aidev/worktrees/feat/x)
expect_pass sh -c "test $rc != 0 && test -f .aidev/worktrees/feat/x/wip.txt && git worktree list | grep -q 'fu-1b/.aidev/worktrees/feat/x'"
msg="update worktrees: once the work is committed, remove succeeds"
(cd .aidev/worktrees/feat/x && git add -A && git -c core.hooksPath=/dev/null commit -qm wip)
expect_pass git worktree remove .aidev/worktrees/feat/x
mkf .aidev/worktrees/feat/junk/f && wt -b feat/y .aidev/worktrees/feat/y
msg="update worktrees: beside a checkout, a folder with none in it is named by its own path"
expect_pass sh -c "$UP 2>&1 | grep -q '.aidev/worktrees/feat/junk is not a checkout git knows'"

# update: what a whole subfolder's move leaves behind, and references the old checks missed.
ax "$T/fu-2" "mkf specs/suite/README.md specs/app.spec.js && printf 'specs/suite/.cache/\n' >> .gitignore
  mkdir -p tools && printf 'cat \"\$(dirname \"\$0\")/../specs/suite/README.md\"\n' > tools/r.sh"
mkf specs/suite/notes.txt specs/suite/.cache/a
out=$($UP 2>&1)
msg="update leftovers: the dry run names specs/suite/'s untracked notes.txt and ignored .cache/"
expect_pass sh -c "echo \"\$0\" | grep -q 'specs/suite/ moves, but files git doesn.t track stay in it: specs/suite/.cache/, specs/suite/notes.txt'" "$out"
msg="update stale: .gitignore's specs/suite/.cache/ is stale; its .aidev/worktrees/ line, which update removes, is not"
expect_pass sh -c "echo \"\$0\" | sed -n '/^Stale references/,/^\$/p' | grep -q '2: specs/suite/.cache/' && ! echo \"\$0\" | sed -n '/^Stale references/,/^\$/p' | grep -q '1: .aidev/worktrees/'" "$out"
msg="update stale: \$(dirname \"\$0\")/../specs/suite/README.md is stale"
expect_pass sh -c "echo \"\$0\" | sed -n '/^Stale references/,/^\$/p' | grep -q 'tools/r.sh'" "$out"

# M5 and pre-push: a detached checkout at trunk is trunk.
FM="$T/fu-m5"; pcnew "$FM" && git add -A && git commit -qm init && $J init --meta --name fm >/dev/null \
  && git add -A && git commit -qm meta-init && $J release >/dev/null
git init -q --bare "$T/fu-m5.git" && git remote add origin "$T/fu-m5.git" && git push -q origin main 2>/dev/null
git switch -q -c ub && printf '\n### grain\n' >> README.md && printf -- '- grain\n' >> CHANGELOG.md \
  && git add -A && git commit -qm "GLOSSARY: grain" && git checkout -q --detach main
msg="M5: on a detached HEAD at main, a merge of an unreviewed branch is refused"
out=$(git merge --no-ff --no-edit ub 2>&1); rc=$?; git merge --abort 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'M5 '" "$out"
msg="pre-push: git push origin HEAD:main of that merge, made with the hooks off, is refused"
git -c core.hooksPath=/dev/null merge -q --no-ff --no-edit ub
expect_refuse git push -q origin HEAD:main
msg="pre-push: still refused with a chained pre-push.local that reads all of stdin first"
printf '#!/bin/sh
cat >/dev/null
' > .git/hooks/pre-push.local && chmod +x .git/hooks/pre-push.local
expect_refuse git push -q origin HEAD:main
rm .git/hooks/pre-push.local
git checkout -q main

# jig merge: an unsynced job with a conflict in an append file is sent to jig sync.
FS="$T/fu-sync"; pcnew "$FS" && printf '# Changelog\n' > CHANGELOG.md && printf 'base\n' > common.txt && git add -A && git commit -qm init \
  && $J init >/dev/null && git add -A && git commit -qm board
for j in K L M; do $J open $j --shares CHANGELOG.md common.txt >/dev/null; done; git add -A && git commit -qm "open K L M"
for j in K L M; do
  ( cd "$FS/.git/jig/worktrees/$j" && printf -- '- %s\n' "$j" >> CHANGELOG.md && printf 'x=1\n' > "$j.py" \
    && { [ $j = L ] || printf '%s\n' "$j" > common.txt; } && git add -A \
    && git commit -qm "$j" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $j" )
done
msg="gate: an executable check.sh is printed as ./.jig/scripts/check.sh, with git worktree remove --force"
out=$($J gate L 2>&1); git worktree remove --force .git/jig/worktrees/gate-L 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q '&& ./.jig/scripts/check.sh' && echo \"\$0\" | grep -q 'git worktree remove --force .git/jig/worktrees/gate-L'" "$out"
chmod -x .jig/scripts/check.sh && git add .jig/scripts/check.sh && git commit -qm "check.sh not executable"
msg="gate: a check.sh that isn't executable is printed as bash ./.jig/scripts/check.sh"
out=$($J gate L 2>&1); git worktree remove --force .git/jig/worktrees/gate-L 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q '&& bash ./.jig/scripts/check.sh'" "$out"
$J merge K >/dev/null 2>&1
msg="merge: L, unsynced, conflicts only in CHANGELOG.md: refused, naming jig sync, with trunk left clean"
out=$($J merge L 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'jig sync. the job, then merge' && ! git rev-parse -q --verify MERGE_HEAD && test -z \"\$(git status --porcelain --untracked-files=no)\" && grep -q '\"L\"' .jig/jobs.json" "$out"
msg="merge: M conflicts in CHANGELOG.md and common.txt: refused, naming jig sync and only the append file"
out=$($J merge M 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'append files (CHANGELOG.md): .jig sync.' && ! git rev-parse -q --verify MERGE_HEAD && grep -q '\"M\"' .jig/jobs.json" "$out"
msg="merge: M's sync resolves CHANGELOG.md and stops on common.txt"
out=$(cd "$FS/.git/jig/worktrees/M" && $J sync 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^  common.txt' && ! echo \"\$0\" | grep -q '^  CHANGELOG.md'" "$out"
(cd "$FS/.git/jig/worktrees/M" && git merge --abort)
(cd "$FS/.git/jig/worktrees/L" && $J sync >/dev/null 2>&1)
SHIM="$T/fu-shim"; mkdir -p "$SHIM" && realgit=$(command -v git)
printf '#!/bin/sh\n[ "$1" = version ] && { echo "git version 2.30.0"; exit 0; }\nfor a in "$@"; do [ "$a" = --write-tree ] && exit 129; done\nexec %s "$@"\n' "$realgit" > "$SHIM/git" && chmod +x "$SHIM/git"
msg="merge: with a git older than 2.38, a synced job is refused, saying 2.38 is needed"
out=$(PATH="$SHIM:$PATH" $J merge L 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'needs git 2.38'" "$out"
msg="merge: once synced, L merges with no new handoff"
expect_pass sh -c "$J merge L && ! grep -q '\"L\"' .jig/jobs.json && grep -q '^- K' CHANGELOG.md && grep -q '^- L' CHANGELOG.md"

# The plugin's hooks: a repo's check.sh may be in another language.
FH="$T/fu-hook"; pcnew "$FH" && git add -A && git commit -qm init && $J init >/dev/null
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' > .jig/scripts/check.sh && cp .jig/scripts/check.sh .jig/scripts/format.sh
chmod +x .jig/scripts/check.sh .jig/scripts/format.sh
msg="plugin hook: an executable Python check.sh that exits 0 lets the Stop hook exit 0, and format.sh runs too"
expect_pass sh -c "CLAUDE_PROJECT_DIR='$FH' bash '$P/../scripts/check.sh' && CLAUDE_PROJECT_DIR='$FH' bash '$P/../scripts/format.sh'"

# R6 "unique" with no job open, and the edit and move cases under a dotted counter.
FU="$T/fu-r6"; pcnew "$FU" && printf 'SCHEMA_VERSION = 17\n' > storage.py && git add -A && git commit -qm init && $J init >/dev/null
board "b['reserve'] = {'schema': {'pattern': r'SCHEMA_VERSION\s*=\s*(\d+)', 'files': ['**/*.py'], 'unique': True}, 'section': {'pattern': r'^### (\d+)\.\d+', 'files': ['docs/**']}}"
mkdir -p docs/a && printf '# A\n\n### 1.1 One\n\n### 2.1 Two\n' > docs/a/a.md && git add -A && git commit -qm board
git switch -q -c feat
msg="R6 unique: no job open, a second SCHEMA_VERSION = 17 on a branch is refused"
printf 'SCHEMA_VERSION = 17\n' > other.py; git add -A; expect_refuse git commit -qm s2; undo
msg="R6 unique: no job open, a new SCHEMA_VERSION = 18 needs no reservation"
printf 'SCHEMA_VERSION = 18\n' > other.py; git add -A; expect_pass git commit -qm s3
git switch -q main && $J open S --reserve section >/dev/null && git add -A && git commit -qm "open S"
cd "$FU/.git/jig/worktrees/S"
msg="R6 dotted: editing ### 2.1's text takes nothing"
sed -i.bak 's/### 2.1 Two/### 2.1 Two renamed/' docs/a/a.md && rm docs/a/a.md.bak; git add -A; expect_pass git commit -qm e1
msg="R6 dotted: moving the page takes nothing"
mkdir -p docs/b && git mv docs/a/a.md docs/b/b.md; expect_pass git commit -qm mv
msg="R6 dotted: ### 1.2 under section 1, which trunk has, takes nothing"
printf '\n### 1.2 More\n' >> docs/b/b.md; git add -A; expect_pass git commit -qm e2
msg="R6 dotted: ### 4.1, not held (S holds 3), is refused"
printf '\n### 4.1 Four\n' >> docs/b/b.md; git add -A; expect_refuse git commit -qm e3; undo
msg="R6 dotted: ### 3.1, held, is accepted"
printf '\n### 3.1 Three\n' >> docs/b/b.md; git add -A; expect_pass git commit -qm e4

# Staging: a destination with prose in it, a register in a new folder, a misspelt register.
FT="$T/fu-st"; pcnew "$FT" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="staging: decisions destination 'the register in docs/DECISIONS.md' is refused as not a path, with no traceback"
stage p1.md this decisions new 'the register in docs/DECISIONS.md' '| D-001 | x | accepted | 2026-11-02 |\n'
out=$($J staging resolve p1.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"isn't a path\" && ! echo \"\$0\" | grep -q Traceback && test ! -e docs/DECISIONS.md" "$out"
msg="staging: doc destination 'see docs/x.md' is refused as not a path, and writes no file"
stage p2.md this doc new 'see docs/x.md'
out=$($J staging resolve p2.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"isn't a path\" && test ! -e 'see docs/x.md'" "$out"
msg="staging: the bare path docs/x.md resolves"
stage p2.md this doc new docs/x.md; expect_pass sh -c "$J staging resolve p2.md && test -f docs/x.md"
msg="staging: decisions staged as new into docs/reg/DECISIONS.md, a folder that doesn't exist, makes it"
stage p1.md this decisions new docs/reg/DECISIONS.md '| D-001 | x | accepted | 2026-11-02 |\n'
expect_pass sh -c "$J staging resolve p1.md && grep -q 'D-001' docs/reg/DECISIONS.md"
FV="$T/fu-stm"; pcnew "$FV" && git add -A && git commit -qm init && $J init --meta --name fv >/dev/null && git add -A && git commit -qm meta-init
msg="staging: in a metarepo, a decisions destination entry_files doesn't name (DECISION.md) is refused"
stage p3.md this decisions new DECISION.md '| D-001 | x | accepted | 2026-11-02 |\n'
out=$($J staging resolve p3.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'entry_files' && test ! -e DECISION.md" "$out"
msg="staging: in a metarepo, destination DECISIONS.md resolves"
stage p3.md this decisions new DECISIONS.md '| D-001 | x | accepted | 2026-11-02 |\n'
expect_pass sh -c "$J staging resolve p3.md && grep -q 'D-001' DECISIONS.md"

# Advice in an old-layout repo names jig update first.
R="$JR" old "$T/fu-old" 5d955a2 jig2
msg="propose: in an old-layout repo it names jig update first"
out=$(python3 "$P/jig/jig.py" propose jig/specs/x.md s 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'older jig layout (jig/lanes.json): run .jig update. first'" "$out"
export JIG_CONFIG="$T/fu-repos.json"
FW="$T/fu-fw"; pcnew "$FW" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J repos add oldrepo "$T/fu-old" >/dev/null
msg="staging: forwarding to a repo on an older layout names jig update there"
stage f1.md oldrepo doc new docs/x.md
out=$($J staging resolve f1.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'older jig layout (jig/lanes.json): run .jig update. there' && test -f .jig/staging/f1.md" "$out"

# Decisions: M2's message, M3 on a cited file renamed away or deleted, sync's terms by the prefix.
FD="$T/fu-dec"; pcnew "$FD" && git add -A && git commit -qm init && $J init --meta --name fd --prefix dec- >/dev/null \
  && git add -A && git commit -qm meta-init && $J release >/dev/null
git switch -q -c m2 && printf '| dec-1 | x | accepted, owner | 2026-11-02 |\n' >> DECISIONS.md && printf -- '- dec-1\n' >> CHANGELOG.md && git add -A
msg="M2: 'accepted, owner' is refused, and the refusal says the note goes in parentheses"
out=$(git commit -qm "DECISIONS: dec-1" 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'exactly a status.*(note)'" "$out"
sed -i.bak 's/accepted, owner/accepted (owner)/' DECISIONS.md && rm DECISIONS.md.bak && git add -A && git commit -qm "DECISIONS: dec-1" \
  && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit m2 && $J release >/dev/null
git switch -q -c m3 && mkdir -p old && git mv README.md old/README.md
msg="M3: README.md renamed out of entry_files, with no changelog line, is refused"
expect_refuse git commit -qm "GLOSSARY: move"
git mv old/README.md README.md && git rm -q README.md
msg="M3: README.md deleted, with no changelog line, is refused"
expect_refuse git commit -qm "GLOSSARY: drop"
git reset -q --hard && git switch -q main
FE="$T/fu-para"; pcnew "$FE" && mkdir -p api && printf 'x=1\n' > api/a.py && printf 'see dec-12\n' > api/twelve.md && printf 'see dec-1.\n' > api/one.md && printf 'two grains\n' > api/g.md \
  && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para fd --location "$FD" >/dev/null 2>&1 && git add -A && git commit -qm "init --para"
(cd "$FD" && git switch -q -c m4 && sed -i.bak 's/| dec-1 | x |/| dec-1 | y |/' DECISIONS.md && rm DECISIONS.md.bak && printf -- '- dec-1 y\n' >> CHANGELOG.md \
  && printf '\n### grain\n\n### vault\nx\n' >> README.md \
  && perl -0pi -e 's/^## Glossary$/## Install\nrun it\n\n## Glossary/m' README.md \
  && git add -A && git commit -qm "DECISIONS: dec-1 y" && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit m4 && $J release >/dev/null)
out=$($J sync 2>&1)
msg="sync: a lowercase decision_prefix's dec-1 is reported, used in api/one.md and not in api/twelve.md"
expect_pass sh -c "echo \"\$0\" | grep -q 'dec-1: used in api/one.md\$'" "$out"
msg="sync: a glossary heading still counts an inflected use (grain in 'grains')"
expect_pass sh -c "echo \"\$0\" | grep -q 'grain: used in api/g.md'" "$out"
msg="sync: a ### term in README.md § Glossary is in the term report"
expect_pass sh -c "echo \"\$0\" | grep -q '^  vault: '" "$out"
msg="sync: a README.md heading outside ## Glossary is no term"
expect_pass sh -c "! echo \"\$0\" | grep -q 'Install'" "$out"

# Hardware: a datasheet whose name holds parentheses.
FK="$T/fu-hw"; pcnew "$FK" && mkdir -p docs/watch/datasheets && printf '%%PDF-fake\n' > 'docs/watch/datasheets/qx-20(rev1).pdf'
printf '# Watch\n\n| RTC | QX-20 | time | [ds](datasheets/qx-20(rev1).pdf) |\n' > docs/watch/watch.md
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="survey: datasheets/qx-20(rev1).pdf, linked bare, is neither missing nor unlinked"
expect_pass hrsurvey "assert r['datasheets_missing'] == [] and r['datasheets_unlinked'] == [], r"
}

# ---------------------------------------------------------------- sync buffer
sec_sync_buffer() {
# A metarepo whose decision cites the pararepo's UI doc, and a pararepo working ahead of it.
SM="$T/sb-meta"; pcnew "$SM" && git add -A && git commit -qm init && $J init --meta --name sbm >/dev/null
printf '| D-001 | the list shows ids (`sb-para/docs/ui.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
printf '| D-002 | the other app has a page (`other-para/docs/x.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
printf '| D-003 | the help page (`SB-Para/docs/z.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
git add -A && git commit -qm meta-init && $J release >/dev/null
SP="$T/sb-para"; pcnew "$SP" && mkdir -p api docs && printf 'x=1\n' > api/a.py && printf '# UI\n' > docs/ui.md && printf '# X\n' > docs/x.md && printf '# Z\n' > docs/z.md && printf 'dist/\n' > .gitignore
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para sbm --location "$SM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release'] = {'artifacts': ['dist/app-*.zip']}" && git add -A && git commit -qm "release protocol"

msg="buffer: a pararepo release with its own steps and a glob that matches nothing tags nothing"
board "b['release']['artifacts'].append('dist/*.dmg')" && git add -A && git commit -qm "release: dmg"
out=$($J release --version 0.9.0 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'made no file matching dist/\\*.dmg' && ! git tag | grep -qx v0.9.0" "$out"
git revert --no-edit HEAD >/dev/null
msg="buffer: a pararepo release with no buffer runs its steps, checks the glob, and opens no proposal branch"
out=$($J release --version 0.9.0 2>&1); expect_pass sh -c "git tag | grep -qx v0.9.0 && test $(sbprops) = 0 && echo \"\$0\" | grep -q 'dist/app-0.9.0.zip'" "$out"
msg="buffer P2: a contract-path change with no buffer row and no spec answer is refused"
printf 'y=2\n' >> api/a.py && git add -A; expect_refuse git commit -qm "api: y"
msg="buffer P2: with a row added to BUFFER.md in the same commit it is accepted"
mkdir -p .jig/ledgers && cp "$P/ledgers/BUFFER.md" .jig/ledgers/BUFFER.md && brow B1 'ids shown' 'names shown' 'first try' Open >> .jig/ledgers/BUFFER.md
git add -A; expect_pass git commit -qm "api: y"
msg="buffer P2: a spec with meta: buffered B1 answers it too"
mkdir -p .jig/specs && printf '# b\n\n- meta: buffered B1\n' > .jig/specs/b.md && printf 'z=3\n' >> api/a.py && git add -A; expect_pass git commit -qm "api: z"
msg="buffer P2: meta: buffered naming a row the ledger doesn't have is refused"
printf '# c\n\n- meta: buffered B9\n' > .jig/specs/c.md && printf 'w=4\n' >> api/a.py && git add -A; expect_refuse git commit -qm "api: w"; undo
msg="buffer P2: a row whose state is neither Open nor Closed is refused"
brow B2 x y z Settling >> .jig/ledgers/BUFFER.md && git add -A; expect_refuse git commit -qm "buffer: B2"; undo
msg="buffer P2: a second row with an id already taken is refused"
brow B1 'ids hidden' 'ids shown' 'twin' Open >> .jig/ledgers/BUFFER.md && printf 'w=4\n' >> api/a.py && git add -A; expect_refuse git commit -qm "api: w"; undo
msg="buffer P2: an Open row closed by hand, in a commit that changes a contract path, is refused"
sed -i.bak 's/| Open |$/| Closed |/' .jig/ledgers/BUFFER.md && rm .jig/ledgers/BUFFER.md.bak && printf 'w=4\n' >> api/a.py && git add -A; expect_refuse git commit -qm "api: w"; undo
msg="buffer P2: an Open row deleted, or the whole ledger, is refused"
sed -i.bak '/^| B1 /d' .jig/ledgers/BUFFER.md && rm .jig/ledgers/BUFFER.md.bak && git add -A && git commit -qm "buffer: drop B1" >/dev/null 2>&1; a=$?; undo
git rm -q .jig/ledgers/BUFFER.md && printf 'w=4\n' >> api/a.py && git add -A && git commit -qm "api: w" >/dev/null 2>&1; b=$?; undo
expect_pass test "$a$b" = 11
msg="buffer P2: a change of mind that edits the row is accepted, and no metarepo branch exists"
sed -i.bak 's/names shown/both shown/' .jig/ledgers/BUFFER.md && rm .jig/ledgers/BUFFER.md.bak && printf 'y=5\n' >> api/a.py && git add -A
expect_pass sh -c "git commit -qm 'api: both' && test \$(git -C '$SM' branch --list 'propose/*' | wc -l) = 0"
msg="buffer P2: meta: none — <reason> and a proposal still answer it"
printf '# n\n\n- meta: none — internal\n' > .jig/specs/n.md && printf 'v=6\n' >> api/a.py && git add -A && git commit -qm "api: v" >/dev/null 2>&1; a=$?
printf '# p\n\n- meta: sbm proposal propose/sb-para-p\n' > .jig/specs/p.md && printf 'u=7\n' >> api/a.py && git add -A && git commit -qm "api: u" >/dev/null 2>&1; b=$?
git rm -q .jig/specs/n.md .jig/specs/p.md .jig/specs/b.md && git commit -qm "specs: done"
expect_pass test "$a$b" = 00
msg="buffer: pushing with open rows succeeds"
git init -q --bare "$T/sb-remote.git" && git remote add origin "$T/sb-remote.git"; expect_pass git push -q origin main
brow B2 'ids sorted' 'unsorted' 'second try' Open >> .jig/ledgers/BUFFER.md && printf 't=8\n' >> api/a.py && git add -A && git commit -qm "api: t"
msg="buffer: jig release with two Open rows opens one metarepo proposal whose spec, in the release, lists both"
out=$($J release --version 1.0.0 2>&1)
expect_pass sh -c "test \$(git -C '$SM' branch --list 'propose/*' | wc -l) = 1 && git -C '$SM' rev-parse -q --verify refs/heads/propose/sb-para-buffer-v1.0.0 >/dev/null && git show v1.0.0:.jig/specs/buffer-v1.0.0.md | grep -qx -- '- B1' && git show v1.0.0:.jig/specs/buffer-v1.0.0.md | grep -qx -- '- B2' && grep -q 'meta: sbm proposal propose/sb-para-buffer-v1.0.0' .jig/specs/buffer-v1.0.0.md && test -z \"\$(git status --porcelain)\"" "$out"
msg="buffer: the release warns, as jig sync does, of a path a metarepo decision cites that contract_paths doesn't cover"
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/ui.md is cited by D-001'" "$out"
msg="buffer: the rows stay Open after the proposal"
expect_pass sh -c "test \$(grep -c '| Open |\$' .jig/ledgers/BUFFER.md) = 2"
brow B3 'ids paged' 'scrolled' 'third try' Open >> .jig/ledgers/BUFFER.md && printf 's=9\n' >> api/a.py && git add -A && git commit -qm "api: s"
(cd "$SM" && git switch -q propose/sb-para-buffer-v1.0.0 && sed -i.bak 's/the list shows ids/the list shows ids and names, sorted/' DECISIONS.md && rm DECISIONS.md.bak \
  && printf -- '- D-001: ids and names, sorted\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001: ids and names" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit propose/sb-para-buffer-v1.0.0 && $J release >/dev/null)
msg="buffer: after the metarepo releases it, jig sync moves the pin and closes B1 and B2 in one commit; B3 stays Open"
before=$(git rev-parse HEAD); out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(git rev-list --count $before..HEAD)\" = 1 && git log -1 --format=%s | grep -qx 'meta: sbm v0.1.0 → v0.2.0' && grep -q '\"pin\": \"v0.2.0\"' .jig/para.json && grep -q 'at \`v0.2.0\`' AGENTS.md && grep -q '^| B1 .*| Closed |\$' .jig/ledgers/BUFFER.md && grep -q '^| B2 .*| Closed |\$' .jig/ledgers/BUFFER.md && grep -q '^| B3 .*| Open |\$' .jig/ledgers/BUFFER.md && test \"\$(git show --name-only --format= HEAD | sort | tr '\n' ' ')\" = '.jig/ledgers/BUFFER.md .jig/para.json AGENTS.md ' && test -z \"\$(git status --porcelain)\" && head -1 .jig/meta-cache/PIN | grep -qx v0.2.0" "$out"
msg="buffer: jig sync reports a pararepo path a metarepo decision cites that contract_paths doesn't cover, and not one it covers or another repo's"
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/ui.md is cited by D-001 and is not a contract path' && ! echo \"\$0\" | grep -q 'api/a.py is cited' && ! echo \"\$0\" | grep -q 'docs/x.md is cited'" "$out"
msg="buffer: a decision may name this repo in any case, the path still exact"
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/z.md is cited by D-003 and is not a contract path'" "$out"
msg="buffer P2: meta: buffered naming a Closed row is refused"
printf '# c\n\n- meta: buffered B1\n' > .jig/specs/c.md && printf 'w=4\n' >> api/a.py && git add -A; expect_refuse git commit -qm "api: w"; undo
msg="buffer: a second sync moves nothing"
before=$(git rev-parse HEAD); out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(git rev-parse HEAD)\" = $before && echo \"\$0\" | grep -q 'sbm v0.2.0 is the latest release'" "$out"
msg="buffer: propose --buffer by hand puts B3, the one Open row, in its own proposal"
out=$($J propose --buffer later 2>&1)
expect_pass sh -c "git -C '$SM' rev-parse -q --verify refs/heads/propose/sb-para-later >/dev/null && grep -qx -- '- B3' .jig/specs/later.md && ! grep -qx -- '- B1' .jig/specs/later.md" "$out"
msg="buffer: the proposal's spec names where each claim lives, and a pointer for one this repo owns"
expect_pass sh -c "grep -q 'What the metarepo holds' .jig/specs/later.md && grep -q 'pointer' .jig/specs/later.md"
git add .jig/specs/later.md && git commit -qm "specs: later"
msg="buffer: a release whose Open rows a proposal already carries unchanged opens no branch"
$J release --version 1.0.1 >/dev/null 2>&1; rc=$?
expect_pass sh -c "test $rc = 0 && git tag | grep -qx v1.0.1 && test \$(git -C '$SM' branch --list 'propose/*' | wc -l) = 2"
sed -i.bak 's/scrolled (third try)/scrolled, then paged (fourth try)/' .jig/ledgers/BUFFER.md && rm .jig/ledgers/BUFFER.md.bak && printf 'r=10\n' >> api/a.py && git add -A && git commit -qm "api: r"
sbland propose/sb-para-later later
msg="buffer: a row edited after its proposal stays Open when that proposal releases; sync commits nothing"
before=$(git rev-parse HEAD); out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(git rev-parse HEAD)\" = $before && grep -q '^| B3 .*| Open |\$' .jig/ledgers/BUFFER.md && echo \"\$0\" | grep -q 'sbm v0.3.0 is out'" "$out"
sbbump v0.3.0
msg="buffer: the edited row goes again in the next release's proposal"
$J release --version 1.0.2 >/dev/null 2>&1
expect_pass sh -c "git -C '$SM' rev-parse -q --verify refs/heads/propose/sb-para-buffer-v1.0.2 >/dev/null && grep -qx -- '- B3' .jig/specs/buffer-v1.0.2.md && grep -q 'fourth try' .jig/specs/buffer-v1.0.2.md"
sbland propose/sb-para-buffer-v1.0.2 again && sbbump v0.4.0
msg="buffer: with the pin bumped by hand past the release, sync still closes the row, in one commit, the pin where it is"
before=$(git rev-parse HEAD); out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(git rev-list --count $before..HEAD)\" = 1 && git log -1 --format=%s | grep -qx 'meta: sbm v0.4.0: close B3' && grep -q '^| B3 .*| Closed |\$' .jig/ledgers/BUFFER.md && grep -q '\"pin\": \"v0.4.0\"' .jig/para.json && test -z \"\$(git status --porcelain)\"" "$out"
git -C "$SM" branch propose/sb-para-extra main && sbland propose/sb-para-extra extra
msg="buffer: a release with every row Closed opens no branch"
n=$(git -C "$SM" branch --list 'propose/*' | wc -l); out=$($J release --version 1.0.3 2>&1)
expect_pass sh -c "git tag | grep -qx v1.0.3 && test \$(git -C '$SM' branch --list 'propose/*' | wc -l) = $n"
msg="buffer: a release after a newer metarepo release, pin not bumped, warns as jig sync does and tags"
expect_pass sh -c "echo \"\$0\" | grep -q 'sbm v0.5.0 is out; this repo pins v0.4.0' && git tag | grep -qx v1.0.3" "$out"
(cd "$SM" && git switch -q -c d4 && mkdir -p .jig/specs .jig/handoffs && printf '# s\n\n## Done when\n\n## Touches\n' > .jig/specs/s.md \
  && printf '# h\n\n## Built\n\n## Left\n' > .jig/handoffs/h.md && printf '| D-004 | ids are links | accepted (owner) | 2026-11-03 |\n' >> DECISIONS.md \
  && printf -- '- D-004\n' >> CHANGELOG.md && git add -A && git commit -qm "D-004: links" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit d4 && $J release >/dev/null)
msg="sync: the changes report lists a new decision, and no heading from the metarepo's .jig/ files"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'sbm v0.6.0 is out' && echo \"\$0\" | grep -q 'D-004:' && ! echo \"\$0\" | grep -qE '(Built|Left|Done when|Touches):'" "$out"
# Page pointers: a metarepo page points to files this repo owns, one of them already gone.
mkdir -p docs/guide && printf '# B\n\n## Build (release)\n\n## The `run` step\n' > docs/b.md && printf '# Guide\n' > docs/guide/a.md && git add -A && git commit -qm "docs: b, guide"
(cd "$SM" && git switch -q -c ptr && printf '\n### Screens\nThe list: `sb-para/docs/ui.md § UI`. See sb-para/docs/ui.md § UI for the list.\n\n### Help\nSee `sb-para/docs/z.md`, `sb-para/docs/gone.md` and sb-para:docs/x.md § Colors.\n\n### Build\n`sb-para/docs/b.md § Build (release)`, then sb-para/docs/b.md § The `run` step, in sb-para/docs/guide. Use this/that wording.\n' >> README.md \
  && printf '| D-005 | the old page (`sb-para/docs/old.md`) | superseded by D-004 | 2026-11-03 |\n' >> DECISIONS.md \
  && printf -- '- D-005, GLOSSARY: Screens, Help, Build\n' >> CHANGELOG.md && git add -A && git commit -qm "D-005, GLOSSARY: Screens, Help, Build" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit ptr && $J release >/dev/null)
sbbump v0.7.0
msg="pointers: sync reports a page pointer to a file this repo doesn't have, and to a heading a file lacks"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -qx '.jig/meta-cache/README.md points to docs/gone.md, which this repo doesn.t have' && echo \"\$0\" | grep -qx '.jig/meta-cache/README.md points to docs/x.md § Colors, which docs/x.md has no heading for'" "$out"
msg="pointers: pointers that resolve print nothing: in prose, a code span with (, a heading with code, a folder"
expect_pass sh -c "! echo \"\$0\" | grep -qE 'points to docs/(ui|z|b)\.md|points to docs/guide'" "$out"
msg="pointers: this/that is not a pointer, a superseded row's pointer isn't checked, and a page pointer gets no contract_paths advice"
expect_pass sh -c "! echo \"\$0\" | grep -qE 'points to that|docs/old.md|docs/x.md is cited'" "$out"
msg="pointers: the pararepo's release warns of a stale pointer and still tags"
out=$($J release --version 1.0.4 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'points to docs/gone.md' && git tag | grep -qx v1.0.4" "$out"
msg="pointers P2: a commit deleting a file a page pointer names is refused, and the refusal names the pointer"
git rm -q docs/z.md; out=$(git commit -qm "docs: drop z" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'README.md points to docs/z.md'" "$out"
msg="pointers P2: a commit renaming the heading a § names is refused, naming it"
sed -i.bak 's/^# UI$/# Screens/' docs/ui.md && rm docs/ui.md.bak && git add -A; out=$(git commit -qm "docs: rename UI" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/ui.md § UI'" "$out"
msg="pointers P2: removing a heading a code-span pointer names, ( and all, is refused"
sed -i.bak '/^## Build (release)$/d' docs/b.md && rm docs/b.md.bak && git add -A; out=$(git commit -qm "docs: drop build" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/b.md § Build (release)'" "$out"
msg="pointers P2: removing a pointed-to folder is refused"
git rm -rq docs/guide; out=$(git commit -qm "docs: drop guide" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/guide'" "$out"
msg="pointers P2: the delete passes with meta: buffered <id>"
brow B4 'help page' 'gone' 'pointer' Open >> .jig/ledgers/BUFFER.md && git add -A && git commit -qm "buffer: B4"
printf '# z\n\n- meta: buffered B4\n' > .jig/specs/z.md && git rm -q docs/z.md && git add -A; expect_pass git commit -qm "docs: drop z"
}

# ---------------------------------------------------------------- pointers
sec_pointers() {
# Numbered pointers: `§2` names `## 2. Motes`, as the Documentation rule cites rules. pp is
# today's pararepo; po is one on v0.6.0, whose P2 let removals through, for update to report.
PM="$T/pm"; pcnew "$PM" && git add -A && git commit -qm init && $J init --meta --name pm >/dev/null
printf '\n### Pointers\n`pp/docs/x.md §2.1`, `pp/docs/x.md §2`, `pp/docs/x.md § 10`, `pp/docs/x.md § 3` and `pp/docs/x.md §1`.\nThe rules: `pp/docs/r.md §1`. Gone: `pp/docs/g.md § Gone`.\nThe prose pp/docs/x.md §1.2 (cited by path, for now)\nTwice: `pp/docs/none.md § A` and `pp/docs/none.md § B`.\nWords, not numbers: `pp/docs/x.md § 2-factor` and `pp/docs/x.md § 2.a`.\nThe old app: `po/docs/x.md §2`, `po/docs/w.md §4`, `po/docs/r.md §1` and `po/docs/ui.md §4`.\nIts theme: po/docs/ui.md § Colors for the theme\n' >> README.md
printf -- '- GLOSSARY: Pointers\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: Pointers" && $J release >/dev/null
# docs <dir>: the pages the metarepo points into
docs() { mkdir -p api docs && printf 'x=1\n' > api/a.py && printf '# X\n\n## 2. Motes\n\n### 2.1 Identity\n\n## 10. Open questions\n' > docs/x.md \
  && printf '# R\n\n## Rules\n\n### 1.1 One\n' > docs/r.md && printf '# G\n\n## Other\n' > docs/g.md && printf '# W\n\n## 4. Keys\n\n## 40 Other\n' > docs/w.md; }
PP="$T/pp"; pcnew "$PP" && docs && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para pm --location "$PM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
G=".jig/meta-cache/README.md points to"
msg="pointers: sync resolves §2.1, §2 and § 10 by number, and reports § 3 and §1, which ## 10. doesn't satisfy"
out=$($J sync 2>&1)
expect_pass sh -c "! echo \"\$0\" | grep -qE 'docs/x.md § (2|2.1|10),' && echo \"\$0\" | grep -qx '$G docs/x.md § 3, which docs/x.md has no heading for' && echo \"\$0\" | grep -qx '$G docs/x.md § 1, which docs/x.md has no heading for'" "$out"
msg="pointers: §1 under ## Rules with ### 1.1 is dangling: 1.1 is not heading 1"
expect_pass sh -c "echo \"\$0\" | grep -qx '$G docs/r.md § 1, which docs/r.md has no heading for'" "$out"
msg="pointers: a prose §1.2 (… prints its number whole, and two pointers into a missing file print one line"
expect_pass sh -c "echo \"\$0\" | grep -qx '$G docs/x.md § 1.2, which docs/x.md has no heading for' && test \$(echo \"\$0\" | grep -c 'docs/none.md') = 1" "$out"
msg="pointers: § 2-factor and § 2.a are words, not heading 2, so they dangle"
expect_pass sh -c "echo \"\$0\" | grep -qx '$G docs/x.md § 2-factor, which docs/x.md has no heading for' && echo \"\$0\" | grep -qx '$G docs/x.md § 2.a, which docs/x.md has no heading for'" "$out"
msg="pointers P2: renaming a file only numbered pointers name is refused, naming the pointer"
git mv docs/x.md docs/y.md; out=$(git commit -qm "docs: x → y" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/x.md, which'" "$out"
msg="pointers P2: deleting ### 2.1 Identity is refused, naming docs/x.md § 2.1"
sed -i.bak '/^### 2.1 Identity$/d' docs/x.md && rm docs/x.md.bak && git add -A; out=$(git commit -qm "docs: drop 2.1" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/x.md § 2.1'" "$out"
msg="pointers P2: renaming a file whose one pointer already dangled is refused: the file is lost"
git mv docs/r.md docs/s.md; out=$(git commit -qm "docs: r → s" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/r.md, which'" "$out"
msg="pointers P2: deleting a file whose one pointer (§ Gone) already dangled is refused"
git rm -q docs/g.md; out=$(git commit -qm "docs: drop g" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'points to docs/g.md, which'" "$out"
msg="pointers P2: an edit that leaves § Gone missing commits"
printf '\n## More\n' >> docs/g.md && git add -A; expect_pass git commit -qm "docs: g more"
msg="pointers P2: the x.md rename commits with meta: buffered <id>"
mkdir -p .jig/ledgers .jig/specs && cp "$P/ledgers/BUFFER.md" .jig/ledgers/BUFFER.md \
  && printf '| B1 | %s: the pointer to docs/x.md | docs/y.md (rename) | owner, 2026-11-05 | Open |\n' "$G" >> .jig/ledgers/BUFFER.md \
  && git add -A && git commit -qm "buffer: B1" >/dev/null
printf '# y\n\n- meta: buffered B1\n' > .jig/specs/y.md && git mv docs/x.md docs/y.md && git add -A; expect_pass git commit -qm "docs: x → y"

# The cleanup: po runs v0.6.0, whose P2 never resolved a number.
PO="$T/po"; mkdir -p "$PO/.t" && git -C "$JR" archive v0.6.0 plugin/templates | tar -x -C "$PO/.t"
cd "$PO" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r .t/plugin/templates/jig .jig && cp .t/plugin/templates/AGENTS.md .t/plugin/templates/CLAUDE.md . && rm -rf .t
docs && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para pm --location "$PM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="pointers: under v0.6.0's hook, renaming x.md and deleting ## 4. Keys both commit (the bug)"
git mv docs/x.md docs/y.md && git commit -qm "docs: x → y" >/dev/null 2>&1; a=$?; mv_hash=$(git rev-parse --short HEAD)
sed -i.bak '/^## 4. Keys$/d' docs/w.md && rm docs/w.md.bak && git add -A && git commit -qm "docs: drop keys" >/dev/null 2>&1; b=$?; keys_hash=$(git rev-parse --short HEAD)
expect_pass test "$a$b" = 00
# One commit drops ## Colors and ## 4: Keys and renames ## Values to ## Keystone, answered by a spec.
printf '# UI\n\n## Colors\n\n## Values\n\n## 4: Keys\n' > docs/ui.md && git add -A && git commit -qm "docs: ui" >/dev/null 2>&1
mkdir -p .jig/specs && printf '# ui\n\n- meta: none — smoke\n' > .jig/specs/ui.md && printf '# UI\n\n## Keystone\n' > docs/ui.md
git add -A && git commit -qm "docs: ui rework" >/dev/null 2>&1; ui_hash=$(git log -1 --format=%h --grep='^docs: ui rework$')
msg="pointers: update's dry run lists Metarepo pointers: the rename and the heading, each with its commit and a BUFFER.md row"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^Metarepo pointers' && echo \"\$0\" | grep 'docs/x.md, which' | grep \"$mv_hash\" | grep 'docs/y.md' | grep -q 'BUFFER.md' && echo \"\$0\" | grep 'docs/w.md § 4,' | grep \"$keys_hash\" | grep -q 'BUFFER.md'" "$out"
msg="pointers: update finds the commit that removed a prose heading (§ Colors for the theme) and a 4: heading, by the resolver"
expect_pass sh -c "test -n '$ui_hash' && echo \"\$0\" | grep 'docs/ui.md § Colors for the theme,' | grep \"$ui_hash\" | grep -q 'BUFFER.md' && echo \"\$0\" | grep 'docs/ui.md § 4,' | grep \"$ui_hash\" | grep -q 'BUFFER.md'" "$out"
msg="pointers: update says this repo never had docs/r.md § 1, names jig propose, offers no row, and changes nothing"
expect_pass sh -c "echo \"\$0\" | grep 'docs/r.md § 1,' | grep 'never had it' | grep -q 'jig propose' && ! echo \"\$0\" | grep 'docs/r.md § 1,' | grep -q 'BUFFER' && test -z \"\$(git status --porcelain)\"" "$out"
msg="pointers: with an Open row naming docs/x.md committed, update offers no row for it, and --apply leaves BUFFER.md alone"
mkdir -p .jig/ledgers && cp "$P/ledgers/BUFFER.md" .jig/ledgers/BUFFER.md \
  && printf '| B1 | %s: the pointer to docs/x.md | docs/y.md, %s | owner, 2026-11-05 | Open |\n' "$G" "$mv_hash" >> .jig/ledgers/BUFFER.md \
  && printf '| B2 | %s: the pointer to docs/w.md § 9 | deleted, abc1234 | owner, 2026-11-05 | Open |\n' "$G" >> .jig/ledgers/BUFFER.md \
  && git add -A && git commit -qm "buffer: B1, B2" >/dev/null
out=$($UP 2>&1); before=$(shasum .jig/ledgers/BUFFER.md); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | grep 'docs/x.md, which' | grep -q 'Open row B1' && ! echo \"\$0\" | grep 'docs/x.md, which' | grep -q 'offer a row' && test \"\$(shasum .jig/ledgers/BUFFER.md)\" = '$before' && test -z \"\$(git status --porcelain -- .jig/ledgers/BUFFER.md)\"" "$out"
msg="pointers: an Open row about another heading of the file (w.md § 9) doesn't stand in for § 4"
expect_pass sh -c "echo \"\$0\" | grep 'docs/w.md § 4,' | grep -q 'offer a row'" "$out"
msg="pointers: RULES.md has the number rule and P2's lost-file rule"
expect_pass sh -c "grep -q '§ 2\` is \`## 2. Motes\`, not \`### 2.1\`' '$P/jig/RULES.md' && grep '^| P2 |' '$P/jig/RULES.md' | grep -q 'a lost file counts even when its heading was already missing'"
}

sec_removals() {
# Removals: a delete changes its path and a rename changes both, for every rule that guards a
# path. rp is today's pararepo; po is one on v0.6.0, whose P2 let removals through.
RM="$T/rm"; pcnew "$RM" && git add -A && git commit -qm init && $J init --meta --name rm >/dev/null
printf '\n### Pointers\nThe old app: `po/api/e.py`.\n' >> README.md
printf -- '- GLOSSARY: Pointers\n' >> CHANGELOG.md && git add -A && git commit -qm "GLOSSARY: Pointers" && $J release >/dev/null
RP="$T/rp"; pcnew "$RP" && mkf api/a.py api/b.py && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para rm --location "$RM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="removals P2: git mv api/a.py lib/a.py is refused, naming P2 api/a.py"
mkdir -p lib && git mv api/a.py lib/a.py; out=$(git commit -qm "mv a" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'P2 api/a.py'" "$out"
msg="removals P2: git rm api/b.py is refused, naming P2 api/b.py"
git rm -q api/b.py; out=$(git commit -qm "rm b" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'P2 api/b.py'" "$out"
msg="removals P4: git rm api/b.py, answered, is refused while a file for the metarepo is staged"
mkdir -p .jig/staging .jig/specs && stage note.md rm doc new docs/n.md
printf '# b\n\n- meta: none — smoke\n' > .jig/specs/b.md && git rm -q api/b.py && git add -A; out=$(git commit -qm "rm b" 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'P4 api/b.py'" "$out"
rm .jig/staging/note.md
msg="removals P2: the rm commits with a spec saying meta: none"
expect_pass git commit -qm "rm b"
msg="removals P2: the mv commits with a spec saying meta: none"
printf '# a\n\n- meta: none — smoke\n' > .jig/specs/a.md && mkdir -p lib && git mv api/a.py lib/a.py && git add -A
expect_pass git commit -qm "mv a"
msg="removals P1: git rm AGENTS.md is refused, naming P1"
git rm -q AGENTS.md; out=$(git commit -qm "rm agents" 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'P1 the AGENTS.md header'" "$out"
msg="removals P3: untracking a tracked .jig/meta-cache/PIN commits"
git add -f .jig/meta-cache/PIN && git commit -q --no-verify -m cache && git rm -q --cached .jig/meta-cache/PIN
expect_pass git commit -qm "untrack PIN"

# Jobs: A owns src/ui/** and tools/**, shares lib/**; B owns src/core/**.
PJ="$T/pj"; pcnew "$PJ" && mkf other/o.py src/core/b.py src/ui/a.py src/ui/w.py tools/t.py docs/ui/ui.md docs/lib/lib.md
git add -A && git commit -qm init && $J init >/dev/null
board "b['docmap'] = {'docs/ui/ui.md': ['src/ui/**'], 'docs/lib/lib.md': ['lib/**']}"
git add -A && git commit -qm board
$J open A --spec t --owns 'src/ui/**' 'tools/**' --shares 'lib/**' >/dev/null 2>&1 && $J open B --spec t --owns 'src/core/**' >/dev/null 2>&1
git add -A && git commit -qm "open A, B"
cd .git/jig/worktrees/A
# refused <rule> <what>: commit what's staged, expect a refusal naming the rule, undo
refused() { out=$(git commit -qm "$2" 2>&1); rc=$?; undo
  expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '$1 '" "$out"; }
msg="removals R3: git rm other/o.py in A is refused"; git rm -q other/o.py; refused R3 rm-o
msg="removals R3: git mv other/o.py src/ui/o.py in A is refused"; git mv other/o.py src/ui/o.py; refused R3 mv-o
msg="removals R4: git rm src/core/b.py in A is refused"; git rm -q src/core/b.py; refused R4 rm-b
msg="removals R4: git mv src/core/b.py src/ui/b.py in A is refused"; git mv src/core/b.py src/ui/b.py; refused R4 mv-b
msg="removals R5: git rm .jig/config.json in A is refused"; git rm -q .jig/config.json; refused R5 rm-config
msg="removals R3: git rm src/ui/w.py in A commits"; git rm -q src/ui/w.py; expect_pass git commit -qm "rm w"
msg="removals fold-in: a move asks the old page and the new, and UNOWNED names only the new path"
mkdir -p lib tools/x && git mv src/ui/a.py lib/a.py && git mv tools/t.py tools/x/t.py && git commit -qm "move a, t"
$J reviewed >/dev/null 2>&1; $J handoff >/dev/null 2>&1; note=$(cat .jig/handoffs/A-*.md 2>/dev/null)
# ui.md counts src/ui/w.py, dropped earlier, and src/ui/a.py's old side: two files, not one.
expect_pass sh -c "echo \"\$0\" | grep 'docs/ui/ui.md' | grep -q '(2 files)' && echo \"\$0\" | grep -q 'docs/lib/lib.md' && echo \"\$0\" | grep -q 'UNOWNED tools/x/t.py' && ! echo \"\$0\" | grep -q 'UNOWNED tools/t.py'" "$note"
msg="removals open: jig open C --owns src/ui/a.py is refused, naming job A, which moved it"
cd "$PJ"; out=$($J open C --spec t --owns src/ui/a.py 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'open job A'" "$out"

# The cleanup: po runs v0.6.0, whose P2 never saw a removal.
PO="$T/po"; mkdir -p "$PO/.t" && git -C "$JR" archive v0.6.0 plugin/templates | tar -x -C "$PO/.t"
cd "$PO" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r .t/plugin/templates/jig .jig && cp .t/plugin/templates/AGENTS.md .t/plugin/templates/CLAUDE.md . && rm -rf .t
mkf api/a.py api/b.py api/c.py api/d.py api/e.py api/f.py && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para rm --location "$RM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="removals: under v0.6.0's hook a move, a drop, an answered drop and a rowed drop all commit (the bug)"
mkdir -p lib .jig/specs .jig/ledgers
git mv api/a.py lib/a.py && git commit -qm "move a" >/dev/null 2>&1; a=$?; mv_hash=$(git rev-parse --short HEAD)
git rm -q api/b.py && git commit -qm "drop b" >/dev/null 2>&1; b=$?; b_hash=$(git rev-parse --short HEAD)
printf '# c\n\n- meta: none — smoke\n' > .jig/specs/c.md && git rm -q api/c.py && git add -A && git commit -qm "drop c" >/dev/null 2>&1; c=$?
cp "$P/ledgers/BUFFER.md" .jig/ledgers/BUFFER.md && printf '| B1 | the contract: api/d.py | deleted | owner, 2026-11-05 | Open |\n' >> .jig/ledgers/BUFFER.md
git rm -q api/d.py && git add -A && git commit -qm "drop d" >/dev/null 2>&1; d=$?
# v0.6.0 already refused losing a file a pointer names, so this one slipped past its hook another way.
git rm -q api/e.py && git commit -q --no-verify -m "drop e" >/dev/null 2>&1; e=$?
git rm -q api/f.py && git commit -qm "drop f" >/dev/null 2>&1 && git checkout -q HEAD~1 -- api/f.py && printf '# f\n\n- meta: none — smoke\n' > .jig/specs/f.md && git add -A && git commit -qm "restore f" >/dev/null 2>&1; f=$?
expect_pass test "$a$b$c$d$e$f" = 000000
out=$($UP 2>&1)
removals=$(echo "$out" | sed -n '/^Contract removals/,/^$/p'); pointed=$(echo "$out" | sed -n '/^Metarepo pointers/,/^$/p')
msg="removals: update's dry run lists the move with its hash, api/a.py → lib/a.py, that lib/a.py isn't a contract path, and a BUFFER.md row"
expect_pass sh -c "echo \"\$0\" | grep \"$mv_hash\" | grep 'api/a.py → lib/a.py' | grep \"lib/a.py isn't a contract path\" | grep -q 'BUFFER.md'" "$removals"
msg="removals: it lists the drop with its hash, api/b.py deleted, and a BUFFER.md row"
expect_pass sh -c "echo \"\$0\" | grep \"$b_hash\" | grep 'api/b.py deleted' | grep -q 'BUFFER.md'" "$removals"
msg="removals: no line for the answered drop (api/c.py), the rowed one (api/d.py) or the restored one (api/f.py), and update changes nothing"
expect_pass sh -c "! echo \"\$0\" | grep -qE 'api/(c|d|f).py' && test -z \"\$(git status --porcelain)\"" "$removals"
msg="removals: a contract path a cached pointer names (po/api/e.py) is under Metarepo pointers, not Contract removals"
expect_pass sh -c "echo \"\$0\" | grep -q 'api/e.py' && ! echo \"\$1\" | grep -q 'api/e.py'" "$pointed" "$removals"
msg="removals: with an Open row naming api/b.py committed, update offers no row for it, and --apply leaves BUFFER.md alone"
printf '| B2 | the contract: api/b.py | deleted, %s | owner, 2026-11-05 | Open |\n' "$b_hash" >> .jig/ledgers/BUFFER.md && git add -A && git commit -qm "buffer: B2" >/dev/null 2>&1
out=$($UP 2>&1); before=$(shasum .jig/ledgers/BUFFER.md); $UP --apply >/dev/null 2>&1
removals=$(echo "$out" | sed -n '/^Contract removals/,/^$/p')
expect_pass sh -c "echo \"\$0\" | grep -q \"$mv_hash\" && ! echo \"\$0\" | grep -q 'api/b.py' && test \"\$(shasum .jig/ledgers/BUFFER.md)\" = '$before'" "$removals"
msg="removals: once the update is committed, update is up to date and still lists the unanswered move and the pointer"
git add -A && git -c core.hooksPath=/dev/null commit -qm update; out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -qx 'up to date' && echo \"\$0\" | sed -n '/^Contract removals/,/^\$/p' | grep -q \"$mv_hash\" && echo \"\$0\" | sed -n '/^Metarepo pointers/,/^\$/p' | grep -q 'api/e.py'" "$out"

msg="removals M1: a metarepo branch removing a code file committed with --no-verify commits"
cd "$RM" && printf 'x=1\n' > tool.py && git add tool.py && git commit -q --no-verify -m code
git switch -q -c drop-tool && git rm -q tool.py; expect_pass git commit -qm "TOOL: drop tool"
msg="removals: RULES.md says a delete and a rename count, and P2's row names them"
expect_pass sh -c "grep -q 'a rename changes both of its paths: R3–R5, P1, P2 and P4 count each' '$P/jig/RULES.md' && grep '^| P2 |' '$P/jig/RULES.md' | grep -q 'a delete, or a rename from one'"
}

# ---------------------------------------------------------------- feedback
sec_feedback() {
export JIG_CONFIG="$T/fb/repos.json"      # its feedback/ fallback sits beside it, never the user's
FB="$T/fb-jig"; pcnew "$FB" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

msg="feedback: a report without from: is refused by the list"
fb .jig/staging nofrom.md
out=$($J staging 2>&1); rc=$?
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q 'no from'" "$out"
rm .jig/staging/nofrom.md
msg="feedback: a report with from: lists as feedback, naming where it came from"
fb .jig/staging r1.md widget
out=$($J staging 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'r1.md: new feedback for this.*from widget'" "$out"
msg="feedback: resolve waits for a spec carrying its Source line, then resolves"
out=$($J staging resolve r1.md 2>&1); rc=$?
mkdir -p .jig/specs && printf '# Fix\n\nSource: chat r1.md (staged as r1.md)\n' > .jig/specs/fix-r1.md
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'a report resolves into a spec' && $J staging resolve r1.md && test ! -e .jig/staging/r1.md" "$out"

msg="feedback: the fallback folder beside repos.json is listed"
fb "$T/fb/feedback" r2.md gadget
expect_pass sh -c "$J staging | grep -q 'r2.md: new feedback.*from gadget'"

msg="feedback: a report in the fallback folder drops from there, and nothing is committed"
before=$(git rev-parse HEAD)
expect_pass sh -c "$J staging drop r2.md && test ! -e '$T/fb/feedback/r2.md' && test \"\$(git rev-parse HEAD)\" = '$before'"

FJ="$T/fb2/jig"; pcnew "$FJ" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="feedback: in a repo named jig, a target: jig report in the fallback waits for a spec carrying its mark, then resolves"
fbj "$T/fb/feedback" r3.md widget
out=$($J staging resolve r3.md 2>&1); rc=$?
mkdir -p .jig/specs && printf '# Fix\n\nSource: chat r3.md (staged as r3.md)\n' > .jig/specs/fix-r3.md
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'a report resolves into a spec' && $J staging resolve r3.md && test ! -e '$T/fb/feedback/r3.md'" "$out"

FR="$T/fb-rel"; pcnew "$FR" && git add -A && git commit -qm init && $J init --meta --name fr >/dev/null && git add -A && git commit -qm meta-init
fb "$T/fb/feedback" other.md widget && sed -i.bak 's/^target: this$/target: elsewhere/' "$T/fb/feedback/other.md" && rm "$T/fb/feedback/other.md.bak"
fb "$T/fb/feedback" mine.md widget && sed -i.bak 's/^target: this$/target: fr/' "$T/fb/feedback/mine.md" && rm "$T/fb/feedback/mine.md.bak"
msg="feedback: release refuses while a report for this repo waits in the fallback, naming it and not another repo's"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'release waits while 1 file.*mine.md' && ! echo \"\$0\" | grep -q other.md && ! git tag | grep -q ." "$out"
msg="feedback: a report naming this repo in another case holds the release too"
$J staging drop mine.md >/dev/null
fb "$T/fb/feedback" upper.md widget && sed -i.bak 's/^target: this$/target: FR/' "$T/fb/feedback/upper.md" && rm "$T/fb/feedback/upper.md.bak"
out=$($J release 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'release waits while 1 file.*upper.md' && ! git tag | grep -q ." "$out"
msg="feedback: once it's dropped, the release goes through beside the other repo's report"
expect_pass sh -c "$J staging drop upper.md >/dev/null && $J release >/dev/null && git tag | grep -q ."
rm "$T/fb/feedback/other.md"
msg="feedback: jig repos prints where tool reports wait"
expect_pass sh -c "$J repos | grep -q 'tool reports wait in .*/fb/feedback while'"
}

# Sections in file order. Ones joined by a comma share state and run in one process, in
# order: staging releases metarepo's $M; R6 as ints works in R6 takes' repo $R.
# The slowest start first, so the run isn't waiting on one that started last.
# ---------------------------------------------------------------- doc homes
sec_homes() {
page() { mkdir -p "$(dirname "$1")" && printf '# %s\n\n## Now\nx\n\n## Rules\n### 1.1 y\n\n## Checks\n- 1.1 review\n' "$1" > "$1"; }
homes() { python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
h = {e['path']: e for e in r['homeless']}
$1"; }
behind() { printf '# behind\n' >> .jig/jig.py && git commit -qam behind; }

HR="$T/homes-rules"; pcnew "$HR" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs && printf '# Old rules\n\n- always do x\n' > docs/AGENTS.md
printf '# App\n\nAgents read [the old rules](docs/AGENTS.md).\n' > README.md
printf '# Guide\n\nsee AGENTS.md\n' > docs/guide.md && printf '# Notes\n\nsome notes\n' > docs/notes.md
git add -A && git commit -qm docs
msg="homes: survey names docs/AGENTS.md as rules, named by README.md alone; docs/notes.md is a stray"
expect_pass homes "assert h['docs/AGENTS.md']['kind'] == 'rules' and h['docs/AGENTS.md']['naming'] == ['README.md'], h.get('docs/AGENTS.md')
assert h['docs/notes.md']['kind'] == 'stray', h"
msg="homes: survey prints docs/AGENTS.md under its own heading, and writes nothing"
before=$(snap); out=$($J survey 2>&1); after=$(snap)
expect_pass sh -c "echo \"\$0\" | grep -A1 '^Agent instruction files off root:' | grep -q '^  docs/AGENTS.md: ' && test \"\$1\" = \"\$2\"" "$out" "$before" "$after"
behind
msg="homes: the dry run lists docs/AGENTS.md to review, naming README.md:3; --apply leaves both alone"
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  docs/AGENTS.md: .*README.md:3' && test -z \"\$(git status --porcelain docs/AGENTS.md README.md)\" && test -f docs/AGENTS.md" "$out"
git commit -qm update
printf '# App\n\nAgents read AGENTS.md.\n' > README.md && git rm -q docs/AGENTS.md && git add -A && git commit -qm "rules: one rulebook"
msg="homes: once the link is repointed and the file deleted, survey lists neither"
expect_pass homes "assert 'docs/AGENTS.md' not in h and 'README.md' not in h, h"

HP="$T/homes-pages"; pcnew "$HP" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
page docs/systems/a.md && page docs/systems/b.md && page docs/c/c.md && page docs/c/d.md
printf -- '- Pages live in `docs/systems/`.\n' >> AGENTS.md
board "b['docmap'] = {'docs/systems/a.md': ['src/**']}"
git add -A && git commit -qm pages
msg="homes: survey gives each page its destination, nested under a folder with its own page, and passes docs/c/c.md"
expect_pass homes "assert {p: h[p]['to'] for p in h if h[p]['kind'] == 'page'} == {'docs/systems/a.md': 'docs/a/a.md', 'docs/systems/b.md': 'docs/b/b.md', 'docs/c/d.md': 'docs/c/d/d.md'}, h
assert 'docs/c/c.md' not in h, h"
behind
msg="homes: the dry run lists the three moves, the docmap key and the AGENTS.md line naming the folder"
out=$($UP 2>&1)
expect_pass sh -c "for w in 'git mv docs/systems/a.md docs/a/a.md' 'git mv docs/systems/b.md docs/b/b.md' 'git mv docs/c/d.md docs/c/d/d.md' '.jig/config.json docmap: docs/systems/a.md' 'AGENTS.md:[0-9]*: - Pages live in .docs/systems/.'; do echo \"\$0\" | grep -q \"^      \$w\" || { echo \"missing \$w\"; exit 1; }; done" "$out"
$UP --apply >/dev/null 2>&1 && git commit -qm update
mkdir -p docs/a docs/b docs/c/d && git mv docs/systems/a.md docs/a/a.md && git mv docs/systems/b.md docs/b/b.md && git mv docs/c/d.md docs/c/d/d.md
sed -i.bak 's|`docs/systems/`|`docs/`|' AGENTS.md && rm AGENTS.md.bak
board "b['docmap'] = {'docs/a/a.md': ['src/**']}" && git add -A && git commit -qm "docs: pages named for their folders"
msg="homes: once the moves are carried out, survey lists none of them"
expect_pass homes "assert not h, h"
page docs/systems/c.md && git add -A && git commit -qm "c again" && behind
msg="homes: a page whose destination exists is proposed as a fold, not a move"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^      fold docs/systems/c.md into docs/c/c.md' && ! echo \"\$0\" | grep -q 'git mv docs/systems/c.md'" "$out"

# The docs tree is two levels deep; a third only on the owner's deep_subsystems entry.
HD="$T/homes-deep"; pcnew "$HD" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
page docs/a/a.md && page docs/a/b/b.md && page docs/a/b/c/c.md && page docs/c/d/d.md && page docs/a/b/x.md
git add -A && git commit -qm deep
msg="homes: a page below a subsystem is deep, folding into its subsystem's page; docs/c/d/d.md passes; a page beside a subsystem's folds into it"
expect_pass homes "assert (h['docs/a/b/c/c.md']['kind'], h['docs/a/b/c/c.md']['to']) == ('deep', 'docs/a/b/b.md'), h
assert 'docs/c/d/d.md' not in h and 'docs/a/b/b.md' not in h, h
assert (h['docs/a/b/x.md']['kind'], h['docs/a/b/x.md']['to'], h['docs/a/b/x.md']['fold']) == ('page', 'docs/a/b/b.md', True), h"
msg="homes: survey prints the deep page under its own heading"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -A2 '^Pages below a subsystem' | tail -1 | grep -q '^  docs/a/b/c/c.md: fold it into docs/a/b/b.md, or ask the owner to approve docs/a/b/c in '" "$out"
behind
msg="homes: the dry run lists the deep page to review; --apply writes no deep_subsystems key"
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  docs/a/b/c/c.md: below a subsystem' && ! grep -q deep_subsystems .jig/config.json" "$out"
git add -A && git commit -qm update
board "b['deep_subsystems'] = {'docs/a/b/c': 'own module; independent of b'}" && git add -A && git commit -qm approve
msg="homes: with docs/a/b/c approved, survey doesn't list docs/a/b/c/c.md"
expect_pass homes "assert 'docs/a/b/c/c.md' not in h, h"
behind
msg="homes: update keeps the deep_subsystems entry and calls no key unknown"
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "! echo \"\$0\" | grep -q 'not one jig knows' && python3 -c \"import json; assert json.load(open('.jig/config.json'))['deep_subsystems'] == {'docs/a/b/c': 'own module; independent of b'}\"" "$out"
git add -A && git commit -qm update
board "b['deep_subsystems'] = {'docs/a/b/c': ''}" && git add -A && git commit -qm unreason
msg="homes: an empty rationale approves nothing"
expect_pass homes "assert h['docs/a/b/c/c.md']['kind'] == 'deep', h"

# A deep page in the old shape, mapped in docmap, under a misspelled approval.
HE="$T/homes-deep-old"; pcnew "$HE" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/e && printf '# E\n\nThe e system.\n' > docs/e/e.md && page docs/e/f/g/g.md && page docs/e/f/g/h/h.md
board "b['docmap'] = {'docs/e/f/g/g.md': ['src/**']}; b['deep_subsystems'] = {'docs/e/f/g/h': 'own rig', 'docs/e/f/g/': 'typo'}"
git add -A && git commit -qm deep-old
msg="homes: a deep page in the old shape gets the contract check, and survey says /jig:redocument"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'run /jig:redocument' && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert any(e['path'] == 'docs/e/f/g/g.md' and any(p.startswith('old contract') for p in e['problems']) for e in r['page_contract']), r['page_contract']
assert r['deep_unmatched'] == ['docs/e/f/g/'], r['deep_unmatched']\"" "$out"
msg="homes: survey names the unapproved level, not the approved one, and says move when the subsystem page is missing"
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/e/f/g/h/h.md: move it to docs/e/f/f.md, or ask the owner to approve docs/e/f/g in ' && echo \"\$0\" | grep -A1 'deep_subsystems keys that name no tracked folder' | grep -q '^  docs/e/f/g/\$'" "$out"
behind
msg="homes: update's deep row names the docmap key a fold touches"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | sed -n '/^  docs\/e\/f\/g\/g.md: below a subsystem/,/^  [^ ]/p' | grep -q '^      .jig/config.json docmap: docs/e/f/g/g.md'" "$out"

# What a citation is not: bytes in a binary, a longer name, the same path under another repo.
HB="$T/homes-bytes"; pcnew "$HB" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf 'x\0README.md docs/ui.md\0' > blob.bin && printf 'caf\351: see README.md\n' > notes.txt
mkdir -p docs && printf '# UI\n' > docs/ui.md && printf 'see touch_ui.md and app/docs/ui.md\n' > other.txt
printf '# Gemini\n' > GEMINI.md && git add -A && git commit -qm bytes
msg="homes: a binary and a Latin-1 file naming README.md: survey and the update dry run both exit 0"
s=$(code $J survey); behind; u=$(code $UP)
expect_pass test "$s$u" = 00
msg="homes: a longer name or another repo's path is no citation; a root GEMINI.md is at home"
expect_pass homes "assert h['docs/ui.md']['naming'] == [], h['docs/ui.md']
assert 'GEMINI.md' not in h, h"

msg="homes: a misplaced page that quotes three RULES.md sentences is a page, not a copy"
python3 - <<'PY'
import re
rules = open('.jig/RULES.md').read()
quoted = [s for s in re.split(r'(?<=[.!?])\s+', re.sub(r'\s+', ' ', rules)) if len(s) > 40 and s[0].isupper()][:3]
open('docs/quoting.md', 'w').write('# Q\n\n## Now\n' + ' '.join(quoted) + '\n\n## Rules\nx\n\n## Checks\ny\n')
PY
git add -A && git commit -qm quoting
expect_pass homes "assert h['docs/quoting.md']['kind'] == 'page', h['docs/quoting.md']"

HX="$T/homes-meta-fresh"; pcnew "$HX" && git add -A && git commit -qm init && $J init --meta --name hx >/dev/null && git add -A && git commit -qm meta
msg="homes: a fresh metarepo, its CHANGELOG.md included, has no homeless files"
expect_pass homes "assert not h, h"

# A pararepo whose page a metarepo decision points into, as sync_buffer builds one.
HM="$T/homes-meta"; pcnew "$HM" && git add -A && git commit -qm init && $J init --meta --name hm >/dev/null
printf '| D-001 | the list rule (`app/docs/systems/a.md § Rules`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
git add -A && git commit -qm meta-init && $J release >/dev/null
HA="$T/app"; pcnew "$HA" && page docs/systems/a.md && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para hm --location "$HM" --contract 'docs/systems/a.md' >/dev/null && git add -A && git commit -qm "init --para"
behind
msg="homes: in a pararepo, a page's proposal names the cached pointer, BUFFER.md and the contract path"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^      .jig/meta-cache/DECISIONS.md points at docs/systems/a.md § Rules' && echo \"\$0\" | grep -q '^      the move.s commit carries a .jig/ledgers/BUFFER.md row' && echo \"\$0\" | grep -q '^      .jig/para.json contract_paths: docs/systems/a.md'" "$out"
# A glossary is README.md § Glossary, one ### heading per term, in any repo.
HG="$T/homes-glossary"; pcnew "$HG" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '# App\n\n## Glossary\n\n**mote** — x\n\n**seam** (join): y\n\n**not** a term here\n\n## Use\n\n**late** — outside the section\n' > README.md
printf '# Glossary\n\n**grain** — z\n' > GLOSSARY.md && git add -A && git commit -qm glossary
msg="homes: survey names mote and seam, bold terms in README.md § Glossary, and nothing outside it"
expect_pass homes "assert r['glossary_unheaded'] == ['mote', 'seam'], r['glossary_unheaded']"
msg="homes: a root GLOSSARY.md is listed with to README.md § Glossary, in --json and in print"
expect_pass homes "assert h['GLOSSARY.md']['kind'] == 'stray' and h['GLOSSARY.md']['to'] == 'README.md § Glossary', h.get('GLOSSARY.md')"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^GLOSSARY.md → README.md § Glossary' && echo \"\$0\" | grep -q 'not headings: 2 (mote, seam)'" "$out"
printf '# App\n\n## Glossary\n\n### mote\nx\n\n### seam\ny\n' > README.md && git commit -qam headings
msg="homes: with ### headings instead, survey names no term"
expect_pass homes "assert r['glossary_unheaded'] == [], r['glossary_unheaded']"
behind
msg="homes: update lists GLOSSARY.md under Repo files to review, and --apply leaves it alone"
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  GLOSSARY.md: the glossary.s home is README.md § Glossary' && test -z \"\$(git status --porcelain GLOSSARY.md README.md)\" && test -f GLOSSARY.md" "$out"
}

# ---------------------------------------------------------------- update's AGENTS.md lines
sec_agents_lines() {
abehind() { printf '# behind\n' >> .jig/jig.py && git commit -qam behind; }
alines() { $UP 2>&1 | grep '^  AGENTS.md: '; }
AL="$T/agents-lines"; pcnew "$AL"
sed -i.bak -e 's/`TODO`/`make filled-cmd`/' -e 's/^TODO: one sentence.*/A filled-project sentence./' -e '/^- setup:/d' AGENTS.md
python3 -c "
s = open('AGENTS.md').read(); a = s.index('## Firmware'); b = s.index('## Context')
open('AGENTS.md', 'w').write(s[:a] + s[b:])"
rm AGENTS.md.bak && test -f .jig/scripts/setup.sh && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
abehind
out=$($UP 2>&1)
msg="agents lines: no template diff and none of the filled text; the one AGENTS.md line proposes the template's setup: line"
expect_pass sh -c "! echo \"\$0\" | grep -qE 'against the template|filled-' && test \"\$(echo \"\$0\" | grep -c '^  AGENTS.md: ')\" = 1 && echo \"\$0\" | grep -q '^  AGENTS.md: names no .\.jig/scripts/setup\.sh.: add under ## Commands .- setup:  .\.jig/scripts/setup\.sh. (runs itself'" "$out"
grep '^- setup:' "$P/AGENTS.md" > s.tmp && sed -i.bak '/^- check:/r s.tmp' AGENTS.md && rm s.tmp AGENTS.md.bak && git commit -qam setup
msg="agents lines: with the setup: line restored, no AGENTS.md line prints"
out=$(alines); expect_pass test -z "$out"
sed -i.bak 's/^- Rulebook .*/- Read `.jig\/RULES.md` (the rulebook) first./' AGENTS.md && rm AGENTS.md.bak && git commit -qam aside
msg="agents lines: a mention of RULES.md with an aside after it counts as the Rulebook line"
out=$(alines); expect_pass test -z "$out"
git checkout -q HEAD~1 -- AGENTS.md && git commit -qm "rulebook back"
sed -i.bak '/^- Rulebook /d' AGENTS.md && rm AGENTS.md.bak && git commit -qam "no rulebook"
msg="agents lines: with the Rulebook line removed, it is proposed, though the docs lines cite RULES.md (Documentation)"
out=$(alines); want="  AGENTS.md: names no \`.jig/RULES.md\`: add under ## Workflow \`$(grep '^- Rulebook ' "$P/AGENTS.md")\`"
expect_pass sh -c "grep -q 'RULES.md. (Documentation)' AGENTS.md && test \"\$0\" = \"\$1\"" "$out" "$want"
git checkout -q HEAD~1 -- AGENTS.md && git commit -qm rulebook

python3 -c "
s = open('AGENTS.md').read(); i = s.index('## Code')
open('AGENTS.md', 'w').write(s[:i] + '## Jobs (parallel sessions)\n- We split work our own way.\n- Ask before merging.\n\n' + s[i:])"
git commit -qam "a reworded Jobs block"
n=$(grep -n '^## Jobs (parallel sessions)' AGENTS.md | cut -d: -f1)
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
msg="agents lines: a reworded Jobs block, the Rulebook line already under Workflow, is proposed for deletion, naming its lines; --apply leaves AGENTS.md alone"
expect_pass sh -c "echo \"\$0\" | grep -q \"^  AGENTS.md: lines ${n}–$((n + 2)), .## Jobs (parallel sessions)., are a block jig retired: delete it, heading to the next heading: the Rulebook line is already outside it\" && test -z \"\$(git status --porcelain AGENTS.md)\"" "$out"
git commit -qm update
sed -i.bak 's/^## Jobs (parallel sessions)$/## Lanes (parallel sessions)/' AGENTS.md && rm AGENTS.md.bak && git commit -qam lanes && abehind
msg="agents lines: the same block under Lanes is proposed too"
out=$(alines); expect_pass sh -c "echo \"\$0\" | grep -q \"lines ${n}–$((n + 2)), .## Lanes (parallel sessions)., are a block jig retired\"" "$out"
sed -i.bak 's/^## Lanes (parallel sessions)$/## Jobs we run/' AGENTS.md && rm AGENTS.md.bak && git commit -qam "our own jobs"
msg="agents lines: a repo's own ## Jobs we run gets no proposal"
out=$(alines); expect_pass sh -c "test -z \"\$0\" && grep -q '^## Jobs we run' AGENTS.md" "$out"
}

SLOW="pararepo_commands entry_globs report_fixes sync_buffer"
# ---------------------------------------------------------------- a / in a branch or job name
sec_slash_names() {
SL="$T/slash"; D=$(date +%F)
mkdir -p "$SL" && cd "$SL" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p src && printf 'x=1\n' > src/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board

git checkout -q -b a/b-c
printf 'x=2\n' > src/a.py && git commit -qam work
$J reviewed --tier 2 --effort 2 >/dev/null
out=$($J handoff --spec .jig/specs/x.md 2>&1); rc=$?
msg="slash: solo on a/b-c, handoff writes the flat .jig/handoffs/a-b-c-<date>.md and no subfolder"
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'wrote .jig/handoffs/a-b-c-$D.md' && test ! -e .jig/handoffs/a" "$out"
foldin && git add -A && git commit -qm note
head=$(git rev-parse HEAD~1)
out=$($J gate 2>&1); rc=$?
msg="slash: gate finds the note, exits 0, and never says the report's 'has filed no handoff note'"
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'a/b-c: gate ${head:0:12} from .jig/handoffs/a-b-c-$D.md on a/b-c' && ! echo \"\$0\" | grep -q 'has filed no handoff note'" "$out"
msg="slash: the gate's scratch is the flat gate-a-b-c, and its printed cleanup leaves worktrees/ empty"
rm_line=$(echo "$out" | grep -o 'git worktree remove --force [^ ]*' | head -1)
expect_pass sh -c "test -d .git/jig/worktrees/gate-a-b-c && test '$rm_line' = 'git worktree remove --force .git/jig/worktrees/gate-a-b-c' && $rm_line && test -z \"\$(ls -A .git/jig/worktrees)\""

# Branch a-b-c's note on a/b-c: one stem, another name in its header.
printf '# Handoff: a-b-c\n\nCommit: %s\n' "$(git rev-parse HEAD~2)" > ".jig/handoffs/a-b-c-$D-2.md"
git add -A && git commit -qm "a-b-c's note"
out=$($J gate 2>&1); rc=$?
git worktree remove --force .git/jig/worktrees/gate-a-b-c 2>/dev/null
msg="slash: a note whose header names a-b-c is not a/b-c's, so gate still takes a-b-c-<date>.md"
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'a/b-c: gate ${head:0:12} from .jig/handoffs/a-b-c-$D.md on a/b-c'" "$out"

git checkout -q main
$J open a/b >/dev/null 2>&1 && git add -A && git commit -qm "open a/b"
(cd .git/jig/worktrees/a/b && printf 'y=1\n' > src/b.py && git add -A && git commit -qm b \
  && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && git add -A && git commit -qm note)
msg="slash: open refuses job a-b while a/b is open, naming the shared file name"
out=$($J open a-b 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'open job a/b share the file name a-b' && ! python3 -c \"import json, sys; sys.exit('a-b' not in json.load(open('.jig/jobs.json')))\"" "$out"
msg="slash: job a/b's handoff writes .jig/handoffs/a-b-<date>.md, and status on trunk counts it"
expect_pass sh -c "git show a/b:.jig/handoffs/a-b-$D.md | head -1 | grep -qx '# Handoff: a/b' && $J status | grep -q '^  a/b .*handoffs:1 '"

SU="$T/slash-up"
mkdir -p "$SU" && cd "$SU" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init >/dev/null
mkdir -p .jig/handoffs/a .jig/handoffs/x
printf '# Handoff: a/b-c\n' > .jig/handoffs/a/b-c-2026-01-01.md
printf '# Handoff: x/y\n' > .jig/handoffs/x/y-2026-01-01.md
printf '# Handoff: x-y\n' > .jig/handoffs/x-y-2026-01-01.md
git add -A && git -c core.hooksPath=/dev/null commit -qm "notes the bug left"
out=$($UP 2>&1)
msg="slash: update's dry run flattens both nested notes, a clash taking -2, and changes nothing"
expect_pass sh -c "echo \"\$0\" | sed -n '/^Moves/,/^\$/p' > m && grep -qx '  .jig/handoffs/a/b-c-2026-01-01.md → .jig/handoffs/a-b-c-2026-01-01.md' m && grep -qx '  .jig/handoffs/x/y-2026-01-01.md → .jig/handoffs/x-y-2026-01-01-2.md' m && rm m && test -z \"\$(git status --porcelain)\"" "$out"
$UP --apply >/dev/null 2>&1
msg="slash: update --apply stages both renames, removes the emptied subfolders, and a rerun is up to date"
expect_pass sh -c "$(declare -f renamed); renamed .jig/handoffs/a/b-c-2026-01-01.md .jig/handoffs/a-b-c-2026-01-01.md && renamed .jig/handoffs/x/y-2026-01-01.md .jig/handoffs/x-y-2026-01-01-2.md && test ! -e .jig/handoffs/a && test ! -e .jig/handoffs/x && $UP | grep -qx 'up to date'"
# An older tool's handoff folder that update moves here whole, subfolders and all: not the bug's.
ax "$T/slash-ax" "mkdir -p .aidev/handoffs/lane-a && printf '# r1\n' > .aidev/handoffs/lane-a/round-1.md && printf '# Handoff: lane-a\n' > .aidev/handoffs/lane-a/lane-a-2026-01-01.md"
$UP --apply >/dev/null 2>&1; git add -A && git -c core.hooksPath=/dev/null commit -qm update
msg="slash: a subfolder update moved from .aidev/handoffs/ stays nested, and a second update is up to date"
expect_pass sh -c "test -f .jig/handoffs/lane-a/round-1.md && test -f .jig/handoffs/lane-a/lane-a-2026-01-01.md && $UP | grep -qx 'up to date'"
}

# ---------------------------------------------------------------- page contract
sec_page_contract() {
pc() { python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
c = {e['path']: e['problems'] for e in r['page_contract']}
h = {e['path']: e for e in r['homeless']}
$1"; }
# answer <note> <python>: rewrite the note's fold-in lines, n the note's text
answer() { python3 -c "
import sys; f = sys.argv[1]; n = open(f).read()
$2
open(f, 'w').write(n)" "$1"; }
PG="$T/page-contract"; pcnew "$PG" && mkdir -p src docs/ui && printf 'x = 1\n' > src/ui.py
printf '# UI\n\nThe UI draws the list.\n\n## Renderer\n\nDraws rows.\n\n## Invariants\n\n- Rows are at least 44px — touch-target minimum; held by test_touch_targets.\n\n## Undefined\n\n- Offline mode — stops at the cache layer; parked 2026-11-01.\n- Dark theme — stops at the palette; parked 2026-11-02.\n' > docs/ui/ui.md
git add -A && git commit -qm init && $J init >/dev/null && board "b['docmap'] = {'docs/ui/ui.md': ['src/**']}" && git add -A && git commit -qm board
$J open U1 --spec t --owns 'src/**' 'docs/ui/**' >/dev/null && git add -A && git commit -qm "open U1"
cd .git/jig/worktrees/U1 && printf 'x = 2\n' > src/ui.py && git commit -qam change && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/U1-*.md)
msg="page contract: the handoff writes one fold-in line per Undefined entry on a covering page"
expect_pass sh -c "grep -qF -- '- [ ] Undefined in docs/ui/ui.md: \"Offline mode — stops at the cache layer; parked 2026-11-01.\" — built / untouched / departed: ___' $note && grep -qF -- '- [ ] Undefined in docs/ui/ui.md: \"Dark theme' $note"
answer $note "n = n.replace('- [ ] docs/ui/ui.md — updated / no change because ___', '- [x] docs/ui/ui.md — no change because the renderer still draws rows')"
git add -A && git commit -qm "note"
msg="page contract: the gate refuses while an Undefined line is blank"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'unanswered' && echo \"\$0\" | grep -q 'Undefined in docs/ui/ui.md' && ! echo \"\$0\" | grep -q 'no change because ___'" "$out"
answer $note "import re; n = re.sub(r'- \[ \] (Undefined in .*Offline.*) — built / untouched / departed: ___', r'- [x] \1 — Untouched (not this task)', n); n = re.sub(r'- \[ \] (Undefined in .*Dark.*) — built / untouched / departed: ___', r'- [x] \1 — departed: themes moved to the OS setting', n)"
git commit -qam "answer"
msg="page contract: the gate passes untouched and departed answers, with text after them, in any case"
expect_pass sh -c "cd '$PG' && $(declare -f gate_ok); J='$J'; gate_ok U1"
answer $note "n = n.replace('— Untouched (not this task)', '— built — moved into Cache')"
git commit -qam "built, not moved"
msg="page contract: the gate refuses built while the entry is still under Undefined"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'built means moved, not copied'" "$out"
python3 -c "
f = 'docs/ui/ui.md'; s = open(f).read()
open(f, 'w').write(s.replace('- Offline mode — stops at the cache layer;', '- Offline mode (built, see Cache) — stops at the cache layer;').replace('## Renderer\n\nDraws rows.\n', '## Renderer\n\nDraws rows.\n\n## Cache\n\nWorks offline.\n'))"
git commit -qam "offline mode: entry reworded, not deleted" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
fold2() { answer $1 "import re; n = n.replace('- [ ] docs/ui/ui.md — updated / no change because ___', '- [x] docs/ui/ui.md — updated: Cache'); n = re.sub(r'- \[ \] (Undefined in .*Offline.*) — built / untouched / departed: ___', r'- [x] \1 — built', n); n = re.sub(r'- \[ \] (Undefined in .*Dark.*) — built / untouched / departed: ___', r'- [x] \1 — untouched', n)"; }
fold2 $(ls .jig/handoffs/U1-*-2.md) && git add -A && git commit -qm "note 2"
msg="page contract: the gate refuses built when the entry was reworded instead of deleted, and names it"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'a reworded entry is still the entry' && echo \"\$0\" | grep -q 'reworded, still under Undefined: Offline mode (built, see Cache)'" "$out"
python3 -c "
import re; f = 'docs/ui/ui.md'; s = open(f).read()
open(f, 'w').write(re.sub(r'- Offline mode .*\n', '', s) + '- Export to CSV — stops at the file picker; parked 2026-11-06.\n')"
git commit -qam "offline mode built; export parked" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/U1-*-3.md)
msg="page contract: an entry the branch deleted still gets its line, from trunk's page"
expect_pass grep -qF 'Undefined in docs/ui/ui.md: "Offline mode' $note
fold2 $note && git add -A && git commit -qm "note 3"
msg="page contract: the gate passes built once the entry is gone, beside an unrelated new entry"
expect_pass sh -c "cd '$PG' && $(declare -f gate_ok); J='$J'; gate_ok U1"
answer $note "n = n.replace('— untouched', '— built / untouched')"
git commit -qam "two answers"
msg="page contract: the gate refuses a line that keeps more than one answer, and says so"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'more than one answer kept'" "$out"
answer $note "n = n.replace('— built / untouched', '— departed')"
git commit -qam "bare departed"
msg="page contract: the gate refuses departed with no why"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'departed needs its why'" "$out"

cd "$PG" && mkdir -p docs/old docs/inv docs/after docs/nolead docs/misc
printf '# Old\n\n## Now\nx\n\n## Rules\n### 1.1 y\n\n## Checks\n- 1.1 review\n' > docs/old/old.md
printf '# Inv\n\nInv holds keys.\n\n## Invariants\n\n- Keys are sorted — lookups bisect; held by test_sorted.\n- Keys are short.\n- Keys are ASCII — the wire format.\n' > docs/inv/inv.md
printf '# After\n\nAfter does things.\n\n## Undefined\n\n- Sync — parked 2026-11-01.\n\n## Notes\n\nmore\n' > docs/after/after.md
printf '# Nolead\n\n## Part\n\nText.\n' > docs/nolead/nolead.md
printf '# Misc\n\nMisc is a part.\n\n## Invariants\n\n- A — b; held by review.\n' > docs/misc/x.md
git add -A && git commit -qm pages
msg="page contract: survey flags an old-format page as old contract — convert"
expect_pass pc "assert len(c['docs/old/old.md']) == 1 and c['docs/old/old.md'][0].startswith('old contract — convert'), c"
msg="page contract: survey flags invariants missing a holder or a why, and passes the one with both"
expect_pass pc "p = c['docs/inv/inv.md']; assert len(p) == 2 and any('Keys are short.' in x for x in p) and any('Keys are ASCII' in x for x in p), p"
msg="page contract: survey flags a section after Undefined, and a page with no lead paragraph"
expect_pass pc "assert any('after ## Undefined: Notes' in x for x in c['docs/after/after.md']), c
assert any('no lead paragraph' in x for x in c['docs/nolead/nolead.md']), c"
msg="page contract: a page in the contract and a misplaced page are not read against it"
expect_pass pc "assert not {'docs/ui/ui.md', 'docs/misc/x.md'} & set(c), c"
msg="page contract: a misplaced page with an Invariants section is a page, given its home"
expect_pass pc "assert h['docs/misc/x.md']['kind'] == 'page' and h['docs/misc/x.md']['to'] == 'docs/x/x.md', h"
msg="page contract: survey prints them under their own heading"
expect_pass sh -c "$J survey | grep -A9 '^Pages off the page contract' | grep -q '^  docs/old/old.md: old contract — convert'"
msg="page contract: survey points a repo with old-contract pages at /jig:redocument, not /jig:adopt"
expect_pass sh -c "$J survey | tail -1 | grep -q 'run /jig:redocument to convert them'"
msg="page contract: an old-format page outside the docs tree points at /jig:redocument too"
PO="$T/page-outside"; pcnew "$PO" && mkdir -p docs/notes && printf '# Sync\n\n## Now\nx\n\n## Rules\n### 1.1 y\n\n## Checks\n- 1.1 review\n' > docs/notes/sync.md
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
expect_pass sh -c "$J survey | tail -1 | grep -q 'run /jig:redocument to convert them'"

PU="$T/page-template"; pcnew "$PU" && rm .jig/docs-page.md && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="page contract: update installs .jig/docs-page.md in a repo that lacks it, and a rerun is up to date"
$UP --apply >/dev/null 2>&1; git add -A && git commit -qm update
expect_pass sh -c "cmp -s .jig/docs-page.md '$P/jig/docs-page.md' && $UP | grep -qx 'up to date'"
msg="page contract: a solo commit on trunk that deletes an Undefined entry still gets its line"
mkdir -p src docs/s && printf 'x = 1\n' > src/s.py && printf '# S\n\nS is.\n\n## Undefined\n\n- Sync — parked 2026-11-01.\n' > docs/s/s.md
board "b['docmap'] = {'docs/s/s.md': ['src/**']}" && git add -A && git commit -qm s
printf 'x = 2\n' > src/s.py && printf '# S\n\nS is, and syncs.\n' > docs/s/s.md && git commit -qam "sync built" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
expect_pass grep -qF 'Undefined in docs/s/s.md: "Sync' .jig/handoffs/main-*.md
}

# ---------------------------------------------------------------- roadmap
sec_roadmap() {
rspec() { mkdir -p .jig/specs && printf '# %s\n\nSource: smoke\nScope: %s\n\n## Intent\nx\n' "$1" "$2" > ".jig/specs/$1.md"; }
rsolo() {  # rsolo <spec> [--partial] [--spec path]: a solo handoff of that spec on trunk, landed
  printf '%s\n' "$1" >> work.txt && git add -A && git commit -qm "work $1" && $J reviewed >/dev/null \
    && $J handoff --spec "${3:-.jig/specs/$1.md}" ${2:-} >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $1"; }
rstate() { $J roadmap | grep -E "^  $1 " | awk '{print $2}'; }
rphase() { $J roadmap | grep -E "^$1 " | awk '{print $2}'; }
RM="$T/rm"; pcnew "$RM" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '# Roadmap\n\n## alpha\nExit when:\n- [ ] boots on the dev board\nScopes:\n- `screen`: the panel driver\n- `battery`: charge state\n- `sound`: a beep\n\n## beta\nExit when:\n- [ ] ships to a tester\nScopes:\n- `radio`: the link\n- `ota`: updates\n' > .jig/roadmap.md
rspec s1 'alpha/screen, alpha/battery' && rspec s2 alpha/battery && rspec s3 beta/radio && rspec s4 alpha/sound
git add -A && git commit -qm roadmap

msg="roadmap: a scope no spec takes is open; one taken by a spec with no landed handoff is taken"
$J roadmap > /dev/null
expect_pass test "$(rstate beta/ota)|$(rstate alpha/screen)" = "open|taken"
rsolo s1
msg="roadmap: a scope whose specs all have landed handoffs is done; one spec taking two scopes counts for both"
expect_pass sh -c "test '$(rstate alpha/screen)' = done && $J roadmap | grep -E '^  alpha/battery ' | grep -q 's1.md (complete)'"
msg="roadmap: a scope taken by two specs stays taken until both are complete"
expect_pass test "$(rstate alpha/battery)" = taken
rsolo s2 --partial
msg="roadmap: a landed --partial handoff records Partial: yes and leaves its spec incomplete"
expect_pass sh -c "grep -q '^Partial: yes' .jig/handoffs/main-*.md && test '$(rstate alpha/battery)' = taken"
rsolo s2
msg="roadmap: a later full handoff completes it, and the scope is done"
expect_pass test "$(rstate alpha/battery)" = done
rsolo s4 "" "$PWD/.jig/specs/s4.md"
msg="roadmap: an absolute --spec is written from the repo root, and still completes its spec"
expect_pass sh -c "grep -qx 'Spec: .jig/specs/s4.md' .jig/handoffs/main-*.md && ! grep -q '^Spec: /' .jig/handoffs/main-*.md && test '$(rstate alpha/sound)' = done"
msg="roadmap: a --spec outside the repo is refused"
expect_refuse sh -c "printf 'y\n' >> work.txt && git commit -qam y && $J reviewed >/dev/null && $J handoff --spec /tmp/elsewhere.md"
git reset -q --hard HEAD~1
msg="roadmap: every scope done but an exit box unticked: the phase isn't done"
expect_pass test "$(rphase alpha)|$(rphase beta)" = "current|next"
sed -i.bak 's/- \[ \] boots/- [x] boots/' .jig/roadmap.md && rm .jig/roadmap.md.bak && git commit -qam "alpha: boots"
msg="roadmap: ticking it makes the phase done, and the current phase moves to the next"
expect_pass test "$(rphase alpha)|$(rphase beta)" = "done|current"

msg="roadmap: jig roadmap reports a missing ROADMAP.md"
expect_pass sh -c "$J roadmap | grep -q 'ROADMAP.md on main is missing'"
$J roadmap --write >/dev/null
msg="roadmap: --write writes the phase line and a board per phase, scopes in their columns with their specs linked"
expect_pass python3 - <<'PY'
t = open('ROADMAP.md').read()
assert 'alpha ✓ → **beta** (current)' in t, t
assert 'jig roadmap --write' in t.splitlines()[2], t
beta = t.split('## beta')[1]
rows = [l for l in beta.splitlines() if l.startswith('| ') and 'Open' not in l]
cells = [[c.strip() for c in r.strip('|').split(' | ')] for r in rows]
assert cells[0][0].startswith('**ota**') and cells[0][1].startswith('**radio**') and '[s3](.jig/specs/s3.md)' in cells[0][1], cells
alpha = t.split('## alpha')[1].split('## beta')[0]
done = [[c.strip() for c in r.strip('|').split(' | ')][2] for r in alpha.splitlines() if r.startswith('| **') or r.startswith('|  |')]
assert any('**battery**' in d and '[s1](.jig/specs/s1.md) ✓' in d and '[s2](.jig/specs/s2.md) ✓' in d for d in done), alpha
assert '- [x] boots on the dev board' in alpha, alpha
PY
git add -A && git commit -qm "roadmap view"
msg="roadmap: once committed it isn't stale"
expect_pass sh -c "! $J roadmap | grep -q stale"
msg="roadmap: survey counts ROADMAP.md as a home, not a stray"
expect_pass hrsurvey "assert 'ROADMAP.md' not in [e['path'] for e in r['homeless']], r['homeless']"

$J open J --spec .jig/specs/s3.md >/dev/null && git add -A && git commit -qm "open J"
( cd .git/jig/worktrees/J && printf 'radio\n' > radio.txt && git add -A && git commit -qm radio \
  && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note J" )
msg="roadmap: a bare jig handoff in a job writes the board's spec as its Spec:"
expect_pass grep -qx 'Spec: .jig/specs/s3.md' .git/jig/worktrees/J/.jig/handoffs/J-*.md
msg="roadmap: the hook refuses .jig/roadmap.md and ROADMAP.md edits on a branch (R5)"
out=$(cd .git/jig/worktrees/J && printf 'x\n' >> .jig/roadmap.md && printf 'x\n' >> ROADMAP.md && git add -A && $J check --staged; git reset -q --hard)
expect_pass sh -c "echo \"\$0\" | grep -q 'R5 the roadmap is the owner.s: .jig/roadmap.md' && echo \"\$0\" | grep -q 'R5 the roadmap is the owner.s: ROADMAP.md'" "$out"
msg="roadmap: the hook refuses a spec on a branch citing a scope the roadmap doesn't have"
out=$(cd .git/jig/worktrees/J && rspec bad alpha/nope && git add -A && git commit -qm bad 2>&1; git reset -q --hard; git clean -fdq)
expect_pass sh -c "echo \"\$0\" | grep -q 'bad.md takes alpha/nope'" "$out"
$J merge J >/dev/null
msg="roadmap: jig merge rewrites ROADMAP.md in the merge commit, moving the job's scope to Done"
expect_pass sh -c "git show --name-only --format= HEAD | grep -qx ROADMAP.md && git show HEAD:ROADMAP.md | python3 -c \"
import sys; beta = sys.stdin.read().split('## beta')[1]
row = [l for l in beta.splitlines() if 'radio' in l][0]
assert [c.strip() for c in row.strip('|').split(' | ')][2].startswith('**radio**'), row\""
rspec s5 beta/ota && git add -A && git commit -qm s5
msg="roadmap: jig roadmap reports a stale ROADMAP.md after solo work on trunk"
expect_pass sh -c "$J roadmap | grep -q 'ROADMAP.md on main is stale'"

msg="roadmap: the hook refuses a spec on trunk citing an unknown scope"
rspec bad beta/nope && git add -A; expect_refuse git commit -qm bad; undo
sed -i.bak '/`ota`/d' .jig/roadmap.md && rm .jig/roadmap.md.bak && git add -A
msg="roadmap: the hook refuses a trunk roadmap edit dropping a scope a spec takes, naming the spec"
out=$(git commit -qm "drop ota" 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'drops beta/ota, which .jig/specs/s5.md still takes'" "$out"
msg="roadmap: re-pointing the spec in that commit is accepted"
rspec s5 beta/radio && git add -A; expect_pass git commit -qm "drop ota, s5 on radio"

msg="roadmap: a staged kind: roadmap file is listed"
stage r.md this roadmap update .jig/roadmap.md 'add a phase v1 with scope `case`, because x\n'
expect_pass sh -c "$J staging | grep -q 'r.md: update roadmap for this → .jig/roadmap.md'"
msg="roadmap: resolve refuses until a trunk commit to .jig/roadmap.md carries its mark"
expect_refuse $J staging resolve r.md
printf '\n## v1\nScopes:\n- `case`: the enclosure\n' >> .jig/roadmap.md && $J roadmap --write >/dev/null && git add -A
git commit -qm "roadmap: v1" -m "Source: chat r.md (staged as r.md)"
msg="roadmap: after that commit it resolves"
expect_pass sh -c "$J staging resolve r.md && test ! -e .jig/staging/r.md"
msg="roadmap: a mark in a commit that didn't touch .jig/roadmap.md doesn't count"
stage q.md this roadmap update .jig/roadmap.md 'x\n' && git commit -q --allow-empty -m "x" -m "Source: chat q.md (staged as q.md)"
expect_refuse $J staging resolve q.md; rm .jig/staging/q.md
msg="roadmap: a roadmap change staged as change: new is refused"
stage n.md this roadmap new .jig/roadmap.md 'x\n'
expect_pass sh -c "! $J staging resolve n.md && $J staging | grep -q 'a roadmap change is .change: update.'"
rm .jig/staging/n.md
msg="roadmap: a roadmap change with any other destination is refused"
stage d.md this roadmap update docs/plan.md 'x\n'
expect_pass sh -c "! $J staging resolve d.md && $J staging | grep -q 'lands in .jig/roadmap.md only'"
rm .jig/staging/d.md

rbad() { printf "$1" > .jig/roadmap.md && git add -A; out=$(git commit -qm bad 2>&1); rc=$?; git reset -q --hard; }
msg="roadmap: the hook refuses a duplicate scope id, naming its line"
rbad '## a\nScopes:\n- `x`: y\n- `x`: z\n'
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'line 4: scope a/x appears twice'" "$out"
msg="roadmap: the hook refuses a duplicate phase, naming its line"
rbad '## a\nScopes:\n- `x`: y\n## a\nExit when:\n- [ ] z\n'
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'line 4: phase a appears twice'" "$out"
msg="roadmap: the hook refuses a phase with neither Exit when: nor Scopes:"
rbad '## a\nScopes:\n- `x`: y\n\n## Notes\nprose\n'
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'line 5: phase Notes has neither'" "$out"
msg="roadmap: the hook refuses a line under Scopes: that isn't a scope; a nested item is never one"
rbad '## a\nScopes:\n- `x`: y\n  - SPI\n- two words: z\n'
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'line 4: not a scope.*- SPI' && echo \"\$0\" | grep -q 'line 5: not a scope'" "$out"
msg="roadmap: jig roadmap reports the same problems and exits 1"
printf '## a\nScopes:\n- `x`: y\n  - SPI\n' > .jig/roadmap.md && git add -A && git -c core.hooksPath=/dev/null commit -qm planted
out=$($J roadmap 2>&1); rc=$?; git reset -q --hard HEAD~1
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q 'roadmap.md line 4: not a scope'" "$out"
msg="roadmap: --write reads tracked files only: an untracked spec draft takes nothing"
rspec draft beta/radio && sed -i.bak 's|^Scope: .*|Scope: v1/case|' .jig/specs/draft.md && rm .jig/specs/draft.md.bak
$J roadmap --write >/dev/null
expect_pass sh -c "! grep -q draft ROADMAP.md"
rm .jig/specs/draft.md; git checkout -q -- ROADMAP.md
msg="roadmap: the spec template carries no live Scope: line"
expect_refuse grep -q '^Scope:' "$P/specs/_template.md"

RE="$T/rm-empty"; pcnew "$RE" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '## a\nExit when:\n\n## b\nScopes:\n- `x`: y\n' > .jig/roadmap.md && git add -A && git commit -qm roadmap
msg="roadmap: a phase with no scopes and no exit boxes is empty, never done"
expect_pass sh -c "$J roadmap | grep -q '^a  current  (empty' && $J roadmap --write >/dev/null && grep -q '^## a (current, empty)' ROADMAP.md"
git checkout -q -- . 2>/dev/null; rm -f ROADMAP.md

RC="$T/rm-conflict"; pcnew "$RC" && mkdir -p src && printf 'x=1\n' > src/x.py && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '## a\nScopes:\n- `x`: y\n' > .jig/roadmap.md && rspec s1 a/x && git add -A && git commit -qm roadmap
$J roadmap --write >/dev/null && git add -A && git commit -qm view
$J open C --spec .jig/specs/s1.md --owns 'src/**' >/dev/null && git add -A && git commit -qm "open C"
( cd .git/jig/worktrees/C && printf 'x=2\n' > src/x.py && git commit -qam two && $J reviewed >/dev/null \
  && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note C" )
printf 'x=3\n' > src/x.py && git commit -qam three
out=$($J merge C 2>&1)
printf 'x=2\n' > src/x.py && git add src/x.py && $J roadmap --write >/dev/null && git add ROADMAP.md && git commit -q --no-edit
msg="roadmap: on a conflicted merge, following jig's steps (resolve, --write, add, commit) moves the job's scope to Done"
expect_pass sh -c "echo \"\$0\" | grep -q 'jig roadmap --write' && git show HEAD:ROADMAP.md | grep -q '^|  |  | \*\*x\*\*'" "$out"

RT="$T/rm-meta"; mkdir -p "$RT" && cd "$RT" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init --meta >/dev/null 2>&1 && git add -A && git commit -qm "GLOSSARY: board"
printf '## a\nScopes:\n- `x`: y\n' > .jig/roadmap.md && git add -A && git commit -qm "GLOSSARY: roadmap"
msg="roadmap: in a metarepo, M4 lets ROADMAP.md be committed on trunk where a roadmap exists"
$J roadmap --write >/dev/null && git add -A; expect_pass git commit -qm "GLOSSARY: roadmap view"

NR="$T/no-roadmap"; pcnew "$NR" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="roadmap: with no .jig/roadmap.md, jig roadmap says there is none"
expect_pass sh -c "$J roadmap | grep -q 'no roadmap'"
msg="roadmap: with no roadmap, no hook check fires on a spec's Scope: line"
rspec s1 alpha/whatever && git add -A && expect_pass git commit -qm s1
$J open N --spec .jig/specs/s1.md >/dev/null && git add -A && git commit -qm "open N"
( cd .git/jig/worktrees/N && printf 'n\n' > n.txt && git add -A && git commit -qm n \
  && $J reviewed >/dev/null && $J handoff --spec .jig/specs/s1.md >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note N" )
msg="roadmap: with no roadmap, jig merge writes no ROADMAP.md"
expect_pass sh -c "$J merge N >/dev/null && test ! -e ROADMAP.md && ! git show --name-only --format= HEAD | grep -q ROADMAP"
printf '# Our roadmap\nhand written\n' > ROADMAP.md && git add -A && git commit -qm "hand roadmap"
msg="roadmap: with no roadmap, a hand-written ROADMAP.md is edited on a branch freely (no R5)"
git switch -q -c feat && printf 'more\n' >> ROADMAP.md && git add -A && expect_pass git commit -qm "edit hand roadmap"
git switch -q main
msg="roadmap: with no roadmap, a job sharing ROADMAP.md edits it with no R5"
$J open H --shares ROADMAP.md >/dev/null && git add -A && git commit -qm "open H"
out=$(cd .git/jig/worktrees/H && printf 'job\n' >> ROADMAP.md && git add -A && git commit -qm job 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! echo \"\$0\" | grep -q R5" "$out"
msg="roadmap: with no roadmap, survey lists a hand-written ROADMAP.md as a stray"
expect_pass hrsurvey "assert 'ROADMAP.md' in [e['path'] for e in r['homeless']], r['homeless']"
}

UNITS="rules update board_split worktree_setup metarepo,staging pararepo release r6_takes,r6_ints merge_after_sync repos workflow init_old_board ledger_rows hardware update_per_file pararepo_commands entry_globs report_fixes sync_buffer pointers removals feedback slash_names homes agents_lines page_contract roadmap"

if [ "${1:-}" = --list ]; then echo $UNITS | tr ' ,' '\n\n'; exit 0; fi
if [ "${1:-}" = --unit ]; then        # --unit <run folder> <unit>: one unit, its output to a file
  T="$2/${3%%,*}"; mkdir -p "$T"
  # Before any jig command, so every case and any fragment copied out of this file writes
  # user-level state into the section's own folder. Sections still set their own lists.
  export JIG_CONFIG="$T/repos.json" XDG_CONFIG_HOME="$T/config"
  # Python's __pycache__ writes into a .jig/ that a parallel section may be copying.
  export PYTHONDONTWRITEBYTECODE=1
  exec > "$2/$3.out" 2>&1 < /dev/null
  for s in $(echo "$3" | tr , ' '); do
    declare -F "sec_$s" >/dev/null || { bad "no section $s"; continue; }
    cd "$T" && "sec_$s"
  done
  echo $fail > "$2/$3.rc"; exit 0
fi

pick=""
for want in "$@"; do               # a section named on its own runs its whole unit
  u=$(echo $UNITS | tr ' ' '\n' | grep -E "(^|,)$want(,|\$)") || { echo "no section $want: see --list" >&2; exit 2; }
  case " $pick " in *" $u "*) ;; *) pick="$pick $u" ;; esac
done
[ -n "$pick" ] || pick=$UNITS
for f in $(declare -F | awk '$3 ~ /^sec_/ {print substr($3, 5)}'); do   # a section UNITS forgot never runs
  case " $(echo $UNITS | tr , ' ') " in *" $f "*) ;; *) bad "section $f is not in UNITS" ;; esac
done
real_before=$(cfg_state "$REAL_CFG")
RUN=$(mktemp -d "${TMPDIR:-/tmp}/jig-smoke.XXXXXX")
echo "smoke: sections run in $RUN"
jobs=${JIG_SMOKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}
order=$(for u in $SLOW $pick; do echo $u; done | awk -v p=" $pick " 'index(p, " " $0 " ") && !seen[$0]++')
# Its own process group, so a stopped run takes its units with it and no caller's processes.
set -m
echo "$order" | xargs -P "$jobs" -I{} bash "$0" --unit "$RUN" {} &
units=$!
set +m
trap 'kill -TERM -- -$units 2>/dev/null; wait $units; rm -rf "$RUN"; exit 130' INT TERM
wait $units
trap - INT TERM
for u in $UNITS; do
  case " $pick " in *" $u "*) ;; *) continue ;; esac
  cat "$RUN/$u.out" 2>/dev/null
  rc=$(cat "$RUN/$u.rc" 2>/dev/null) || rc=""
  [ "$rc" = 0 ] || { [ "$rc" = 1 ] || echo "FAIL  section $u did not finish"; fail=1; }
done


msg="isolation: the user's real jig config folder is unchanged by the run"
real_after=$(cfg_state "$REAL_CFG")
expect_pass test "$real_after" = "$real_before"
# Another session's real jig work can change it too; the diff shows which file did.
[ "$real_after" = "$real_before" ] || diff <(echo "$real_before") <(echo "$real_after")

rm -rf "$RUN"
exit $fail
