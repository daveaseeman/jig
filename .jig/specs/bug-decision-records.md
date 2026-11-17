# Bug: a folder of decision records never reaches the log

Source: Daisy hubnode session / 2026-11-16 / the owner (Dave Seeman) (staged as feedback-Daisy-2026-11-16-decision-record-folders.md): "a folder of one-file records isn't recognized as a decision register"
Source: Daisy hubnode session / 2026-11-16 / the owner (Dave Seeman) (staged as feedback-Daisy-2026-11-16-decision-record-folders.md): "`--merge-log` refuses once the log holds any entry"

The owner, 2026-11-16: "they just need to move docs/decisions to .jig/decisions, why didn't
update catch that?"

## Intent
A folder of decision records is a decision register. That is one Markdown file per decision,
the ADR shape adr-tools and MADR write. `jig init` and `jig update` find it, and survey says
where it goes. `jig update --merge-log` turns each record into a log entry. When the log already
holds entries, the records are added after them, so a repo that adopted jig before this fix can
still merge.

## 1. Why
**Issue 1: the folder isn't found.**
1. Why didn't update offer to merge `docs/decisions/`? `log_sources` lists CHANGELOG.md and `old_registers`, and `old_registers` found nothing. [seen]
2. Why nothing? It takes only a file named `DECISIONS.md` (or a metarepo entry file) holding `| D-12 |` rows. A record folder is many files, and its index rows are links. [seen]
3. Why only that shape? The merge (d897b21) was built for the register it replaced. Survey's ADR line predates the log and points ADRs at `.jig/specs/`. Root. [seen]

**Issue 2: the merge refuses a log in use.**
1. Why does `--merge-log` refuse Daisy now? Its log isn't the seed: jobs have written entries since update wrote it on 2026-11-12. [seen]
2. Why does that stop it? `log_sources` and `cmd_merge_log` merge only into an absent or seed log. [seen]
3. Why only then? Init writes no log beside a source it knows, so the merge assumed it ran first. A source jig learns later finds the log in use. Root. [seen]

## 2. Givens
- [seen] The code here is the report's: `git hash-object plugin/templates/jig/jig.py` is
  f0005adc5fe4, the same as Daisy's `.jig/jig.py`.
- [seen] Scratch repo A, Daisy's form. `docs/decisions/` holds `0000-template.md`, then
  `0001`–`0003` (`# 0001. Title`, `- **Date:**`, `- **Status:**`, then sections), and a
  `README.md` index. `jig init` wrote the seed log. `survey --json` lists all five as `stray`.
  `jig update` says nothing about them. `update --merge-log` says "no CHANGELOG.md or decision
  register to merge".
- [seen] Scratch repo C held two layouts and failed the same way, with six strays and nothing to
  merge:
  - adr-tools' form in `doc/adr/`: `# 2. Use shell`, a `Date:` line, a `## Status` section, and
    "Superceded by [3. …](0003-….md)";
  - MADR's form in `docs/decisions/`: front matter `status:`, `date:` and `decision-makers:`, a
    title with no number, and `adr-template.md` beside the records.

  Survey's coordination line found `docs/decisions` but not `doc/adr`, and mapped it to
  "`.jig/specs/` decisions + `.jig/ledgers/WORKAROUNDS.md`".
- [seen] The layouts, from their own sources:
  - adr-tools (its `src/template.md`, `src/adr-new` and `doc/adr/0002-…`): files named with
    `printf %04d` then the slug; titles `# N. Title` with no padding; a `Date:` line; a
    `## Status` section; and links "Superceded by" and "Supercedes", spelled that way.
  - MADR (its README and template): `docs/decisions/nnnn-title.md`, and front matter that may
    be left out: `status` (proposed | rejected | accepted | deprecated | superseded by ADR-0123),
    `date` and `decision-makers`. Titles carry no number, and `adr-template.md` sits in the
    folder.

  All of them share a folder, a number and a slug in each file name, and a status and a date in
  each record, with sections after. They differ in where the status sits and in whether the
  title has a number.
