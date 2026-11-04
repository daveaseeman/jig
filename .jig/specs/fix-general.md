# /jig:fix asks whether a fix is general

Source: owner, 2026-11-03, after the first `/jig:fix` run turned one repo's threat model into a spec.

## Intent
`/jig:fix` checks that a report reproduces, but not that fixing it helps any repo besides the
reporter. Add that question before the decision, so a fix fitted to one repo is dropped with a reason.

## Done when
- [ ] `plugin/skills/fix/SKILL.md` has a new step 3, before Decide (which becomes 4, Show 5),
      worded as the owner gave it:

      > 3. **General?** Picture another repo using the same feature the way RULES.md describes
      > it, run by people and agents making ordinary mistakes. It could be a regular repo, a
      > pararepo or a metarepo, whichever applies. Is solving this problem likely to lead to a
      > general improvement for that repo, too? If so, it's worth keeping; if not, it might be
      > overfit to one example. The solution is definitely not worth implementing if the problem
      > only appears for a repo that wants more than RULES.md promises (like a stricter
      > guarantee, or a policy or tool of its own) or if someone would have to be working
      > against jig on purpose to trigger it. If the fix is too specific, then: drop it, say what
      > jig does promise, and suggest how the reporting repo can meet its stricter need itself.

- [ ] Decide gains a bullet: **too specific** (step 3) → `jig staging drop <file>`, with step 3's
      reason and suggestion. Step 4 (Show) shows that reason like any other drop's.
- [ ] The skill names no repo and no past case.
- [ ] The `fix` row in `marketing/FEATURES.md` (main checkout, gitignored) says it drops a fix
      too specific to one repo. The hubnode edits it before the change.
- [ ] Smoke passes, and the validator passes.

## Out of scope
- Any code: `jig staging drop` already takes a reason.
- Re-running `/jig:fix` on reports already decided.

## Touches
`plugin/skills/fix/SKILL.md`.

## Workflow
spec: tier 2, effort 2
execute: tier 2, effort 3
review: tier 2, effort 1
check: tier 3, effort 4
