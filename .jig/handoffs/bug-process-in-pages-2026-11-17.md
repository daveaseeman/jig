# Handoff: bug-process-in-pages

Commit: d0bdb2652ce1f670b351522d86e9bc71ab46ff5a
Date: 2026-11-17
Spec: .jig/specs/bug-process-in-pages.md
Source: Daisy hubnode session / 2026-11-16 / the owner (Dave Seeman) (staged as feedback-Daisy-2026-11-16-process-in-pages.md): "docs/ is meant to describe daisy's own code not how to use a tool that defines itself how it is used … Jig has a place for release process, we dont need that in docs because it doesnt describe the app", and "WHY IS JIG MENTIONED IN DAISYS DOCS".
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
Pages describe the product only; how the repository is worked has its homes, by one test.
- RULES.md, Documentation: a **Product and process** paragraph (homes, and the carve-outs for product behaviour and a board page's Toolchain and Flash / rollback). Homes: the one-home sentence ("a procedure an agent runs in a skill, and the rest of how the repo is worked in `.jig/process.md`, never in `docs/`"), the test's table (W1's row for jig's own rules), and where a line cut from AGENTS.md goes. The Invariants item: a holder is a named test or what is seen on screen, and review is none.
- `plugin/templates/process.md`: new, created on first use (never by init's copy of `templates/jig/`), with § Code style and § Release. The AGENTS.md template has its cut-line comment and a pointer line naming triggers.
- jig.py:
  - `process_prose`/`process_lines` list a page's `.jig/` path other than the decision log, `./` and `../` forms included and `~/.jig/` excluded, outside fenced code and HTML comments; a quoted `<!--` opens nothing. They print under survey's "How the repository is worked…" heading (JSON `process_in_pages`) and in update's Repo files to review.
  - `holder_names_review`: survey and update list each Invariants entry whose holder names review (H1 (a)).
  - The Too long line says where a cut line goes. UNOWNED's excuse names the repo's tooling. `home_fix` and PLAN_FILES sort a rules file by the test.
  - `.jig/process.md` is read by `--claims` and the other jig-folder readers, and named in Doc homes.
- Templates docs-page.md and hardware.md drop review as a holder. The skills redocument, spec, review, retro, survey, update, init, adopt and hubnode point at the test; redocument gains a process fate and a `Process:` Flagged line.
- tests/smoke.sh: the "held by review" fixtures hold `test_*`. New tests in boundary (process), page_contract (holders), hardware (the board template), claims (process.md), and rules (init's copy).
- `.jig/decisions.md`: an Unreleased Changed line.


## Done-when evidence
- Product and process paragraph: `grep -n "Product and process" plugin/templates/jig/RULES.md` → line 230; `grep -n "a procedure an agent runs" plugin/templates/jig/RULES.md` → the one-home sentence and the table row; `grep -rn "know-how in the agent's skills" plugin` → nothing.
- The `.jig/` listing: `bash tests/smoke.sh boundary` → PASS for each process test. Survey lists the config.json line, the three relative-link forms, the quoted-`<!--` line and the layout tree, and nothing else: no decision log, comment, fence, product line, spec path, `~/.jig/` or process.md. The heading names the homes, update lists the line, and Doc homes names `.jig/process.md`.
- The board template: `bash tests/smoke.sh hardware` → "process: the board template, copied onto a page, names no .jig/ path survey lists" PASS.
- `.jig/process.md`: the template exists at `plugin/templates/process.md` (the hubnode's Interpreted line). `bash tests/smoke.sh claims` → "a copy in .jig/process.md is listed" PASS. `bash tests/smoke.sh rules` → init's `.jig/` holds no process.md, PASS.
- Holders: `bash tests/smoke.sh page_contract` → "each invariant whose holder names review is listed as such, never as no holder…" PASS, and "update lists the same eight entries" PASS. `grep -nE "TEST_NAME|which is no holder" plugin/templates/jig/jig.py` → nothing.
- Too long and UNOWNED: `bash tests/smoke.sh boundary` → "survey's Too long line names where a cut line goes, and never a page" PASS, and "the fold-in's UNOWNED line names the repository's own tooling" PASS.
- Skills point at the test: `grep -c process.md plugin/skills/{hubnode,spec,retro,update,adopt}/SKILL.md` → each ≥ 1.
- Reported symptom, by hand on read-only `git archive` copies, run as `JIG_CONFIG=<scratch>/repos.json XDG_CONFIG_HOME=<scratch> python3 <worktree>/plugin/templates/jig/jig.py survey [--json]` in each copy:
  - Daisy at 2209ef36^ (the reported state; its HEAD has since moved the lines): survey lists docs/core.md:23, :215 and :218 and docs/app/releases.md:128 (:162 sits in a fence, which 2a excludes: Interpreted), and the update dry run lists 4 process lines.
  - Holders at 9214e52: Maige-OS 9a278a1 lists 20 entries whose holder names review, Maige-Lite 7c510b5 lists 16, Daisy e23ea548 lists 0. No `page_contract` line says "no holder".
- `.jig/scripts/check.sh` → exit 0. `claude plugin validate ./plugin` → ✔ Validation passed. `grep -rnE 'Maige|maige|Daisy|daisy' plugin` → nothing.
- Smoke runs on this branch: boundary, page_contract, hardware, claims and rules → 180 PASS, 0 FAIL (473bbc7). page_contract and hardware → 77 PASS, 0 FAIL (9214e52). rules, update, agents_lines, homes, init_old_board, update_per_file, report_fixes, removals, pointers and structure → 400 PASS at 8aa759d; its one FAIL (init copying process.md) was fixed, and the template has since moved out of `templates/jig/`. The full suite is the check role's.


## Review
- review-work of 8aa759d: 1 blocking. PROCESS_PATH missed `../.jig/` links: fixed in 473bbc7, smoked. Should-fix S1–S3 and the optionals were taken in 473bbc7: the pointer line, process.md in `--claims` and the other readers, Doc homes, the inline `<!--`, the template moved to `templates/process.md`, § Release, and redocument's holders. The Homes table rows for reading-list and CI stay as they are.
- review-change of 473bbc7: 1 blocking. The review-holder pattern lost "review of …" forms: fixed in e5847be. The round's should-fix was used, so 7 DEFERRED rows (3 should-fix, 4 optional).
- review-change of e5847be: blocking (strike 3), which started Bug. Bug spec `.jig/specs/bug-process-in-pages-holders.md` (992e372). H1 was answered by the owner on 2026-11-17, "do both", read as (a). Built in 9214e52, with the sync with trunk resolved by hand in 24d9b50 (hubnode/SKILL.md, both sides kept).
- review-change of 24d9b50..9214e52: clean, blocking 0. Its 5 findings (1 should-fix, 4 optional) are DEFERRED rows in d0bdb26: `code-review`/`peer-review` compounds, the first "held by" in an entry, the survey/update skill text, one exception covering a whole page, and the parent spec's Correction wording.


## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Documentation: Product and process, the Invariants item, what survey lists; Homes: the one-home sentence and the test's table). This repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/jig.py`: the listings, the holder check, and the survey, fold-in and update wording.
- `plugin/templates/jig/RULES.md`: Product and process, the Homes table, the Invariants holder, what survey and update list.
- `tests/smoke.sh`: the held-by-review fixtures, and new tests in boundary, page_contract, hardware, claims and rules.
- `plugin/skills/hubnode/SKILL.md`: where new process goes (the sync with rigger kept its inbox paragraph beside it).
- `plugin/skills/review/SKILL.md`: question 9 asks about how the repository is worked.
- `plugin/skills/init/SKILL.md`, `adopt/SKILL.md`, `update/SKILL.md`: where cut lines go, sorting rules files by the test, process.md's template and pointer line.
- `.jig/decisions.md`: the Unreleased line. `.jig/ledgers/DEFERRED.md`: 12 rows.


## Test by hand
In a scratch repo with a page that has a line "jig's `docmap` in `.jig/config.json` says which page owns a file." and an invariant "- X — Y; held by review.", run `jig survey`. Watch for the "How the repository is worked…" heading naming the line, and the page-contract line "invariant whose holder names review…". Then run `jig update` (dry run) and see both under Repo files to review.


## Left
Nothing on this spec. The DEFERRED rows stand: 3 should-fix pointer-line gaps and 4 optional from review-change of 473bbc7, and 1 should-fix and 4 optional from review-change of 9214e52. marketing/FEATURES.md is the hubnode's.

