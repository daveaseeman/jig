# Bug: the gate takes a job's first handoff of the day, not its latest

## Intent
`jig gate` and `jig merge` read a job's newest handoff note: notes ordered by (date, sequence),
a note with no `-n` suffix being sequence 1, and only notes named exactly
`<job>-<YYYY-MM-DD>[-n].md`.

## Why
- `[seen]` `jig handoff` (`jig.py:870-874`) writes `<job>-<date>.md`, then `-2.md`, `-3.md` the
  same day.
- `[seen]` `handoff_notes` (`jig.py:546-550`) returns them `sorted()` by name; `cmd_gate` takes
  `notes[-1]` (`jig.py:932`), `cmd_merge` too (`jig.py:664`). `-` (0x2d) sorts before `.` (0x2e),
  so `<job>-<date>.md` sorts after `-2.md` and `-3.md`: the gate and the merge check always use
  the day's first note.
- `[seen]` On this repo: `.jig/handoffs/para-spec-2026-10-30.md` sorts after `...-2.md`.
- `[seen]` Two notes are enough. On branch `update-spec` at 3f5349a only
  `update-spec-2026-10-30.md` and `-2.md` exist, and `jig gate update-spec` prints
  `gate 0888a4209474 from .jig/handoffs/update-spec-2026-10-30.md`.
- `[seen]` Several notes a day is by design: the subnode skill says to hand off "as often as a
  coherent piece is done".
- `[seen]` It has happened before. In an adopting repo's history, 8 jobs filed a `-2` on one
  day and one filed a `-3`, whose notes name three different commits. That repo's checker had
  the same `sorted()` / `notes[-1]`, so its gate named the first note's commit and checked the
  first note's fold-in. The job was gated and merged anyway.
- A correction, not a workaround: no `WORKAROUND:` comment or ledger row.
- `[seen]` Same function, second bug: `startswith(f"{name}-")` takes job `para-spec`'s notes as
  job `para`'s. Exact name matching fixes both.
- `[seen]` Nothing else picks a "latest" note: `cmd_status` only counts them; no skill or
  `RULES.md` line says which note wins.

## Done when
- [x] Smoke: a job files three handoffs on one day; `jig gate` names the `-3` note.
- [x] Smoke: `jig merge` of that job passes the moved-branch check against the `-3` note's commit
      (the `-1` note names an older commit, so taking it would refuse).
- [x] Smoke: job `A`, with its three notes and job `A-x`'s note on its branch, reports
      `handoffs:3` in `jig status`.
- [x] `bash tests/smoke.sh` and `claude plugin validate ./plugin` pass.

## Out of scope
- `.jig/jig.py` (the installed copy): it changes by `/jig:update`.
- Note naming: `jig handoff` keeps writing the same names.

## Touches
- `plugin/templates/jig/jig.py`: `handoff_notes` parses names and sorts by (date, sequence).
- `tests/smoke.sh`: the cases above.
- `plugin/skills/review/SKILL.md`: its "last handoff" is the note `jig gate` names (review finding).

## Alternatives considered
- Name the first note `-1.md`. Rejected: existing repos' notes keep the old names, so the reader
  must handle no suffix anyway. `[seen]` this repo's `.jig/handoffs/`.
- Order by commit time of each note (`git log`). Rejected: the name already carries the order.
  `[seen]` `cmd_handoff` numbers a day's notes in the order it writes them.
- Pick by file mtime. Rejected: the notes are read from the branch with `git ls-tree`, which has
  no mtime. `[seen]` `jig.py:548`.

## Decisions
- One regex, `^<job>-(\d{4}-\d{2}-\d{2})(?:-(\d+))?\.md$`, in `handoff_notes`. `cmd_handoff`
  carries a one-line pointer to it, so the writer and the reader change together.
- Build, Oct 30. Done as written. The merge case is the existing "merge: the job's entry is
  deleted…" case, now run after three notes on job A. The `-1` note and the stray
  `A-x-<date>.md` both name a commit the branch has moved past, so the old code, which took
  either, would refuse it. The status case uses that stray note, which the old code counted
  and, sorting it last, gated. The gate case answers the `-3` note's fold-in
  first, as the H1 cases do. Smoke: 261 PASS, 0 FAIL; the validator passes. Against the
  pre-fix `jig.py`, the same three notes gate `A-<date>.md`. After the review fixes: 261 PASS,
  0 FAIL, and with the pre-fix `jig.py` all three new cases fail, the merge case among them.
- Review, Oct 30 (fresh context, on the diff). No blocking. Should-fix, taken: the merge case
  passed on the old code too, because the stray note had no `Commit:` and merge fell back to
  the branch; it now names an old commit. Should-fix, taken: the review skill's "last
  handoff" now says which note. Optional, taken: the `git log` rejection retagged `[seen]`.
  Deferred to the ledger: a later note dated earlier (clock or timezone), the smoke run
  crossing midnight, solo branches with `/`, and a note with no `Commit:` passing merge.