- [seen] A snapshot of Daisy's trunk, from `git --no-optional-locks archive`, committed in
  scratch and run with its own `.jig/jig.py`. `survey --json` lists 85 homeless: 84 under
  `docs/decisions/`, plus `docs/README.md`. `update --merge-log` prints ".jig/decisions.md
  exists: nothing to merge". The reporter's counts hold.
- [seen] Daisy's folder holds 82 records (0001 to 0083, with no 0069), `0000-template.md`, and a
  `README.md` index of 115 lines, 33 of them not rows.
  - Statuses: mostly `in force`, some followed by ", amended by N" and prose; `superseded by N`
    (five records); and `ended (…)` (0025).
  - Its log runs from D-001 to past D-030, all added since 2026-11-15.
  - Its board has `reserve.record` over `docs/decisions/README.md`.
- [seen] Repo A, with D-001 committed in the log and a two-row `DECISIONS.md` added after it:
  `update` lists nothing, and `--merge-log` prints "exists: nothing to merge". The register
  shape has Issue 2 too, but only when it is added after the log.
- [seen] `jig init` (jig.py ~813) and update's log step (~9614) write no log beside a source that
  `old_log_files` finds.
- [seen] Survey calls a plain repo's `DECISIONS.md` a stray too. RULES.md's Homes lists a root
  `CHANGELOG.md` "until `jig update` merges it" and a metarepo's registers, but not a plain
  repo's register.
- [seen] M2 lets a converted entry go without a `Touches:` line only when the old log had no
  entries and a register's rows went in the same commit (`touches_problems`, `migrating_log`,
  `migrated_ids`). An entry appended to a log in use without `Touches:` is refused today.
- [seen] The boundary hook refuses an added log line that names `.jig/specs/`,
  `.jig/handoffs/`, `.jig/roadmap.md` or a root document (`boundary_rules`). Daisy's records
  0068 and 0070 name `.jig/specs/`, and update's sweep lists them.
- [seen] Daisy's pages cite records two ways: by path, such as
  `docs/decisions/0021-ci-by-hand.md` (5 pages), and as "record 0033" (`docs/core.md`).
  Handoffs cite "record 0070". No page cites a D-id, but handoffs do.
- [seen] RULES.md (Decision log, Ids): numbering starts above every id the log has ever named,
  so no id is given twice.
- [assumed] The reporter's "pages already cite D-001 to D-009" doesn't hold for pages in Daisy's
  trunk today, though it does for handoffs [seen]. The case against renumbering the log rests
  on the Ids rule instead.
- [assumed] log4brains' date-named files (`YYYYMMDD-slug.md`) fit the same rule as numbered
  names. Not checked, and the fix doesn't depend on it.

## 3. One layer up
- A root `CHANGELOG.md` and a `DECISIONS.md` are found by name, and each is one file. Neither
  path reads a folder. `DECISIONS.md` has Issue 2 only when it is added after the log. jig
  always found it, so jig never stranded one. [seen]
- Survey's `COORDINATION` already names ADR folders, by four names. It maps them to a home
  RULES.md no longer gives (`.jig/specs/`), and the adopt skill's table says the same. Both
  predate the log (eaec973). [seen]
- Two patterns already solve parts of this shape. [seen]
  - `--glossary` moves a document into jig's home for it and rewrites every pointer to it in the
    same change, leaving history as written. It also lists the lines the hook would refuse, for
    the session to edit.
  - `jig merge` numbers entries above the highest id ever named.

  A record folder's merge needs both.

## 4. Workaround or correction
A correction in jig: read the folder shape as a register, and let the merge append to a log in
use. Converting by hand would be repeated in every ADR repo and would lose the citation rewrite.

## General?
Picture any repo that adopts jig with ADRs in adr-tools' or MADR's layout. RULES.md gives its
decisions one home, the log, and says update merges "the register". Today that repo gets:
- strays with nowhere to go;
- a survey line pointing ADRs at specs;
- no merge.

Fixing this helps every such repo, whether plain, metarepo or pararepo. It asks for nothing
beyond what RULES.md promises, and no one has to work against jig to hit it. Issue 2 is general
too: without its fix, every repo that adopted jig before this fix and has written one entry
stays stranded.

