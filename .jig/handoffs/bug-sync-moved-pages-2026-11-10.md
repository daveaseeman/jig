# Handoff: bug-sync-moved-pages

Commit: 7ed7f7230f5d3dae495b7685e95729085dd0e05f
Date: 2026-11-10
Spec: .jig/specs/bug-sync-moved-pages.md
Review: tier 2, effort 2
Ran: fresh Opus review of cfdf5aa: no blocking; S1 false citation when meta name matches a folder here, S2 cost lines x entries, S3 decision-id sections flagged (all reproduced), fixed in 7ed7f72; O5 spec says sync and release, O6 Closed rows and HEAD reads made consistent; O7 rename threshold deferred. Hubnode checked 7ed7f72 by diff and smoke pararepo/sync_buffer/pointers.

## Built
<!-- what this delivers, in a few lines -->
- At a metarepo release jump, `changes_report` lists each entry file the new release moved or removed (`<old> (now <new>)` / `<old> (removed)`) with every file here that uses it; "used in" now counts `.jig/specs/` and `.jig/ledgers/` (Open BUFFER rows only).
- On every sync and at a pararepo's release, `meta_citations` checks each `<meta>/<path> § section` citation at HEAD against the cache: a missing file, heading, or decision row (when `§` is a decision id) is named; a bare path naming a metarepo entry file and nothing here gets "write it as `<meta>/<path>`". Handoffs and Closed BUFFER rows are left out. Reports only.
- RULES.md: the bump report's contents, and a "Citing the metarepo" paragraph. BUFFER template claim column: `<meta>/<path> § section`.

## Done-when evidence
<!-- one line per spec item: the command run and what it printed -->
- Repro, smoke `pararepo` "para sync: a newer release lists an entry file it moved…": PASS; prints `products/hardware/walyt.md (now products/walyt/walyt.md): used in .jig/ledgers/BUFFER.md, .jig/specs/s.md, docs/a.md`; heading line `Interaction (rev 2): used in .jig/ledgers/BUFFER.md`: PASS.
- Deleted entry file reads `products/gone.md (removed): not used here` when only a handoff and a Closed row mention it: PASS.
- After the bump: spec citing `mm/products/hardware/walyt.md § Two stages` named; `mm/products/walyt/walyt.md § Interaction` not named; bare `products/walyt/walyt.md` named with "write it as `mm/products/walyt/walyt.md`"; Closed row and handoff not named: all PASS. Plus decision-id row check and folder-named-like-metarepo cases: PASS.
- The D-001 case still passes, now expecting `D-001: used in .jig/ledgers/BUFFER.md, .jig/specs/buffer-v0.1.1.md, api/ids.md` (its BUFFER rows and buffer spec cite D-001).
- `bash tests/smoke.sh`: 778 PASS, 0 FAIL, exit 0. `claude plugin validate ./plugin`: ✔ Validation passed. `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin`: empty.

## Review
<!-- findings from the adversarial review, and what you did about each -->
- S1 (should-fix) a metarepo named like a folder here gave false citations: fixed, a `<meta>/<path>` that is a tracked path or folder here is skipped; smoke case added.
- S2 (should-fix) cost lines × entries: fixed, one `cat-file --batch` of HEAD's text blobs (binary and >1 MB skipped), one plain alternation, boundaries checked after; ~2.4 s at 3000 files × 200 lines × 300 entries.
- S3 (should-fix) `§ D-001` flagged as a missing heading: fixed, a decision-id section checks for the row; smoke case added.
- O5 spec wording, O6 Closed rows in `used_in` and HEAD reads: taken. O7 rename threshold: deferred, row in DEFERRED.md.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Metarepo and pararepos: the bump report, Citing the metarepo).

## Shared files changed
<!-- each shared/common file, and why this job had to touch it -->
- `plugin/templates/jig/jig.py`: new `entries_moved`, `closed_row`, `used_in`, `head_texts`, `meta_citations` beside `changes_report`; two call sites (`sync_meta`, `para_problems`) gain the citation lines.
- `plugin/templates/jig/RULES.md`: the pin-bump sentence, plus one appended paragraph after the sync buffer.
- `tests/smoke.sh`: one block appended at the end of `sec_pararepo`; the D-001 case's expected line updated.

## Test by hand
<!-- what a person should click or watch -->
- In a pararepo whose pin is behind a metarepo release that moved a page, run `jig sync` on trunk: the report names the move and the files citing it, then each stale `<meta>/<path>` citation by file and line.

## Left
<!-- what remains on this job -->
- Nothing on this job. Existing pararepos' bare citations (e.g. `DECISIONS.md § D-001` in BUFFER rows) will now be reported; requalifying them is each repo's work.
