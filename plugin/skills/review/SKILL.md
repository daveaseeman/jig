---
name: review
description: The review role - an adversarial fresh-context review of a job's diff (review-work) or of what changed since its last review (review-change), recorded with its blocking findings. Use when `jig next` names review-work or review-change, or working alone after the checks pass, before the handoff note.
---

Your settings are the review role's (`jig roles`). Your steps are review-work, the job's whole
diff once per handoff, and review-change, only what changed since the last recorded review
after a fix or a hand-resolved sync. Always a fresh context: never the session that built it.
`jig next` decides what comes after.

## Brief

The hubnode starts this role, as a subagent where there is one, with:

```
running <model> at <effort>
If your own model differs from this line, reply with only your running line and stop.
Run /jig:review (<review-work or review-change>) on job <name> in <worktree>: <the diff or
delta, below>, with only the spec <spec> and AGENTS.md<, and the previous review's findings:
<findings>>. Rerun no check the builder's report shows for the same commit: <report>.
Run only the narrowest check a specific finding needs.
```

## Dispatch

Run the subagent at the `review` role's settings: `jig roles` gives its tier and effort,
`${CLAUDE_PLUGIN_ROOT}/tiers.json` maps them to a model and an effort level. A number with no
entry there is refused: say so and stop. Its prompt starts with `running <model> at
<effort>`, the configured settings. The first line of its reply is `running <model>`, the
model read from its own settings, and no effort: a self-read effort is too often wrong to act
on. Check the effort with the host's readout of that session where the host has one (the Claude
app shows each session's), and record the configured numbers either way. A self-read the host
contradicts is never a mismatch. The prompt also says: "if your own model differs from this
line, reply with only your `running` line and stop". At a mismatch in model, retry once, then
ask the owner; never use the mismatched run's output. A model it can't read, it reports as
`unknown`: no retry, record it as `unknown` (`--ran "unknown at <effort>"`) and tell the owner
once.

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

Rerun no check the builder's report shows for the same commit: the author ran it and showed
the output, and the check role runs the complete check. Run only the narrowest check a specific finding needs (one smoke section, one command),
and say which one and why.

A reviewer that runs jig to test a finding does it in a throwaway repo. There, set both variables on every jig command, not by one `export`: an agent's shell may not keep it to the next command. Point them at a folder `<dir>` beside the repo, not inside its working tree, so jig's files never show as untracked there: `JIG_CONFIG=<dir>/repos.json XDG_CONFIG_HOME=<dir>/config python3 .jig/jig.py …`. That keeps the user's own jig config untouched.

## Review-change

The first review of a job is review-work. After it, a fix or a sync resolved by hand gets a
review-change: the subagent at the same review role's settings, as Dispatch says, given the
delta, the previous review's findings, the spec and `AGENTS.md`. The delta of a fix is `git diff <last recorded review>..HEAD` (the commit `jig
handoff` named when it refused); of a sync resolved by hand, `git show --remerge-diff <merge>`
and `git diff <merge>..HEAD`, never trunk's work the merge brought in. It asks: does the delta
fix what the findings named, and does it break anything they didn't? When the delta changes
anything the findings didn't name, the review-change stops and says so, and a review-work
runs instead, recorded without `--change`. A clean `jig sync` needs neither:
`jig handoff` accepts it as it is.

## What counts

Rank findings: **blocking** (wrong, or misses the spec) / **should-fix** / **optional**.
Style is not a finding. Neither is an abstraction that isn't there yet. A finding that touches
the property the diff exists to hold is never optional, whether or not it predates the diff —
"pre-existing" says when a hole appeared, not whether this change must close it.

A reviewer asked for gaps will invent them. Only correctness and spec gaps block; everything
else is a note. Don't add layers, defensive code, or tests for cases that can't happen
because the reviewer suggested them.

## Then

Blocking findings go to the work session as a fix (Fix in `jig flows`); one round of
should-fix is enough, and a review with no blocking findings ends the fixing (`.jig/RULES.md`,
Contracts, and the hubnode skill say what follows). Every should-fix or optional finding the
work session doesn't take gets a row in `.jig/ledgers/DEFERRED.md` there. A job's third
blocking review, counting its first review-work, starts Bug: `jig reviewed` refuses the next
until the bug role's spec for the job, with `Bug-for: <job>`, is committed. Bug runs only then, or when the owner calls it.

## Record it

The session that dispatched the review records it, once: the hubnode, or the work session
working alone. The reviewer never records its own review, and nobody records a second one on
the same commit: the newest record of a commit is the one jig reads, so a second without
`--blocking` would erase the findings. Record every review, blocking findings or none, on the
commit it reviewed, in the job's worktree:

```sh
python3 .jig/jig.py reviewed --tier N --effort N --ran "<model> at <effort>" --blocking N
```

`--change` for a review-change. The tier and effort are the review role's configured ones,
from `jig roles`; `--ran` is the model its first line said it ran on, with the effort from
the host's readout or the configured one. `--blocking` counts the blocking findings it left:
`jig handoff` refuses while the newest review recorded any, and the rounds are counted from
it. `jig gate` warns when the settings fall short of the spec's `## Roles`.

`jig handoff` refuses without a record for that commit, or for one under it that only a
clean sync or the note's bookkeeping follows. Only record a review you actually ran, and
carry its findings into the note's Review heading.
