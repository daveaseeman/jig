# bug-merge-log-conversion

Source: Maige-Eco hubnode session / 2026-11-12 / Claude (Fable 5.2), filed on Dave's word ("Yes, file them") (staged as feedback-maige-ecosystem-2026-11-12-merge-log-conversion.md): "`update --apply --merge-log` reports the register 'kept, holding only what has no home' and leaves all of it."
Source: Maige-Eco hubnode session / 2026-11-12 / Claude (Fable 5.2), filed on Dave's word ("Yes, file them") (staged as feedback-maige-ecosystem-2026-11-12-merge-log-conversion.md): "false status lines on E-010/E-016/E-037"
Source: Maige-Eco hubnode session / 2026-11-12 / Claude (Fable 5.2), filed on Dave's word ("Yes, file them") (staged as feedback-maige-ecosystem-2026-11-12-merge-log-conversion.md): "a release section's change lines sit inside the last entry's block"

## Intent
`jig update --apply --merge-log` writes what it says it writes. The kept register holds only
what had no home. A superseded row's status says who accepted it and when, or the run says it
couldn't tell. Change lines sit under a group heading, outside every entry's block. The run's
own output then commits unedited.

## Why
1. **The table stays in the kept register.**
   - Why is the table still in the kept file? `as_written()` writes each leftover paragraph as every line from its first to its last, not the paragraph's own lines.
   - Why does one paragraph span the table? `paragraphs()` keeps a heading with everything after it, up to the next heading. Here the heading is above the table and the notes are below it.
2. **A superseded row converts as `Accepted (not recorded, <the day it was superseded>).`**
   - Why? `row_entry()` takes who from the status cell's parentheses and the day from the row's date cells. `Superseded by D-004 | 2026-11-11` has neither.
   - Why doesn't the row have them? With one status cell and one date cell, superseding a row overwrites both. jig's old row format couldn't put a who beside `by`.
   - Root: the converter reads the row as it stands. Only git's history of the row still says who accepted it and when.
3. **Change lines land inside a section's last entry.**
   - Why? The converter writes a section's entries and then its old lines, with no group heading between them. `log_entries()` ends a block only at `## ` or `### `.
   - Why are there no group headings? Old changelogs, jig's own among them, had bare lines under each release. RULES.md's log keeps them under Keep a Changelog groups.

## Givens
I reproduced these against `plugin/templates/jig/jig.py`, whose `git hash-object` is the
report's `1a8efef0e75c`, so line numbers hold. The throwaway repos used `E-` ids, as the
report's did. Examples below say `D-`.
- `[seen]` Bug 1, reproduced in a metarepo job with prefix `E-`. The register was `# Cross-product decisions`, a preamble, a 4-row table and two notes. The run printed "kept, holding only what has no home" and `no home, move by hand: …DECISIONS.md:1–14`. The kept file was byte-identical to the old one.
- `[seen]` Committing that output unedited is refused. The hook says `M3 .jig/decisions.md changed: add a line to CHANGELOG.md` and, for every converted entry, `M2 … names no page it touches`. Both `migrated_here()` and `migrating_log()` still see rows in the register. With the table deleted by hand, the same commit passes.
- `[seen]` I ran `parse_register()` and `as_written()` over five register shapes. Only a kept heading (`#` or `##`) above the table with kept lines below it leaks. Jig's own seed heading `# Decisions` is filtered as `OLD_SEED`, which is why smoke's plain-repo case passes.
- `[seen]` One layer up, the changelog preamble goes through the same `as_written()` (7972). An old-seed line between two preamble paragraphs under one heading comes back in the kept `CHANGELOG.md`.
- `[seen]` Once the log exists, a dry run of `jig update` lists no old logs at all, because `log_sources()` returns nothing. The report's "no longer lists that file" can't be observed, so the commit passing stands in for it.
- `[seen]` Bug 2, reproduced: the row was committed as `Accepted (Dave) | 2026-10-27`, then as `Superseded by E-004 | 2026-11-11`. It converts to `Accepted (not recorded, 2026-11-11).`, the run says nothing about it, and M2 takes the line.
- `[seen]` `git log -G'^\|\s*E-002\s*\|' -- <register>` finds both revisions; the older one has the who and the date. `removed_entry()` (3538) already walks history this way for the log.
- `[seen]` Jig's own old register shape loses the who for every superseded row. Its seed had columns `| Id | Decision | Status | Date |` (v0.9.0), and RULES.md said a stale row "is marked `superseded by` the newer". `STATUS_CELL` takes `(note)` or `by X`, never both.
- `[assumed]` The reporter's E-010, E-016 and E-037 took the same path. That is their `[seen]`; Maige-Eco is read-only here, so I did not reread it.
- `[seen]` Bug 3, reproduced. Each section's last entry block (`log_entries`) runs through the section's `- ` lines, and `jig decision <id>` prints them as part of that entry. The report had the second as `[assumed]`.
- `[seen]` On a later job, with the log already on trunk, I removed a superseded entry that was the last in a release (case A below).
  - Removing its heading and status line only, as RULES.md asks, is refused with `release v1.0.0 is frozen`. The entry above it, whose block now runs through the change lines, is then asked for a `Touches:` line.
  - Removing the block as jig reads it, change lines included, passes, and the release loses its change lines. This is the reverse of the report's expectation.
