---
name: work
description: The work role - build a job's spec in its worktree, prove it with evidence, hand off, fix blocking findings and resolve syncs, all in one session. Use when a kickoff or the hubnode assigns the work role, or working alone on "build this", "hand off", "fix the findings", "sync my job".
---

`jig` below is `python3 .jig/jig.py`. Your settings are the work role's (`jig roles`). Your
steps are work, handoff, fix and sync; `jig next` decides what comes after each. One session
keeps the build through every fix and sync: you are that session.

## Brief

The hubnode starts this role with:

```
running <model> at <effort>
If your own model differs from this line, reply with only your running line and stop.
You are the subnode for job <name>, in the work role. Run /jig:subnode, then /jig:work.
<the kickoff jig open printed: worktree, spec, owns, shares, reserved numbers>
```

A fix or a sync on the same job continues this session with a message, never a new one.

## Work

While working, run `.jig/scripts/check.sh` and the parts of the suite your change touched,
never `check.sh --full`: the complete check is the check role's, once per gate or batch.

- Your files are your `owns`, your `shares`, `common`, and anything new you create. If you
  need another, ask the hubnode to add it to `shares` and build elsewhere meanwhile.
- Your numbers are the board's. Never take one by looking at what seems free.
- A choice that outlives your spec, or a change a release's reader can act on, goes in
  `.jig/decisions.md` (`.jig/RULES.md`, Decision log), which any job may add to. Write a new
  decision as `### D-?<slug> <title>`; `jig merge` numbers it. To change an accepted entry
  trunk has, supersede it with a new accepted entry and remove the old one in the same commit.
- Keep merges mechanical: append rather than edit shared prose; new routes in your own
  handler registered by one line; new tests in your own file; a new fixture as a new file.
- Commit often. The hook runs the rules; when it refuses, fix the cause. Never `--no-verify`.

## Evidence

Pick the cheapest check that is actually evidence:

| Change touches | Check |
|---|---|
| Pure logic (parsing, hashing, state machines) | Unit test. Write it first if the behavior is non-obvious. |
| Display / UI rendering | Emulator screenshot, then hardware when it looks right. |
| Driver, bus, peripheral, timing | Hardware. Serial log the agent can read. Emulation only if the board's page (the one `boards` in `.jig/config.json` lists for it) says that peripheral is modeled. |
| Build config, linker, partitions | Build + flash + boot log. |

- Compiled is not verified. A green build earns the right to flash, nothing more.
- Show the output: the command, the result, the log line that proves it. Don't summarize it away.
- Running jig in a throwaway repo? There, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.
- A run that can outlast your shell's foreground time limit goes in the background, with its output to a file, and you act on its exit notice. Where the shell gives no notice, start it with `cmd > out 2>&1 & echo $!`, then in each later command poll that literal pid for less than the limit: `for i in $(seq 50); do kill -0 <pid> 2>/dev/null || break; sleep 10; done`. A pid kept in a variable is gone by the next command, and the loop would end at once as if the run had. Cap the whole wait at about twice the run's usual time, then read the output and report what you see. Never wait on a match: a process pattern (`pgrep -f`, `ps | grep`) can match another waiter's or another run's command line, and a log line never comes from a run that dies early.
- If the check can't be run (no board attached, no emulator), say so explicitly and stop. Don't infer success.
- Prefer a check the next agent can re-run from `.jig/scripts/check.sh` over one that lived only in this session.

When the checks pass, report the commit and the commands with their output to the hubnode:
the review role runs next in a fresh session (`jig next`). Working alone, run `/jig:review`
yourself.

## Handoff

A handoff is a mergeable chunk, not the whole job — hand off as often as a coherent piece
is done. It follows a review with no blocking findings; `jig handoff` refuses while the
newest review recorded some.

1. `jig handoff --spec .jig/specs/<task>.md`. A chunk that doesn't finish its spec hands off
   with `--partial`, so the roadmap doesn't count the spec complete. The review is already
   recorded, by the review role. Never run `jig reviewed` yourself after it: it overwrites
   the tier and effort recorded.
2. Fill every heading in the note. Commit it with the work, and with the DEFERRED.md rows
   for the review's untaken findings: rows added there after the review don't count as a change.
3. Message the hubnode: the job, the commit, the note's path. Then keep building, or wait.

## Fix

The review's blocking findings come back to this session as a fix. Fix them, run the checks
the fix touched, commit, and report: a review-change runs next, in a fresh session, on what
changed since the last recorded review. Every should-fix or optional finding you don't take
gets a row in `.jig/ledgers/DEFERRED.md` with its rank and one reason, tagged `[seen]` or
`[assumed]`; the first row creates the file from
`${CLAUDE_PLUGIN_ROOT}/templates/ledgers/DEFERRED.md`. Three fix rounds that end blocking are
the limit: jig refuses the next review until the bug role's spec for the job is committed.

## Sync

When trunk moves: `jig sync`. Append-only collisions resolve themselves, and a clean sync
needs no new review. Anything else stops with the files named — resolve those with the other
job's section open, run the checks, commit, and report: a hand-resolved sync gets a
review-change (`jig next`) before the next handoff.

## Never

Push or merge: every push and merge happens in the hubnode's session. Review your own diff in this context: a review is always a fresh one.
