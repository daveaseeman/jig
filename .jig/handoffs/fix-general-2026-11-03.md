# Handoff: fix-general

Commit: 4c248d92691fe2512c1d2650bba0f06a94592d3c
Date: 2026-11-03
Spec: .jig/specs/fix-general.md
Review: tier 2, effort 1
Ran: claude-opus-5-5 at xhigh, fresh context (subagent)

## Built
`/jig:fix` gains step 3, **General?**, in the owner's wording: before deciding, ask whether
fixing the report would help a typical repo using the feature as RULES.md describes it. Decide
(now step 4) goes by step 3 first, and its new first bullet, **too specific**, drops the report
saying what jig promises and how the reporting repo can meet its stricter need. Show is step 5.

## Done-when evidence
- New step 3, owner's wording: `sed -n 16,24p plugin/skills/fix/SKILL.md` shows it verbatim, before Decide (4) and Show (5).
- Decide's "too specific" bullet: SKILL.md step 4, first bullet; "Decide by step 3, then by `/jig:bug`'s fourth step". Show (5) shows every drop's reason, unchanged.
- No repo or past case named: `grep -niE 'maige|threat' plugin/skills/fix/SKILL.md` → no match (exit 1).
- FEATURES row: edited by the hubnode in the main checkout (gitignored), not in this branch.
- Smoke: `bash tests/smoke.sh; echo rc=$?` → rc=0, tail:
  `PASS  feedback: once it's dropped, the release goes through beside the other repo's report`
  `PASS  feedback: jig repos prints where tool reports wait`
  `PASS  isolation: the user's real jig config folder is unchanged by the run`
- Validator: `claude plugin validate ./plugin` → `✔ Validation passed`.

## Review
Round 1: a fresh-context claude-opus-5-5 subagent, set to xhigh (it reported its effort as
unknown). Nothing blocking; two should-fix, four optional.
1. Step 4 didn't say step 3 wins → Decide now reads "by step 3, then by `/jig:bug`'s fourth step", too-specific bullet first. Fixed in 4c248d9.
2. `jig staging drop` takes no reason (a reason exits 2) → bullet says "saying step 3's reason and suggestion"; spec's Out of scope corrected. Fixed in 4c248d9.
3. Spec said "Step 4 (Show)" → "Step 5 (Show)". Fixed in 4c248d9.
4. Too-specific and workaround bullets overlap → workaround tagged "(`/jig:bug` step 4)". Fixed in 4c248d9.
5. FEATURES row → updated by the hubnode.
6. `/jig:feedback` doesn't ask the reporter the same question → deferred, row in `.jig/ledgers/DEFERRED.md`.

## Fold-in
<!-- Every documentation page that covers code this changed. Replace each ___ and tick the
     box: the page is updated, or it needed no change and this says why. The gate refuses
     an unanswered line. An UNOWNED file has no page covering it: add it to docmap in the
     board, or say why it needs none. -->
- [x] no code changed — nothing to fold in (a skill's text only; no docs page covers plugin/skills)

## Shared files changed
- `.jig/specs/fix-general.md` (common): review findings 2 and 3 corrected the spec's text.
- `.jig/ledgers/DEFERRED.md` (common, append): row for deferred finding 6.

## Test by hand
Next `/jig:fix` run with feedback staged: a report that only a repo wanting more than RULES.md promises would hit is dropped as too specific, with what jig promises and a suggestion shown.

## Left
Nothing. Finding 6 is a possible follow-up spec, the owner's call.
