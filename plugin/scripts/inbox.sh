#!/usr/bin/env bash
# Plugin hook, on UserPromptSubmit. In the trunk checkout of a jig repo whose .jig/inbox/ holds
# unread messages, prints one line with their count and the command that reads them. It reads
# and moves nothing: a subnode session may have the trunk folder as its project too, and only
# the hubnode's `jig inbox` marks a message read. Anywhere else (no .jig/, a job's worktree, an
# empty inbox, a repo that never ran `jig install-hooks`) it prints nothing. Always exits 0, so
# it can never block a prompt.
set -u
cat >/dev/null 2>&1   # the event's JSON: the prompt itself doesn't matter here
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
[ "$(cd "$top" && pwd -P)" = "$(cd "$(dirname "$common")" && pwd -P)" ] || exit 0
# Only in a repo that opted in, as check.sh: the marker is in .git/, which a fetched repo
# can't bring with it.
[ -f "$common/jig/enabled" ] || exit 0
n=$(find "$top/.jig/inbox" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
[ "${n:-0}" -gt 0 ] || exit 0
s=""; [ "$n" = 1 ] || s="s"
echo "jig: $n unread message$s in .jig/inbox/ for this repo's hubnode: \`python3 .jig/jig.py inbox\` shows and marks them read."
exit 0
