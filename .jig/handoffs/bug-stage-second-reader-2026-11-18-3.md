# Handoff: bug-stage-second-reader

Commit: aad54620e7eff54654947a7074d670bdefb4d1cc
Date: 2026-11-18
Spec: .jig/specs/bug-stage-second-reader.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
Final. Part 3 (the owner: "Review before staging"; then "Fix them first"), commits f998ab7 and 149dc65, with ledger commits 295de9e and aad5462. It replaces part 2's mark-then-remove design. For parts 1 and 2, see `.jig/handoffs/bug-stage-second-reader-2026-11-18.md` and `-2.md` (partial).
- § Staging a file: the file goes into the target's `.jig/staging/` only after the Second reader. One file is a batch of one.
- § A batch, Second reader: before anything is written to staging, a fresh worker at tier 2, effort 2 reads every draft against a verbatim record. You fix, show the owner, then write.
- With no reader the batch is written with `; unreviewed` from the start. No reader means: the host can start no worker; the worker errors, times out or returns no report; the session compacts after handing over the drafts and before the findings are fixed and shown; or the record isn't verbatim.
- A summary, or a rigger's `record/`, is not the record.
- A file's `source:` is final once written.
- § Resolving names an unreviewed file as staged with no reader, or against a record that wasn't verbatim.

## Done-when evidence
- Second reader item, drafts before staging, `; unreviewed` from the start, `source:` final, verbatim record, no model name: `plugin/skills/stage/SKILL.md` § Staging a file and § A batch. The smoke cases assert each.
- Resolving names unreviewed: § Resolving, "was staged with no reader, or against a record that wasn't verbatim".
- Smoke: `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh staging_batches` gives rc 0, 34 PASS, 0 FAIL (`stage-second-reader-part3b-smoke.out` in the hubnode's shared notes folder). That includes four stage-skill cases (part 1's, part 3's two, and the target rule), and twice "PASS  staging: a request staged ; unreviewed resolves against a spec carrying that exact source, and no longer does once the mark is taken off". Each new text case fails against the commit before it.
- Check: `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` exits 0.
- Fires (dry run) and symptom gone (Daisy replay): part 1's evidence, in `bug-stage-second-reader-evidence.md` in the hubnode's shared notes folder. The worker caught all three planted faults before "staged". On the Daisy copies it named the table "accepted as a whole" and the Intent / Done when contradiction, plus the other four faults. The replay is partly circular: its record was rebuilt from the final files. Part 3 changes when the files are written (drafts are read before staging), not what the reader is given or asked.
- FEATURES row: the hubnode's (gitignored).

## Review
Parts 1 and 2: see the earlier notes. Part 3's rounds:
- review-change of 9b7f5c2..f998ab7, recorded at f998ab7. Clean, blocking 0. On its two should-fix findings the owner, 2026-11-18, said "Fix them first":
  - SF1: "Staging a file" wrote before the reader. Fixed in 149dc65.
  - SF2: compaction. Fixed in 149dc65.
  - O2: the tag split. Taken.
  - O3: the DEFERRED SF1 row. Taken.
- review-change of f998ab7..149dc65, recorded at 149dc65. Clean, blocking 0. The reviewer found no path that writes before the reader or changes a written `source:`. Its findings are DEFERRED rows (295de9e, aad5462):
  - SF-a (should-fix): the compaction window should end at "written", not "fixed and shown". Deferred.
  - O-a and O-b (optional): deferred.
  - O-c: the old O4 is settled. It is an appended row, since jig counts an in-place edit of a reviewed row as a change.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each roadmap item naming one of those
     pages (an Up next item, or a taken scope) has its own line: keep one answer, built,
     untouched or departed: <why>. An Up next item answered built leaves the roadmap when
     the job merges. The gate refuses an unanswered line. An UNOWNED file has no page
     covering it: add it to docmap in the board, or say why it needs none. A pair line
     (`<id> vs <log> § <ids> (<page>): ___`) is answered after its colon, once for every id
     on it: agrees, narrows: <how>, or conflicts: <resolution>; on a line of several ids,
     narrows and conflicts name at least one of them. jig reads the rest of the line, so it
     stays as jig wrote it. -->
- [x] no code changed — nothing to fold in (skill text, smoke cases, the spec and the ledger; no docs page describes the stage skill's steps)

## Shared files changed
- `plugin/skills/stage/SKILL.md`: § Staging a file (one sentence), § A batch (the Second reader item) and § Resolving (one sentence). rig-and-versioning's pin-bump change is elsewhere in the file.
- `tests/smoke.sh`: cases appended in `sec_staging_batches`.
- `.jig/ledgers/DEFERRED.md`: rows appended, and the part 1 and part 2 SF rows marked taken.

## Test by hand
Run `/jig:stage` from a chat. The worker's findings and your fixes should be shown before anything appears in the target's `.jig/staging/`, and only then the word "staged". On a host with no worker, the files should land with `source: …; unreviewed`, and the reply should say unreviewed.

## Left
Nothing in the spec. SF-a, O-a, O-b, O1 and O3 are in DEFERRED.md, and SF3 (rig's handling of an unreviewed file) belongs with rig's skill.
