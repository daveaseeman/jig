# Handoff: review-bug-feedback

Commit: 04de9fdc8589f0858e577264fe75cd37fa4f0089
Date: 2026-11-03
Spec: .jig/specs/review-bug-feedback.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at unknown, fresh context (subagent; effort set to xhigh, not readable by the subagent)

## Built
- `bug` workflow step (tier 2, effort 1, after `spec`): tier no worse and effort no lower than
  spec's; a field the repo leaves unset follows a raised spec.
- Review rule compares tier against execute's; review's effort rule is dropped (owner, mid-build).
- `/jig:review` doesn't rerun the full checks; only the narrowest check a finding needs.
- `/jig:feedback` is owner-only (`disable-model-invocation: true`); RULES.md's bug-in-jig line
  and `/jig:update`'s blocked case hand the decision to the owner.
- Hubnode and fix skills run `/jig:bug` at the `bug` step; review skill and templates/AGENTS.md
  ask the hubnode to run the non-convergence `/jig:bug`.

## Done-when evidence
- Review doesn't rerun checks: `plugin/skills/review/SKILL.md` (text).
- `bug` step: smoke workflow "the bug step is printed, in step order after spec"; bug tier 3 and
  bug effort 3 refused by `jig workflow` and the hook; bug tier 1 effort 2 accepted; a raised
  spec raises an unset bug field, a set one is kept. All PASS.
- Review vs execute (amended spec item): review effort 2 and effort 3 with execute at 3
  accepted; review tier 3 refused by `jig workflow` and the hook, naming execute's tier. PASS.
- RULES.md table lists `bug` and the review rule; hubnode *Who runs each step* has the `bug`
  bullet; fix skill runs `/jig:bug` at that step (text).
- Four-line pre-bug spec gates and the weaker-review warning fires: smoke workflow "a spec with
  the four pre-bug Workflow lines gates; ... warned about, not refused". PASS.
- Feedback owner-only: frontmatter set; smoke staging "only the skills that change the repo,
  tag, write user config or report on jig are user-only" lists `adopt feedback init release
  repos update`. PASS. RULES.md bug-in-jig line and update/SKILL.md blocked case (text).
- Section runs (full suite runs at the gate):
  - c9ac26c: `bash tests/smoke.sh workflow staging feedback rules` → 133 PASS, 0 FAIL, rc=0
  - 635ec7c: same sections → 132 PASS, 0 FAIL, rc=0
  - 1a67c7e (+ AGENTS.md line): `bash tests/smoke.sh workflow staging rules update` → 219 PASS,
    0 FAIL, rc=0
  - 04de9fd: `bash tests/smoke.sh staging` → 54 PASS, 0 FAIL, rc=0
  - `claude plugin validate ./plugin` → "✔ Validation passed"; `python3 .jig/jig.py check` → ok, rc=0
- FEATURES.md rows: edited by the hubnode on trunk, not on this branch.

## Review
Round 1: fresh claude-opus-5-5 subagent, set to xhigh, reported unknown; it didn't rerun the
suite. Nothing blocking; four should-fix and five optional.
- 3, 5, 6, 7, 8: taken, fixed in 1a67c7e and 04de9fd.
- 1, 2, 4: in repo files (README, FEATURES, AGENTS.md); fixed by the hubnode on trunk.
- 9: resolves at merge.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its workflow rules are documented in RULES.md's Workflow section, updated in this job

## Shared files changed
- `plugin/templates/AGENTS.md`: shared by the board at c9b765c for review finding 8 (one line:
  in a repo with a hubnode, ask it to run `/jig:bug`).

## Test by hand
- In a repo, `python3 .jig/jig.py workflow` prints five lines with `bug: tier 2, effort 1`.
- Ask a session to report a jig bug: it should tell the owner, not run `/jig:feedback`.

## Left
- This repo's own review override, on trunk after the release and `/jig:update` (spec's Out of scope).
