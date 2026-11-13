# Handoff: docs-structure-evidence

Commit: f537c9579a9a5f843a7b78bee151325e987dd7b2
Date: 2026-11-12
Spec: .jig/specs/docs-structure-evidence.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
Survey, update and redocument now take evidence from the repo's own structure-bearing files, not only its pages and the board.
- `contract_holders`: a check of the old Now / Rules / Checks headings, a `reserve` counter over numbered page headings, and a root AGENTS/CLAUDE/GEMINI line holding the old contract. The line kinds are "bind as if they stood", the `§N.M` placeholder, Now joined to Rules or Checks, and a § or Rules/Checks pair right after a page's name. Survey lists them under their own heading (JSON `contract_holders`); its last line names /jig:update once no old page is left. Update lists them under Repo files to review and never edits them. Redocument seeds them as its first rows (verb `convert`), and its cleanup removes them.
- `page_levels` (JSON `levels`; `--levels` prints each with its evidence, imports included). Levels:
  - `subsystem`: has own files;
  - `section`: its docmap key's globs match no tracked file, so it folds;
  - `shared`: another page covers every file it does, a sibling (fold one into the other) or a seam;
  - `unmapped`: no docmap key, so name its files or fold it.
  Evidence: own files, JSON structure maps, CODEOWNERS, build manifests, and Python, JS/TS and C/C++ imports. `deep_fix`, `page_shapes` and update give each page one answer for its level.
- `structure_maps`: JSON files whose entries declare two or more docs pages with tracked files. Survey compares each with the docmap and names the files that read it.
- Words: "subsystem" for a docs level in RULES.md, `docs-page.md` (`## <Section>`), and the adopt, redocument and survey skills. `RETIRED_RULES` keeps the reworded tree sentence, so a frozen copy of the rules still reads as a copy.

## Done-when evidence
- Smoke `structure` (new, 11 cases on f537c95's code) passes: the holders, update's listing and `--apply` leaving them, b a section with no form move, f shared with c, c's `--levels` line ("subsystem: 1 own file, 1 shared with docs/a/f.md; reached through src/a/c/index.py, from 1 file"), owners.json the same as and then different from the docmap, d's fold-only deep line, plus the review rounds' cases. `homes` prints none of the new headings.
- Daisy, a scratch clone at df641b1d running this jig.py, untouched (`git status` empty):
  - Holders: `daisy/tests/test_docs.py:99` and `:1016`, `.jig/config.json reserve.section`, `AGENTS.md:9`, `:12` (cites `docs/core/core.md §2`) and `:50`.
  - `--levels`: subsystem 30, unmapped 10, section 3 (prompt, cloud, local), shared 0. All 13 hand-folded pages get a fold answer and no deep_subsystems choice.
  - Map: `docs/owners.json` is listed, named by `scripts/gen_reference.py`, `scripts/reading_list.py`, `daisy/tests/test_docs.py`, `daisy/tests/test_reading_list.py` and 20 Markdown files.
  - Before this change: survey named none of these, and its last line was only "Pages in the old Now / Rules / Checks shape". CPU time is 15.3 s on trunk, 15.6 s now, and 18.5 s with `--levels`.
- In this checkout, `python3 plugin/templates/jig/jig.py survey --json` gives `contract_holders: []`.
- `bash tests/redocument-fixture.sh`: "seed: holder rows first, docs/store/cache.md a section".
- Greps: `grep -rn "part page" plugin` and `grep -n "<Part>" plugin/templates/jig/docs-page.md` find nothing; RULES.md no longer says "a part of a system".
- `bash tests/smoke.sh` gives 1050 PASS and 0 FAIL on 07766a5, the last code change; f537c95 adds only the ledger and the spec rewrap. `claude plugin validate ./plugin` passes, and so does `.jig/scripts/check.sh`. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Review
The hubnode ran three rounds of adversarial review, recorded at f537c95 (tier 2, effort 2).
- **Round 1** (1 blocking, 4 should-fix), fixed in 38b3a40:
  - A page with no docmap key was called a section; it is now `unmapped`, and the `flat` smoke cases are back as they were.
  - Deeply nested JSON crashed survey; the parse is now guarded and size-capped.
  - Locale files read as structure maps; a map now needs two entries that name tracked files.
  - The holder scans over-matched: numbered headings and register counters were flagged.
  - Deep pages got several answers; deep_fix now takes the level.
- **Round 2** (2 blocking, 2 should-fix), fixed in 374907e:
  - Unmapped deep pages still got the deep_subsystems choice.
  - The spec was amended: unmapped is its own level, and a section is a key that matches nothing.
  - The line scan missed named holders.
  - Update didn't list a non-deep unmapped page.
  - The deep-JSON smoke case didn't reach its error path.
- **Round 3** (1 blocking, 1 should-fix), fixed in 07766a5:
  - Update drafted a fold for unmapped and seam deep pages.
  - The widened line scan flagged ordinary lines; a citation now needs a page's name right before it.
  - Two optional wording fixes were taken (the spec's done-when and the deep heading).
- The final review confirmed all fixes. The 11 rows not taken (4 from the final review, 7 from earlier rounds) are in `.jig/ledgers/DEFERRED.md`.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here: the subsystem definition, the body sections, the tree sentence, the new paragraph on levels and holders, and `jig survey [--json] [--levels]` in Commands.

## Shared files changed
- `plugin/templates/jig/jig.py`: the functions, survey, update, deep_fix, page_shapes and argparse, as the spec's Touches says.
- `plugin/templates/jig/RULES.md` and `plugin/templates/jig/docs-page.md`: the "subsystem" wording, the levels and holders paragraph, and the command list.
- The survey, update, redocument and adopt skills: the holder rows, the Level column, unmapped, and the wording.
- `tests/smoke.sh`: the new `structure` section and one `homes` case.
- `tests/redocument-fixture.sh`: a holder and a section in the fixture, the Level column in the seed, and its check.
- `.jig/ledgers/DEFERRED.md`: the rows the review deferred.
- `.jig/specs/docs-structure-evidence.md`: the review's amendments, which say unmapped is its own level, narrow the line holders, and update the Daisy done-when.
- The `marketing/FEATURES.md` rows ("Old-contract holders", "Page levels from evidence") are already in the main checkout, as the kickoff said.

## Test by hand
- In a repo with a pre-Nov-6 jig, run `python3 .jig/jig.py survey`. The new heading should list its check, counter and AGENTS lines.
- Run `survey --levels` and read each page's level and evidence. A page you know is a subsystem should come out `subsystem`.

## Left
- Nothing on this spec.
- The DEFERRED rows are follow-ups: widening the citation forms, possessive forms, a marker for converted checks, and import resolution.
- Daisy's own files are untouched, as the spec's Out of scope says.
