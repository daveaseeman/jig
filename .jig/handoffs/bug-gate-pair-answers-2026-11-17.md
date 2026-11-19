# Handoff: bug-gate-pair-answers

Commit: c9eec5cc32b881a6b11d4dcabdab67995fe1e8e4
Date: 2026-11-17
Spec: .jig/specs/bug-gate-pair-answers.md
Source: Adventure Studio hubnode session / 2026-11-16 / Claude for Dave (staged as feedback-adventure-studio-2026-11-16-gate-pair-answers.md): "a pair line whose shape was changed is reported as \"main moved\""
Source: Adventure Studio hubnode session / 2026-11-16 / Claude for Dave (staged as feedback-adventure-studio-2026-11-16-gate-pair-answers.md): "a pair is made for every entry that shares a page, so most pairs say nothing"
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
<!-- what this delivers, in a few lines -->
Issue 1: any checklist line `- [.] <id> vs …` is a pair line (`PAIR_SHAPED`), so one reshaped (its log label dropped, say) is refused by name at commit and in the gate's fold-in check, never read as missing. The gate splits the pairs a note doesn't answer by cause: left out of the note (found at the note's commit against its merge-base), new on trunk since the base, or, for another repo's log, read as it stands now with no cause claimed. No "moved since the handoff". The fold-in list cut at ten ends `… and N more`. The note's Fold-in comment says how a pair line is answered.
Issue 2 (the owner's G1, 2026-11-17, "one line per page, answered once"): `pair_lines` writes one line per entry, page and peer log, listing every peer there in number order; `pair_keys` covers each id; narrows or conflicts on a line of several ids names at least one of them. One-id lines in today's shape still count; the gate's unmet list prints only the uncovered ids.
RULES.md's fold-in paragraph and the review skill's step 8 say so. FEATURES.md's Decision log row is the hubnode's, updated.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Hook refuses a label-dropped pair line with "keep a pair line's shape": smoke touches "touches hook: a pair line with its log label dropped is refused…" PASS.
- Same note hook-off, the gate's fold-in check names it, no "moved since": "touches gate: a pair line with its label dropped is named in the fold-in check, not blamed on trunk moving" PASS.
- A deleted generated line is named "left out of the note"; the merged job's pair "new on main": cheaper_rounds "a generated pair line deleted is named as left out of the note, and the merged job's as new on trunk" PASS; touches one/two case PASS.
- No-checkbox line commits: "touches hook: narrows naming one of the line's ids commits, beside a no-checkbox line of the job's own" PASS.
- More than ten unanswered lines print ten and `… and N more`: touches PASS.
- Symptom, exports snapshot (de2ae5d on cb04982, archived read-only into scratch repos): trunk's jig.py `pair_problem` names 0 of e7024bb's note's lines, this one 11.
- One line naming D-001 to D-010 for an eleventh entry: touches PASS. agrees commits and passes the gate; `narrows: D-004, …` commits; `narrows: when …` refused naming the line; `___` refused: touches PASS (four cases).
- One-id note answered passes the gate: touches PASS.
- A job merged since adds D-011: the gate names only D-011, as new on main: touches PASS.
- Symptom, pair_lines: rulings-d92 snapshot (6d8ca13 on 3fa017f) 187 → 15; exports 11 → 4.
- The review fix: a pararepo's log gaining an entry after the handoff is listed under "in another repo's log, read as it stands now", not "left out": touches PASS.
- `.jig/scripts/check.sh` → rc=0. `bash tests/smoke.sh touches touches_terms cheaper_rounds metarepo` → rc=0, PASS 185, FAIL 0 (at 0f6c169). `claude plugin validate ./plugin` → ✔ Validation passed (at a7dc094). `grep -rniE 'adventure|rulings-d92' plugin` → nothing.
- The reviewer ran every new case on trunk's jig.py: each fails there and passes here (9 of 96).

## Review
<!-- findings from the adversarial review, and what you did about each -->
Review-work of a7dc094 (tier 2, effort 2): 1 blocking.
- Blocking: for a pair with another repo's log, the gate claimed a false cause ("left out of the note") because `peer_logs` reads that log as it stands now, whatever the base. Fixed in 0f6c169: the cause split covers this repo's log only; other logs get a list that claims no cause. Smoke case added in touches (metarepo TH, pararepo pa).
- Optional: RULES.md's "a checklist line with ` vs ` in it" was broader than `PAIR_SHAPED`. Taken: narrowed to `- [ ] <id> vs …`.
- Optional: the gate runs `pair_lines` twice. Not taken: DEFERRED.md row, rejected.
Review-change of 0f6c169 (tier 2, effort 2): 0 blocking, no should-fix. The reviewer ran eight hand cases on both versions (a7dc094 false "left out" in three, 0f6c169 none).
- Optional: the no-cause heading doesn't fit a pararepo's metarepo log read at the pin, and cmd_gate's comment "Each list names the cause jig found" now covers one that names none. DEFERRED.md row.
- Optional: RULES.md names only `- [ ]`, where `PAIR_SHAPED` covers `- [x]` too. DEFERRED.md row.
- Optional: a peer log the gate can't reach is skipped silently (pre-existing). DEFERRED.md row.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap (a new page starts from .jig/docs-page.md), or no page needed because RULES.md (plugin/templates/jig/RULES.md) is its page, edited here: the fold-in paragraph now says one line per page answered once, the reshaped-line refusal, and the gate's causes

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- plugin/templates/jig/jig.py: the pair code, cmd_gate's unmet-pairs message and fold-in cut, NOTE's Fold-in comment (bug-process-in-pages also edits that comment: merge as text).
- plugin/templates/jig/RULES.md: the fold-in paragraph's pair-line text.
- plugin/skills/review/SKILL.md: step 8's sentence on the pairs the fold-in asks.
- tests/smoke.sh: new cases at the end of sec_touches and after its TH survey case; changed expectations in touches (one/two gate), touches_terms (D-?ny line) and cheaper_rounds (p2 deletes its pair line).

## Test by hand
<!-- what a person should click or watch -->
In a repo with several entries on one page, add an entry on a branch and `jig handoff`: one pair line names every peer. Drop the `.jig/decisions.md § ` label from it and commit: the hook names the line.

## Left
<!-- what remains on this job -->
Nothing on this spec. The three optional findings from review-change are rows in DEFERRED.md.