## Design
1. **A record folder** is a folder outside the tool folders that directly holds two or more
   tracked record files.
   - A record file is named `<n>-<slug>.md`, where `<n>` is digits, optionally after `adr` or
     `ADR` and a hyphen, and the name doesn't contain `template`.
   - A record file has a status: a front-matter `status:` key, a `Status:` line or list item
     (bold or not), or the first line under a `## Status` heading.
   - The folder's other Markdown files belong to the folder but aren't records: an index
     (`README.md`, `index.md`) and anything else, such as a template.

   `old_log_files` and `log_sources` list the folder as `<folder>/: a folder of decision
   records, N records`. So init and update write no seed log beside it, and update lists it
   under Repo files to review, naming `--merge-log`.

   While the folder holds records, survey counts its files as at home, as a root CHANGELOG.md
   is until merged (RULES.md, Homes). A plain repo's `DECISIONS.md` with rows is at home too.
   Survey's coordination line names each record folder and maps it to `.jig/decisions.md`
   through `jig update --merge-log`, and the adopt skill's ADRs row says the same.
2. **Converting** (`--merge-log`): one entry per record, in number order.
   - **Id**: the next number above the highest the log has ever named, as `jig merge` numbers
     them. An empty log starts at 1, so records 0001 to 0003 become D-001 to D-003.
   - **Title**: the record's heading without its number (`# 2. Use shell`, `# 0001. Use A`,
     `# ADR-0001: Use A`).
   - **Status** (only the status phrase is read; any text after it on its line, such as
     `in force, amended by 0033. Built by …`, is kept as a body line):

     | Record's status | Becomes |
     |---|---|
     | `accepted`, `in force`, `approved` | `Accepted (<who>, <date>).` |
     | `proposed`, `draft` | `Proposed (<date>).` under `## Open` |
     | `open` | `Open (<date>).` under `## Open` |
     | `superseded by N` (or `superceded by N`) | Accepted, and N's entry ends `Supersedes <id>.` |
     | `rejected`, `deprecated` | left out and listed; git keeps the file |
     | anything else | refused before anything is written, naming the record and its words |
   - **Who**: the record's `decision-makers` or `Deciders` field if it has one, else
     `not recorded`.
   - **Date**: its `date` or `Date` field. A record with none takes the day git added the file,
     and the run lists it to check.
   - **Body**: the rest of the record, in order:
     - fields jig doesn't map, as `Key: value` lines;
     - each heading as a bold label paragraph (`**Context.**`), since any `##` or `###` line
       ends an entry's block;
     - relative links rebased to the log's folder;
     - a last line naming the record it was (`Record 0001 before this log.`).
   - **Placement**: accepted entries go after `## Unreleased`'s last entry, before its change
     lines. Open and proposed entries go after `## Open`'s last entry.
   - **Refusals**: any of these is refused before anything is written, naming the file:
     - two records with one number;
     - a `superseded by` that names no record, or one that is left out;
     - a numbered file with no status.
3. **Into a log in use.** When the log already holds entries, record folders still merge,
   appended as above. The existing entries and change lines stay byte for byte, and the dry run
   says "appends D-011 to D-013". A `CHANGELOG.md` or a register still merges only into an empty
   log. Instead of "nothing to merge", the run names each one it leaves and why.
4. **Citations.** In the same change, each tracked file's citation of a record is rewritten to
   the record's new id:
   - a path or link to a record file;
   - `record N`, `ADR N` or `ADR-N`, in any case, padded or not, where N is a record's number.

   History is left as written: `.jig/handoffs/`, fenced code, and released sections. As
   `--glossary` does, the dry run lists:
   - each line it rewrites;
   - each citation it can't rewrite, such as one of a record left out;
   - each file still naming the folder, to repoint;
   - each line of the new entries the hook would refuse (a spec path, a root document), left for
     the session to edit before committing.
5. **Removing.** The records are removed, and so are the index rows that link to them. The index
   is removed when nothing else is left in it. Whatever else remains, such as the template or
   the index's prose, is kept and listed, as a register's leftovers are. On trunk, the board
   changes too: `append_files` or a `reserve` counter that names the index or a record counts
   the log instead.
