# docs-structure-evidence

Source: jig hubnode side session (Daisy survey), 2026-11-12, raised by the owner (staged as feedback-Daisy-2026-11-12-update-leaves-old-contract-enforcers.md): docs tooling enforces the old shape, and nothing in jig noticed that Daisy's 22 "part" pages may not be subsystems.

This spec covers issues 1 and 4 of the report. Issues 2 and 3 are `findings-record` and `page-form-enforced`.
Both issues come from one root. Survey, update and redocument take their evidence from pages
(headings, paths) and the board only. The repo's own files that hold its docs structure are
not evidence: its checks, its counters, its always-loaded lines, its structure maps, its
manifests and its imports.

## Intent
Survey and update list every check, counter and always-loaded line that still holds jig's old
page contract, and redocument converts them before any page. Every page below a system gets a
level (subsystem, a section of its system, or shared), worked out from evidence: the files it
owns, the repo's structure maps and manifests, and its imports. Survey, update and redocument
give that one answer, and the owner approves it. "Subsystem" names a docs page's level
everywhere; "part" means a hardware part only.

## Why
Issue 1:
1. Q: Why did Daisy's redocument stop before converting a page?
   A: `daisy/tests/test_docs.py` fails any page without Now, Rules and Checks, and check.sh runs it at every stop. Nothing had listed it.
2. Q: Why had nothing listed it?
   A: Survey and update read pages. `old_contract()` is only ever given a page's text, and no code reads the repo's checks, counters or AGENTS.md for the contract.
3. Q: Why does a repo hold the old contract outside its pages?
   A: jig shipped it until b47bd64 (Nov 6). It came with a `section` counter over `docs/**` and an AGENTS line making page rules bind. The contract change migrated pages only.

Issue 4:
1. Q: Why did nothing notice that Daisy's pages with no files aren't subsystems?
   A: jig judges a page's level by its path. `depth_ok`, `unapproved` and `page_folder` count folders, and nothing compares a page's files with its siblings'.
2. Q: Why does nothing check RULES.md's definition?
   A: docs-subsystems wrote the definition and deferred the check: "whether survey should check it is a later call."
3. Q: Where did Daisy's levels come from, then?
   A: From `docs/owners.json`, a predecessor's map. `gen_reference.py` turns it into the docmap and `test_docs.py` enforces it. jig reads the docmap, never the map behind it.

## Givens
- `[seen]` The report's `jig_version` `1a8efef0e75c` is `git hash-object` of today's
  `plugin/templates/jig/jig.py`, and of Daisy's `.jig/jig.py`. The bug is in this copy.
- `[seen]` A scratch clone of Daisy at `df641b1d`. `jig survey` names none of these:
  - `daisy/tests/test_docs.py`;
  - `.jig/config.json` `reserve.section`;
  - `AGENTS.md:9` and `:50`;
  - `docs/owners.json`, `scripts/gen_reference.py`, `scripts/reading_list.py`.

  Its last line is "Pages in the old Now / Rules / Checks shape: run /jig:redocument".
