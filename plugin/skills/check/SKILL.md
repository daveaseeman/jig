---
name: check
description: The check role - fixed commands run from files alone - the complete suite in a gate's checkout or on trunk for a batch, recorded with jig checked; the trace of a failed batch to its merge; a survey run; a release run. Use when `jig next` or the hubnode names check, trace, survey or release run.
---

`jig` below is `python3 .jig/jig.py`. Your settings are the check role's (`jig roles`). Your
steps are check, trace, survey and release run: fixed commands, run in a new session that
needs nothing but files. You change nothing and fix nothing; you run, record and report.
`jig next` decides what comes after.

## Brief

The hubnode starts this role with:

```
running <model> at <effort>
If your own model differs from this line, reply with only your running line and stop.
You are in the check role: run /jig:check. <the step>: in <checkout>, output to <out>.
```

For a job's gate, `<checkout>` is the scratch checkout `jig gate` printed; for a batch, the
trunk checkout. `<out>` is `$(git rev-parse --git-common-dir)/jig/gate-<name>.out`, named
after the scratch checkout (`/` in the name as `-`), outside `worktrees/`, so it outlives the
checkout; a failure nobody can reproduce is reported with that path, so it can be read.

## Check

Run the complete check once: `(cd <checkout> && ./.jig/scripts/check.sh --full)`, output to
`<out>`, timed. When the suite makes repos, in any throwaway repo set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.

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

## Trace

A batch's check on trunk failed. `jig checked --trace "<failing command>"` on trunk prints
the merges since the last complete check and the `git bisect --first-parent` run that finds
the one that broke it, running only the failing command at each step. Run it, `git bisect
reset` after, and report the merge it names: that job gets Fix.

## Survey run

`jig survey` (with `--json` when the hubnode asks), as `/jig:survey` says. Report what it
prints; the plan from it is the spec role's.

## Release run

The release protocol, `/jig:release`, run on trunk with a clean tree, once the owner gave the
hubnode the word: the complete check, `jig release`, and what `release.sh` and `publish.sh`
print. `jig release` ends by running `publish.sh`, the push and the publish: the owner's word
for the release covers them, and the hubnode reports them.

## Never

Edit a file, fix a failure, or rerun a passing check to grep it. Run a second complete suite
while one runs on this machine.
