#!/usr/bin/env bash
# Plugin hook, on UserPromptSubmit. When this session is the trunk checkout of a jig repo and
# .jig/inbox/ holds an unread message, runs the repo's own `jig inbox`: it prints each one into
# the turn and marks it read, so a ruling a rigger sent reaches the hubnode with the owner's
# next prompt. Anywhere else (no .jig/, a job's worktree, an empty inbox, a jig.py without the
# command, a repo that never ran `jig install-hooks`) it prints nothing. Always exits 0, so it
# can never block a prompt.
set -u
cat >/dev/null 2>&1   # the event's JSON: the prompt itself doesn't matter here
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
# A subnode's worktree never reads the hubnode's inbox.
[ "$(cd "$top" && pwd -P)" = "$(cd "$(dirname "$common")" && pwd -P)" ] || exit 0
# It runs the repo's own jig.py, so only in a repo that opted in, as check.sh: the marker is
# in .git/, which a fetched repo can't bring with it.
[ -f "$common/jig/enabled" ] || exit 0
[ -f "$top/.jig/jig.py" ] || exit 0
ls "$top/.jig/inbox/"*.md >/dev/null 2>&1 || exit 0
cd "$top" && python3 .jig/jig.py inbox 2>/dev/null
exit 0