- `[seen]` In a clone at `934cbbba` (just before Daisy's update `9450375d`), the plugin's
  `jig update` dry run writes the new `RULES.md` and `docs-page.md`. It names `test_docs.py` only
  for lines that name `docs/core/core.md`, which a form move would rename, and names neither the
  counter nor the two AGENTS lines.
- `[seen]` In the clone, the docs tests pass (73). Rewrite `docs/chains/cursor/cursor.md` to the
  contract (a lead paragraph, one section) and two fail:
  `test_every_system_document_has_its_shape` and `test_every_cited_section_has_exactly_one_heading`.
  The tests ran under Daisy's venv interpreter, reading the clone.
- `[seen]` The report's symptoms reproduce in a minimal scratch repo from this checkout's
  templates. It holds:
  - `docs/a.md`;
  - `docs/a/b.md`, old contract, docmap `[]`;
  - `docs/a/c.md`, covering `src/a/c/**`;
  - `tests/test_docs.py` holding `["Now", "Rules", "Checks"]`;
  - a `section` counter;
  - the two AGENTS lines;
  - `docs/owners.json`.

  `jig survey` and the `jig update` dry run name none of the test, the counter, the lines, the
  map, or b's level.
- `[seen]` `old_contract()` (`jig.py:1788`) is called from `page_problems`, `page_shaped` and
  survey's last line (`1794`, `1987`, `2836`). Each passes it a page's text.
- `[seen]` jig shipped the old contract's other holders.
  - Before b47bd64, RULES.md's counter example was
    `"section": {"pattern": "^### (\\d+)\\.\\d+", "files": ["docs/**/*.md"]}`.
  - Adopt's migration line was `--reserve schema=<held> section=<held>`.
  - From the initial commit `eaec973` to `b47bd64^`, the AGENTS template's docs line ends:
    "Rules written in a documentation page bind as if they stood in this file."
  - Daisy's `AGENTS.md:9` rewords that line ("bind as if they stood here"). `:50` says "Now and
    Rules match the code".
- `[seen]` `docs-page-contract.md`, Migration: "`jig update` ships the new RULES.md; it does not
  rewrite pages. Survey flags old-format pages". Its Design: "R6 section counters for docs pages
  are dropped from the template config examples". Nothing told a repo that already holds one.
- `[seen]` `update.md`, Out of scope: "Editing the repo's own files: `AGENTS.md`, `CLAUDE.md`,
  docs, specs, ledgers, code. `update` moves jig's files and reports stale references; the skill
  and the user fix them."
- `[seen]` `/jig:adopt`, What does not migrate: "Repo-specific docs tests. They stay the repo's,
  reading whatever file they read."
- `[seen]` Daisy's `test_docs.py`, `gen_reference.py` and `owners.json` came in `d3ec4f37`
  (2026-10-16), and `reading_list.py` in `f5ac3127` (2026-10-21). Daisy adopted ai-dev on
  2026-10-26. `owners.json` lists `test_docs.py` under `repository`.
- `[seen]` In this checkout, one scan runs outside `.jig/`: the three words together on one line.
  It finds only `plugin/templates/jig/jig.py` (`Now|Rules|Checks`), and that file is under
  `not_docs`.
  - `tests/smoke.sh:3280` holds all three headings in one `printf` fixture, but `\nx\n\n## `
    separates them, so that scan misses it.
  - A scan for heading-form strings (`## Now` in code) would flag it.

  On the Daisy clone, the same scan finds exactly `test_docs.py`, the counter and lines 9 and 50.
- `[seen]` `docs-subsystems.md`, Out of scope: "Checking "files of its own" mechanically, for
  example that a subsystem page has a docmap glob matching files its system's other globs don't.
  The definition says it; whether survey should check it is a later call."
- `[seen]` The phrase "files of its own" appears in RULES.md:145–148, `docs-page.md` and nowhere
  in `jig.py`. `page_globs` and `doc_owners` are used by handoff, reading-list and the gate's
  board checks, never to judge a level. `misfiled_seams` is the one place that compares globs
  across pages.
- `[seen]` Daisy's docmap:
  - 4 keys map to `[]`: `extensions`, `conversations/prompt`, `engine/cloud`, `lanes/local`;
  - its 10 deep pages have no key.
- `[seen]` A scratch probe on the clone took each page below a system. It worked out its own
  files (covered by its docmap globs and by no page except those above it), and its Python and
  JS/TS imports. Results:
  - 13 pages own no files. They are the 13 that Daisy's approved remap merges by hand, rows 5–15
    ("canvas and home own no files", "owns no files").
  - The 22 pages of row 4 each own 1–44 files. Each is reached from the rest of its system
    through 0–5 of its files (folders 5 of 34, skills 1 of 9).
  - The imports separated nothing that own files didn't.
- `[seen]` `owners.json`:
  - top-level keys `about`, `checked`, `skip`, `core`, `systems` (12), `shared`, `repository`;
  - 33 "parts", 3 of them with no files;
  - `gen_reference.py`'s `docmap_of()` writes `.jig/config.json`'s docmap from it;
  - `test_docs.py` check 8 requires the docmap to equal what that writes.
- `[seen]` Drop `docs/conversations/prompt/prompt.md`'s docmap key in the clone, as redocument
  step 5 would after the fold, and `test_the_board_s_docmap_is_derived_from_owners` fails.
  Daisy's approved remap row 21 leaves `owners.json`, `gen_reference.py` and `reading_list.py`
  unchanged.
- `[seen]` jig's text uses "part" for a docs level:
  - "part pages" in adopt `SKILL.md:36` and redocument `SKILL.md:100`;
  - `## <Part>` in `docs-page.md`;
  - "a part of a system" in RULES.md:145.

  It also uses it for hardware: `components/<part>/`, and RULES.md:248. `docs-page.md` also still
  says a subsystem "gets a folder and a page of its own", from before flat-pages.
- `[seen]` Timings: survey takes 23 s on the clone's 969 files. The probe's level and import
  pass took 13 s, unoptimized.
- `[assumed]` Other repos that ran `/jig:init` before Nov 6 carry the template's AGENTS sentence,
  and some carry the example counter. This is inferred from the templates; no other repo was
  read. It is a risk to the benefit only: the scan is cheap and prints nothing where there is
  nothing.
- `[assumed]` JS path aliases (`@/lib`), dynamic imports and runtime interfaces (HTTP, IPC) are
  common, so import evidence undercounts. The output says what it couldn't read.

## One layer up
- **Sibling: update's stale references.** Repo code that names a path jig moved is listed with
  its lines, and a `.py` naming `.jig/lanes.json` warns. A contract change is the same shape,
  repo files naming what jig changed, and gets no such pass. What's different is that a path is
  a string, while a contract is a shape. So the scan keys on jig's own retired shapes: the three
  words, a heading counter and the template sentence. The layout table keys on jig's own old
  paths the same way.
- **The healthy path: Daisy's remap did it by hand.**
  - Row 1 is `test_docs.py`, the first job, accepting both shapes while the run lasts.
  - Rows 19–20 handle the AGENTS lines and the counter at cleanup.
  - Rows 5–15 fold the pages that own no files.

  This spec makes jig produce those rows.
- **Existing code to reuse:**
  - `misfiled_seams` compares docmap globs across systems;
  - `page_globs` gives a page's globs in either form;
  - `naming()` finds the files that name a path;
  - `deep_subsystems` already asks for a rationale with "the files it has of its own", which is
    the evidence computed here.

## Design
**A. Holders of the old contract (issue 1).** `contract_holders(root, files, board)` is shared
by survey and update. It reads tracked files outside jig's folders and outside `not_docs`. A
file under `not_docs` ships as code, so its text is the product's, not a check of this repo's
pages. It finds three kinds of holder, each with its fix:
- **A check:** a non-Markdown file with `Now`, `Rules` and `Checks` together on one line,
  separated only by quotes, commas, pipes, brackets or spaces (`["Now", "Rules", "Checks"]`,
  `(Now|Rules|Checks)`). Fix: it converts with the pages, accepting both shapes while
  /jig:redocument runs and the new one only after its cleanup.
- **A counter:** a `reserve` counter whose pattern takes a number from a heading line of a
  docs page its files cover. Fix: drop it at redocument's cleanup, once no page holds a numbered
  heading, since the contract cites by heading. A register or the decision log is no page, so
  their counters aren't holders.
- **A line:** in root `AGENTS.md`, `CLAUDE.md` or `GEMINI.md`, a line that has any of:
  - "bind as if they stood" (the template sentence and its rewordings);
  - two of Now, Rules, Checks joined (`Now and Rules`, `Rules/Checks`);
  - a numbered page citation (`§N.M`, `§87`, `### N.M`).

  Fix: the template's Documentation line, and cite a page by its heading.

Survey prints them under "Checks, counters and lines that hold the old page contract (RULES.md,
Documentation)", and `--json` gives them as `contract_holders`. Its last line names
/jig:redocument while old pages stand. With no old page left, it names /jig:update, to edit each
holder where it sits. Update lists each holder under Repo files to review, with the same fix,
and never edits it.

