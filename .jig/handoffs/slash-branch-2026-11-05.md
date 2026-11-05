# Handoff: slash-branch

Commit: 491421f467fcb1ab8751f3d01ddf47c4014af6f2
Date: 2026-11-05
Spec: .jig/specs/bug-slash-branch.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to high, not readable by the subagent)

## Built
A `/` in a branch or job name now hands off and gates. `file_safe()` maps `/` to `-` for the note's file name (`cmd_handoff`) and the gate's scratch (`gate-<name>`). `handoff_notes` reads only flat notes whose first line is `# Handoff: <name>`. `jig open` refuses a job whose file-safe name an open job already has. `jig update` flattens notes the bug left in subfolders of `.jig/handoffs/` (only those whose header names their path), a clash taking the day's next `-N`, and removes the emptied folders. RULES.md (Handoff step 1) and the hubnode skill (Gating step 2) say the mapping.

## Done-when evidence
All via `bash tests/smoke.sh slash_names` (9 PASS at 491421f; every case FAILs against cb6af2f's jig.py, and A/B's against bd9ffaf's):
- [x] Solo `a/b-c` handoff: exit 0, prints `wrote .jig/handoffs/a-b-c-<date>.md`, no `.jig/handoffs/a/` — PASS "solo on a/b-c, handoff writes the flat …".
- [x] Gate exits 0 with `a/b-c: gate <commit> from .jig/handoffs/a-b-c-<date>.md on a/b-c`, no `has filed no handoff note` — PASS "gate finds the note …".
- [x] Scratch is `.git/jig/worktrees/gate-a-b-c`; after the printed remove, `worktrees/` is empty — PASS "the gate's scratch is the flat gate-a-b-c …".
- [x] Collision: `a-b-c-<date>-2.md` headed `# Handoff: a-b-c` is ignored, gate takes `a-b-c-<date>.md` — PASS "a note whose header names a-b-c …".
- [x] Job `a/b` writes `a-b-<date>.md`; `jig status` shows `a/b … handoffs:1` — PASS "job a/b's handoff writes …".
- [x] Update dry run lists both moves (`x/y` → `x-y-2026-01-01-2.md`), porcelain empty — PASS "update's dry run flattens both nested notes …".
- [x] `--apply` stages both as R100, subfolders gone, rerun `up to date` — PASS "update --apply stages both renames …".
- [x] board_split's "takes the -3 note" and "counts its own three notes, not job A-x's" pass unchanged (full run).
- [x] `grep -n 'gate-' plugin/skills/hubnode/SKILL.md` → line 112: `gate-<name>.out`, named after the scratch checkout `jig gate` printed.
- [x] Full `bash tests/smoke.sh`: 532 PASS, 0 FAIL, exit 0; `claude plugin validate ./plugin`: Validation passed; `.jig/scripts/check.sh` rc 0. Plus review cases: "open refuses job a-b while a/b is open …" and "a subfolder update moved from .aidev/handoffs/ stays nested …" PASS.

## Review
Round 1 (hubnode, fresh subagent, tier 2, effort 2, at bd9ffaf): no blocking.
- Should-fix A: same-day note collision across jobs `a/b` and `a-b` (add/add conflict at the second merge). Fixed in 491421f: `jig open` refuses a job whose `file_safe` name equals an open job's, naming the clash; smoke case added; spec Decisions updated.
- Should-fix B: `handoff_rows` flattened subfolders update itself moves from `.aidev/handoffs/` and claude-lane. Fixed in 491421f: only a nested `<name>-<date>[-N].md` whose first line is `# Handoff: <prefix>/<name>` moves; `.aidev` smoke case (second update up to date) added; spec Decisions updated.
- Optional C: emptied-folder set was a second copy of the rule. Fixed in 491421f: `handoff_rows` returns the folders with its rows.
- Optional D: RULES.md named the mapping only under Working alone. Fixed in 491421f: stated in Handoff, gate, merge step 1, for jobs and solo.
Recorded at 491421f (tier 2, effort 2).

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap, or no page needed because jig's own docs are RULES.md and the skills, which this change updated (RULES.md Handoff step 1, hubnode Gating step 2); this repo keeps no docs/ page for jig.py

## Shared files changed
- `plugin/templates/jig/jig.py`: only the functions the spec's Touches names, plus `cmd_open` (finding A): `file_safe` and `handoff_notes`, `cmd_handoff`'s path, `cmd_gate`'s scratch name, `handoff_rows` before STEPS, `cmd_update`'s plan line and its rmdir pass.
- `plugin/templates/jig/RULES.md`: one sentence in Handoff, gate, merge step 1.
- `tests/smoke.sh`: new section `sec_slash_names` before UNITS, and `slash_names` appended to UNITS.
- `.jig/specs/bug-slash-branch.md`: Decisions updated for findings A and B, as the hubnode allowed.

## Test by hand
In a throwaway repo (with `JIG_CONFIG`/`XDG_CONFIG_HOME` set): `git checkout -b feature/x`, commit, `jig reviewed`, `jig handoff`. The note lands at `.jig/handoffs/feature-x-<date>.md`. Commit it, then `jig gate` prints `from .jig/handoffs/feature-x-…` and the scratch `.git/jig/worktrees/gate-feature-x`.

## Left
Nothing on this job. Out of scope per the spec: job worktrees stay nested at `.git/jig/worktrees/<branch>`; `review_marker` keeps `%`.
