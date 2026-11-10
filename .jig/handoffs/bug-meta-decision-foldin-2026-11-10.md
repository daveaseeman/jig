# Handoff: bug-meta-decision-foldin

Commit: 04e99ceb1eca5d8770a47c61b46b7b3074774fcc
Date: 2026-11-10
Spec: .jig/specs/bug-meta-decision-foldin.md
Review: tier 2, effort 2
Ran: fresh Opus review of b2f6296: no blocking; S1 citing pages got Undefined lines, S2 register outside entry_files missed (both reproduced), fixed in 04e99ce with smoke cases; O3 one diff + early return, O4 trunk's meta taken; O5 deferred. Hubnode checked 04e99ce by diff and smoke metarepo.

## Built
<!-- what this delivers, in a few lines -->
In a metarepo, `jig handoff` now writes one fold-in line for each entry page whose text cites a
decision whose row the branch added, edited or removed (superseded included). The line names the
ids, e.g. `(D-007)`. Ids match whole. The page holding the row and CHANGELOG.md are skipped. Rows
are read from every changed `.md`, as M2 reads them. The prefix and entry set are trunk's. The
register is read in one helper, `changed_decisions`, for decision-log. The gate is unchanged.
A repo with no meta.json gets the same fold-in as before.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Page A asked with (D-007), with no line for B (D-0070), the stray page, DECISIONS.md, CHANGELOG.md or "no code changed": `bash tests/smoke.sh metarepo` printed PASS for "a changed row asks the entry page citing it in passing, naming the id" and "no line for D-0070's page, a page outside entry_files, the register or CHANGELOG.md".
- Gate refuses, then passes: PASS "the gate refuses the note while the line is unanswered" and "and passes once it is answered".
- Superseded by D-012 asks A: PASS "a row marked superseded by asks the page citing it".
- Passing mention asked: page A cites D-007 mid-sentence, and the first case covers it.
- No meta.json keeps today's fold-in: full `bash tests/smoke.sh` printed 776 PASS and 0 FAIL (notes folder, bug-meta-decision-foldin-smoke-2.out).
- `claude plugin validate ./plugin` printed "✔ Validation passed". `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` found nothing (exit 1).
- Review fixes: PASS "a page asked only for a decision it cites gets one line, none for its Undefined entries" and "a row in a register outside entry_files still asks the entry page citing it".

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode review of b2f6296 found nothing blocking.
- S1: citing-only pages got Undefined lines. Fixed: those lines are now written only for docmap pages, with a smoke case.
- S2: a register outside entry_files was missed. Fixed: rows are read from every changed .md, as M2 does, with a smoke case.
- O3: taken. One diff, and an early return when no row changed.
- O4: taken. The prefix and entry set come from load_meta(trunk).
- O5: deferred to DEFERRED.md. As specced, the page holding the row is the row's home.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Fold-in).

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- plugin/templates/jig/jig.py: `foldin_lines`, plus the new `changed_decisions` and `decision_citers` next to `terms_changed`.
- plugin/templates/jig/RULES.md: one paragraph appended to Fold-in.
- tests/smoke.sh: a meta-fold fixture appended at the end of `sec_metarepo`.
- .jig/ledgers/DEFERRED.md: one appended row (O5), as the hubnode asked.

## Test by hand
<!-- what a person should click or watch -->
In a metarepo, change only one decision row on a branch, then run `jig handoff`. Each entry page citing that id gets a line naming it.

## Left
<!-- what remains on this job -->
Nothing. The FEATURES.md row is the hubnode's.
