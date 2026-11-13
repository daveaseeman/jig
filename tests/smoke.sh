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
m2() { ulog "$1" && git add -A
  $J check --staged; local rc=$?; git reset -q; git checkout -q -- .jig/decisions.md; return $rc; }
stage() {  # stage <file> <target> <kind> <change> <destination> [body]
  printf -- '---\nstaged: true\ntarget: %s\nkind: %s\nchange: %s\ndestination: %s\nsource: chat %s\nstatus: staged\n---\n%b' \
    "$2" "$3" "$4" "$5" "$1" "${6:-# Title\n\nbody\n}" > ".jig/staging/$1"
  case "${6:-}" in *"Touches: docs/shared.md"*) [ -f docs/shared.md ] || { mkdir -p docs && printf '# Shared\n' > docs/shared.md; } ;; esac; }
board() { python3 -c "import json,sys; b=json.load(open('.jig/config.json')); $1; json.dump(b, open('.jig/config.json','w'), indent=2)"; }
dec() { ulog "### D-$1 x
Accepted (owner, 2026-10-30).
Touches: docs/shared.md" && git add -A; }
foldin() { sed -i.bak -e 's/^- \[ \]/- [x]/' -e '/ vs .* § /s/___/agrees/' -e 's/___/smoke/g' .jig/handoffs/*.md && rm .jig/handoffs/*.bak; }
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
pcfold() { sed -i.bak -e 's/^- \[ \]/- [x]/' -e '/ vs .* § /s/___/agrees/' -e 's/___/smoke/g' .jig/handoffs/*.md && rm .jig/handoffs/*.bak; }
setjson() {  # setjson <file> <key> <value>
  python3 -c "import json,sys; f=sys.argv[1]; d=json.load(open(f)); d[sys.argv[2]]=sys.argv[3]; json.dump(d, open(f,'w'), indent=2)" "$@"; }
gate_ok() { out=$($J gate "$1" 2>&1); rc=$?; git worktree remove --force ".git/jig/worktrees/gate-$1" 2>/dev/null; return $rc; }
setentry() { python3 -c "import json,sys; f='.jig/meta.json'; d=json.load(open(f)); d['entry_files']=sys.argv[1:]; json.dump(d, open(f,'w'), indent=2)" "$@"; }
emerge() {  # emerge <branch> <subject> <file>...: commit the staged change on a branch, review it, merge it into main
  b=$1 s=$2; shift 2; git switch -q -c "$b" && git add -- "$@" && git commit -qm "$s" && $J reviewed >/dev/null \
    && git switch -q main && git merge -q --no-ff --no-edit "$b"; }
underhead() { ulog "$1"; }
ulog() {  # ulog <text> [section]: add text at the top of a section of the decision log (default Unreleased);
  # an entry touching a shared fixture page (docs/shared.md, docs/other.md) writes it when the repo has none
  python3 -c "import sys; f='.jig/decisions.md'; s=open(f).read(); h='## '+sys.argv[2]+'\n'; assert h in s, h; open(f,'w').write(s.replace(h, h+'\n'+sys.argv[1]+'\n', 1))" "$1" "${2:-Unreleased}"
  case "$1" in *"Touches: docs/"*) for pg in $(echo "$1" | sed -n 's/^Touches: //p' | tr ',' ' '); do
    case "$pg" in docs/shared.md|docs/other.md) [ -f "$pg" ] || { mkdir -p "$(dirname "$pg")" && printf '# Shared\n' > "$pg"; } ;; esac; done ;; esac; }
emergejob() {  # emergejob <job> <subject>: open a job in $EM, hand it off, and merge it with --subject
  (cd "$EM" && $J open "$1" --branch "b-$1" --owns "products/$1.md" >/dev/null && git add -A && git commit -qm "TOOL: open $1" \
    && cd ".git/jig/worktrees/b-$1" && printf '# x\n' > "products/$1.md" && ulog "- $1" \
    && git add -A && git commit -qm "PRODUCTS: $1" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold \
    && git add -A && git commit -qm "TOOL: note $1" && cd "$EM" && $J merge "$1" --subject "$2" >/dev/null); }
sbprops() { git -C "$SM" branch --list 'propose/*' | wc -l | tr -d ' '; }
brow() { printf '| %s | DECISIONS.md § D-001: %s | api/a.py, %s (%s) | owner, 2026-11-02 | %s |\n' "$@"; }
sbland() {  # sbland <proposal branch> <term>: the metarepo writes it, merges and releases
  (cd "$SM" && git switch -q "$1" && printf '\n### %s\n' "$2" >> README.md && ulog "- $2" \
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

msg="init: .jig/ holds jig.py, RULES.md, docs-page.md, config.json, jobs.json, decisions.md, the five scripts and staging/.gitignore, nothing else"
expect_pass test "$(find .jig -type f | LC_ALL=C sort | tr '\n' ' ')" = ".jig/RULES.md .jig/config.json .jig/decisions.md .jig/docs-page.md .jig/jig.py .jig/jobs.json .jig/scripts/check.sh .jig/scripts/derive.sh .jig/scripts/format.sh .jig/scripts/publish.sh .jig/scripts/release.sh .jig/scripts/setup.sh .jig/staging/.gitignore "

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
           '.aidev/RULES.md', 'jig/RULES.md', '.jig/RULES.md', '.jig/docs-page.md', '.gitignore', '.jig/scripts/setup.sh', '.jig/scripts/derive.sh', '.jig/scripts/release.sh', '.jig/scripts/publish.sh', '.jig/staging/.gitignore', '.jig/decisions.md'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or set(paths) <= allowed, line"

  msg="update $name: every board glob that matched before still matches"
  expect_pass python3 -c "$GLOBS" "$P/jig/jig.py" "$board"

  msg="update $name: hooks read trunk's .jig/jig.py and none was kept as .local; .git/jig/enabled, no .git/aidev, no old ignore line"
  expect_pass sh -c "grep -q 'git show main:.jig/jig.py' .git/hooks/pre-commit && ! ls .git/hooks/*.local && test -f .git/jig/enabled && test ! -e .git/aidev && ! grep -q worktrees .gitignore"

  msg="update $name: nothing tracked is left in jig/, .aidev/, specs/ or ledgers/; the config is stamped 10, with release.sh, publish.sh and an empty decision log added"
  expect_pass sh -c "test -z \"\$(git ls-files jig .aidev specs ledgers .jig/lanes.json)\" && ! grep -q payload .jig/config.json && grep -q '\"version\": 10' .jig/config.json && git ls-files --error-unmatch .jig/scripts/release.sh .jig/scripts/publish.sh .jig/decisions.md"

  msg="update $name: publish.sh is added from the template, TODO line included, and staged"
  expect_pass sh -c "git diff --cached --name-status | grep -q '^A.\.jig/scripts/publish.sh$' && grep -q '^# TODO: publish steps\.' .jig/scripts/publish.sh && test -x .jig/scripts/publish.sh"

  msg="update $name: derive.sh is added from the template, executable, and staged"
  expect_pass sh -c "cmp -s .jig/scripts/derive.sh '$P/jig/scripts/derive.sh' && test -x .jig/scripts/derive.sh && git diff --cached --name-status | grep -q '^A.\.jig/scripts/derive.sh$'"

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
  expect_pass test "$(echo "$out" | head -1)" = "up to date" -a "$before" = "$after"

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
expect_pass test "$($UP 2>&1 | head -1)" = "up to date"
git reset -q --hard HEAD~1

msg="update: a board stamped above this jig refuses"
python3 -c "import json; b = json.load(open('.jig/config.json')); b['version'] = 99; json.dump(b, open('.jig/config.json', 'w'))"
git commit -qam ahead
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'repo is ahead; update the plugin'" "$out"
git reset -q --hard HEAD~1

msg="update: an up-to-date repo says so even with a worktree open"
git worktree add -q --detach "$T/up-extra0" HEAD 2>/dev/null
expect_pass test "$($UP 2>&1 | head -1)" = "up to date"
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

# A gate's scratch checkout left behind is jig's own: update removes it rather than refusing.
wt --detach .git/jig/worktrees/gate-J HEAD && mkdir -p .git/jig/worktrees/gate-J/venv && printf 'x\n' > .git/jig/worktrees/gate-J/venv/x
wt .git/jig/worktrees/J -b J
msg="update: a leftover gate-J is listed as gate scratch and isn't refused; job J's own worktree still is"
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'remove .git/jig/worktrees/gate-J (gate scratch, removed on --apply)' && ! echo \"\$0\" | grep -q 'git worktree remove .git/jig/worktrees/gate-J' && echo \"\$0\" | grep -q 'git worktree remove .git/jig/worktrees/J'" "$out"
git worktree remove .git/jig/worktrees/J && git branch -q -D J
msg="update: a gate checkout with a tracked edit stays a refusal, naming it"
printf 'edit\n' >> .git/jig/worktrees/gate-J/AGENTS.md
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'gate scratch .git/jig/worktrees/gate-J has tracked changes'" "$out"
git -C .git/jig/worktrees/gate-J checkout -q -- AGENTS.md
msg="update: --apply removes the leftover gate checkout, untracked files and all"
$UP --apply >/dev/null 2>&1
expect_pass sh -c "test ! -e .git/jig/worktrees/gate-J && ! git worktree list | grep -q gate-J"
git reset -q --hard

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
msg="update: a docs/HARDWARE.md that holds a board is proposed as docs/<board>.md, flat, registered in boards"
sed -i.bak 's/^- MCU \/ board: TODO.*/- MCU \/ board: ESP32-S3-DevKitC-1 (N16R8)/' docs/HARDWARE.md && rm docs/HARDWARE.md.bak
git commit -qam board-page
expect_pass sh -c "$UP 2>&1 | grep -q 'rename it to docs/esp32-s3-devkitc-1.md, list it under boards'"
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
jig = {'.jig/config.json', '.jig/jobs.json', '.jig/jig.py', '.jig/RULES.md', '.jig/docs-page.md', '.jig/scripts/setup.sh', '.jig/scripts/derive.sh', '.jig/scripts/release.sh', '.jig/scripts/publish.sh',
       '.jig/ledgers/DEFERRED.md', '.jig/staging/.gitignore', '.gitignore', '.jig/decisions.md'}
for line in subprocess.check_output(['git', 'diff', '--cached', '-M', '--name-status'], text=True).splitlines():
    status, *paths = line.split('\t')
    assert status == 'R100' or (status == 'D' and paths[0] in removed) or paths[-1] in jig, line" "$removed $board"

  case $gen in
    ai-dev)
      msg="update $gen: REVIEW_LEDGER.md's untaken rows are DEFERRED.md; its taken rows are gone"
      expect_pass sh -c "grep -q L-001 .jig/ledgers/DEFERRED.md && grep -q L-003 .jig/ledgers/DEFERRED.md && grep -q L-005 .jig/ledgers/DEFERRED.md && ! grep -q 'L-00[24]' .jig/ledgers/DEFERRED.md && test ! -e docs/REVIEW_LEDGER.md"
      msg="update $gen: a root HARDWARE.md naming a board moves to docs/<board>.md, flat, byte for byte, and is registered in boards"
      expect_pass sh -c "git diff --cached -M --name-status | grep -q '^R100.HARDWARE.md.docs/devkit-s3.md' && python3 -c \"import json; assert json.load(open('.jig/config.json'))['boards'] == ['docs/devkit-s3.md']\"";;
    claude-lane)
      msg="update $gen: board.json is the board, merged entries and claude-lane's own keys gone; the folder is gone"
      expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['trunk'] == 'main' and 'lanes' not in b and 'seen' not in b and 'main' not in b and 'next' not in b['reserve']['section'], b\" && test ! -e .claude/claude-lane && git diff --cached -M --name-status | grep -q '^R100.*old-2026-01-01.md'";;
    dot-jig-v7)
      msg="update $gen: the one-file board splits: config.json without jobs or log, an empty jobs.json, no lanes.json"
      expect_pass sh -c "python3 -c \"import json; c = json.load(open('.jig/config.json')); assert c['version'] == 10 and not {'lanes', 'log'} & set(c) and json.load(open('.jig/jobs.json')) == {}, c\" && test ! -e .jig/lanes.json && echo \"\$0\" | grep -q 'board: lanes.old (merged)' && echo \"\$0\" | grep -q 'board: log'" "$out";;
  esac

  msg="update $gen: a second update is up to date"
  expect_pass test "$($UP 2>&1 | head -1)" = "up to date"

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
assert c['version'] == 10 and j == {}, (c, j)"
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
msg="meta: init --meta writes docs/glossary.md, no GLOSSARY.md or README.md, and entry_files names the glossary, not README.md"
expect_pass sh -c "test ! -e GLOSSARY.md && test ! -e README.md && grep -qx '# Glossary' docs/glossary.md && grep -q '\"docs/glossary.md\"' .jig/meta.json && ! grep -q '\"README.md\"' .jig/meta.json"
msg="meta: init --meta writes the decision log, and no CHANGELOG.md or DECISIONS.md"
expect_pass sh -c "grep -qx '## Unreleased' .jig/decisions.md && test ! -e CHANGELOG.md && test ! -e DECISIONS.md"

