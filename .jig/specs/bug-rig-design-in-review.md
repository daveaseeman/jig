# Bug: rig's dependency rules were designed in review rounds

Source: the owner, jig hubnode session, 2026-11-16: "its supposed to be 3 strikes you're out, so bug on third failure". The hubnode asked the bug role why the job `rig` needed three fix rounds, and whether anything still needs correcting now that its last review is clean.
Bug-for: rig

## Intent
rig's spec says what its fix rounds decided, its picture counts every question it puts to the
owner, and this spec, which unlocks rig's next review, doesn't come back as a job to start
once rig merges. The rule whose absence let a clean job reopen goes to bug-strike-count, which
rewrites the same lines. The strike count itself is bug-strike-count's.

## 1. Why
1. Why three blocking reviews? Strike 1 came from the spec's grouping text. Strikes 2 and 3 both
   came from cycle handling, added after a clean review at 809f22e. [seen]
2. Why build cycles after a clean review? The hubnode relayed its 3 should-fix and 4 optional
   findings as "take these". Optional 5 asked for cycles, which the spec never names. [seen]
3. Why did nothing stop that pass? "One round of should-fix is enough" is only in the review
   skill. The hubnode skill and RULES.md, where findings are routed, don't say it. [seen]

Strike 1: review-work blocked because the spec put a dependent item "in the same group" of
"proposed jobs", so the build offered merge or keep apart to two specs that only depend. [seen]
Strikes 2 and 3: the cycle answer was written in fix messages, not the spec, and rig's own Never
barred `/jig:stage`'s remedy (edit one `after:` header) until round 3. [seen]

Root: rig's dependency rules (a dependency orders separate jobs; a cycle waits on the owner and
is broken in one item's own line) were never in its spec, so they were designed in review
rounds, two of them in a pass reopened after a clean review.

## 2. Givens
- [seen] rig's review log (`.git/jig/reviewed.log`): 3365c56 review-work, 1 blocking; 809f22e
  review-change, 0 blocking; a0b9276, 1; e76ff8f, 1; 832dc69, 0. A review came back clean after
  the first fix round; the brief's list of four leaves it out.
- [seen] After a clean review with nothing changed since, `next_step` returns handoff (jig.py
  ~2184). The hubnode's message on 809f22e: "0 blocking findings ... Take these ... Another short
  review-change follows", then should-fix 1-3 and "optional, take these" 4-7.
- [seen] Optional 5: "An `after` cycle ... mark both items `answer`, or list them under Waiting
  on". Should-fix 3 turned the next step into a list (taken Up next items before the real one).
- [seen] a0b9276 built both. Its review blocked on the cycle answer: removing "the other's" line
  left the chosen item waiting, and editing a staged header broke rig's Never. Its should-fix:
  judge only next-step items whose state is open.
