# Handoff: touches-abstract

Commit: b550295faba507124697b47d6b0b9d87900e80f6
Date: 2026-11-13
Spec: .jig/specs/bug-touches-abstract.md
Review: tier 2, effort 2

## Built
A decision entry's `Touches:` line can name a glossary term, `docs/glossary.md § <term>` (or `<meta>/docs/glossary.md § <term>` from a pararepo, checked against the cache at the pin), or `none — <reason>` (em dash or ` - `).
M2 checks the term against the glossary's headings and table rows, matched case-insensitively.
Two entries on one term are peers, and the whole glossary meets every term. A term never meets the pages of its genre.
Term pair lines fold in and pass the gate when answered. `none` has no peers, and `--peers` says why.
`jig update` no longer lists entries on a term or on none. RULES.md (Decision log: Touches, Peers, M2) covers all of it.

## Done-when evidence
`bash tests/smoke.sh` → rc=0, PASS 1249, no FAIL; `claude plugin validate ./plugin` → ✔ Validation passed (run on 7486524; the sync merge b550295 brought only .jig/jobs.json and a spec).
- [x] Reported symptom: PASS "touches terms M2: an entry naming a glossary term passes, in any case", PASS "Touches: none with a reason passes, commas and all", PASS "touches terms update: lists the entry with no line, not the one that touches none, nor those on a term".
- [x] Fix fires: PASS "touches terms: two entries on one term are peers, the whole glossary meets the term, a page in its genre doesn't", PASS "the page entry has no peer in the glossary", PASS "--peers on a none entry says it touches no page, and why".
- [x] Still refused: PASS "a term the glossary lacks is refused, naming it", "§ on a page other than the glossary is refused", "none with no reason is refused", "none beside a page is refused, either way round" (×2), "a missing page is still refused".
- [x] Pararepo: PASS "a pararepo names the metarepo's term at the pin", PASS "a pararepo naming a term the metarepo's glossary lacks at the pin is refused".
- [x] Fold-in: PASS "an entry on a term gets a pair line with each entry on it, and the none entry gets none".
- [x] Smoke and validator pass; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → empty.

## Review
Hubnode review of c91bfdb, all findings fixed in 7486524; review recorded for b550295.
1. Blocking — a term pair line could never pass the gate: `PAIR_LINE` refused a blank inside the parentheses, so `(docs/glossary.md § products)` didn't parse. Fixed: the parentheses take `page § term`. Smoke: PASS "touches terms gate: term pair lines answered agrees pass the gate" and PASS "a term pair with an entry trunk took after the handoff is refused, naming it".
2. `none — how AGENTS.md is written` was refused as mixing none with pages. Fixed: only a comma piece shaped like a pointer counts as a page. Smoke: PASS "a reason may name a file in prose"; the AGENTS.md case passes M2, and the root-document check still names AGENTS.md (PASS "a reason naming a root document is no page beside none").
3. Update's backfill line and RULES.md's M2 line said pages only. Fixed: both name the term form and `none — <reason>`. Covered by the update smoke case.
4. `none` parsing was loose. Fixed: exactly `none — <reason>` (em dash or ` - `); anything else that starts with none is refused naming the form. Smoke: PASS "none in another shape is refused, naming the form" (×3: `none: …`, `` `none` — … ``, `None — …`).
5. Optional — `placement_hints` changed: taken, listed under Shared files changed.
6. Optional — a term holding a comma was cut in two. Fixed: a non-pointer piece after a `§` piece joins it. Smoke: PASS "a term holding a comma is one term, and the pointer after it another".
7. Optional — the update case didn't check that `§` entries go unlisted. Taken: PASS "update: lists the entry with no line, not the one that touches none, nor those on a term".
None deferred, so no DEFERRED.md rows.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Decision log: the Touches, Peers and M2 paragraphs and the M2 row), updated here.

## Shared files changed
- plugin/templates/jig/jig.py: term and none parsing (`entry_touches`, `touches_none`, `touched_term`, `touch_key`), M2 in `touches_problems`, `PAIR_LINE`, `cmd_peers`, update's backfill line, and `placement_hints`. `placement_hints` was a change the job needed: it shows a term key as `docs/glossary.md § <term>` rather than the internal key.
- plugin/templates/jig/RULES.md: the Decision log's Touches, Peers and M2 text, which must describe the new forms.
- tests/smoke.sh: a new section, `touches_terms`, added to UNITS; no existing case edited.
- marketing/FEATURES.md: not edited here; it is gitignored and the hubnode added the row in the main checkout.

## Test by hand
In a metarepo with `## products` in docs/glossary.md, add a decision with `Touches: docs/glossary.md § products` and another with `Touches: none — repo-wide rule`; both commit. `python3 .jig/jig.py check --peers D-00N` on the first lists other entries on products; on the second it prints "touches no page" and the reason.

## Left
Nothing on this spec. Out of scope as the spec says: `§` on pages other than the glossary, and folder or genre pointers.
