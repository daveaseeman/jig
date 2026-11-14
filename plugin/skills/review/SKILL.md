---
name: review
description: Adversarial fresh-context review of a diff before a handoff. Run after the checks pass, before writing the handoff note.
---

Runs once per handoff — a mergeable chunk — not once per commit. The spec is written at that
scope, so that is the scope at which these questions can be answered.

## Dispatch

Run the subagent at the `review` step's settings: `jig workflow` gives its tier and effort,
`${CLAUDE_PLUGIN_ROOT}/tiers.json` maps them to a model and an effort level. A number with no
entry there is refused: say so and stop. Its prompt starts with `running <model> at
<effort>`, and so must the first line of its reply, read from its own settings; a value it
can't read, it reports as `unknown`. The prompt also says: "if your own model or effort
differs from this line, reply with only your `running` line and stop". At a mismatch in model
or effort, retry once, then ask the owner; never use the mismatched run's output. Only a value
it read and that differs is a mismatch: an `unknown` gets no retry, record it as `unknown`
(`--ran "<model> at unknown"`) and tell the owner once.

Give a subagent exactly this and nothing else: the diff since the last handoff
(`git diff <last-handoff-commit>..HEAD`, or `git diff <trunk>...HEAD` for the first one; the
last handoff is the `Commit:` of the note `jig gate` names, not the last note by name),
the task's spec, and `AGENTS.md`. Not the conversation, not your reasoning. The reviewer
evaluates the result on its own terms.

Its job is to find the reason this change is wrong. Its questions:

1. Does every "done when" item have evidence? Name it, or it isn't done. Does "done when"
   cover the symptom in the spec's `Source:` line? A fix spec whose "done when" doesn't, and whose
   `Out of scope` doesn't say why, is blocking.
2. Did anything change outside "touches" / "out of scope"?
3. Is there a sibling path that does the same job differently now? Asymmetry is a finding.
4. If this is a fix: is `Alternatives considered` filled, and is each rejection reason
   tagged `[seen]`? An empty slot, or an `[assumed]` reason the fix depends on, is blocking.
5. What would make this fail that the author didn't consider? One concrete scenario, or say
   there isn't one.
6. In a pararepo: does it change a contract path without a buffer row, a metarepo
   proposal, a `meta: <name> pointers <branch>`, or a `meta: none` reason that holds? Does a
   buffer row say what the code now does? A `pointers` spec moves pointers only: if its diff
   changes a metarepo claim, that is a finding (the claim change needs a buffer row or a
   proposal).
7. In a metarepo: does a changed claim still stand, in other words, anywhere the spec didn't
   list (Every copy)? Does older text it contradicts still read as current, Accepted or not
   (Newer wins)? Is each changed claim stated only at its home, with a pointer everywhere else
   (What the metarepo holds)? A decision row and the pages citing it as their source are one
   home, not copies.

8. For each decision entry the diff adds or changes, `jig decision <id> --peers` lists its
   peers, the entries touching the same pages here and across the metarepo, with their rule
   sentences. These are the pairs the handoff's fold-in will ask about. For each pair:
   1. Do both govern the same situation?
   2. Do their outcomes differ?
   3. Is one an exception the other permits? Then the answer is narrows, saying how.
   4. Is either in the wrong repo: a pararepo binding others, or the metarepo binding one
      pararepo?

   Two outcomes for one situation, neither an exception the other permits, is a conflict:
   blocking until the change resolves it. Does each added entry open with its rule sentence?

9. For each decision entry and each page change the diff adds, ask: is this about the product, or about when and in what order we build it? An entry or a page
   line that is the project (a priority order, a delivery queue, a phase, build status, "not
   built yet", parked work) is blocking: it goes to `.jig/roadmap.md` (`## Up next` for work
   parked mid-build, naming its pages; `## No phase` for named work with no phase yet), and the
   page or entry keeps only what the product does today
   (`.jig/RULES.md`, Documentation, Product and project). Judge by what it says, never by a
   heading or a word: a `## Status` section describing a status call, or a motor's three
   phases, is the product. "Demo priorities: A, then B" is the
   roadmap's, never an entry. The hook catches paths and scope ids; prose is yours to catch.

A file in `.jig/staging/` is not decided; a finding that rests on one says so.

Don't rerun the full checks: the author ran them and showed the output, and the gate runs them
again. Run only the narrowest check a specific finding needs (one smoke section, one command),
and say which one and why.

A reviewer that runs jig to test a finding does it in a throwaway repo. There, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.

## What counts

Rank findings: **blocking** (wrong, or misses the spec) / **should-fix** / **optional**.
Style is not a finding. Neither is an abstraction that isn't there yet. A finding that touches
the property the diff exists to hold is never optional, whether or not it predates the diff —
"pre-existing" says when a hole appeared, not whether this change must close it.

A reviewer asked for gaps will invent them. Only correctness and spec gaps block; everything
else is a note. Don't add layers, defensive code, or tests for cases that can't happen
because the reviewer suggested them.

## Then

Fix blocking items and re-run the checks. One round of should-fix is enough. If a third
round of fixes still leaves something blocking, don't start a fourth: run `/jig:bug` on why
the fixes aren't converging (in a repo with a hubnode, ask the hubnode to run it). Every should-fix or optional finding you
don't take gets a row in `.jig/ledgers/DEFERRED.md` with its rank and one reason, tagged `[seen]` or
`[assumed]`. The first row creates the file from `${CLAUDE_PLUGIN_ROOT}/templates/ledgers/DEFERRED.md`.

## Record it

When no blocking findings remain, with everything committed:

```sh
python3 .jig/jig.py reviewed --tier N --effort N --ran "<model> at <effort>"
```

The tier and effort the review ran at, from `jig workflow`'s `review` line, and what its
first line said it ran on. `jig gate` warns when they fall short of the spec's Workflow
section.

`jig handoff` refuses without a record for that exact commit. Only record a review you
actually ran, and carry its findings into the note's Review heading.
