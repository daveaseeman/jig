# AGENTS.md

<!-- ~40 rule lines, once the sections this repo doesn't need are deleted. For every line ask:
     would removing it cause a mistake? If not, cut it. A long file gets ignored wholesale. -->

## Project
TODO: one sentence. What this is and what "working" looks like.
Risk: R0 — personal prototype, single user, nothing shipped. Optimize for speed and clarity, not assurance.

## Commands
- build:  `TODO`
- test:   `TODO`
- lint:   `TODO`
- run:    `TODO`
- check:  `jig/scripts/check.sh` (runs on every stop; must pass before you're done)

## Workflow
- Task bigger than a one-sentence diff → write `jig/specs/<task>.md` first (see /jig:brief). Plan before editing.
- Run `check` yourself and show the output. Don't claim done on a green build alone.
- Commit often; the git hook runs the rules. Never `--no-verify`.
- A mergeable chunk is a handoff: checks pass → adversarial review (/jig:review) → `jig reviewed` → `jig handoff`. Review happens once per handoff, not per commit.
- Same fix twice → write a skill (see /jig:retro).

## Lanes (parallel sessions)
- Rulebook `jig/RULES.md`, enforced by `python3 jig/jig.py`. Roles: /jig:hubnode, /jig:subnode.
- Only the hubnode touches trunk, the board, and merges; a subnode stays in its worktree and its listed files.
- Keep merges mechanical: append rather than edit shared prose; new routes, tests, and fixtures each in a file of your own.
- Scarce numbers (migrations, sections) come from the board, never from what looks free.

## Code
- Comments explain *why*. A comment restating the code is a naming failure — rename instead — and it rots the moment the code moves on.
  Exception, where a name genuinely can't carry it: register writes, bit manipulation, protocol framing, non-obvious algorithms. State plainly what those do.
- Bug reported → /jig:bug before editing. Prefer the fix that makes the odd path look like the healthy ones over one that patches the symptom.
- A workaround is allowed when it's the right fix. It gets a `WORKAROUND:` comment and a row in `jig/ledgers/WORKAROUNDS.md`. Never silently.
- A review finding you defer or reject gets a row in `jig/ledgers/DEFERRED.md` at handoff.
- No new dependencies without saying so in the spec.
- Documentation is one page per system under `docs/systems/`, shaped as `jig/RULES.md` (Documentation) says; a change isn't done until its page is current. Rules written in a documentation page bind as if they stood in this file.
- One job, one home per document: AGENTS.md rules · the docs tree what the code is now · jig/specs/ a task in flight · jig/ledgers/WORKAROUNDS.md patches in the code · jig/ledgers/DEFERRED.md findings not in it · .claude/skills/ know-how · README.md outsiders · git history. A new `.md` elsewhere means its home wasn't found. `jig survey` lists the strays.

## Firmware (delete if not applicable)
- Each board this repo builds for gets a page in `docs/hardware/<board>.md` (/jig:hardware) before code for it passes the gate. Where one exists, read it before touching a pin, bus, or peripheral, and load the skills it lists.
- Logic gets unit tests. Driver code gets run on hardware. Don't mock a bus to make a driver "testable."
- Graphics: emulate first. Everything else: flash as soon as confident it won't brick.

## Context
- One task per session. Hand off via files, not conversation.
- Research in subagents; keep the main context for the change itself.
- When compacting, preserve: modified files, the test command, open decisions.
