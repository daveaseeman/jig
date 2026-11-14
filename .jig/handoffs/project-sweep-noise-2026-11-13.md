# Handoff: project-sweep-noise

Commit: c794c76f10e8c8cf4e1be5fd16cc9c55eff68c90
Date: 2026-11-13
Spec: .jig/specs/bug-project-sweep-noise.md
Review: tier 2, effort 2

## Built
- `jig survey` and `jig update` stop judging existing product text by words. Gone from both: `## Status`, `## Current state` and `## Roadmap` headings, "phase N" / "spec step N" prose (`PROJECT_PROSE`), bare `ROADMAP.md`, bare scope ids, and `SCOPE_WORDS` over decision entries and register rows (`scope_candidates`, removed with it).
- Kept, since they are never product text: `## Undefined`, `.jig/specs/`, `.jig/handoffs/` and `.jig/roadmap.md` paths, scope ids in code quotes (the hook's own set), and plan files by name (`TODO.md` …).
- The hook is unchanged: it still refuses the precise patterns and adds no note (owner's decision). The word patterns are judged by whoever writes the text.
- RULES.md (Product and project, page sections, survey and update sweep paragraphs) and the update, survey, review (step 9) and retro skills say the same.

## Done-when evidence
- Reported symptoms gone: smoke `PASS sweep: a page line naming a spec is under Repo files to review; phase 3, Phase 5 and ## Status sections aren't, in update or survey` (`docs/hal.md`: `## Status` over `hal_status`; `docs/r.md`: "In Phase 5 the wallet is a TEE."). Also `PASS sweep: no released entry is listed by its words, launch, phases and demo included, in update or survey`. The survey half asserts the spec-path line is present, so a crash can't pass.
- Precise listings stay: `PASS boundary: survey lists old spec paths, quoted scope ids and ## Undefined, and no words: phase 3, ## Status, bare ids, ROADMAP.md`, `PASS boundary: update lists the old quoted scope id under Repo files to review, and not phase 3` (`docs/b.md: line 5: "phase-1/screen" names the plan`), `PASS sweep: update lists each ## Undefined entry as the Up next item it would be, naming the page`, `PASS sweep: tracked TODO.md and FEATURES.md are each listed with their destination`.
- The hook still refuses: `PASS boundary: the hook refuses a page line naming a spec, with the line named`, `PASS boundary: the hook refuses a page line naming a scope id in code quotes`.
- Word patterns commit silently: `PASS boundary: a page line saying phase 3 and a ## Status heading commit, and the hook says nothing about them` (rc 0, no `jig` output).
- `grep -n 'SCOPE_WORDS\|scope_candidates' plugin/templates/jig/jig.py` → no output.
- RULES.md and the skills: `plugin/templates/jig/RULES.md`, `plugin/skills/{update,survey,review,retro}/SKILL.md`, in 79f52d7 and c794c76.
- `marketing/FEATURES.md` boundary row: the hubnode's item. The file is gitignored and lives only in the main checkout, so the hubnode wrote the row ("Boundary held at creation, not by search"). Not done on this branch.
- `bash tests/smoke.sh` at c794c76 → `smoke_rc=0`, 1228 PASS, 0 FAIL. `claude plugin validate ./plugin` → `✔ Validation passed`. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → no output, rc 1.
- A run before that one failed one check, `isolation: the user's real jig config folder is unchanged by the run`. `~/.config/jig/repos.json` changed at 19:11:47, while other sessions were doing real jig work. The rerun right after was clean and the file was untouched.

## Review
Hubnode review of 79f52d7: nothing blocking. All five findings were taken, in c794c76:
1. `plugin/skills/retro/SKILL.md:26` still said survey lists `## Status`/`## Roadmap`. Taken: retro now names `## Undefined` as the listed heading, and a `## Status` or `## Roadmap` section is judged by what it says (build status or when → project; the product's own thing stays). Synced first; retro is added to shares.
2. RULES.md's flat "A page has no … `## Status` …" contradicted the new lines. Taken: a section holds the project only when it gives build status (done, pending, not built yet) or says when and in what order; what it says decides, not its heading. Review step 9 matches: "judge by what it says, never by a heading or a word". Only step 9 was edited; roadmap-no-phase's lines 62-63 were left alone.
3. Optional: evidence for update's half of Done-when 2. Taken: a backticked scope id smoke test (`update lists the old quoted scope id under Repo files to review, and not phase 3`).
4. Optional: `! $J survey | grep` passes on a crash. Taken: survey output is captured once and the assertions require the expected listings (`## Undefined`, the spec path, `"phase-1/screen"`) to be present.
5. Optional: the moot DEFERRED.md row about `SCOPE_WORDS` matching paths. Taken: disposition reads "taken by project-sweep-noise (bug-project-sweep-noise): `SCOPE_WORDS` removed".

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md` (Documentation: Product and project, page sections, survey and update sweep paragraphs), updated here, plus the survey and update skills.

## Shared files changed
- `plugin/templates/jig/jig.py`: `project_sections`, `project_prose` and `project_review` narrowed. `PROJECT_PROSE`, `PLAN_PATHS`, `scope_bare`, `SCOPE_WORDS` and `scope_candidates` removed. No other function touched.
- `plugin/templates/jig/RULES.md`: the four paragraphs the spec names.
- `tests/smoke.sh`: assertions in the boundary section and `sec_sweep`, plus two planted pages and one decision entry; no section moved.
- `plugin/skills/review/SKILL.md`: step 9 only (roadmap-no-phase edits lines 62-63).
- `plugin/skills/retro/SKILL.md`: added after review (finding 1), one line about survey's listed headings.
- `.jig/ledgers/DEFERRED.md` (common): one row's disposition (finding 5).

## Test by hand
- In a scratch repo on this jig, add a page with `## Status` over "`hal_status` returns `EVT_*` bits" and the line "In Phase 5 the wallet is a TEE.", then commit. The commit succeeds silently. `python3 .jig/jig.py survey` and `python3 .jig/jig.py update` list neither.
- Add a line naming `.jig/specs/x.md` to that page: the commit is refused, naming the line.

## Left
- Nothing on this job.
- Follow-up (spec's Out of scope): survey's `root_docs_named` (`ROOT_DOC_WORD`) searches bare words over existing text in the same way. No report yet.
