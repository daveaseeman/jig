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
- check:  `.jig/scripts/check.sh` (runs on every stop; must pass before you're done)
- setup:  `.jig/scripts/setup.sh` (runs itself in new worktrees and after merges; run it after changing dependencies)
- derive: `.jig/scripts/derive.sh` (writes the files derived from the whole tree; `jig merge` runs it and commits what `derived_files` in `.jig/config.json` lists; branches don't commit them)

## Workflow
- Task bigger than a one-sentence diff → write `.jig/specs/<task>.md` first (see /jig:spec). Plan before editing.
- Run `check` yourself and show the output. Don't claim done on a green build alone.
- Commit often; the git hook runs the rules. Never `--no-verify`.
- A mergeable chunk is a handoff: checks pass → adversarial review (/jig:review) → `jig reviewed` → `jig handoff --spec .jig/specs/<task>.md`. Review happens once per handoff, not per commit. A chunk that doesn't finish its spec hands off with `--partial`.
- Same fix twice → write a skill (see /jig:retro).
- A choice that outlives its spec, or a change a release's reader can act on, gets an entry or a line under `## Unreleased` in `.jig/decisions.md`, as `.jig/RULES.md` (Decision log) says.
- Rulebook `.jig/RULES.md`, enforced by `python3 .jig/jig.py`. Roles: /jig:hubnode, /jig:subnode.

## Code
- Comments explain *why*. A comment restating the code is a naming failure — rename instead — and it rots the moment the code moves on.
  Exception, where a name genuinely can't carry it: register writes, bit manipulation, protocol framing, non-obvious algorithms. State plainly what those do.
- Bug reported → /jig:bug before editing (in a repo with a hubnode, ask the hubnode to run it). Prefer the fix that makes the odd path look like the healthy ones over one that patches the symptom.
- A workaround is allowed when it's the right fix. It gets a `WORKAROUND:` comment and a row in `.jig/ledgers/WORKAROUNDS.md`. Never silently.
- A review finding you defer or reject gets a row in `.jig/ledgers/DEFERRED.md` at handoff.
- No new dependencies without saying so in the spec.
- Documentation is shaped and housed as `.jig/RULES.md` (Documentation) says; a change isn't done until its page is current. A page describes the code; where they disagree, the code on trunk is reality.
- A new `.md` outside the homes `.jig/RULES.md` (Documentation) lists means its home wasn't found. `jig survey` lists the strays.

## Firmware (delete if not applicable)
- Each board this repo builds for gets its page, `docs/<board>.md` (a subsystem's page in a larger system; in a folder of its own, `docs/<board>/<board>.md`, once it holds files), listed in `boards` in `.jig/config.json`, before code for it passes the gate (/jig:hardware). Where one exists, read it before touching a pin, bus, or peripheral, and load the skills it lists.
- Logic gets unit tests. Driver code gets run on hardware. Don't mock a bus to make a driver "testable."
- Graphics: emulate first. Everything else: flash as soon as confident it won't brick.

## Context
- One task per session. Hand off via files, not conversation.
- Research in subagents; keep the main context for the change itself.
- When compacting, preserve: modified files, the test command, open decisions.
