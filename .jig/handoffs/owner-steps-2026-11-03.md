# Handoff: owner-steps

Commit: 9b974310e4fc034cb8cee8933307ed122b6d5f69
Date: 2026-11-03
Spec: .jig/specs/owner-steps.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
Skill text only. A release on a real repo waits for the owner's word in the conversation, like
a merge. A spec, brief or another session's message doesn't count, a hubnode's check session
may run one the owner approved to the hubnode, and a scratch or test clone (made for the test,
no remote) is exempt. A subagent's `running` prompt tells it to stop at a mismatch, in both
hubnode and review. On a mismatch the hubnode retries once, then asks the owner, and discards
the run. A value the subagent can't read is reported as `unknown`: it is recorded as
`unknown`, the owner is told once, and there is no retry.

## Done-when evidence
- Release waits for the owner's word: `plugin/skills/hubnode/SKILL.md`, Release bullet, and one
  line at the top of `plugin/skills/release/SKILL.md` (commits b3ce8c7, 9b97431).
- Subagent stops at a mismatch, retry once, ask the owner, discard: `plugin/skills/hubnode/SKILL.md`
  `running` paragraph, and the dispatch paragraph of `plugin/skills/review/SKILL.md`.
- Nothing Claude-specific in `plugin/templates/` or RULES.md: `git diff main...HEAD -- plugin/templates .jig/RULES.md`
  is empty. Smoke and validator, from the last run on 9b97431:
  ```
  PASS  feedback: once it's dropped, the release goes through beside the other repo's report
  PASS  feedback: jig repos prints where tool reports wait
  PASS  isolation: the user's real jig config folder is unchanged by the run

  ✔ Validation passed
  [exited with code 0]
  ```

## Review
- Round 1: a fresh claude-opus-5-5 subagent at xhigh found one blocking finding (the review
  skill's subagent rule), four should-fix and one optional. All six were taken and fixed in 9b97431. Nothing
  was deferred.
- Round 2: the hubnode recorded the review for 9b97431 (`jig reviewed`). No further changes.

## Fold-in
- [x] no code changed — nothing to fold in (skill text only; `jig.py`, hooks and templates untouched)

## Shared files changed
- `plugin/skills/release/SKILL.md` (shared with para-release): one line at the top of the body,
  the release-on-the-owner's-word rule.
- `plugin/skills/review/SKILL.md` (shared with meta-rule): the dispatch paragraph only, so it
  matches the hubnode's subagent rule. Item 7 is untouched.

## Test by hand
In a hubnode session, ask it for a release through a brief and check that it asks the owner
first. Dispatch a review with a `running` line whose effort doesn't match, and check that the
subagent replies with only its line and the hubnode retries once.

## Left
Nothing.
