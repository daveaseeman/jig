---
name: check
description: The check role - fixed commands run from files alone, never in the trunk checkout - the complete suite in a gate's checkout or a detached worktree of trunk for a batch or a release, recorded with jig checked; the trace of a failed batch to its merge; a survey run. Use when `jig next` or the hubnode names check, trace or survey.
---

`jig` below is `python3 .jig/jig.py`. Your settings are the check role's (`jig roles`). Your
steps are check (before a release too), trace and survey: fixed commands, run in a new session that
needs nothing but files, never in the trunk checkout. You change nothing and fix nothing; you
run, record and report.
`jig next` decides what comes after.

## Brief

The hubnode starts this role with:

```
running <model> at <effort>
If your own model differs from this line, reply with only your running line and stop.
You are in the check role: run /jig:check. <the step>: in <checkout>, output to <out>.
```

For a job's gate, `<checkout>` is the scratch checkout `jig gate` printed. For a batch or a
release, it is a detached worktree of trunk's tip the hubnode made for you
(`git worktree add --detach .git/jig/worktrees/check-<trunk> <trunk>`): `jig checked` there
records trunk's commit, and the hubnode removes it after your report. `<out>` is `$(git rev-parse --git-common-dir)/jig/gate-<name>.out`, named
after the scratch checkout (`/` in the name as `-`), outside `worktrees/`, so it outlives the
checkout; a failure nobody can reproduce is reported with that path, so it can be read.

## Check

Run the complete check once, through the queue: `(cd <checkout> && python3 .jig/jig.py queue
--full -- ./.jig/scripts/check.sh --full)`, output to `<out>`, timed. It waits for a slot and for
any other complete check; jig holds the slot and never chooses what runs. When the suite makes repos, in any throwaway repo set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.

It outlasts your shell's foreground limit: start it in the background with its output to the
file, and act on its exit notice. Where the shell gives no notice, start it with
`cmd > out 2>&1 & echo $!`, then in each later command poll that literal pid for less than the
limit: `for i in $(seq 50); do kill -0 <pid> 2>/dev/null || break; sleep 10; done`. Cap the
whole wait at about twice the run's usual time (`jig status` prints the last one's), then read
the output. Never wait on a match: a process pattern can match another run's command line,
and a log line never comes from a run that dies early.

If it passes, record it in that checkout:
`jig checked --tier <N> --effort <N> --seconds <s>`, the check role's numbers. Report the
exit code, the seconds and the output's tail.

### Overflow to CI

Exit 3 from `jig queue --full` means the machine is full and the repo set `queue.overflow`,
the owner's standing yes for `jig-check/*` pushes (`.jig/RULES.md`, The queue). It printed
the route; take it, in the same checkout:

1. `git push <remote> HEAD:refs/heads/jig-check/<sha>`, as printed.
2. Watch the run of `jig-check.yml` on that branch (`gh run watch`) to its end.
3. If it passed: `jig checked --ci <run url> --tier <N> --effort <N> --seconds <the run's
   seconds>`. jig reads the run through `gh` and refuses unless it ran HEAD and succeeded.
4. `git push <remote> --delete jig-check/<sha>`, passed or not.

Report the run's URL, its result and the record. A failed run is reported like a failed local
one, with the URL in place of `<out>`.

## Trace

A batch's check on trunk failed. `jig checked --trace "<failing command>"`, in the same detached
worktree of trunk's tip, prints
the merges since the last complete check and the `git bisect --first-parent` run that finds
the one that broke it, running only the failing command at each step. Run it, `git bisect
reset` after, and report the merge it names: that job gets Fix.

## Survey run

`jig survey` (with `--json` when the hubnode asks), as `/jig:survey` says. Report what it
prints; the plan from it is the spec role's.

## Before a release

Before a release: the complete check, as Check says, in a detached worktree of trunk's tip,
recorded with `jig checked`. That is all of it. You never run `jig release`: it commits on
trunk, tags, and runs `publish.sh`, the push and the publish, which are the hubnode's on the
owner's word (`/jig:release`).

## Never

Edit a file, fix a failure, or rerun a passing check to grep it. Run a complete suite outside
`jig queue --full`. Push any branch but the `jig-check/<sha>` the overflow printed, or push
that one without `queue.overflow` set.
