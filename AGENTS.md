# AGENTS.md

## Project
jig: a Claude Code plugin plus a portable repo-side checker (`jig.py`, git hooks) for
prototyping software and firmware with AI agents. Working = `tests/smoke.sh` passes, the plugin validates, and a
fresh repo set up with `/jig:init` runs one full spec → work → review → handoff → gate cycle.
Risk: R0 — one user, nothing shipped. Optimize for simplicity and clarity, not assurance.
`.jig/` is jig running on this repo — the installed release. `plugin/` is the product. Edit `plugin/`; `.jig/` changes only by `/jig:update`.

## Commands
- smoke:  `python3 .jig/jig.py queue -- bash tests/smoke.sh` (the rules, end to end, in throwaway repos; sections run in parallel, ~2 min). `python3 .jig/jig.py queue -- bash tests/smoke.sh <section>…` reruns only those (`--list` names them). Every test or check run goes through `jig queue`, which waits for the machine's one slot (`queue.width: "all"`: smoke uses every core)
- validate: `claude plugin validate ./plugin`
- reload in a session: `/reload-plugins`
- check: `python3 .jig/jig.py queue -- .jig/scripts/check.sh` (the validator and a syntax check of `jig.py`); the full smoke is the complete check
- setup:  `.jig/scripts/setup.sh` (runs itself in new worktrees and after merges; run it after changing dependencies)
- derive: `.jig/scripts/derive.sh` (writes the files built from several sources that separate jobs change; `jig merge` runs it and commits what `derived_files` in `.jig/config.json` lists; branches don't commit them)

## Workflow
- Task bigger than a one-sentence diff → `.jig/specs/<task>.md` first (/jig:spec).
- Every change to the plugin is proposed before it is made. One proposal, approved, then one pass.
- While working, run `check` and the smoke sections you touched (`python3 .jig/jig.py queue -- bash tests/smoke.sh <section>…`), and show the output. That is the evidence. The full suite is the check role's, once per gate or batch.
- A mergeable chunk is a handoff: checks pass → /jig:review → `jig reviewed` → `jig handoff`. `jig next` names each job's next step and who takes it (`jig roles`, `jig flows`).
- A diff that changes only skill text, docs or specs (no `jig.py`, hooks, templates or `tests/`) gets a lighter review: tier 2, effort 3. Anything else gets the review role's settings. This is the owner's setting, not a hubnode's pick; `jig gate` warns that it ran below the spec's review line, and that warning is expected.
- A release, on the owner's word: write `dist/notes-X.Y.Z.md` (install line, then New / Changed / Fixed), bring `README.md` up to the release from those notes with `/davewriter:davewriter` and commit it, then `python3 .jig/jig.py release --feature` (or `--patch`). jig is at 0.y.z, so `--milestone` doesn't apply until the owner calls 1.0.0. After the tag, `.jig/scripts/publish.sh` pushes main and the tag (the marketplace serves `./plugin` from main) and publishes `dist/jig-X.Y.Z.plugin` as the GitHub release, failing unless the release lists it.
- Rulebook `.jig/RULES.md`, enforced by `python3 .jig/jig.py`. Nodes: /jig:hubnode, /jig:subnode. Roles: /jig:spec, /jig:bug, /jig:work, /jig:review, /jig:check, each at its `jig roles` settings; `jig next` names the next step.

## Code
- `jig.py` is stdlib Python, one file, no AI-tool dependency. Enforcement lives there and in git hooks; skills are thin wrappers that call it.
- Nothing Claude-specific in `plugin/templates/jig/`, templates, or `RULES.md`. Standard terms are mapped in `RULES.md`, not adopted.
- Comments explain *why*. A comment restating the code is a naming failure.
- Every feature has a row in `marketing/FEATURES.md`: what, where it came from, why, what it is not. A row with no why is a cut candidate. Add the row before the feature.
- `marketing/DIFFERENCES.md` and `marketing/FEATURES.md` are repo docs, not plugin files. Nothing in `plugin/` references them.
- No remnants of any specific adopting repo in `plugin/` — examples are generic.

## Context
- One task per session. Hand off via files, not conversation.
