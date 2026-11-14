---
name: retro
description: Turn a repeated fix or discovery into a reusable skill or a line in a board's page, and triage the two ledgers and the roadmap's Up next items. Use at the end of a task, or when you notice "I've done this before."
---

Ask: did anything in this task get solved that will need solving again?

- Hardware quirk (init order, pull-up, timing, voltage) → one line in that board's page, `docs/<board>.md` (`docs/<board>/<board>.md` once it holds files) or a subsystem's in a larger system (the pages `boards` in `.jig/config.json` lists) → Known failure modes.
- Framework/peripheral knowledge (how to make X work on Y) → `.claude/skills/<platform>-<peripheral>/SKILL.md` from `${CLAUDE_PLUGIN_ROOT}/templates/skills/_template/SKILL.md`. Mark `verified: false` until it has produced working code on the board, and list it under Skills in each board page it applies to.
- A board page lists a skill under Skills that jig ships and `.claude/skills/` lacks → install it from `${CLAUDE_PLUGIN_ROOT}/templates/skills/<name>/`, never overwriting.
- Process friction (the check was wrong, the spec template missed something) → edit the process file directly.

Then read `.jig/ledgers/WORKAROUNDS.md` (no file means no rows yet):
- Two rows in the same subsystem → propose a refactor task; the correction they both avoided is its intent.
- "Proof it fires" empty → it's a wish, not a fix. Flag it.
- Reason tagged `[assumed]` → can it be converted now? If the assumption was wrong, the correction goes back on the table.

Then read `.jig/ledgers/DEFERRED.md` (likewise):
- Deferred rows for a scope that has closed → re-rank together; take, or reject with a reason.
- Rejected with `[assumed]` → can it be converted now? A wrong assumption puts the finding back.

Then read `## Up next` in `.jig/roadmap.md`, if the repo keeps one:
- An item the code now does → it was built without its fold-in: put its content in the body of the pages it touches, and propose removing the item (the roadmap changes on trunk, on the owner's word).
- An item that has sat unclaimed for months → a delete candidate. Propose it; delete only on the owner's word, as it was written on the owner's word.
- An item that is really a review finding → it belongs in `.jig/ledgers/DEFERRED.md`, not both.
- A page still carrying `## Undefined` (`jig survey` lists it) → each entry is an Up next item or an `## Open` question to propose, and the section goes. A `## Status` or `## Roadmap` section that says what is built or when is the same; one that describes the product's own thing (a status call, a state machine) stays.

In a pararepo: the same cross-repo confusion twice is a glossary entry, a term in the metarepo's `docs/glossary.md`, proposed to the metarepo with `jig propose`.

Don't file one-offs. Twice is the bar.
