---
name: bug
description: The bug role - investigate a cause before any diff exists (whys, givens tagged seen or assumed, one layer up, workaround or correction) and end with the spec for what it found. Runs only when a workflow calls it (a job past three blocking fix rounds, a feedback group) or the owner invokes /jig:bug with a symptom.
---

Your settings are the bug role's (`jig roles`). Your step is bug, and it ends with the spec
for what you found; `jig next` decides what comes after. You run only when a workflow calls
you (Bug, after a job's third blocking fix round; Feedback, once per group) or the owner types
`/jig:bug`. A session that only thinks it has seen something broken says so to the hubnode
and the owner; it never starts this on its own reading.

For a job, you run in the job's worktree and commit your spec on its branch: `jig reviewed`
reads the `Bug-for:` line there. For a feedback group, you run in a detached worktree of trunk
the hubnode names and commit nothing: the hubnode reads your spec and commits it on trunk.

## Brief

The hubnode starts this role with:

```
running <model> at <effort>
If your own model differs from this line, reply with only your running line and stop.
You are in the bug role: run /jig:bug, in <worktree: the job's, or a detached worktree of
trunk for a feedback group>, on <the symptom, in the reporter's words> for <job, or the
feedback group's files>. <For a job past its fix rounds: the findings each round left.>
```

Run this in order. Write it to `.jig/specs/bug-<name>.md`. Nothing gets edited until step 5 is done.

## 1. Why — up to 3 loops
Why did this happen? Answer. Why that? Answer. Stop at a root or at 3.
Each Q and A under 180 characters. Symptom first, no guessing past what you've read.

## 2. Givens
Everything known about the problem. Tag each line:
- `[seen]` — a log line, a test result, a file you read, something the user watched happen
- `[assumed]` — plausible, not observed

Every `[assumed]` given the fix depends on gets converted before step 5: go read the log, run the thing, or ask one question. If it can't be converted, say so and treat it as a risk, not a fact.

Reproducing in a throwaway repo? There, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.

## 3. One layer up
- Is there a sibling path (another mode, caller, handler) that does the same job? Does it have this problem?
- If not — what's structurally different?
- Is there an existing pattern in this codebase that already solves this shape?

## 4. Workaround or correction
Does the fix handle the symptom where it appears, or change the thing that produced it?
Prefer the correction. A workaround is fine when it is the right fix — say why in one line.

## 5. Write the spec
The spec opens with `Source:` naming who reported it, when, and the symptom in their words.
For a job past its fix rounds, it carries `Bug-for: <job>` on a line of its own: `jig
reviewed` refuses that job's next review until a committed spec says so.
`Alternatives considered` is required: `<sibling or correction> — rejected because <reason> — this reason is [seen|assumed]`.
Fill `## Roles` from `jig roles`, as `/jig:spec` says.
`Done when` must include an observable that proves the fix fires. A fix that can't be observed isn't a fix.
It also includes an observable that the symptom the report describes no longer happens. If the whys moved
to a different cause, the spec says what happens to the original symptom: fixed too, with that
observable, or left, as an `Out of scope` line with its reason, so the owner sees it.

If the fix is a workaround:
- one-line code comment, ≤120 chars, starting `WORKAROUND:` — what it patches and why a patch was right
- an entry in `.jig/ledgers/WORKAROUNDS.md` (the commit hook checks for it); the first creates the file from `${CLAUDE_PLUGIN_ROOT}/templates/ledgers/WORKAROUNDS.md`