msg="meta: init --meta then release tags v0.1.0, with no release.sh steps to fill, and says it's a metarepo"
out=$($J release 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '(metarepo)' && git tag | grep -qx v0.1.0 && grep -q '^## v0.1.0 - ' .jig/decisions.md" "$out"
msg="meta: the release leaves an empty ## Unreleased above its heading for the next entries"
expect_pass sh -c "grep -A2 '^## Unreleased\$' .jig/decisions.md | grep -q '^## v0.1.0 - '"
msg="meta: a second release with no entry-file change says nothing to release"
out=$(mrel); expect_pass sh -c "echo \"\$0\" | grep -q 'nothing to release'" "$out"

git switch -q -c b1
msg="meta M1: a source file outside .jig/ is refused"
printf 'x=1\n' > tool.py && git add tool.py; expect_refuse git commit -qm "D-001: tool"; git rm -q --cached tool.py; rm tool.py
msg="meta: a change to .jig/jig.py is accepted"
printf '\n' >> .jig/jig.py && git add .jig/jig.py; expect_pass git commit -qm "TOOL: jig"
msg="meta M2: an entry with no status line is refused"
expect_refuse m2 '### D-001 use JSON'
msg="meta M2: an open question is an entry under ## Open"
ulog '### D-001 which wire format?
Open (2026-10-29).
Touches: docs/shared.md' Open && git add -A; expect_pass $J check --staged; git reset -q; git checkout -q -- .jig/decisions.md
msg="meta M2: an open entry under ## Unreleased is refused"
expect_refuse m2 '### D-001 which wire format?
Open (2026-10-29).
Touches: docs/shared.md'
msg="meta M2: an accepted entry with who, and one superseding another, are accepted"
expect_pass m2 '### D-001 x
Accepted (owner, 2026-10-29).
Touches: docs/shared.md'
expect_pass m2 '### D-002 y
Accepted (owner, 2026-10-30). Supersedes D-001.
Touches: docs/shared.md

### D-001 x
Accepted (owner, 2026-10-29).
Touches: docs/shared.md'
msg="meta M2: an accepted entry that doesn't say who decided is refused"
expect_refuse m2 '### D-001 x
Accepted (2026-10-29).'
msg="meta M2: a title that merely starts with a status word is no status in the heading"
expect_pass m2 '### D-001 Open ports stay closed
Accepted (owner, 2026-10-29).
Touches: docs/shared.md'
msg="meta M3: an entry file changed without a line in the log is refused"
printf '\n## rune\nx\n' >> docs/glossary.md && git add -A
expect_refuse git commit -qm "GLOSSARY: rune"
msg="meta M6: a subject without an id prefix is refused"
ulog 'GLOSSARY: Add "rune".' && git add -A
expect_refuse git commit -qm "use rune"
msg="meta: an id-prefixed glossary change with its log line is accepted"
expect_pass git commit -qm "GLOSSARY: rune"
msg="meta M6: a subject leading with a placeholder id is accepted"
git switch -q -c b1p && ulog '### D-?wire-json config is JSON
Accepted (owner, 2026-10-29).
Touches: docs/shared.md' && git add -A
expect_pass git commit -qm "D-?wire-json: config is JSON"
msg="meta M2: a plain git merge bringing an unnumbered id onto main is refused"
git switch -q main && out=$(git merge -q --no-ff --no-edit b1p 2>&1); git merge --abort 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q \"D-?wire-json isn't numbered\"" "$out"
git switch -q main
git switch -q -c b4
msg="meta M3: a README.md change needs no log line: the README is no entry file"
printf '# docs\n\n## Install\nrun it\n' > README.md && git add README.md
expect_pass git commit -qam "README: install"
msg="meta M3: a glossary term change needs the log line"
printf '\n## rune\nx\n' >> docs/glossary.md && git add -A
expect_refuse git commit -qm "GLOSSARY: rune"; git reset -q --hard && git switch -q main

msg="meta M4: a direct commit on main is refused"
printf '\n## mote\n' >> docs/glossary.md && ulog '- mote' && git add -A
expect_refuse git commit -qm "GLOSSARY: mote"; git reset -q --hard
msg="meta M4: a direct commit of the log alone on main is refused too: a decision is reviewed work"
ulog '### D-009 x
Accepted (owner, 2026-10-29).
Touches: docs/shared.md' && git add -A
expect_refuse git commit -qm "D-009: x"; git reset -q --hard

msg="meta M5: a --no-ff merge of an unreviewed branch is refused"
expect_refuse git merge -q --no-ff --no-edit b1; git merge --abort 2>/dev/null
msg="meta: the same merge once the branch is reviewed is accepted"
git switch -q b1 && $J reviewed >/dev/null && git switch -q main
expect_pass git merge -q --no-ff --no-edit b1
msg="meta: a git pull of a reviewed branch into main is accepted"
git switch -q -c b3 && printf '\n## seam\n' >> docs/glossary.md && ulog '- seam' && git add -A && git commit -qm "GLOSSARY: seam" && $J reviewed >/dev/null && git switch -q main
expect_pass git pull -q --no-ff --no-edit . b3

msg="meta: release tags v0.2.0 (minor is a metarepo's default)"
expect_pass sh -c "$J release && git tag | grep -qx v0.2.0"

git switch -q -c b2 && printf '\n## grain\n' >> docs/glossary.md && ulog '- grain' && git add -A && git commit -qm "GLOSSARY: grain" && git switch -q main
git merge -q --ff-only b2
git init -q --bare "$T/meta-remote.git" && git remote add origin "$T/meta-remote.git"
msg="meta: a fast-forward of an unreviewed branch: release refuses, naming the commit"
out=$(mrel); c=$(git rev-parse --short=12 HEAD)
expect_pass sh -c "echo \"\$0\" | grep -q '$c is on main without a reviewed merge'" "$out"
msg="meta: and pre-push refuses it"
expect_refuse git push -q origin main
git reset -q --hard v0.2.0
msg="meta: a fast-forward that changes only the log is still refused: it isn't jig's bookkeeping"
git switch -q -c b5 && ulog '- loose' && git add -A && git commit -qm "TOOL: loose" && git switch -q main && git merge -q --ff-only b5
out=$(mrel); expect_pass sh -c "echo \"\$0\" | grep -q 'without a reviewed merge'" "$out"
git reset -q --hard v0.2.0

msg="meta: a tag made by hand fails the next release and pre-push, naming it"
git tag v0.3
out=$(mrel)
expect_pass sh -c "echo \"\$0\" | grep -q 'tag v0.3 was not made by jig release' && ! git push -q origin main 2>/dev/null" "$out"
git tag -d v0.3 >/dev/null
msg="meta: a tag made before the log, whose CHANGELOG.md has the release heading, still counts as released"
git switch -q -c old && printf '# Changelog\n\n## v0.2.5 — 2026-01-01\n' > CHANGELOG.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "old" && git tag -a v0.2.5 -m v0.2.5 && git switch -q main
out=$(mrel); expect_pass sh -c "! echo \"\$0\" | grep -q 'tag v0.2.5 was not made'" "$out"
git tag -d v0.2.5 >/dev/null && git branch -qD old

msg="meta R3: a job given only GLOSSARY.md commits a term with its log line"
$J open gl --branch b-gl --owns GLOSSARY.md --shares README.md >/dev/null && git add -A && git commit -qm "TOOL: open gl"
board "b['common'] = ['AGENTS.md']" && git add -A && git commit -qm "TOOL: narrow common"
cd .git/jig/worktrees/b-gl && $J sync >/dev/null 2>&1
printf '\n## mote\n' >> GLOSSARY.md && ulog '- mote' && git add -A
expect_pass git commit -qm "GLOSSARY: mote"
msg="meta R3: the same job rewriting a line already in the log is refused"
printf '\n## seam\n' >> GLOSSARY.md && sed -i.bak 's/^A breaking change/Breaking/' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm "GLOSSARY: seam" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'R3 .jig/decisions.md'" "$out"
msg="meta R3: the same job editing a line it added itself is accepted"
sed -i.bak 's/^- mote$/- mote, again/' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
expect_pass git commit -qm "GLOSSARY: mote again"
msg="meta R3: the same job deleting the log is refused"
git rm -q .jig/decisions.md && printf 'x\n' > notes.txt && git add -A
out=$(git commit -qm "TOOL: notes" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'R3 .jig/decisions.md'" "$out"
cd "$M"

# A decision entry and the pages citing it are one home: changing the entry asks those pages.
MF="$T/meta-fold"; mkdir -p "$MF" && cd "$MF" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name docs >/dev/null && setentry .jig/decisions.md README.md 'pages/*.md'
mkdir -p pages notes && ulog '### D-007 x
Accepted (owner, 2026-11-01).
Touches: docs/shared.md

### D-020 r
Accepted (owner, 2026-11-01).
Touches: docs/other.md'
printf '# A\n\nWe keep it short, as D-007 says. Retries follow D-020.\n\n## Undefined\n- retries — parked 2026-11-01.\n' > pages/a.md
printf '# B\n\nSee D-0070.\n' > pages/b.md
printf '# C\n\nD-007\n' > notes/c.md
git add -A && git -c core.hooksPath=/dev/null commit -qm "meta-init"
$J open d7 --branch b-d7 >/dev/null && git add -A && git commit -qm "TOOL: open d7"
cd .git/jig/worktrees/b-d7
ulog '### D-?retry-cap retries are capped
Accepted (owner, 2026-11-02). Supersedes D-007.
Touches: docs/shared.md'
git add -A && git commit -qm "D-?retry-cap: y" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/*.md)
msg="meta fold-in: an entry superseding D-007 asks the entry page citing it in passing, naming the ids"
expect_pass grep -qx -- '- \[ \] pages/a.md — updated / no change because ___   (D-007)' "$note"
msg="meta fold-in: a page asked only for a decision it cites gets one line, none for its Undefined entries"
expect_pass test "$(grep -c 'pages/a.md' "$note")" = 1
msg="meta fold-in: no line for D-0070's page, a page outside entry_files, or the log"
expect_pass sh -c "! grep -qE 'pages/b.md|notes/c.md|decisions.md|no code changed' '$note'"
git add -A && git commit -qm "TOOL: note d7" && cd "$MF"
msg="meta fold-in: the gate refuses the note while the line is unanswered"
expect_refuse gate_ok d7
cd .git/jig/worktrees/b-d7 && pcfold && git add -A && git commit -qm "TOOL: answer d7" && cd "$MF"
msg="meta fold-in: and passes once it is answered"
expect_pass gate_ok d7
printf '# D\n\nWe follow D-?retry-cap.\n' > pages/d.md
msg="merge: jig merge numbers D-?retry-cap after the log's highest, in the log and in the page citing it, in the merge commit"
mkdir -p .jig/specs && printf 'x\n' > .jig/specs/d7.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "TOOL: page d"
cd .git/jig/worktrees/b-d7 && printf '# E\n\nAs D-?retry-cap says.\n' > pages/e.md && git add -A && git commit -qm "D-?retry-cap: page" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note again" && cd "$MF"
out=$($J merge d7 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'D-?retry-cap → D-021' && grep -qx '### D-021 retries are capped' .jig/decisions.md && grep -q 'As D-021 says' pages/e.md && test \"\$(git log -1 --format=%P | wc -w | tr -d ' ')\" = 2 && ! git status --porcelain | grep -q ." "$out"
msg="merge: a page on trunk the merge didn't change keeps its placeholder"
expect_pass grep -q 'D-?retry-cap' pages/d.md
msg="decision: jig decision D-007 names the entry that supersedes it"
out=$($J decision D-007 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'D-007 is superseded by D-021'" "$out"
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

msg="staging: an update to AGENTS.md with no marked trunk commit is refused, naming the commit route"
stage g.md this doc update AGENTS.md
out=$($J staging resolve g.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'with .Source: chat g.md (staged as g.md). in the commit message, never in the file' && ! echo \"\$0\" | grep -q 'keeping'" "$out"
msg="staging: a marked commit that didn't change AGENTS.md doesn't count"
git commit -q --allow-empty -m "x" -m "Source: chat g.md (staged as g.md)"
expect_refuse $J staging resolve g.md
printf '\n- one more rule\n' >> AGENTS.md && git add AGENTS.md
git commit -qm "agents: one more rule" -m "Source: chat g.md (staged as g.md)"
msg="staging: once a trunk commit that changed AGENTS.md carries the mark, it resolves with no mark in the file"
expect_pass sh -c "$J staging resolve g.md && test ! -e .jig/staging/g.md && ! grep -q 'staged as g.md' AGENTS.md"
msg="staging: a mark only on the merge of a job that changed AGENTS.md resolves it"
stage h.md this doc update AGENTS.md
git switch -q -c rules-job && printf -- '- a rule from a job\n' >> AGENTS.md && git commit -qam "agents: a rule"
git switch -q main && git merge -q --no-ff rules-job -m "merge rules-job" -m "Source: chat h.md (staged as h.md)"
expect_pass sh -c "$J staging resolve h.md && test ! -e .jig/staging/h.md"
msg="staging: a new GEMINI.md is written with no mark, and resolves once a trunk commit adding it carries one"
stage m.md this doc new GEMINI.md '# Gemini\n\n- a rule\n'
expect_refuse $J staging resolve m.md
expect_pass sh -c "test -e .jig/staging/m.md && grep -qx '# Gemini' GEMINI.md && ! grep -q 'staged as' GEMINI.md"
git add GEMINI.md && git commit -qm "gemini" -m "Source: chat m.md (staged as m.md)"
expect_pass sh -c "$J staging resolve m.md && test ! -e .jig/staging/m.md && ! grep -q 'staged as' GEMINI.md"

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

msg="staging: decision entries land in the log; other body lines refuse until handled"
stage r.md this decisions new .jig/decisions.md 'and edit the glossary\n### D-001 one\nAccepted (owner, 2026-10-29).\nTouches: docs/shared.md\n'
expect_refuse $J staging resolve r.md
stage r.md this decisions new .jig/decisions.md '### D-001 one\nAccepted (owner, 2026-10-29).\nTouches: docs/shared.md\n'
expect_pass sh -c "$J staging resolve r.md && sed -n '/^## Unreleased/,\$p' .jig/decisions.md | grep -qx '### D-001 one'"
msg="staging: a decision id already in the log is refused as new"
stage r.md this decisions new .jig/decisions.md '### D-001 again\nAccepted (owner, 2026-10-29).\nTouches: docs/shared.md\n'
expect_refuse $J staging resolve r.md
msg="staging: decisions for any file but the log are refused, naming it"
stage r.md this decisions new docs/decisions.md '### D-002 two\nAccepted (owner, 2026-10-29).\nTouches: docs/shared.md\n'
out=$($J staging resolve r.md 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'not .jig/decisions.md' && test ! -e docs/decisions.md" "$out"
msg="staging: an entry with no status line is refused"
stage r.md this decisions new .jig/decisions.md '### D-003 three\n'
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
msg="staging: an open decision resolved into a metarepo lands under ## Open"
stage dm.md this decisions new .jig/decisions.md '### D-?wire which wire format?\nOpen (2026-10-30).\nTouches: docs/shared.md\n'
out=$($J staging resolve dm.md 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '1 entry added to .jig/decisions.md' && sed -n '/^## Open/,/^## Unreleased/p' .jig/decisions.md | grep -qx '### D-?wire which wire format?'" "$out"
# Resolved in the trunk checkout, the entry is committed by a job, as M4 asks.
git diff -- .jig/decisions.md > "$T/dm.patch" && git checkout -q -- .jig/decisions.md
cd .git/jig/worktrees/b-gl && git apply -C1 "$T/dm.patch" && git add -A
msg="staging: and a job's commit of it passes M3 and R3, the entry being its line"; expect_pass git commit -qm "D-?wire: x"
cd "$M"

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
expect_pass sh -c "grep -q '\"pin\": \"v0.1.0\"' .jig/para.json && ! grep -q location .jig/para.json && grep -q '\"docs\"' '$T/repos.json' && grep -q 'jig:meta' AGENTS.md && test -f .jig/meta-cache/.jig/decisions.md && grep -qx '.jig/meta-cache/' .gitignore && grep -qx 'mrclone/' .gitignore"
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
git add -f .jig/meta-cache/.jig/decisions.md; expect_refuse git commit -qm cache; git reset -q
msg="para P3: staging the metarepo checkout is refused"
git add -f mrclone 2>/dev/null; expect_refuse git commit -qm clone; git reset -q

msg="propose: a branch on the metarepo, the id in the spec, the metarepo's main untouched"
mainbefore=$(git -C mrclone rev-parse main)
$J propose .jig/specs/x.md fmt >/dev/null
expect_pass sh -c "git -C mrclone rev-parse -q --verify refs/heads/propose/pr-fmt && grep -q 'meta: docs proposal propose/pr-fmt' .jig/specs/x.md && test \"\$(git -C mrclone rev-parse main)\" = '$mainbefore' && test \"\$(git -C mrclone branch --show-current)\" = main"
git add -A && git commit -qm "specs: proposal"

msg="para P4: a contract change waits while a file for the metarepo is staged"
stage meta-note.md docs decisions new .jig/decisions.md '### D-?x x\nProposed (2026-10-29).\nTouches: docs/shared.md\n'
printf 'z=3\n' >> api/a.py && printf -- '- meta: none — still internal\n' >> .jig/specs/x.md && git add api/a.py .jig/specs/x.md
expect_refuse git commit -qm "api: more"
python3 .jig/jig.py staging drop meta-note.md >/dev/null
msg="para P4: a file staged for the metarepo by its name in another case holds it back too"
stage upper-note.md DOCS decisions new .jig/decisions.md '### D-?x x\nProposed (2026-10-29).\nTouches: docs/shared.md\n'
expect_refuse git commit -qm "api: more"
python3 .jig/jig.py staging drop upper-note.md >/dev/null
msg="para P4: once it is resolved, the same commit is accepted"
expect_pass git commit -qm "api: more"

msg="para: a new worktree gets the main checkout's cache; propose there names the repo, not the folder"
git worktree add -q --detach "$T/pr-job" HEAD 2>/dev/null
(cd "$T/pr-job" && $J propose .jig/specs/x.md lanefix >/dev/null)
expect_pass sh -c "test -f '$T/pr-job/.jig/meta-cache/.jig/decisions.md' && git -C mrclone rev-parse -q --verify refs/heads/propose/pr-lanefix"
git worktree remove --force "$T/pr-job"

msg="repos: works outside any git repo"
expect_pass sh -c "cd '$T' && python3 '$P/jig/jig.py' repos"

cd "$MR" && git switch -q -c d1 && ulog '### D-001 ids are numbers
Accepted (owner, 2026-10-29).
Touches: docs/shared.md' && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit d1 2>/dev/null && $J release >/dev/null
cd "$PR" && printf 'D-001 is how ids work\n' > api/ids.md && git add api/ids.md && git commit -qm "api: ids" >/dev/null 2>&1
msg="sync on a pararepo trunk: after a release it reports the change in this repo's terms, its BUFFER rows and specs included, and proposes the bump; the pin stays"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'docs v0.2.0 is out' && echo \"\$0\" | grep -qF 'D-001: used in .jig/ledgers/BUFFER.md, .jig/specs/buffer-v0.1.1.md, api/ids.md' && echo \"\$0\" | grep -q 'meta: docs v0.1.0 → v0.2.0' && grep -q '\"pin\": \"v0.1.0\"' .jig/para.json" "$out"

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

# A metarepo release that moves one page and deletes another, and a pararepo citing both.
MM="$T/mm"; mkdir -p "$MM/products/hardware" && cd "$MM" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" .
printf '# Walyt\n\nA board.\n\n## Two stages\n\nOne, then two.\n\n## Interaction (rev 2)\n\nPress, then hold.\n\n## Power\n\nUSB.\n' > products/hardware/walyt.md
printf '# Gone\n\nSoon.\n' > products/gone.md && git add -A && git commit -qm init
$J init --meta --name mm >/dev/null && setentry DECISIONS.md README.md 'products/**/*.md'
git add -A && git commit -qm meta-init && $J release >/dev/null
PP="$T/pp"; mkdir -p "$PP" && cd "$PP" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p api docs .jig/specs .jig/ledgers .jig/handoffs && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
git clone -q "$MM" mmclone && $J init --para mm --location mmclone --contract 'api/**' >/dev/null && git add -A && git commit -qm para-init
cp "$P/ledgers/BUFFER.md" .jig/ledgers/BUFFER.md
printf '| B1 | `mm/products/hardware/walyt.md § Interaction (rev 2)` | api/a.py | owner, 2026-11-10 | Open |\n' >> .jig/ledgers/BUFFER.md
printf '# s\n\nPer `mm/products/hardware/walyt.md § Two stages`.\n' > .jig/specs/s.md
printf 'See products/hardware/walyt.md.\n' > docs/a.md
printf '# h\n\nproducts/gone.md, `mm/products/hardware/walyt.md § Handoffonly`.\n' > .jig/handoffs/h.md
git add -A && git commit -qm "cite mm" >/dev/null 2>&1
printf '| B2 | `mm/products/hardware/walyt.md § Closedonly`, mm/products/gone.md | api/a.py | owner, 2026-11-10 | Closed |\n' >> .jig/ledgers/BUFFER.md
git commit -qam "buffer: B2, as sync would have closed it" --no-verify
cd "$MM" && git switch -q -c mv && mkdir -p products/walyt && git mv products/hardware/walyt.md products/walyt/walyt.md
sed -i.bak 's/^## Interaction (rev 2)$/## Interaction/' products/walyt/walyt.md && rm products/walyt/walyt.md.bak && git rm -q products/gone.md
ulog '- WALYT: Move it to products/walyt/, and remove products/gone.md.' && ulog '### D-001 walyt moves
Accepted (owner, 2026-11-10).
Touches: docs/shared.md' && git add -A && git commit -qm "D-001, WALYT: move it, drop gone" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit mv 2>/dev/null && $J release >/dev/null
cd "$PP" && out=$($J sync 2>&1)
msg="para sync: a newer release lists an entry file it moved, with every file here citing it, specs and ledgers included"
expect_pass sh -c "echo \"\$0\" | grep -qF 'products/hardware/walyt.md (now products/walyt/walyt.md): used in .jig/ledgers/BUFFER.md, .jig/specs/s.md, docs/a.md'" "$out"
msg="para sync: a heading only a BUFFER row cites is used there, not 'not used here'"
expect_pass sh -c "echo \"\$0\" | grep -qF 'Interaction (rev 2): used in .jig/ledgers/BUFFER.md'" "$out"
msg="para sync: a deleted entry file mentioned only in a handoff and a Closed BUFFER row reads (removed): not used here"
expect_pass sh -c "echo \"\$0\" | grep -qF 'products/gone.md (removed): not used here'" "$out"
setjson .jig/para.json pin v0.2.0 && $J init --para mm >/dev/null 2>&1 && git add -A && git commit -qm "meta: mm v0.1.0 → v0.2.0" >/dev/null 2>&1
printf '# s2\n\nPer `mm/products/walyt/walyt.md § Interaction`.\n' > .jig/specs/s2.md
printf '# s3\n\nPer products/walyt/walyt.md.\n' > .jig/specs/s3.md
printf '# s4\n\nPer `mm/.jig/decisions.md § D-001`,\nnot `mm/.jig/decisions.md § D-009`.\n' > .jig/specs/s4.md
mkdir -p mm && printf '# notes\n' > mm/notes.md && printf 'See mm/notes.md.\n' > docs/b.md && git add -A && git commit -qm "specs: s2, s3" >/dev/null 2>&1
out=$($J sync 2>&1)
msg="para sync: a spec citing <meta>/<path> the pin no longer has is named"
expect_pass sh -c "echo \"\$0\" | grep -qF \".jig/specs/s.md:3 cites mm/products/hardware/walyt.md, which mm v0.2.0 doesn't have\"" "$out"
msg="para sync: a citation the pin has, file and heading, is not named"
expect_pass sh -c "! echo \"\$0\" | grep -q 's2.md'" "$out"
msg="para sync: a bare path naming a metarepo entry file is named, with the form to write"
expect_pass sh -c "echo \"\$0\" | grep -qF '.jig/specs/s3.md:3 cites products/walyt/walyt.md bare: write it as \`mm/products/walyt/walyt.md\`'" "$out"
msg="para sync: a citation of a decision id checks the log for its entry, not a heading"
expect_pass sh -c "echo \"\$0\" | grep -qF '.jig/specs/s4.md:4 cites mm/.jig/decisions.md § D-009, which mm v0.2.0 has no row for' && ! echo \"\$0\" | grep -q 's4.md:3'" "$out"
msg="para sync: a path in a folder here named like the metarepo is this repo's own, not a citation"
expect_pass sh -c "! echo \"\$0\" | grep -q 'docs/b.md'" "$out"
msg="para sync: a Closed BUFFER row and a handoff citing the old path are not named"
expect_pass sh -c "echo \"\$0\" | grep -q 'BUFFER.md:.*walyt' && ! echo \"\$0\" | grep -qE 'Closedonly|Handoffonly|handoffs/'" "$out"

cd "$MM" && git switch -q -c sup && ulog '### D-002 the api page is `pp/docs/old.md`
Accepted (owner, 2026-11-10).
Touches: docs/shared.md' && ulog '### D-003 the api page is `pp/docs/a.md`
Accepted (owner, 2026-11-11). Supersedes D-002.
Touches: docs/shared.md

### D-004 the guide is `pp/docs/none.md`
Accepted (owner, 2026-11-11).
Touches: docs/shared.md' && ulog '### Changed
- API: The page moved from `pp/docs/gone2.md`.' && printf 'More.\n' >> products/walyt/walyt.md \
  && git add -A && git commit -qm "D-002, D-003, D-004, WALYT: api pages" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit sup 2>/dev/null && $J release >/dev/null
cd "$PP" && git -C mmclone pull -q 2>/dev/null; out=$($J sync 2>&1)
msg="para sync: a release changing the log and another entry file reports the log's ids too"
expect_pass sh -c "echo \"\$0\" | grep -q '^  D-003: ' && echo \"\$0\" | grep -q '^  D-002: '" "$out"
setjson .jig/para.json pin v0.3.0 && $J init --para mm >/dev/null 2>&1 && git add -A && git commit -qm "meta: mm v0.2.0 → v0.3.0" >/dev/null 2>&1
out=$($J sync 2>&1)
msg="para sync: a log entry's pointer to a file this repo lacks is named; a superseded entry's isn't"
expect_pass sh -c "echo \"\$0\" | grep -q 'decisions.md points to docs/none.md' && ! echo \"\$0\" | grep -q 'docs/old.md'" "$out"
msg="para sync: a released section's change line is history, so its path isn't a pointer"
expect_pass sh -c "! echo \"\$0\" | grep -q 'gone2.md'" "$out"
cd "$MM" && git switch -q -c yank && python3 -c "import re; f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(re.sub(r'^(## v0\.3\.0 - \S+)$', r'\1 [YANKED]\n\nThe api pages were wrong; pin v0.2.0.', s, flags=re.M))" \
  && git add -A && git commit -qm "TOOL: yank v0.3.0" && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit yank
cd "$PP" && git -C mmclone pull -q 2>/dev/null; out=$($J sync 2>&1)
msg="para sync: a pin to a release yanked since says so, with its line"
expect_pass sh -c "echo \"\$0\" | grep -q 'mm v0.3.0, the pin, is yanked: The api pages were wrong; pin v0.2.0.'" "$out"
printf '\n## v1.0.0 - 2026-01-01\n\n### Changed\n- Cite `mm/products/hardware/walyt.md` for the board.\n' >> .jig/decisions.md
ulog '- Cite `mm/products/hardware/walyt.md` again.' && git add -A && git -c core.hooksPath=/dev/null commit -qm "log: released and unreleased citations"
out=$($J sync 2>&1)
msg="para sync: this repo's own released log lines aren't named; an Unreleased one is"
expect_pass sh -c "test \"\$(echo \"\$0\" | grep -c '^.jig/decisions.md:.* cites mm/products/hardware/walyt.md')\" = 1 && echo \"\$0\" | grep -q '^.jig/decisions.md:10 cites'" "$out"

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
c['reserve'] = {'decision': {'pattern': r'^### D-(\d+)', 'files': ['.jig/decisions.md']}}
json.dump(c, open('.jig/config.json', 'w'), indent=2)
EOF
git add -A && git commit -qm "TOOL: decision counter"
$J open D --reserve decision=2 >/dev/null && git add -A && git commit -qm "TOOL: open D"
cd "$MJ/.git/jig/worktrees/D"
msg="R6 ints: a job holding decision 2 adds ### D-002, and check prints ok"
dec 002; expect_pass sh -c "$J check --staged | grep -qx ok"; undo
msg="R6 ints: ### D-003 instead is refused, naming 003 and the held 2"
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
$J open E --reserve decision=3 >/dev/null && git add -A && git commit -qm "TOOL: open E"
cd "$MJ/.git/jig/worktrees/E"
dec 003 && git commit -qm "D-003: x" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
ulog '- D-003 more' && git commit -qm "D-003: more" .jig/decisions.md; foldin
git add -A && git commit -qm "HANDOFF: E"
cd "$MJ"
msg="M5: content committed after the review, then a note: jig merge refuses"
expect_refuse $J merge E
msg="M5: and a plain merge of that tip is refused by M5"
out=$(git merge --no-ff --no-edit E 2>&1); git merge --abort 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q 'M5 '" "$out"
$J open F --reserve decision=4 >/dev/null && git add -A && git commit -qm "TOOL: open F"
( cd "$MJ/.git/jig/worktrees/F" && dec 004 && git commit -qm "D-004: x" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && foldin && git add -A && git commit -qm "HANDOFF: F" )
printf '# u\n' > .jig/specs/u.md && git add -A && git commit -qm "TOOL: spec u"
( cd "$MJ/.git/jig/worktrees/F" && $J sync >/dev/null 2>&1 )
msg="M5: review, then a note, then a sync of trunk: jig merge is accepted, and so is the release"
expect_pass sh -c "$J merge F >/dev/null 2>&1 && ! grep -q '\"F\"' .jig/jobs.json && $J release >/dev/null 2>&1 && git tag | grep -qx v0.2.0"

cd "$R" && mkdir -p .jig/staging
msg="staging: a decisions destination with prose after the path refuses, naming the header field"
stage dd.md this decisions new '.jig/decisions.md, on branch x' '### D-009 x\nAccepted (owner, 2026-10-30).\nTouches: docs/shared.md\n'
out=$($J staging resolve dd.md 2>&1)
expect_pass sh -c "! $J staging resolve dd.md >/dev/null 2>&1 && echo \"\$0\" | grep -q 'destination:' && ! grep -q 'D-009' .jig/decisions.md" "$out"
msg="staging: destination .jig/decisions.md resolves there"
stage dd.md this decisions new .jig/decisions.md '### D-009 x\nAccepted (owner, 2026-10-30).\nTouches: docs/shared.md\n'
expect_pass sh -c "$J staging resolve dd.md && grep -qx '### D-009 x' .jig/decisions.md"
msg="staging: an empty decisions destination is still refused by the header check"
stage de.md this decisions new '' '### D-010 x\nAccepted (owner, 2026-10-30).\nTouches: docs/shared.md\n'
expect_refuse $J staging resolve de.md
msg="staging: D-9 is the D-009 already in the log, and is refused as new"
stage de.md this decisions new .jig/decisions.md '### D-9 again\nAccepted (owner, 2026-10-30).\nTouches: docs/shared.md\n'
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
c['append_files'].append('CHANGELOG.md')   # this repo's own log, an append file of its choosing
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
msg="gate: a second gate of K, with no mark between, replaces the leftover checkout"
expect_pass sh -c "$J gate K >/dev/null 2>&1 && test -d $s"
msg="mark: with a tracked edit in the gate checkout, jig mark K gated refuses, naming it"
printf 'edit\n' >> $s/K.py
out=$($J mark K gated 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '$s has tracked changes (K.py)' && test -d $s && grep -q '\"state\": \"claimed\"' .jig/jobs.json" "$out"
git -C $s checkout -q -- K.py
msg="mark: jig mark K gated removes the gate checkout, untracked files and all"
mkdir -p $s/venv && printf 'x\n' > $s/venv/x
expect_pass sh -c "$J mark K gated >/dev/null 2>&1 && test ! -e $s && ! git worktree list | grep -q gate-K"
git commit -qam "K gated"
msg="open: a job name starting with gate- is refused"
expect_refuse $J open gate-K
msg="mark: a branch checkout at L's gate path is someone's work: mark refuses and leaves it, untracked files and all"
wt .git/jig/worktrees/gate-L -b gate-L && printf 'x\n' > .git/jig/worktrees/gate-L/newwork.py
out=$($J mark L gated 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'has branch gate-L checked out' && test -f .git/jig/worktrees/gate-L/newwork.py && python3 -c \"import json,sys; sys.exit(json.load(open('.jig/jobs.json'))['L']['state'] != 'claimed')\"" "$out"
git worktree remove --force .git/jig/worktrees/gate-L && git branch -q -D gate-L
for j in K L M; do ( cd "$MS/.git/jig/worktrees/$j" && [ $j = M ] || $J sync >/dev/null 2>&1 ); done
( cd "$MS/.git/jig/worktrees/M" && git -c merge.conflictStyle=diff3 merge -q main >/dev/null 2>&1
  printf -- '# Changelog\n- trunk\n- M\n' > CHANGELOG.md && printf 'x=2\n' > M.py && git add -A && git commit -q --no-edit )
( cd "$MS/.git/jig/worktrees/L" && printf 'x=2\n' > L.py && git commit -qam "L after its note" )
msg="merge: a job synced after its handoff, append conflict resolved by the sync, merges with no new handoff"
msg="gate: a gate folder deleted by hand is pruned, so the next gate checks out there again"
$J gate K >/dev/null 2>&1; rm -rf $s
expect_pass sh -c "$J gate K >/dev/null 2>&1 && test -d $s"
expect_pass $J merge K
msg="merge: jig merge K, gated again and never marked, leaves no gate checkout"
expect_pass sh -c "test ! -e $s && ! git worktree list | grep -q gate-K"
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
expect_pass sh -c "test $rc = 0 && test -f .jig/para.json && test \"\$($UP 2>&1 | head -1)\" = 'up to date'" "$out"
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

msg="survey: a page-shaped file beside its system's page is a flat part page, at home; a note there is a linked file"
printf '# Power\n\nThe rails.\n\n## Invariants\n- 3.3V — the parts are 3.3V; held by review.\n' > docs/watch/power.md
printf '# Bring-up\n' > docs/watch/bringup.md && printf '[bring-up](bringup.md)\n' >> docs/watch/watch.md
git add -A && git commit -qm "candidate"
expect_pass hrsurvey "assert r['homeless'] == [], r['homeless']
assert [(e['path'], e['to']) for e in r['page_shapes']] == [('docs/band/band.md', 'docs/band.md')], r['page_shapes']"
mkdir -p docs/watch/img && printf 'png' > docs/watch/img/scope.png && printf '![scope](img/scope.png)\n' >> docs/watch/bringup.md
git add -A && git commit -qm "a note links an image"
msg="datasheets: a file a note in the page's folder links is not unlinked"
expect_pass hrsurvey "assert 'docs/watch/img/scope.png' not in r['datasheets_unlinked'], r['datasheets_unlinked']"
msg="survey: the flat part page is read against the page contract"
printf '\n## Invariants\n- Rails are 3.3V\n' > docs/watch/power.md && git add -A && git commit -qm "power bare invariant"
expect_pass hrsurvey "assert 'docs/watch/power.md' in [e['path'] for e in r['page_contract']], r['page_contract']"

msg="page contract: a board page is read against it like any page"
printf '\n## Invariants\n- Pins are 3.3V\n' >> docs/watch/watch.md
git add -A && git commit -qm "bare invariant"
expect_pass hrsurvey "assert 'docs/watch/watch.md' in [e['path'] for e in r['page_contract']], r['page_contract']"
msg="page contract: the board template, filled in nowhere, is on the contract"
# Planted: alone in its folder, which the hook refuses; only its contract is asked here.
mkdir -p docs/tmpl && cp "$P/hardware.md" docs/tmpl/tmpl.md && git add -A && git -c core.hooksPath=/dev/null commit -qm tmpl
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
  && printf '# Devkit\n\nThe dev board. [schematic](schematic.pdf)\n' > docs/prod/devkit/devkit.md && printf 'pdf\n' > docs/prod/devkit/schematic.pdf \
  && git add -A && git commit -qm "pio and its page") && hwnote G1
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
assert rows == {'docs/hardware/band.md': 'docs/band.md',
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

# A flat board page and its folder form are one page: a job grows the folder with a git mv alone.
HW2="$T/hwflat"; pcnew "$HW2" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs && printf '# Dev\n\nA dev board.\n' > docs/dev.md && printf 'CONFIG_X=y\n' > sdkconfig
board "b['boards'] = ['docs/dev.md']; b['docmap'] = {'docs/dev.md': ['sdkconfig']}" && git add -A && git commit -qm "flat board"
$J open HF1 --spec t --owns 'docs/**' >/dev/null 2>&1 && git add -A && git commit -qm "open HF1"
(cd .git/jig/worktrees/HF1 && mkdir -p docs/dev/datasheets && git mv docs/dev.md docs/dev/dev.md \
  && printf 'pdf\n' > docs/dev/datasheets/x.pdf && printf '[x](datasheets/x.pdf)\n' >> docs/dev/dev.md \
  && git add -A && git commit -qm "dev grows a folder") && hwnote HF1
msg="board gate: a flat board page boards lists moves into its folder with a datasheet on a job branch, and the gate passes"
gate_ok HF1; rc=$?
expect_pass sh -c "test $rc = 0 || { echo \"\$0\"; exit 1; }" "$out"
msg="boards: a boards entry and docmap key in the flat form name the page in its folder form"
git checkout -q HF1 -- docs && git rm -q --cached docs/dev.md 2>/dev/null; rm -f docs/dev.md; git add -A && git commit -qm "dev in its folder"
expect_pass sh -c "python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['boards_missing'] == [] and r['boards_unmapped'] == [] and r['boards_unpaged'] == [] and r['homeless'] == [], r\""
msg="update: a lone page in the old docs/hardware/ layout goes flat, docs/<board>.md"
expect_pass python3 -c "
import sys; sys.path.insert(0, '.jig'); import jig
rows = jig.old_board_rows(['docs/hardware/b.md', 'docs/hardware/c.md', 'docs/hardware/c/wiring.md'], lambda f: '# x\n')
assert {r['path']: r['to'] for r in rows} == {'docs/hardware/b.md': 'docs/b.md', 'docs/hardware/c.md': 'docs/c/c.md', 'docs/hardware/c/wiring.md': 'docs/c/wiring.md'}, rows"
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

(cd "$PM" && git switch -q propose/pa-g && printf '\n### gee\n' >> README.md && ulog '- gee' \
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
  && cd .git/jig/worktrees/propose/pa-t && printf '\n### tee\n' >> README.md && ulog '- tee' \
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
  && ulog '- D-001' && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit d1 && $J release >/dev/null)
msg="sync: a pararepo pinned at a hand-made v0.1 sees v0.2.0, proposes the bump, and caches v0.1"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'tp v0.2.0 is out' && echo \"\$0\" | grep -q 'meta: tp v0.1 → v0.2.0' && head -1 .jig/meta-cache/PIN | grep -qx v0.1" "$out"

# Header migration: a pararepo set up by the v0.3.1 checker, before these commands moved.
PH="$T/ph"; pcnew "$PH" && git -C "$JR" show v0.3.1:plugin/templates/jig/jig.py > .jig/jig.py && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
# An old checker finds releases by CHANGELOG.md, which a metarepo no longer writes: it is told the pin.
$J init --para pm --pin v0.1.0 --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
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
expect_pass sh -c "test -z \"\$(git status --porcelain | grep -vE ' (AGENTS.md|.jig/para.json|.jig/decisions.md)\$')\" && git add -A && git commit -qm 'header'"
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
printf 'more\n' >> products/a.md && ulog '- a'
msg="entry globs: a change to products/a.md (directly under the glob's folder) releases the next minor"
emerge ea "PRODUCTS: a" products/a.md .jig/decisions.md; out=$($J release --minor 2>&1)
expect_pass sh -c "git rev-parse -q --verify refs/tags/v0.2.0 >/dev/null" "$out"
printf 'more\n' >> products/x/b.md && ulog '- b'
msg="entry globs: a change to products/x/b.md releases the next minor"
emerge eb "PRODUCTS: b" products/x/b.md .jig/decisions.md; $J release --minor >/dev/null 2>&1
expect_pass git rev-parse -q --verify refs/tags/v0.3.0
git switch -q -c em3
msg="entry globs: M3 refuses a change to products/a.md with no log line"
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
# Trunk's line goes under ## Open, away from the branch's, so the merge below is clean.
git switch -q main && printf 'w\n' >> products/x/b.md && ulog '- w' Open
emerge em5 "PRODUCTS: w" products/x/b.md .jig/decisions.md; git switch -q em4 && git merge -q --no-edit main
msg="entry globs: after the branch merges a moved trunk, a page-only commit still passes"
printf 'v\n' >> products/a.md; git add -A; expect_pass git commit -qm "PRODUCTS: v"
msg="entry globs: M3 refuses a commit that drops the branch's only line, its page changes kept"
python3 -c "f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(s.replace('\n- y\n', '', 1))"
git add -A; expect_refuse git commit -qm "LOG: drop y"; undo
msg="entry globs: M3 refuses a commit that deletes the log after the branch added its line"
git rm -q .jig/decisions.md; expect_refuse git commit -qm "LOG: gone"; undo
git switch -q main && git switch -q -c em6
msg="entry globs: M3 refuses the log deleted alongside a page change"
printf 'u\n' >> products/a.md && git rm -q .jig/decisions.md && git add -A; expect_refuse git commit -qm "PRODUCTS: u"; undo
msg="entry globs: M3 refuses a non-ASCII page name under the glob with no line"
printf '# d\n' > "products/déjà.md"; git add -A; expect_refuse git commit -qm "PRODUCTS: déjà"; undo
# A pull of trunk's upstream into the branch moves the base, though local main stays behind.
git switch -q main && git switch -q -c emup && printf 't\n' >> products/a.md && ulog '- t' \
  && git add -A && git commit -qm "PRODUCTS: t" && git branch -q --set-upstream-to=emup main
git switch -q main && git switch -q -c em7 && git merge -q --ff-only emup
msg="entry globs: M3 doesn't let upstream trunk's line cover a branch that pulled it"
printf 's\n' >> products/a.md; git add -A; expect_refuse git commit -qm "PRODUCTS: s"; undo
git switch -q main && git branch -q --unset-upstream main
printf '# b top\n' > products/b.md && ulog '- new page b'
msg="entry globs: a new products/b.md needs no meta.json edit; the next release counts it"
emerge ec "PRODUCTS: new b" products/b.md .jig/decisions.md; $J release >/dev/null 2>&1
expect_pass sh -c "git rev-parse -q --verify refs/tags/v0.4.0 >/dev/null && git diff --quiet v0.1.0 HEAD -- .jig/meta.json"

msg="entry globs: a metarepo whose entry_files are all globs makes its first release from them"
EG="$T/eg"; pcnew "$EG" && mkdir -p products && printf '# a\n' > products/a.md
$J init --meta --name eg >/dev/null && setentry 'products/**/*.md' && git add -A && git commit -qm meta-init
out=$($J release 2>&1); expect_pass sh -c "git rev-parse -q --verify refs/tags/v0.1.0 >/dev/null" "$out"

EP="$T/ep"; pcnew "$EP" && mkdir -p api && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para em --location "$EM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
msg="entry globs: init --para caches products/a.md and products/b.md as files, and no file named for a folder"
expect_pass sh -c "test \"\$(cd .jig/meta-cache && find . -type f | sort | tr '\n' ' ')\" = './.jig/decisions.md ./PIN ./products/a.md ./products/b.md ./products/x/b.md '"

# A proposal landed by `jig merge --subject`, its branch then deleted: the gate still finds it.
mkdir -p .jig/specs && printf '# t\n\n## Decisions\n' > .jig/specs/t.md && $J propose .jig/specs/t.md t >/dev/null
git add .jig/specs/t.md && git commit -qm "specs: t" && $J open E1 --spec .jig/specs/t.md --owns 'lib/**' >/dev/null && git add -A && git commit -qm "open E1"
(cd "$EP/.git/jig/worktrees/E1" && mkdir -p lib && printf 'w=1\n' > lib/w.py && git add -A && git commit -qm w && $J reviewed >/dev/null \
  && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note E1")
(cd "$EM" && $J open J --branch propose/ep-t --owns products/t.md CHANGELOG.md >/dev/null && git add -A && git commit -qm "TOOL: open J" \
  && cd .git/jig/worktrees/propose/ep-t && printf '# t\n' > products/t.md && ulog '- t' \
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
cd "$EG" && printf '# c\n' > "products/café.md" && ulog '- café'
emerge en "PRODUCTS: café" "products/café.md" .jig/decisions.md; $J release >/dev/null 2>&1
expect_pass git rev-parse -q --verify refs/tags/v0.2.0

msg="entry globs: a cited file moved out of the exact entry_files still counts for the release"
ER="$T/er"; pcnew "$ER" && $J init --meta --name er >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
git switch -q -c mv && git mv docs/glossary.md glossary.md && ulog '- moved' \
  && git add -A && git commit -qm "GLOSSARY: move" && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit mv
$J release >/dev/null 2>&1; expect_pass git rev-parse -q --verify refs/tags/v0.2.0

# A glob that would reach into .jig/: jig's own files still never count.
EJ="$T/ej"; pcnew "$EJ" && printf '# p\n' > p.md
$J init --meta --name ej >/dev/null && setentry '**/*.md' && git add -A && git commit -qm meta-init && $J release >/dev/null
msg="entry globs: with '**/*.md', a .jig/ file committed on trunk needs no changelog line"
mkdir -p .jig/specs && printf '# s\n' > .jig/specs/s.md && git add -A; expect_pass git commit -qm "TOOL: spec s"
msg="entry globs: with '**/*.md', a .jig/ change alone is nothing to release"
out=$($J release 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'nothing to release'" "$out"
msg="entry globs: with '**/*.md', a pararepo's cache holds no .jig/ file but the decision log"
EK="$T/ek"; pcnew "$EK" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para ej --location "$EJ" >/dev/null 2>&1
expect_pass sh -c "test -f .jig/meta-cache/p.md && test \"\$(find .jig/meta-cache -path '*/.jig/*')\" = .jig/meta-cache/.jig/decisions.md"
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
git switch -q -c ub && printf '\n### grain\n' >> README.md && ulog '- grain' \
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

# jig merge: an unsynced job whose only conflicts are appends is resolved as sync would; any
# other conflict beside an append is sent to jig sync.
FS="$T/fu-sync"; pcnew "$FS" && printf '# Changelog\n' > CHANGELOG.md && printf 'base\n' > common.txt && git add -A && git commit -qm init \
  && $J init >/dev/null && board "b['append_files'].append('CHANGELOG.md')" && git add -A && git commit -qm board
for j in K L M N O; do $J open $j --shares CHANGELOG.md common.txt >/dev/null; done; git add -A && git commit -qm "open K L M N O"
for j in K L M N O; do
  ( cd "$FS/.git/jig/worktrees/$j" && { [ $j = O ] && git rm -q CHANGELOG.md || printf -- '- %s\n' "$j" >> CHANGELOG.md; } \
    && printf 'x=1\n' > "$j.py" && { [ $j = L ] || [ $j = N ] || [ $j = O ] || printf '%s\n' "$j" > common.txt; } && git add -A \
    && git commit -qm "$j" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note $j" )
done
msg="gate: an executable check.sh is printed as ./.jig/scripts/check.sh, and marking gated is the cleanup, not a hand-run remove"
out=$($J gate L 2>&1); git worktree remove --force .git/jig/worktrees/gate-L 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q '&& ./.jig/scripts/check.sh' && echo \"\$0\" | grep -q 'jig mark L gated, which removes .git/jig/worktrees/gate-L' && ! echo \"\$0\" | grep -q 'git worktree remove'" "$out"
chmod -x .jig/scripts/check.sh && git add .jig/scripts/check.sh && git commit -qm "check.sh not executable"
msg="gate: a check.sh that isn't executable is printed as bash ./.jig/scripts/check.sh"
out=$($J gate L 2>&1); git worktree remove --force .git/jig/worktrees/gate-L 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q '&& bash ./.jig/scripts/check.sh'" "$out"
$J merge K >/dev/null 2>&1
msg="gate: M conflicts with trunk in common.txt: the gate stops, naming it, and removes its own checkout"
out=$($J gate M 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'needs a hand in common.txt' && echo \"\$0\" | grep -q 'The checkout is removed' && test ! -e .git/jig/worktrees/gate-M && ! git worktree list | grep -q gate-M" "$out"
SHIM="$T/fu-shim"; mkdir -p "$SHIM" && realgit=$(command -v git)
printf '#!/bin/sh\n[ "$1" = version ] && { echo "git version 2.30.0"; exit 0; }\nfor a in "$@"; do [ "$a" = --write-tree ] && exit 129; done\nexec %s "$@"\n' "$realgit" > "$SHIM/git" && chmod +x "$SHIM/git"
msg="merge: with a git older than 2.38, L, unsynced, conflicting only in CHANGELOG.md, is refused, naming jig sync, with trunk left clean"
out=$(PATH="$SHIM:$PATH" $J merge L 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'jig sync. the job, then merge' && ! git rev-parse -q --verify MERGE_HEAD && test -z \"\$(git status --porcelain --untracked-files=no)\" && grep -q '\"L\"' .jig/jobs.json" "$out"
ltip=$(git rev-parse L)
msg="merge: L, unsynced, conflicts only in CHANGELOG.md: merged with no sync, K's line then L's, L's branch untouched"
out=$($J merge L 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! grep -q '\"L\"' .jig/jobs.json && test \"\$(grep '^- ' CHANGELOG.md | tr '\n' ' ')\" = '- K - L ' && ! grep -q '^[<|=>]\\{7\\}' CHANGELOG.md && test \"\$(git rev-parse L)\" = $ltip" "$out"
msg="merge: it says it resolved CHANGELOG.md as jig sync would, and the commit is 'merge L' with no Conflicts lines"
expect_pass sh -c "echo \"\$0\" | grep -q 'resolved CHANGELOG.md as .jig sync. would' && test \"\$(git log -1 --format=%B | sed '/^\$/d')\" = 'merge L'" "$out"
msg="merge: O deleted CHANGELOG.md, which trunk appended to: refused, naming jig sync, trunk clean and the file kept"
out=$($J merge O 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'append files (CHANGELOG.md): .jig sync.' && ! echo \"\$0\" | grep -q resolved && ! git rev-parse -q --verify MERGE_HEAD && test -z \"\$(git status --porcelain --untracked-files=no)\" && test -f CHANGELOG.md" "$out"
msg="merge: M conflicts in CHANGELOG.md and common.txt: refused, naming jig sync and only the append file"
out=$($J merge M 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'append files (CHANGELOG.md): .jig sync.' && ! git rev-parse -q --verify MERGE_HEAD && grep -q '\"M\"' .jig/jobs.json" "$out"
msg="merge: M's sync resolves CHANGELOG.md and stops on common.txt"
out=$(cd "$FS/.git/jig/worktrees/M" && $J sync 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^  common.txt' && ! echo \"\$0\" | grep -q '^  CHANGELOG.md'" "$out"
(cd "$FS/.git/jig/worktrees/M" && git merge --abort)
(cd "$FS/.git/jig/worktrees/N" && $J sync >/dev/null 2>&1)
msg="merge: with a git older than 2.38, a synced job is refused, saying 2.38 is needed"
out=$(PATH="$SHIM:$PATH" $J merge N 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'needs git 2.38'" "$out"
msg="merge: once synced, N merges with no new handoff"
expect_pass sh -c "$J merge N && ! grep -q '\"N\"' .jig/jobs.json && grep -q '^- K' CHANGELOG.md && grep -q '^- N' CHANGELOG.md"

# DEFERRED.md rows: two jobs' rows merge back to back; rows added beside the note don't count.
FD="$T/fu-defer"; pcnew "$FD" && git add -A && git commit -qm init && $J init >/dev/null \
  && mkdir -p .jig/ledgers && cp "$P/ledgers/DEFERRED.md" .jig/ledgers/ && printf '| 2026-11-01 | base | f0 | should-fix | deferred | r |\n' >> .jig/ledgers/DEFERRED.md && git add -A && git commit -qm board
DROW='| 2026-11-13 | %s | f | optional | deferred | r |\n'
for j in A B E C C2 X; do $J open $j >/dev/null; done; git add -A && git commit -qm "open jobs"
for j in A B E C C2 X; do
  ( cd "$FD/.git/jig/worktrees/$j" && printf 'x=1\n' > "$j.py" \
    && { case $j in A|B) printf "$DROW" "$j" >> .jig/ledgers/DEFERRED.md;; E) sed -i.bak 's/| f0 |/| f0 edited |/' .jig/ledgers/DEFERRED.md && rm .jig/ledgers/DEFERRED.md.bak;; esac; } \
    && git add -A && git commit -qm "$j" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold \
    && { case $j in C|C2) printf "$DROW" "$j" >> .jig/ledgers/DEFERRED.md;; esac; } \
    && { [ $j = C2 ] && sed -i.bak 's/| f0 |/| f0 reworded |/' .jig/ledgers/DEFERRED.md && rm .jig/ledgers/DEFERRED.md.bak || true; } \
    && git add -A && git commit -qm "note $j" \
    && { [ $j = X ] && printf 'more\n' >> AGENTS.md && git commit -qam "after the note" || true; } )
done
msg="merge: A's DEFERRED.md row merges"
expect_pass $J merge A
msg="merge: with a git older than 2.38, B, whose row meets A's, is refused, naming jig sync, trunk clean"
out=$(PATH="$SHIM:$PATH" $J merge B 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'jig sync. the job, then merge' && ! git rev-parse -q --verify MERGE_HEAD && test -z \"\$(git status --porcelain --untracked-files=no)\"" "$out"
btip=$(git rev-parse B)
msg="merge: then B merges with no sync and no new note: the base row, A's, then B's, B's branch untouched"
out=$($J merge B 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && test \"\$(grep -o '| \\(base\\|A\\|B\\) |' .jig/ledgers/DEFERRED.md | tr -d '| ' | tr '\n' ' ')\" = 'base A B ' && ! grep -q '^[<|=>]\\{7\\}' .jig/ledgers/DEFERRED.md && test \"\$(git rev-parse B)\" = $btip && echo \"\$0\" | grep -q 'resolved .jig/ledgers/DEFERRED.md as .jig sync. would'" "$out"
msg="merge: B's merge tree is the one jig sync, then jig merge, writes"
git ls-tree -r HEAD > "$T/fu-defer.fix" && git reset -q --hard HEAD^ && (cd "$FD/.git/jig/worktrees/B" && $J sync >/dev/null 2>&1) \
  && $J merge B >/dev/null 2>&1 && git ls-tree -r HEAD > "$T/fu-defer.sync"
expect_pass cmp "$T/fu-defer.fix" "$T/fu-defer.sync"
msg="merge: E, whose edit of the base row meets A's append, is refused, naming jig sync, trunk clean"
out=$($J merge E 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'jig sync. the job, then merge' && ! git rev-parse -q --verify MERGE_HEAD && test -z \"\$(git status --porcelain --untracked-files=no)\" && grep -q '\"E\"' .jig/jobs.json" "$out"
msg="merge: C, its note and a DEFERRED.md row in one commit after the review, merges with no second record"
expect_pass $J merge C
msg="merge: C2, whose note commit also rewords the base row, is refused, naming DEFERRED.md"
out=$($J merge C2 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'changed since.*DEFERRED.md'" "$out"
msg="merge: X, with a line added to AGENTS.md after its note, is refused, naming AGENTS.md"
out=$($J merge X 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'changed since.*AGENTS.md'" "$out"

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
stage p1.md this decisions new 'the register in docs/DECISIONS.md' '### D-001 x\nAccepted (owner, 2026-11-02).\nTouches: docs/shared.md\n'
out=$($J staging resolve p1.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"isn't a path\" && ! echo \"\$0\" | grep -q Traceback && test ! -e docs/DECISIONS.md" "$out"
msg="staging: doc destination 'see docs/x.md' is refused as not a path, and writes no file"
stage p2.md this doc new 'see docs/x.md'
out=$($J staging resolve p2.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"isn't a path\" && test ! -e 'see docs/x.md'" "$out"
msg="staging: the bare path docs/x.md resolves"
stage p2.md this doc new docs/x.md; expect_pass sh -c "$J staging resolve p2.md && test -f docs/x.md"
msg="staging: decisions staged for docs/reg/DECISIONS.md are refused, naming the log, and make no folder"
stage p1.md this decisions new docs/reg/DECISIONS.md '### D-001 x\nAccepted (owner, 2026-11-02).\nTouches: docs/shared.md\n'
out=$($J staging resolve p1.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '.jig/decisions.md' && test ! -e docs/reg" "$out"; rm .jig/staging/p1.md
FV="$T/fu-stm"; pcnew "$FV" && git add -A && git commit -qm init && $J init --meta --name fv >/dev/null && git add -A && git commit -qm meta-init
msg="staging: in a metarepo, a misspelt destination (DECISION.md) is refused, naming the log"
stage p3.md this decisions new DECISION.md '### D-001 x\nAccepted (owner, 2026-11-02).\nTouches: docs/shared.md\n'
out=$($J staging resolve p3.md 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '.jig/decisions.md' && test ! -e DECISION.md" "$out"
msg="staging: in a metarepo, destination .jig/decisions.md resolves"
stage p3.md this decisions new .jig/decisions.md '### D-001 x\nAccepted (owner, 2026-11-02).\nTouches: docs/shared.md\n'
expect_pass sh -c "$J staging resolve p3.md && grep -qx '### D-001 x' .jig/decisions.md"

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
git switch -q -c m2 && ulog '### dec-1 x
Accepted, owner, 2026-11-02.' && git add -A
msg="M2: 'Accepted, owner, …' is refused, and the refusal shows the status line's form"
out=$(git commit -qm "DECISIONS: dec-1" 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -qF 'Accepted (who, YYYY-MM-DD).'" "$out"
perl -pi -e 's{^Accepted, owner, 2026-11-02\.$}{Accepted (owner, 2026-11-02).\nTouches: docs/shared.md}' .jig/decisions.md && mkdir -p docs && printf '# Shared\n' > docs/shared.md && git add -A && git commit -qm "DECISIONS: dec-1" \
  && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit m2 && $J release >/dev/null
git switch -q -c m3 && mkdir -p old && git mv docs/glossary.md old/glossary.md
msg="M3: docs/glossary.md renamed out of entry_files, with no log line, is refused"
expect_refuse git commit -qm "GLOSSARY: move"
git mv old/glossary.md docs/glossary.md && git rm -q docs/glossary.md
msg="M3: docs/glossary.md deleted, with no log line, is refused"
expect_refuse git commit -qm "GLOSSARY: drop"
git reset -q --hard && git switch -q main
FE="$T/fu-para"; pcnew "$FE" && mkdir -p api && printf 'x=1\n' > api/a.py && printf 'see dec-12\n' > api/twelve.md && printf 'see dec-1.\n' > api/one.md && printf 'two grains\n' > api/g.md \
  && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para fd --location "$FD" >/dev/null 2>&1 && git add -A && git commit -qm "init --para"
(cd "$FD" && git switch -q -c m4 && ulog '### dec-2 y
Accepted (owner, 2026-11-03). Supersedes dec-1.
Touches: docs/shared.md' \
  && printf '\n## grain\n\n## vault\nx\n' >> docs/glossary.md \
  && printf '# fd\n\n## Install\nrun it\n' > README.md \
  && git add -A && git commit -qm "DECISIONS: dec-1 y" && $J reviewed >/dev/null && git switch -q main && git merge -q --no-ff --no-edit m4 && $J release >/dev/null)
out=$($J sync 2>&1)
msg="sync: a lowercase decision_prefix's dec-1 is reported, used in api/one.md and not in api/twelve.md"
expect_pass sh -c "echo \"\$0\" | grep -q 'dec-1: used in api/one.md\$'" "$out"
msg="sync: a glossary heading still counts an inflected use (grain in 'grains')"
expect_pass sh -c "echo \"\$0\" | grep -q 'grain: used in api/g.md'" "$out"
msg="sync: a ## term in docs/glossary.md is in the term report"
expect_pass sh -c "echo \"\$0\" | grep -q '^  vault: '" "$out"
msg="sync: a README.md heading is no term: the README is no entry file"
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
# Its decisions are a register of rows from before the log, still an entry page: an old
# metarepo's releases are cached and read the same way.
SM="$T/sb-meta"; pcnew "$SM" && git add -A && git commit -qm init && $J init --meta --name sbm >/dev/null && setentry .jig/decisions.md DECISIONS.md README.md
printf '| D-001 | the list shows ids (`sb-para/docs/ui.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
printf '| D-002 | the other app has a page (`other-para/docs/x.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
printf '| D-003 | the help page (`SB-Para/docs/z.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
printf "| D-011 | The sync rule sits at the top of every product repo's \`AGENTS.md\` | accepted (owner) | 2026-11-01 |\n" >> DECISIONS.md
printf '| D-014 | the metarepo'"'"'s own agents file (`this/AGENTS.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
printf '| D-013 | the UI doc (`docs/ui.md`) | accepted (owner) | 2026-11-01 |\n' >> DECISIONS.md
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
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/ui.md is not a contract path, and D-001, D-013 name it'" "$out"
msg="buffer: a root file named bare (D-011) or after this/ (D-014) is no pointer here: no AGENTS.md line"
expect_pass sh -c "! echo \"\$0\" | grep -q 'AGENTS.md'" "$out"
msg="buffer: the rows stay Open after the proposal"
expect_pass sh -c "test \$(grep -c '| Open |\$' .jig/ledgers/BUFFER.md) = 2"
brow B3 'ids paged' 'scrolled' 'third try' Open >> .jig/ledgers/BUFFER.md && printf 's=9\n' >> api/a.py && git add -A && git commit -qm "api: s"
(cd "$SM" && git switch -q propose/sb-para-buffer-v1.0.0 && sed -i.bak 's/the list shows ids/the list shows ids and names, sorted/' DECISIONS.md && rm DECISIONS.md.bak \
  && printf '| D-012 | the agents file (`sb-para/AGENTS.md`) | accepted (owner) | 2026-11-02 |\n' >> DECISIONS.md \
  && ulog '- D-001: ids and names, sorted' && git add -A && git commit -qm "D-001: ids and names" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit propose/sb-para-buffer-v1.0.0 && $J release >/dev/null)
msg="buffer: after the metarepo releases it, jig sync moves the pin and closes B1 and B2 in one commit; B3 stays Open"
before=$(git rev-parse HEAD); out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(git rev-list --count $before..HEAD)\" = 1 && git log -1 --format=%s | grep -qx 'meta: sbm v0.1.0 → v0.2.0' && grep -q '\"pin\": \"v0.2.0\"' .jig/para.json && grep -q 'at \`v0.2.0\`' AGENTS.md && grep -q '^| B1 .*| Closed |\$' .jig/ledgers/BUFFER.md && grep -q '^| B2 .*| Closed |\$' .jig/ledgers/BUFFER.md && grep -q '^| B3 .*| Open |\$' .jig/ledgers/BUFFER.md && test \"\$(git show --name-only --format= HEAD | sort | tr '\n' ' ')\" = '.jig/ledgers/BUFFER.md .jig/para.json AGENTS.md ' && test -z \"\$(git status --porcelain)\" && head -1 .jig/meta-cache/PIN | grep -qx v0.2.0" "$out"
msg="buffer: jig sync reports a pararepo path a metarepo decision cites that contract_paths doesn't cover, and not one it covers or another repo's"
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/ui.md is not a contract path, and D-001, D-013 name it' && ! echo \"\$0\" | grep -q 'api/a.py is not' && ! echo \"\$0\" | grep -q 'docs/x.md is not'" "$out"
msg="buffer: a decision may name this repo in any case, the path still exact"
expect_pass sh -c "echo \"\$0\" | grep -q 'docs/z.md is not a contract path, and D-003 name it'" "$out"
msg="buffer P2: meta: buffered naming a Closed row is refused"
printf '# c\n\n- meta: buffered B1\n' > .jig/specs/c.md && printf 'w=4\n' >> api/a.py && git add -A; expect_refuse git commit -qm "api: w"; undo
msg="buffer: a second sync moves nothing"
before=$(git rev-parse HEAD); out=$($J sync 2>&1)
expect_pass sh -c "test \"\$(git rev-parse HEAD)\" = $before && echo \"\$0\" | grep -q 'sbm v0.2.0 is the latest release'" "$out"
msg="buffer: a root file after this repo's name (D-012) is reported, bare D-011 and this/ D-014 aren't, and the line asks"
expect_pass sh -c "echo \"\$0\" | grep -qx 'AGENTS.md is not a contract path, and D-012 name it. If the decision describes something this repo can change there, add the path to \"contract_paths\" in .jig/para.json; if not, nothing is needed.'" "$out"
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
  && ulog '- D-004' && git add -A && git commit -qm "D-004: links" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit d4 && $J release >/dev/null)
msg="sync: the changes report lists a new decision, and no heading from the metarepo's .jig/ files"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'sbm v0.6.0 is out' && echo \"\$0\" | grep -q 'D-004:' && ! echo \"\$0\" | grep -qE '(Built|Left|Done when|Touches):'" "$out"
# Page pointers: a metarepo page points to files this repo owns, one of them already gone.
mkdir -p docs/guide && printf '# B\n\n## Build (release)\n\n## The `run` step\n' > docs/b.md && printf '# Guide\n' > docs/guide/a.md && git add -A && git commit -qm "docs: b, guide"
(cd "$SM" && git switch -q -c ptr && printf '\n### Screens\nThe list: `sb-para/docs/ui.md § UI`. See sb-para/docs/ui.md § UI for the list.\n\n### Help\nSee `sb-para/docs/z.md`, `sb-para/docs/gone.md` and sb-para:docs/x.md § Colors.\n\n### Build\n`sb-para/docs/b.md § Build (release)`, then sb-para/docs/b.md § The `run` step, in sb-para/docs/guide. Use this/that wording.\n' >> README.md \
  && printf '| D-005 | the old page (`sb-para/docs/old.md`) | superseded by D-004 | 2026-11-03 |\n' >> DECISIONS.md \
  && ulog '- D-005, GLOSSARY: Screens, Help, Build' && git add -A && git commit -qm "D-005, GLOSSARY: Screens, Help, Build" && $J reviewed >/dev/null \
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
printf '\n## Pointers\n`pp/docs/x.md §2.1`, `pp/docs/x.md §2`, `pp/docs/x.md § 10`, `pp/docs/x.md § 3` and `pp/docs/x.md §1`.\nThe rules: `pp/docs/r.md §1`. Gone: `pp/docs/g.md § Gone`.\nThe prose pp/docs/x.md §1.2 (cited by path, for now)\nTwice: `pp/docs/none.md § A` and `pp/docs/none.md § B`.\nWords, not numbers: `pp/docs/x.md § 2-factor` and `pp/docs/x.md § 2.a`.\nThe old app: `po/docs/x.md §2`, `po/docs/w.md §4`, `po/docs/r.md §1` and `po/docs/ui.md §4`.\nIts theme: po/docs/ui.md § Colors for the theme\n' >> docs/glossary.md
ulog '- GLOSSARY: Pointers' && git add -A && git commit -qm "GLOSSARY: Pointers" && $J release >/dev/null
# docs <dir>: the pages the metarepo points into
docs() { mkdir -p api docs && printf 'x=1\n' > api/a.py && printf '# X\n\n## 2. Motes\n\n### 2.1 Identity\n\n## 10. Open questions\n' > docs/x.md \
  && printf '# R\n\n## Rules\n\n### 1.1 One\n' > docs/r.md && printf '# G\n\n## Other\n' > docs/g.md && printf '# W\n\n## 4. Keys\n\n## 40 Other\n' > docs/w.md; }
PP="$T/pp"; pcnew "$PP" && docs && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para pm --location "$PM" --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
G=".jig/meta-cache/docs/glossary.md points to"
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
$J init --para pm --location "$PM" --pin v0.1.0 --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
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
printf '\n## Pointers\nThe old app: `po/api/e.py`.\n' >> docs/glossary.md
ulog '- GLOSSARY: Pointers' && git add -A && git commit -qm "GLOSSARY: Pointers" && $J release >/dev/null
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
$J init --para rm --location "$RM" --pin v0.1.0 --contract 'api/**' >/dev/null && git add -A && git commit -qm "init --para"
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
sec_structure() {
# The repo's own files that hold its docs structure: old-contract holders, levels, maps.
SR="$T/structure"; pcnew "$SR" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/a src/a/c tests scripts
printf '# A\n\nThe a system.\n\n## Thing\n\nx\n' > docs/a/a.md
printf '# B\n\n## Now\nx\n\n## Rules\n### 1.1 y\n\n## Checks\n- 1.1 review\n' > docs/a/b.md
printf '# C\n\nThe c subsystem.\n\n## Index\n\nx\n' > docs/a/c.md
printf '# F\n\nThe f page.\n\n## Impl\n\nx\n' > docs/a/f.md
printf 'X = 1\n' > src/a/c/index.py && printf 'Y = 2\n' > src/a/c/impl.py
printf 'from src.a.c import index\n' > src/a/main.py
# Written with %s, so this file holds no list of the three headings itself.
printf 'HEADS = ["Now", "Rules", "%s"]\n' Checks > tests/test_docs.py
printf '#!/bin/sh\nprintf "# x\\n\\n## Now\\nx\\n\\n## Rules\\nx\\n\\n## Checks\\nx\\n" > p.md\n' > tests/fixture.sh
printf -- '- Rules written in a documentation page bind as if they stood in this file.\n- Keep %s and Rules current.\n' Now >> AGENTS.md
printf '{"systems": {"a": {"files": ["src/a/**"], "parts": {"b": {"files": []}, "c": {"files": ["src/a/c/**"]}}}}}\n' > docs/owners.json
printf 'import json\nprint(json.load(open("docs/owners.json")))\n' > scripts/gen.py
board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/b.md': [], 'docs/a/c.md': ['src/a/c/**'], 'docs/a/f.md': ['src/a/c/impl.py']}; b['reserve'] = {'section': {'next': 1, 'pattern': r'^### (\d+)\.\d+', 'files': ['docs/**/*.md']}}"
git add -A && git commit -qm fixture
n=$(grep -n 'bind as if' AGENTS.md | cut -d: -f1); m=$((n + 1))
msg="structure: survey names the check, the counter and both AGENTS.md lines as holders, not the fixture, and its last line names /jig:redocument"
out=$($J survey 2>&1)
expect_pass sh -c "h=\$(echo \"\$0\" | sed -n '/^Checks, counters and lines that hold the old page contract/,/^\$/p')
for w in 'tests/test_docs.py:1: ' '.jig/config.json reserve.section: ' \"AGENTS.md:$n: \" \"AGENTS.md:$m: \"; do echo \"\$h\" | grep -qF \"  \$w\" || { echo \"missing \$w\"; exit 1; }; done
! echo \"\$h\" | grep -q fixture.sh && echo \"\$0\" | tail -1 | grep -q '/jig:redocument'" "$out"
# --apply's own layout step drops the counter's `next`; the holder is its pattern and files.
msg="structure: the update dry run lists the same four under Repo files to review; --apply leaves them unchanged"
printf '# behind\n' >> .jig/jig.py && git commit -qam behind
before=$(shasum tests/test_docs.py AGENTS.md; python3 -c "import json; c = json.load(open('.jig/config.json'))['reserve']['section']; print(c['pattern'], c['files'])")
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
after=$(shasum tests/test_docs.py AGENTS.md; python3 -c "import json; c = json.load(open('.jig/config.json'))['reserve']['section']; print(c['pattern'], c['files'])")
expect_pass sh -c "r=\$(echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p')
for w in 'tests/test_docs.py:1: ' '.jig/config.json reserve.section: ' \"AGENTS.md:$n: \" \"AGENTS.md:$m: \"; do echo \"\$r\" | grep -qF \"  \$w\" || { echo \"missing \$w\"; exit 1; }; done
test \"\$1\" = \"\$2\"" "$out" "$before" "$after"
git add -A && git commit -qm update >/dev/null
msg="structure: b covers no file, a section of docs/a/a.md with no form move; f shares every file with c; c is not named"
out=$($J survey 2>&1)
expect_pass sh -c "h=\$(echo \"\$0\" | sed -n '/^Pages below a system that own no files/,/^\$/p')
echo \"\$h\" | grep -q '^  docs/a/b.md: section: covers no file: a section of docs/a/a.md' \
&& echo \"\$h\" | grep -q '^  docs/a/f.md: shared: every file it covers is docs/a/c.md.s too: the same subsystem, fold one into the other' \
&& ! echo \"\$h\" | grep -q '^  docs/a/c.md' && ! echo \"\$0\" | sed -n '/^Pages in the wrong shape/,/^\$/p' | grep -q 'docs/a/b.md'" "$out"
msg="structure: --levels gives c its own file, the file it shares with f, and the file the rest of a reaches it through"
expect_pass sh -c "$J survey --levels | grep -qF '  docs/a/c.md: subsystem: 1 own file, 1 shared with docs/a/f.md; reached through src/a/c/index.py, from 1 file'"
msg="structure: survey lists docs/owners.json as declaring a, b and c with the docmap's files, named by scripts/gen.py"
expect_pass sh -c "echo \"\$0\" | grep -qF '  docs/owners.json: declares docs/a/a.md, docs/a/b.md, docs/a/c.md; the same files as the docmap; named by scripts/gen.py'" "$out"
msg="structure: with c's docmap globs changed, the map's line says it differs for c"
board "b['docmap']['docs/a/c.md'] = ['src/a/c/index.py']" && git commit -qam "c narrower"
expect_pass sh -c "$J survey | grep -qF '  docs/owners.json: declares docs/a/a.md, docs/a/b.md, docs/a/c.md; differs from the docmap for docs/a/c.md'"
msg="structure: docs/a/c/d.md, covering no file, gets only the fold into docs/a/c.md, no deep_subsystems choice"
mkdir -p docs/a/c && printf '# D\n\nThe d page.\n\n## X\n\nx\n' > docs/a/c/d.md
# Planted: d is c's company while c stays flat, which the hook refuses.
board "b['docmap']['docs/a/c/d.md'] = []" && git add -A && git -c core.hooksPath=/dev/null commit -qm d
out=$($J survey 2>&1)
expect_pass sh -c "l=\$(echo \"\$0\" | sed -n '/^Pages below a subsystem/,/^\$/p' | grep '^  docs/a/c/d.md: ')
echo \"\$l\" | grep -q 'fold it into docs/a/c.md' && ! echo \"\$l\" | grep -q deep_subsystems" "$out"
msg="structure: a page with no docmap key is unmapped, not a section; update lists it the same, with no fold drafted"
printf '# G\n\nThe g page.\n\n## Invariants\n- g is g — it is; held by review.\n' > docs/a/g.md && printf 'x\n' > src/a/g.py
printf '# E\n\nThe e page.\n\n## Invariants\n- e is e — it is; held by review.\n' > docs/a/c/e.md && git add -A && git commit -qm "g, and e below c"
printf '# behind\n' >> .jig/jig.py && git commit -qam behind
out=$($J survey 2>&1); up=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -qF '  docs/a/g.md: unmapped: no docmap key: name its files in docmap, or fold it into docs/a/a.md' \
&& echo \"\$1\" | grep -qF '  docs/a/g.md: unmapped: no docmap key: name its files in docmap, or fold it into docs/a/a.md' \
&& ! echo \"\$1\" | grep -q 'fold docs/a/g.md'" "$out" "$up"
msg="structure: a deep page with no docmap key gets the one unmapped answer, with no deep_subsystems choice"
expect_pass sh -c "l=\$(echo \"\$0\" | sed -n '/^Pages below a subsystem/,/^\$/p' | grep '^  docs/a/c/e.md: ')
echo \"\$l\" | grep -q 'unmapped: no docmap key: name its files in docmap, or fold it into docs/a/c.md' && ! echo \"\$l\" | grep -q deep_subsystems \
&& ! echo \"\$1\" | grep -q 'fold docs/a/c/e.md'" "$out" "$up"
git checkout -q HEAD~1 -- .jig/jig.py && git commit -qam back
msg="structure: locale files keyed by page names, a JSON file nested 2000 deep, a register's counter and the repo's own words hold nothing"
mkdir -p locales docs/adr && printf '{"a": {"title": "A"}, "c": {"title": "C"}}\n' > locales/en.json && cp locales/en.json locales/fr.json
python3 -c "print('{\"a\": {\"c\": ' * 1000 + '1' + '}}' * 1000)" > deep.json
printf '# ADRs\n\n## 1. Use SQLite\n\nAccepted.\n' > docs/adr/log.md
board "b['reserve']['adr'] = {'pattern': r'^## (\d+)\. ', 'files': ['docs/adr/*.md']}"
# docs/core.md makes `core` a page's name: a word beside it, or a § after another name, cites nothing.
printf '# Core\n\nThe core system.\n\n## Invariants\n- core is core — it is; held by review.\n' > docs/core.md
printf -- '## 1.1 Setup\n- Caching follows RFC 9111 §5.2.\n- Lint Rules and Checks run in CI.\n' >> AGENTS.md
printf -- '- Our lint rules follow the Google style guide §3.2.\n- Keep the docs current with each change (§ 2 of CONTRIBUTING).\n' >> AGENTS.md
printf -- '- Do not change core without a review; see CONTRIBUTING §2.\n- The core loop runs its Rules and Checks in CI.\n' >> AGENTS.md
git add -A && git commit -qm noise
out=$($J survey 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! echo \"\$0\" | grep -q 'locales/\|deep.json\|reserve.adr' \
&& test \$(echo \"\$0\" | sed -n '/^Checks, counters and lines/,/^\$/p' | grep -c '^  AGENTS.md:') = 2" "$out"
msg="structure: a § placeholder, a § after a page's name, and a system's Rules and Checks are holders"
printf -- '- Cite a rule by its number, §N.M, in commits.\n- Follow core §2 for hard rules.\n- Keep each system%ss Rules and Checks current.\n' "'" >> AGENTS.md && git commit -qam "old lines"
expect_pass sh -c "test \$($J survey | sed -n '/^Checks, counters and lines/,/^\$/p' | grep -c '^  AGENTS.md:') = 5"
}

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
git add -A && git -c core.hooksPath=/dev/null commit -qm docs   # a page naming AGENTS.md, from before the rule
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
msg="homes: survey gives each page its destination, flat in docs/, and passes docs/c/c.md and docs/c/d.md, a flat part page beside it"
expect_pass homes "assert {p: h[p]['to'] for p in h if h[p]['kind'] == 'page'} == {'docs/systems/a.md': 'docs/a.md', 'docs/systems/b.md': 'docs/b.md'}, h
assert 'docs/c/c.md' not in h and 'docs/c/d.md' not in h, h"
behind
msg="homes: the dry run lists the two moves, the docmap key and the AGENTS.md line naming the folder"
out=$($UP 2>&1)
expect_pass sh -c "for w in 'git mv docs/systems/a.md docs/a.md' 'git mv docs/systems/b.md docs/b.md' '.jig/config.json docmap: docs/systems/a.md' 'AGENTS.md:[0-9]*: - Pages live in .docs/systems/.'; do echo \"\$0\" | grep -q \"^      \$w\" || { echo \"missing \$w\"; exit 1; }; done" "$out"
$UP --apply >/dev/null 2>&1 && git commit -qm update
git mv docs/systems/a.md docs/a.md && git mv docs/systems/b.md docs/b.md
sed -i.bak 's|`docs/systems/`|`docs/`|' AGENTS.md && rm AGENTS.md.bak
board "b['docmap'] = {'docs/a.md': ['src/**']}" && git add -A && git commit -qm "docs: pages flat in docs/"
msg="homes: once the moves are carried out, survey lists none of them"
expect_pass homes "assert not h, h"
msg="homes: survey prints no holder, no page that owns no files and no structure map"
expect_pass sh -c "! $J survey | grep -qE '^(Checks, counters and lines|Pages below a system that own no files|Files that declare the docs structure)'"
page docs/systems/c.md && git add -A && git commit -qm "c again" && behind
msg="homes: a page whose destination exists is proposed as a fold, not a move"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^      fold docs/systems/c.md into docs/c/c.md' && ! echo \"\$0\" | grep -q 'git mv docs/systems/c.md'" "$out"

# The docs tree is two levels deep; a third only on the owner's deep_subsystems entry.
HD="$T/homes-deep"; pcnew "$HD" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
page docs/a/a.md && page docs/a/b/b.md && page docs/a/b/c/c.md && page docs/c/c.md && page docs/c/d/d.md && page docs/a/b/x.md
# Planted: docs/c/d/d.md is alone in its folder, which the hook refuses.
git add -A && git -c core.hooksPath=/dev/null commit -qm deep
msg="homes: a page below a subsystem is deep, folding into its subsystem's page; docs/c/d/d.md passes; a flat page beside a subsystem's is deep too"
expect_pass homes "assert (h['docs/a/b/c/c.md']['kind'], h['docs/a/b/c/c.md']['to']) == ('deep', 'docs/a/b/b.md'), h
assert 'docs/c/d/d.md' not in h and 'docs/a/b/b.md' not in h, h
assert (h['docs/a/b/x.md']['kind'], h['docs/a/b/x.md']['to'], h['docs/a/b/x.md']['fold']) == ('deep', 'docs/a/b/b.md', True), h"
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
import os; os.makedirs('docs/misc', exist_ok=True)
open('docs/misc/quoting.md', 'w').write('# Q\n\n## Now\n' + ' '.join(quoted) + '\n\n## Rules\nx\n\n## Checks\ny\n')
PY
git add -A && git commit -qm quoting
expect_pass homes "assert h['docs/misc/quoting.md']['kind'] == 'page', h['docs/misc/quoting.md']"

HX="$T/homes-meta-fresh"; pcnew "$HX" && git add -A && git commit -qm init && $J init --meta --name hx >/dev/null && git add -A && git commit -qm meta
msg="homes: a fresh metarepo has no homeless files"
expect_pass homes "assert not h, h"

# A pararepo whose page a metarepo decision points into, as sync_buffer builds one.
HM="$T/homes-meta"; pcnew "$HM" && git add -A && git commit -qm init && $J init --meta --name hm >/dev/null
ulog '### D-001 the list rule (`app/docs/systems/a.md § Rules`)
Accepted (owner, 2026-11-01).
Touches: docs/shared.md'
git add -A && git commit -qm meta-init && $J release >/dev/null
HA="$T/app"; pcnew "$HA" && page docs/systems/a.md && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para hm --location "$HM" --contract 'docs/systems/a.md' >/dev/null && git add -A && git commit -qm "init --para"
behind
msg="homes: in a pararepo, a page's proposal names the cached pointer, BUFFER.md and the contract path"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^      .jig/meta-cache/.jig/decisions.md points at docs/systems/a.md § Rules' && echo \"\$0\" | grep -q '^      the move.s commit carries a .jig/ledgers/BUFFER.md row' && echo \"\$0\" | grep -q '^      .jig/para.json contract_paths: docs/systems/a.md'" "$out"
# A glossary is docs/glossary.md, a ## heading or a table row per term, in any repo.
HG="$T/homes-glossary"; pcnew "$HG" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs && printf '# Glossary\n\n**mote** — x\n\n**seam** (join): y\n\n**not** a term here\n\n## grain\n\n**grain** — under its own heading\n' > docs/glossary.md
printf '# Glossary\n\n**grain** — z\n' > GLOSSARY.md && git add -A && git commit -qm glossary
msg="homes: survey names mote and seam, bold terms in docs/glossary.md, and not one under its own heading"
expect_pass homes "assert r['glossary_unheaded'] == ['mote', 'seam'], r['glossary_unheaded']"
msg="homes: a root GLOSSARY.md is listed with to docs/glossary.md, in --json and in print"
expect_pass homes "assert h['GLOSSARY.md']['kind'] == 'stray' and h['GLOSSARY.md']['to'] == 'docs/glossary.md', h.get('GLOSSARY.md')"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^GLOSSARY.md → docs/glossary.md' && echo \"\$0\" | grep -q 'not headings or rows: 2 (mote, seam)'" "$out"
printf '# Glossary\n\n## mote\nx\n\n## seam\ny\n' > docs/glossary.md && git commit -qam headings
msg="homes: with ## headings instead, survey names no term"
expect_pass homes "assert r['glossary_unheaded'] == [], r['glossary_unheaded']"
behind
msg="homes: update lists GLOSSARY.md under Repo files to review, and --apply leaves it alone"
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  GLOSSARY.md: the glossary.s home is docs/glossary.md' && test -z \"\$(git status --porcelain GLOSSARY.md docs/glossary.md)\" && test -f GLOSSARY.md" "$out"
# The reading list climbs the docs tree from each covering page; fold-in doesn't.
HL="$T/homes-reading"; pcnew "$HL" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
page docs/a/a.md && page docs/a/b/b.md && page docs/a/b/c/c.md && mkdir -p src/a/c && printf 'x\n' > src/a/lib.rs && printf 'x\n' > src/a/b.rs && printf 'x\n' > src/a/c/c.rs
board "b['docmap'] = {'docs/a/a.md': ['src/a/lib.rs'], 'docs/a/b/b.md': ['src/a/b.rs'], 'docs/a/b/c/c.md': ['src/a/c/**']}" && git add -A && git commit -qm docmap
rl() { $J reading-list "$@" | sed -n '/^Read first:/,/^$/p' | grep '^  docs/'; }
msg="homes: reading-list for a subsystem's file prints its page, then its system's page marked as the parent"
expect_pass test "$(rl src/a/b.rs)" = "$(printf '  docs/a/b/b.md\n  docs/a/a.md   (parent of docs/a/b/b.md)')"
board "b['deep_subsystems'] = {'docs/a/b/c': 'own module'}" && git add -A && git commit -qm approve
msg="homes: under an approved deep level, reading-list prints c, then b and a, each once and marked"
expect_pass test "$(rl src/a/c/c.rs)" = "$(printf '  docs/a/b/c/c.md\n  docs/a/b/b.md   (parent of docs/a/b/c/c.md)\n  docs/a/a.md   (parent of docs/a/b/b.md)')"
msg="homes: a page that covers a named file prints once, without the parent mark"
expect_pass test "$(rl src/a/lib.rs src/a/b.rs)" = "$(printf '  docs/a/a.md\n  docs/a/b/b.md')"
page docs/net/net.md && page docs/seam-gpio.md && mkdir -p main && printf 'x\n' > main/app.c && printf 'x\n' > main/x.c
printf '# X\n\nThe x part.\n' > docs/net/x.md
board "b['docmap']['docs/seam-gpio.md'] = ['main/app.c']; b['docmap']['docs/net/x.md'] = ['main/x.c']" && git add -A && git commit -qm seam
msg="homes: a seam page, flat in docs/ where its two systems share a folder, prints no parent"
expect_pass test "$(rl main/app.c)" = "  docs/seam-gpio.md"
msg="homes: a docmap-named flat page in a system's folder climbs to that system's page, whatever its sections"
expect_pass test "$(rl main/x.c)" = "$(printf '  docs/net/x.md\n  docs/net/net.md   (parent of docs/net/x.md)')"
$J open RL --spec t --owns 'src/**' >/dev/null && git add -A && git commit -qm "open RL"
( cd .git/jig/worktrees/RL && printf 'y\n' > src/a/b.rs && git add -A && git commit -qm b && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 )
msg="homes: a handoff changing only a subsystem's file asks only its page"
expect_pass sh -c "test \"\$(grep -c -- '^- \[ \] docs/' .git/jig/worktrees/RL/.jig/handoffs/RL-*.md)\" = 1 && grep -q -- '^- \[ \] docs/a/b/b.md' .git/jig/worktrees/RL/.jig/handoffs/RL-*.md"

# A page is one file, flat in its parent's folder, until it holds another.
HF="$T/homes-flat"; pcnew "$HF" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/a src/a src/b src/c && printf '# A\n\nThe a system. [notes](notes.md)\n' > docs/a/a.md
printf '# B\n\nThe b part.\n' > docs/a/b.md && printf '# Notes\n\nsome notes\n' > docs/a/notes.md
printf '# C\n\nThe c part.\n\n## Invariants\n- c is c — it is; held by review.\n' > docs/a/c.md
printf 'x\n' > src/a/lib.rs && printf 'x\n' > src/b/b.rs && printf 'x\n' > src/c/c.rs
board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/b.md': ['src/b/**'], 'docs/a/c.md': ['src/c/**']}"
git add -A && git commit -qm flat
msg="flat: docs/a/b.md (docmap names it) and docs/a/c.md (Invariants) are flat pages, docs/a/notes.md a linked file: survey reports none"
expect_pass homes "assert not h and r['page_shapes'] == [] and r['datasheets_unlinked'] == [], (h, r['page_shapes'], r['datasheets_unlinked'])"
msg="flat: reading-list for a flat part page's file prints it, then its system's page marked as the parent"
expect_pass test "$(rl src/c/c.rs)" = "$(printf '  docs/a/c.md\n  docs/a/a.md   (parent of docs/a/c.md)')"
mkdir -p docs/a/d && printf '# D\n\nThe d part.\n' > docs/a/d/d.md && git add -A && git commit -qm "d alone"
msg="flat: a folder page alone in its folder is reported flat at docs/a/d.md, in --json and in print"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/d/d.md: flat at docs/a/d.md' && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert [(e['path'], e['to'], e['into']) for e in r['page_shapes']] == [('docs/a/d/d.md', 'docs/a/d.md', False)], r['page_shapes']\"" "$out"
behind
msg="flat: update lists the one-file folder under Repo files to review with its git mv; --apply leaves it"
out=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  docs/a/d/d.md: flat at docs/a/d.md' && echo \"\$0\" | grep -q '^      git mv docs/a/d/d.md docs/a/d.md' && test -f docs/a/d/d.md && test -z \"\$(git status --porcelain docs)\"" "$out"
git add -A && git commit -qm update
printf 'pdf' > docs/a/d/wiring.pdf && printf '[wiring](wiring.pdf)\n' >> docs/a/d/d.md && git add -A && git commit -qm wiring
msg="flat: with docs/a/d/wiring.pdf beside it, the folder page isn't reported"
expect_pass homes "assert r['page_shapes'] == [], r['page_shapes']"
mkdir -p docs/a/b && printf 'png' > docs/a/b/scope.png && git add -A && git -c core.hooksPath=/dev/null commit -qm "b has a file"  # planted
msg="flat: a flat page with a folder of its own name is told to move into it"
expect_pass homes "assert [(e['path'], e['to'], e['into']) for e in r['page_shapes']] == [('docs/a/b.md', 'docs/a/b/b.md', True)], r['page_shapes']"
git mv docs/a/b.md docs/a/b/b.md && printf '[scope](scope.png)\n' >> docs/a/b/b.md && printf '# E\n\nThe e part.\n' > docs/a/b/e.md
board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/b/b.md': ['src/b/**'], 'docs/a/b/e.md': ['src/b/e/**']}" && git add -A && git commit -qm "b into its folder, e below it"
msg="flat: docs/a/b/e.md, docmap-named, is deep without a deep_subsystems entry for docs/a/b/e"
expect_pass homes "assert (h['docs/a/b/e.md']['kind'], h['docs/a/b/e.md']['to']) == ('deep', 'docs/a/b/b.md'), h
assert r['page_shapes'] == [], r['page_shapes']"
board "b['deep_subsystems'] = {'docs/a/b/e': 'own module'}" && git add -A && git commit -qm approve
msg="flat: with docs/a/b/e approved, it is at home"
expect_pass homes "assert not h, h"
msg="flat: an approved deep folder page alone goes flat, and its approval still names a tracked page"
expect_pass homes "assert r['deep_unmatched'] == [], r['deep_unmatched']"
mkdir -p docs/a/b/f && printf '# F\n\nThe f part.\n' > docs/a/b/f.md && printf '# F2\n\nThe f part again.\n' > docs/a/b/f/f.md
board "b['docmap']['docs/a/b/f.md'] = ['src/f/**']; b['deep_subsystems']['docs/a/b/f'] = 'own module'" && git add -A && git commit -qm "f twice"
msg="flat: docs/a/b/f.md and docs/a/b/f/f.md together: the flat one folds into the folder page"
expect_pass homes "assert [(e['path'], e['to'], e['into'], e['fold']) for e in r['page_shapes']] == [('docs/a/b/f.md', 'docs/a/b/f/f.md', True, True)], r['page_shapes']"

# A flat page still owns the folder it has started to fill.
HF2="$T/homes-flat-owner"; pcnew "$HF2" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/a docs/b/datasheets src/a src/b && printf 'docs/**/datasheets/\n' > .gitignore
printf '# A\n\nThe a system.\n\n## Invariants\n- a — x; held by review.\n' > docs/a.md
printf '# B\n\nThe b part.\n\n## Invariants\n- b — x; held by review.\n' > docs/a/b.md
printf '# B board\n\nThe b board. [x](b/datasheets/x.pdf)\n' > docs/b.md && printf 'pdf\n' > docs/b/datasheets/x.pdf
printf 'x\n' > src/a/a.rs && printf 'x\n' > src/b/b.rs
board "b['docmap'] = {'docs/a.md': ['src/a/**'], 'docs/a/b.md': ['src/a/b/**'], 'docs/b.md': ['src/b/**']}" && git add -A && git -c core.hooksPath=/dev/null commit -qm owners  # planted: both flat pages hold files
msg="flat: a flat docs/a.md owns docs/a/, so docs/a/b.md stays its part and only a.md is told to move in"
expect_pass homes "assert not h, h
assert sorted((e['path'], e['to'], e['into']) for e in r['page_shapes']) == [('docs/a.md', 'docs/a/a.md', True), ('docs/b.md', 'docs/b/b.md', True)], r['page_shapes']"
msg="flat: a flat page linking its own ignored datasheets/ is told to move in, not to share the file"
expect_pass homes "assert r['datasheets_misplaced'] == [] and r['datasheets_orphan'] == [], r"
mkdir -p docs/g src/g && printf '# G\n\nThe g system.\n' > docs/g.md && printf '# Seam\n\nThe seam.\n' > docs/a/seam-g.md && printf 'x\n' > src/g/g.rs
board "b['docmap']['docs/g.md'] = ['src/g/**']; b['docmap']['docs/a/seam-g.md'] = ['src/a/a.rs', 'src/g/g.rs']" && git add -A && git commit -qm seam
msg="flat: a page in one system's folder covering another system's file is named as a misfiled seam"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/seam-g.md: covers files of two systems (also docs/g.md.s): a seam lives in their nearest shared folder' && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert r['seams_misfiled'] == [{'path': 'docs/a/seam-g.md', 'other': 'docs/g.md'}], r['seams_misfiled']\"" "$out"
mkdir -p docs/systems && printf '# Old\n\nAn old page.\n' > docs/systems/old.md
board "b['docmap']['docs/systems/old.md'] = ['src/g/g.rs']" && git add -A && git commit -qm "old folder"
msg="flat: a page in a folder no page owns is listed once, as misplaced, and never as a seam"
out=$($J survey 2>&1)
expect_pass sh -c "test \$(echo \"\$0\" | grep -c 'docs/systems/old.md') = 1 && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
h = {e['path']: e for e in r['homeless']}
assert h['docs/systems/old.md']['to'] == 'docs/old.md', h
assert r['seams_misfiled'] == [{'path': 'docs/a/seam-g.md', 'other': 'docs/g.md'}], r['seams_misfiled']\"" "$out"
git mv docs/a.md docs/a/a.md && board "b['docmap']['docs/a/a.md'] = b['docmap'].pop('docs/a.md')" && git add -A && git commit -qm "a into its folder"
msg="flat: with its system page in the folder, docs/a/a.md, the seam is still named"
expect_pass homes "assert r['seams_misfiled'] == [{'path': 'docs/a/seam-g.md', 'other': 'docs/g.md'}], r['seams_misfiled']"
mkdir -p docs/systems/rest && printf '# Rest\n\nThe rest page. [scope](scope.png)\n' > docs/systems/rest/rest.md && printf 'png' > docs/systems/rest/scope.png
board "b['docmap']['docs/systems/rest/rest.md'] = ['src/g/g.rs']" && git add -A && git commit -qm "folder page in an ownerless folder"
msg="flat: a folder page in a folder no page owns is listed once, to move with its folder, and never as a seam"
out=$($J survey 2>&1)
expect_pass sh -c "test \$(echo \"\$0\" | grep -c 'docs/systems/rest/rest.md') = 1 && ! echo \"\$0\" | grep -q 'sits in docs/systems/rest/rest.md' && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
h = {e['path']: e for e in r['homeless']}
assert (h['docs/systems/rest/rest.md']['kind'], h['docs/systems/rest/rest.md']['to']) == ('page', 'docs/rest/rest.md'), h
assert r['seams_misfiled'] == [{'path': 'docs/a/seam-g.md', 'other': 'docs/g.md'}], r['seams_misfiled']\"" "$out"

# A house-format page the board names is a page wherever it sits; a jig repo never adopts again.
HF="$T/homes-house"; pcnew "$HF" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/crates/s src/s && printf 'x\n' > src/s/s.rs
for n in store lib; do printf '# %s\n\n## Does\nKeeps rows.\n\n## Gotchas\nNone.\n' $n > docs/crates/s/$n.md; done
board "b['docmap'] = {'docs/crates/s/store.md': ['src/s/s.rs'], 'docs/crates/s/lib.md': ['src/s/**']}" && git add -A && git commit -qm house
msg="house: docmap pages in any format are pages outside the docs tree, not unread strays, and survey says /jig:redocument"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | sed -n '/^Pages outside the docs tree/,/^\$/p' | grep -q '^  docs/crates/s/store.md → docs/store.md' && echo \"\$0\" | sed -n '/^Pages outside the docs tree/,/^\$/p' | grep -q '^  docs/crates/s/lib.md → docs/lib.md' && ! echo \"\$0\" | grep -q 'never read since' && echo \"\$0\" | tail -1 | grep -q 'run /jig:redocument'" "$out"
behind
msg="house: update proposes moving both, with their docmap keys"
out=$($UP 2>&1)
expect_pass sh -c "for w in 'git mv docs/crates/s/store.md docs/store.md' 'git mv docs/crates/s/lib.md docs/lib.md' '.jig/config.json docmap: docs/crates/s/store.md' '.jig/config.json docmap: docs/crates/s/lib.md'; do echo \"\$0\" | grep -q \"^      \$w\" || { echo \"missing \$w\"; exit 1; }; done" "$out"

HL="$T/homes-nolead"; pcnew "$HL" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/s && printf '# S\n\n## Part\n\nText.\n' > docs/s/s.md && git add -A && git commit -qm page
msg="house: a page at home with no lead paragraph sends a jig repo to /jig:update, not adopt or redocument"
expect_pass sh -c "$J survey | tail -1 | grep -q 'run /jig:update to review each in place' && test \$($J survey | tail -1 | grep -o '/jig:update' | wc -l) = 1"
msg="house: on a current repo, update is up to date, exits 0, and still lists the page with its problem"
out=$($UP 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | head -1 | grep -qx 'up to date' && echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  docs/s/s.md: off the page contract .*no lead paragraph'" "$out"
msg="house: a clean jig repo's survey says nothing to do"
# Flat too: a page alone in its folder is a finding, and survey counts it.
printf '# S\n\nS keeps rows.\n\n## Part\n\nText.\n' > docs/s/s.md && git mv docs/s/s.md docs/s.md && board "b['docmap'] = {'docs/s.md': ['src/**']}" && git commit -qam lead
expect_pass sh -c "$J survey | tail -1 | grep -qx 'On jig already: nothing to do.'"
msg="house: a docmap key at the root moves to docs/ alone, with only its own references"
mkdir -p src && printf 'x\n' > src/x.py && printf '# Architecture\n\n## Layers\nTwo.\n' > ARCHITECTURE.md
printf '# App\n\nSee ARCHITECTURE.md and src/x.py.\n' > README.md
board "b['docmap'] = {'ARCHITECTURE.md': ['src/**']}" && git add -A && git commit -qm arch
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  ARCHITECTURE.md: 1 page outside the docs tree' && echo \"\$0\" | grep -q '^      git mv ARCHITECTURE.md docs/ARCHITECTURE.md' && ! echo \"\$0\" | grep -q '^  /: ' && ! echo \"\$0\" | grep -q 'AGENTS.md:[0-9]'" "$out"
msg="house: package READMEs that docmap names stay where they are"
mkdir -p crates/a crates/b && printf '# a\n\nThe a crate.\n' > crates/a/README.md && printf '# b\n\nThe b crate.\n' > crates/b/README.md
board "b['docmap'] = {'crates/a/README.md': ['src/**'], 'crates/b/README.md': ['src/**']}" && git add -A && git commit -qm crates
out=$($UP 2>&1)
expect_pass sh -c "! echo \"\$0\" | grep -q 'git mv crates/' && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert not {'crates/a/README.md', 'crates/b/README.md'} & {h['path'] for h in r['homeless']}, r['homeless']\"" "$out"
msg="house: the same page in a repo with no board still gets /jig:adopt"
HN="$T/homes-noboard"; pcnew "$HN" && mkdir -p docs/s && printf '# S\n\n## Part\n\nText.\n' > docs/s/s.md && git add -A && git commit -qm init
expect_pass sh -c "$J survey | tail -1 | grep -q 'Run /jig:adopt'"
msg="house: a jig repo with only a stray gets no /jig:adopt line"
HS="$T/homes-stray"; pcnew "$HS" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs && printf 'Ideas.\n' > docs/ideas.md && git add -A && git commit -qm stray
expect_pass sh -c "! $J survey | grep -q '/jig:adopt'"

# A page's form is refused when a change puts it wrong; one already wrong is survey's.
ipage() { mkdir -p "$(dirname "$1")" && printf '# P\n\nP keeps rows.\n\n## Invariants\n- rows stay sorted\n' > "$1"; }
frefused() { out=$(git commit -qm "$1" 2>&1); rc=$?; git reset -q --hard; git clean -fdq; }
HF="$T/homes-form"; pcnew "$HF" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
ipage docs/a/a.md && ipage docs/a/c.md && ipage docs/a/d/d.md && mkf docs/a/d/wiring.pdf src/x.py
git add -A && git -c core.hooksPath=/dev/null commit -qm pages
msg="form: a lone docs/a/b/b.md is refused by jig check --staged and the hook, naming docs/a/b.md"
ipage docs/a/b/b.md && git add -A && chk=$($J check --staged 2>&1); crc=$?; frefused lone
expect_pass sh -c "test $crc != 0 && test $rc != 0 && echo \"\$0\" | grep -q '^docs/a/b/b.md: flat at docs/a/b.md: its folder holds nothing else' && echo \"\$1\" | grep -q 'docs/a/b/b.md: flat at docs/a/b.md'" "$chk" "$out"
msg="form: the refusal holds survey's line for the same page"
ipage docs/a/b/b.md && git add -A
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
e = [e for e in r['page_shapes'] if e['path'] == 'docs/a/b/b.md'][0]
fix = 'flat at %s: its folder holds nothing else' % e['to']
out = subprocess.run(['python3', '.jig/jig.py', 'check', '--staged'], capture_output=True, text=True).stdout
assert 'docs/a/b/b.md: ' + fix + ' (' in out, out
assert '  docs/a/b/b.md: ' + fix in subprocess.check_output(['python3', '.jig/jig.py', 'survey'], text=True)"
undo
msg="form: the same page added flat at docs/a/b.md commits"
ipage docs/a/b.md && git add -A && expect_pass git commit -qm flat
msg="form: a first file in flat docs/a/c.md's folder is refused, naming docs/a/c/c.md"
mkf docs/a/c/x.png && git add -A && frefused png
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/a/c.md: has a folder of its own name, docs/a/c/: move it to docs/a/c/c.md'" "$out"
msg="form: the same file with the git mv into its folder commits"
mkf docs/a/c/x.png && git add -A && git mv docs/a/c.md docs/a/c/c.md && expect_pass git commit -qm into
msg="form: removing docs/a/d/'s last other file is refused, naming docs/a/d.md"
git rm -q docs/a/d/wiring.pdf && frefused rmpdf
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/a/d/d.md: flat at docs/a/d.md'" "$out"
msg="form: the same removal with the page moved flat commits"
git rm -q docs/a/d/wiring.pdf && git mv docs/a/d/d.md docs/a/d.md && expect_pass git commit -qm flatten
msg="form: a lone page already on trunk commits when its text or src/ changes, and survey still lists it"
ipage docs/a/e/e.md && git add -A && git -c core.hooksPath=/dev/null commit -qm planted
printf -- '- one more\n' >> docs/a/e/e.md && git add -A && expect_pass git commit -qm edit
printf 'y\n' > src/x.py && git add -A && expect_pass git commit -qm src
expect_pass sh -c "$J survey | grep -q '^  docs/a/e/e.md: flat at docs/a/e.md'"
msg="form: a lone unnamed folder page isn't refused; survey says name it in docmap"
mkdir -p docs/g && printf '# G\n\nNotes.\n' > docs/g/g.md && git add -A && expect_pass git commit -qm unnamed
expect_pass sh -c "$J survey | grep -q '^  docs/g/g.md: flat at docs/g.md: .*name it in docmap'"
msg="form: an exception the owner recorded for a page's shape lets a change put it back"
ipage docs/n/n.md && board "b['docmap']['docs/n/n.md'] = ['src/n/**']; b['findings'] = {'shape:docs/n/n.md': 'exception: schematics land next month'}"
git add -A && git -c core.hooksPath=/dev/null commit -qm "n, excepted" && git mv docs/n/n.md docs/n.md && git commit -qm "n flat"
git mv docs/n.md docs/n/n.md && expect_pass git commit -qm "n back"
msg="form: update's fold of a deep page drafts the move flat of the page it leaves alone, and that commit passes"
ipage docs/q/q.md && ipage docs/q/r/r.md && ipage docs/q/r/s/s.md && mkf src/q/r/s/y.py
board "b['docmap'].update({'docs/q/r/r.md': ['src/q/r/*.py'], 'docs/q/r/s/s.md': ['src/q/r/s/**']})"
git add -A && git -c core.hooksPath=/dev/null commit -qm deep && behind
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -A2 '^      fold docs/q/r/s/s.md into docs/q/r/r.md' | grep -q '^      git mv docs/q/r/r.md docs/q/r.md'" "$out"
cat docs/q/r/s/s.md >> docs/q/r/r.md && git rm -q docs/q/r/s/s.md && git add -A && git mv docs/q/r/r.md docs/q/r.md
expect_pass git commit -qm "fold s"
msg="form: an approved move of a lone folder page lands flat, and its commit passes"
ipage docs/w/k/k.md && board "b['docmap']['docs/w/k/k.md'] = []" && git add -A && git -c core.hooksPath=/dev/null commit -qm "lone k"
board "b['findings']['page:docs/w/k/k.md'] = 'approved'" && git commit -qam "k approved" && behind
$UP --apply >/dev/null 2>&1
expect_pass sh -c "git diff --cached --name-status | grep -q '^R.*docs/w/k/k.md	docs/k.md' && git commit -qm apply"
msg="form: a fold carries no move for a page whose company it leaves as it was: that move is its own finding"
ipage docs/u.md && ipage docs/u/c.md && ipage docs/u/e/e.md && mkf src/u/u.py src/u/c/c.py
board "b['docmap'].update({'docs/u.md': ['src/u/*.py'], 'docs/u/c.md': ['src/u/c/**'], 'docs/u/e/e.md': ['src/u/none/**']})"
git add -A && git -c core.hooksPath=/dev/null commit -qm "u, already wrong" && behind
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^      fold docs/u/e/e.md into ' && ! echo \"\$0\" | grep -q '^      git mv docs/u.md docs/u/u.md\$'" "$out"
msg="form: adding a system page above a lone page gives it a home, and the hook refuses its form"
ipage docs/v/b/b.md && board "b['docmap']['docs/v/b/b.md'] = []" && git add -A && git -c core.hooksPath=/dev/null commit -qm "lone v/b"
ipage docs/v/v.md && git add -A && frefused "v page"
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/v/b/b.md: flat at docs/v/b.md'" "$out"
msg="form: jig check run from a subfolder judges the whole tree"
board "b['docmap']['docs/z/z.md'] = []" && git commit -qam "z named" && ipage docs/z/z.md && git add -A
out=$(cd docs && python3 ../.jig/jig.py check --staged 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '^docs/z/z.md: flat at docs/z.md'" "$out"
msg="form: a one-page edit in a tree of hundreds of pages is judged in seconds, not minutes"
# 30 systems of 10 pages, each mapped to code of its own with a README beside it: a stray .md apiece.
python3 -c "
import json, os
b = json.load(open('.jig/config.json'))
for i in range(30):
    os.makedirs(f'docs/t{i}', exist_ok=True)
    for j in range(10):
        page = f'docs/t{i}/' + (f'p{j}.md' if j else f't{i}.md')
        open(page, 'w').write('# P\\n\\nPart.\\n\\n## Invariants\\n- x\\n')
        os.makedirs(f'src/t{i}/p{j}', exist_ok=True)
        open(f'src/t{i}/p{j}/a.py', 'w').write('x\\n')
        open(f'src/t{i}/p{j}/README.md', 'w').write('readme\\n')
        b['docmap'][page] = [f'src/t{i}/p{j}/**']
json.dump(b, open('.jig/config.json', 'w'), indent=2)"
git add -A && git -c core.hooksPath=/dev/null commit -qm many && printf -- '- e\n' >> docs/t1/p1.md && git add -A
start=$(date +%s); out=$($J check --staged 2>&1); took=$(( $(date +%s) - start ))
expect_pass sh -c "test $took -lt 20 && test \"\$0\" = ok" "$out"
git reset -q --hard
msg="form: jig merge of a job that slipped a lone page in stops with the refusal and commits no merge"
$J open pf --branch b-pf --owns 'docs/**' >/dev/null && git add -A && git commit -qm "TOOL: open pf"
tip=$(git rev-parse HEAD)
(cd .git/jig/worktrees/b-pf && ipage docs/h/h.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "h: page" \
  && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note pf")
out=$($J merge pf 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/h/h.md: flat at docs/h.md' && test \"\$(git rev-parse HEAD)\" = $tip" "$out"
git merge --abort 2>/dev/null
msg="form: the merge's hint says to abort and fix it on the job's branch"
expect_pass sh -c "echo \"\$0\" | grep -q 'git merge --abort., which puts pf.s entry back, fix it on b-pf'" "$out"
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

# ---------------------------------------------------------------- a metarepo's docs tree
sec_meta_docs() {
mhomes() { python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
h = {e['path']: e for e in r['homeless']}
$1"; }
MD="$T/meta-docs"; mkdir -p "$MD" && cd "$MD" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --no-hooks >/dev/null
python3 -c "import json; p='.jig/meta.json'; d=json.load(open(p)); d['entry_files'] += ['products/**/*.md']; json.dump(d, open(p, 'w'))"
mkdir -p products/hardware && printf '# x\n\nX is a part.\n' > products/hardware/x.md && git add -A
msg="meta docs: a page entry_files names outside docs/ is a page outside the docs tree, to docs/products/x.md"
expect_pass mhomes "assert h['products/hardware/x.md']['kind'] == 'page' and h['products/hardware/x.md']['to'] == 'docs/products/x.md', h"
msg="meta docs: the decisions register, CHANGELOG.md and README.md are not listed"
expect_pass mhomes "assert not {'DECISIONS.md', 'CHANGELOG.md', 'README.md'} & set(h), h"
msg="meta docs: survey's last line names /jig:redocument"
out=$($J survey 2>&1); expect_pass sh -c "echo \"\$0\" | tail -1 | grep -q '/jig:redocument'" "$out"
mkdir -p docs/products && printf '# w\n\nW is a product, and it exists for a reason.\n' > docs/products/w.md
printf '# y\n\nY is a page.\n' > docs/y.md && git add -A
msg="meta docs: docs/products/w.md with a lead paragraph passes survey, with no docs/products/products.md"
expect_pass mhomes "assert 'docs/products/w.md' not in h and not [e for e in r['page_contract'] if e['path'] == 'docs/products/w.md'], (h, r['page_contract'])"
msg="meta docs: docs/y.md in a metarepo needs a genre"
out=$($J survey 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/y.md: needs a genre'" "$out"
mkdir -p docs/products/w/datasheets && printf '# a\n\n## Undefined\n' > docs/products/w/a.md && git add -A
msg="meta docs: a genre adds no depth: a page there with subsystems moves into its folder, docs/products/w/w.md"
expect_pass mhomes "assert [e['to'] for e in r['page_shapes'] if e['path'] == 'docs/products/w.md'] == ['docs/products/w/w.md'], r['page_shapes']"
git rm -rq --cached docs/products/w && rm -r docs/products/w
mkdir -p features/echo && printf '# echo\n\nEcho is.\n' > features/echo/echo.md && printf '# spells\n\nSpells.\n' > features/echo/spells.md
printf '# Glossary\n\n**x** — y\n' > GLOSSARY.md && git add -A
msg="meta docs: a page outside docs/ named for its folder, and a file beside it, are both pages to move"
expect_pass mhomes "assert h['features/echo/echo.md']['to'] == 'docs/features/echo.md' and h['features/echo/spells.md']['to'] == 'docs/features/spells.md', h"
msg="meta docs: GLOSSARY.md is bound for docs/glossary.md, not a genre"
expect_pass mhomes "assert h['GLOSSARY.md']['to'] == 'docs/glossary.md', h['GLOSSARY.md']"
msg="meta docs: the Doc homes line gives the genre tree"
out=$($J survey 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'docs/<genre>/<name>.md each page'" "$out"
python3 -c "import json; p='.jig/config.json'; d=json.load(open(p)); d['not_docs'] = ['features/**', 'DECISIONS.md']; json.dump(d, open(p, 'w'))"
msg="meta docs: a not_docs glob hiding pages is named, and survey still routes to /jig:redocument"
out=$($J survey 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'glob features/\*\* hides 2 pages' && ! echo \"\$0\" | grep -q 'glob DECISIONS.md' && echo \"\$0\" | tail -1 | grep -q '/jig:redocument'" "$out"
python3 -c "import json; p='.jig/config.json'; d=json.load(open(p)); d['not_docs'] = []; json.dump(d, open(p, 'w'))"
git commit -qm docs --no-verify
msg="meta docs: update proposes genres from the folders under docs/, and docs/**/*.md for entry_files"
out=$($UP 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q '\"genres\": \[\"products\"\]' && echo \"\$0\" | grep -q 'docs/\*\*/\*.md'" "$out"

MG="$T/meta-genres"; mkdir -p "$MG" && cd "$MG" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --no-hooks --genres product-ecosystem >/dev/null
msg="meta docs: --genres product-ecosystem writes the four genres to meta.json"
expect_pass python3 -c "import json; assert json.load(open('.jig/meta.json'))['genres'] == ['products', 'features', 'principles', 'concepts']"
msg="meta docs: and a ## heading per genre in docs/glossary.md"
expect_pass sh -c "grep '^## ' docs/glossary.md | tr '\n' ' ' | grep -qx '## products ## features ## principles ## concepts '"
mkdir -p docs/misc && printf '# z\n\nZ is.\n' > docs/misc/z.md && git add -A
msg="meta docs: with genres set, docs/misc/z.md is in an undeclared genre"
out=$($J survey 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/misc/z.md: misc/ is no genre'" "$out"
MC="$T/meta-custom"; mkdir -p "$MC" && cd "$MC" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && git add -A && git commit -qm init && $J init --meta --no-hooks --genres a,b >/dev/null
msg="meta docs: --genres puts docs/**/*.md in entry_files, so pararepos cite the pages"
expect_pass python3 -c "import json; assert 'docs/**/*.md' in json.load(open('$MG/.jig/meta.json'))['entry_files']"
msg="meta docs: --genres a,b writes those two, each a ## heading"
expect_pass sh -c "python3 -c \"import json; assert json.load(open('.jig/meta.json'))['genres'] == ['a', 'b']\" && grep -qx '## a' docs/glossary.md && grep -qx '## b' docs/glossary.md"

CR="$T/meta-docs-code"; pcnew "$CR" && git add -A && git commit -qm init && $J init >/dev/null
mkdir -p docs/products && printf '# products\n\nProducts is a system.\n\n## Undefined\n' > docs/products.md
printf '# x\n\nX is a part of products.\n\n## Undefined\n' > docs/products/x.md && git add -A
msg="meta docs: in a code repo, docs/products/x.md is still part x of system products"
expect_pass sh -c "python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert not r['homeless'] and r['genres'] is None, r['homeless']\" && ! $J survey | grep -q 'genre'"
}

# ---------------------------------------------------------------- the glossary in docs/
# A repo's terms are docs/glossary.md, headings or a table; docs point only at docs, so update
# moves a README glossary or a root GLOSSARY.md there and rewrites what points at the old home.
sec_glossary() {
gs() { python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
h = {e['path']: e for e in r['homeless']}
$1"; }
nohook() { git -c core.hooksPath=/dev/null commit -qm "$1"; }   # what a repo held before the rule

GR="$T/gl-readme"; pcnew "$GR" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '# App\n\nIntro.\n\n## Glossary\n\n### mote\nA speck, `x`.\n\n#### usage\nrare\n\n### seam\n\nA join — see mote.\n\n## Use\n\nrun it\n' > README.md
mkdir -p docs && printf '# A\n\nThe a system.\n\nMade of motes (README.md § mote).\n\nThe [glossary](../GLOSSARY.md) says so.\n\nGone: README.md § gone.\n' > docs/a.md
git add -A && nohook pages
msg="glossary: update lists a README glossary under Repo files to review, bound for docs/glossary.md"
out=$($J update 2>&1)
expect_pass sh -c "echo \"\$0\" | sed -n '/^Repo files to review/,/^\$/p' | grep -q '^  README.md: the glossary.s home is docs/glossary.md'" "$out"
msg="glossary: the dry run lists both pointer lines it rewrites, lists README.md § gone as left, and changes nothing"
out=$($J update --glossary 2>&1)
expect_pass sh -c "echo \"\$0\" | sed -n '/^Pointers rewritten/,/^Pointers left/p' | grep -q '^  docs/a.md:5: ' && echo \"\$0\" | sed -n '/^Pointers rewritten/,/^Pointers left/p' | grep -q '^  docs/a.md:7: ' && echo \"\$0\" | sed -n '/^Pointers left/,\$p' | grep -q '^  docs/a.md:9: README.md § gone: names no glossary term' && test -z \"\$(git status --porcelain)\" && test ! -e docs/glossary.md" "$out"
$J update --apply --glossary >/dev/null 2>&1
msg="glossary: --apply --glossary writes each ### term as a ## heading, its text byte for byte, and removes the README section"
expect_pass sh -c "test \"\$(cat docs/glossary.md)\" = \"\$(printf '# Glossary\n\n## mote\nA speck, \`x\`.\n\n### usage\nrare\n\n## seam\n\nA join — see mote.')\" && ! grep -q Glossary README.md && grep -qx 'run it' README.md"
msg="glossary: and rewrites README.md § mote to docs/glossary.md § mote and the GLOSSARY.md link, leaving README.md § gone"
expect_pass sh -c "sed -n 5p docs/a.md | grep -qF '(docs/glossary.md § mote)' && sed -n 7p docs/a.md | grep -qF '[glossary](glossary.md)' && sed -n 9p docs/a.md | grep -qF 'README.md § gone'"
msg="glossary: the move commits through the hook, and survey then has no glossary finding"
expect_pass sh -c "git commit -qm 'glossary: to docs/' && python3 -c \"
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
assert not r['readme_glossary'] and r['glossary_terms'] == ['mote', 'seam'] and not r['glossary_unheaded'], r\""

GG="$T/gl-file"; pcnew "$GG" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '# Glossary\n\nOur words.\n\n**grain** — wood, not sand\n\n## mote\nA speck.\n' > GLOSSARY.md && git add -A && git commit -qm glossary
$J update --apply --glossary >/dev/null 2>&1
msg="glossary: a root GLOSSARY.md folds into docs/glossary.md, a bold term gaining a heading, its text unchanged"
expect_pass sh -c "test ! -e GLOSSARY.md && test \"\$(cat docs/glossary.md)\" = \"\$(printf '# Glossary\n\nOur words.\n\n## grain\n\n**grain** — wood, not sand\n\n## mote\nA speck.')\""

GT="$T/gl-table"; pcnew "$GT" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '# App\n\n## Glossary\n\nThe words we use.\n\n| Term | Means | Owner |\n|---|---|---|\n| `mote` | a speck | ann |\n| **seam** | a join, not a weld | bo |\n' > README.md && git add -A && git commit -qm glossary
$J update --apply --glossary >/dev/null 2>&1
msg="glossary: a README glossary written as a table moves as the same table, rows byte for byte"
expect_pass sh -c "sed -n '/^| Term/,\$p' docs/glossary.md > ../gt.new && sed -n '/^| Term/,\$p' README.md | wc -l | grep -q '^ *0' && printf '| Term | Means | Owner |\n|---|---|---|\n| \`mote\` | a speck | ann |\n| **seam** | a join, not a weld | bo |\n' | cmp -s - ../gt.new"

GD="$T/gl-there"; pcnew "$GD" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs && printf '# Glossary\n\n| Term | Means |\n|---|---|\n| `mote` | a speck |\n| seam | a join |\n' > docs/glossary.md
printf '# App\n\nSee [the glossary](docs/glossary.md).\n' > README.md && git add -A && git commit -qm glossary
msg="glossary: a repo on a table docs/glossary.md gets no glossary finding from survey, and the readers list its first column"
expect_pass gs "assert not r['readme_glossary'] and not r['glossary_unheaded'] and 'docs/glossary.md' not in h and not [e for e in r['page_contract'] if e['path'] == 'docs/glossary.md'] and r['glossary_terms'] == ['mote', 'seam'], r"
msg="glossary: nor from update, whose --glossary has nothing to move"
expect_pass sh -c "! $J update 2>&1 | grep -qi glossary && $J update --glossary 2>&1 | grep -q 'nothing to move'"
msg="glossary hook: an added page line naming README.md § x is refused, naming the line"
printf '# B\n\nThe b system.\n\nSee README.md § mote.\n' > docs/b.md && git add -A
out=$(git commit -qm b 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/b.md line 5 names README.md, a root document'" "$out"
msg="glossary hook: so is one naming AGENTS.md, and one in the decision log"
printf '# B\n\nThe b system.\n\nAgents read AGENTS.md.\n' > docs/b.md && git add -A; rc1=$(code git commit -qm b); undo
ulog '- see CLAUDE.md' && git add -A; rc2=$(code git commit -qm log); undo
expect_pass test "$rc1" != 0 -a "$rc2" != 0
msg="glossary hook: a page line naming docs/glossary.md § mote, or another repo's README, passes"
printf '# B\n\nThe b system, made of motes (docs/glossary.md § mote), as app/README.md says.\n' > docs/b.md && git add -A
expect_pass git commit -qm b
msg="glossary: survey lists a page's prose naming the root README, which the hook can't judge"
printf '\nListed in the root README.\n' >> docs/b.md && git add -A && git commit -qm prose
expect_pass gs "assert [e['lines'] for e in r['root_docs_named'] if e['path'] == 'docs/b.md'] == [[[5, 'Listed in the root README.']]], r['root_docs_named']"

GM="$T/gl-meta"; pcnew "$GM" && git add -A && git commit -qm init && $J init --meta --name gm --genres a,b >/dev/null 2>&1 && git add -A && git commit -qm meta-init && $J release >/dev/null
msg="glossary meta: init --meta seeds docs/glossary.md with a ## heading per genre, and entry_files has no README.md"
expect_pass sh -c "grep -qx '## a' docs/glossary.md && grep -qx '## b' docs/glossary.md && ! grep -q '\"README.md\"' .jig/meta.json"
msg="glossary meta: survey doesn't hold docs/glossary.md to the page contract or call it a stray in docs/, and names a bold term in it"
git switch -q -c t && printf '\n**grain** — wood\n' >> docs/glossary.md
expect_pass gs "assert 'docs/glossary.md' not in h and not [e for e in r['page_contract'] if e['path'] == 'docs/glossary.md'] and r['glossary_unheaded'] == ['grain'], (h, r['page_contract'], r['glossary_unheaded'])"
git checkout -q -- docs/glossary.md
msg="glossary meta: a README prose change needs no log line"
printf '# gm\n\nWhat this ecosystem is.\n' > README.md && git add -A
expect_pass git commit -qm "README: intro"
msg="glossary meta: a glossary term change does"
printf '\n## c\n\nA third.\n' >> docs/glossary.md && git add -A
expect_refuse git commit -qm "GLOSSARY: c"
msg="glossary meta: and passes with its log line"
ulog '- GLOSSARY: c' && git add -A
expect_pass git commit -qm "GLOSSARY: c"
git switch -q main

# A metarepo on the old home, a pararepo citing it, and the release that moves it.
GO="$T/gl-old"; pcnew "$GO" && git add -A && git commit -qm init && $J init --meta --name go >/dev/null 2>&1
rm -r docs && setentry .jig/decisions.md README.md
printf '# go\n\n## Glossary\n\n### mote\nA speck.\n\n### seam\nA join.\n' > README.md && git add -A && nohook "meta-init" && $J release >/dev/null
GP="$T/gl-para"; pcnew "$GP" && mkdir -p api && printf 'x=1\n' > api/a.py && printf 'Each mote: `go/README.md § mote`.\n' > api/notes.md \
  && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para go --location "$GO" >/dev/null 2>&1 && git add -A && git commit -qm "init --para"
cd "$GO"
msg="glossary meta: --apply --glossary on the metarepo's trunk is refused: the move is a job's (M4)"
expect_pass sh -c "test \$($J update --apply --glossary >/dev/null 2>&1; echo \$?) = 2 && test -z \"\$(git status --porcelain)\""
git switch -q -c mv >/dev/null 2>&1 && $J update --apply --glossary >/dev/null 2>&1
msg="glossary meta: on a branch the move rewrites entry_files in the same change"
expect_pass sh -c "git diff --cached --name-only | grep -qx .jig/meta.json && python3 -c \"import json; e = json.load(open('.jig/meta.json'))['entry_files']; assert 'README.md' not in e and 'docs/glossary.md' in e, e\""
ulog '- GLOSSARY: moved to docs/glossary.md' && git add -A && git commit -qm "GLOSSARY: move to docs/" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit mv && $J release >/dev/null
cd "$GP" && out=$($J sync 2>&1)
msg="glossary meta: a release across the move reports each term as moved, not removed"
expect_pass sh -c "echo \"\$0\" | grep -q '^  mote (moved: README.md § mote → docs/glossary.md § mote): used in api/notes.md' && echo \"\$0\" | grep -q '^  seam (moved: ' && ! echo \"\$0\" | grep -q '^  mote: '" "$out"
setjson .jig/para.json pin v0.2.0 && $J init --para >/dev/null 2>&1 && git add -A && git commit -qm "meta: go v0.1.0 → v0.2.0"
msg="glossary meta: at the pin bump, the pararepo's go/README.md § mote is named with its new home"
out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -qF 'api/notes.md:1 cites go/README.md § mote, which go v0.2.0 doesn'\''t have: now \`go/docs/glossary.md § mote\`'" "$out"
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
PG="$T/page-contract"; pcnew "$PG" && mkdir -p src docs/ui .jig/specs && printf 'x = 1\n' > src/ui.py
printf '# UI\n\nThe UI draws the list.\n\n## Renderer\n\nDraws rows.\n\n## Invariants\n\n- Rows are at least 44px — touch-target minimum; held by test_touch_targets.\n' > docs/ui/ui.md
git add -A && git commit -qm init && $J init >/dev/null && board "b['docmap'] = {'docs/ui/ui.md': ['src/ui.py'], 'docs/ui/list.md': ['src/list.py']}" && git add -A && git commit -qm board
mkdir -p docs/ui && printf '# Radio\n\nRadio links.\n' > docs/radio.md && printf '# Other\n\nOther is.\n' > docs/other.md && printf '# List\n\nThe list part.\n' > docs/ui/list.md && printf 'y = 1\n' > src/list.py
printf '# Roadmap\n\n## alpha\nScopes:\n- `screen`: the panel (touches docs/ui/ui.md)\n- `radio`: the link (touches docs/radio.md)\n\n## Up next\n- `offline`: Offline mode; stops at the cache layer; parked 2026-11-01 (touches docs/ui/ui.md)\n- `dark`: Dark theme; stops at the palette; parked 2026-11-02 (touches docs/ui.md, docs/other.md)\n- `export`: Export; parked 2026-11-03 (touches docs/other.md)\n' > .jig/roadmap.md
printf '# t\n\nSource: smoke\nScope: alpha/screen\n\n## Intent\nx\n' > .jig/specs/t.md
msg="up next: a roadmap with ## Up next parses, Up next is no phase, and an item names its pages"
git add -A && expect_pass git commit -qm roadmap
msg="up next: jig roadmap lists Up next apart from the phases, each item with its pages"
expect_pass sh -c "$J roadmap | grep -q '^Up next' && ! $J roadmap | grep -q '^Up next  current' && $J roadmap | grep -q 'offline.*touches docs/ui/ui.md'"
msg="up next: ROADMAP.md shows Up next after the phases, each item with its pages"
$J roadmap --write >/dev/null
expect_pass python3 -c "
t = open('ROADMAP.md').read(); u = t.split('## Up next')[1]
assert t.index('## alpha') < t.index('## Up next'), t
assert '**offline**: Offline mode' in u and '[docs/ui/ui.md](docs/ui/ui.md)' in u and '**export**' in u, u"
git add -A && git commit -qm view
msg="up next: jig reading-list prints the Up next items and open scopes naming each page"
out=$($J reading-list src/ui.py)
expect_pass sh -c "echo \"\$0\" | grep -q 'up next .offline.: Offline mode' && echo \"\$0\" | grep -q 'up next .dark.' && echo \"\$0\" | grep -q 'scope .alpha/screen.' && ! echo \"\$0\" | grep -q 'export\|radio'" "$out"
rbad() { printf "$1" > .jig/roadmap.md && git add -A; out=$(git commit -qm bad 2>&1); rc=$?; git reset -q --hard; }
msg="up next: reading-list prints a parent page's items when a child's file is read, in either order"
o1=$($J reading-list src/list.py); o2=$($J reading-list src/list.py src/ui.py); o3=$($J reading-list src/ui.py src/list.py)
expect_pass sh -c "for o in \"\$0\" \"\$1\" \"\$2\"; do echo \"\$o\" | grep -A3 '^  docs/ui/ui.md' | grep -q 'up next .offline.' || exit 1; done" "$o1" "$o2" "$o3"
msg="up next: the hook refuses an Up next item that names no page, by line"
rbad '## Up next\n- `x`: parked work\n'
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'line 2: Up next item x names no page'" "$out"
$J open U1 --spec .jig/specs/t.md --owns 'src/**' 'docs/ui/**' >/dev/null && git add -A && git commit -qm "open U1"
cd .git/jig/worktrees/U1 && printf 'x = 2\n' > src/ui.py && git commit -qam change && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/U1-*.md)
msg="up next: the handoff writes one fold-in line per Up next item or taken scope naming a covering page, in either form"
expect_pass sh -c "grep -qF -- '- [ ] Up next \`offline\` (docs/ui/ui.md): \"Offline mode; stops at the cache layer; parked 2026-11-01\" — built / untouched / departed: ___' $note && grep -qF -- '- [ ] Up next \`dark\` (docs/ui/ui.md)' $note && grep -qF -- '- [ ] Scope \`alpha/screen\` (docs/ui/ui.md): \"the panel\"' $note && ! grep -q 'export\|radio' $note"
answer $note "n = n.replace('- [ ] docs/ui/ui.md — updated / no change because ___', '- [x] docs/ui/ui.md — no change because the renderer still draws rows')"
git add -A && git commit -qm "note"
msg="up next: the gate refuses while an item line is blank"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'unanswered' && echo \"\$0\" | grep -q 'Up next .offline.' && ! echo \"\$0\" | grep -q 'no change because ___'" "$out"
answer $note "import re; n = re.sub(r'- \[ \] (Up next .offline.*) — built / untouched / departed: ___', r'- [x] \1 — Untouched (not this task)', n); n = re.sub(r'- \[ \] (Up next .dark.*) — built / untouched / departed: ___', r'- [x] \1 — departed: themes moved to the OS setting', n); n = re.sub(r'- \[ \] (Scope .*) — built / untouched / departed: ___', r'- [x] \1 — built', n)"
git commit -qam "answer"
msg="up next: the gate passes untouched, departed and built answers, with text after them, in any case"
expect_pass sh -c "cd '$PG' && $(declare -f gate_ok); J='$J'; gate_ok U1"
answer $note "n = n.replace('— Untouched (not this task)', '— built / untouched')"
git commit -qam "two answers"
msg="up next: the gate refuses a line that keeps more than one answer, and says so"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'more than one answer kept'" "$out"
answer $note "n = n.replace('— built / untouched', '— departed')"
git commit -qam "bare departed"
msg="up next: the gate refuses departed with no why"
out=$(cd "$PG" && { gate_ok U1; rc=$?; echo "$out"; exit $rc; }); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'departed needs its why'" "$out"
answer $note "n = n.replace('(touches', '(touches').replace('parked 2026-11-01\" — departed', 'parked 2026-11-01\" — built: the cache serves offline')"
git commit -qam "offline built"
cd "$PG" && $J merge U1 >/dev/null 2>&1
msg="up next: jig merge removes the item answered built from .jig/roadmap.md in the merge commit, and keeps the rest"
expect_pass sh -c "git show --name-only --format= HEAD | grep -qx .jig/roadmap.md && ! grep -q offline .jig/roadmap.md && grep -q '\`dark\`' .jig/roadmap.md && grep -q '\`export\`' .jig/roadmap.md"
msg="up next: and ROADMAP.md, rewritten in the same commit, no longer shows it"
expect_pass sh -c "! git show HEAD:ROADMAP.md | grep -q offline && git show HEAD:ROADMAP.md | grep -q '\*\*dark\*\*' && test -z \"\$(git status --porcelain)\""

mkdir -p docs/old docs/inv docs/after docs/nolead docs/misc
printf '# Old\n\n## Now\nx\n\n## Rules\n### 1.1 y\n\n## Checks\n- 1.1 review\n' > docs/old/old.md
printf '# Inv\n\nInv holds keys.\n\n## Invariants\n\n- Keys are sorted — lookups bisect; held by test_sorted.\n- Keys are short.\n- Keys are ASCII — the wire format.\n' > docs/inv/inv.md
printf '# After\n\nAfter does things.\n\n## Undefined\n\n- Sync — parked 2026-11-01.\n\n## Notes\n\nmore\n' > docs/after/after.md
printf '# Nolead\n\n## Part\n\nText.\n' > docs/nolead/nolead.md
printf '# Misc\n\nMisc is a part.\n\n## Invariants\n\n- A — b; held by review.\n' > docs/misc/x.md
# Planted: each page alone in its folder, which the hook refuses; only the contract is asked here.
git add -A && git -c core.hooksPath=/dev/null commit -qm pages
msg="page contract: survey flags an old-format page as old contract — convert"
expect_pass pc "assert len(c['docs/old/old.md']) == 1 and c['docs/old/old.md'][0].startswith('old contract — convert'), c"
msg="page contract: survey flags invariants missing a holder or a why, and passes the one with both"
expect_pass pc "p = c['docs/inv/inv.md']; assert len(p) == 2 and any('Keys are short.' in x for x in p) and any('Keys are ASCII' in x for x in p), p"
msg="page contract: survey flags a page with no lead paragraph; a page still carrying ## Undefined is in the contract otherwise"
expect_pass pc "assert any('no lead paragraph' in x for x in c['docs/nolead/nolead.md']), c
assert 'docs/after/after.md' not in c, c"
msg="page contract: a page in the contract and a misplaced page are not read against it"
expect_pass pc "assert not {'docs/ui/ui.md', 'docs/misc/x.md'} & set(c), c"
msg="page contract: a misplaced page with an Invariants section is a page, given its home"
expect_pass pc "assert h['docs/misc/x.md']['kind'] == 'page' and h['docs/misc/x.md']['to'] == 'docs/x.md', h"
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
msg="up next: a solo commit on trunk changing a page an Up next item names gets its line"
mkdir -p src docs/s && printf 'x = 1\n' > src/s.py && printf '# S\n\nS is.\n' > docs/s/s.md
printf '## Up next\n- `sync`: Sync; parked 2026-11-01 (touches docs/s.md)\n' > .jig/roadmap.md
board "b['docmap'] = {'docs/s/s.md': ['src/**']}" && git add -A && git commit -qm s
printf 'x = 2\n' > src/s.py && git commit -qam "sync" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
expect_pass grep -qF 'Up next `sync` (docs/s/s.md): "Sync; parked 2026-11-01"' .jig/handoffs/main-*.md
msg="up next: solo on trunk, the gate refuses while an item answered built is still in the roadmap"
pcfold && sed -i.bak 's/ — built \/ untouched \/ departed: smoke/ — built: syncs/' .jig/handoffs/main-*.md && rm .jig/handoffs/*.bak && git add -A && git commit -qm "note s"
out=$($J gate 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'answers built for sync, still under ## Up next'" "$out"
msg="up next: once the item is deleted on trunk, the gate no longer asks"
printf '' > .jig/roadmap.md && git add -A && git commit -qm "sync built"
out=$($J gate 2>&1)
expect_pass sh -c "! echo \"\$0\" | grep -q 'still under ## Up next'" "$out"
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
git init -q --bare "$T/rm-meta-remote.git" && git remote add origin "$T/rm-meta-remote.git"
msg="roadmap: in a metarepo, pre-push passes that trunk commit of ROADMAP.md as M4 did"
expect_pass git push -q origin main
msg="roadmap: and release accepts it, and tags"
out=$(mrel); expect_pass sh -c "echo \"\$0\" | grep -q 'released v0.1.0' && git tag | grep -qx v0.1.0" "$out"
msg="roadmap: in a metarepo, dropping the roadmap and its view in one commit passes the hook and release"
git rm -q .jig/roadmap.md ROADMAP.md && expect_pass git commit -qm "GLOSSARY: drop roadmap"
out=$(mrel); expect_pass sh -c "! echo \"\$0\" | grep -q 'without a reviewed merge'" "$out"
msg="roadmap: in a metarepo with no roadmap at that commit, a ROADMAP.md commit made with hooks off is still refused by release"
printf 'hand\n' > ROADMAP.md && git add -A \
  && git -c core.hooksPath=/dev/null commit -qm "GLOSSARY: hand view" && c=$(git rev-parse --short=12 HEAD)
out=$(mrel); expect_pass sh -c "echo \"\$0\" | grep -q \"$c is on main without a reviewed merge\"" "$out"

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

# ---------------------------------------------------------------- project and product
sec_boundary() {
BD="$T/boundary"; pcnew "$BD" && mkdir -p docs src && printf 'x = 1\n' > src/a.py
printf '# A\n\nA keeps the list.\n' > docs/a.md && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '## phase-1\nScopes:\n- `screen`: the panel (touches docs/a.md)\n\n## 1\nScopes:\n- `screen`: x\n\n## v1\nScopes:\n- `api`: y\n' > .jig/roadmap.md && git add -A && git commit -qm roadmap
refused() { out=$(git commit -qm "$1" 2>&1); rc=$?; git reset -q --hard; }
msg="boundary: the hook refuses a page line naming a spec, with the line named"
printf 'Built as .jig/specs/x.md says.\n' >> docs/a.md && git add -A && refused spec
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/a.md line 4 names .jig/specs/, the project' && echo \"\$0\" | grep -q 'Built as .jig/specs/x.md says.'" "$out"
msg="boundary: the hook refuses a page line naming .jig/roadmap.md"
printf 'See .jig/roadmap.md.\n' >> docs/a.md && git add -A && refused roadmap
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'names .jig/roadmap.md'" "$out"
msg="boundary: the hook refuses a page line naming a scope id in code quotes"
printf 'The API came in `v1/api`.\n' >> docs/a.md && git add -A && refused scope
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/a.md line 4 names .v1/api.'" "$out"
msg="boundary: words that may be the product's pass: a quoted phase name, a bare scope id, ROADMAP.md"
printf 'Returns `1` on success. The v1/api endpoint answers. Values 1/screen are scaled. See ROADMAP.md.\n' >> docs/a.md && git add -A
expect_pass git commit -qm words
msg="boundary: the hook refuses a decision-log line naming a spec or a quoted scope"
ulog '- The panel ships, per .jig/specs/x.md.' && git add -A && refused log1
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '.jig/decisions.md line .* names .jig/specs/'" "$out"
ulog '- Demo priorities: `phase-1/screen`, then the rest.' && git add -A && refused log2
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q '.jig/decisions.md line .* names .phase-1/screen.'" "$out"
msg="boundary: the same references in a spec pass"
mkdir -p .jig/specs && printf '# y\n\nSource: smoke\nScope: phase-1/screen\n\nSee .jig/specs/x.md, ROADMAP.md, docs/a.md and `phase-1/screen`.\n' > .jig/specs/y.md && git add -A
expect_pass git commit -qm spec
msg="boundary: a git mv of a page holding an old spec path commits: its lines aren't new"
printf '# Old\n\nOld is.\n\nOnce cited .jig/specs/x.md.\n' > docs/old.md && git add -A && git -c core.hooksPath=/dev/null commit -qm planted
git mv docs/old.md docs/older.md && expect_pass git commit -qm moved
msg="boundary: survey lists plan prose, paths and scope ids on a page and in the log, and project headings"
printf '# B\n\nB is.\n\nThe gesture lands in phase 3, after spec step 6.\n\n## Status\n\nhalf done\n\n## Undefined\n\n- sync — parked 2026-11-01.\n' > docs/b.md
ulog '- Demo priorities: A in phase 2, then B.' && git add -A && git -c core.hooksPath=/dev/null commit -qm b
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
p = {e['path']: ' | '.join(e['problems']) for e in r['project_in_product']}
b = p['docs/b.md']
assert '\"phase 3\"' in b and '\"spec step 6\"' in b and '## Status is the project' in b and '## Undefined is the project' in b and 'Up next' in b, b
assert '\"v1/api\"' in p['docs/a.md'] and '\"ROADMAP.md\"' in p['docs/a.md'] and '\".jig/specs/\"' in p['docs/older.md'], p
assert '\"phase 2\"' in p['.jig/decisions.md'], p"
expect_pass sh -c "$J survey | grep -q '^  docs/b.md: ## Status is the project'"
msg="boundary: with the project in its pages, survey's verdict isn't nothing to do"
expect_pass sh -c "$J survey | tail -1 | grep -q 'move the project listed above'"
msg="boundary: a page still carrying ## Undefined is edited and committed as before"
printf '\nB keeps more.\n' >> docs/b.md && git add -A && expect_pass git commit -qm "b more"
msg="boundary: the hook refuses docs/roadmap.md, naming .jig/roadmap.md"
printf '# Plan\n' > docs/roadmap.md && git add -A && refused docroadmap
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'docs/roadmap.md is a roadmap among the product.s pages.*.jig/roadmap.md only'" "$out"
msg="boundary: on trunk the hook refuses a roadmap item touching a page that doesn't exist"
printf '\n## Up next\n- `gone`: parked; parked 2026-11-01 (touches docs/gone.md)\n' >> .jig/roadmap.md && git add -A && refused gone
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'gone touches docs/gone.md, which this commit leaves with no page'" "$out"
msg="boundary: on trunk the hook refuses renaming a touched page without re-pointing it, and passes when re-pointed"
git mv docs/a.md docs/c.md && refused rename
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'phase-1/screen touches docs/a.md'" "$out"
git mv docs/a.md docs/c.md && sed -i.bak 's|touches docs/a.md|touches docs/c.md|' .jig/roadmap.md && rm .jig/roadmap.md.bak && git add -A
expect_pass git commit -qm "a is c"
msg="boundary: jig roadmap reports a touched page that doesn't exist"
printf '\n## Up next\n- `gone`: parked; parked 2026-11-01 (touches docs/gone.md)\n' >> .jig/roadmap.md && git add -A && git -c core.hooksPath=/dev/null commit -qm planted
out=$($J roadmap 2>&1); rc=$?; git reset -q --hard HEAD~1
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q 'gone touches docs/gone.md, which main has no page for'" "$out"
msg="boundary: jig merge re-points a page the job moved in every (touches …) naming it"
$J open M --spec .jig/specs/y.md --owns 'docs/**' >/dev/null && git add -A && git commit -qm "open M"
( cd .git/jig/worktrees/M && git mv docs/c.md docs/d.md && git commit -qm move && $J reviewed >/dev/null \
  && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note M" )
$J merge M >/dev/null 2>&1
expect_pass sh -c "grep -q 'touches docs/d.md' .jig/roadmap.md && git show --name-only --format= HEAD | grep -qx .jig/roadmap.md"

BM="$T/boundary-meta"; mkdir -p "$BM" && cd "$BM" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init --meta >/dev/null 2>&1 && git add -A && git commit -qm "GLOSSARY: board"
setentry .jig/decisions.md README.md 'products/**' ROADMAP.md && git add -A && git commit -qm "GLOSSARY: entry files"
msg="boundary: in a metarepo, the hook refuses products/roadmap.md when entry_files match it"
mkdir -p products && printf '# Plan\n' > products/roadmap.md && git add -A && refused "GLOSSARY: plan"
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'products/roadmap.md is a roadmap.*.jig/roadmap.md only'" "$out"
msg="boundary: in a metarepo with no .jig/roadmap.md, a root ROADMAP.md entry_files match is refused too"
printf '# Plan\n' > ROADMAP.md && git add -A && refused "GLOSSARY: plan"
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'ROADMAP.md is a roadmap'" "$out"
msg="boundary: in a metarepo, an entry file outside docs/ naming a spec is refused"
mkdir -p products && printf '# X\n\nSee .jig/specs/x.md.\n' > products/x.md && git add -A && refused "GLOSSARY: x"
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'products/x.md line 3 names .jig/specs/'" "$out"
msg="boundary: in a metarepo, changing .jig/roadmap.md on trunk asks for no log line (M3)"
mkdir -p docs/g && printf "# A\\n\\nA is.\\n" > docs/g/a.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "GLOSSARY: a"
printf '## Up next\n- `x`: parked; parked 2026-11-01 (touches docs/g/a.md)\n' > .jig/roadmap.md && git add -A
out=$(git commit -qm "GLOSSARY: roadmap" 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! echo \"\$0\" | grep -q M3" "$out"
}

# ---------------------------------------------------------------- the decision log, in a plain repo
sec_decisions() {
DL="$T/dl"; pcnew "$DL" && git add -A && git commit -qm init && $J init >/dev/null
msg="decisions: init writes .jig/decisions.md with its preamble, ## Open and ## Unreleased"
expect_pass sh -c "grep -q 'Keep a Changelog' .jig/decisions.md && grep -q 'Semantic Versioning' .jig/decisions.md && grep -qx '## Open' .jig/decisions.md && grep -qx '## Unreleased' .jig/decisions.md"
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release']['artifacts'] = ['dist/*.zip']" && printf 'dist/\n' > .gitignore
ulog '### D-001 ids are numbers
Accepted (owner, 2026-11-01).
Touches: docs/shared.md'
git add -A && git commit -qm "board, D-001"
msg="decisions: release --minor in a plain repo makes v0.1.0, names Unreleased for it, and adds an empty Unreleased above"
day=$(date +%F); out=$($J release --minor 2>&1)
expect_pass sh -c "git tag | grep -qx v0.1.0 && grep -A2 '^## Unreleased\$' .jig/decisions.md | grep -qx '## v0.1.0 - $day' && git show v0.1.0:.jig/decisions.md | grep -A3 '^## v0.1.0 - ' | grep -qx '### D-001 ids are numbers'" "$out"
msg="decisions M2: a status in the heading is refused"
expect_refuse m2 '### D-002 Ports stay closed (Accepted)
Accepted (owner, 2026-11-02).
Touches: docs/shared.md'
msg="decisions M2: an entry with no status line is refused"
expect_refuse m2 '### D-002 ports stay closed'
msg="decisions M2: a supersedes link to no entry is refused"
expect_refuse m2 '### D-002 ports stay closed
Accepted (owner, 2026-11-02). Supersedes D-009.
Touches: docs/shared.md'
msg="decisions M2: an open entry under a release heading is refused, as M2"
ulog '### D-002 which port?
Open (2026-11-02).
Touches: docs/shared.md' "v0.1.0 - $day" && git add -A; out=$($J check --staged 2>&1); git reset -q; git checkout -q -- .jig/decisions.md
expect_pass sh -c "echo \"\$0\" | grep -q 'M2 .*D-002 is open: release v0.1.0 holds accepted entries only'" "$out"
msg="decisions: a commit editing a line under ## v0.1.0 is refused"
sed -i.bak 's/^### D-001 ids are numbers$/### D-001 ids are strings/' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm edit 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
msg="decisions: adding [YANKED] to the heading and one line under it is accepted"
python3 -c "import re; f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(re.sub(r'^(## v0\.1\.0 - \S+)$', r'\1 [YANKED]\n\nIds broke; pin v0.2.0.', s, flags=re.M))"
git add -A; expect_pass git commit -qm yank
msg="decisions: a second line under a yanked release is refused"
python3 -c "f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(s.replace('pin v0.2.0.\n', 'pin v0.2.0.\nAlso this.\n', 1))"
git add -A; expect_refuse git commit -qm more; undo
ulog '### D-002 ids are strings
Accepted (owner, 2026-11-03). Supersedes D-001.
Touches: docs/shared.md' && git add -A && git commit -qm "D-002: strings"
msg="decisions: jig decision D-001 prints the entry and names the one that supersedes it"
out=$($J decision D-001 2>&1); expect_pass sh -c "echo \"\$0\" | grep -qx '### D-001 ids are numbers' && echo \"\$0\" | grep -q 'D-001 is superseded by D-002'" "$out"
mkdir -p docs/store && printf '# Store\n\nThe store.\n' > docs/store/store.md && git add -A && git commit -qm "docs: store"
$J open st >/dev/null && git add -A && git commit -qm "open st"
cd .git/jig/worktrees/st
ulog '### D-?store-ro the store opens read-only
Accepted (owner, 2026-11-04).
Touches: docs/shared.md' && printf '\nIt opens read-only (D-?store-ro).\n' >> docs/store/store.md \
  && printf 'A placeholder shape, D-?not-an-entry, with no entry.\n' > docs/store/notes.md && git add -A
msg="decisions: a job opened with no --shares commits an entry D-?store-ro and a page citing it"
expect_pass git commit -qm "D-?store-ro: read-only"
msg="decisions: the same job editing a released line is refused"
sed -i.bak 's/^Ids broke; pin v0.2.0\.$/Ids broke./' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A; expect_refuse git commit -qm edit; undo
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note st" && cd "$DL"
msg="decisions: jig merge numbers it D-003, in the log and the page, in the merge commit"
out=$($J merge st 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'numbered D-?store-ro → D-003' && git show HEAD:.jig/decisions.md | grep -qx '### D-003 the store opens read-only' && git show HEAD:docs/store/store.md | grep -q '(D-003)' && ! grep -rq 'D-?store-ro' .jig/decisions.md docs && test \"\$(git log -1 --format=%P | wc -w | tr -d ' ')\" = 2 && test -z \"\$(git status --porcelain)\"" "$out"
msg="decisions: the merge commit's message lists each number it gave"
expect_pass sh -c "git log -1 --format=%B | grep -q 'Numbered: D-?store-ro → D-003'"
msg="decisions: text shaped like a placeholder with no entry behind it is left as it is"
expect_pass grep -q 'D-?not-an-entry' docs/store/notes.md

# A conflicted merge: the hint names jig merge --number, and trunk refuses an unnumbered id.
$J open cf >/dev/null && git add -A && git commit -qm "open cf"
(cd .git/jig/worktrees/cf && ulog '### D-?cache-off the cache is off
Accepted (owner, 2026-11-05).
Touches: docs/shared.md' && printf '# Store\n\nThe store, uncached (D-?cache-off).\n' > docs/store/store.md && git add -A \
  && git commit -qm "D-?cache-off: off" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note cf")
printf '# Store\n\nThe store, on trunk.\n' > docs/store/store.md && git add -A && git commit -qm "docs: trunk edit"
out=$($J merge cf 2>&1)
msg="decisions: a conflicted merge's hint names jig merge --number before the commit"
expect_pass sh -c "echo \"\$0\" | grep -q 'jig merge --number'" "$out"
printf '# Store\n\nThe store, on trunk, uncached (D-?cache-off).\n' > docs/store/store.md && git add -A
msg="decisions: committing that merge with the id unnumbered is refused on trunk, naming jig merge --number"
out=$(git commit -q --no-edit 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q \"D-?cache-off isn't numbered\"" "$out"
msg="decisions: jig merge --number numbers it in the log and the resolved page, and the commit passes"
out=$($J merge --number 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'D-?cache-off → D-004' && grep -qx '### D-004 the cache is off' .jig/decisions.md && grep -q '(D-004)' docs/store/store.md && git commit -q --no-edit && git log -1 --format=%B | grep -q 'Numbered: D-?cache-off → D-004'" "$out"
msg="decisions: jig release refuses an unnumbered id in the log"
ulog '### D-?late x
Accepted (owner, 2026-11-06).
Touches: docs/shared.md' && git add -A && git -c core.hooksPath=/dev/null commit -qm "late, hooks off"
out=$($J release --minor 2>&1); expect_pass sh -c "! git tag | grep -qx v0.2.0 && echo \"\$0\" | grep -q \"D-?late isn't numbered\"" "$out"
git reset -q --hard HEAD~1

# A metarepo set up before the log keeps its CHANGELOG.md and register until jig update moves them.
OM="$T/old-meta"; mkdir -p "$OM/.t" && git -C "$JR" archive v0.9.0 plugin/templates | tar -x -C "$OM/.t"
cd "$OM" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r .t/plugin/templates/jig .jig && cp .t/plugin/templates/AGENTS.md .t/plugin/templates/CLAUDE.md . && rm -rf .t
git add -A && git commit -qm init && $J init --meta --name om >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
cp "$P/jig/jig.py" .jig/jig.py && git add -A && git commit -qm "TOOL: this jig"
$J open o1 --shares DECISIONS.md >/dev/null && git add -A && git commit -qm "TOOL: open o1"
cd .git/jig/worktrees/o1
msg="old shape: M2 still checks a register row"
printf '| D-001 | ids |\n' >> DECISIONS.md && printf -- '- D-001\n' >> CHANGELOG.md && git add -A; expect_refuse git commit -qm "D-001: ids"; undo
msg="old shape: M3 still asks for a CHANGELOG.md line"
printf '| D-001 | ids | accepted | 2026-11-01 |\n' >> DECISIONS.md && git add -A; out=$(git commit -qm "D-001: ids" 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'M3 DECISIONS.md changed: add a line to CHANGELOG.md'" "$out"
msg="old shape: a job adds its row and its CHANGELOG.md line, R3 letting it add the line"
printf '| D-001 | ids | accepted | 2026-11-01 |\n' >> DECISIONS.md && printf -- '- D-001\n' >> CHANGELOG.md && git add -A
expect_pass git commit -qm "D-001: ids"
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note o1" && cd "$OM"
msg="old shape: it merges, and the release writes CHANGELOG.md's heading and no log"
$J merge o1 >/dev/null 2>&1; out=$($J release 2>&1)
expect_pass sh -c "git tag | grep -qx v0.2.0 && grep -q '^## v0.2.0 — ' CHANGELOG.md && test ! -e .jig/decisions.md && test -z \"\$(git status --porcelain)\"" "$out"

# The migration: jig update lists both old files, changes nothing without a yes, and merges on one.
board "b['reserve'] = {'decision': {'pattern': r'^\|\s*D-(\d+)\s*\|', 'files': ['DECISIONS.md']}}" && git add -A && git commit -qm "TOOL: decision counter"
git switch -q -c rows && printf '| D-002 | which wire format? | proposed (Ann) | 2026-11-02 |\n| D-003 | use XML | rejected | 2026-11-02 |\n\nSource for D-002: the wire thread.\n' >> DECISIONS.md \
  && printf -- '- D-002, D-003\n' >> CHANGELOG.md && printf '\nDecisions: DECISIONS.md.\n' >> README.md && git add -A && git commit -qm "D-002, D-003: rows" && $J reviewed >/dev/null \
  && git switch -q main && git merge -q --no-ff --no-edit rows
msg="old shape: a branch adding a .jig/decisions.md doesn't switch the old M2 off"
git switch -q -c sneak && printf '| D-009 | x | maybe | 2026-11-02 |\n' >> DECISIONS.md && printf -- '- D-009\n' >> CHANGELOG.md && printf '# log\n' > .jig/decisions.md && git add -A
expect_refuse git commit -qm "D-009: x"; undo; git switch -q main && git branch -qD sneak
git worktree remove --force .git/jig/worktrees/o1
# A pararepo pinned before the migration, to read the bump across it.
PA="$T/old-para"; pcnew "$PA" && mkdir -p api && printf 'x=1\n' > api/a.py && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
$J init --para om --location "$OM" --contract 'api/**' >/dev/null 2>&1 && git add -A && git commit -qm "init --para"; cd "$OM"
UP="python3 $P/jig/jig.py update"
oldfiles() { git status --porcelain; shasum CHANGELOG.md DECISIONS.md .jig/meta.json .jig/config.json 2>/dev/null; ls .jig; }
before=$(oldfiles); out=$($UP 2>&1); after=$(oldfiles)
msg="migration: update's dry run lists CHANGELOG.md and DECISIONS.md under Repo files to review, naming --merge-log, and changes nothing"
expect_pass sh -c "echo \"\$0\" | grep -q '^  CHANGELOG.md: .*--merge-log' && echo \"\$0\" | grep -q '^  DECISIONS.md: a decision register, 3 rows' && test \"\$1\" = \"\$2\"" "$out" "$before" "$after"
msg="migration: --apply without --merge-log leaves both old files, and writes no log"
$UP --apply >/dev/null 2>&1; expect_pass sh -c "test -f CHANGELOG.md && test -f DECISIONS.md && test ! -e .jig/decisions.md"
git add -A && git commit -qm "TOOL: update" >/dev/null 2>&1
before=$(oldfiles); out=$($UP --merge-log 2>&1); after=$(oldfiles)
msg="migration: --merge-log alone shows the log, the rejected id kept taken, what names the old files, and on a metarepo's trunk names a job, changing nothing"
expect_pass sh -c "echo \"\$0\" | grep -qx '## v0.2.0 - [0-9-]*' && echo \"\$0\" | grep -q 'D-003: rejected, left out' && echo \"\$0\" | grep -q 'repoint what names the old files: README.md' && echo \"\$0\" | grep -q 'jig open merge-log' && test \"\$1\" = \"\$2\"" "$out" "$before" "$after"
msg="migration: on a metarepo's trunk --apply --merge-log is refused, naming a job, and writes nothing"
before=$(oldfiles); out=$($UP --apply --merge-log 2>&1); rc=$?; after=$(oldfiles)
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'M4' && echo \"\$0\" | grep -q 'jig open' && test \"\$1\" = \"\$2\"" "$out" "$before" "$after"
$J open ml --shares CHANGELOG.md DECISIONS.md README.md >/dev/null && git add -A && git commit -qm "TOOL: open ml"
cd .git/jig/worktrees/ml
msg="migration: in the job's worktree --apply --merge-log writes the log, removes both files and rewrites entry_files, leaving the board for trunk"
out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "test ! -e CHANGELOG.md && test ! -e DECISIONS.md && git diff --cached --quiet -- .jig/config.json && echo \"\$0\" | grep -q 'on main, after the merge' && python3 -c \"import json; e=json.load(open('.jig/meta.json'))['entry_files']; assert e[0]=='.jig/decisions.md' and 'DECISIONS.md' not in e, e\"" "$out"
msg="migration: releases keep their lines, re-headed; rows land by status; a note naming one id joins its entry; the proposer is kept"
expect_pass sh -c "sed -n '/^## v0.1.0 - /,\$p' .jig/decisions.md | grep -qx '### D-001 ids' && sed -n '/^## v0.1.0 - /,\$p' .jig/decisions.md | grep -qx -- '- D-001' && grep -qx '## v0.2.0 - [0-9-]*' .jig/decisions.md && sed -n '/^## Open/,/^## Unreleased/p' .jig/decisions.md | grep -qx '### D-002 which wire format?' && grep -qx 'Proposed (Ann, 2026-11-02).' .jig/decisions.md && sed -n '/^### D-002/,/^## Unreleased/p' .jig/decisions.md | grep -qx 'Source for D-002: the wire thread.' && ! grep -q '^### D-003' .jig/decisions.md && grep -q 'left out of it: D-003' .jig/decisions.md && grep -qx -- '- D-002, D-003' .jig/decisions.md && ! grep -q '^## .*—' .jig/decisions.md"
msg="migration: the job's commit of it passes, judged by the log's rules since it merges the old files away"
expect_pass git commit -qm "TOOL: merge the log"
# The branch is judged from where it left trunk: its own conversion isn't trunk's yet, so a
# later commit on it may correct what the first got wrong, as the squash would.
A=$(git rev-parse HEAD)
restate() { python3 -c "import re; f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(re.sub(r'(?m)^(### D-001 ids\n\w+ \()', r'\1owner, ', s, count=1))"; }
msg="branch log: a later commit on the job changing a status line in its converted release passes"
restate && git add -A; expect_pass git commit -qm "D-001: restated"; git reset -q --hard "$A"
msg="branch log: a later commit on the job adding ### Changed above its converted release's change line passes"
python3 -c "f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(s.replace('\n- D-002, D-003\n', '\n### Changed\n- D-002, D-003\n', 1))" && git add -A
expect_pass git commit -qm "TOOL: Changed above a release line"; git reset -q --hard "$A"
msg="branch log: a later commit on the job retitling a converted entry with no Touches line passes"
sed -i.bak 's/^### D-002 which wire format?$/### D-002 which wire format, then?/' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
expect_pass git commit -qm "D-002: retitled"; git reset -q --hard "$A"
msg="branch log: a new numbered entry with no Touches line on the converted branch is refused: only the register's ids are exempt"
ulog '### D-009 x
Accepted (owner, 2026-11-03).' && git add -A; out=$(git commit -qm "D-009: x" 2>&1); git reset -q --hard "$A"
expect_pass sh -c "echo \"\$0\" | grep -q 'D-009 names no page it touches'" "$out"
msg="branch log: reverting the conversion, staged and committed, passes with the counter on the register's rows"
git revert --no-commit HEAD && ck=$($J check 2>&1) && out=$(git commit -qm "TOOL: revert the log" 2>&1); rc=$?; git reset -q --hard "$A"
expect_pass sh -c "test $rc = 0" "$out"
msg="branch log: jig check on the reverted tree, unstaged, agrees with the hook"
expect_pass sh -c "test \"\$0\" = ok" "$ck"
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note ml" && cd "$OM"
msg="migration: the job merges into main, and --apply --merge-log there then rewrites only the board: append_files and the counter"
$J merge ml >/dev/null 2>&1; out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "git log -1 --format=%s | grep -qx 'merge ml' && python3 -c \"import json; c=json.load(open('.jig/config.json')); assert 'CHANGELOG.md' not in c['append_files'] and '.jig/decisions.md' in c['append_files'], c; assert c['reserve']['decision']['files']==['.jig/decisions.md'], c\" && git diff --cached --name-only | grep -qx .jig/config.json && git commit -qm 'TOOL: board after the log'" "$out"
msg="branch log: on trunk after the merge, the status-line edit is refused as frozen on main"
restate && git add -A; out=$(git commit -qm "D-001: restated" 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
msg="migration: afterwards a job's entry is numbered above the rejected D-003, the counter agreeing, and the release takes the history"
$J open o2 >/dev/null && git add -A && git commit -qm "TOOL: open o2"
(cd .git/jig/worktrees/o2 && ulog '### D-?cache cache off
Accepted (owner, 2026-11-03).
Touches: docs/shared.md' && git add -A && git commit -qm "D-?cache: off" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note o2")
$J merge o2 >/dev/null 2>&1; out=$($J release 2>&1)
expect_pass sh -c "git tag | grep -qx v0.3.0 && grep -qx '### D-004 cache off' .jig/decisions.md && grep -A2 '^## Unreleased\$' .jig/decisions.md | grep -q '^## v0.3.0 - ' && $J status | grep -qx 'reserve decision: next free 5'" "$out"
msg="migration: a second --merge-log has nothing to merge"
out=$($UP --merge-log 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'nothing to merge'" "$out"
msg="migration: a pararepo's bump across it reports the register's move on one line and only decisions new or changed since the pin (D-002, D-004), not D-001"
cd "$PA" && out=$($J sync 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'DECISIONS.md (now .jig/decisions.md)' && echo \"\$0\" | grep -q '^  D-004: ' && echo \"\$0\" | grep -q '^  D-002: ' && ! echo \"\$0\" | grep -q '^  D-001: '" "$out"

# A plain repo's own CHANGELOG.md and register, in Keep a Changelog's spelling, with words
# that have no place in the log.
PX="$T/old-plain"; pcnew "$PX"
printf '# Changelog\n\nOwner note: older history is in the wiki.\n\n## [Unreleased]\n- D-003 later\n\n## [1.0.0] - 2026-01-01\n- D-001–D-002 the first rules\n' > CHANGELOG.md
printf '# Decisions\n\n| # | Decision | Status | Binds | Date |\n|---|---|---|---|---|\n| D-001 | a | accepted (Ann) | api | 2026-01-01 |\n| D-002 | b | accepted (Ann) | api | 2026-01-01 |\n| D-003 | c | proposed (Bo) | ui | 2026-02-01 |\n| D-004 | d | Proposed (runtime team, from the 2026-10-27 identity research) | ui | 2026-10-27 |\n| D-005 | e | Accepted (Dave, after review) | ui | 2026-10-28 |\n\n## Pending delivery\n\nAccepted (Dave): hold the queue.\n' > DECISIONS.md
git add -A && git commit -qm init
out=$($J init 2>&1)
msg="init: beside a CHANGELOG.md and a register, it writes no log, naming --merge-log"
expect_pass sh -c "test ! -e .jig/decisions.md && echo \"\$0\" | grep -q 'merge-log'" "$out"
git add -A && git commit -qm board
msg="migration: an untracked CHANGELOG.md is refused before anything is written"
git rm -q --cached CHANGELOG.md && git commit -qm untrack && out=$($UP --apply --merge-log 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"isn't tracked\" && test ! -e .jig/decisions.md" "$out"
git add CHANGELOG.md && git commit -qm retrack
msg="migration: a row the old M2 refused (no status) is refused too, before anything is written"
PY2="$T/old-bad"; pcnew "$PY2" && printf '# Decisions\n\n| Id | Decision | Status | Date |\n|---|---|---|---|\n| D-001 | a |  | 2026-01-01 |\n' > DECISIONS.md \
  && git add -A && git commit -qm init && $J init >/dev/null 2>&1 && git add -A && git commit -qm board
out=$($UP --apply --merge-log 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'row D-001 has no status cell or no date' && test ! -e .jig/decisions.md && test -f DECISIONS.md" "$out"
cd "$PX"
msg="migration: a log holding only init's seed doesn't stop the merge"
cp "$DL/.jig/decisions.md" /dev/null && python3 -c "import sys; sys.path.insert(0, '.jig'); import importlib.util as u; s=u.spec_from_file_location('j', '.jig/jig.py'); m=u.module_from_spec(s); s.loader.exec_module(m); open('.jig/decisions.md','w').write(m.LOG_SEED)" && git add -A && git commit -qm seed
out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^Written .jig/decisions.md'" "$out"
msg="migration: a range in a release line places each id; [Unreleased] is the one Unreleased; a # column is the id and Binds stays named"
expect_pass sh -c "sed -n '/^## v1.0.0 - 2026-01-01/,\$p' .jig/decisions.md | grep -qx '### D-001 a' && sed -n '/^## v1.0.0 - 2026-01-01/,\$p' .jig/decisions.md | grep -qx '### D-002 b' && test \$(grep -ci '^## \[*unreleased' .jig/decisions.md) = 1 && grep -qx -- '- D-003 later' .jig/decisions.md && grep -qx 'Proposed (Bo, 2026-02-01).' .jig/decisions.md && grep -qx 'Binds: api' .jig/decisions.md"
msg="migration: a row's note with commas and a date in it converts to a status line M2 takes, and the result checks clean"
expect_pass sh -c "grep -qx 'Proposed (runtime team, from the 2026-10-27 identity research, 2026-10-27).' .jig/decisions.md && grep -qx 'Accepted (Dave, after review, 2026-10-28).' .jig/decisions.md && $J check --staged | grep -qx ok"
msg="migration: what has no home stays in the old file, as written, and the run names it"
expect_pass sh -c "echo \"\$0\" | grep -q 'no home, move by hand: DECISIONS.md' && grep -qx '## Pending delivery' DECISIONS.md && grep -qx 'Accepted (Dave): hold the queue.' DECISIONS.md && ! grep -q '^| D-' DECISIONS.md && grep -qx 'Owner note: older history is in the wiki.' CHANGELOG.md && ! grep -q '^## ' CHANGELOG.md" "$out"
cd "$DL"
}

# ---------------------------------------------------------------- a superseded entry is removed
rment() { python3 -c "import re,sys; f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(re.sub(r'(?ms)^### '+sys.argv[1]+r' .*?(?=^##|\Z)', '', s))" "$1"; }
sec_supersede() {
SR="$T/sr"; pcnew "$SR" && git add -A && git commit -qm init && $J init >/dev/null
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release']['artifacts'] = ['dist/*.zip']" && printf 'dist/\n' > .gitignore
ulog '### Added
- IDS: Number them.' && ulog '### D-001 ids are numbers
Accepted (owner, 2026-11-01).
Touches: docs/shared.md' && git add -A && git commit -qm "board, D-001" && $J release --minor >/dev/null
msg="supersede: removing a released entry with nothing superseding it is refused, naming it"
rment D-001 && git add -A; out=$(git commit -qm drop 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'D-001 is removed from release v0.1.0, and no entry in the log supersedes it'" "$out"
msg="supersede: editing a released change line is still refused"
sed -i.bak 's/^- IDS: Number them\.$/- IDS: Number all./' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm edit 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
msg="supersede: a proposed entry naming Supersedes D-001 removes nothing: removing D-001 with it is refused"
ulog '### D-002 maybe strings
Proposed (2026-11-02). Supersedes D-001.
Touches: docs/shared.md' Open && rment D-001 && git add -A; out=$(git commit -qm proposal 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'D-001 is removed from release v0.1.0, and no entry in the log supersedes it'" "$out"
msg="supersede: one commit adding D-002 that supersedes D-001 and removing D-001 from v0.1.0 is accepted, change lines kept"
ulog '### D-002 ids are strings
Accepted (owner, 2026-11-02). Supersedes D-001.
Touches: docs/shared.md' && rment D-001 && git add -A
expect_pass sh -c "git commit -qm 'D-002: strings' && ! grep -q '^### D-001' .jig/decisions.md && grep -qx -- '- IDS: Number them.' .jig/decisions.md"
msg="supersede: a later commit touching the log passes M2, Supersedes D-001 resolving through history"
ulog '### Changed
- IDS: Strings now.' && git add -A; expect_pass git commit -qm "IDS: strings"
msg="supersede: a supersedes link to an id the log never had is refused"
ulog '### D-003 x
Accepted (owner, 2026-11-03). Supersedes D-099.
Touches: docs/shared.md' && git add -A; out=$(git commit -qm d3 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'supersedes D-099, which has no entry'" "$out"
msg="supersede: jig decision D-001 prints it from git, the release it was in, and D-002 as what holds now"
out=$($J decision D-001 2>&1); expect_pass sh -c "echo \"\$0\" | grep -qx '### D-001 ids are numbers' && echo \"\$0\" | grep -q 'in v0.1.0' && echo \"\$0\" | grep -q 'superseded by D-002' && echo \"\$0\" | grep -q 'What holds now is D-002'" "$out"
msg="supersede: jig decision D-002 names D-001 as superseded and removed"
out=$($J decision D-002 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'D-002 supersedes D-001, which is removed'" "$out"
msg="supersede: jig decision of an id never in the log fails"
expect_refuse $J decision D-077
$J open sj >/dev/null && git add -A && git commit -qm "open sj"
cd .git/jig/worktrees/sj
msg="supersede: a job removing an Unreleased entry nothing supersedes is refused (R3)"
rment D-002 && git add -A; expect_refuse git commit -qm drop; undo
msg="supersede: a job adding D-?ids-uuid that supersedes D-002 and removing D-002 is accepted, and merges"
ulog '### D-?ids-uuid ids are uuids
Accepted (owner, 2026-11-04). Supersedes D-002.
Touches: docs/shared.md' && rment D-002 && git add -A
expect_pass git commit -qm "D-?ids-uuid: uuids"
$J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note sj" && cd "$SR"
msg="supersede: jig merge numbers it D-003, and trunk's log has no D-002"
out=$($J merge sj 2>&1); expect_pass sh -c "grep -qx '### D-003 ids are uuids' .jig/decisions.md && ! grep -q '^### D-002' .jig/decisions.md" "$out"
msg="supersede: jig decision D-001 walks two removals to D-003"
out=$($J decision D-001 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'D-002 is superseded by D-003' && echo \"\$0\" | grep -q 'What holds now is D-003'" "$out"
msg="supersede: on trunk, D-004 superseding D-003, an id given only in a merge commit, removes it and passes M2"
ulog '### D-004 ids are ulids
Accepted (owner, 2026-11-05). Supersedes D-003.
Touches: docs/shared.md' && rment D-003 && git add -A; expect_pass git commit -qm "D-004: ulids"
git clone -q --depth 1 "file://$SR" "$T/shallow" && cd "$T/shallow"
msg="supersede: in a shallow clone, a log commit passes M2 though D-003's entry is in history it lacks"
ulog '### Changed
- IDS: Shallow.' && git add -A; expect_pass $J check --staged; undo
msg="supersede: in a shallow clone, jig decision D-003 says the clone is shallow"
out=$($J decision D-003 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q 'this clone is shallow'" "$out"
cd "$SR"
msg="supersede: jig update lists a superseded entry the log still holds under Repo files to review"
ulog '### D-006 keep the old way
Accepted (owner, 2026-11-05). Supersedes D-005.
Touches: docs/shared.md

### D-005 the old way
Accepted (owner, 2026-11-05).
Touches: docs/shared.md' && ulog '### D-007 maybe go back
Proposed (2026-11-06). Supersedes D-004.
Touches: docs/shared.md' Open && git add -A && git commit -qm "D-005, D-006, D-007"
out=$($J update 2>&1); expect_pass sh -c "echo \"\$0\" | grep -A9 'Repo files to review' | grep -q 'D-005 is superseded by D-006: remove it; the entry superseding it names it'" "$out"
msg="supersede: jig update doesn't list an entry only a proposal supersedes"
expect_pass sh -c "! echo \"\$0\" | grep -q 'D-004 is superseded'" "$out"

SM2="$T/sm"; mkdir -p "$SM2" && cd "$SM2" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --name sm >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
git switch -q -c a && ulog '### D-001 ids are numbers
Accepted (owner, 2026-11-01).
Touches: docs/shared.md' && git add -A && git commit -qm "D-001: ids" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit a && $J release >/dev/null
SP="$T/sp"; mkdir -p "$SP" && cd "$SP" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && mkdir -p api .jig/specs && printf 'x=1\n' > api/a.py
git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
git clone -q "$SM2" smclone && $J init --para sm --location smclone --contract 'api/**' >/dev/null && git add -A && git commit -qm para-init
printf '# s\n\nPer `sm/.jig/decisions.md § D-001`.\n' > .jig/specs/s.md && git add -A && git commit -qm "cite sm" >/dev/null 2>&1
cd "$SM2" && git switch -q -c b && ulog '### D-002 ids are strings
Accepted (owner, 2026-11-02). Supersedes D-001.
Touches: docs/shared.md' && rment D-001 && git add -A && git commit -qm "D-002: strings" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit b && $J release >/dev/null
cd "$SP" && git -C smclone pull -q 2>/dev/null && setjson .jig/para.json pin v0.3.0 && $J init --para sm >/dev/null 2>&1 \
  && git add -A && git commit -qm "meta: sm v0.2.0 → v0.3.0" >/dev/null 2>&1; out=$($J sync 2>&1)
msg="supersede: a pararepo citing a removed metarepo entry is told after the pin bump, with the successor named"
expect_pass sh -c "echo \"\$0\" | grep -qF '.jig/specs/s.md:3 cites sm/.jig/decisions.md § D-001, which sm' && echo \"\$0\" | grep -qF 'has no row for: now sm/.jig/decisions.md § D-002'" "$out"
cd "$SM2" && git switch -q -c c && ulog '### D-003 ids are uuids
Accepted (owner, 2026-11-03). Supersedes D-002.
Touches: docs/shared.md' && rment D-002 && git add -A && git commit -qm "D-003: uuids" && $J reviewed >/dev/null
git switch -q main && git merge -q --no-ff --no-edit c && $J release >/dev/null
cd "$SP" && git -C smclone pull -q 2>/dev/null && setjson .jig/para.json pin v0.4.0 && $J init --para sm >/dev/null 2>&1 \
  && git add -A && git commit -qm "meta: sm v0.3.0 → v0.4.0" >/dev/null 2>&1; out=$($J sync 2>&1)
msg="supersede: a citation two removals back walks the metarepo's history to the entry that holds at the pin"
expect_pass sh -c "echo \"\$0\" | grep -qF 'has no row for: now sm/.jig/decisions.md § D-003'" "$out"

# A job's branch is judged from where it left trunk, migration or not: a later commit may
# undo or correct a supersede that trunk never had, with a counter over the log.
SU="$T/su"; pcnew "$SU" && git add -A && git commit -qm init && $J init >/dev/null
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh && printf 'dist/\n' > .gitignore
board "b['release']['artifacts'] = ['dist/*.zip']; b['reserve'] = {'decision': {'pattern': r'^### D-(\d+)', 'files': ['.jig/decisions.md']}}"
ulog '### Added
- PORTS: Closed.'
ulog '### D-002 ports stay closed
Accepted (owner, 2026-11-01).
Touches: docs/shared.md

### D-001 ids are numbers
Accepted (owner, 2026-11-01).
Touches: docs/shared.md' && git add -A && git commit -qm "board, D-001, D-002"; out=$($J release --minor 2>&1)
msg="branch log: the set-up releases D-001 and D-002 in v0.1.0"
expect_pass sh -c "git tag | grep -qx v0.1.0" "$out"
$J open su >/dev/null && git add -A && git commit -qm "open su"
cd .git/jig/worktrees/su
ulog '### D-?str ids are strings
Accepted (owner, 2026-11-02). Supersedes D-001.
Touches: docs/shared.md' && rment D-001 && git add -A && git commit -qm "D-?str: strings"
msg="branch log: the job's commit A supersedes D-001 and removes it"
expect_pass sh -c "! grep -q '^### D-001' .jig/decisions.md && test -z \"\$(git status --porcelain)\""
msg="branch log: reverting a job's supersede, staged and committed, passes with no R6"
git revert --no-commit HEAD && out=$(git commit -qm "revert D-?str" 2>&1); rc=$?; git reset -q --hard HEAD~$((rc == 0))
expect_pass sh -c "test $rc = 0" "$out"
msg="branch log: correcting a job's supersede to supersede D-002 instead passes with no R6"
git show HEAD~1:.jig/decisions.md > .jig/decisions.md && ulog '### D-?str ports are open
Accepted (owner, 2026-11-02). Supersedes D-002.
Touches: docs/shared.md' && rment D-002 && git add -A
out=$(git commit -qm "D-?str: D-002 instead" 2>&1); rc=$?; git reset -q --hard HEAD~$((rc == 0))
expect_pass sh -c "test $rc = 0" "$out"
msg="branch log: editing an entry trunk released is still refused on the branch, frozen on main"
sed -i.bak 's/^### D-002 ports stay closed$/### D-002 ports stay shut/' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm edit 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
msg="branch log: removing a released entry nothing supersedes is still refused on the branch"
rment D-002 && git add -A; out=$(git commit -qm drop 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'D-002 is removed from release v0.1.0, and no entry in the log supersedes it'" "$out"
msg="branch log: deleting a log trunk has is still refused on the branch"
git rm -q .jig/decisions.md; out=$(git commit -qm gone 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'it is never deleted'" "$out"
msg="branch log: a new entry with no Touches line is still refused on the branch"
ulog '### D-?x x
Accepted (owner, 2026-11-03).' && git add -A; out=$(git commit -qm x 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'D-?x names no page it touches'" "$out"
# A branch can hold a release its local trunk lacks: made from origin's trunk, or pulled. That
# release is trunk's, and frozen, though the merge base doesn't have it.
cd "$SU" && printf '# Reqs\n\n| Id | What |\n|---|---|\n| REQ-1 | boot in 2s |\n' > docs/reqs.md && git add -A && git commit -qm "docs: reqs"
$J open sv >/dev/null && git add -A && git commit -qm "open sv"; was=$(git rev-parse HEAD)
ulog '### Added
- PORTS: Open on request.' && git add -A && git commit -qm "PORTS: open on request"; $J release --minor >/dev/null 2>&1
cd .git/jig/worktrees/sv && git merge -q --ff-only main && git update-ref refs/heads/main "$was"
msg="branch log: a branch holding a release its stale local trunk lacks finds it frozen"
sed -i.bak 's/^- PORTS: Open on request\.$/- PORTS: Open./' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm "PORTS: open" 2>&1); undo
expect_pass sh -c "grep -qx '## v0.2.0 - [0-9-]*' .jig/decisions.md && echo \"\$0\" | grep -q 'release v0.2.0 is frozen on main'" "$out"
# A table in an ordinary page is no register: changing it doesn't make a commit a conversion.
msg="branch log: with a stale trunk, rewording a table row beside an edit to trunk's later release doesn't unfreeze it"
sed -i.bak 's/^- PORTS: Open on request\.$/- PORTS: Open./' .jig/decisions.md && sed -i.bak 's/^| REQ-1 | boot in 2s |$/- REQ-1: boot in 2s/' docs/reqs.md && rm .jig/decisions.md.bak docs/reqs.md.bak && git add -A
out=$(git commit -qm "PORTS: open" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.2.0 is frozen on main'" "$out"
# The stale merge base can predate the log: only the releases its CHANGELOG.md held are ones a
# conversion on this branch wrote. What trunk released after converting stays frozen.
SV="$T/sv"; pcnew "$SV" && git add -A && git commit -qm init && $J init >/dev/null
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh && printf 'dist/\n' > .gitignore
board "b['release']['artifacts'] = ['dist/*.zip']" && git add -A && git commit -qm board
$J open feat >/dev/null && git add -A && git commit -qm "open feat"; cp .jig/decisions.md "$T/sv-log"
nohook() { git -c core.hooksPath=/dev/null commit -qm "$1"; }
git rm -q .jig/decisions.md && printf '# Changelog\n\n## v0.0.1 - 2026-11-01\n\n### Added\n- IDS: Number them.\n' > CHANGELOG.md && git add -A && nohook "pre-log"; was=$(git rev-parse HEAD)
git rm -q CHANGELOG.md && cp "$T/sv-log" .jig/decisions.md && ulog '## v0.0.1 - 2026-11-01

### Added
- IDS: Number them.' && git add -A && nohook "TOOL: merge the log"
ulog '### D-002 ports stay shut
Accepted (owner, 2026-11-05).
Touches: docs/shared.md' && ulog '### Added
- PORTS: Closed.' && git add -A && git commit -qm "D-002: ports" && $J release --minor >/dev/null 2>&1
cd .git/jig/worktrees/feat && git merge -q --ff-only main && git update-ref refs/heads/main "$was"
msg="branch log: with a stale trunk from before the log, the set-up holds v0.1.0 beyond it"
expect_pass sh -c "grep -qx '## v0.1.0 - [0-9-]*' .jig/decisions.md && test \$(git merge-base main HEAD) = $was"
msg="branch log: with a stale trunk from before the log, a status in trunk's later release is frozen"
sed -i.bak 's/^Accepted (owner, 2026-11-05)\.$/Accepted (owner, 2026-11-06)./' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm "D-002: restated" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
msg="branch log: with a stale trunk from before the log, dropping trunk's later release is refused"
python3 -c "import re; f='.jig/decisions.md'; s=open(f).read(); open(f,'w').write(re.sub(r'(?s)## v0\.1\.0 .*?(?=## v0\.0\.1)', '', s))" && git add -A
out=$(git commit -qm "drop v0.1.0" 2>&1); undo; expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.1.0 is gone'" "$out"
msg="branch log: with a stale trunk from before the log, deleting the log is refused, alone or beside an old CHANGELOG.md or a table"
r1=$(git rm -q .jig/decisions.md; git commit -qm gone 2>&1); undo
r2=$(git rm -q .jig/decisions.md; printf '# Changelog\n\n## v0.0.1 - 2026-11-01\n\n### Added\n- IDS: Number them.\n' > CHANGELOG.md; git add -A; git commit -qm gone 2>&1); undo
r3=$(git rm -q .jig/decisions.md; printf '# Notes\n\n| REQ-1 | x |\n' > notes.md; git add -A; git commit -qm gone 2>&1); undo
expect_pass sh -c "for r in \"\$0\" \"\$1\" \"\$2\"; do echo \"\$r\" | grep -q 'it is never deleted' || exit 1; done" "$r1" "$r2" "$r3"
msg="branch log: with a stale trunk, a conversion a remote's trunk already holds is trunk's: its releases are frozen"
git update-ref refs/remotes/origin/main HEAD && sed -i.bak 's/^- IDS: Number them\.$/- IDS: Number all./' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm "IDS: all" 2>&1); undo; git update-ref -d refs/remotes/origin/main
expect_pass sh -c "echo \"\$0\" | grep -q 'release v0.0.1 is frozen on main'" "$out"
# The base's CHANGELOG.md had a v0.1.0; trunk dropped it, started a fresh log and released its
# own v0.1.0. Only what the commit adding the log wrote is a conversion's, so trunk's is frozen.
SW="$T/sw"; pcnew "$SW" && git add -A && git commit -qm init && $J init >/dev/null
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh && printf 'dist/\n' > .gitignore
board "b['release']['artifacts'] = ['dist/*.zip']" && git add -A && git commit -qm board
$J open feat >/dev/null && git add -A && git commit -qm "open feat"; cp .jig/decisions.md "$T/sw-log"
git rm -q .jig/decisions.md && printf '# Changelog\n\n## v0.1.0 - 2026-11-01\n\n### Added\n- IDS: Number them.\n' > CHANGELOG.md && git add -A && nohook "pre-log"; was=$(git rev-parse HEAD)
git rm -q CHANGELOG.md && cp "$T/sw-log" .jig/decisions.md && git add -A && nohook "fresh log"
ulog '### Added
- TRUNK: Its own v0.1.0.' && git add -A && git commit -qm "TRUNK: own" && $J release --minor >/dev/null 2>&1
cd .git/jig/worktrees/feat && git merge -q --ff-only main && git update-ref refs/heads/main "$was"
msg="branch log: a release trunk made after dropping the base's CHANGELOG.md, under a version it held, is frozen"
sed -i.bak 's/^- TRUNK: Its own v0\.1\.0\.$/- TRUNK: Rewritten./' .jig/decisions.md && rm .jig/decisions.md.bak && git add -A
out=$(git commit -qm "TRUNK: rewritten" 2>&1); undo
expect_pass sh -c "grep -q '^- TRUNK: Its own v0.1.0.' .jig/decisions.md && echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
cd "$SR"
}



sec_touches() {
# A decision names the pages it touches; jig puts each pair touching one page in front of a reader.
export JIG_CONFIG="$T/repos.json" XDG_CONFIG_HOME="$T/config"     # never the user's real list
TP="$T/tp"; pcnew "$TP" && mkdir -p docs/a docs/x && printf '# A\n' > docs/a.md && printf '# B\n' > docs/a/b.md \
  && printf '# X\n' > docs/x/x.md && git add -A && git commit -qm init && $J init >/dev/null
ulog '### D-001 old one
Accepted (owner, 2026-11-01).

When anything happens, log it.' && git add -A
msg="touches M2: the first numbered entry in a fresh log, with no Touches, is refused: only update's register merge is exempt"
expect_refuse $J check --staged
git -c core.hooksPath=/dev/null commit -qm "board, D-001 (written before Touches)"
msg="touches M2: a new entry with no Touches line is refused, naming the line"
ulog '### D-002 a rules
Accepted (owner, 2026-11-02).

When a is idle, it sleeps.' && git add -A; out=$($J check --staged 2>&1); rc=$?; git reset -q; git checkout -q -- .jig/decisions.md
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'D-002 names no page it touches'" "$out"
msg="touches M2: a Touches naming a page that isn't there is refused"
expect_refuse m2 '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: docs/nope.md'
msg="touches M2: a page named in its folder form while it is flat is accepted, and so is a folder page named flat"
expect_pass m2 '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: docs/a/a.md, `docs/x.md`'
msg="touches M2: AGENTS.md is no docs page"
expect_refuse m2 '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: AGENTS.md'
msg="touches M2: a file docmap names outside docs/ is a page"
mkdir -p guide && printf '# G\n' > guide/g.md && board "b['docmap'] = {'guide/g.md': ['src/**']}" && git add -A && git commit -qm "board: guide"
expect_pass m2 '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: guide/g.md'
msg="touches M2: this repo's own name as a prefix, in either pointer form, is its own page"
expect_pass m2 '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: tp/docs/a.md, tp:docs/x.md'
msg="touches M2: a <repo>: pointer naming a repo jig doesn't know is refused"
expect_refuse m2 '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: zz:docs/a.md'
msg="touches M2: an untouched old entry with none passes beside a new change line"
expect_pass m2 '### Added
- a thing'
ulog '### D-003 x rules
Accepted (owner, 2026-11-02).
Touches: docs/x.md

When x starts, it warms up first.' && ulog '### D-002 a rules
Accepted (owner, 2026-11-02).
Touches: docs/a.md

When a is idle, it sleeps. Then more.' && git add -A && git commit -qm "D-002, D-003: a and x"
git switch -q -c t1 && ulog '### D-?b b rules
Accepted (owner, 2026-11-03).
Touches: docs/a/b.md

When b is idle, it stays awake.' && git add -A && git commit -qm "D-?b: b" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/*.md)
msg="touches fold-in: an entry on docs/a/b.md gets a pair line with the one on docs/a.md, the page above"
expect_pass grep -qxF -- '- [ ] D-?b vs .jig/decisions.md § D-002 (docs/a/b.md): ___' "$note"
msg="touches fold-in: no pair line for the entry on an unrelated page, nor the old entry with no Touches"
expect_pass sh -c "! grep -qE '§ D-00[13]' '$note'"
msg="touches: jig decision --peers lists the peers with their first body sentence"
out=$($J decision D-002 --peers 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'D-?b b rules' && echo \"\$0\" | grep -qx '      When b is idle, it stays awake.' && echo \"\$0\" | grep -qx '  When a is idle, it sleeps.' && ! echo \"\$0\" | grep -q 'D-003'" "$out"
rm -rf .jig/handoffs && git switch -q main
msg="touches update: a live entry with no Touches is listed under Repo files to review"
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'D-001 old one has no Touches line'" "$out"

# The backfill reaches a release: a released entry may gain its Touches line, and nothing else.
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release']['artifacts'] = ['dist/*.zip']" && printf 'dist/\n' >> .gitignore && git add -A \
  && git commit -qm "release protocol" && $J release --minor >/dev/null 2>&1
touch_d1() { python3 -c "import sys; f='.jig/decisions.md'; s=open(f).read(); a='### D-001 old one\nAccepted (owner, 2026-11-01).\n'; assert a in s; s=s.replace(a, a+'Touches: '+sys.argv[1]+'\n'); open(f,'w').write(s.replace('log it.', sys.argv[2]) if len(sys.argv) > 2 else s)" "$@"; }
msg="touches release: backfilling Touches on a released entry passes"
touch_d1 docs/a.md && git add -A; out=$($J check --staged 2>&1); rc=$?; git reset -q; git checkout -q -- .jig/decisions.md
expect_pass sh -c "test $rc = 0 && git show HEAD:.jig/decisions.md | grep -q '^## v0.1.0 - '" "$out"
msg="touches release: the same backfill with the entry's body edited too is refused as frozen"
touch_d1 docs/a.md 'log everything.' && git add -A; out=$($J check --staged 2>&1); rc=$?; git reset -q; git checkout -q -- .jig/decisions.md
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'release v0.1.0 is frozen on main'" "$out"
msg="touches release: a backfill naming no docs page is refused by M2"
touch_d1 AGENTS.md && git add -A; out=$($J check --staged 2>&1); rc=$?; git reset -q; git checkout -q -- .jig/decisions.md
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'D-001 touches AGENTS.md' && ! echo \"\$0\" | grep -q frozen" "$out"

# The reported symptom: a pararepo entry and the metarepo's on one feature, put side by side.
TM="$T/tm"; pcnew "$TM" && git add -A && git commit -qm init && $J init --meta --name hub --genres features >/dev/null
mkdir -p docs/features && printf '# Gestures\n' > docs/features/gestures.md && printf '# Taps\n' > docs/features/taps.md
ulog '### D-033 gestures count as activity
Accepted (owner, 2026-11-01).
Touches: docs/features/gestures.md

When the device sees a gesture, it counts as activity.'
git add -A && git -c core.hooksPath=/dev/null commit -qm "meta-init" && $J release >/dev/null
TQ="$T/tq"; pcnew "$TQ" && mkdir -p docs && printf '# Identity\n' > docs/identity.md && git add -A && git commit -qm init \
  && $J init >/dev/null && git add -A && git commit -qm board
$J init --para hub --location "$TM" >/dev/null 2>&1 && git add -A && git commit -qm "init --para"
$J open lock --branch b-lock >/dev/null && git add -A && git commit -qm "TOOL: open lock"
cd .git/jig/worktrees/b-lock
msg="touches M2: in a pararepo, a pointer to a metarepo page the pin lacks is refused"
expect_refuse m2 '### D-?id-lock the lock ignores gestures
Accepted (owner, 2026-11-02).
Touches: hub/docs/features/nope.md'
mv .jig/meta-cache "$T/wt-cache" && mv "$TQ/.jig/meta-cache" "$T/main-cache"
msg="touches M2: with no cache, a metarepo pointer still needs a docs page's shape"
expect_refuse m2 '### D-?id-lock the lock ignores gestures
Accepted (owner, 2026-11-02).
Touches: hub/src/x.md'
msg="touches M2: with no cache, a docs-shaped metarepo pointer passes"
expect_pass m2 '### D-?id-lock the lock ignores gestures
Accepted (owner, 2026-11-02).
Touches: hub/docs/features/later.md'
mv "$T/wt-cache" .jig/meta-cache && mv "$T/main-cache" "$TQ/.jig/meta-cache"
ulog '### D-?id-lock the lock ignores gestures
Accepted (owner, 2026-11-02).
Touches: hub/docs/features/gestures.md, docs/identity.md

When the identity lock is on, a gesture is not activity.'
git add -A && git commit -qm "D-?id-lock: ignore gestures" && $J reviewed >/dev/null
cp .jig/meta-cache/PIN "$T/pin" && printf 'v0.0.9\n' > .jig/meta-cache/PIN && $J handoff >/dev/null 2>&1
msg="touches fold-in: a cache at another pin is a line to answer, naming both pins, and gives no pair"
expect_pass sh -c "grep -qF -- '- [ ] not read for peers: hub'\''s log: .jig/meta-cache/ is at v0.0.9, the pin is v0.1.0' .jig/handoffs/*.md && ! grep -q '§ D-033' .jig/handoffs/*.md"
rm -f .jig/handoffs/*.md && cp "$T/pin" .jig/meta-cache/PIN && $J handoff >/dev/null 2>&1
note=$(ls .jig/handoffs/*.md)
msg="touches fold-in: a pararepo entry touching the metarepo's page gets a pair line with the metarepo's entry"
expect_pass grep -qxF -- '- [ ] D-?id-lock vs hub/.jig/decisions.md § D-033 (hub/docs/features/gestures.md): ___' "$note"
git add -A && git commit -qm "TOOL: note lock" && cd "$TQ"
msg="touches gate: the pair line unanswered is refused"
expect_refuse gate_ok lock
cd .git/jig/worktrees/b-lock && sed -i.bak -e 's/^- \[ \]/- [x]/' -e 's/: ___$/: conflicts/' -e 's/___/smoke/g' .jig/handoffs/*.md && rm .jig/handoffs/*.bak \
  && git add -A && git commit -qm "TOOL: answer lock" && cd "$TQ"
msg="touches gate: conflicts with no resolution is refused"
out=$($J gate lock 2>&1); git worktree remove --force .git/jig/worktrees/gate-lock 2>/dev/null
expect_pass sh -c "echo \"\$0\" | grep -q 'conflicts needs its resolution'" "$out"
cd .git/jig/worktrees/b-lock && sed -i.bak 's/ (hub\/docs\/features\/gestures.md): conflicts$/: agrees/' .jig/handoffs/*.md && rm .jig/handoffs/*.bak \
  && git add -A && git commit -qm "TOOL: reshape lock" && cd "$TQ"
msg="touches gate: a pair line reshaped by hand is refused"
expect_refuse gate_ok lock
cd .git/jig/worktrees/b-lock && sed -i.bak 's/§ D-033: agrees$/§ D-033 (hub\/docs\/features\/gestures.md): narrows: when locked (an exception the metarepo allows), gestures wait/' .jig/handoffs/*.md && rm .jig/handoffs/*.bak \
  && git add -A && git commit -qm "TOOL: answer lock again" && cd "$TQ"
msg="touches gate: answered narrows, with parentheses in the answer, it passes"
expect_pass gate_ok lock

# Two jobs ruling on one page at once meet at the gate of the second, after the first merges.
for j in one two; do
  $J open $j --branch b-$j >/dev/null && git add -A && git commit -qm "TOOL: open $j"
  (cd .git/jig/worktrees/b-$j && ulog "### D-?$j $j rules
Accepted (owner, 2026-11-03).
Touches: docs/identity.md

When $j runs, the lock waits." && git add -A && git commit -qm "D-?$j: $j" && $J reviewed >/dev/null \
    && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note $j")
done
gate_ok one && $J merge one >/dev/null 2>&1
msg="touches gate: a pair with a job merged since the handoff is refused, naming it"
out=$($J gate two 2>&1); rc=$?; git worktree remove --force .git/jig/worktrees/gate-two 2>/dev/null
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q \"doesn't answer these pairs\" && echo \"\$0\" | grep -qF 'D-?two vs .jig/decisions.md § D-' && echo \"\$0\" | grep -q 'jig sync'" "$out"

# A metarepo reads its registered pararepos' trunks: a page two of them rule on is probably its own.
TH="$T/th"; pcnew "$TH" && git add -A && git commit -qm init && $J init --meta --name house --genres features >/dev/null
python3 -c "import json; f='.jig/meta.json'; d=json.load(open(f)); d['pararepos']=['pa', 'pb', 'pc']; json.dump(d, open(f,'w'), indent=2)"
mkdir -p docs/features && printf '# X\n' > docs/features/x.md && printf '# Y\n' > docs/features/y.md
ulog '### D-001 y rules
Accepted (owner, 2026-11-01).
Touches: docs/features/y.md

When y runs, it runs alone.' && git add -A && git -c core.hooksPath=/dev/null commit -qm "meta-init"
for r in pa pb; do
  mkdir -p "$T/$r/.jig" && cd "$T/$r" && git init -q -b main && git config user.email t@t && git config user.name t
  printf '# Decisions\n\n## Open\n\n## Unreleased\n\n### D-001 %s on x\nAccepted (owner, 2026-11-02).\nTouches: house/docs/features/x.md, house/docs/features/y.md\n\nWhen x runs, %s waits.\n' $r $r > .jig/decisions.md
  git add -A && git commit -qm init && cd "$TH" && $J repos add para "$T/$r" --name $r >/dev/null
done
msg="touches survey: a metarepo names the page two pararepos rule on and it doesn't, not one it rules on too"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -qx '  docs/features/x: pa, pb rule on it, and no entry here does' && ! echo \"\$0\" | grep -q 'docs/features/y:'" "$out"
msg="touches M2: a metarepo entry naming a pararepo's page is refused"
expect_refuse m2 '### D-002 z rules
Accepted (owner, 2026-11-02).
Touches: pa/docs/x.md'
msg="touches: --peers in a metarepo reads the pararepos, and names one it can't find"
out=$($J decision D-001 --peers 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'pa/.jig/decisions.md § D-001' && echo \"\$0\" | grep -q 'pb/.jig/decisions.md § D-001' && echo \"\$0\" | grep -q 'not read: pc'" "$out"

# A metarepo named docs: a bare docs/… path is the pararepo's own page; the metarepo's is docs:<path>.
TD="$T/td"; pcnew "$TD" && git add -A && git commit -qm init && $J init --meta --name docs --genres features >/dev/null
mkdir -p docs/features && printf '# Gestures\n' > docs/features/gestures.md && git add -A \
  && git -c core.hooksPath=/dev/null commit -qm "meta-init" && $J release >/dev/null
TR="$T/tr"; pcnew "$TR" && mkdir -p docs && printf '# Own\n' > docs/own.md && git add -A && git commit -qm init \
  && $J init >/dev/null && git add -A && git commit -qm board
$J init --para docs --location "$TD" >/dev/null 2>&1 && git add -A && git commit -qm "init --para" && git switch -q -c x
msg="touches M2: with a metarepo named docs, docs:<path> is its page and docs/own.md this repo's"
expect_pass m2 '### D-?a a rules
Accepted (owner, 2026-11-02).
Touches: docs:docs/features/gestures.md, docs/own.md'
msg="touches M2: with a metarepo named docs, a bare docs/features/gestures.md is this repo's, and missing"
expect_refuse m2 '### D-?a a rules
Accepted (owner, 2026-11-02).
Touches: docs/features/gestures.md'
cd "$T"
}


# ---------------------------------------------------------------- a staged batch: after:, check, Workflow, near names
sbafter() { sed -i.bak "s/^status: staged\$/after: $2\nstatus: staged/" ".jig/staging/$1" && rm ".jig/staging/$1.bak"; }
sec_staging_batches() {
export JIG_CONFIG="$T/sb-repos.json" XDG_CONFIG_HOME="$T/sb-config"
SB="$T/sb"; mkdir -p "$SB" && cd "$SB" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
# named so that name order and after: order disagree
stage z.md this doc new docs/z.md; stage b.md this doc new docs/b.md; stage c.md this doc new docs/c.md
sbafter b.md z.md; sbafter c.md b.md
msg="staging: the list puts each file after the one its after: names (z, b, c), not in name order"
expect_pass test "$($J staging | sed -n 's/^  \([a-z]\.md\):.*/\1/p' | tr '\n' ' ')" = "z.md b.md c.md "
msg="staging: resolve refuses c.md while b.md, which it waits for, is staged, and names b.md"
out=$($J staging resolve c.md 2>&1); rc=$?
expect_pass sh -c "test $rc -ne 0 && echo \"\$0\" | grep -q 'waits for b.md' && test -f .jig/staging/c.md" "$out"
msg="staging: once the file it waits for is resolved, a file resolves, and the list doesn't flag the gone file"
$J staging resolve z.md >/dev/null
expect_pass sh -c "$J staging && ! $J staging | grep -q 'z.md:' && $J staging resolve b.md"
$J staging drop c.md >/dev/null
msg="staging: after: takes a YAML list and names without .md"
stage p.md this doc new docs/p.md; stage q.md this doc new docs/q.md; stage r.md this doc new docs/r.md
sbafter p.md '[q, "r.md"]'
expect_refuse $J staging resolve p.md
$J staging drop q.md >/dev/null; $J staging drop r.md >/dev/null
expect_pass $J staging resolve p.md
msg="staging: in a cycle, only its members are named as in it; a file waiting on it is told so"
stage a.md this doc new docs/a.md; stage b.md this doc new docs/b2.md; stage c.md this doc new docs/c2.md
sbafter a.md b.md; sbafter b.md a.md; sbafter c.md a.md
out=$($J staging 2>&1); rc=$?
expect_pass sh -c "test $rc -ne 0 && echo \"\$0\" | grep -q 'in a cycle with b.md' && echo \"\$0\" | grep -q 'in a cycle with a.md' && echo \"\$0\" | grep -q 'waits on a cycle' && test \$(echo \"\$0\" | grep -c 'in a cycle') = 2" "$out"
msg="staging: resolve's refusal of a file in a cycle names the cycle"
expect_pass sh -c "$J staging resolve a.md 2>&1 | grep -q 'in a cycle with b.md'"
for f in a b c; do $J staging drop $f.md >/dev/null; done

$J workflow > "$T/wf"
msg="staging: a spec with an empty ## Workflow resolves with jig workflow's lines in it"
stage w.md this spec new w.md '# W\n\n## Intent\nx\n\n## Workflow\n<!-- fill -->\n\n## After\ny\n'
$J staging resolve w.md >/dev/null
expect_pass sh -c "sed -n '/^## Workflow/,/^## After/p' .jig/specs/w.md | grep -vE '^(## |<!--|\$)' | diff - '$T/wf' && grep -q '^## After' .jig/specs/w.md"
msg="staging: a spec with no ## Workflow gets one"
stage v.md this spec new v.md '# V\n\n## Intent\nx\n'
$J staging resolve v.md >/dev/null
expect_pass sh -c "sed -n '/^## Workflow/,\$p' .jig/specs/v.md | tail -n +2 | diff - '$T/wf'"
msg="staging: a spec whose ## Workflow holds lines keeps them"
stage u.md this spec new u.md '# U\n\n## Workflow\nspec: tier 1, effort 1\n'
$J staging resolve u.md >/dev/null
expect_pass test "$(sed -n '/^## Workflow/,$p' .jig/specs/u.md | tail -n +2)" = "spec: tier 1, effort 1"
msg="staging: a Workflow heading with text after it, lower case or at the end with no newline is filled once"
stage t1.md this spec new t1.md '# T\n\n## Workflow (from the repo)\n\n## After\ny\n'
stage t2.md this spec new t2.md '# T\n\n## workflow\n'
stage t3.md this spec new t3.md '# T\n\n## Workflow'
for f in t1 t2 t3; do $J staging resolve $f.md >/dev/null; done
expect_pass sh -c "for f in t1 t2 t3; do test \$(grep -ci '^## workflow' .jig/specs/\$f.md) = 1 && grep -q '^review: tier [0-9], effort [0-9]$' .jig/specs/\$f.md || exit 1; done; grep -q '^## After' .jig/specs/t1.md"
msg="staging: a spec to fill while jig workflow refuses is refused, and stays staged"
setwf '{"execute": {"effort": 2}}'
stage x.md this spec new x.md '# X\n\n## Workflow\n'
expect_pass sh -c "! $J staging resolve x.md 2>/dev/null && $J staging resolve x.md 2>&1 | grep -q 'jig workflow. refuses' && test -f .jig/staging/x.md && test ! -e .jig/specs/x.md"
git checkout -q -- .jig/config.json; $J staging drop x.md >/dev/null

$J repos add north-star "$SB" >/dev/null
OUT="$T/sb-out"; mkdir -p "$OUT"
hdr() { printf -- '---\nstaged: true\ntarget: %s\n%bchange: new\ndestination: %s\nsource: chat\n%bstatus: staged\n---\nx\n' "$2" "$3" "$4" "${5:-}" > "$OUT/$1"; }
hdr nokind.md north-star '' docs/x.md
hdr good.md north-star 'kind: doc\n' docs/x.md
msg="staging check: run outside any repo, a file with no kind: is named, and it exits non-zero"
out=$(cd "$OUT" && python3 "$P/jig/jig.py" staging check nokind.md good.md 2>&1); rc=$?
expect_pass sh -c "test $rc -ne 0 && echo \"\$0\" | grep -q 'no kind' && echo \"\$0\" | grep -q '^good.md: ok'" "$out"
msg="staging check: a good file passes"
expect_pass sh -c "cd '$OUT' && python3 '$P/jig/jig.py' staging check good.md"
msg="staging check: an absolute destination, an after: outside the batch and an unlisted target are each named"
hdr worse.md nowhere 'kind: doc\n' /tmp/x.md 'after: missing.md\n'
out=$(cd "$OUT" && python3 "$P/jig/jig.py" staging check worse.md 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'outside the target' && echo \"\$0\" | grep -q 'after missing.md' && echo \"\$0\" | grep -q \"target 'nowhere'\"" "$out"
msg="staging check: a destination climbing out with .. is refused, as resolve refuses it"
hdr up.md north-star 'kind: doc\n' ../../etc/x.md
expect_refuse sh -c "cd '$OUT' && python3 '$P/jig/jig.py' staging check up.md"
msg="staging check: the target matches whatever its case, as resolve matches it"
hdr case.md NORTH-STAR 'kind: doc\n' docs/x.md
expect_pass sh -c "cd '$OUT' && python3 '$P/jig/jig.py' staging check case.md"
msg="staging check: an after: naming a file already in the target's staging passes"
stage y.md this doc new docs/y.md
hdr next.md north-star 'kind: doc\n' docs/n.md 'after: y.md\n'
expect_pass sh -c "cd '$OUT' && python3 '$P/jig/jig.py' staging check next.md"
msg="staging check: a cycle in the batch fails, naming it"
hdr c1.md north-star 'kind: doc\n' docs/c1.md 'after: c2.md\n'
hdr c2.md north-star 'kind: doc\n' docs/c2.md 'after: c1.md\n'
out=$(cd "$OUT" && python3 "$P/jig/jig.py" staging check c1.md c2.md 2>&1); rc=$?
expect_pass sh -c "test $rc -ne 0 && echo \"\$0\" | grep -q 'in a cycle with c2.md'" "$out"

msg="repos: NorthStar and north-star are flagged on the list, with both paths"
NS="$T/NorthStarDir"; mkdir -p "$NS"
$J repos add NorthStar "$NS" >/dev/null
out=$($J repos 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'NorthStar and north-star' && echo \"\$0\" | grep -q 'NorthStarDir\$' && echo \"\$0\" | grep -q '/sb\$'" "$out"
msg="staging check: a target with a near-duplicate in the list is warned about, and still passes"
out=$(cd "$OUT" && python3 "$P/jig/jig.py" staging check good.md 2>&1); rc=$?
expect_pass sh -c "test $rc -eq 0 && echo \"\$0\" | grep -q 'warning: .*both in the repos list'" "$out"
msg="repos add: adding a near-duplicate name warns"
expect_pass sh -c "$J repos add North_Star '$T' | grep -q 'warning: North_Star'"
msg="repos rename: renaming to a near-duplicate name warns"
$J repos rename North_Star other >/dev/null
expect_pass sh -c "$J repos rename other north.star | grep -q 'warning: .*north.star'"
}


# ---------------------------------------------------------------- update's project sweep
sec_sweep() {
SW="$T/sweep"; pcnew "$SW" && mkdir -p docs && printf "# Q\n\nQ is.\n" > docs/q.md && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
UP="python3 $P/jig/jig.py update"
printf '# P\n\nP keeps the list.\n\nBuilt as .jig/specs/x.md says, in phase 3.\n\n## Status\n\nhalf done\n\n## Undefined\n\n- Sync over BLE — stops at the GATT table; parked 2026-11-01.\n- Dark theme — stops at the palette;\n  parked 2026-11-02.\n' > docs/p.md
printf -- '- [ ] ship it\n' > TODO.md && printf '| Feature | Why |\n| x | y |\n' > FEATURES.md
git add -A && git -c core.hooksPath=/dev/null commit -qm planted
out=$($UP 2>&1)
msg="sweep: update lists each ## Undefined entry as the Up next item it would be, naming the page"
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/p.md: ## Undefined entry → .jig/roadmap.md ## Up next.*- .p-sync-over-ble.: Sync over BLE; stops at the GATT table; parked 2026-11-01 (touches docs/p.md)' && echo \"\$0\" | grep -q 'Dark theme; stops at the palette; parked 2026-11-02 (touches docs/p.md)'" "$out"
msg="sweep: a page line naming a spec, one saying phase 3, and a ## Status section are under Repo files to review"
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/p.md: line 5: \".jig/specs/\" names the plan' && echo \"\$0\" | grep -q '^  docs/p.md: line 5: \"phase 3\"' && echo \"\$0\" | grep -q '^  docs/p.md: ## Status is the project'" "$out"
msg="sweep: tracked TODO.md and FEATURES.md are each listed with their destination"
expect_pass sh -c "echo \"\$0\" | grep -q '^  TODO.md: the project.s plan: its items go to .jig/roadmap.md' && echo \"\$0\" | grep -q '^  FEATURES.md: the product: each feature goes to its system.s page'" "$out"
msg="sweep: --sweep alone is a dry run that changes nothing"
before=$(git status --porcelain); out=$($UP --sweep 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'Dry run' && test ! -e .jig/roadmap.md && test -z \"\$1\"" "$out" "$before"
msg="sweep: --apply --sweep creates .jig/roadmap.md with both under ## Up next, removes the section, and commits"
out=$($UP --apply --sweep 2>&1)
expect_pass sh -c "grep -qx '## Up next' .jig/roadmap.md && grep -q '^- .p-sync-over-ble.: Sync over BLE; stops at the GATT table; parked 2026-11-01 (touches docs/p.md)\$' .jig/roadmap.md && grep -q 'parked 2026-11-02 (touches docs/p.md)\$' .jig/roadmap.md && ! grep -q Undefined docs/p.md && grep -q '^half done' docs/p.md && git commit -qm sweep" "$out"
msg="sweep: a second dry run says nothing about it"
out=$($UP 2>&1); expect_pass sh -c "! echo \"\$0\" | grep -q 'Undefined' && $UP --sweep | grep -q 'nothing to sweep'" "$out"
msg="sweep: on a branch, --apply --sweep with entries trunk's roadmap lacks is refused, naming trunk (R5)"
printf '\n## Undefined\n\n- Export — stops at CSV; parked 2026-11-03.\n' >> docs/p.md && git add -A && git -c core.hooksPath=/dev/null commit -qm more
git switch -q -c side && out=$($UP --apply --sweep 2>&1); rc=$?; git switch -q main
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'edited on main only (R5)' && grep -q Undefined docs/p.md" "$out"
git reset -q --hard HEAD~1 && git branch -qD side

# A struck released entry: a ### Removed line naming it is what lets it go.
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release']['artifacts'] = ['dist/*.zip']" && printf 'dist/\n' > .gitignore
ulog '### D-002 ids are numbers
Accepted (owner, 2026-11-01).
Touches: docs/p.md' && ulog '### D-001 Demo priorities: A, then B
Accepted (owner, 2026-11-01).
Touches: docs/p.md' && git add -A && git commit -qm "D-001, D-002" && $J release --minor >/dev/null
msg="sweep: a released D-001 Demo priorities is listed as a project candidate, D-002 isn't"
out=$($UP 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q '^  .jig/decisions.md: D-001 Demo priorities: A, then B reads as project scope.*strike, split or keep' && ! echo \"\$0\" | grep -q 'D-002 ids'" "$out"
msg="sweep: removing released D-001 with no ### Removed line naming it is refused"
rment D-001 && git add -A; out=$(git commit -qm drop 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'D-001 is removed from release v0.1.0.*### Removed.*in the same commit'" "$out"
msg="sweep: a ### Removed line naming D-002 doesn't let D-001 go"
ulog '### Removed
- D-002: project scope, not a product decision.' && rment D-001 && git add -A; expect_refuse git commit -qm drop; undo
msg="sweep: removing it with an Unreleased ### Removed line naming D-001 commits, the release's other lines kept"
ulog '### Removed
- D-001: project scope, not a product decision.' && rment D-001 && git add -A
expect_pass sh -c "git commit -qm 'D-001: struck' && ! grep -q '^### D-001' .jig/decisions.md && grep -qx '### D-002 ids are numbers' .jig/decisions.md"

# Before --merge-log: a register's priority row and a Pending delivery section are listed, and a struck row is left out.
SR2="$T/sweep-reg"; pcnew "$SR2" && printf '# Decisions\n\n| Id | Decision | Status | Date |\n|---|---|---|---|\n| D-001 | ids are numbers | accepted | 2026-11-01 |\n| D-002 | Demo priorities: 1) radio 2) screen | accepted | 2026-11-02 |\n\n## Pending delivery to the app\n\n- the radio patch\n' > DECISIONS.md
git add -A && git commit -qm init && $J init >/dev/null 2>&1 && git add -A && git commit -qm board
out=$($UP 2>&1)
msg="sweep: before --merge-log, update lists the register's priority row and its Pending delivery section, not the ids row"
expect_pass sh -c "echo \"\$0\" | grep -q '^  DECISIONS.md: row D-002 Demo priorities.*reads as project scope' && echo \"\$0\" | grep -q '^  DECISIONS.md: lines .* .## Pending delivery to the app. read as project scope' && ! echo \"\$0\" | grep -q 'row D-001'" "$out"
msg="sweep: a row whose Status says struck is left out of the log --merge-log writes, its number named"
sed -i.bak 's/| accepted | 2026-11-02 |/| struck | 2026-11-02 |/' DECISIONS.md && rm DECISIONS.md.bak && git add -A && git commit -qm "D-002: struck"
out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "grep -qx '### D-001 ids are numbers' .jig/decisions.md && ! grep -q '^### D-002' .jig/decisions.md && grep -q 'Struck as project scope before this log, and left out of it: D-002' .jig/decisions.md && echo \"\$0\" | grep -q 'D-002: struck as project scope, left out'" "$out"

# In a metarepo the roadmap is trunk's (R5) and the pages a job's (M4): two runs.
SM2="$T/sweep-meta"; mkdir -p "$SM2" && cd "$SM2" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init --meta >/dev/null 2>&1 && git add -A && git commit -qm "GLOSSARY: board"
mkdir -p docs/g && printf '# A\n\nA is.\n\n## Undefined\n\n- Export — stops at CSV; parked 2026-11-03.\n' > docs/g/a.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "GLOSSARY: a"
msg="sweep: on a metarepo's trunk --apply --sweep writes the roadmap only, and names a job for the pages"
out=$($UP --apply --sweep 2>&1)
expect_pass sh -c "grep -q '^- .a-export.: Export; stops at CSV; parked 2026-11-03 (touches docs/g/a.md)' .jig/roadmap.md && grep -q Undefined docs/g/a.md && echo \"\$0\" | grep -q 'jig open project-sweep --shares docs/g/a.md' && git commit -qm 'TOOL: up next'" "$out"
$J open project-sweep --shares docs/g/a.md >/dev/null && git add -A && git commit -qm "TOOL: open project-sweep"
msg="sweep: in the job's worktree --apply --sweep removes the section whose entries trunk's roadmap holds, and commits"
cd .git/jig/worktrees/project-sweep && out=$($UP --apply --sweep 2>&1) && ulog '- GLOSSARY: parked work leaves the pages.'
expect_pass sh -c "! grep -q Undefined docs/g/a.md && echo \"\$0\" | grep -q 'already there' && git add -A && git commit -qm 'GLOSSARY: sweep'" "$out"

# Review fixes: two sections on one page, not_docs, an entry file, the Removed line's form.
SW3="$T/sweep-more"; pcnew "$SW3" && mkdir -p docs/BigPage docs/old && printf '# Q\n\nQ is.\n' > docs/q.md && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
printf '# T\n\nT is.\n\n## Undefined\n\n- One — stops at a; parked 2026-11-01.\n\n## Invariants\n\n- T holds — why; held by test_t.\n\n## Undefined\n\n- Two — stops at b; parked 2026-11-02.\n\n## Tail\n\nTail text.\n' > docs/t.md
printf '# Big\n\nBig is.\n\n## Undefined\n\n- Sync stuff — stops at x; parked 2026-11-01.\n' > docs/BigPage/BigPage.md
printf '# Old\n\nOld is.\n\n## Undefined\n\n- Kept — stops at y; parked 2026-11-01.\n' > docs/old/TODO.md
board "b['not_docs'] = ['docs/old/**']" && git add -A && git -c core.hooksPath=/dev/null commit -qm planted
out=$($UP 2>&1)
msg="sweep: update skips not_docs pages and plan-named files under it, and lowercases a page stem in ids"
expect_pass sh -c "! echo \"\$0\" | grep -q 'docs/old/' && echo \"\$0\" | grep -q '.bigpage-sync-stuff.: Sync stuff'" "$out"
msg="sweep: a page with two ## Undefined sections around Invariants loses both, keeping Invariants and Tail, written once"
out=$($UP --apply --sweep 2>&1)
expect_pass sh -c "! grep -q Undefined docs/t.md && grep -qx '## Invariants' docs/t.md && grep -qx '## Tail' docs/t.md && grep -qx 'Tail text.' docs/t.md && grep -q 'T holds' docs/t.md && grep -q '(touches docs/t.md)' .jig/roadmap.md && test \$(grep -c 'touches docs/t.md' .jig/roadmap.md) = 2 && test \$(echo \"\$0\" | grep '^Written' | grep -o 'docs/t.md' | wc -l) = 1 && grep -q Undefined docs/old/TODO.md && git commit -qm sweep" "$out"
msg="sweep: a ### Removed line that mentions D-001 in a sentence doesn't let released D-001 go"
sed -i.bak '/^# TODO: release protocol/d' .jig/scripts/release.sh && rm .jig/scripts/release.sh.bak
printf 'mkdir -p dist && printf x > "dist/app-$version.zip"\n' >> .jig/scripts/release.sh
board "b['release']['artifacts'] = ['dist/*.zip']" && printf 'dist/\n' > .gitignore
ulog '### D-002 ids are numbers
Accepted (owner, 2026-11-01).
Touches: docs/q.md' && ulog '### D-001 Demo priorities: A, then B
Accepted (owner, 2026-11-01).
Touches: docs/q.md' && git add -A && git commit -qm "D-001, D-002" && $J release --minor >/dev/null
ulog '### Removed
- The JSON fallback D-001 left in place.' && rment D-001 && git add -A; out=$(git commit -qm drop 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'D-001 is removed from release.*in the same commit'" "$out"
msg="sweep: a ### Removed line naming an id the log still has is refused"
ulog '### Removed
- D-002: project scope, not a product decision.' && git add -A; out=$(git commit -qm keep 2>&1); rc=$?; undo
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'strikes an entry the log still has'" "$out"
msg="sweep: - D-1: counts as D-001, by number, and lets it go"
ulog '### Removed
- D-1: project scope, not a product decision.' && rment D-001 && git add -A
expect_pass sh -c "git commit -qm 'D-001: struck' && ! grep -q '^### D-001' .jig/decisions.md"

msg="sweep: in a metarepo, an ## Undefined section on an entry file outside docs/ is listed and swept"
SM3="$T/sweep-entry"; mkdir -p "$SM3" && cd "$SM3" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init && $J init --meta >/dev/null 2>&1 && git add -A && git commit -qm "GLOSSARY: board"
setentry .jig/decisions.md README.md 'products/**' && mkdir -p products && printf '# W\n\nW is.\n\n## Undefined\n\n- Pairing — stops at keys; parked 2026-11-04.\n' > products/w.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "GLOSSARY: w"
out=$($UP 2>&1); out2=$($UP --apply --sweep 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  products/w.md: ## Undefined entry' && grep -q '(touches products/w.md)' .jig/roadmap.md" "$out" "$out2"

# A struck register row in an old-shape metarepo: M2 takes it, M3 asks its CHANGELOG line, and the job's merge leaves it out.
SO="$T/sweep-old"; mkdir -p "$SO/.t" && git -C "$JR" archive v0.9.0 plugin/templates | tar -x -C "$SO/.t"
cd "$SO" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r .t/plugin/templates/jig .jig && cp .t/plugin/templates/AGENTS.md .t/plugin/templates/CLAUDE.md . && rm -rf .t
git add -A && git commit -qm init && $J init --meta --name so >/dev/null && git add -A && git commit -qm meta-init && $J release >/dev/null
cp "$P/jig/jig.py" .jig/jig.py && git add -A && git commit -qm "TOOL: this jig"
$J open o1 --shares DECISIONS.md CHANGELOG.md >/dev/null && git add -A && git commit -qm "TOOL: open o1"
(cd .git/jig/worktrees/o1 && printf '| D-001 | radio first | superseded by D-002 | 2026-11-01 |\n| D-002 | Demo priorities: 1) radio 2) screen | accepted | 2026-11-02 |\n| D-003 | ids are numbers | accepted | 2026-11-02 |\n' >> DECISIONS.md \
  && printf -- '- D-001, D-002, D-003\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001, D-002, D-003: rows" && $J reviewed >/dev/null \
  && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "TOOL: note o1")
$J merge o1 >/dev/null 2>&1
msg="sweep: old-shape metarepo: update lists the priority row before --merge-log"
out=$($UP 2>&1); expect_pass sh -c "echo \"\$0\" | grep -q '^  DECISIONS.md: row D-002 Demo priorities.*reads as project scope'" "$out"
$J open ml --shares DECISIONS.md CHANGELOG.md README.md >/dev/null && git add -A && git commit -qm "TOOL: open ml"
cd .git/jig/worktrees/ml
msg="sweep: old-shape metarepo: a row struck with no CHANGELOG.md line is refused (M3)"
sed -i.bak 's/| accepted | 2026-11-02 |$/| struck | 2026-11-02 |/;/D-003/s/| struck |/| accepted |/' DECISIONS.md && rm DECISIONS.md.bak && git add -A
out=$(git commit -qm "D-002: struck" 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'M3 DECISIONS.md changed: add a line to CHANGELOG.md' && ! echo \"\$0\" | grep -q 'M2 a decision row'" "$out"
msg="sweep: old-shape metarepo: with its CHANGELOG.md line, the struck row commits (M2 takes struck)"
printf -- '- D-002: struck, project scope\n' >> CHANGELOG.md && git add -A && expect_pass git commit -qm "D-002: struck"
msg="sweep: --merge-log refuses while the struck D-002 supersedes D-001, naming both"
out=$($UP --merge-log 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'D-001 is superseded by D-002, which is struck: strike D-001 too'" "$out"
msg="sweep: D-001 struck too, the job's --apply --merge-log leaves both out of the log and keeps D-003"
sed -i.bak 's/| superseded by D-002 |/| struck |/' DECISIONS.md && rm DECISIONS.md.bak && printf -- '- D-001: struck, project scope\n' >> CHANGELOG.md && git add -A && git commit -qm "D-001: struck" >/dev/null 2>&1
out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "grep -qx '### D-003 ids are numbers' .jig/decisions.md && ! grep -q '^### D-00[12]' .jig/decisions.md && grep -q 'left out of it: D-001, D-002' .jig/decisions.md && git commit -qm 'TOOL: merge the log'" "$out"
}

# ---------------------------------------------------------------- derive.sh at jig merge
sec_merge_derived() {
MD="$T/derive"; FLAG="$T/derive-fail"; LOG="$T/derive-setup.log"
pcnew "$MD" && mkdir -p src && for f in b d f h j l; do printf 'x=1\n' > src/$f.py; done
printf 'base\n' > shared.txt && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
msg="derive: after init, .jig/scripts/derive.sh is executable and exits 0"
expect_pass sh -c "test -x .jig/scripts/derive.sh && .jig/scripts/derive.sh"
# mdjob <job> <source> [regen]: a job adding one source, handed off; regen also commits INDEX.md.
mdjob() {
  $J open "$1" --owns "src/$2" --shares INDEX.md shared.txt >/dev/null && git add -A && git commit -qm "open $1"
  ( cd ".git/jig/worktrees/$1" && printf 'x=1\n' > "src/$2" && { [ -z "${3:-}" ] || .jig/scripts/derive.sh; } \
    && git add -A && git commit -qm "$1: $2" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 \
    && pcfold && git add -A && git commit -qm "note $1" )
}
fresh() { .jig/scripts/derive.sh && git diff --quiet -- INDEX.md; }
derived() { python3 -c "import json,sys; f='.jig/config.json'; d=json.load(open(f)); d['derived_files']=sys.argv[1:]; json.dump(d, open(f,'w'), indent=2)" "$@"; }
parents() { git log -1 --format=%P | wc -w | tr -d ' '; }

mdjob H0 c0.py; git merge -q --no-ff --no-edit H0 2>/dev/null
msg="derive: with no derived_files, a job already in trunk merges without the stale-files line"
out=$($J merge H0 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! echo \"\$0\" | grep -q \"didn't run\"" "$out"

mdjob T0 c.py
msg="derive: with the template's derive.sh, jig merge prints no derived: line and commits the job's files and its entry, nothing more"
out=$($J merge T0 2>&1)
want=$( { git diff --name-only HEAD^1 HEAD^2; echo .jig/jobs.json; } | sort -u)
expect_pass sh -c "! echo \"\$0\" | grep -q '^derived:' && test \"\$(git diff --name-only HEAD^1 HEAD | sort)\" = \"\$1\"" "$out" "$want"

cat > .jig/scripts/derive.sh <<DER
#!/bin/sh
set -eu
cd "\$(dirname "\$0")/../.."
[ ! -e "$FLAG" ] || exit 3
{ echo "count: \$(ls src | wc -l | tr -d ' ')"; ls src; } > INDEX.md
DER
printf '#!/bin/sh\npwd -P >> "%s"\n' "$LOG" > .jig/scripts/setup.sh
derived INDEX.md && .jig/scripts/derive.sh && git add -A && git commit -qm "derive INDEX.md"

mdjob A a.py; mdjob B e.py
for j in A B; do
  msg="derive: jig merge $j, which never touched INDEX.md, exits 0, prints derived: INDEX.md, and commits it current in the merge commit"
  out=$($J merge $j 2>&1); rc=$?
  expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'derived: INDEX.md' && test -z \"\$(git status --porcelain)\" && test $(parents) = 2 && git diff --name-only HEAD^1 HEAD | grep -qx INDEX.md && $(declare -f fresh); fresh" "$out"
done

# The symptom: two jobs regenerate from their own sources; git merges their copies cleanly, wrong.
mdjob C a0.py regen; mdjob D z9.py regen
$J merge C >/dev/null 2>&1
msg="derive: two jobs that each committed a regenerated INDEX.md merge cleanly, and trunk's INDEX.md counts both"
out=$($J merge D 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && grep -qx 'count: 12' INDEX.md && grep -qx a0.py INDEX.md && grep -qx z9.py INDEX.md && test -z \"\$(git status --porcelain)\"" "$out"

mdjob E k.py; touch "$FLAG"
msg="derive: a derive.sh that exits 3 stops jig merge before its commit: exit 1, MERGE_HEAD, stderr naming derive.sh, 3 and jig merge --number"
err=$($J merge E 2>&1 >/dev/null); rc=$?
expect_pass sh -c "test $rc = 1 && git rev-parse -q --verify MERGE_HEAD && echo \"\$0\" | grep -q '.jig/scripts/derive.sh exited 3' && echo \"\$0\" | grep -q 'jig merge --number'" "$err"
rm "$FLAG"
msg="derive: once fixed, jig merge --number and git commit leave INDEX.md current and the tree clean"
expect_pass sh -c "$J merge --number && git commit -q --no-edit && test -z \"\$(git status --porcelain)\" && grep -qx k.py INDEX.md && $(declare -f fresh); fresh"

mdjob F m.py; touch "$FLAG"; $J merge F >/dev/null 2>&1
msg="derive: after a failed derive, git merge --abort puts F's entry back"
expect_pass sh -c "git merge --abort && grep -q '\"F\"' .jig/jobs.json && test -z \"\$(git status --porcelain --untracked-files=no)\""
rm "$FLAG"

mdjob G n.py
(cd .git/jig/worktrees/G && printf 'job\n' > shared.txt && git commit -qam "G: shared" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note G again")
printf 'trunk\n' > shared.txt && git commit -qam "trunk: shared"
msg="derive: a merge that stops on a source conflict no longer says to run setup.sh after the commit"
err=$($J merge G 2>&1); rc=$?
expect_pass sh -c "test $rc = 1 && echo \"\$0\" | grep -q '^  shared.txt' && ! echo \"\$0\" | grep -q 'then run .*setup.sh'" "$err"
printf 'both\n' > shared.txt && git add shared.txt && : > "$LOG"
msg="derive: once resolved, jig merge --number runs setup.sh once and writes INDEX.md; the commit leaves the tree clean"
out=$($J merge --number 2>&1)
expect_pass sh -c "test \$(wc -l < '$LOG' | tr -d ' ') = 1 && echo \"\$0\" | grep -qx 'derived: INDEX.md' && git commit -q --no-edit && test -z \"\$(git status --porcelain)\" && grep -qx n.py INDEX.md" "$out"

mdjob H o.py; git merge -q --no-ff --no-edit H 2>/dev/null; touch "$FLAG"
msg="derive: a job already in trunk merges with no derive run, saying derived files may be stale: exit 0, its entry gone, the tree clean"
out=$($J merge H 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! grep -q '\"H\"' .jig/jobs.json && test -z \"\$(git status --porcelain)\" && ! echo \"\$0\" | grep -q '^derived:' && echo \"\$0\" | grep -q \"derive.sh didn't run: a hand merge leaves derived files stale\"" "$out"
rm "$FLAG"

printf 'cp INDEX.md índice.md\n' >> .jig/scripts/derive.sh && derived INDEX.md índice.md && .jig/scripts/derive.sh && git add -A && git commit -qm "derive: a non-ASCII name"
mdjob U p.py
msg="derive: a file derive.sh writes under a non-ASCII name is staged and committed with the merge"
out=$($J merge U 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'derived: INDEX.md, índice.md' && test -z \"\$(git status --porcelain)\" && grep -qx p.py índice.md" "$out"

printf '#!/bin/sh\n.jig/scripts/derive.sh\n' > .jig/scripts/setup.sh && git commit -qam "setup runs the generator too"
mdjob V q.py
msg="derive: when setup.sh writes the derived file too, the merge still commits it and leaves trunk clean"
out=$($J merge V 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q '^derived: INDEX.md' && test -z \"\$(git status --porcelain)\" && grep -qx q.py INDEX.md" "$out"

printf '{}\n' > lock.json && printf '#!/bin/sh\n[ "$(git branch --show-current)" = main ] || exit 0\necho $$ > lock.json\n' > .jig/scripts/setup.sh
git add -A && git commit -qm "setup rewrites a tracked lockfile on trunk"
mdjob W r.py
msg="derive: a tracked file setup.sh rewrote is warned about and left out of the merge commit"
out=$($J merge W 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'changed and not committed: lock.json' && ! echo \"\$0\" | grep '^derived:' | grep -q lock.json && ! git diff --name-only HEAD^1 HEAD | grep -qx lock.json" "$out"
git checkout -q -- lock.json && printf '#!/bin/sh\nexit 0\n' > .jig/scripts/setup.sh && git commit -qam "setup quiet"

cat > .jig/scripts/derive.sh <<DER
#!/bin/sh
set -eu
cd "\$(dirname "\$0")/../.."
{ echo "count: \$(ls src | wc -l | tr -d ' ')"; ls src; } > INDEX.md
[ ! -e "$FLAG" ] || exit 3
DER
git commit -qam "derive writes, then may fail"
mdjob X s.py; touch "$FLAG"; $J merge X >/dev/null 2>&1; rm "$FLAG"
msg="derive: a derived file a failed run already wrote lands: --number and the commit leave it current and the tree clean"
out=$($J merge --number 2>&1)
expect_pass sh -c "git commit -q --no-edit && test -z \"\$(git status --porcelain)\" && git show HEAD:INDEX.md | grep -qx s.py && $(declare -f fresh); fresh" "$out"

printf 'old\n' > old.md && printf 'rm -f old.md\n' >> .jig/scripts/derive.sh && derived INDEX.md old.md && git add -A && git commit -qm "derive deletes old.md"
mdjob Y t.py
msg="derive: a tracked file derive.sh deletes is staged as deleted: listed, gone from the merge commit, the tree clean"
out=$($J merge Y 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'derived: INDEX.md, old.md' && ! git cat-file -e HEAD:old.md 2>/dev/null && test -z \"\$(git status --porcelain)\"" "$out"

# Writes INDEX.md only on a difference, and recreates gen/: a failed run's correct write must
# still land, and an untracked file it removes has nothing to stage.
cat > .jig/scripts/derive.sh <<DER
#!/bin/sh
set -eu
cd "\$(dirname "\$0")/../.."
tmp=\$(mktemp); { echo "count: \$(ls src | wc -l | tr -d ' ')"; ls src; } > "\$tmp"
cmp -s "\$tmp" INDEX.md && rm -f "\$tmp" || mv "\$tmp" INDEX.md
rm -rf gen && mkdir gen && : > gen/index.md
[ ! -e "$FLAG" ] || exit 3
DER
derived INDEX.md "gen/**" && .jig/scripts/derive.sh && git add -A && git commit -qm "derive writes on a difference"
mdjob Z u.py; touch "$FLAG"; $J merge Z >/dev/null 2>&1; rm "$FLAG"; touch gen/stray.md
msg="derive: after a failed run, a rerun that finds INDEX.md current and removes an untracked file still commits INDEX.md current and leaves the tree clean"
out=$($J merge --number 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && git commit -q --no-edit && test -z \"\$(git status --porcelain)\" && git show HEAD:INDEX.md | grep -qx u.py" "$out"

# The final review's two: a failed atomic write's temp file, and a hand run before --number.
cat > .jig/scripts/derive.sh <<DER
#!/bin/sh
set -eu
cd "\$(dirname "\$0")/../.."
tmp=\$(mktemp INDEX.md.XXXXXX)
{ echo "count: \$(ls src | wc -l | tr -d ' ')"; ls src; } > "\$tmp"
[ ! -e "$FLAG" ] || exit 3
cmp -s "\$tmp" INDEX.md && rm -f "\$tmp" || mv "\$tmp" INDEX.md
DER
derived INDEX.md && git add -A && git commit -qm "derive: atomic, writes on a difference"
mdjob N1 v.py; touch "$FLAG"; $J merge N1 >/dev/null 2>&1; rm "$FLAG"
msg="derive: a failed run's temp file is not committed; --number and the commit leave INDEX.md current"
out=$($J merge --number 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'derived: INDEX.md' && git commit -q --no-edit && ! git diff --name-only HEAD^1 HEAD | grep -q 'INDEX.md\.' && git show HEAD:INDEX.md | grep -qx v.py && test -z \"\$(git status --porcelain --untracked-files=no)\"" "$out"
rm -f INDEX.md.??????
msg="derive: after a failed run, git merge --abort leaves the tracked tree clean"
mdjob N2 w.py; touch "$FLAG"; $J merge N2 >/dev/null 2>&1; rm "$FLAG"
expect_pass sh -c "git merge --abort && grep -q '\"N2\"' .jig/jobs.json && test -z \"\$(git status --porcelain --untracked-files=no)\""
rm -f INDEX.md.??????

mdjob N3 x.py
(cd .git/jig/worktrees/N3 && printf 'job3\n' > shared.txt && git commit -qam "N3: shared" && $J reviewed >/dev/null && $J handoff >/dev/null 2>&1 && pcfold && git add -A && git commit -qm "note N3 again")
printf 'trunk3\n' > shared.txt && git commit -qam "trunk: shared again"
$J merge N3 >/dev/null 2>&1; printf 'both3\n' > shared.txt && git add shared.txt && .jig/scripts/derive.sh
msg="derive: a hand run of a write-on-a-difference derive before --number still lands: INDEX.md current in the commit, the tree clean"
out=$($J merge --number 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -qx 'derived: INDEX.md' && git commit -q --no-edit && test -z \"\$(git status --porcelain)\" && git show HEAD:INDEX.md | grep -qx x.py" "$out"

printf 'echo y > undeclared.md\n' >> .jig/scripts/derive.sh && printf 'n\n' > undeclared.md && git add -A && git commit -qm "derive writes an undeclared tracked file"
mdjob N4 y.py
msg="derive: a tracked file derive.sh writes outside derived_files is named and not committed"
out=$($J merge N4 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'changed and not committed: undeclared.md' && ! git diff --name-only HEAD^1 HEAD | grep -qx undeclared.md && git diff --name-only HEAD^1 HEAD | grep -qx INDEX.md" "$out"
git checkout -q -- undeclared.md

mdjob N5 z.py; derived INDEX.md "gen/**" "docs/reference" && git commit -qam "derived: gen and a typo"
printf 'draft\n' > gen/scratch-draft.md
msg="derive: an untracked file matching derived_files refuses the merge before it starts, naming it"
err=$($J merge N5 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'untracked gen/scratch-draft.md matches derived_files: remove or commit it' && ! git rev-parse -q --verify MERGE_HEAD && grep -q '\"N5\"' .jig/jobs.json" "$err"
rm gen/scratch-draft.md
msg="derive: a derived_files glob that matches nothing after derive ran is named"
out=$($J merge N5 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'derived_files glob docs/reference matches no file' && ! echo \"\$0\" | grep -q 'glob gen/'" "$out"

git checkout -q -- undeclared.md; mdjob N6 zz.py; mkdir -p sub
msg="derive: jig merge run from a subdirectory isn't refused for tracked derived files, and commits INDEX.md"
out=$(cd sub && python3 ../.jig/jig.py merge N6 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! echo \"\$0\" | grep -q 'matches derived_files' && git show HEAD:INDEX.md | grep -qx zz.py" "$out"
git checkout -q -- undeclared.md 2>/dev/null
}

# ---------------------------------------------------------------- the findings record
sec_findings() {
FR="$T/findings"; pcnew "$FR" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/a/b docs/a/c docs/old src/a src/b src/c && printf '# A\n\nThe a system.\n' > docs/a/a.md
printf '# B\n\n## Part\n\nThe b part, with no lead paragraph.\n' > docs/a/b/b.md && printf '# C\n\nThe c part.\n' > docs/a/c/c.md
printf '# X\n\nnotes\n' > docs/old/x.md && printf '# App\n\nSee [b](docs/a/b/b.md).\n' > README.md
printf 'x\n' > src/a/a.rs && printf 'x\n' > src/b/b.rs && printf 'x\n' > src/c/c.rs
board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/b/b.md': ['src/b/**'], 'docs/a/c/c.md': ['src/c/**']}"
git add -A && git commit -qm pages
msg="findings: survey --json gives b and c their shape ids, outcome null, and the stray no id"
expect_pass python3 -c "
import json, subprocess
r = json.loads(subprocess.check_output(['python3', '.jig/jig.py', 'survey', '--json']))
got = sorted((e['id'], e['outcome']) for e in r['page_shapes'])
assert got == [('shape:docs/a/b/b.md', None), ('shape:docs/a/c/c.md', None)], got
assert [('id' in e) for e in r['homeless'] if e['path'] == 'docs/old/x.md'] == [False], r['homeless']"
msg="findings: survey marks each not answered, and its last line counts only the findings it shows with an id"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/b/b.md: flat at docs/a/b.md.*\[shape:docs/a/b/b.md: not answered\]' && echo \"\$0\" | grep -q '^  docs/a/c/c.md: .*not answered' && echo \"\$0\" | grep -q '^  docs/a/b/b.md: .*\[contract:docs/a/b/b.md: not answered\]' && test \$(echo \"\$0\" | grep -c 'not answered\]') = 3 && echo \"\$0\" | tail -1 | grep -q '3 findings not answered: run /jig:update'" "$out"
msg="findings: with no entry, update --apply leaves both pages where they are"
$UP --apply >/dev/null 2>&1
expect_pass sh -c "test -f docs/a/b/b.md && test -f docs/a/c/c.md && test -z \"\$(git status --porcelain)\""
board "b['findings'] = {'shape:docs/a/b/b.md': 'approved', 'contract:docs/a/b/b.md': 'exception: the lead is the table', 'shape:docs/a/c/c.md': 'deferred: redocument'}"
git add -A && git commit -qm "findings: b approved, c deferred"
msg="findings: update --apply carries out the approved move, moves b's other entry with it, leaves the deferred one"
out=$($UP --apply 2>&1)
renamed docs/a/b/b.md docs/a/b.md; mv_rc=$?
expect_pass sh -c "test $mv_rc = 0 && test -f docs/a/c/c.md && python3 -c \"
import json; b = json.load(open('.jig/config.json'))
assert b['findings'] == {'contract:docs/a/b.md': 'exception: the lead is the table', 'shape:docs/a/c/c.md': 'deferred: redocument'}, b['findings']
assert 'docs/a/b.md' in b['docmap'] and 'docs/a/b/b.md' not in b['docmap'], b['docmap']\"" "$out"
msg="findings: what the move leaves for the session is printed: README.md names the old path"
expect_pass sh -c "echo \"\$0\" | sed -n '/^Left for the session/,/^\$/p' | grep -q '^  README.md:3: '" "$out"
git commit -qm "update: b moved"
msg="findings: survey prints c deferred to redocument, b's exception at its new path, and no shape line for b"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/c/c.md: .*\[shape:docs/a/c/c.md: deferred: redocument\]' && echo \"\$0\" | grep -q '\[contract:docs/a/b.md: exception: the lead is the table\]' && ! echo \"\$0\" | grep -q 'docs/a/b/b.md'" "$out"
remap() { printf '# Redocument: the remap\n\n| # | Old path(s) | New path | Verb | Notes |\n|---|---|---|---|---|\n| 1 | `docs/a/c/c.md` | %s | rewrite | |\n%b' "$1" "${2:-}" > .jig/redocument.md; }
msg="findings: the hook refuses a remap keeping c where survey moves it, naming the path, its destination and findings"
remap same && git add .jig/redocument.md
out=$(git commit -qm remap 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | grep -q 'keeps docs/a/c/c.md where it is, and survey moves it to docs/a/c.md' && echo \"\$0\" | grep -q 'findings'" "$out"
undo
msg="findings: a remap keeping c while another row gives its folder company commits: judged on the tree it leaves"
remap same '| 2 | `docs/old/x.md` | `docs/a/c/x.md` | move | |\n' && git add .jig/redocument.md
expect_pass git commit -qm "remap: x joins c"
git rm -q .jig/redocument.md && git commit -qm "remap: gone"
msg="findings: an exception with no reason still refuses, and survey lists it, and a deep exception, as no answer"
board "b['findings'] = {'shape:docs/a/c/c.md': 'exception: ', 'deep:docs/a/c/d': 'exception: why not'}" && git add -A && git commit -qm "findings: empty exception"
out=$($J survey 2>&1)
remap same && git add .jig/redocument.md
out2=$(git commit -qm remap 2>&1); rc=$?
expect_pass sh -c "test $rc != 0 && echo \"\$0\" | sed -n '/findings entries that count as no answer/,/^\$/p' | grep -q '^  shape:docs/a/c/c.md: nothing after its colon' && echo \"\$0\" | grep -q '^  deep:docs/a/c/d: .*deep_subsystems'" "$out"
undo
msg="findings: with the owner's reason recorded, the remap commits, and survey prints the exception"
board "b['findings'] = {'shape:docs/a/c/c.md': 'exception: the generator reads folder paths'}" && git add -A && git commit -qm "findings: c's exception"
remap same && git add .jig/redocument.md
out=$(git commit -qm remap 2>&1 && $J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/c/c.md: .*\[shape:docs/a/c/c.md: exception: the generator reads folder paths\]'" "$out"
msg="findings: a row that moves c commits with no entry"
board "del b['findings']" && git add -A && git commit -qm "findings: none"
remap '`docs/a/c.md`' && git add .jig/redocument.md
expect_pass git commit -qm "remap: move c"
msg="findings: survey names a remap on trunk that keeps c, and its last line counts it"
remap same && git add .jig/redocument.md && git -c core.hooksPath=/dev/null commit -qm "remap: keep c, past the hook"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^Remap rows that keep a page where survey moves it' && echo \"\$0\" | grep -q '^  docs/a/c/c.md: survey moves it to docs/a/c.md' && echo \"\$0\" | tail -1 | grep -q '1 remap row keeping a page survey moves'" "$out"

msg="findings: an exception the remap check asked for outlives update --apply while the remap stands"
printf '# Z\n\nz notes\n' > docs/a/c/z.md && git add -A && git commit -qm "z beside c"
board "b['findings'] = {'shape:docs/a/c/c.md': 'exception: the generator reads folder paths'}" && git add -A && git commit -qm "findings: c"
remap same '| 2 | `docs/a/c/z.md` | `docs/a/z.md` | move | |\n' && git add .jig/redocument.md && git commit -qm "remap: z out" >/dev/null 2>&1
$UP --apply >/dev/null 2>&1
expect_pass python3 -c "
import json; b = json.load(open('.jig/config.json'))
assert b['findings'] == {'shape:docs/a/c/c.md': 'exception: the generator reads folder paths'}, b.get('findings')"
undo
msg="findings: update lists a deep page's contract finding with its id, as survey counts it"
mkdir -p docs/a/c/d && printf '# D\n\n## Part\n\nNo lead.\n' > docs/a/c/d/d.md && git add -A && git commit -qm "d below c" >/dev/null 2>&1
out=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/c/d/d.md: off the page contract.*\[contract:docs/a/c/d/d.md: not answered\]'" "$out"

# A page that changed form by hand settles its move's answer; its other answers follow it.
FI="$T/findings-follow"; pcnew "$FI" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/a/x docs/a/b && printf '# A\n\nThe a system.\n' > docs/a/a.md && printf '# X\n\nThe x part.\n' > docs/a/x/x.md
printf '# B\n\n## Part\n\nB, with no lead.\n' > docs/a/b/b.md
board "b['docmap'] = {'docs/a/x/x.md': ['src/x/**'], 'docs/a/b/b.md': ['src/b/**']}; b['findings'] = {'shape:docs/a/x/x.md': 'approved', 'contract:docs/a/b/b.md': 'exception: table lead'}"
git add -A && git commit -qm pages
git mv docs/a/x/x.md docs/a/x.md && mkdir -p docs/a/x && printf 'n\n' > docs/a/x/notes.md && printf 'f\n' > docs/a/x/fig.txt
printf '[notes](x/notes.md) [fig](x/fig.txt)\n' >> docs/a/x.md && git add -A && git -c core.hooksPath=/dev/null commit -qm "x flat by hand, then company"
msg="findings: a move's answer doesn't follow a page that changed form, so --apply never makes the opposite move"
$UP --apply >/dev/null 2>&1 && git commit -qm "update" >/dev/null 2>&1; $UP --apply >/dev/null 2>&1
expect_pass sh -c "test -f docs/a/x.md && ! git diff --cached --name-status | grep -q '^R' && python3 -c \"
import json; b = json.load(open('.jig/config.json'))
assert not any(k.startswith('shape:') for k in b.get('findings', {})), b.get('findings')\""
undo

# An answer stays where the owner put it: jig moves one only with its own move, and never drops an exception.
fpages() {  # fpages <dir>: a, and b off the contract with its exception recorded and its shape deferred
  pcnew "$1" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
  mkdir -p docs/a/b && printf '# A\n\nThe a system.\n' > docs/a/a.md && printf '# B\n\n## Part\n\nB, with no lead.\n' > docs/a/b/b.md
  board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/b/b.md': ['src/b/**']}; b['findings'] = {'contract:docs/a/b/b.md': 'exception: table lead', 'shape:docs/a/b/b.md': 'deferred: redocument'}"
  git add -A && git commit -qm "b and its answers"; }
H='# Redocument: the remap\n\n| # | Old path(s) | New path | Verb | Notes |\n|---|---|---|---|---|\n'
recis() { python3 -c "import json,sys; b = json.load(open('.jig/config.json')); assert b.get('findings') == json.loads(sys.argv[1]), b.get('findings')" "$1"; }
fpages "$T/findings-rename"
git mv docs/a/b/b.md docs/a/q.md && board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/q.md': ['src/b/**']}" && git add -A && git commit -qm "a job renames b to q"
msg="findings: a job's rename leaves b's exception where the owner put it; --apply drops only the deferral"
$UP --apply >/dev/null 2>&1 && git commit -qm update >/dev/null 2>&1
expect_pass recis '{"contract:docs/a/b/b.md": "exception: table lead"}'
msg="findings: survey lists the exception as answering no finding, counts it, and shows q's contract finding not answered"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | sed -n '/exceptions that answer no finding/,/^\$/p' | grep -q '^  contract:docs/a/b/b.md: exception: table lead' && echo \"\$0\" | grep -q '\[contract:docs/a/q.md: not answered\]' && echo \"\$0\" | tail -1 | grep -q '1 exception answering no finding: drop each on trunk, or record it at the page.s new path' && echo \"\$0\" | tail -1 | grep -q '1 finding not answered: run /jig:update'" "$out"
msg="findings: an entry whose kind has no id, or a typo, is listed as no answer"
board "b['findings']['stray:docs/x.md'] = 'exception: kept'; b['findings']['shapes:docs/a/q.md'] = 'approved'" && git add -A && git commit -qm "findings: odd keys"
out=$($J survey 2>&1)
expect_pass sh -c "echo \"\$0\" | sed -n '/findings entries that count as no answer/,/^\$/p' | grep -q '^  stray:docs/x.md: no finding has the kind stray' && echo \"\$0\" | grep -q '^  shapes:docs/a/q.md: no finding has the kind shapes'" "$out"
fpages "$T/findings-taken"
board "b['findings'] = {'shape:docs/a/b/b.md': 'approved', 'contract:docs/a/b/b.md': 'exception: NEW', 'contract:docs/a/b.md': 'exception: OLD'}" && git add -A && git commit -qm "two exceptions for b"
msg="findings: the dry run already says which entry a move will leave at its old id"
expect_pass sh -c "$UP 2>&1 | grep -q 'contract:docs/a/b/b.md: left at its old id, since contract:docs/a/b.md is already recorded'"
msg="findings: a carried-out move never renames an entry onto an id already recorded, and says so"
out=$($UP --apply 2>&1)
expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['findings'] == {'contract:docs/a/b/b.md': 'exception: NEW', 'contract:docs/a/b.md': 'exception: OLD'}, b['findings']\" && echo \"\$0\" | grep -q 'contract:docs/a/b/b.md: left at its old id, since contract:docs/a/b.md is already recorded'" "$out"
fpages "$T/findings-merge"
printf 'n\n' > docs/a/notes.md && printf '[notes](notes.md)\n' >> docs/a/a.md && git add -A && git commit -qm "a has notes"
printf "$H| 1 | \`docs/a/a.md\` | same | rewrite | |\n| 2 | \`docs/a/b/b.md\` | \`docs/a/a.md\` | merge | into a |\n" > .jig/redocument.md && git add -A && git commit -qm remap
git rm -q docs/a/b/b.md && board "b['docmap'].pop('docs/a/b/b.md')" && git add -A && git commit -qm "b merged into a"
msg="findings: a merge keeps b's exception, and survey holds back the unused list while the remap is on trunk"
$UP --apply >/dev/null 2>&1 && git commit -qm update >/dev/null 2>&1
out=$($J survey 2>&1)
expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['findings'] == {'contract:docs/a/b/b.md': 'exception: table lead'}, b['findings']\" && ! echo \"\$0\" | grep -q 'answer no finding'" "$out"
fpages "$T/findings-split"
printf "$H| 1 | \`docs/a/b/b.md\` | \`docs/a/e.md\` | split | first half |\n| 2 | \`docs/a/b/b.md\` | \`docs/a/f.md\` | split | second half |\n" > .jig/redocument.md && git add -A && git commit -qm remap
printf '# E\n\n## Part\n\nFirst half.\n' > docs/a/e.md && printf '# F\n\n## Part\n\nSecond half.\n' > docs/a/f.md
git rm -q docs/a/b/b.md && board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/e.md': ['src/b/x/**'], 'docs/a/f.md': ['src/b/y/**']}" && git add -A && git commit -qm "b split"
msg="findings: a split puts b's exception on neither half; e and f are not answered"
$UP --apply >/dev/null 2>&1 && git commit -qm update >/dev/null 2>&1
out=$($J survey 2>&1)
expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['findings'] == {'contract:docs/a/b/b.md': 'exception: table lead'}, b['findings']\" && echo \"\$0\" | grep -q '\[contract:docs/a/e.md: not answered\]' && echo \"\$0\" | grep -q '\[contract:docs/a/f.md: not answered\]'" "$out"
fpages "$T/findings-redocument"
printf "$H| 1 | \`docs/a/b/b.md\` | \`docs/a/e.md\` | move | |\n" > .jig/redocument.md
board "b['findings']['contract:docs/a/e.md'] = 'exception: table lead'" && git add -A && git commit -qm "step 2-3: the remap, b's exception recorded at e"
printf '# E\n\n## Part\n\nB rewritten, table lead kept.\n' > docs/a/e.md && board "b['docmap']['docs/a/e.md'] = ['src/b/**']" && git add -A && git commit -qm "e's job merged"
git rm -q docs/a/b/b.md .jig/redocument.md && board "b['docmap'].pop('docs/a/b/b.md'); [b['findings'].pop(k) for k in ('contract:docs/a/b/b.md', 'shape:docs/a/b/b.md')]" && git add -A && git commit -qm "step 6: cleanup"
msg="findings: by the book, redocument ends with the exception at e, survey showing it, and no exception unused"
$UP --apply >/dev/null 2>&1; git commit -qm update >/dev/null 2>&1
out=$($J survey 2>&1)
expect_pass sh -c "python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['findings'] == {'contract:docs/a/e.md': 'exception: table lead'}, b['findings']\" && echo \"\$0\" | grep -q '\[contract:docs/a/e.md: exception: table lead\]' && ! echo \"\$0\" | grep -q 'answer no finding'" "$out"

pcnew "$T/findings-onto-one" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p notes misc docs && printf '# B\n\nThe b system.\n' > notes/b.md && printf '# B2\n\nAnother b.\n' > misc/b.md && printf '# A\n\nThe a system.\n' > docs/a.md
board "b['docmap'] = {'docs/a.md': ['src/a/**'], 'notes/b.md': ['src/b/**'], 'misc/b.md': ['src/c/**']}; b['findings'] = {'page:notes/b.md': 'approved', 'page:misc/b.md': 'approved'}"
git add -A && git commit -qm "two pages approved onto docs/b.md"
msg="findings: two approved moves onto one path: the dry run holds one back, and --apply moves one and keeps the other recorded"
dry=$($UP 2>&1); out=$($UP --apply 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'held back' && test \$(git diff --cached --name-status | grep -c '^R') = 1 && python3 -c \"
import json; b = json.load(open('.jig/config.json')); assert len(b['findings']) == 1 and list(b['findings'].values()) == ['approved'], b['findings']\"" "$dry"
undo
pcnew "$T/findings-case" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p notes misc docs && printf '# B\n\nThe B system.\n' > notes/B.md && printf '# b\n\nThe b system.\n' > misc/b.md && printf '# A\n\nThe a system.\n' > docs/a.md
board "b['docmap'] = {'docs/a.md': ['src/a/**'], 'notes/B.md': ['src/b/**'], 'misc/b.md': ['src/c/**']}; b['findings'] = {'page:notes/B.md': 'approved', 'page:misc/b.md': 'approved'}"
git add -A && git commit -qm "two pages approved onto docs/B.md and docs/b.md"
msg="findings: destinations differing only in case are one path: --apply moves one and holds the other back"
out=$($UP --apply 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && echo \"\$0\" | grep -q 'held back' && test \$(git diff --cached --name-status | grep -c '^R') = 1" "$out"
undo
pcnew "$T/findings-dest" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p notes docs && printf '# B\n\nThe b system.\n' > notes/b.md && printf '# A\n\nThe a system.\n' > docs/a.md
board "b['docmap'] = {'docs/a.md': ['src/a/**'], 'notes/b.md': ['src/b/**']}; b['findings'] = {'page:notes/b.md': 'approved', 'section:notes/b.md': 'exception: keep', 'section:docs/b.md': 'deferred: later'}"
git add -A && git commit -qm "a stale deferral at the destination id"
msg="findings: the dry run and --apply agree when a stale deferral sits on the destination id"
dry=$($UP 2>&1); $UP --apply >/dev/null 2>&1
expect_pass sh -c "! echo \"\$0\" | grep -q 'left at its old id' && python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['findings'] == {'section:docs/b.md': 'exception: keep'}, b['findings']\"" "$dry"
undo
pcnew "$T/findings-flagged" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p docs/a/b && printf '# A\n\nThe a system.\n' > docs/a/a.md && printf '# B\n\nThe b part.\n' > docs/a/b/b.md
board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/b/b.md': ['src/b/**']}; b['findings'] = {'shape:docs/a/b/b.md ': 'approved'}"
git add -A && git commit -qm "an approval with a trailing space"
msg="findings: --apply never drops an entry survey lists as no answer"
$UP --apply >/dev/null 2>&1
expect_pass sh -c "test -f docs/a/b/b.md && python3 -c \"import json; b = json.load(open('.jig/config.json')); assert b['findings'] == {'shape:docs/a/b/b.md ': 'approved'}, b['findings']\" && $J survey 2>&1 | grep -q '^  shape:docs/a/b/b.md : the id has stray space'"
undo
pcnew "$T/findings-level" && git add -A && git commit -qm init && $J init >/dev/null && git add -A && git commit -qm board
mkdir -p src/a docs/a/s && echo x > src/a/x.py && printf '# A\n\nThe a system.\n\n[s](s/s.md)\n' > docs/a/a.md && printf '# S\n\nThe s part.\n\n[n](n.txt)\n' > docs/a/s/s.md && printf 'n\n' > docs/a/s/n.txt
board "b['docmap'] = {'docs/a/a.md': ['src/a/**'], 'docs/a/s/s.md': ['nothing/**']}"
git add -A && git commit -qm "s covers no file"
msg="findings: a page covering no file has a section id in survey and update, and survey's last line counts it"
sv=$($J survey 2>&1); up=$($UP 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q '^  docs/a/s/s.md: section: .*\[section:docs/a/s/s.md: not answered\]' && echo \"\$0\" | tail -1 | grep -q '1 finding not answered: run /jig:update' && echo \"\$1\" | grep -q '\[section:docs/a/s/s.md: not answered\]'" "$sv" "$up"

# A metarepo's pages move in a job (M4): trunk records the yes, and makes no move.
FM="$T/findings-meta"; mkdir -p "$FM" && cd "$FM" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r "$P/jig" .jig && cp "$P/AGENTS.md" "$P/CLAUDE.md" . && git add -A && git commit -qm init
$J init --meta --no-hooks >/dev/null && git add -A && git commit -qm meta
mkdir -p docs/g/p docs/g/q && printf '# P\n\nP is a thing.\n' > docs/g/p/p.md && printf '# Q\n\nQ is a thing.\n' > docs/g/q/q.md && git add -A && git commit -qm pages
msg="findings: in a metarepo, update --apply lists an approved move as a job's and makes none"
board "b['findings'] = {'shape:docs/g/p/p.md': 'approved'}" && git add -A && git commit -qm "findings: p"
out=$($UP --apply 2>&1)
expect_pass sh -c "echo \"\$0\" | grep -q 'a job.s in a metarepo (M4)' && echo \"\$0\" | grep -q '^  git mv docs/g/p/p.md docs/g/p.md' && test -f docs/g/p/p.md && ! git diff --cached --name-status | grep -q docs/g" "$out"
msg="findings: in a metarepo, survey's last line routes an approved move to a job"
expect_pass sh -c "$J survey 2>&1 | tail -1 | grep -q '1 finding approved and not done: move each in a job (M4)'"
nohook() { git -c core.hooksPath=/dev/null commit -qm "$1"; }
git add -A && nohook update
msg="findings: in a metarepo, after the job's move merged, --apply drops the approval and keeps the exception where it was"
printf '# Q\n\n## Part\n\nQ, with no lead.\n' > docs/g/q/q.md
board "b['findings']['contract:docs/g/q/q.md'] = 'exception: table lead'; b['findings']['shape:docs/g/q/q.md'] = 'approved'; b['docmap'] = {'docs/g/q/q.md': ['x/**']}"
git add -A && nohook "findings: q" && git mv docs/g/q/q.md docs/g/q.md && nohook "the job's move, merged"
$UP --apply >/dev/null 2>&1
expect_pass python3 -c "
import json; b = json.load(open('.jig/config.json'))
assert b['findings'] == {'shape:docs/g/p/p.md': 'approved', 'contract:docs/g/q/q.md': 'exception: table lead'}, b['findings']"
}

# ---------------------------------------------------------------- what --merge-log writes
# A register with a heading above its table and notes below, superseded rows whose who and date
# only history holds, and bare change lines: the run's output commits as written.
mlreg() {  # mlreg <D-002's status cell> <its date>: the register, D-002 as given
  printf '# Cross-product decisions\n\nWhat binds every product.\n\n| Id | Decision | Status | Date |\n|---|---|---|---|\n| D-001 | a | accepted (Ann) | 2026-01-01 |\n| D-002 | b | %s | %s |\n| D-003 | c | accepted (Cy) | 2026-02-01 |\n\nA note naming no row.\n\n## Glossary mapping\n\n| Term | Meaning |\n|---|---|\n| foo | bar |\n' "$1" "$2" > DECISIONS.md; }
mlchangelog() {
  printf '# Release notes\n\nFirst paragraph.\n\nEvery change to an entry file adds a line here; `jig release` turns Unreleased into the next version.\n\nSecond paragraph.\n\n## Unreleased\n- D-003 later\n\n## v1.0.0 — 2026-01-01\n- D-001, D-002 the first rules\n\n## v0.9.0 — 2025-12-01\n- an older line\n' > CHANGELOG.md; }
nocl() { python3 -c "
import sys, importlib.util as u
s = u.spec_from_file_location('j', '.jig/jig.py'); m = u.module_from_spec(s); s.loader.exec_module(m)
bad = [e['id'] for e in m.log_entries(open('.jig/decisions.md').read(), 'D-') if any(l.startswith('- ') for l in e['block'].splitlines())]
assert not bad, bad"; }
sec_merge_log() {
ML="$T/ml-plain"; pcnew "$ML" && mlchangelog && mlreg 'accepted (Bo)' 2026-01-01 && git add -A && git commit -qm init
mlreg 'superseded by D-003' 2026-02-01 && git add -A && git commit -qm "D-003 supersedes D-002"
$J init >/dev/null 2>&1 && git add -A && git commit -qm board
out=$($UP --apply --merge-log 2>&1)
msg="merge-log: the kept register has its heading, preamble and note, and no line of the decision table"
expect_pass sh -c "grep -qx '# Cross-product decisions' DECISIONS.md && grep -qx 'What binds every product.' DECISIONS.md && grep -qx 'A note naming no row.' DECISIONS.md && ! grep -qE '^\| (D-0|Id )|^\|---\|---\|---\|---\|' DECISIONS.md"
msg="merge-log: the kept register's lines are the old ones less the decision table, in order, a note's own table kept whole"
expect_pass sh -c "test \"\$(git show HEAD:DECISIONS.md | grep -v '^\$' | grep -v '^| D-0' | grep -vxF '| Id | Decision | Status | Date |' | grep -vxF '|---|---|---|---|')\" = \"\$(grep -v '^\$' DECISIONS.md)\" && grep -qxF '|---|---|' DECISIONS.md"
msg="merge-log: the changelog preamble keeps both paragraphs and drops the old seed line"
expect_pass sh -c "test \"\$(cat CHANGELOG.md)\" = \"\$(printf '# Release notes\n\nFirst paragraph.\n\nSecond paragraph.')\""
msg="merge-log: a superseded row takes its who and date from the register's history"
expect_pass sh -c "grep -qx 'Accepted (Bo, 2026-01-01).' .jig/decisions.md && ! grep -q 'not recorded' .jig/decisions.md && ! echo \"\$0\" | grep -q 'D-002: superseded'" "$out"
msg="merge-log: no entry's block holds a change line"
expect_pass nocl
msg="merge-log: bare change lines get ### Changed above them, in Unreleased and in a release"
expect_pass sh -c "sed -n '/^## Unreleased/,/^## v1/p' .jig/decisions.md | grep -A2 -x '### Changed' | grep -qx -- '- D-003 later' && sed -n '/^## v1.0.0/,\$p' .jig/decisions.md | grep -A2 -x '### Changed' | grep -qx -- '- D-001, D-002 the first rules'"
msg="merge-log: each release keeps its own change lines"
expect_pass sh -c "sed -n '/^## v1.0.0/,/^## v0.9.0/p' .jig/decisions.md | grep -qx -- '- D-001, D-002 the first rules' && ! sed -n '/^## v1.0.0/,/^## v0.9.0/p' .jig/decisions.md | grep -q 'older line' && sed -n '/^## v0.9.0/,\$p' .jig/decisions.md | grep -qx -- '- an older line'"
msg="merge-log: the run's output commits unedited"
expect_pass git commit -qm "TOOL: merge the log"
$J open rm >/dev/null 2>&1 && git add -A && git commit -qm "open rm" && cd .git/jig/worktrees/rm
msg="merge-log: a later job removes the superseded D-002, last in its release, by its heading and status line"
python3 -c "f='.jig/decisions.md'; s=open(f).read(); b='### D-002 b\nAccepted (Bo, 2026-01-01).\n\n'; assert b in s; open(f,'w').write(s.replace(b, ''))" && git add -A
expect_pass git commit -qm "D-002: removed, D-003 supersedes it"
git reset -q --hard HEAD~1
msg="merge-log: removing the release's change lines with it is refused as frozen"
python3 -c "f='.jig/decisions.md'; s=open(f).read(); b='### D-002 b\nAccepted (Bo, 2026-01-01).\n\n### Changed\n\n- D-001, D-002 the first rules\n'; assert b in s; open(f,'w').write(s.replace(b, ''))" && git add -A
out=$(git commit -qm "D-002: removed" 2>&1); undo
expect_pass sh -c "echo \"\$0\" | grep -q 'release v1.0.0 is frozen'" "$out"
cd "$ML"

msg="merge-log: a row superseded in its only commit converts as not recorded, and the run names it"
ML1="$T/ml-one"; pcnew "$ML1" && mlchangelog && mlreg 'superseded by D-003' 2026-02-01 && git add -A && git commit -qm init && $J init >/dev/null 2>&1 && git add -A && git commit -qm board
out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "grep -qx 'Accepted (not recorded, 2026-02-01).' .jig/decisions.md && echo \"\$0\" | grep -q '^  D-002: superseded, .* who accepted it or when: check'" "$out"
msg="merge-log: no converted entry reads not recorded without the run naming it"
expect_pass sh -c "for i in \$(grep -B1 'not recorded' .jig/decisions.md | sed -n 's/^### \(D-[0-9]*\) .*/\1/p'); do echo \"\$0\" | grep -q \"^  \$i: superseded\" || exit 1; done" "$out"

msg="merge-log: a row proposed, then superseded, is never dated as accepted from its proposal: the run names it"
ML2="$T/ml-prop"; pcnew "$ML2" && mlchangelog && mlreg 'proposed (Bo)' 2026-01-02 && git add -A && git commit -qm init
mlreg 'superseded by D-003' 2026-02-01 && git add -A && git commit -qm sup && $J init >/dev/null 2>&1 && git add -A && git commit -qm board
out=$($UP --apply --merge-log 2>&1)
expect_pass sh -c "grep -qx 'Accepted (not recorded, 2026-02-01).' .jig/decisions.md && ! grep -q 'Bo' .jig/decisions.md && echo \"\$0\" | grep -q '^  D-002: superseded, .* or when: check'" "$out"

msg="merge-log: a second decision table with its own header, and one headed No., leave no header or separator behind"
ML3="$T/ml-tables"; pcnew "$ML3" && mlchangelog
printf '# Register\n\nKept.\n\n## Current\n\n| Id | Decision | Status | Date |\n|---|---|---|---|\n| D-001 | a | accepted (Ann) | 2026-01-01 |\n\n## Retired\n\n| Id | Decision | Status | Date | Why |\n|---|---|---|---|---|\n| D-002 | b | rejected | 2026-01-01 | too slow |\n| D-005 | e | accepted (Ed) | 2026-01-01 | cheap |\n\n## Moved\n\n| Id | Status | Date | Decision | Why |\n|---|---|---|---|---|\n| D-004 | accepted (Bo) | 2026-02-01 | b wins | speed |\n\n## Later\n\n| Id | Status | Date | Decision |\n|---|---|---|---|\n| TBD | placeholder | | |\n| D-006 | accepted (Fy) | 2026-03-01 | f wins |\n' > DECISIONS.md
mkdir -p bare && printf '# Bare register\n\nKept as well.\n\n| D-007 | g | accepted (Gu) | 2026-03-02 |\n|---|---|---|---|\n| D-008 | h | accepted (Gu) | 2026-03-03 |\n' > bare/DECISIONS.md
mkdir -p sub && printf '# Sub register\n\nKept too.\n\n| No. | Decision | Status | Date |\n|---|---|---|---|\n| D-003 | c | accepted (Cy) | 2026-02-01 |\n' > sub/DECISIONS.md
git add -A && git commit -qm init && $J init >/dev/null 2>&1 && git add -A && git commit -qm board
$UP --apply --merge-log >/dev/null 2>&1
expect_pass sh -c "grep -qx 'Kept.' DECISIONS.md && grep -qx '## Retired' DECISIONS.md && grep -qx 'Kept too.' sub/DECISIONS.md && ! grep -q '^|' sub/DECISIONS.md && ! grep -qE '^\| (D-0|Id \| Decision)|^\|---\|---\|---\|---\|---\|' DECISIONS.md && test \$(grep -cxF '|---|---|---|---|' DECISIONS.md) = 1"
msg="merge-log: each row is read against its own table's header: columns in another order, and an extra column's name"
expect_pass sh -c "grep -qx '### D-004 b wins' .jig/decisions.md && grep -qx 'Accepted (Bo, 2026-02-01).' .jig/decisions.md && grep -qx 'Why: speed' .jig/decisions.md && grep -qx 'Why: cheap' .jig/decisions.md && ! grep -q '^Note: ' .jig/decisions.md"
msg="merge-log: a table whose first row is no decision reads its rows by its own header, and keeps that row with its header"
expect_pass sh -c "grep -qx '### D-006 f wins' .jig/decisions.md && grep -qx 'Accepted (Fy, 2026-03-01).' .jig/decisions.md && grep -qxF '| TBD | placeholder | | |' DECISIONS.md && grep -qxF '| Id | Status | Date | Decision |' DECISIONS.md"
msg="merge-log: a register with no header row keeps every row, the first included, and leaves no separator"
expect_pass sh -c "grep -qx '### D-007 g' .jig/decisions.md && grep -qx '### D-008 h' .jig/decisions.md && grep -qx 'Kept as well.' bare/DECISIONS.md && ! grep -q '^|' bare/DECISIONS.md"
msg="merge-log: a row that comes out as no entry, whatever the cause, refuses the run, naming it, and writes nothing"
git reset -q --hard && git clean -fdq && out=$(python3 -c "
import sys, pathlib, importlib.util as u
s = u.spec_from_file_location('j', '$P/jig/jig.py'); m = u.module_from_spec(s); s.loader.exec_module(m)
orig = m.parse_register
m.parse_register = lambda t, p: (lambda r: ([e for e in r[0] if e['id'] != 'D-001'], r[1]))(orig(t, p))
sys.exit(m.cmd_merge_log(pathlib.Path('.').resolve(), True))" 2>&1); rc=$?
expect_pass sh -c "test $rc = 2 && echo \"\$0\" | grep -q 'DECISIONS.md: row D-001 came out as no entry' && test ! -e .jig/decisions.md && test -z \"\$(git status --porcelain)\"" "$out"

# A metarepo job: the run's output commits unedited, with no M3 and no M2 asking for Touches.
MM="$T/ml-meta"; mkdir -p "$MM/.t" && git -C "$JR" archive v0.9.0 plugin/templates | tar -x -C "$MM/.t"
cd "$MM" && git init -q -b main && git config user.email t@t && git config user.name t
cp -r .t/plugin/templates/jig .jig && cp .t/plugin/templates/AGENTS.md .t/plugin/templates/CLAUDE.md . && rm -rf .t
git add -A && git commit -qm init && $J init --meta --name mm >/dev/null && git add -A && git commit -qm meta-init
mlchangelog && mlreg 'accepted (Bo)' 2026-01-01 && git add -A && git -c core.hooksPath=/dev/null commit -qm rows
mlreg 'superseded by D-003' 2026-02-01 && git add -A && git -c core.hooksPath=/dev/null commit -qm "D-003 supersedes D-002"
cp "$P/jig/jig.py" .jig/jig.py && git add -A && git commit -qm "TOOL: this jig"
$UP --apply >/dev/null 2>&1; git add -A && git commit -qm "TOOL: update" >/dev/null 2>&1
$J open mlj --shares CHANGELOG.md DECISIONS.md >/dev/null 2>&1 && git add -A && git commit -qm "TOOL: open mlj"
cd .git/jig/worktrees/mlj && $UP --apply --merge-log >/dev/null 2>&1
msg="merge-log: in a metarepo job, the run's output commits unedited: no M3, no entry asked for its pages"
out=$(git commit -qm "TOOL: merge the log" 2>&1); rc=$?
expect_pass sh -c "test $rc = 0 && ! echo \"\$0\" | grep -q 'M3 ' && ! echo \"\$0\" | grep -q 'names no page it touches'" "$out"
msg="merge-log: across the merge, a pararepo's sync hears of no decision as changed, the history-dated D-002 included"
expect_pass python3 -c "
import importlib.util as u, pathlib
s = u.spec_from_file_location('j', '.jig/jig.py'); m = u.module_from_spec(s); s.loader.exec_module(m)
got = m.terms_changed(pathlib.Path('.').resolve(), 'HEAD~1', 'HEAD')
assert m.merged_registers(pathlib.Path('.').resolve(), 'HEAD~1', 'HEAD') and not got, got"
cd "$MM"
}

UNITS="rules merge_derived update board_split worktree_setup metarepo,staging pararepo release r6_takes,r6_ints merge_after_sync repos workflow init_old_board ledger_rows hardware update_per_file pararepo_commands entry_globs report_fixes sync_buffer pointers removals feedback slash_names homes structure meta_docs agents_lines page_contract roadmap boundary decisions supersede touches sweep staging_batches merge_log findings glossary"

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
