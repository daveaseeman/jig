# bug-root-file-contract-path

Source: Maige-Lite hubnode session, Dave + Claude, 2026-11-11 — investigated in Maige-Lite's .jig/specs/bug-agents-contract-path.md (staged as feedback-Maige-Lite-2026-11-11-agents-md-contract-path.md): "`jig sync` asks for AGENTS.md as a contract path"

## Intent
`jig sync` names a file as cited but not a contract path only when a decision points at this
repo's file. A root file that every repo has (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `README.md`,
`CHANGELOG.md`), named bare in a decision about every repo, points at no repo. The line asks a
question, never a to-do.

## Why
- Why does sync print "AGENTS.md is cited by E-001 and is not a contract path"? `uncovered_paths`
  counts any bare mention of a tracked path as this repo's, and E-001 says "the sync rule sits at
  the top of every product repo's `AGENTS.md`".
- Why is that wrong? E-001 is about every pararepo, not a pointer to this one. RULES.md gives a
  pointer a form, `<repo>/<path>` or `<repo>:<path>`, and a bare root file name has no repo in it.
- Why did a session act on it twice? The line reads as an instruction ("add it to
  contract_paths …"), with its condition last. The owner wants `AGENTS.md` out of contract paths
  (Dave, Nov 11: "agents stays out of contract path").

## Givens
- `[seen]` `uncovered_paths` (jig.py ~5023) matches `named_path(path, bare=True)`, and keeps a
  decision when `not m.group("name")`, so a bare `AGENTS.md` counts as this repo's.
- `[seen]` RULES.md (~762): "`jig sync` also names each file here that a decision at the pin
  cites and `contract_paths` doesn't cover; adding it is the hubnode's call."
- `[seen]` The report's text of E-001 at maige-ecosystem v1.1.0, quoted in the staged file.
- `[seen]` P1 already refuses an `AGENTS.md` header that differs from what `jig init --para`
  generates, which is the part of the file E-001 describes.
- `[seen]` The hubnode skill (step 5, line 26) relays "each file it says is cited but not a
  contract path" as a line of the sync report.
- `[assumed]` Older decisions name a pararepo's files under folders bare (`docs/ui.md`), so the
  bare match must stay for those.

## One layer up
The sibling report in the same function's run, "cites <path> bare: write it as `<meta>/<path>`",
asks which repo a bare path means before it reports. `uncovered_paths` never asks. A root file
every repo has is the case where a bare path can't mean this repo alone.

## Design
- In `uncovered_paths`, a root file in `ROOT_DOCS` counts as cited only after this repo's name
  (`<name>/AGENTS.md` or `<name>:AGENTS.md`). A path under a folder keeps the bare match.
- The line becomes a question:
  `<path> is named by <ids>, and <path> is not a contract path. If the decision describes
  something this repo can change there, add the path to "contract_paths" in .jig/para.json; if
  not, nothing is needed.`
- RULES.md, the sync buffer: say which cited paths are named, root files only by name, and that
  the line asks the owner rather than prescribing.
- The hubnode skill, step 5: report each such line as a question for the owner with what the
  decision says, never as a fix to apply.

## Done when
- [ ] Smoke: a scratch pararepo whose pinned metarepo decision reads "The sync rule sits at the top
  of every product repo's `AGENTS.md`". `jig sync` on trunk prints no "is not a contract path"
  line for `AGENTS.md` (the reported symptom gone).
- [ ] Smoke: the same repo with a decision naming `<this repo's name>/AGENTS.md` still prints the
  line for it, and a decision naming bare `docs/ui.md` (tracked, outside `contract_paths`) still
  prints the line for `docs/ui.md`.
- [ ] The printed line asks rather than instructs, and doesn't open its remedy with "add".
- [ ] RULES.md and `plugin/skills/hubnode/SKILL.md` say the same as the code.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- A config key recording a declined path (the report's option c). Nothing else in this repo's
  reports has needed it once root files stop matching bare. Revisit if a real pointer is declined.
- Rewording metarepo decisions that name files in prose.

## Touches
- `plugin/templates/jig/jig.py` (`uncovered_paths`)
- `plugin/templates/jig/RULES.md` (The sync buffer)
- `plugin/skills/hubnode/SKILL.md` (step 5)
- `tests/smoke.sh`

## Alternatives considered
- Add `AGENTS.md` to each pararepo's `contract_paths`, as the line says. Rejected: P2 would then
  ask for a metarepo answer on every edit to a pararepo's own rules, for a claim P1 already holds.
  Reason is [seen: the report's Givens, RULES.md P1 and P2].
- Skip only the paths P1 holds (the report's option a). Rejected: it covers `AGENTS.md` and not
  `README.md` or `CHANGELOG.md`, which a decision about every repo can name the same way. Reason
  is [assumed].
- A `not_contract` key with reasons (the report's option c). Rejected for now: a new config key for
  a case the name rule removes. Reason is [assumed].
- Drop the report. Rejected: for a real pointer into a file outside `contract_paths`, it is the
  only warning that a decision describes something that can change unasked. Reason is [seen: the
  function's docstring].

## Decisions
- A bare root file name is about every repo. Only `<repo>/<file>` or `<repo>:<file>` names this
  one.
- Runs after `project-product-boundary`, which owns `jig.py`, RULES.md, `smoke.sh` and the
  hubnode skill.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
