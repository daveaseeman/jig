#!/usr/bin/env bash
# Plugin hook. Delegates to the repo's own scripts/check.sh — but only in a repo that
# opted in. The marker lives in .git/, which is never cloned or committed, so a repo
# you fetched from someone else cannot turn this on for itself and get its scripts run.
# `jig init` / `jig install-hooks` writes it.
set -u
repo="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$repo" 2>/dev/null || exit 0
gitdir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ -f "$gitdir/jig/enabled" ] || exit 0
[ -x "$repo/scripts/check.sh" ] && exec "$repo/scripts/check.sh"
exit 0
