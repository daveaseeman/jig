# Bugs from a metarepo: R6 compares numbers as text, M5 blocks the job flow, a decisions destination is guessed

Source: `/jig:feedback` from a metarepo on layout 8, Oct 30 (`jig-feedback-<metarepo>-2026-10-30.md`).
Each cited line was checked against `plugin/templates/jig/jig.py` at 4bae972/b5ed1cf.

## Intent
A zero-padded id (`D-002`) counts as the number its job holds. In a metarepo, a job can sync,
be gated and be merged by the normal commands. A decisions file whose `destination` isn't a
bare path is refused, the way a doc's is, instead of landing in a guessed file.

## 1. R6 compares as text
- `[seen]` `reserved_refusals` keys `before`/`after` by `m.group(1)` and checks `got not in held`,
  where `held` holds the numbers as strings (`str(int)`). So `002` ≠ `2`, and a job holding
  decision 2 is refused when it adds `| D-002 |`.
- `[seen]` `next_number` and `highest_on_trunk` already compare as ints. Only this check uses
  text. jig's own examples are zero-padded (`D-001` in RULES.md M2, the `init --meta` seed).
- Correction: key by `int(...)`, build `held` from ints, print the captured text in the refusal.

## 2. M5 runs on every merge, on every branch
- `[seen]` `meta_rules`: `if merging:` applies M5 with no `branch == trunk` check, although its
  comment and RULES.md say "main takes only merges of reviewed branches". So `jig sync` in a job
  (merging trunk's `.jig/`-only commits) and the gate's detached scratch merge are refused.
- `[seen]` `jig handoff` requires the review record to equal HEAD, so the note is committed
  after the review. `jig merge` merges the tip, which is that note commit, and M5 refuses it.
- `[seen]` `cmd_merge` already treats a commit that adds only `.jig/handoffs/` as not changing
  the gated work.
- Correction:
  - M5 runs only on trunk.
  - A merged commit counts as reviewed when a reviewed commit is its ancestor and the diff
    between them touches only `.jig/handoffs/`. `meta_problems`' merge check uses the same rule,
    for `release` and pre-push.

## 3. A decisions `destination` with prose after the path
- `[seen]` `cmd_staging`: `inside(dest if dest.endswith(".md") else "DECISIONS.md")` at both
  decisions sites. A destination like `decisions/DECISIONS.md, on branch x` falls back to a root
  `DECISIONS.md` the repo may not have.
- `[seen]` The spec/doc branch already refuses a destination that isn't a path.
- Correction:
  - A non-empty destination that isn't a bare `.md` path refuses, naming the header field.
  - An empty one still falls back to the root `DECISIONS.md`.

## Done when
Smoke, in a metarepo fixture with `reserve.decision = {pattern: ^\|\s*D-(\d+)\s*\|, files: [DECISIONS.md]}`:
- [ ] A job holding decision 2 adds `| D-002 |`: `jig check --staged` prints `ok`.
- [ ] It adds `| D-003 |` instead and is refused with R6, which names 3 and the held 2. An
      unpadded counter (`SCHEMA_VERSION\s*=\s*(\d+)`) behaves as before.
- [ ] After a `.jig/`-only commit on trunk, `jig sync` in the job commits its merge.
- [ ] Review, handoff, a committed note, then gate: `jig merge <job>` succeeds and removes the
      entry from `jobs.json`. `jig release` and a push (pre-push) accept the history.
- [ ] Still refused: content committed after `jig reviewed`, then a note, then gate. `jig merge`
      refuses with M5.
- [ ] The gate's `git merge <trunk>` in a detached scratch checkout commits.
- [ ] `destination: docs/DECISIONS.md, on branch x` refuses, naming the header.
      `destination: docs/DECISIONS.md` resolves. An empty destination resolves to the root
      `DECISIONS.md` as before.
- [ ] Smoke passes, and the validator passes.

## Out of scope
- How `jig handoff` and `jig reviewed` order the note and the review.
- Parsing a path out of a prose destination.

## Touches
`plugin/templates/jig/jig.py` (`reserved_refusals`, `meta_rules`, `meta_problems`,
`cmd_staging`), `plugin/templates/jig/RULES.md` (M5 says "on trunk", and the handoff-note
exception), `tests/smoke.sh`.

## Alternatives considered
- Document a `0*` in the counter pattern. Rejected: the default pattern for jig's own id style
  stays broken, and nothing tells an author to add it. `[seen]`: the repo needed exactly that.
- Exempt every `.jig/`-only commit from M5. Rejected: a branch could slip unreviewed spec or
  ledger edits into trunk. Handoff notes are the only bookkeeping made after a review by
  design. `[seen]`: `jig handoff` requires the review to equal HEAD.
- Have `jig merge` merge the gated commit and teach R6 that a merge of it ends the job.
  Rejected: larger, and the note would have to reach trunk separately. `[assumed]`
- Read the leading path out of a prose destination. Rejected: guessing what a chat meant caused
  this. `[seen]`
