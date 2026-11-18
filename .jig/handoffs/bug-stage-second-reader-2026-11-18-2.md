# Handoff: bug-stage-second-reader

Commit: 9b7f5c2b6bab5c704847741c05cc9bb1b1fa07a3
Date: 2026-11-18
Spec: .jig/specs/bug-stage-second-reader.md
Partial: yes
Review: tier 2, effort 2
Ran: claude-opus-5-5 at high
Review-change: tier 2, effort 2
Review-change ran: claude-opus-5-5 at high

## Built
Part 2 (SF1, SF2; the owner: "Fix before merge"), commit 9b7f5c2. In § A batch, every staged file was written with `; unreviewed` and the mark was removed only after the reader's findings were fixed and shown. A record that isn't verbatim keeps the mark, and a summary or a rigger's `record/` is not the record. The smoke section got one new case, and DEFERRED's SF1 and SF2 rows are marked taken. Partial: the owner has since chosen "Review before staging", which part 3 builds and which replaces this part's SF1 design.

## Done-when evidence
- Smoke: `python3 plugin/templates/jig/jig.py queue -- bash tests/smoke.sh staging_batches` → rc 0, 31 PASS, 0 FAIL, including `PASS  stage skill: every file is written unreviewed and the mark comes off only after the findings are shown; a failed worker, an ended session or a record that isn't verbatim leaves it` (output in `stage-second-reader-part2-smoke.out`, hubnode's notes folder). The new assertion fails against part 1's skill.
- Check: `python3 plugin/templates/jig/jig.py queue -- .jig/scripts/check.sh` → rc 0.
- Part 1's dry run and Daisy replay stand (`bug-stage-second-reader-evidence.md`).

## Review
review-change of e731bdf..9b7f5c2, recorded by the hubnode at 9b7f5c2. Blocking: 0.
- should-fix: removing `; unreviewed` later breaks the exact-mark link. A spec, page or commit made while the mark is on carries `Source: …; unreviewed (staged as …)`. Once the mark comes off, `jig staging resolve` no longer finds that carrier (the reviewer reproduced it: exit 1, "write a new spec … carrying …"). rig-and-versioning's `taken` matching breaks the same way. Taken by part 3: the owner, 2026-11-18, chose "Review before staging".
- optional: say "returns no report", not "returns nothing". Taken by part 3.
- optional: Resolving's "had no second reader" should match the new wording. Taken by part 3.
No DEFERRED rows: part 3 takes every finding.

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
- [x] no code changed — nothing to fold in (skill text, a smoke case and the spec; no docs page describes the stage skill's steps)

## Shared files changed
- `plugin/skills/stage/SKILL.md`: § A batch, the Second reader item.
- `tests/smoke.sh`: one case appended in `sec_staging_batches`.
- `.jig/ledgers/DEFERRED.md`: the SF1 and SF2 rows are marked taken.

## Test by hand
Nothing new for this part. Part 3 replaces its SF1 design.

## Left
Part 3: the reader reads the drafts before anything is written to staging. With no worker, or a record that isn't verbatim, the batch is written with `; unreviewed` from the start, and `source:` is final once written. Also the two optional wording fixes.
