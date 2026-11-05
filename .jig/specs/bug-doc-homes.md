# Bug: survey and update don't check where documents live

Source: Dave Seeman (owner) / 2026-11-05 (AdventureStudio): "Two AGENTS.md files exist in the repo … docs/AGENTS.md (526 lines) — a pre-jig planning artifact … It's a shadow ruleset that actively misleads. jig survey didn't catch it because any file under docs/ passes the 'at home' check unconditionally."
Source: Dave Seeman (owner) / 2026-11-05 (Maige-Lite): "maige-lite still has a systems/ folder in docs/, instead of folders for named systems and sub-systems. So /update apparently didn't catch that."
Source: Maige-Lite hubnode session local_25f7e824 / 2026-11-04 / Dave Seeman (staged as feedback-Maige-Lite-2026-11-04-agents-template-diff.md): "`jig update`'s 'AGENTS.md against the template' buries the template changes in expected drift … Nothing marks which is which. The hubnode read the Jobs block as missing and asked the owner to add it."
Owner, 2026-11-05: clean up, not just stop recreating. For each symptom, update (or survey) finds what it already left in repos and fixes it, or proposes the fix.

## Intent
Survey checks every Markdown file against the homes RULES.md defines, by shape and by kind. Update
proposes a fix for each file an old convention or a missed check left behind. jig writes no copy of
a convention into a file the repo owns, so update has nothing of jig's to diff in AGENTS.md.