6. **The hook.** The commit of `--apply --merge-log`'s output passes unedited. M2's allowance for
   converted entries covers entries whose records the same commit removes, whether the log was
   empty or in use. An entry added later without `Touches:` is still refused. In a metarepo the
   merge is a job, as now.
7. **RULES.md** changes in three places:
   - Homes: a register, a `DECISIONS.md` or a folder of decision records, is at home until
     merged.
   - Decision log, Before the log: the folder, what a record becomes, appending to a log in
     use, and citations.
   - Commands.

   The update skill's merge paragraph names a folder of records.

## Done when
- [ ] Smoke `merge_log`, fixture R. `docs/decisions/` holds, in Daisy's form:
  - `0000-template.md`;
  - `0001-a.md` (in force), `0002-b.md` (superseded by 0003) and `0003-c.md`;
  - a `README.md` index whose three rows link to the records.

  Outside the folder, a page names `record 0001` and `docs/decisions/0002-b.md`, and a handoff
  names `record 0001`.

  In R, `jig init` writes no log and names the folder, and `jig update` lists
  `docs/decisions/: a folder of decision records, 3 records`. This FAILs at v0.14.0, where init
  writes the seed log and update lists nothing [seen].
- [ ] Smoke, in R: `jig survey --json` lists none of the folder's five files as homeless while
  the folder holds records, and its coordination line maps the folder to `.jig/decisions.md`.
  A plain repo's `DECISIONS.md` with rows isn't homeless either. This FAILs at v0.14.0, where
  survey lists five strays and maps the folder to `.jig/specs/` [seen].
- [ ] Smoke, in R: `--apply --merge-log` writes:
  - D-001 to D-003 in order, with titles that have no number;
  - the status line `Accepted (not recorded, <date>).`, with D-003's ending
    `Supersedes D-002.`.

  `log_entries` reads three entries, each block holding its `**Context.**` paragraph. After
  the run:
  - the records and the index are gone, and the template is kept and listed;
  - the page names D-001 and D-002, and the handoff still says `record 0001`;
  - the staged result commits unedited through the hooks.
- [ ] Smoke: adr-tools' form in `doc/adr/` (a `## Status` section with "Superceded by
  [3. …](0003-….md)") and MADR's form (front matter, `# Title`, `adr-template.md`) each list as
  a record folder and convert. MADR's entries take their who from `decision-makers`. A guide
  folder of `docs/guide/01-intro.md` and `02-setup.md` with no status is not a record folder.
- [ ] Smoke, Issue 2: R with D-001 and D-002 committed in the log before the folder is added.
  - The dry run lists the folder and says `appends D-003 to D-005`.
  - `--apply` writes them after D-002, leaves D-001 and D-002 byte for byte, and its output
    commits unedited.
  - A second run prints "nothing to merge".

  This FAILs at v0.14.0, which says "exists: nothing to merge" [seen].
- [ ] Smoke: each of these is refused before anything is written, naming the file:
  - a record whose status is `ended`;
  - a `superseded by 0009` when there is no 0009;
  - a numbered file with no status.

  A record that names `.jig/specs/x.md` is listed as a line the hook would refuse.
- [ ] The reported symptom is gone. On a snapshot of Daisy's trunk
  (`git --no-optional-locks archive`, committed in a scratch repo, run with this jig.py):
  - `jig survey --json` lists nothing under `docs/decisions/` as homeless;
  - `jig update` lists `docs/decisions/: a folder of decision records, 82 records`;
  - the `--merge-log` dry run names the ids it would append after the log's highest, and
    refuses 0025's `ended`, naming it.
- [ ] `.jig/scripts/check.sh` exits 0, `bash tests/smoke.sh merge_log decisions homes update`
  passes, `claude plugin validate ./plugin` passes, and `grep -rnE 'Daisy|daisy' plugin` finds
  nothing. The full suite runs once, at the check step.

## Out of scope
- A `CHANGELOG.md` or a register beside a log in use. These still merge only into an empty log:
  a register's ids are in the log's own form (D-001 in both), so renumbering one makes every
  citation of it ambiguous. jig has always found both by name, so none was stranded before
  its log began. The run names them (Design 3).
