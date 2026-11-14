# Handoff: rounds-fix

Commit: 3c55be6035cb418db0d4acf46157de0d9e32fa43
Date: 2026-11-13
Spec: Fix the 7 smoke failures the batch check found on 25aafa4 (sections rules/hardware, homes): jig handoff writes no note there after the cheaper-rounds merge; see .git/jig/gate-batch.out
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high (review of d07f13c; its optional comment fix taken after)

## Built
Fixes the seven batch-check failures on 25aafa4 (rules: hardware H1/H2 and hwref H3/H4; homes: RL).
- Cause: `job_chain` (from cheaper-rounds) ran `git rev-list --first-parent HEAD ^main`. In a repo with a `main/` folder (firmware), git calls that ambiguous and fails. `git()` returns "" on failure, so the chain was empty, `jig handoff` found no review, and no note was written.
- Fix: both rev-list calls in `job_chain` end with `--`. The tests described correct behaviour and are unchanged; only cheaper_rounds' fixture gained a `main/` folder, to guard it.

## Done-when evidence
- `.jig/scripts/check.sh`: rc 0.
- `bash tests/smoke.sh rules homes cheaper_rounds` on d07f13c: 156 PASS, 0 FAIL (the seven named cases pass).
- The reviewer reverted only the `--` in a scratch copy: cheaper_rounds went to 10 PASS, 13 FAIL. So the new fixture guards the fix.
- Since d07f13c only a smoke comment changed (`bash -n` ok).

## Review
Fresh Opus subagent at high, given only the diff, the spec and AGENTS.md: no blocking findings.
- Sibling check, as the hubnode asked: every git call cheaper-rounds added was tested with a `main/` folder present, and none is still exposed.
  - `merge-base X main` (deferred_deleted, proposed_added): fine.
  - `rev-list sha..main` (changed_since): fine, because git checks the whole `a..b` as a filename.
  - `show main:path`: fine.
  - The solo `git log … <sha>^ -- .jig/handoffs/`: SHAs only, and already has `--`.
- Should-fix, left for the owner: the same bug in calls that predate cheaper-rounds. Each is a one-token fix (a trailing `--`); a sweep candidate:
  - jig.py ~1387 and ~1398, `last_checked_on` / `batch_merges` (a3e9c67): `rev-list --first-parent main` and `git log … main`. In a firmware repo, `jig release` would not see an owed batch check.
  - jig.py ~6214, `job_of_change` (7d1c92d): `rev-list --first-parent <tip> ^trunk`. A change can read as belonging to no job.
  - jig.py ~7218, `brought_by`: `rev-list --first-parent --merges <trunk>`. `trunk_answers` finds nothing.
  - jig.py ~7313, `contract_removals`: `git log … <trunk>` (meta/pararepos only).
- Optional, taken: the fixture comment now names what it guards.
- Optional, not taken: `check=True` on job_chain's calls, so a failure is loud rather than reading as "no review on record". The owner's call; it goes with the sweep.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because the change is internal to job_chain; RULES.md describes no git argument form

## Shared files changed
- `plugin/templates/jig/jig.py`: `job_chain`'s two rev-list calls end with `--`.
- `tests/smoke.sh`: `sec_cheaper_rounds`' fixture adds a `main/` folder, with a comment naming what it guards.

## Test by hand
Nothing to click. In a repo with a `main/` folder and trunk `main`: open a job, commit, `jig reviewed`, `jig handoff`. It writes the note.

## Left
Nothing on this job. The older calls listed under Review are a sweep for the owner to decide.
