# Handoff: bug-gate-scratch-left

Commit: fb34ab108e4e1d286979731601d0a37d05e3eb01
Date: 2026-11-11
Spec: .jig/specs/bug-gate-scratch-left.md
Review: tier 2, effort 2
Ran: fresh Opus review of bc096fe: B1 mark/merge deleted a gate-<job> named job's live worktree (reproduced), fixed in fb34ab1 (open refuses gate- names; gate_scratch_problem removes only a detached checkout jig made); S1 second gate removes the leftover, S2 subshell check line, S3 tracked-change message names files; optionals taken (git rc, non-conflict merge failure, prune, merge-in-progress message). Hubnode checked fb34ab1 by diff and a repro: trunk ahead, gate, mark gated removes the clean checkout.

## Built
jig removes the scratch checkout `jig gate` creates. `jig mark <job> gated`, `jig merge <job>` and the next
`jig gate <job>` remove `.git/jig/worktrees/gate-<job>`, untracked files and all, through one check
(`gate_scratch_problem`). That check refuses a checkout on a branch, a merge in progress, tracked changes (named,
"from setup.sh or a hand edit"), or a folder that isn't its own checkout. `jig open` refuses a `gate-` job name.
`jig update` lists a clean detached `gate-*` checkout as gate scratch and removes it on `--apply`; others stay
refusals. A gate stuck on, or failing, its merge of trunk removes its own checkout. Every removal prunes git's
records. The gate prints the check as a subshell and drops the hand-run remove (a solo gate, with no mark, keeps it).

## Done-when evidence
- mark removes, tracked edit refuses: smoke `merge_after_sync` "mark: with a tracked edit in the gate checkout, jig mark K gated refuses, naming it" and "mark: jig mark K gated removes the gate checkout, untracked files and all": PASS.
- gate + merge, no mark: "merge: jig merge K, gated again and never marked, leaves no gate checkout": PASS.
- update: smoke `update` "a leftover gate-J is listed as gate scratch and isn't refused; job J's own worktree still is", "a gate checkout with a tracked edit stays a refusal, naming it", "--apply removes the leftover gate checkout, untracked files and all": PASS.
- gate output and hubnode skill: `report_fixes` "gate: an executable check.sh is printed ..., and marking gated is the cleanup, not a hand-run remove": PASS; `plugin/skills/hubnode/SKILL.md` step 5 says mark removes it, and has no remove step.
- `bash tests/smoke.sh`: 898 PASS, 0 FAIL, exit 0. `bash tests/redocument-fixture.sh` exit 0. `claude plugin validate ./plugin` exit 0 ("Validation passed"). `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` empty (exit 1). `.jig/scripts/check.sh` exit 0. Output: side-session notes, bug-gate-scratch-left-smoke-2.out.

## Review
Fresh review of bc096fe (hubnode):
- B1 (blocking, reproduced): a job named gate-<job> lost its worktree on `mark <job> gated`. Fixed: open refuses gate- names, and removal refuses a branch checkout. Smoke repro (branch checkout at gate-L with untracked newwork.py survives a refused mark).
- S1: a second gate died on the leftover. Fixed: gate removes it first. Smoke case added.
- S2: the shell was left in a removed folder. Fixed: the check is printed as a subshell.
- S3: setup-made changes were blamed on an edit. Fixed: the message names the files, and says "from setup.sh or a hand edit".
- Optional items, all taken:
  - The stuck merge checks git's return code (smoke: M stuck on common.txt).
  - A merge that fails without conflicts removes the checkout.
  - Every removal prunes (smoke: a folder deleted by hand, then gating again).
  - A merge in progress gets its own message.
The hubnode checked fb34ab1 by diff and with a repro.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because the gate's behaviour is documented in `plugin/templates/jig/RULES.md` (Handoff, gate, merge: updated with the checkout's lifetime) and `plugin/skills/hubnode/SKILL.md` (updated). `plugin/skills/update/SKILL.md` lines 28-31 ("`update` runs none") are now stale for gate scratch, and that file isn't on this job's list: see Left.

## Shared files changed
- `plugin/templates/jig/jig.py`: mark, merge, gate, open, update (the fix itself).
- `plugin/templates/jig/RULES.md`: the gate checkout lives until the job is marked gated or merged.
- `plugin/skills/hubnode/SKILL.md`: drop the hand-run remove; mark removes the checkout.
- `tests/smoke.sh`: cases in `update`, `merge_after_sync`, `report_fixes`.

## Test by hand
In a repo with a job: `jig gate J`, run the printed `(cd … && check.sh)`, then `jig mark J gated`. It prints "removed the gate's scratch checkout", and `git worktree list` has no gate-J.

## Left
- `plugin/skills/update/SKILL.md` (~28-31) should say that update removes a clean gate scratch checkout itself on `--apply`. That's a one-line skill edit for the hubnode, or a share for this job.
- The FEATURES.md row is the hubnode's.
