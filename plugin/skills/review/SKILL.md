---
name: review
description: Adversarial fresh-context review of a diff before a handoff. Run after the checks pass, before writing the handoff note.
---

Runs once per handoff — a mergeable chunk — not once per commit. The spec is written at that
scope, so that is the scope at which these questions can be answered.

## Dispatch

Give a subagent exactly this and nothing else: the diff since the last handoff
(`git diff <last-handoff-commit>..HEAD`, or `git diff <trunk>...HEAD` for the first one),
the task's spec, and `AGENTS.md`. Not the conversation, not your reasoning. The reviewer
evaluates the result on its own terms.

Its job is to find the reason this change is wrong. Five questions:

1. Does every "done when" item have evidence? Name it, or it isn't done.
2. Did anything change outside "touches" / "out of scope"?
3. Is there a sibling path that does the same job differently now? Asymmetry is a finding.
4. If this is a fix: is `Alternatives considered` filled, and is each rejection reason
   tagged `[seen]`? An empty slot, or an `[assumed]` reason the fix depends on, is blocking.
5. What would make this fail that the author didn't consider? One concrete scenario, or say
   there isn't one.

## What counts

Rank findings: **blocking** (wrong, or misses the spec) / **should-fix** / **optional**.
Style is not a finding. Neither is an abstraction that isn't there yet. A finding that touches
the property the diff exists to hold is never optional, whether or not it predates the diff —
"pre-existing" says when a hole appeared, not whether this change must close it.

A reviewer asked for gaps will invent them. Only correctness and spec gaps block; everything
else is a note. Don't add layers, defensive code, or tests for cases that can't happen
because the reviewer suggested them.

## Then

Fix blocking items and re-run the checks. One round of should-fix is enough; if a third
round is needed, the spec was wrong — fix the spec. Every should-fix or optional finding you
don't take gets a row in `jig/ledgers/DEFERRED.md` with its rank and one reason, tagged `[seen]` or
`[assumed]`.

## Record it

When no blocking findings remain, with everything committed:

```sh
python3 jig/jig.py reviewed
```

`jig handoff` refuses without a record for that exact commit. Only record a review you
actually ran, and carry its findings into the note's Review heading.