Redocument:
- Step 1 seeds one row per holder.
- The holder rows are the run's first job, before any page job, so check.sh passes on converted
  pages.
- Step 6's cleanup removes the old shape's acceptance, the counter and the lines.

Adopt 4b now reads: "Repo-specific docs tests stay the repo's; where they check a page shape or
number rules, they convert with the pages."

**B. A page's level (issue 4).** `page_levels(root, files, board)` covers each page below a
system, in a code repo; a metarepo has no code to read. Its evidence is read-only and stdlib.
1. **Own files.** These are the tracked files its docmap globs (in either form) cover, minus the
   files any page other than those above it covers.
2. **Structure files**, each taken as evidence:
   - **A JSON structure map:** a tracked JSON file in which entries name at least two docs
     pages. An entry names a page when the page's folder names appear in order in its key path
     (`systems.a.parts.b` → `docs/a/b.md`). Its files are the strings in the entry's own lists
     that match tracked files.
   - **`CODEOWNERS`:** the owners of a page's own files.
   - **Build manifests:** a folder below the root holding `package.json`, `Cargo.toml`,
     `go.mod`, `pyproject.toml`, `setup.py`, `CMakeLists.txt`, `idf_component.yml` or
     `library.json` is a unit that builds on its own. These are found by presence, with no
     parsing.
