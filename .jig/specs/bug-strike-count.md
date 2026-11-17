# Bug: the fix limit allows a fourth failure; the owner's rule is three strikes

Source: the owner, jig hubnode session, 2026-11-16: "That's not right, its supposed to be 3 strikes you're out, so bug on third failure not fourth". Seen on the job `rig`, whose reviews read: review-work 3365c56 blocking, review-change 809f22e clean, then a0b9276 and e76ff8f blocking. `jig reviewed` printed "Fix round 3 of 3" after e76ff8f and sent a third fix round, where the owner's rule had Bug start. The bug role on rig (`.jig/specs/bug-rig-design-in-review.md`, on rig's branch) found the two later strikes came from a should-fix pass the hubnode sent after the clean 809f22e, which nothing in the hubnode skill or RULES.md forbids.

## Intent
A job's third blocking review, counting its first review-work, starts Bug. `jig reviewed`
refuses a fourth review of that job (full or change) until a spec carrying `Bug-for: <job>`
is committed, and every text that states the limit says "the third blocking review".
A review with no blocking findings ends the fixing, so a clean job isn't reopened into new
strikes.

## 1. Why
- Why did rig get a third fix round? `blocking_rounds` (jig.py ~2075) returns blocking reviews
  minus one, and `cmd_reviewed` refuses only when that reaches `FIX_ROUNDS = 3`: four
  blocking reviews. [seen]
- Why minus one? The code counts fix rounds ("the first blocking review starts round 1 and
  ends none"), not failures. [seen]
- Why rounds? The Oct 30 workflow spec wrote "up to three rounds, then /jig:bug", which the
  roles-and-flows job carried into code, RULES.md, the skills and the README as-is; the owner's
  intent was three failures. [seen]

## 2. Givens
- [seen] `FIX_ROUNDS = 3` (jig.py ~117); `blocking_rounds`, `cmd_reviewed`'s refusal and its
  "Fix round N of 3" / "That was fix round 3" lines (~2075-2136); `next_step`'s bug reason
  (~2175); `FLOWS`' Bug trigger "a fourth fix round" (~97).
- [seen] Text stating the old count: RULES.md (the Bug row ~650; "Fix rounds are counted…"
  ~673-676), README.md's Bug row (~165), and the hubnode (~117), review (~124), work (~82),
  bug (~8, ~25, ~54) and spec (~65) skills.
- [seen] smoke `next`/`workflow` cases (~2076-2088) assert the old count.
- [seen] The README drawing comes from `FLOWS` (`scripts/roles_svg.py`); `check.sh` fails
  when it is stale.

- [seen] rig's clean review at 809f22e was followed by 3 should-fix and 4 optional findings the
  hubnode sent to build; one asked for cycle handling rig's spec never named, and both later
  strikes were about it. "One round of should-fix is enough" is only in review/SKILL.md; the
  hubnode skill and RULES.md, which route findings, don't say it.

## 3. One layer up
Counting is per part of a job (a handoff note ends a part); that stays. Nothing else counts
review failures, so there is no sibling path.

## 4. Correction
Count strikes: the number of blocking reviews in the part. A third blocking review is the
limit; the next `jig reviewed` is refused until the bug spec is committed. `FIX_ROUNDS`
becomes `STRIKES = 3`. Correction, not a workaround.

The rule whose absence reopened rig after a clean review goes in the hubnode skill (beside the
strike paragraph) and RULES.md's count contract, in these words (the owner, 2026-11-16, "2. a"):
> A review with no blocking findings ends the fixing: the job hands off, as `jig next` says.
> Should-fix and optional findings get one round per part; what is left after it gets DEFERRED
> rows. A finding that needs behavior the spec never names is a spec change before it is built
> (an `Interpreted:` line the hubnode accepts, or the owner's answer), or an Up next item.
The review and work skills point to it rather than restate it.

## Done when
- [ ] Smoke: three blocking reviews of one job (review-work, then two review-changes) make
      `jig next` name bug, and a fourth `jig reviewed` (full or `--change`) is refused, naming
      `Bug-for: <job>`. With that spec committed, it is recorded. Two blocking reviews still
      leave a fix round. The reported case: rig's sequence (blocking, clean, blocking,
      blocking) yields bug after the fourth review, the third blocking one.
- [ ] `jig reviewed` prints the strike, e.g. "Strike 2 of 3: the work session fixes them, then
      review-change", and on the third "Strike 3 of 3: Bug runs next; the next review is
      refused until the bug role's spec, with `Bug-for: <job>`, is committed".
- [ ] `FLOWS`' Bug trigger and `next_step`'s reason say "a job's third blocking review", and
      the README drawing is redrawn (`python3 scripts/roles_svg.py`; `check.sh` passes).
- [ ] RULES.md, README.md and the hubnode, review, work, bug and spec skills say the third
      blocking review starts Bug: `grep -rniE "fourth fix round|three fix rounds|third blocking fix round" plugin README.md` is empty.
- [ ] The clean-review rule: `grep -n 'ends the fixing' plugin/skills/hubnode/SKILL.md
      plugin/templates/jig/RULES.md` finds it in both, and `review/SKILL.md`'s "one round of
      should-fix" line points to it.
- [ ] `.jig/scripts/check.sh` exits 0; the smoke sections touched (`next`, `workflow`, and any
      others the grep finds asserting the old text) pass; `claude plugin validate ./plugin`
      passes; the full suite runs once at the check step.

## Out of scope
- Changing what a part is (a handoff note still ends one).
- Jobs already past their strikes on this machine: the new count applies to the next `jig reviewed`.

## Touches
- `plugin/templates/jig/jig.py` (`FIX_ROUNDS`, `blocking_rounds`, `cmd_reviewed`, `next_step`, `FLOWS`)
- `plugin/templates/jig/RULES.md` (Workflow: the Bug row, the count)
- `plugin/skills/hubnode/SKILL.md`, `review/SKILL.md`, `work/SKILL.md`, `bug/SKILL.md`, `spec/SKILL.md`
- `README.md`, `assets/roles-and-flows-light.svg`, `assets/roles-and-flows-dark.svg`
- `tests/smoke.sh` (`next`, `workflow`)
- `marketing/FEATURES.md` (gitignored: the hubnode's)

## Alternatives considered
- Keep counting fix rounds and set the limit to 2 — rejected because "fix round 2 of 2" still
  names rounds, not the failures the owner counts, and the text would keep the wrong model —
  [seen]: the owner's words count failures.
- Count only review-changes as strikes — rejected because the owner's "third failure" counts the
  first review-work too, as rig's case shows — [seen].

## Decisions
- The owner, 2026-11-16: "3 strikes you're out, so bug on third failure not fourth".
- The owner, 2026-11-16, on the bug role's proposal from rig: carry the clean-review rule into
  this spec ("2. a").
- Interpreted: a clean review between strikes doesn't reset the count; resetting would hide
  rig's strikes 2 and 3.
- Interpreted: a strike is a review that recorded at least one blocking finding, full or change,
  within the current part of the job.
- Kept separate from every-copy: different code (every-copy adds `jig reading-list --claims`; bug-strike-count changes `jig reviewed`'s count), sharing jig.py, RULES.md, the spec skill and smoke.sh. The owner, 2026-11-16: "Keep separate".

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
work: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
