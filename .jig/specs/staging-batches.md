# staging-batches

Source: Guild Ops chat "Evaluate Adventure Studio against v5.0" / 2026-11-10 / Dave, with Claude (staged as feedback-jig-batch-order.md): "A staged batch has no order"
Source: Guild Ops chat "Evaluate Adventure Studio against v5.0" / 2026-11-10 / Dave, with Claude (staged as feedback-jig-find-target.md): "A chat cannot find its staging target without the repos list"
Source: Guild Ops chat "Evaluate Adventure Studio against v5.0" / 2026-11-10 / Dave, with Claude (staged as feedback-jig-sweep-protocol.md): "Notes on the staging sweep prompt"

## Intent
Staging works for a batch written from a chat:
- Files can say what they wait for, and `jig staging` lists them in an order that works.
- A chat can check its headers before it stages.
- A spec staged from a chat gets its `## Workflow` filled when it resolves.
- Two near-identical names in the repos list are flagged before a file lands in the wrong repo.

## Why
- Why did a 32-file batch need a guide page to carry its order? No header says what a file waits
  for, and `jig staging` lists by name.
- Why did a batch's headers go unchecked? `jig staging` runs inside the repo, and a chat writes
  from outside it.
- Why do chat-staged specs arrive with an empty Workflow? `jig workflow` reads the repo's config,
  which the chat can't run.
- Why did a plan carry the wrong repo name? `AdventureStudio` and `adventure-studio` are two
  entries in one list, and nothing points that out.

## Givens
- `[seen]` `/jig:stage` already tells a chat to request `~/.config/jig/` first and never stop at
  "no access" (`plugin/skills/stage/SKILL.md` ~28, spec `stage-ask-access`, v0.10.0). The
  find-target report was written against an older plugin (`jig_version: 9`).
- `[seen]` Resolving a `change: new` spec refuses when the destination exists ("stage it as
  `change: update`"), so two sweeps naming one new spec can't both land (jig.py ~5742).
- `[seen]` `jig repos` lists each entry with its kind and path (the repos skill). It doesn't
  compare names.
- `[seen]` The sweep-protocol report's items 2 and 3 (a "no repo" row, a name for the plan-only
  pass) are about the owner's own sweep prompt, not jig.

## Design
- **`after:` header key**, optional: one or more staged file names this file waits for.
  - `jig staging` lists files in an order that respects it (a topological sort, name order
    within a level), and marks a file whose `after` names a file that isn't staged or resolved.
  - `resolve` refuses a file while a file in its `after` is still staged, naming it.
  - The stage skill says to set it when a batch's files depend on each other, for example a
    roadmap before a spec that takes its scopes.
- **`jig staging check <file>…`** checks headers only. It runs from the plugin's copy outside any
  repo, against the target's path from `jig repos`. It finds an unknown kind, a missing key, an
  absolute destination, or an `after` naming no file in the batch. The stage skill runs it before
  saying a batch is staged.
- **`resolve` fills `## Workflow`.** A spec whose `## Workflow` is empty, or missing, gets
  `jig workflow`'s lines when it resolves into `.jig/specs/`, as `/jig:spec` writes them.
- **Near-duplicate names.** `jig repos` and `jig repos add` warn when two entries' names are equal
  once case and punctuation (`-`, `_`, `.`, spaces) are dropped, printing both paths.
- **The stage skill, for a sweep.** A sweep that skips work the target already has needs to read
  its `.jig/specs/`, `.jig/roadmap.md` and `.jig/decisions.md`. The skill says to request read
  access to those, or to say that step was skipped.

## Done when
- [ ] Smoke: three staged files, `c.md` with `after: b.md` and `b.md` with `after: a.md`.
  `jig staging` lists a, b, c. `resolve c.md` is refused, naming `b.md`, while b is staged.
- [ ] Smoke: `jig staging check` on a file with no `kind:`, run from outside any repo, names the
  problem and exits non-zero. A good file passes.
- [ ] Smoke: a staged spec with an empty `## Workflow` resolves with `jig workflow`'s lines in it.
- [ ] Smoke: repos entries `AdventureStudio` and `adventure-studio`. `jig repos` warns, printing
  both paths.
- [ ] RULES.md § Staging and `plugin/skills/stage/SKILL.md` say each of these.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A manifest file for a batch. `after:` in each file carries the same order without a file that
  can drift from the batch.
- A place for owner questions before execution. A spec's Decisions, or an `## Open` decision
  entry, already holds a question.
- The owner's sweep prompt (a "no repo" row, naming the plan-only pass). That is the owner's to
  edit.
- Reference material such as a zipped rulebook (feedback-jig-reference-material.md, dropped; see
  the resolve).

## Touches
- `plugin/templates/jig/jig.py` (`cmd_staging`: list order, `after`, `check`, resolve's Workflow;
  `cmd_repos`)
- `plugin/templates/jig/RULES.md` (§ Staging)
- `plugin/skills/stage/SKILL.md`, `plugin/skills/repos/SKILL.md`
- `tests/smoke.sh`

## Alternatives considered
- A batch manifest file (the report's second option). Rejected: a separate file can disagree
  with the files it orders, and `after:` lives with the file it constrains. Reason is [assumed].
- Leave Workflow to the resolving session. Rejected: `/jig:spec` already fills it from
  `jig workflow`, so resolve can apply the same lines with no judgment. Reason is [seen: the spec
  skill, step 6].

## Decisions
- Runs after `project-product-boundary`, which owns `jig.py`, RULES.md and `smoke.sh`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
