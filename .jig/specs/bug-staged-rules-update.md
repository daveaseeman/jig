# bug-staged-rules-update

Source: Adventure-Studio hubnode session / 2026-11-11 / Dave, with Claude (staged as feedback-adventure-studio-2026-11-11-agents-md-provenance.md): "`staging resolve` wants a `Source:` line inside AGENTS.md"

## Intent
A staged update to a root rules file (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) resolves the way a
roadmap change does: its provenance is a trunk commit that changed the file and carries the
`Source: … (staged as <file>)` line. Nothing is added to the file. `/jig:init` and `jig survey`
count `AGENTS.md`'s lines the same way.

## Why
- Why was the resolve refused? For a `change: update` doc, `resolve` checks that the destination's
  text holds the mark, and the hubnode had put the mark in the commit message.
- Why is the mark in the file wrong here? `AGENTS.md` is loaded on every turn. A provenance line
  there costs every load and changes no behavior, and the template says to cut lines like that.
- Why is there no other way through? Only the roadmap resolves from a commit message ("the
  roadmap itself carries no provenance"). A root rules file is the same case.

## Givens
- `[seen]` `cmd_staging` resolve (jig.py ~5648-5710): `landed(dest)` reads the destination's
  text. The `kind == "roadmap"` branch instead looks for a trunk commit that changed
  `.jig/roadmap.md` with the mark.
- `[seen]` The refusal: "needs judgment: edit AGENTS.md with this file's content, keeping
  `Source: …` in it as provenance". A session following it literally adds the line to AGENTS.md.
- `[seen]` `jig staging drop` records nothing, so the workaround left no tie between the commit
  and the staged file.
- `[seen]` Survey counts rule lines (blank lines, headings and table rows don't count; jig.py
  ~2558). `/jig:init` says "Keep AGENTS.md under 40 lines" and the session counted raw lines.

## Design
- **Resolve.** For an update whose destination is in `RULES_NAMES` (`AGENTS.md`, `CLAUDE.md`,
  `GEMINI.md`), `landed` is true when a trunk commit that changed the destination carries the
  mark, the same test the roadmap branch uses. The refusal names that route: "commit the edit on
  trunk with `<mark>` in the message". A doc under `docs/`, and every other destination, behave
  as today.
- RULES.md § Staging: one sentence beside the roadmap's, naming the root rules files.
- **One count.** `/jig:init` says "under 40 rule lines (blank lines, headings and table rows
  don't count), as `jig survey` counts them". The limit stays 40 (see Decisions).

## Done when
- [ ] Smoke: a staged `kind: doc`, `change: update`, `destination: AGENTS.md`. Once a trunk commit
  that changed `AGENTS.md` carries its `Source: … (staged as <file>)` line, `resolve` succeeds
  with no such line in `AGENTS.md` (the reported refusal gone).
- [ ] Smoke: with no such commit it is refused, and the message names the commit route, not
  "keeping … in it".
- [ ] Smoke: an `update` to a page under `docs/` still needs the mark in the page.
- [ ] RULES.md § Staging states it, and `plugin/skills/init/SKILL.md` counts as survey does.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Extending commit-message provenance to every `update` doc. A page is where a reader looks for
  where a claim came from.
- Changing the 40-line number: the owner kept it.

## Touches
- `plugin/templates/jig/jig.py` (staging resolve's `landed` for root rules files)
- `plugin/templates/jig/RULES.md` (§ Staging)
- `plugin/skills/init/SKILL.md`
- `tests/smoke.sh`

## Alternatives considered
- Keep the mark in AGENTS.md. Rejected: every line there is paid for on every load. Reason is
  [seen: the template's own comment; survey's always-loaded rule].
- Drop the staged file, as the hubnode did. Rejected as the fix: drop records nothing, and the
  refusal still tells the next session to add the line. Reason is [seen: the report].
- Commit-message provenance for every update doc. Rejected: pages are looked up, and the mark in
  them says where a claim came from. Reason is [assumed].

## Decisions
- The limit stays 40 rule lines, counted one way (owner, Nov 11: "Let's keep 40"). It stays a
  survey finding, not a refusal.
- Runs after `project-product-boundary`, which owns `jig.py`, RULES.md and `smoke.sh`.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