- `[seen]` RULES.md (Decision log) says "Change lines follow the entries, in Keep a Changelog's groups". The converter is the only jig code that writes change lines. An old changelog that already had groups converts with its headings, so it is unaffected.

## One layer up
- Bug 1: the changelog preamble has the same flaw and takes the same fix. One-id notes are placed from their own `(n, l)` pairs and are fine.
- Bug 2: open and proposed rows keep their note, and rejected and struck rows are left out. Only a superseded row loses what it said. The pattern of walking history for an id already exists in `removed_entry()`.
- Bug 3: a log written by hand to RULES.md has group headings, and `removed_lines()` reads `### Removed`. The converter alone writes bare lines.

## Workaround or correction
All three are corrections to what produces the output.
1. `as_written()` writes each paragraph's own lines, with one blank line wherever the old file had a gap between two of them.
2. A superseded row's who and date come from the newest revision of the register in git whose status for that row was accepted.
   - Where git can't say (a shallow clone, the row never anything but superseded, a moved register), the line is written from the row as it stands. The run prints a line naming the id as needing its who and date checked before the commit.
3. Lines that sat under no group heading in the old section get `### Changed` above them. Lines already under a group keep that group's heading.

## Done when
- [ ] Smoke: a register made of `# <heading>`, a preamble, a table and a note below it goes through `--apply --merge-log`. The kept file has the heading, the preamble and the note, and no line starting `|`.
- [ ] Smoke, fix fires: the kept file's non-blank lines equal the old file's non-blank lines minus its table lines, in order.
- [ ] Smoke, symptom gone: in a metarepo job, the run's output committed unedited passes the hook. There is no `M3 … CHANGELOG.md` and no `names no page it touches` for a converted entry.
- [ ] Smoke: a `CHANGELOG.md` preamble with the old seed line between two paragraphs under a heading keeps both paragraphs and drops the seed line.
- [ ] Smoke: a row committed as `accepted (Ann) | 2026-01-01`, then changed to `superseded by D-00N | 2026-02-01`, converts to `Accepted (Ann, 2026-01-01).`
- [ ] Smoke, fix fires: the same register committed in one commit converts, and the run prints a line naming that id as needing its who and date. A test asserts the line.
- [ ] Smoke, symptom gone: no converted superseded entry reads `not recorded` without a run line naming it.
- [ ] Smoke: `--merge-log` over a changelog with bare lines under a release and under Unreleased gives a log where no block from `log_entries()` contains a change line.
- [ ] Smoke, fix fires: each section the converter writes with change lines has a `### ` group heading above them, `### Changed` for lines that had none.
- [ ] Smoke, symptom gone: with that log on trunk, a later job removes a superseded entry that was last in its release. Removing its heading and status line passes. Removing the release's change lines with it is refused as frozen.
- [ ] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.
- [ ] `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin tests` finds nothing new.

