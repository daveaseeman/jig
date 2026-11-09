# AGENTS.md

## Project
jig: a Claude Code plugin plus a portable repo-side checker (`jig.py`, git hooks) for
prototyping software and firmware with AI agents. Working = `tests/smoke.sh` passes, the plugin validates, and a
fresh repo set up with `/jig:init` runs one full brief → review → handoff → gate cycle.
Risk: R0 — one user, nothing shipped. Optimize for simplicity and clarity, not assurance.
`.jig/` is jig running on this repo — the installed release. `plugin/` is the product. Edit `plugin/`; `.jig/` changes only by `/jig:update`.

## Commands
- smoke:  `bash tests/smoke.sh` (the rules, end to end, in throwaway repos; sections run in parallel, ~2 min). `bash tests/smoke.sh <section>…` reruns only those (`--list` names them)
- validate: `claude plugin validate ./plugin`
- reload in a session: `/reload-plugins`
- check: `.jig/scripts/check.sh` (the validator and a syntax check of `jig.py`; the full smoke runs at the gate)

## Workflow
- Task bigger than a one-sentence diff → `.jig/specs/<task>.md` first (/jig:brief).
- Every change to the plugin is proposed before it is made. One proposal, approved, then one pass.
- Run the smoke test and the validator yourself and show the output. That is the evidence.
- A mergeable chunk is a handoff: checks pass → /jig:review → `jig reviewed` → `jig handoff`.
- A diff that changes only skill text, docs or specs (no `jig.py`, hooks, templates or `tests/`) gets a lighter review: tier 2, effort 3. Anything else gets the workflow's `review` step. This is the owner's setting, not a hubnode's pick; `jig gate` warns that it ran below the spec's review line, and that warning is expected.
- A release, on the owner's word: write `dist/notes-X.Y.Z.md` (install line, then New / Changed / Fixed), then `python3 .jig/jig.py release --minor` (or `--patch`, `--major`). After the tag, `.jig/scripts/publish.sh` pushes main and the tag (the marketplace serves `./plugin` from main) and publishes `dist/jig-X.Y.Z.plugin` as the GitHub release, failing unless the release lists it.

## Code
- `jig.py` is stdlib Python, one file, no AI-tool dependency. Enforcement lives there and in git hooks; skills are thin wrappers that call it.
- Nothing Claude-specific in `plugin/templates/jig/`, templates, or `RULES.md`. Standard terms are mapped in `RULES.md`, not adopted.
- Comments explain *why*. A comment restating the code is a naming failure.
- Every feature has a row in `marketing/FEATURES.md`: what, where it came from, why, what it is not. A row with no why is a cut candidate. Add the row before the feature.
- `marketing/DIFFERENCES.md` and `marketing/FEATURES.md` are repo docs, not plugin files. Nothing in `plugin/` references them.
- No remnants of any specific adopting repo in `plugin/` — examples are generic.

## Context
- One task per session. Hand off via files, not conversation.
