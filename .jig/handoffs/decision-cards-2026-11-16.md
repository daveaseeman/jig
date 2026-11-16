# Handoff: decision-cards

Commit: de177e6db77498acd0754464a6880164fab9ad05
Date: 2026-11-16
Spec: .jig/specs/decision-cards.md
Review: tier 2, effort 3
Ran: claude-opus-5-5 at medium
Review-change: tier 2, effort 3
Review-change ran: claude-opus-5-5 at medium

## Built
- New `plugin/skills/decision-cards/SKILL.md`: the rules for putting decisions to the owner (a block per decision with a recommended option, Elaborate and Hold on each block's right with their fill texts, picks that change only the card, one "Fill reply" joined with "; and", fill-never-send, checking the current state before acting on a reply). It also has the text form for hosts that can't draw a card, with the reply "1b; and 2 hold", and one complete working card (theme variables only, `sendPrompt`, no external scripts).
- `plugin/skills/hubnode/SKILL.md`: pointers to `/jig:decision-cards`, one general line and one each at Reconfiguring, Rulings, Merging and Release. None of the card's rules are restated there.

## Done-when evidence
- Skill exists, and its description fires only for decisions put to the owner: `plugin/skills/decision-cards/SKILL.md` (frontmatter). It states every rule in the spec's "The card" and holds one working card. `node --check` on the card's script: ok. In jsdom, two Fill clicks made 1 `sendPrompt` call; Hold replaced the block's pick; clearing a pick enabled Fill again; the replies were joined with "; and".
- The hubnode points to it and restates nothing: `grep -n "; and" plugin/skills/hubnode/SKILL.md` printed nothing.
- Rig spec item: done on trunk before the job opened (ticked in the spec).
- Nothing tool-specific in the templates: `grep -rn "decision-cards" plugin/templates` printed nothing. A `card` grep on RULES.md matches only "discards".
- Text fallback with the example reply: the "Where the host can't draw a card" section of the skill, with "Reply like: 1a; and 2 hold" and the "1b; and 2 hold" reading.
- `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: exit 0. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` printed nothing. No smoke section: skill text only.

## Review
- review-work on 4cc2aa7: 0 blocking. Should-fix: Fill doubled the reply on a second click. Fixed in 58eb92b (fills once and reads "Filled" until a pick changes). Optional: 2b "hold the release" read like the standing Hold. Fixed in 58eb92b. Optional: `/jig:release` names no pointer. Deferred (DEFERRED.md).
- review-change on 58eb92b: 0 blocking. Optional: the 2b label had a semicolon, the separator the example teaches. Fixed in 2af99e0. Optional: a refill appends to the old reply. Fixed in 2af99e0 ("Clear your reply box before filling again" in the rule and the hint).
- review-change on 2af99e0: 0 blocking. Two optional wording points (the rule's sentence is addressed to the owner; the spec doesn't mention the hint's sentence). Both deferred, on the hubnode's word (DEFERRED.md, de177e6).

## Fold-in
- [x] no code changed — nothing to fold in: skill text only. No jig.py, hooks, templates or tests changed, and no documentation page describes these skills' text.

## Shared files changed
- `plugin/skills/hubnode/SKILL.md` (shares): pointers only, which the spec requires where the hubnode asks the owner. The description, which rig also edits, is untouched.
- `.jig/ledgers/DEFERRED.md` (common): four rows for review findings not taken, appended at the end.

## Test by hand
- In the Claude app, have a hubnode put two decisions to the owner with `/jig:decision-cards`. Check that the card draws in both light and dark themes, that Elaborate and Hold sit on each block's right, and that picks update the preview line. Check that "Fill reply" writes the reply into the box once, joined with "; and", without sending, and then reads "Filled".
- In a terminal session, check that the same decisions come out as numbered text and that "1b; and 2 hold" is read back correctly.

## Left
- Nothing on this job. The deferred wording rows are in DEFERRED.md.
