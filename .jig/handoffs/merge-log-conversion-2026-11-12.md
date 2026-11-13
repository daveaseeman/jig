# Handoff: merge-log-conversion

Commit: 847abdee43da3b3b4cb16368dbabccb9dc30010a
Date: 2026-11-12
Spec: .jig/specs/bug-merge-log-conversion.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
`jig update --apply --merge-log` writes what it says it writes (all in `jig.py`):
- The kept register holds only what had no home. `as_written()` writes each paragraph's own lines, and `parse_register()` reads every table on its own. A decision table's header and separator are known by the decision row under them, and each row is read against its own table's header. A note's own table comes back whole.
- A superseded row's who and date come from the register's git history, from the newest revision where the row was accepted (`accepted_before`, `date_superseded`). Where history can't say, the run prints a line naming the id. A pararepo's sync dates the old side the same way, so those rows don't read as changed.
- Bare change lines in Unreleased and release sections get `### Changed` above them (`grouped()`).
- A guard: a register row that comes out as neither an entry nor a named rejected or struck row refuses the run, naming it.
- `plugin/skills/update/SKILL.md`: the run's output list includes superseded rows git couldn't date.

## Done-when evidence
Smoke section `merge_log` (`bash tests/smoke.sh merge_log`), all PASS. At 644c67b every case failed against trunk's `jig.py`.
- Heading, preamble, table and note: "the kept register has its heading, preamble and note, and no line of the decision table": PASS
- Fix fires, kept lines: "the kept register's lines are the old ones less the decision table, in order, a note's own table kept whole": PASS
- Symptom gone in a metarepo job: "in a metarepo job, the run's output commits unedited: no M3, no entry asked for its pages": PASS
- Changelog preamble: "the changelog preamble keeps both paragraphs and drops the old seed line": PASS
- `accepted (Ann)` row then superseded: "a superseded row takes its who and date from the register's history" (`Accepted (Bo, 2026-01-01).`): PASS
- Fix fires, one commit: "a row superseded in its only commit converts as not recorded, and the run names it": PASS
- Symptom gone, not recorded: "no converted entry reads not recorded without the run naming it": PASS
- No change line in an entry block: "no entry's block holds a change line": PASS
- Fix fires, group headings: "bare change lines get ### Changed above them, in Unreleased and in a release": PASS
- Symptom gone, later removal: "a later job removes the superseded D-002 … by its heading and status line" and "removing the release's change lines with it is refused as frozen": PASS
- `bash tests/smoke.sh`: rc=0, 1058 PASS, 0 FAIL, at 0b78b29 (847abde adds only DEFERRED rows). `claude plugin validate ./plugin`: "✔ Validation passed".
- `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin tests`: only `tests/smoke.sh:1563`, the existing check that greps for these names. Nothing new.

## Review
The hubnode ran it at tier 2, effort 2, over four rounds plus a ledger-only re-record at 847abde.
- Round 1 (644c67b → 034974f):
  - Fixed, blocking: superseded rows were dated from proposed or open revisions; now accepted only.
  - Fixed, blocking: a second table in a note lost its separator.
  - Fixed, should-fix: a pararepo's sync reported history-dated rows as changed.
  - Fixed, optional: `### Changed` landed under non-release `## ` sections.
  - Deferred, optional: the history walk.
- Round 2 (→ 57c50a7):
  - Fixed: a decision table with another header, or headed `No.`, left its header behind.
  - Fixed: the spec's correction 2 said "not superseded"; it now says "accepted".
  - C, from branch-log-old-side's fixture `ml`, where both change lines landed under v0.1.0: not a converter bug. That fixture appends lines with `printf >> CHANGELOG.md`, so they land at the end of the file, under the bottom section (v0.1.0), and `jig release` puts v0.2.0's heading under Unreleased, leaving it empty. The converter copies sections as they are. A smoke case shows a two-release changelog keeping each release's line in its own section.
- Round 3 (→ 397681f): fixed, each row is read against its own table's header (reordered columns, an extra column's label).
- Round 4 (→ 0b78b29):
  - Fixed: a headerless register dropped its first row.
  - Fixed: a table whose first row is no decision fell back to the file's first header.
  - Fixed, optional: nearest decision header above.
  - Added a guard against any lost row, with a stubbed smoke case.
- Deferred, four rows in `.jig/ledgers/DEFERRED.md` (847abde):
  - should-fix: a headerless table borrowing a differently ordered header.
  - optional: the guard counts presence, not count.
  - optional: a decision row inside a note's table.
  - optional: the history walk.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — add to docmap (a new page starts from .jig/docs-page.md), or no page needed because jig.py is the product's code, and no docs page covers it (the spec's Touches, `reading-list`); RULES.md already groups change lines, and the update skill's clause is updated in this change

## Shared files changed
- `plugin/templates/jig/jig.py`: the converter's corrections (`as_written`, `parse_register`, `accepted_before`, `date_superseded`, `grouped`, `merged_log`, `cmd_merge_log`), and `terms_changed` so a sync dates superseded rows the same way.
- `tests/smoke.sh`: a new section, `sec_merge_log`, appended before `UNITS`, and `merge_log` added to `UNITS`. Helpers `mlreg`, `mlchangelog`, `nocl`.
- `plugin/skills/update/SKILL.md`: one clause in the list of what `--merge-log` prints.
- `.jig/specs/bug-merge-log-conversion.md`: correction 2 reworded to "was accepted", as the review asked.
- `.jig/ledgers/DEFERRED.md`: four rows.

## Test by hand
In a scratch repo with a `DECISIONS.md` (a heading, a preamble, a table, a note under it), commit a row as `accepted (Ann)`, then change it to `superseded by D-00N`. Run `python3 <plugin>/templates/jig/jig.py update --merge-log`.
- The dry run shows the entry as `Accepted (Ann, <first date>).`.
- `--apply --merge-log` leaves the kept `DECISIONS.md` with no decision-table line.
- The staged result commits without edits.

## Left
Nothing on this spec. The four DEFERRED rows above are for a later job.