- Registers in other shapes, such as numeric ids, or an index table with no records behind it.
- Deciding whether a converted record is project or product. Update's sweep lists candidates
  after the merge, as it does for register rows, and lists converted entries to backfill
  `Touches:`, as now.
- An open job that writes records in the folder. The hubnode runs the merge when no such job is
  open; a later sync shows any conflict.
- A pararepo's citations of a metarepo's record paths. `bug-sync-moved-pages` names them at
  the pin bump.
- The `jig migrate-log` rename (spec `split-merge-log`). Whichever of the two lands second does
  the renaming.

## Alternatives considered
- Read the index (`README.md`) as a register through its linked rows — rejected because the
  index holds only titles, dates and statuses: the decisions' text lives in the records, and
  MADR keeps no index at all — this reason is [seen] (Daisy's README and records; MADR's
  README).
- Find the folder by name, using survey's list (`docs/adr`, `docs/decisions`, `adr`,
  `decisions`) — rejected because adr-tools' default `doc/adr` isn't on it, and a name says
  nothing about what the folder holds — this reason is [seen] (repo C's coordination line).
- Require a `# NNNN.` title, as the report proposes — rejected because MADR's titles have no
  number and adr-tools' number has no padding (`# 2.`) — this reason is [seen] (their
  templates, and adr-tools' own records).
- Leave it to `/jig:redocument` — rejected because records aren't pages and a remap has no row
  for decisions — this reason is [seen] (Daisy's remap, row 22: `docs/decisions/**`, "not in
  this run").
- Renumber the log's entries after the records, so the records keep their numbers — rejected
  because RULES.md never gives an id twice, and handoffs already cite the log's ids — this
  reason is [seen] (RULES.md, Ids; Daisy's handoffs).
- A workaround in Daisy: move its entries aside, restore the seed log, merge, renumber —
  rejected for the same reason, and because every such repo would repeat it — this reason is
  [seen].
- Also append a register and a CHANGELOG.md to a log in use — rejected because their ids are in
  the log's own form, so renumbering is ambiguous in every citation, and jig never stranded
  them — this reason is [seen] (`old_registers` finds them by name; init writes no log beside
  them).
- Keep survey mapping ADRs to `.jig/specs/` — rejected because RULES.md's Homes gives the log to
  decisions that outlive their spec, and that line predates the log (eaec973) — this reason is
  [seen].

## Decisions
- Interpreted: `in force` and `approved` read as accepted, alongside the standard ADR words.
  Refusing them would make the reporting repo rewrite 82 status lines. Refusing any other word,
  such as `ended`, keeps jig from guessing. This is a question for the owner.
- Interpreted: a deprecated record is left out, like a rejected one, since the log shows what
  holds now.
- Interpreted: converted records take the next ids, never their own numbers. So one rule serves
  an empty log and a log in use, and no id is given twice.
- Interpreted: each entry ends with a line naming the record it was, so a citation left in
  history (a handoff's "record 0070") can be followed.

## Touches
- `plugin/templates/jig/jig.py`:
  - `old_registers`, `old_log_files` and `log_sources`;
  - a record-folder reader beside `merged_log`;
  - `cmd_merge_log` and `board_rewrite`;
  - `at_home` and `doc_homes`;
  - `COORDINATION`;
  - the hook: `migrating_log`, `merged_files_at`, `migrated_ids`, `migrated_here` and
    `touches_problems`.
- `plugin/templates/jig/RULES.md`: Documentation (Homes), Decision log (Before the log), and
  Commands.
- `plugin/skills/update/SKILL.md`: the merge paragraph.
- `plugin/skills/adopt/SKILL.md`: the ADRs row.
- `tests/smoke.sh`: `merge_log` and `homes`.
- `marketing/FEATURES.md`, which is gitignored and in the main checkout: the Decision log row's
  migration sentence names a folder of decision records.
- The owner, 2026-11-17: "All are approved now": `in force` and `approved` count as accepted, beside the standard ADR words; any other status word is refused, naming the record.
- Kept separate from bug-process-in-pages: different code (one merges decision records into the log, the other sets what pages hold and where process goes), sharing jig.py, RULES.md and smoke.sh. The owner, 2026-11-17: "All are approved now".

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
recheck: tier 2, effort 2
check: tier 3, effort 4
