---
name: retro
description: Turn a repeated fix or discovery into a reusable skill or a docs/HARDWARE.md line, and triage the two ledgers. Use at the end of a task, or when you notice "I've done this before."
---

Ask: did anything in this task get solved that will need solving again?

- Hardware quirk (init order, pull-up, timing, voltage) → one line in `docs/HARDWARE.md` → Known failure modes.
- Framework/peripheral knowledge (how to make X work on Y) → `.claude/skills/<platform>-<peripheral>/SKILL.md` using `_skill-template`. Mark `verified: false` until it has produced working code on the board.
- Process friction (the check was wrong, the spec template missed something) → edit the process file directly.

Then read `jig/ledgers/WORKAROUNDS.md`:
- Two rows in the same subsystem → propose a refactor task; the correction they both avoided is its intent.
- "Proof it fires" empty → it's a wish, not a fix. Flag it.
- Reason tagged `[assumed]` → can it be converted now? If the assumption was wrong, the correction goes back on the table.

Then read `jig/ledgers/DEFERRED.md`:
- Deferred rows for a scope that has closed → re-rank together; take, or reject with a reason.
- Rejected with `[assumed]` → can it be converted now? A wrong assumption puts the finding back.

Don't file one-offs. Twice is the bar.