- [seen] e76ff8f put a staged file's answer under `## Owner's answers`. Its review blocked: `jig
  rig` and `jig staging resolve` read only the `after:` header (jig.py ~8105-8112), so no answer
  broke a staged ring. 832dc69 edits the chosen file's own header, as `/jig:stage` does (stage
  SKILL.md:77-78); its review was clean. rig's Never has barred that edit since 3365c56.
- [seen] Strike 1: rig.md:33-35, "grouped into proposed jobs (overlapping Touches → one job ...;
  `after:` and spec dependencies → ordered within it)", and :64-65, "placed after it in the same
  group". 3365c56 joined overlap or dependency in one union, with no record of which, and its
  block 4 offered every group of more than one spec merge or keep apart.
- [seen] rig.md has no line on cycles (`grep -c cycle` is 0), nor on the `opens` states, overlap
  with a waiting spec outside a group, or taken Up next items. RULES.md's rig paragraph
  (~714-730) and the skill state them. Round 1's two readings went into the spec as
  `Interpreted:` lines; nothing after round 1 did.
- [seen] `review/SKILL.md:122`: "one round of should-fix is enough". `hubnode/SKILL.md` and
  RULES.md never mention should-fix or optional findings; the work skill says only that an
  untaken one gets a DEFERRED row. Round 1 took review-work's 4 should-fix and 3 optional; the
  pass after 809f22e was a second round.
- [seen] At 832dc69, `bash tests/smoke.sh rig` passes 21 of 21 (run for this spec).
- [seen] Throwaway repo at 832dc69: two waiting specs sharing a path print "0 things waiting on
  your answers; 0 can start now." and "Waiting on you: nothing", while `jig consolidate` says to
  answer the group before opening any of it. A spec and a staged file building after each other
  print the same count, the cycle listed only under Waiting on. `waiting_on_you` counts only open
  or unjudged items (jig.py ~11882-11887).
- [seen] Throwaway repo: a spec carrying `Bug-for: j`, named by no open job or note, is listed
  under Can start now: `waiting_specs` (jig.py ~1267) never reads `Bug-for:`. No spec on main
  carries one yet; this is the first.
- [seen] Throwaway repo: with staged `a.md` (`after: b`) and `b.md`, `--json` lists the items a,
  b (kind, path) and the group b, a; `jig staging resolve a.md` refuses while b.md is staged,
  naming it.
- [seen] bug-strike-count (main, c575577) counts strikes per part. `blocking_reviews` counts every
  blocking review in the part, a clean one between them too, so rig's real sequence (blocking,
  clean, blocking, blocking) reaches Bug at e76ff8f's review. Its Source lists only the blocking
  reviews.
- [assumed] The hubnode took the post-clean findings on its own call, not the owner's: its
  session isn't readable from here. The fix doesn't depend on it; the rule binds either way.

## 3. One layer up
- `jig consolidate` (`overlap_groups`, jig.py ~1295) groups waiting specs by Touches overlap
  alone: a dependency never joins a group and no cycle can form, so strike 1's mix-up can't
  happen there. Its "proposed as one job" is right for its groups. [seen]
- `jig staging` (`batch_order` ~7933, `resolve` ~8104-8112, `staging check`, `/jig:stage`) names
  a cycle's members apart from the files that only wait on one, refuses `resolve` with "fix one
  header's after:", and fails a batch holding a cycle before it is staged. No such problem: it
  is the pattern rig reached in round 3. [seen]
- What's different: staging's cycle rule was written once, with its check, before it was built.
  rig's was written in fix messages, against a Never that barred staging's remedy. [seen]
- The pattern that already solves "a reviewer found a case the spec never names" is the spec's
  Decisions: rig's round 1 put its two readings there as `Interpreted:` lines. Rounds 2 and 3
  didn't. [seen]
- A sibling gap this spec is the first to reach: a `Bug-for:` spec lands on trunk with its job,
  and `waiting_specs` then reads it as waiting. [seen]

## 4. Correction
Correction, not a workaround: each part changes what produced it.

In the rig job (its owns and shares cover every file; one pass, then one review-change):
1. **The spec catches up.** `.jig/specs/rig.md` says what the rounds settled, so the gate and
   later readers judge against it:
   - Can start now: overlapping Touches are one job to answer (merged or kept apart, as `jig
     consolidate` groups); a dependency (`after:`, `Build after`) puts items in one group as
     separate jobs that open in order, with nothing to answer.
   - Waiting on you and the count line: open staged items, the next step whose state is open,
     each overlapping pair and each dependency cycle.
   - Done when, Grouping, gains the cycle: it waits on the owner, whose answer removes the other
     ring members from the chosen item's own `Build after` line or `after:` header, as
     `/jig:stage` breaks a staged cycle.
   - Decisions: the cycle answer, the `opens` states, overlap with any waiting spec, and an Up
     next item taken only by its exact page name, as readings the hubnode accepted 2026-11-16.
2. **The picture counts every question it asks.** `rig_state`'s `waiting_on_you` counts each
   overlapping pair and each dependency cycle once (a ring once, not per member), beside open
   and unjudged items, and `rig_text` lists them under Waiting on you. The skill's count line
   and Waiting on you say the same, and RULES.md's rig paragraph says what the count counts.
3. **A bug spec isn't a waiting spec.** `waiting_specs` skips a spec carrying a `Bug-for:` line:
   it is committed on its job's branch and reaches trunk only when that job merges, built. The
   board's waiting-spec sentence (RULES.md ~62-64) says so.

Carried to bug-strike-count, which rewrites the same paragraphs (hubnode SKILL.md ~120-123,
RULES.md's "Fix rounds are counted" contract): the rule whose absence let rig reopen after a
clean review. Proposed text, for the owner:
> A review with no blocking findings ends the fixing: the job hands off, as `jig next` says.
> Should-fix and optional findings get one round per part; what is left after it gets DEFERRED
> rows. A finding that needs behavior the spec never names is a spec change before it is built
> (an `Interpreted:` line the hubnode accepts, or the owner's answer), or an Up next item.

## Done when
- [ ] The fix fires: smoke `rig` adds two waiting specs sharing a path and two specs that build
      after each other. `waiting_on_you` in `jig rig --json` rises by exactly 2, the count line
      says so, and `Waiting on you:` has one line for the pair and one for the cycle. At 832dc69
      neither is counted or listed there. The existing first case still prints `3 things
      waiting on your answers; 1 can start now.`
- [ ] Smoke `rig`: a committed spec carrying `Bug-for: <job>`, named by no open job or note, is
      in neither `jig rig --json`'s items nor `jig consolidate`'s groups; the same spec without
      that line is listed. After rig merges, `jig rig --json` on trunk has no item for
      `.jig/specs/bug-rig-design-in-review.md`.
- [ ] `grep -c cycle .jig/specs/rig.md` is at least 1 (0 at 832dc69), `grep -n 'ordered within
      it' .jig/specs/rig.md` is empty, and its Waiting on you line names overlapping pairs and
      cycles.
