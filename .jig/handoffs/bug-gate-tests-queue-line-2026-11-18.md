# Handoff: bug-gate-tests-queue-line

Commit: 9566cd0fd4fd7fe7baac0443e1a095314398229e
Date: 2026-11-18
Spec: .jig/specs/bug-gate-tests-queue-line.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high

## Built
The three gate smoke tests that failed the batch check of daf9be2 now expect the line `jig gate` prints since check-queue: `(cd <scratch> && python3 .jig/jig.py queue --full -- [bash ]./.jig/scripts/check.sh --full)`. Only `tests/smoke.sh` changed (3 lines, all `grep -F`). `jig.py` is untouched.

## Done-when evidence
- `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh report_fixes merge_after_sync` → smoke rc=0, 74 PASS, 0 FAIL, including:
  - "PASS  gate: with an append conflict between trunk and the note commit, the scratch checkout has trunk merged and no conflict, and the check is printed"
  - "PASS  gate: an executable check.sh is printed as ./.jig/scripts/check.sh, and marking gated is the cleanup, not a hand-run remove"
  - "PASS  gate: a check.sh that isn't executable is printed as bash ./.jig/scripts/check.sh"
- The spec's grep for the old expectations → nothing (rc=1).
- `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → check rc=0. The full suite runs at the batch check.

## Review
- review-work of main...9566cd0: clean, blocking 0, no should-fix.
- Optional, not taken: the 3056/3060 test names still say "printed as [bash ]./.jig/scripts/check.sh". They're true as substrings. There's a DEFERRED row.

## Fold-in
- [x] no code changed — nothing to fold in

## Shared files changed
- `tests/smoke.sh`: the three gate expectations, as the spec says.

## Test by hand
Nothing to click: rerun `bash tests/smoke.sh report_fixes merge_after_sync` (through `jig queue`).

## Left
Nothing on this job.
