# bug-project-sweep-noise

Source: Maige-Lite hubnode session, 2026-11-13 (staged as feedback-Maige-Lite-2026-11-13-survey-status-heading.md): `jig survey` and `jig update` both print `docs/hal.md: ## Status is the project's: what is built → the body, in the present tense; what isn't → .jig/roadmap.md`, for a section that documents the `hal_status` call.
Source: maige-ecosystem hubnode session, 2026-11-13 (staged as feedback-maige-ecosystem-2026-11-13-scope-sweep-over-flags.md): `jig update` and `jig survey` list, on every run, accepted entries as "reads as project scope ("launch"): strike, split or keep", and README lines as `"Phase 5" names the plan`.

Owner's direction (maige-ecosystem report): "separating product from scope is having grave
consequences by over-flagging. pull back on the searching docs to find issues and focus on
tooling that splits them as they're created."

## 1. Why
- Why flagged? Survey and update judge all existing product text by words: a heading's name
  (`project_sections`, `jig.py:1987`), "phase N" prose and bare names (`project_prose`, `:1993`),
  and `SCOPE_WORDS` over every decision entry and register row (`scope_candidates`, `:9672`).
- Why wrong? The words have product meanings: a status API, a state machine's current state, a
  three-phase motor, an app launcher, a demo mode, the launch configuration. The code's comment
  at `:9621` accepts that and hands every hit to the owner.
- Why grave? None of these findings has an id, so no recorded answer silences one: each prints
  on every run of either command, for the owner and every session, forever.

## 2. Givens
Reproduced at de3cc14 in a throwaway repo (`J init`, `.jig/jig.py` copied so the hook runs).
The reports' `jig_version` (a8a32d1dbb7e) is not a commit in this repo; the code is unchanged
in the lines above since v0.11.0, so the bug is current.
- [seen] `## Status` over "`hal_status` returns `EVT_*` bits" is listed by survey and update;
  `## Status screens` below it is not (exact heading match).
- [seen] `In Phase 5 the wallet is a TEE.` on a page: listed by both, `"Phase 5" names the plan`.
- [seen] An accepted entry "The launch base is a TEE with 32 GB." is listed by update as
  `reads as project scope ("launch")`. Survey does not list it: survey runs only the prose and
  path patterns over the log, not `SCOPE_WORDS`. The report's "survey lists E-011…" is
  [assumed] (or survey listed something else in those entries).
- [seen] Generality: an entry "commutates three phases from the hall sensors" (`"phases"`), one
  "The launcher shows four apps; a demo mode loops them" (`"launch"`, prefix match), and
  `## Current state` over "`fsm_state()` returns it" are all listed. Seven findings in a
  four-file repo whose only project text is one planted spec path.
- [seen] The findings carry no id: `project_review` returns `(file, message)` pairs
  (`:9699`), and survey's `project_in_product` is never passed through `tagged` (`:3515`).
  The Maige-Lite report's "a recorded exception" is not available either.
- [seen] The hook refuses at creation an added page line naming `.jig/specs/`:
  `jig: docs/q.md line 7 names .jig/specs/, the project's…`, rc=1. It accepts an added
  `## Status` section saying "Done: x, pending: y. Phase 6 next." (rc=0): today nothing but
  `/jig:review` step 9 catches project prose at creation.
- [assumed] maige-ecosystem's `README.md` is a metarepo entry file, which is how a README line
  reaches `product_pages`. Not checked: no Maige checkout is touched.

## 3. One layer up
- **The two enforcement points.** The hook judges added lines by patterns that are never
  product text (a jig project path, a scope id in code quotes): precise, once, at creation.
  The sweep judges all old text by patterns that often are product text: imprecise, every run,
  no way to answer. Same rule, two judges; only the second over-flags.