3. **Imports**, with `--levels` only:
   - Python, by `ast`;
   - JS/TS relative specifiers;
   - C/C++ quoted includes.

   Each is resolved against tracked files. For a page with own code: which of its files the
   rest of its system imports, and from how many files. Other languages print "no import
   evidence for .<ext>".

Levels:
- **A section of `<page above>`:** it covers no tracked file (no docmap key, or globs matching
  nothing). RULES.md's definition settles this one, so no `deep_subsystems` rationale can hold
  either. It is still a fold on the owner's yes, never a move jig makes.
- **Shared:** it covers files, but another page, not one above it, covers every one of them.
  - With a sibling, it is the same subsystem as that sibling: fold one into the other.
  - With a page of another system, it is a seam, which `misfiled_seams` already names. The seam
    goes in the folder both systems share.
- **A subsystem:** it has own files. `--levels` prints its evidence, and the files it shares.
- Board pages are exempt: `boards` makes them what they are, and survey already lists an
  unmapped one.

Survey always prints the sections and shared pages under "Pages below a system that own no
files (RULES.md, Documentation: a subsystem has files of its own)", with the page each folds
into. It also lists
each JSON structure map under "Files that declare the docs structure":
- what the map declares;
- how it compares with the docmap: the same files, or the pages where they differ;
- the files that name it (`naming()`).

A map that declares the same files as the docmap is a second declaration: the two must change
together, so keep one, or derive one from the other. `jig survey --levels` prints one line per
page, with its level and evidence, and `--json` carries `levels`.

**One answer.**
- `page_shapes` proposes no form move for a page whose level is a section.
- For a deep page that owns no files, `deep_fix` offers only the fold. For one with own files it
  offers both choices, and names those files as the rationale's evidence.
- Update lists each section under Repo files to review, with its fold and the `commit_lines` it
  touches.
- Redocument's remap table gains a Level column, seeded from `survey --levels`. A row whose level
  differs from survey's shows survey's evidence beside it, for the owner.

**C. Words.**
- RULES.md:
  - "A **subsystem** is a system inside a system: it works independently of the rest of it…";
  - body sections are "named for what its code has (Schema, Renderer, Sync)";
  - "the tree names the product's systems, not its files".
- `docs-page.md`:
  - `## <Part>` becomes `## <Section>`;
  - "A part with files of its own…" becomes "A section whose code has files of its own…";
  - "gets a folder and a page" becomes "gets a page of its own".
- Adopt and redocument: "part pages" becomes "subsystem pages".
- Survey and redocument: "named for the system's parts" becomes "named for what its code has".
- `jig.py`: the comments at ~1515 and ~2286.
- Unchanged: hardware's `components/<part>/`, and RULES.md's "A part whose behavior the code
  touches…".