- [ ] `plugin/skills/rig/SKILL.md` section 2's count line and Waiting on you name overlapping
      pairs and cycles; RULES.md's waiting-spec sentence names the `Bug-for:` exception.
- [ ] `.jig/scripts/check.sh` exits 0; `bash tests/smoke.sh rig next consolidate` passes;
      `claude plugin validate ./plugin` passes. The full suite runs once at the check step.

## Out of scope
- The original symptom, the count ("bug on third failure"): bug-strike-count owns it. Under its
  rule rig's sequence reaches Bug at e76ff8f's review, the clean 809f22e between strikes
  included; its smoke should replay that sequence, clean review and all, since its Source lists
  only the blocking ones.
- The hubnode rule above: built with bug-strike-count, as one job for the same lines.
- Auto mode resolving a staged file before the one it comes after: `jig staging resolve`
  refuses, naming the file to resolve first. The remaining risk is one refused command.
- `jig open` doesn't read `Build after`: rig only proposes, and offers only `opens: now`.
- The DEFERRED rows the rounds left stay as they are.

## Touches
- `.jig/specs/rig.md` (What it shows, Done when: Grouping, Decisions)
- `plugin/templates/jig/jig.py` (`waiting_specs`, `rig_state`, `rig_text`)
- `plugin/templates/jig/RULES.md` (The board: the waiting-spec sentence; Workflow: rig)
- `plugin/skills/rig/SKILL.md` (2. The picture: the count line, Waiting on you)
- `tests/smoke.sh` (`rig`)

## Alternatives considered
- Hand rig off now with no change, its last review being clean — rejected because once rig
  merges `jig rig` offers this spec as a job to start, and its headline reads "0 things waiting
  on your answers" while its batch asks about an overlap or a cycle — [seen] (throwaway repo at
  832dc69).
- Build the hubnode rule in the rig job — rejected because bug-strike-count rewrites the same
  hubnode paragraph and RULES.md contract, so two jobs would edit the same lines — [seen]
  (bug-strike-count's Givens and Touches).
- Enforce the rule in jig.py (refuse a review-change after a clean review) — rejected because
  jig can't tell a should-fix pass from a hand-resolved sync or a new part, and `jig next`
  already names handoff after a clean review — [seen] (`next_step`).
- Reset the strike count at a clean review — rejected because a reset would hide exactly rig's
  strikes 2 and 3, which came after the clean 809f22e — [seen] (the review log).
- Call rounds 2 and 3 reviewer noise — rejected because both holes were real: the first answer
  left the chosen item waiting, and the second couldn't change what `jig rig` reads — [seen]
  (the findings on a0b9276 and e76ff8f; jig.py ~8105-8112).
- Retire this spec by naming it on a second `Spec:` line in rig's note — rejected because `jig
  handoff --spec` takes one spec and the gate reads only the first line, so every Bug job would
  need the same hand edit — [seen] (jig.py ~2498, ~12048).
- Count each cycle member, not each ring — rejected because a ring is one question (block 6 asks
  which item goes first) — [seen] (rig SKILL.md, step 3).

## Decisions
- Interpreted, for the owner's yes: "things waiting on your answers" are the open and unjudged
  items, the open next step, each overlapping pair and each dependency cycle, every block that
  asks the owner a question (blocks 1, 2, 5 and 6). The write-a-spec and start-a-job offers are
  what "can start now" counts.
- Interpreted: a spec carrying `Bug-for: <job>` is built in its job, so it is never waiting.
- Recommended, for the owner: carry the hubnode rule (§4) into bug-strike-count's spec before
  that job opens, its Done when gaining "`grep -n 'ends the fixing'` finds it in
  `plugin/skills/hubnode/SKILL.md` and RULES.md".
- Kept separate from bug-strike-count: this spec is built in the rig job and unlocks its next review; bug-strike-count changes the strike count and the text that states it.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