- **The sweep's listings split the same way.** Precise ones never fire on product text:
  `## Undefined` (jig's own retired heading, which `--sweep` moves), a `.jig/specs/`,
  `.jig/handoffs/` or `.jig/roadmap.md` path, a backticked scope id, a plan file by name
  (`TODO.md`). Word ones do: `## Status`, `## Current state`, `## Roadmap`, "phase N",
  "spec step N", bare `ROADMAP.md`, a bare scope id, `SCOPE_WORDS`.
- **Sibling, not in scope.** Survey's `root_docs_named` also lists bare words over existing
  text (`ROOT_DOC_WORD`, "README" in prose, glossary-in-docs, unreleased). Same shape; no report
  yet. Named in Out of scope.

## 4. Workaround or correction
Correction. Survey and update keep only the precise listings; the word patterns leave the
after-the-fact search and move to the commit, where they judge only added lines, once, and
never refuse. Exactly:

| Listing (survey / update) | Fate | Why |
|---|---|---|
| `## Undefined` heading; its entries as Up next items; "holds text besides its entries" | stays | jig's own retired heading, no product meaning; `--sweep` acts on it |
| `.jig/specs/`, `.jig/handoffs/`, `.jig/roadmap.md` on a page, entry file or in the log | stays | the hook's own set: never product text, so no false positive; lists old text the hook predates |
| a scope id in code quotes | stays | same: the hook's set |
| plan and register files by name (`TODO.md`, `FEATURES.md`, …) | stays | one per file, by name, a migration path; not reported as noise |
| `## Status`, `## Current state`, `## Roadmap` headings | goes | the heading's word is often the product's (`hal_status`, an FSM's state) |
| "phase N", "spec step N" prose (`PROJECT_PROSE`) | goes | "Phase 5" can be product text and is unanswerable; caught at creation instead |
| bare `ROADMAP.md`, bare scope id | goes | RULES.md already says these may be product text |
| `SCOPE_WORDS` over decision entries, register rows and register notes (`scope_candidates`) | goes, and `SCOPE_WORDS` with it | launch, phase, demo, milestone are product words in firmware; the owner sorts each by hand, every run |

At creation: the commit hook keeps its refusals of the precise patterns, and adds no note.
The word patterns (project headings, "phase N" or "spec step N" prose, a bare `ROADMAP.md`, a
bare scope id) are judged by whoever writes the text, where `/jig:spec` step 5, fold-in and
`/jig:review` step 9 already ask for meaning. `SCOPE_WORDS` goes entirely.

The struck-entry mechanism stays as RULES.md has it (`### Removed` line, `struck` cell): the
owner can still strike an entry by hand. Only the search that proposed candidates goes.

## Intent
Survey and update stop listing existing product text by words; the boundary is held where
text is written: the hook refuses the precise patterns, and nothing searches for the word
patterns.

## Done when
- [ ] Smoke: a page with `## Status` over "`hal_status` returns …", a page line "In Phase 5 the
  wallet is a TEE.", and accepted entries saying "the launch base", "three phases" and "a demo
  mode", committed with the hook off: `jig survey` and `jig update` print none of them. This
  shows both reported symptoms are gone.
- [ ] Smoke: on the same repo, an old page line naming `.jig/specs/x.md`, a backticked scope id,
  a `## Undefined` entry and a tracked `TODO.md` are still listed by survey (`project_in_product`)
  and update (Repo files to review), with the messages they have today.
- [ ] Smoke: a commit adding a page line naming `.jig/specs/` or a backticked scope id is still
  refused, as today.
- [ ] Smoke: a commit adding a page line "Lands in phase 3." and a `## Status` heading succeeds
  (rc 0) with no `jig:` output about either.
- [ ] `SCOPE_WORDS` and `scope_candidates` are gone from `jig.py`; `grep -n SCOPE_WORDS
  plugin/templates/jig/jig.py` is empty.
- [ ] RULES.md (Documentation: Product and project; the page-sections paragraph; survey's and
  update's sweep paragraphs) says what survey and update list and that the hook refuses only the precise patterns, matching
  the table above; the update and survey skills, `/jig:update`'s "decision entry that reads as
  project scope" bullet included, say the same. The `marketing/FEATURES.md` boundary row's
  "survey lists prose" and "project decisions struck … or split" say what lists now.
- [ ] `bash tests/smoke.sh` passes, `claude plugin validate ./plugin` passes, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- `root_docs_named`'s bare-word listing (`ROOT_DOC_WORD`): same shape, no report; a follow-up
  if it over-flags.
- An opt-in `jig survey --project` keeping the old list (see Alternatives).
- Ids and recorded answers for the listings that stay: they are precise, so a hit is real.
- `/jig:redocument`'s fates for a status or plan section: an agent rewriting a page reads it
  for meaning, at creation.
- Editing any reporting repo: each gets this through `/jig:update`.

## Touches
- `plugin/templates/jig/jig.py`: `project_sections` and `project_prose` (`~1975–2005`) narrowed
  to `## Undefined` and the precise paths and quoted ids; `SCOPE_WORDS`
  and `scope_candidates` (`~9621–9697`) removed; `project_review` (`~9699`) and survey's
  `project_in_product` (`~3515`) and its print block (`~3709`) follow
- `plugin/templates/jig/RULES.md`: lines ~179–196, ~224–229, ~362–383
- `plugin/skills/update/SKILL.md` (~82–108), `plugin/skills/survey/SKILL.md` (~51–55),
  `plugin/skills/review/SKILL.md` step 9 (unchanged unless it says survey lists the prose)
- `marketing/FEATURES.md`: the project/product boundary row
- `tests/smoke.sh`: `sec_sweep` (~5334–5460) and the boundary section (~4518–4535)

## Alternatives considered
- **Narrow the heading check by content** (the Maige-Lite report: flag `## Status` only when
  the first paragraph has no code identifier, or has "done", "pending", a date): rejected
  because it keeps judging old text by words, the thing the owner asked to pull back, and the
  same tuning would follow for "phase" and "launch" [seen: the generality repro hits all three].
- **An opt-in `jig survey --project`** keeping the old list (maige-ecosystem's first option):
  rejected because nothing in jig would ask for it, so it is a flag kept for one migration that
  is done in both reporting repos, and its output would still be unanswerable [seen: no ids].
- **Skip released entries only** (maige-ecosystem's third option): rejected because unreleased
  accepted entries have the same product words, and the page listings have no release at all.
- **Give each finding an id so it can be answered once**: rejected because it makes every
  false positive a chore the owner does per repo per hit, which is the cost being removed.
- **A non-refusing `jig: note:` from the hook on added project-looking lines**: rejected by the
  owner, 2026-11-13 (Decisions). An agent reads a note as must-fix and rewords good product
  text, the over-flagging this spec removes. Reason is [seen: owner, Nov 13].
- **Refuse, not note, the word patterns at commit**: rejected because a refusal of
  `## Status` would block the Maige-Lite page outright, with no way past but a rename [seen:
  the heading is the API's name].

## Decisions
- **No hook note** (Dave, 2026-11-13: "Yes, open all eight", taking the hubnode's
  recommendation): creation-time tooling stays the hook's precise refusals, `/jig:spec` step 5,
  fold-in and `/jig:review` step 9.
- The precise listings stay in survey and update: they have never been reported as noise, and
  old text from before v0.11.0's hook is still the project's.
- `SCOPE_WORDS` goes entirely, not into the note: its hits in this repro were all product text.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
