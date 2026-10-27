# AGENTS.md

## Project
jig: a Claude Code plugin plus a portable repo-side checker (`.jig/jig.py`, git hooks) for
prototyping software and firmware with AI agents. Working = `tests/smoke.sh` passes, the plugin validates, and a
fresh repo set up with `/jig:init` runs one full brief → review → handoff → gate cycle.
Risk: R0 — one user, nothing shipped. Optimize for simplicity and clarity, not assurance.

## Commands
- smoke:  `bash tests/smoke.sh` (the rules, end to end, in a throwaway repo)
- validate: `claude plugin validate ./plugin`
- reload in a session: `/reload-plugins`

## Workflow
- Task bigger than a one-sentence diff → `specs/<task>.md` first (/jig:brief).
- Every change to the plugin is proposed before it is made. One proposal, approved, then one pass.
- Run the smoke test and the validator yourself and show the output. That is the evidence.
- A mergeable chunk is a handoff: checks pass → /jig:review → `jig reviewed` → `jig handoff`.

## Code
- `jig.py` is stdlib Python, one file, no AI-tool dependency. Enforcement lives there and in git hooks; skills are thin wrappers that call it.
- Nothing Claude-specific in `.jig/`, templates, or `RULES.md`. Standard terms are mapped in `RULES.md`, not adopted.
- Comments explain *why*. A comment restating the code is a naming failure.
- Every feature has a row in `marketing/FEATURES.md`: what, where it came from, why, what it is not. A row with no why is a cut candidate. Add the row before the feature.
- `marketing/DIFFERENCES.md` and `marketing/FEATURES.md` are repo docs, not plugin files. Nothing in `plugin/` references them.
- No remnants of any specific adopting repo in `plugin/` — examples are generic.

## Context
- One task per session. Hand off via files, not conversation.
- This repo does not run jig on itself yet. When it does, `/jig:init` sets that up; don't hand-place its files.
