# Decisions: an `open` status, and M2 reads the status cell whole

Source: a `/jig:feedback` report from a metarepo adopting jig, Oct 29
(`jig-feedback-<metarepo>-2026-10-29.md`, two issues). Its claims were checked against
`jig.py` here: the status tuple is at line 1105, M2's check is at line 1173, and the seed comment is at line 1261.

## Intent
A question that binds the pararepos gets a decision row and an id when it's asked, before
anyone proposes an answer. It can be cited and pinned from the start, and its whole history
stays on one row: open → proposed → accepted or rejected, and later superseded. M2 accepts a
row only when one whole cell is a status, so a Decision cell that happens to start with a
status word ("Open question: …", "Accepted practice: …") no longer passes for one.

## Done when
Each case below is a smoke case in the meta fixture: append the row to the entry file, add a changelog line, and run `jig check --staged`.
- [x] `| D-n | <question> | open | 2026-10-29 |` prints `ok`.
- [x] `| D-n | x | accepted (owner) | 2026-10-29 |` and `| D-n | x | superseded by D-m | 2026-10-29 |`
      print `ok`.
- [x] Refused by M2:
  - `| D-n | Accepted practice: radios off |  | 2026-10-29 |` (empty status)
  - `| D-n | Open question: which copy? |  | 2026-10-29 |`
  - `| D-n | x | acceptedly | 2026-10-29 |`
- [x] The M2 refusal lists `open/proposed/accepted/superseded/rejected`.
- [x] `jig meta-init` writes an entry file whose comment lists all five.
- [x] `RULES.md` M2 names the five statuses. *Metarepo and pararepos* has one sentence on the
      lifecycle, and says that a reversal (accepted → superseded or rejected) is a major release.
- [x] The existing meta smoke cases pass, and the validator passes.

## Out of scope
- A status list set per repo in `meta.json`. The point is one vocabulary across metarepos.
- Finding the Status column from the table header (see Alternatives).
- Changing how `release` picks major or minor. The rulebook already says "major for a reversed
  decision"; this only spells out which statuses that means.

## Touches
- `marketing/FEATURES.md`: an `open` status row, before the code.
- `plugin/templates/jig/jig.py`: `DECISION_STATUSES` gains `open` first, in lifecycle order. A
  `STATUS_CELL` regex is built from it. M2 requires one cell to `fullmatch` it.
- `plugin/templates/jig/RULES.md`: the M2 row, and one sentence under *Metarepo and pararepos*.
- `tests/smoke.sh`: the cases above.

## Alternatives considered
- Map `open` to `proposed`. Rejected: proposed means an answer is waiting for a yes, and open
  means there is no answer yet. Merging them marks an unanswered question as answered.
  `[seen]`: the adopting repo's definitions, quoted in the report.
- Keep open questions as prose lists. Rejected: then a question has no id to cite or pin, and
  `para-sync` can't report it. `[seen]`: `terms_changed` reports row ids, so it would report an
  open row with no other change.
- Add a word boundary to the prefix test (`^status\b`). Rejected: "Accepted practice: …" and
  "Open question: …" both start with a whole status word, so they still pass. `[seen]`, from the
  pattern.
- Find the Status column from the header. Rejected for now: a `-U0` diff often leaves the header
  out, so M2 would have to read the staged file and handle several tables. `[assumed]`: the fix
  doesn't depend on this, since whole-cell matching closes every case the report shows.

## Decisions
- Status grammar: a status word alone, a status word followed by a parenthesized note
  (`accepted (owner)`), or `<status> by <id>` (`superseded by D-12`). Cells are already
  lowercased.
- Remaining risk: a Decision cell that consists of nothing but a status word (`| D-n | open | … |`)
  still passes as the status. That's rare, and a row like that says nothing anyway.
- Build, Oct 29. Done as written. Smoke 197 PASS, eight new M2 cases among them; the
  validator passes. The refusal cases differ from the accepted ones only in the row, so each
  is refused by M2 and nothing else.
