#!/usr/bin/env bash
# Plugin hook. Delegates to the repo's own .jig/scripts/check.sh — but only in a repo that
# opted in. The marker lives in .git/, which is never cloned or committed, so a repo
# you fetched from someone else cannot turn this on for itself and get its scripts run.
# `jig init` / `jig install-hooks` writes it.
# Repos set up by older jigs keep it under `jig/` or in a root `scripts/`; without
# the fallback that repo would lose its checks silently on a plugin update.
# It runs the quick level only (no argument): the complete one is the check step's.
set -u
repo="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$repo" 2>/dev/null || exit 0
gitdir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ -f "$gitdir/jig/enabled" ] || exit 0
# jig's own copy runs as itself when executable, so a repo may write it in any language;
# through bash when not, so a lost executable bit can't switch it off. The older paths must
# still be executable: a root scripts/check.sh may be the repo's own, not jig's.
run=()
s="$repo/.jig/scripts/check.sh"
if [ -f "$s" ]; then
  if [ -x "$s" ]; then run=("$s"); else run=(bash "$s"); fi
else
  for s in "$repo/jig/scripts/check.sh" "$repo/scripts/check.sh"; do
    [ -x "$s" ] && { run=("$s"); break; }
  done
fi
[ ${#run[@]} -gt 0 ] || exit 0

# A session ends a turn many times with nothing changed; rerunning the check then proves
# nothing new. The key is the tree git would commit from this worktree, untracked files
# included, hashed through a temporary index so the real one (and anything staged) is left
# alone. Per worktree: each job's tree is its own.
here=$(git rev-parse --absolute-git-dir 2>/dev/null)
state="$here/jig"
tree=""
if [ -n "$here" ]; then
  tmp=$(mktemp "${TMPDIR:-/tmp}/jig-index.XXXXXX")
  # Seeded from the real index, so unchanged files are not hashed again.
  cp "$(git rev-parse --path-format=absolute --git-path index)" "$tmp" 2>/dev/null || rm -f "$tmp"
  tree=$(GIT_INDEX_FILE="$tmp" git add -A >/dev/null 2>&1 && GIT_INDEX_FILE="$tmp" git write-tree 2>/dev/null)
  rm -f "$tmp"
  # A submodule enters the tree as its HEAD alone, so edits inside one would read as no change.
  git status --porcelain=v2 --ignore-submodules=none 2>/dev/null | grep -qE '^[12] .. S(.M.|..U)' && tree=""
fi
if [ -n "$tree" ]; then
  [ "$(cat "$state/check-passed" 2>/dev/null)" = "$tree" ] && exit 0
  # The board and staged chat files are not code: a change to only those checks nothing.
  changed=$(git diff --name-only HEAD "$tree" 2>/dev/null) && [ -n "$changed" ] \
    && ! printf '%s\n' "$changed" | grep -qvE '^(\.jig/jobs\.json|\.jig/staging/.*)$' && exit 0
fi

start=$(date +%s)
"${run[@]}"
rc=$?
mkdir -p "$state" 2>/dev/null
# What each stop's check cost, so slow ones show up before they hit the hook's time limit.
printf '%s\tquick\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$(( $(date +%s) - start ))" "$rc" >> "$state/check.log" 2>/dev/null
[ "$rc" = 0 ] && [ -n "$tree" ] && printf '%s\n' "$tree" > "$state/check-passed"
exit "$rc"
