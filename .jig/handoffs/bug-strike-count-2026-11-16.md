# Handoff: bug-strike-count

Commit: bff74484fdfa6f182c7bf5198e3bb71170d018b4
Date: 2026-11-16
Spec: .jig/specs/bug-strike-count.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
A job's third blocking review, counting its first review-work, starts Bug: `STRIKES = 3`
replaces `FIX_ROUNDS`, a strike is a review recording blocking findings (full or change) in the
current part, and a clean review between strikes resets nothing. `jig reviewed` prints
"Strike N of 3" and refuses a fourth review until a `Bug-for: <job>` spec is committed; `jig
next` names bug at the third strike. With a bug spec already committed, both say the fixing goes
on ("Strike N, under the bug role's spec"). The clean-review rule ("A review with no blocking
findings ends the fixing…") is in the hubnode skill and RULES.md; review and work point to it.
FLOWS, RULES.md, README (table and redrawn SVGs) and the hubnode, review, work, bug and spec
skills say the third blocking review starts Bug.

## Done-when evidence
- Smoke strikes: `bash tests/smoke.sh next workflow svg rig` → rc 0, 97 PASS, 0 FAIL: "reviewed: a second blocking review is strike 2, and leaves a fix round", "next: after the third blocking review, the next step is bug", "reviewed: a fourth review, as a review-change, is refused, naming Bug-for", full refused too, "with the job's bug spec committed, the fourth review is recorded", and rig's sequence: "next: blocking, clean, blocking, blocking is bug".
- Strike lines: smoke greps "Strike 2 of 3: the work session fixes them, then review-change" and "Strike 3 of 3: Bug runs next; the next review is refused until the bug role's spec, with `Bug-for: k`, is committed" — PASS.
- FLOWS/next_step/drawing: `python3 scripts/roles_svg.py` wrote both SVGs; `.jig/scripts/check.sh` → rc 0.
- Text: `grep -rniE "fourth fix round|three fix rounds|third blocking fix round" plugin README.md` → empty.
- Clean-review rule: `grep -n 'ends the fixing'` → hubnode/SKILL.md:129, RULES.md:680; review/SKILL.md's "one round of should-fix" line points to it.
- check.sh rc 0; `claude plugin validate ./plugin` → "✔ Validation passed"; the full suite is the check step's.

## Review
- review-work of ea5d2f4: blocking 0.
  - should-fix: at strike 3 with a `Bug-for` spec already committed, `jig reviewed` said Bug runs next while `jig next` said fix. Taken (bff7448): the branch is `elif not bug_spec_for(...)`, and smoke job k6 shows both agree.
  - optional: review/SKILL.md "the rounds are counted from it" → "the strikes". Taken.
  - optional: RULES.md Contracts opens "Each is a refusal…", but the clean-review bullet isn't one. Taken: the rule is now its own paragraph just after the Contracts list, not in the count contract the spec names.
  - optional: the unreachable `not bug_spec_for` arm. Taken with the should-fix.
  - should-fix, deferred (DEFERRED.md row, [seen]): a committed `Bug-for` spec clears the limit for every later part. It changes what clears the refusal, which the spec never names; the hubnode takes it to the owner.
- review-change of bff7448: blocking 0, no new findings. One optional note, no change: the clean-review rule sits after the Contracts list rather than in the count contract.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Workflow: the Fix and Bug rows, the strike contract, the clean-review rule), with the hubnode, review, work, bug and spec skills and README.

## Shared files changed
- `plugin/templates/jig/jig.py`: the strike count (`STRIKES`, `cmd_reviewed`, `next_step`, `FLOWS`); every-copy changes other code (`jig reading-list --claims`).
- `plugin/templates/jig/RULES.md`: the Fix/Bug rows, the strike contract, the clean-review paragraph.
- `plugin/skills/spec/SKILL.md`: one line on a bug spec's `Bug-for:`.
- `tests/smoke.sh`: `sec_next` cases only.
- `.jig/ledgers/DEFERRED.md`: one appended row.

## Test by hand
In a throwaway repo, open a job, commit, and record three blocking reviews (`jig reviewed --blocking 1`, then `--change --blocking 1` twice, with a commit between each): watch for "Strike 3 of 3: Bug runs next", `jig next` naming bug, and a fourth `jig reviewed` refused until a spec with `Bug-for: <job>` is committed.

## Left
Nothing on this spec. The DEFERRED row (a `Bug-for` spec lifts the limit for later parts) waits on the owner.
