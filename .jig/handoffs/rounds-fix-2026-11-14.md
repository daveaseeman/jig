# Handoff: rounds-fix

Commit: ee07f20d394a17b938d3ef3912b6d4b0ea7c8d89
Date: 2026-11-14
Spec: Fix the 7 smoke failures the batch check found on 25aafa4 (sections rules/hardware, homes): jig handoff writes no note there after the cheaper-rounds merge; see .git/jig/gate-batch.out
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high (recheck of 3c55be6..d1cc116; its should-fix taken after)

## Built
The sweep the owner asked for, on top of the first handoff (rounds-fix-2026-11-13.md, which fixed `job_chain`).
- These five older git calls naming trunk now end with `--`, so a trunk named like a folder (firmware's `main/`) isn't read as a path: `last_checked_on`, `batch_merges`, `job_of_change`, `brought_by`, `contract_removals`.
- Fixtures with a `main/` folder: `check_levels` (release and its owed batch check, through `last_checked_on`) and `removals`' PO repo (update, through `contract_removals`).

## Done-when evidence
- `.jig/scripts/check.sh`: rc 0.
- On d1cc116, `bash tests/smoke.sh check_levels removals pararepo pararepo_commands pointers rules homes cheaper_rounds`: 329 PASS, 0 FAIL.
- On ee07f20, after moving the fixture, `bash tests/smoke.sh removals check_levels`: 57 PASS, 0 FAIL.
- The recheck proved the guards by reverting the fix in scratch clones:
  - check_levels: 4 FAIL with all five calls reverted; 1 FAIL with only last_checked_on reverted.
  - removals with PO's `main/`: 4 FAIL reverted, 0 FAIL fixed.

## Review
Recheck of 3c55be6..d1cc116, a fresh Opus subagent at high: nothing blocking.
- Each `--` keeps the call's meaning. The other calls in those functions can't be ambiguous; the reviewer probed ls-tree, show rev:path, the sha ranges and merge-base.
- Should-fix, taken: `main/` had gone on RP, which never calls contract_removals. It is now on PO, where update calls it (proven, see evidence).
- Optional, comment corrected: check_levels guards `last_checked_on`, not `batch_merges`' bare-trunk fallback. That fallback runs only with no recorded check, which the fixture never reaches.
- Optional, left: `brought_by` and `job_of_change` have no fixture reaching the changed line. Each needs a pararepo merge path to reach it. Both are correct by inspection and by the reviewer's git probe.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because only git argument forms changed; RULES.md describes none

## Shared files changed
- `plugin/templates/jig/jig.py`: a trailing `--` in the five functions named above.
- `tests/smoke.sh`: a `main/` folder in `sec_check_levels`' CL fixture and in `sec_removals`' PO fixture, each with a comment naming what it guards.

## Test by hand
Nothing to click. In a repo with a `main/` folder: merge a job with `jig mark … gated --batch`, then `jig release`. It refuses for the owed batch check.

## Left
Nothing on this job. Unguarded but correct by inspection: brought_by, job_of_change, and batch_merges' path with no recorded check.
