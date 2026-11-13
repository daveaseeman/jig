# Handoff: docs-structure-evidence

Commit: a9d38d65686b69a9dd6c41864835f9419471268e
Date: 2026-11-13
Spec: .jig/specs/docs-structure-evidence.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
The only change since f537c95, whose note is `.jig/handoffs/docs-structure-evidence-2026-11-12.md`, is the sync with main at 7e3ff5b (merge-log-conversion and branch-log-old-side), in merge commit a9d38d6. Its one hand resolution is the UNITS line in `tests/smoke.sh`: main's `merge_log` section is kept whole, with `structure` added back after `homes`. Everything the job delivers is as that note's Built says: old-contract holders, page levels from evidence (`--levels`), structure maps, and "subsystem" for a docs level.

## Done-when evidence
- On a9d38d6: `bash tests/smoke.sh` gives 1093 PASS, 0 FAIL, rc 0, with `structure` 11 PASS and `merge_log` 20 PASS. `claude plugin validate ./plugin` passes, and so does `.jig/scripts/check.sh`.
- Each spec item's evidence (Daisy before and after, this checkout's empty holder list, the redocument fixture's seed, the greps) is in `.jig/handoffs/docs-structure-evidence-2026-11-12.md`. The sync changes none of the code it ran.

## Review
- The hubnode reviewed the resolution with `git show --cc a9d38d6 -- tests/smoke.sh`: main's merge_log section is kept whole, and `structure` is back in UNITS, nothing else. Review recorded at a9d38d6.
- The three adversarial review rounds, their fixes and the 11 DEFERRED rows are in `.jig/handoffs/docs-structure-evidence-2026-11-12.md`.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated in this job (the subsystem definition, the levels and holders paragraph, and `jig survey [--json] [--levels]`). The sync brought main's own jig.py changes, which their own notes answer.

## Shared files changed
- `tests/smoke.sh`: the sync's UNITS-line resolution. This job's `structure` section sits beside main's new `merge_log` section, and both are in UNITS.
- The rest, and why this job touched each, are in `.jig/handoffs/docs-structure-evidence-2026-11-12.md`.

## Test by hand
- `bash tests/smoke.sh --list` names both `structure` and `merge_log`.
- The rest is as in `.jig/handoffs/docs-structure-evidence-2026-11-12.md`.

## Left
- Nothing on this spec. The DEFERRED rows are its follow-ups.