## Done when
- [ ] Smoke `structure` (new section), a repo holding:
  - `docs/a/a.md`;
  - `docs/a/b.md`, old contract, `### 1.1`, docmap `[]`;
  - `docs/a/c.md`, covering `src/a/c/**`: `index.py` and `impl.py`. `src/a/main.py`, under
    `docs/a/a.md`, imports only `index.py`;
  - `docs/a/f.md`, covering `src/a/c/impl.py`;
  - `tests/test_docs.py`, with `HEADS = ["Now", "Rules", "Checks"]`;
  - `tests/fixture.sh`, which `printf`s an old page;
  - a `section` counter `^### (\d+)\.\d+` over `docs/**/*.md`;
  - `AGENTS.md`, with the template sentence and "Now and Rules";
  - `docs/owners.json`, declaring a, b (no files) and c, which `scripts/gen.py` names.

  The checks:
  - `jig survey` names, under the holders heading, `tests/test_docs.py`, `section` and both
    AGENTS lines. It doesn't name `tests/fixture.sh`. Its last line names /jig:redocument. This
    is the fix firing.
  - The `jig update` dry run lists the same four under Repo files to review. `--apply` leaves all
    four unchanged.
  - Survey says `docs/a/b.md` owns no files, a section of `docs/a/a.md`, and gives b no form
    move. It says `docs/a/f.md` shares every file with `docs/a/c.md`: the same subsystem, fold
    one into the other. It doesn't name `c`. `--levels` gives `c` "subsystem: 1 own file, 1
    shared with `docs/a/f.md`; reached through `src/a/c/index.py`, from 1 file".
  - Survey lists `docs/owners.json` as declaring a, b and c with the same files as the docmap,
    and names `scripts/gen.py`. Change c's docmap globs and the line says it differs for c.
  - Add `docs/a/c/d.md` with docmap `[]`. Its deep line offers only the fold into
    `docs/a/c.md`, with no `deep_subsystems` choice.
  - The `homes` fixture prints none of the three new headings.
- [ ] The symptom, on Daisy. A scratch clone at `df641b1d` runs this `jig.py`.
  - `jig survey` names `daisy/tests/test_docs.py`, `reserve.section`, and `AGENTS.md` lines 9
    and 50.
  - `--levels` names as sections the 13 pages that the approved remap folds by hand (rows 5–15).
    It gives each of the 22 row-4 pages a level and its evidence, so none is judged by depth.
  - It lists `docs/owners.json` as declaring the docmap's files, and names `gen_reference.py`,
    `reading_list.py` and `test_docs.py`.
  - Daisy itself is not touched.
- [ ] In this checkout, `python3 plugin/templates/jig/jig.py survey` lists no holder.
- [ ] `tests/redocument-fixture.sh`: the seed taken from `survey --json` puts the holder rows
  first, and gives `b` the level `section`.
- [ ] `grep -rn "part page" plugin` finds nothing. `grep -n "<Part>"
  plugin/templates/jig/docs-page.md` finds nothing. RULES.md doesn't say "a part of a system".
  The update, redocument and adopt skills carry the holder rows and the Level column.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass, and
  `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` finds nothing.

## Out of scope
- Removing or editing a holder or a map. Update lists them, the owner decides and the session
  edits (`update.md`).
- YAML and TOML structure files. There is no stdlib YAML, and `tomllib` needs 3.11, while the
  README asks for 3.10.
- Imports beyond Python, JS/TS and C/C++, and aliases, dynamic imports and runtime interfaces.
  The output names what it couldn't read.
- Proposing a page for a manifest unit that has none. A subsystem gets a page once it has
  something to say (RULES.md); the remap may propose one, but survey doesn't.
- Whole-tree coverage: every source file no page covers. That is a finding of its own, and
  handoff's UNOWNED already asks it of changed files.
- A script that builds folder-form paths and names no map (`f"docs/{x}/{x}.md"`). It can't be
  told apart from one that handles both forms; review catches it.
- Refusing at the hook or the gate (`page-form-enforced`), and recording outcomes
  (`findings-record`).
- Daisy's own files. Its remap row 21 conflicts with step 5's docmap writes, as the givens show.
  Its owner meets that through this change, or by hand now.

