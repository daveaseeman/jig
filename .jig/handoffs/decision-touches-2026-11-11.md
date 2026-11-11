# Handoff: decision-touches

Commit: 5687279fd91390fe809bfb36f268287f54ac0d8f
Date: 2026-11-11
Spec: .jig/specs/decision-touches.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on cd0ad70: B1 (released entries can't take Touches) and S1-S5; S1-S5, O1, O3 fixed in 5c07e4a, B1 in sync merge 5687279; hubnode re-ran the reviewer's repros (first D-001 without Touches refused, metarepo->pararepo pointer refused, own-name prefix accepted, released backfill passes) and a supersede+remove with Touches after the sync

## Built
<!-- what this delivers, in a few lines -->
- Every new or changed decision entry carries a `Touches:` line of docs-page pointers
  (`<repo>/<path>`, `<repo>:<path>`, or this repo's own), checked by M2. Entries already on trunk,
  and those update's `--merge-log` converts, are exempt until they change. A released entry may
  gain or change its Touches line and nothing else.
- Peers: live entries touching one page or a page above, from this log, the metarepo's at the
  pin, and in a metarepo each registered pararepo's trunk. `jig handoff` writes one pair line per
  peer (agrees / narrows: / conflicts:), plus a line for each peer log it couldn't read; the gate
  refuses one unanswered or reshaped, and recomputes the pairs on its scratch merge.
- `jig decision <id> --peers`, survey's placement hint in a metarepo, update's backfill list,
  RULES.md (Decision log, Released sections, Fold-in, M2 row), and the review skill's pair questions.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- M2 refuses a new entry with no Touches, accepts either page form, accepts an untouched old
  entry: `bash tests/smoke.sh touches` → PASS "touches M2: a new entry with no Touches line is
  refused…", "…folder form while it is flat is accepted…", "…an untouched old entry with none passes…".
- The reported symptom: PASS "touches fold-in: a pararepo entry touching the metarepo's page gets a
  pair line with the metarepo's entry", "touches gate: the pair line unanswered is refused",
  "touches gate: answered narrows, with parentheses in the answer, it passes".
- Page above and unrelated page: PASS "touches fold-in: an entry on docs/a/b.md gets a pair line
  with the one on docs/a.md, the page above", "…no pair line for the entry on an unrelated page…".
- Survey in a metarepo: PASS "touches survey: a metarepo names the page two pararepos rule on…".
- `--peers`: PASS "touches: jig decision --peers lists the peers with their first body sentence".
- Update: PASS "touches update: a live entry with no Touches is listed under Repo files to review".
- RULES.md (Decision log, Fold-in, Released sections, M2 row) and plugin/skills/review/SKILL.md (question 8) say it.
- At 5687279: `bash tests/smoke.sh` → 952 PASS, 0 FAIL; `claude plugin validate ./plugin` →
  Validation passed; `.jig/scripts/check.sh` → rc 0; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing.

## Review
<!-- findings from the adversarial review, and what you did about each -->
- B1 (blocking), released entries couldn't take a Touches backfill: fixed in the sync merge
  5687279 (`touches_dropped` in frozen_problems and outside_open_deleted; smoke "touches release: …").
- S1 first numbered entry exempt: fixed in 5c07e4a (only update's register merge is exempt).
- S2 pointer forms: fixed in 5c07e4a (`<repo>:`, own name, `docs/…` always own, metarepo → pararepo refused).
- S3 any .md taken as a page: fixed in 5c07e4a (docs/ or docmap; fixtures use docs/shared.md).
- S4 parallel jobs never paired: fixed in 5c07e4a (gate_pairs on the scratch merge).
- S5 missing or stale cache: fixed in 5c07e4a (unread line to answer, pin compared, shape check).
- O1 pairs reimplemented changed_decisions, read peers from the branch: fixed in 5c07e4a.
- O3 greedy PAIR_LINE, reshaped lines: fixed in 5c07e4a.
- O2 (prefix match, forms outside docs/, `§` suffix), O4 (rename doesn't recheck), O5 (two
  pararepos not paired): deferred, each with a row in .jig/ledgers/DEFERRED.md.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Decision log, Released sections, Fold-in, the M2 row). This repo has no docs tree for the checker.

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- plugin/templates/jig/jig.py: the Touches check, peers, pair lines, the gate's recheck, --peers,
  survey and update lines, and frozen_problems for B1.
- plugin/templates/jig/RULES.md: Decision log, Released sections, Fold-in, the M2 row.
- tests/smoke.sh: the `touches` section, and Touches lines on every existing test entry (now required).
- .jig/ledgers/DEFERRED.md (common): rows for O2, O4, O5.

## Test by hand
<!-- what a person should click or watch -->
In a pararepo, add a decision touching a metarepo genre page that a metarepo entry also touches;
`jig handoff` should list the pair, and `jig decision <id> --peers` should show both rule sentences.

## Left
<!-- what remains on this job -->
Nothing in the spec. The one-time audit prompt's mapping (spec, Backfill) is per ecosystem, outside the plugin.