## Out of scope
- Bug 4 of the same report: a job can't correct or revert a log only its own branch has. It is another group's.
- Logs an earlier jig already converted keep their bare lines. Their release sections are frozen, so this fix doesn't reach into them.
- `split-merge-log` renames the command to `jig migrate-log`. This fix applies to the converter under whichever name it has.
- Seen while reproducing, not investigated: outside a metarepo the log's prefix is always `D-` (`log_prefix()`). A plain repo's register with another prefix converts to entries M2 never reads; a broken status line passed `jig check --staged`.
- From the report's "Also seen, not investigated" list. The tags are the reporter's.
  - The converter attached a one-id source note to its entry. The hook then refused the log because the note names a path under `.jig/specs/`, and the run's own output couldn't be committed until the note was moved back by hand. `[relayed]`
  - On the migrating branch, removing an entry the register had already superseded was refused: "E-046 supersedes E-010, which has no entry in .jig/decisions.md or in main's history of it". `in_log_history()` reads only the log's history, not the register's. A migrated log carries its superseded entries through one merge, and a second job removes them. `[relayed]` for the refusal, `[seen]` for the second job, which passed. I saw the same refusal here too.
  - After `jig merge` of the migrating job, `jig status` printed `reserve decision: next free 1` until `jig update --apply --merge-log` was run on trunk, because the board still counted rows in the register. A job opened in that gap would be handed E-001. `[seen]`
  - `jig merge` refused a branch whose handoff commit also added the review's `DEFERRED.md` rows ("has changed since the commit … names"), though `.jig/ledgers/**` is where the review skill sends untaken findings. A second `jig reviewed` and `jig handoff` at the tip got it through. `[seen]`
  - M6 refused a commit subject that led with an id range (`E-001–E-047: …`). `[relayed]`

## Touches
- `plugin/templates/jig/jig.py`: `as_written`, `row_entry` / `parse_register` / `merged_log` (history for superseded rows, group headings), and the run's report lines in `cmd_merge_log`.
- `tests/smoke.sh`: the migration cases.
- `plugin/skills/update/SKILL.md`: one clause, so the list of what the run prints includes superseded rows git couldn't date.
- No change to RULES.md: it already groups change lines, and the converter now follows it. No new row in FEATURES.md: this corrects the Decision log row's migration. No docs page covers `jig.py` (`reading-list`).

## Alternatives considered
- End a heading's paragraph where a filtered line interrupts it, in `paragraphs()` — rejected because a heading and the notes under it are one section to place (its docstring), and the extra lines come from `as_written()` — this reason is [seen].
- Leave superseded rows out of the log, since the next job removes them anyway — rejected for this fix because the superseding entry's `Supersedes` link would then have to resolve through the register's history. `log_problems()` and `removed_entry()` read only the log's history (Also seen, item 2) — this reason is [seen].
- Keep `not recorded` and document it — rejected because the line is false (its date is the day the row was superseded), and it is frozen once committed in a release section — this reason is [seen].
- Refuse the run until the owner fixes the row, as for a row the old M2 refused — rejected because the old row format can't hold a who beside `superseded by` (`STATUS_CELL`), and git usually has the answer — this reason is [seen].
- End an entry's block at the first `- ` line after its body, in `log_entries()` — rejected because RULES.md gives the body no shape, so a list there is legal and a guard would cut it — this reason is [assumed] (I saw no body with a list).
- M2 refusing a `- ` line under an entry with no group heading between them — rejected for this fix for the same reason: the hook can't tell a body's list from a change line. The owner may still want it for logs written by hand — this reason is [assumed].
- Write change lines above the entries — rejected because RULES.md puts change lines after the entries — this reason is [seen].

## Decisions
- Bare lines go under `### Changed`. Keep a Changelog has no catch-all group. Guessing Added or Fixed from a line's words would put a guess in a frozen release.
- The history walk follows the register's path only. A moved register falls back to the run's line instead of `--follow` guesswork.
- When git can't say, the run warns instead of refusing. One undated row shouldn't block a run whose other rows are right, and the line is named before the commit that freezes it.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