## Touches
- `marketing/FEATURES.md` (main checkout only): rows "Old-contract holders" and "Page levels from
  evidence".
- `plugin/templates/jig/jig.py`:
  - `contract_holders`, `structure_maps`, `page_levels` and the import readers;
  - survey's two headings, `--levels`, its `--json` keys and its last line;
  - `page_shapes` and `deep_fix`;
  - `files_to_review` and `home_findings`;
  - argparse;
  - the comments at ~1515 and ~2286.
- `plugin/templates/jig/RULES.md`: Documentation (the definition, the body sections, the tree
  sentence, and one sentence on holders and levels), and the command list (`jig survey [--json]
  [--levels]`).
- `plugin/templates/jig/docs-page.md`.
- `plugin/skills/survey/SKILL.md`, `update/SKILL.md`, `redocument/SKILL.md` and
  `adopt/SKILL.md`.
- `tests/smoke.sh`: the `structure` section. `sec_update`'s old layouts carry a docs counter, so
  their review lists gain its line.
- `tests/redocument-fixture.sh`.

## Alternatives considered
- Update proposes removing a holder that predates adoption, as the report asks. Rejected: such a
  file holds more than the contract. Daisy's remap keeps 7 of `test_docs.py`'s 10 checks
  (ownership, seams, glossary, sizes, comments, docmap, paths), and when a file arrived says
  nothing about which checks are the contract's. Reason is [seen]: Daisy's `.jig/redocument.md`,
  row 1.
- Flag `## Now` / `## Rules` / `## Checks` strings in code. Rejected: a fixture that writes an
  old page checks nothing. Reason is [seen]: `tests/smoke.sh:3280`.
- Refuse in the hook while a holder stands. Rejected: doc-home findings are reported, never
  refused, and a hook can't tell which of a test file's checks are the contract's. Reason is
  [seen]: `docs-subsystems.md`, Alternatives.
- Survey folds or moves pages by level itself. Rejected: update never edits repo files, and a
  level is the owner's call where the evidence splits. Reason is [seen]: `update.md`, Out of
  scope.
- Leave levels to the remap's judgment, in skill text only. Rejected: Daisy's session did that,
  and a later pasted brief overrode a remap the owner approved. One function behind survey,
  update and redocument gives one answer. Reason is [seen]: the report, issue 2, and Daisy's
  rows 5–15.
- Imports in default survey. Rejected: they are the weakest evidence, they add to an already
  long run, and they belong where a level is decided (the remap, a `deep_subsystems` rationale).
  Reason is [seen]: the probe and the timings.
- A full import graph through language servers or parsers. Rejected: `jig.py` is one stdlib
  file. Reason is [seen]: AGENTS.md, Code.

## Decisions
- The owner, 2026-11-12, on the rejected removal: "conversion is acceptable". A holder is flagged and converted with the pages; update doesn't propose deleting it.
- One group. Both issues fail because survey's evidence is pages and the board, and both fixes
  read the repo's own structure-bearing files, through the same calls.
- General.
  - Issue 1: jig itself shipped every holder kind, and anyone who followed it before Nov 6 holds
    them. Nobody works against jig to hit this.
  - Issue 4: RULES.md defines a subsystem by its own files, while agents make a page per feature
    or screen, and today depth is the only judge. Own files is deterministic; maps and manifests
    are common (workspace packages, firmware components).
  - The report's one-repo piece, deleting files that predate adoption, is rejected above.
- Evidence, not verdicts. The one firm level is "owns no files", which RULES.md's definition
  settles, and even that lands only on a yes. "jig decides", the owner's word, is met as "jig
  proposes a level with evidence, and the owner approves it", as RULES.md already does for a
  deeper level.
- Imports are part B.3. On Daisy they separated nothing that own files didn't, so the owner may
  cut them without touching the rest.
- Each finding here has a kind for `findings-record`'s ids if that spec lands: `holder`, `level`,
  `map`. Neither spec waits for the other.
- This makes the call that `docs-subsystems` deferred, and widens `docs-page-contract`'s
  Migration. Pages are still not rewritten by update; their other holders are now listed.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
