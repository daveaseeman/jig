# Handoff: gate-order

Commit: 28e509c1e6f073d18847813dc157f09a35f2fbb2
Date: 2026-10-30
Spec: .jig/specs/gate-order.md

## Built
`jig gate` and `jig merge` now take a job's newest handoff note. Before, they took that day's
first note.
- `handoff_notes` (`plugin/templates/jig/jig.py`) parses note names as `<job>-<date>[-n].md` and
  orders them by (date, n), a note with no suffix being n = 1. The plain name sort it replaces
  put a day's unsuffixed note after its `-2` and `-3`.
- The exact match also stops job `X` picking up job `X-y`'s notes.
- `cmd_handoff` carries a one-line pointer to that pattern. The names it writes are unchanged.
- The review skill now says which note is the "last handoff": the one `jig gate` names.

## Done-when evidence
- **Gate takes `-3`:** smoke `PASS gate: of three notes filed on one day, the gate takes the -3 note`.
- **Merge checks against `-3`:** smoke `PASS merge: the job's entry is deleted in the merge commit itself … (checked against the -3 note; the first names an older commit)`.
- **Status counts only A's notes:** smoke `PASS status: job A counts its own three notes, not job A-x's` (`handoffs:3`).
- **Smoke and validator:** `bash tests/smoke.sh` gives exit 0, 261 PASS, 0 FAIL; `claude plugin validate ./plugin` gives `✔ Validation passed`.
- **The cases catch the bug:** the same smoke test on a copy with main's `jig.py` FAILs all three new cases. Its `update` cases also fail there, because that copy isn't a git repo, which they need.

## Review
Fresh-context reviewer, Oct 30, on `main...a1199e3`. Nothing blocking. Taken in 28e509c:
- **Should-fix:** the merge case passed on the old code too. The stray `A-x` note had no
  `Commit:`, so merge fell back to the branch itself. The stray note now names a commit the
  branch has moved past.
- **Should-fix:** the review skill's "last handoff" didn't say which note, and the last note by
  name is the bug. It now names the note `jig gate` names.
- **Optional:** the spec's `git log` rejection was `[assumed]`. It is now retagged `[seen]`.

Deferred, one row each in `.jig/ledgers/DEFERRED.md`, all optional:
- a later note dated earlier, from a clock or timezone change;
- a smoke run that crosses midnight;
- solo mode on a branch with `/`, where `jig handoff` writes into a missing folder (pre-existing);
- a note with no `Commit:` passing merge's moved-branch check (pre-existing).

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because this repo's docmap is empty, and RULES.md says nothing about which note the gate takes, so no page states the old order

## Shared files changed
- `.jig/specs/gate-order.md`: the spec, under `.jig/**` (common).
- `.jig/ledgers/DEFERRED.md`: four rows appended (append file).
- This note.

## Test by hand
On a job with two handoffs from one day, run `python3 .jig/jig.py gate <job>` from trunk. It
should print `from .jig/handoffs/<job>-<date>-2.md`. This repo's installed `.jig/jig.py` still
has the old order until `/jig:update`, so run it against `plugin/templates/jig/jig.py`.

## Left
- This repo's `.jig/jig.py` keeps the bug until `/jig:update` installs the next release.
  Until then, gating `update-spec` here takes its first note.
- No `marketing/FEATURES.md` row: a fix, not a feature.
