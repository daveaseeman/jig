# Handoff: update-spec

Commit: c1d30f3b3b56
Date: 2026-10-30
Spec: .jig/specs/update-root-specs.md

## Built
The spec as it now stands. It supersedes the first two handoffs on mixed subfolders.

The owner said, on Oct 30, that update should move a mixed `specs/` subfolder, but only one that is "clearly a jig spec folder", judged from contents and context. The spec now splits that job:
- **`jig.py` gathers.** It holds a mixed subfolder of root `specs/` or `ledgers/` whole, and lists it under "Subfolders to decide" in the dry run and in `--apply`. The listing gives a fixed evidence line: how many specs, lane briefs and handoff notes name it; its files by type; any code that names it; and the `--move` to use.
- **The skill judges.** It reads the folder and decides with the user, in order: dry run; decide; dry run with `--move`; ask; `--apply` with the same `--move`.
- **`--move` moves.** It is mechanical, and refuses on a bad path, a collision, or a repo already updated.

The rest is unchanged from the first handoff: per-file collisions, the depth warning, worktree advice per case, the plan printed under a refusal. Spec only; no code changed.

## Done-when evidence
Spec-only handoff: the Done-when items are the build's, checked by `bash tests/smoke.sh` when it is built.
- The evidence line has an exact expected string.
- The reporting repo's numbers were re-checked by two reviewers at its last ai-dev commit:
  - 18 template-headed specs, 9 lane briefs and 21 handoff notes name `specs/prework/`;
  - no file in it is test-named;
  - no code outside the board names it, except in comments.
- Every generation's spec template has `## Intent` and `## Done when` [seen].
- `.jig/scripts/check.sh` passed.

## Review
Three fresh-context rounds on the subfolder rule since the last handoff.
- **Rounds on `cec238f` and `16178af`.** I tried heuristics in `jig.py`: jig records claim a folder, and test-named files or code references veto it. Each round found a test folder that would still move:
  - fixtures read by a sibling test;
  - `.rspec` lines that start with `--` and read as comments;
  - `*_spec.rb`, `__tests__/`.

  By the review skill's third-round rule, the approach was wrong. The rule was re-specified: `jig.py` gathers, the skill judges, `--move` moves. The rejected heuristic is recorded under Alternatives.
- **Round on `419fbd2`.** 2 blocking findings, 5 should-fix, 5 optional, all taken in `c1d30f3`:
  - Blocking 1: `--move` is unreachable after `--apply`. Now `--apply` lists the subfolders too, and `--move` on an updated repo refuses with the `git mv` advice.
  - Blocking 2: the user never saw the `--move` plan before it applied. The skill's five steps fix that.
  - Should-fix:
    - "mixed" is now Markdown plus non-Markdown;
    - `refused: --move` is in the skill's exit codes;
    - code that names a subfolder is part of its evidence;
    - the board rule for held folders is defined;
    - the Done-when gaps are closed (exact evidence string, exit 1 on the ledgers case, not stale while held, collision changes nothing, `--move` after update).
  - Optional: `--move` paths normalized; argparse is in Touches.

No DEFERRED rows.

## Fold-in
- [x] no code changed — nothing to fold in

## Shared files changed
None.

## Test by hand
Nothing to click. Read "Mixed subfolders" in the spec.

## Left
- Owner: open question 1 (should the stale-reference list be retrievable after the update commit?), and approval of the spec.
- Build after lane `names` merges, in its words.
