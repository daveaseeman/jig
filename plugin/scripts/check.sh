#!/usr/bin/env bash
# Plugin hook. Delegates to the repo's own .jig/scripts/check.sh — but only in a repo that
# opted in. The marker lives in .git/, which is never cloned or committed, so a repo
# you fetched from someone else cannot turn this on for itself and get its scripts run.
# `jig init` / `jig install-hooks` writes it.
# Repos set up by older jigs keep it under `jig/` or in a root `scripts/`; without
# the fallback that repo would lose its checks silently on a plugin update.
set -u
repo="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$repo" 2>/dev/null || exit 0
gitdir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ -f "$gitdir/jig/enabled" ] || exit 0
# jig's own copy runs as itself when executable, so a repo may write it in any language;
# through bash when not, so a lost executable bit can't switch it off. The older paths must
# still be executable: a root scripts/check.sh may be the repo's own, not jig's.
s="$repo/.jig/scripts/check.sh"
if [ -f "$s" ]; then [ -x "$s" ] && exec "$s"; exec bash "$s"; fi
for s in "$repo/jig/scripts/check.sh" "$repo/scripts/check.sh"; do
  [ -x "$s" ] && exec "$s"
done
exit 0
