# Bug: three gate smoke tests expect the gate's old check line

Source: the batch check of trunk daf9be2, 2026-11-18 (check role, `.git/jig/gate-check-main-daf9be2.out`): three FAIL lines, smoke.sh exit 2 after 745s:
- "gate: with an append conflict between trunk and the note commit, the scratch checkout has trunk merged and no conflict, and the check is printed"
- "gate: an executable check.sh is printed as ./.jig/scripts/check.sh, and marking gated is the cleanup, not a hand-run remove"
- "gate: a check.sh that isn't executable is printed as bash ./.jig/scripts/check.sh"

## Intent
The smoke suite passes on trunk again. The three gate assertions expect the line `jig gate` prints
since check-queue: `(cd <scratch> && python3 .jig/jig.py queue --full -- [bash ]./.jig/scripts/check.sh --full)`.

## Why
1. Why did they fail? check-queue (merged daf9be2, review-work S1) changed `cmd_gate`'s printed check
   to go through `jig queue --full`. These three tests grep `cd $s && ./.jig/scripts/check.sh` and
   `&& [bash ]./.jig/scripts/check.sh`, which no longer appear. [seen] (jig.py ~3219; smoke.sh 1908,
   3056, 3060)
2. Why wasn't it caught? The tests sit in `report_fixes` and `merge_after_sync`, and check-queue's
   evidence ran `queue check_levels release`. [seen] (check-queue's handoff notes)

## Givens
- [seen] The batch output has exactly three FAIL lines, all of them these.
- [seen] The gate prints `bash ` before the script only when check.sh isn't executable, still after
  `queue --full -- `.

## Correction
Change each of the three expectations to the queued line, keeping what each test proves:
- 1908: the check is printed, through `queue --full --`;
- 3056: executable, so no `bash `;
- 3060: not executable, so `-- bash ./.jig/scripts/check.sh`.
Don't change `jig.py`.

## Done when
- [ ] `bash tests/smoke.sh report_fixes merge_after_sync` passes, the three named cases among the PASS lines.
- [ ] `grep -n "cd \$s && ./.jig/scripts/check.sh\|'&& ./.jig/scripts/check.sh'\|'&& bash ./.jig/scripts/check.sh'" tests/smoke.sh` finds nothing.
- [ ] `.jig/scripts/check.sh` exits 0. The full suite runs once, at the batch check.

## Out of scope
- `jig.py`'s gate line, which is right as check-queue built it.

## Touches
- `tests/smoke.sh`

## Alternatives considered
- Revert the gate's line to the bare check — rejected, because check-queue's spec and review-work S1
  require the queued command there — [seen].

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
