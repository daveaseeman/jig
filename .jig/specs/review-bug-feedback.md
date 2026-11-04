# Lighter reviews, a bug step, and feedback on the owner's word

Source: owner, 2026-11-03, after a day of slow job cycles and a subnode writing feedback on its
own: "reviewers shouldn't rerun the suite", "lower review to high, keep /jig:bug at xhigh", "only
I should be able to write feedback".

## Intent
Three owner decisions, one job. Reviews stop repeating the checks the gate runs. Review can run
at high while a bug investigation keeps xhigh. Feedback on jig is written only when the owner
says so.

## Done when
**Review doesn't rerun the checks**
- [ ] `plugin/skills/review/SKILL.md`: the reviewer doesn't rerun the full checks the author
      already ran and showed; the gate runs them again. It runs only the narrowest check a
      specific finding needs, and says which.

**A bug step; review judged against execute**
- [ ] `WORKFLOW_DEFAULTS` gains `"bug": {"tier": 2, "effort": 1}`, in step order after `spec`.
      `jig workflow` prints it. Its rule: tier no worse than spec's, effort no lower than spec's.
- [ ] The review rule compares against `execute`, not `spec`: tier no worse than execute's. Its
      effort rule is dropped: any review effort is accepted. Review at effort 2 or 3 with execute
      at 3 is accepted; review at tier 3 with execute at tier 2 is refused, naming execute.
- [ ] RULES.md's workflow table lists `bug` and the new review rule. The hubnode skill's *Who
      runs each step* says a `/jig:bug` investigation, as a subagent or a session, runs at the
      `bug` step; `/jig:fix` runs each group's `/jig:bug` at that step.
- [ ] A spec written before this change (four Workflow lines) still gates, and `jig gate`'s
      weaker-review warning still works. Smoke cases for each item above, in the workflow section.

**Feedback only on the owner's word**
- [ ] `plugin/skills/feedback/SKILL.md` frontmatter has `disable-model-invocation: true`; its body
      says it runs only when the owner asks. The smoke case listing those skills includes it.
- [ ] RULES.md (the bug-in-jig line): say what in jig broke and tell the owner, then stop; the
      owner decides whether to run `/jig:feedback`. Don't patch, don't ledger.
- [ ] `plugin/skills/update/SKILL.md`, the blocked case: show the drafted report; save it only on
      the owner's word.

**Evidence**
- [ ] While building, run only `bash tests/smoke.sh workflow plugin` (and any section a change
      touches). The gate runs the full suite. The validator passes.
- [ ] `marketing/FEATURES.md` rows for `review`, `workflow`, `feedback` and `update`, edited first.

## Out of scope
- This repo's own review override (`"review": {"effort": 2}`): set on trunk after the release
  and `/jig:update`, since trunk's installed checker still holds the old rule.
- Choosing checks or review depth by what a diff touches: its own spec.

## Touches
`plugin/templates/jig/jig.py` (`WORKFLOW_DEFAULTS`, the workflow rules), `plugin/templates/jig/RULES.md`,
`tests/smoke.sh`, skills `review`, `hubnode`, `fix`, `feedback`, `update`.

## Alternatives considered
- Keep review harder than spec and lower spec to medium. Rejected: execute must stay below spec,
  so execute would fall to low. `[seen]`: jig.py's execute rule.
- Make `/jig:bug` part of `review`'s step. Rejected: it writes a spec, and runs before any diff
  exists. `[seen]`: bug skill step 5.
- Keep `/jig:feedback` model-invocable and rely on the text. Rejected: a subnode wrote feedback
  on its own; frontmatter makes it the owner's command, as `/jig:release` already is. `[seen]`:
  the release skill's frontmatter.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