## 1. Why
1. Why did survey pass docs/AGENTS.md and docs/systems/*.md, and update name neither? Survey's home test is `startswith("docs/")`. Update checks jig's own paths and a hand-kept list of two old files.
2. Why a prefix, when RULES.md gives a shape? The shape is prose. fab8888 changed it in RULES.md, the template and a description string only, so no code can compare a page with it.
3. Why does the old shape keep coming back, and why does update diff AGENTS.md whole? jig copied its conventions into files the repo owns (template lines, a seeded docs/README.md). Those freeze, and update can only diff them.

**Root:** the homes RULES.md defines exist only as prose, and partly as copies the repo owns. Survey
checks a prefix instead of them, and update checks none of them. That one root covers all three symptoms:
- #1 is the prefix;
- #3 is a copy that update can only diff;
- #2 is both: the prefix hides the pages, and a frozen copy keeps telling agents `docs/systems/`.

## 2. Givens
Plugin `jig.py` at cb6af2f, byte-identical to 0.6.0's. Survey was run in place, after its code was checked for writes. Both repos' `git status` and `.git/index` mtime were unchanged afterwards. Update ran only in `git clone --shared` copies in the scratchpad.
- `[seen]` In AdventureStudio, survey lists `legal/README.md` and `legal/Guild-…md` and nothing under `docs/`. That folder holds `AGENTS.md` (526 lines) and six other flat pre-jig docs (PRD, SPRINT_PLAN, …).
- `[seen]` Update's dry run there (layout 8) says nothing about `docs/`.
- `[seen]` `docs/AGENTS.md` is named by path in `README.md:106` and `docs/PRODUCT.md:10`. `inbound()` greps the bare name, so it counts every file that names `AGENTS.md` (10), the root's included.
- `[seen]` Maige-Lite has seven tracked pages in `docs/systems/`, each with Now, Rules and Checks. Four pages already sit at `docs/<x>/<x>.md`. `docs/systems/onboarding.md` is untracked, written today at 07:37, and its installed RULES.md says `docs/<system>/<system>.md`.
- `[seen]` Maige-Lite adopted jig on 10-28 (a0fa6d1), when RULES.md said `docs/systems/`. On 10-29, fab8888 changed RULES.md, the template line and `DOC_HOMES`' description string, and added no update row.
- `[seen]` Maige-Lite's `docs/README.md` is jig's pre-bce4fd1 seeded template. It differs in one line, update's own path rewrite. Seven of its 10 sentences are word for word in today's RULES.md, and it still says "under `docs/systems/`".
  - `AGENTS.md:36` sends agents there: "`docs/README.md` says how documentation is shaped". That is the eaec973–7bad67f template line.
  - bce4fd1's spec decided that a seeded `docs/README.md` "stays … `update` never edits those", and it added no review row.
- `[seen]` The template's docs line changed 4 times in 3 days. The restating block's heading changed too: `## Lanes` became `## Jobs`.
- `[seen]` Update's dry run in a Maige-Lite clone (its `jig.py` touched, so the run has an action) prints the 50-line diff. Line 36 is one `+` among them, and Repo files to review is empty.
- `[seen]` `cmd_update` prints its report only on a run with an action. The first run of any changed `jig.py` always has one.
- `[seen]` Four cached metarepo pointers name `maige-lite/docs/systems/ui.md`, and `.jig/para.json`'s `contract_paths` lists it.
- `[seen]` A probe of the check below, run over both repos' tracked files (scratchpad `probe_homes.py`):
  - AdventureStudio: `docs/AGENTS.md` as rules, named by README.md and docs/PRODUCT.md, plus six strays;
  - Maige-Lite: `docs/README.md` as a copy, named by AGENTS.md, plus seven pages, each `→ docs/<name>/<name>.md`;
  - no page that is at home is flagged.
- `[seen]` Smoke's `old()` seeds the old `docs/README.md` for layouts eaec973, 66a044c and 62c8d9f. Each of the three copies has 7 of its 10 sentences in today's RULES.md. The update section asserts that survey then finds nothing homeless.
- `[seen]` RULES.md tells a metarepo to list its pages as `docs/**/*.md` in `entry_files`.
- `[assumed]` AdventureStudio's init went ahead because survey showed no strays under `docs/`: the init skill's adopt gate reads survey. I didn't see that session, and the fix doesn't depend on it.

## 3. One layer up
- **Sibling with no problem:** `files_to_review` already proposes `docs/HARDWARE.md` → `docs/hardware/<board>.md` and removing the old skill template. Each was a row hand-written alongside its convention change. fab8888 and bce4fd1 changed conventions without a row. A check of the shape finds any old shape, with no row to remember.
- **Existing pattern:** `stale_references(plan)` lists every line naming a moved file or an emptied folder, and skips handoffs and jig's own files. A proposed move is a plan, so it fits as is.
- **Sibling bug:** `inbound()` counts the bare name, so every `README.md` and `AGENTS.md` shows the same inflated count (27 for each of Maige-Lite's READMEs).

## 4. Correction
Change what produced the symptoms: give the homes one checkable form, and stop shipping copies.
- **`doc_homes(root)`, shared by survey and update.** It covers tracked `.md` files outside tool dirs and `not_docs`.
  - **At home:**
    - root `AGENTS.md`, `CLAUDE.md` and `README.md`;
    - under `docs/`, a page named for its folder (`docs/…/<x>/<x>.md`);
    - `docs/hardware/<board>.md`, and anything below `docs/hardware/*/`;
    - in a metarepo, whatever `entry_files` matches.
  - **Any other file is a finding with one kind:**
    - `rules`: an `AGENTS.md`, `CLAUDE.md` or `GEMINI.md` anywhere but root.
    - `copy`: three or more of its sentences are word for word in `.jig/RULES.md` (the one beside `jig.py`).
    - `page`: under `docs/`, with Now, Rules and Checks headings. Its destination is under the nearest ancestor folder that has its own page (`docs/c/d.md` → `docs/c/d/d.md`), or else `docs/<stem>/<stem>.md`. If the destination is taken, the page is folded into it.
    - `stray`: anything else.
  - **The files that name it**: by path, or by bare name when no other tracked file has that name. Handoffs and jig's own files are excluded. Survey's `inbound` becomes this count.
- **Survey** prints rules files, copies and pages, each under its own heading with its fix. Strays stay in the linked/cold lists. `--json` puts `kind`, `to` and `naming` on each `homeless` entry.
- **Update** adds the `rules`, `copy` and `page` findings to Repo files to review. Strays get one line: "N documents have no home: `/jig:survey`". `--apply` never touches any of them.
  - **rules**: fold what still binds into AGENTS.md or a page's Rules, repoint the files named, delete it.
  - **copy**: RULES.md is its home and update keeps that current. Delete it, and point what names it at RULES.md.
  - **page**, grouped by folder: each `git mv` with its destination, then these, all named in the proposal:
    - the docmap keys and `contract_paths` that name it;
    - `stale_references` over the moves;
    - in a pararepo, each cached metarepo pointer into it. The move commit carries a `BUFFER.md` row (P2's rename rule), and the next `jig release` proposes it.
- **The template restates nothing RULES.md holds.**
  - The Jobs block shrinks to its Rulebook/Roles line, which moves under Workflow.
  - The docs line, the homes line and the Firmware board-page line point at `.jig/RULES.md` (Documentation) and name no paths. RULES.md (Documentation) lists every home survey checks.
- **Update's AGENTS.md diff goes.** Repo files to review gets an AGENTS.md line in two cases:
  - it doesn't name `.jig/RULES.md`: propose the template's Rulebook line;
  - it doesn't name a `.jig/scripts/<x>` that the template's Commands section names and the repo has: propose that line.

## Done when
A new section `homes` in `tests/smoke.sh`, listed in `UNITS`. Its repos are built from today's templates with `JIG_CONFIG` and `XDG_CONFIG_HOME` set outside them.
- [ ] **Rules file (#1).**
  - Setup: `docs/AGENTS.md`, linked from `README.md`. `docs/guide.md` says "see AGENTS.md", which is ambiguous. `docs/notes.md` has no page headings.
  - Survey `--json` has `docs/AGENTS.md` with `kind == "rules"` and `naming == ["README.md"]`, and `docs/notes.md` as a `stray`, so `docs/` no longer passes a file unconditionally.
  - Survey's text prints `docs/AGENTS.md` under its own heading. `snap` is the same before and after survey.
- [ ] **Its cleanup.** The dry run of a changed `jig.py` lists `docs/AGENTS.md` under Repo files to review with `README.md:<line>`, and `--apply` leaves both files alone. After the proposal is followed (link repointed, file deleted), survey lists neither file.
- [ ] **Pages (#2).**
  - Setup: `docs/systems/{a,b}.md` and `docs/c/d.md` have Now, Rules and Checks. `docs/c/c.md` exists, docmap names `docs/systems/a.md`, and `AGENTS.md` names `docs/systems/`.
  - Survey gives `to` as `docs/a/a.md`, `docs/b/b.md` and `docs/c/d/d.md`, and doesn't list `docs/c/c.md`.
  - The dry run lists the three moves, the docmap key, and the `AGENTS.md` line naming the folder.
  - Once those are carried out, survey lists none of them.
  - A `docs/systems/c.md` beside `docs/c/c.md` is proposed as a fold, not a move.
- [ ] **Pages in a pararepo.** Built as `sync_buffer` builds one; it may live in that section. A cached pointer `app/docs/systems/a.md § Rules` and `contract_paths` naming the page put the cache file, `BUFFER.md` and `.jig/para.json` in that page's proposal.
- [ ] **Copy (#3's leftover).** In the `update` section, `old` eaec973 dot after `--apply`:
  - survey lists `docs/README.md` as a `copy`;
  - the dry run proposes deleting it, and names the `AGENTS.md` line that points at it.
  - The existing "survey finds no homeless files" assertion becomes: exactly `docs/README.md`, a copy, for eaec973, 66a044c and 62c8d9f. `old()`'s jig2 stand-in `docs/README.md` is dropped, since `docs/alpha/alpha.md` already puts `docs/` at root.
- [ ] **Template diff (#3).**
  - Setup: a repo from today's template with TODOs filled, Firmware and Jobs cut, no `setup:` line, and `.jig/scripts/setup.sh` present.
  - The dry run of a changed `jig.py` doesn't print `against the template` or any of the filled text. Its only AGENTS.md line proposes the template's `setup:` line.
  - With that line restored, no AGENTS.md line prints. With the Rulebook line removed, the Rulebook line is proposed.
  - The existing assertion "the dry run shows AGENTS.md against the template" is replaced by these.
- [ ] `grep -nE 'docs/<system>|docs/hardware/|^## (Jobs|Lanes)' plugin/templates/AGENTS.md` prints nothing.
- [ ] `grep` finds in RULES.md (Documentation) the homes list and the sentence that survey checks each Markdown file against it.
- [ ] Read-only, in each reporting repo, `python3 <jig>/plugin/templates/jig/jig.py survey` lists:
  - AdventureStudio: `docs/AGENTS.md` as rules, with 2 files naming it;
  - Maige-Lite: `docs/README.md` as a copy, and the seven `docs/systems/` pages with destinations.
- [ ] `bash tests/smoke.sh`, `claude plugin validate ./plugin` and `.jig/scripts/check.sh` pass, with output shown.

## Out of scope
- **Paraphrased restatements already in a repo's AGENTS.md**, such as an old Jobs or Lanes block. These need judgment, so the update skill reads AGENTS.md against RULES.md and offers to swap each for the pointer. That isn't fixture-tested. Matching them by shipped text is the history-tracking the owner rejected.
- **Classifying strays** (AdventureStudio's PRD, SPRINT_PLAN, …): `/jig:adopt` step 2, as today.
- **P2's contract-path rename hole** (`changed_paths`). Tracked in `bug-numbered-pointers.md`'s Out of scope.
- **A commit hook that refuses a new stray.** Strays are survey's to report, and a hook would block every pre-jig doc on its next edit.
- **Untracked files.** Survey reads the index, so a page shows once it is committed.

## Touches
- `marketing/FEATURES.md` (gitignored), first. Rows:
  - "Docs shape (`.jig/RULES.md` § Documentation)";
  - "`survey`": kinds, and counting by path;
  - both "`update`" rows: the home findings and the AGENTS.md lines; the diff goes;
  - "`AGENTS.md` ≤40 lines": pointers, not restatements.
- `plugin/templates/jig/jig.py`:
  - `doc_homes` (new);
  - `inbound` and `cmd_survey`;
  - `files_to_review` and `cmd_update`'s `report()`: the findings and the AGENTS.md lines; the template diff is removed.
- `plugin/templates/jig/RULES.md`: Documentation.
- `plugin/templates/AGENTS.md`: four lines.
- `plugin/skills/survey/SKILL.md`: one bullet.
- `plugin/skills/update/SKILL.md`: one paragraph. Carry out each finding on a yes, and ask whether a moved page is a subsystem to nest. Never propose adding a line that restates RULES.md.
- `tests/smoke.sh`: `homes` and `UNITS`, the two `update` assertions, and `old()`'s jig2 stand-in.

Two jobs:
1. `doc-homes`: everything but the template, the AGENTS.md lines and their tests.
2. `agents-template`: those, after job 1.

Both edit `report()`, and so does `bug-numbered-pointers`. Their hunks are separate blocks, so merge in any order.

## Alternatives considered
- **A jig copy of the template, diffed old→new, and hashes of shipped lines.** Rejected by the owner ("doesn't solve the problem well"). It would also need every variant ever shipped (`## Lanes`, `## Jobs`, four docs lines). Reason is [seen].
- **A generated jig block in AGENTS.md, like the pararepo header.** Rejected because the template's lines are defaults a repo may change (adopt 3b; Maige-Lite reworded its Code lines). Inserting the block would also duplicate lines the repo already has. Reason is [seen].
- **A `files_to_review` row per old convention** (`docs/systems/`, the seeded README, the Jobs block). This is the existing pattern, and it's rejected as the whole fix: fab8888 and bce4fd1 show that the row gets forgotten. Reason is [seen].
- **`--apply` makes the page moves, as it does for a root HARDWARE.md.** Rejected: the pages are the repo's. A move also needs docmap, `contract_paths`, metarepo rows and a nesting call, all the owner's. Reason is [seen].
- **Keep the diff and add one skill line** (the report's fix 4 alone). Rejected because the restatements still freeze, and the reader still has to find 1 real line among 50. Reason is [seen].
- **Count inbound by path only.** Rejected: a uniquely named doc cited by bare name would read as cold, and survey would advise dropping a cited file. Reason is [assumed].

## Decisions
- **What a page is.** It has all three of Now, Rules and Checks. A doc without them is a stray, and the move proposal is only for pages.
- **When update shows the findings.** Only on a run with an action, as today, which includes the first run of every changed `jig.py`. Survey is the standing check, so a second `--apply` still reads "up to date".
- **Pointers into a moved page.** The proposal names each one and the `BUFFER.md` row. It doesn't rely on P2: today P2 lets a `§1`-only page move through. Once `bug-numbered-pointers` lands, P2 refuses such a move without the row, and its update cleanup catches one already made.
- **The staged report.** It resolves into this spec: its fixes 3 and 4 are adopted here, and fixes 1 and 2 (record the template) are dropped by the owner.
- **No STAMP bump.** This adds no LAYOUT row, config default or STEP.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
