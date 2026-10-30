---
name: subnode
description: Work one job in a repo with parallel jobs. Use at the start of a feature session, on a kickoff message, or on "work on job X", "hand off", "sync my job".
---

Read `.jig/RULES.md` first. `jig` below is `python3 .jig/jig.py`.

One job, one branch, one worktree. You never commit on trunk, never push trunk, never merge.

## Check in

1. Find your job on the board: `jig job`. If this branch is on no job, stop and ask
   the hubnode to open one. Never create a job branch yourself.
2. Work in the worktree the board names, nowhere else.
3. `jig check`. If you are behind trunk, `jig sync` and run the checks before changing
   anything.
4. Say in three lines: the job, its reserved numbers, what you will build first.

## Build

- Your files are your `owns`, your `shares`, `common`, and anything new you create. If you
  need another, ask the hubnode to add it to `shares` and build elsewhere meanwhile.
- Your numbers are the board's. Never take one by looking at what seems free.
- Keep merges mechanical: append rather than edit shared prose; new routes in your own
  handler registered by one line; new tests in your own file; a new fixture as a new file.
- Commit often. The hook runs the rules; when it refuses, fix the cause. Never `--no-verify`.

## Hand off

A handoff is a mergeable chunk, not the whole job — hand off as often as a coherent piece
is done.

1. Run the project's checks (`.jig/scripts/check.sh`, plus whatever `/jig:verify` calls for).
2. Have the diff adversarially reviewed: `/jig:review`. Fix anything blocking.
3. `jig reviewed` to record it, then `jig handoff --spec .jig/specs/<task>.md`.
4. Fill every heading in the note. Commit it with the work.
5. Message the hubnode: the job, the commit, the note's path. Then keep building, or wait.

Do not push. Every push and merge happens in the hubnode's session.

## When trunk moves

`jig sync`. Append-only collisions resolve themselves; anything else stops with the files
named — resolve those with the other job's section open, then run the checks.

## Never

Work in the trunk checkout. Switch anyone's branch. Touch a file outside your lists. Push or
merge. Edit the board.
