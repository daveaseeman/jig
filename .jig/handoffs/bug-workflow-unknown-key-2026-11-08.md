# Handoff: bug-workflow-unknown-key

Commit: 5b532f6e459f0efd780cae41c25eb4d576ca75f4
Date: 2026-11-08
Spec: .jig/specs/bug-workflow-unknown-key.md
Review: tier 2, effort 2
Ran: fresh Opus subagent, effort high: diff main...bug-workflow-unknown-key, spec, AGENTS.md; 0 blocking, 0 should-fix, 2 optional (from_claude_lane comment on dropping workflow; RULES.md key list missing name) — both taken in 5b532f6

## Built
<!-- what this delivers, in a few lines -->
`BOARD_OPTIONAL` (`jig.py`, beside `BOARD_DEFAULTS`): board keys jig reads but never writes,
starting with `workflow`. `jig update`'s unknown-key warning skips them, so a board with a
`workflow` override no longer hears it "is not one jig knows"; a truly unknown key still does.
Update writes only missing `BOARD_DEFAULTS` keys, so it never adds `workflow`. RULES.md's Board
section lists `name` and `workflow` among `config.json`'s keys. `docs-subsystems` and
`flatten-hardware` add `deep_subsystems` and `boards` to the tuple.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- No warning for `workflow`, override unchanged: smoke `workflow` "PASS update: a board's workflow override is not called unknown", "PASS update --apply leaves the workflow override unchanged" (with the fix reverted, the first FAILs)
- `bogus` still warned: "PASS update: a truly unknown board key is still named"
- No `workflow` added: "PASS update --apply adds no workflow key to a board without one"
- RULES.md (Board) lists `workflow`: `RULES.md:27-28`
- `bash tests/smoke.sh` at 5b532f6: exit 0, 656 PASS, 0 FAIL; `claude plugin validate ./plugin`: "✔ Validation passed"; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: no matches (rc 1)

## Review
<!-- findings from the adversarial review, and what you did about each -->
Hubnode's fresh reviewer, tier 2 effort 2, on 35b111c: 0 blocking, 0 should-fix, 2 optional, both taken in 5b532f6.
- Optional: `from_claude_lane` drops keys outside `BOARD_DEFAULTS`, ignoring `BOARD_OPTIONAL`. Behaviour kept (claude-lane boards predate those keys, so the name meant something else there); a comment now says so.
- Optional: RULES.md's config key list omitted `name`. Added.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because the checker's documentation is `plugin/templates/jig/RULES.md` (Board key list updated here) and `plugin/skills/update/SKILL.md`, whose "an unknown board key" warning line still describes the code.

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: the fix, `BOARD_OPTIONAL` and its use in update's check; a comment in `from_claude_lane`
- `plugin/templates/jig/RULES.md`: Board section's config key list (`name`, `workflow`)
- `tests/smoke.sh`: four checks appended in `sec_workflow`

## Test by hand
<!-- what a person should click or watch -->
In a repo whose `.jig/config.json` sets `workflow`, run `python3 .jig/jig.py update`: no "board key `workflow` is not one jig knows" line.

## Left
<!-- what remains on this job -->
Nothing.
