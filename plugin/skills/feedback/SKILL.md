---
name: feedback
description: Report a bug in the jig tool itself (jig/jig.py, jig/RULES.md, its hooks, or a skill) for the plugin owner. Use when the tool, not the repo's code, misbehaved. Changes nothing in the repo.
disable-model-invocation: true
---

This is `/jig:bug` pointed at the tool. The user decides which one applies; don't guess.

Investigate exactly as `/jig:bug` does — whys, givens tagged `[seen]`/`[assumed]`, one
layer up, workaround or correction, spec — reading `jig/jig.py`, `jig/RULES.md`, the
hook output, and the skill involved.

Then:

1. Write the report to a temporary file: `${TMPDIR:-/tmp}/jig-feedback-<repo>-<date>.md`.
   One section per issue, each with the five steps and a "done when" the plugin owner can test.
2. Print the path. That file is the deliverable; the user carries it to the plugin.
3. Stop. Do not edit `jig/jig.py` or `jig/RULES.md`, do not add a `WORKAROUND:` or a ledger row, do not commit.
   If the lane is blocked, say so and ask the hubnode to park it.
