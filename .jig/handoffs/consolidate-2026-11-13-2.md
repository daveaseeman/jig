# Handoff: consolidate

Commit: f39a8cdd9793dad8adaeb5bb6d38d51d5d654bed
Date: 2026-11-13
Spec: .jig/specs/consolidate.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
- Sync of trunk (checks-and-briefs, 6d5c4c1) into consolidate, conflicts resolved keeping both jobs: the `jig.py` dispatch names `consolidate`, `share` and `checked`; `tests/smoke.sh` keeps `sec_consolidate`, `sec_check_levels` and `sec_role_line`, all three in UNITS. Nothing else changed since the first note (`consolidate-2026-11-13.md`), which holds the job's full account.

## Done-when evidence
- Unchanged from `consolidate-2026-11-13.md`; rerun on the merge: `.jig/scripts/check.sh` → ok; `bash tests/smoke.sh consolidate check_levels role_line` → 54 PASS, 0 FAIL. Full suite not run (gate).

## Review
Fresh-context subagent (Opus; effort read as unknown) on the resolution only (`git show --remerge-diff HEAD`, and the diff from 4e29c55 for the two files). Nothing blocking, no should-fix: both sides' lines intact, 27 subparsers = 27 dispatch keys, every `sec_*` in UNITS once. Optional: run `merge_after_sync` (trunk changed it): not taken here, as the hubnode limited sections to those conflicted; the gate's full suite covers it.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`; this sync changed no behaviour of either job.

## Shared files changed
- `plugin/templates/jig/jig.py`: the dispatch line, both jobs' commands. `tests/smoke.sh`: both new sections and the UNITS line.

## Test by hand
- `python3 .jig/jig.py --help` lists `consolidate`, `share` and `checked`.

## Left
- Nothing; the owner's call on held specs leaving "waiting" at a release stands (first note, Left).
