# Handoff: decision-remove-superseded

Commit: 5df431716f6b37f5fb0611dcccda6baed68e0109
Date: 2026-11-11
Spec: .jig/specs/decision-remove-superseded.md
Review: tier 2, effort 2
Ran: fresh Opus reviewer (high) on d7d41c6/d222c6d: B1 (a Proposed supersede removed a live decision), S1 shallow clone, S2 one-hop successor, S3 stale wording; fixed in 5df4317; hubnode re-ran the reviewer's B1 and shallow repros (B1 refused, shallow passes) and an accepted supersede+remove with jig decision walking to D-002

## Built
`.jig/decisions.md` shows only what holds now. The commit adding an accepted entry with
`Supersedes D-n` may remove D-n's whole block, from any section including a released one. A
release's change lines stay frozen, and removing an entry no accepted entry supersedes is
refused, naming it. M2 resolves a supersedes link through trunk's history of the log, and
passes it in a shallow clone. `jig decision <id>` reads a removed entry from git, with its
commit and release, and walks the chain to what holds now. A pararepo citing a removed
metarepo id is told the successor that holds at the pin, walked through the metarepo's git.
`jig update` lists superseded entries an older log still holds.

## Done-when evidence
- Removal with superseding entry accepted, without it refused naming D-001, change line edit refused: `bash tests/smoke.sh supersede` → PASS "removing a released entry with nothing superseding it is refused, naming it", "editing a released change line is still refused", "one commit adding D-002 that supersedes D-001 and removing D-001 from v0.1.0 is accepted, change lines kept".
- M2 through history: PASS "a later commit touching the log passes M2, Supersedes D-001 resolving through history", "a supersedes link to an id the log never had is refused", "on trunk, D-004 superseding D-003, an id given only in a merge commit, removes it and passes M2".
- `jig decision`: PASS "jig decision D-001 prints it from git, the release it was in, and D-002 as what holds now", "jig decision D-002 names D-001 as superseded and removed", "jig decision D-001 walks two removals to D-003".
- Pararepo successor: PASS "a pararepo citing a removed metarepo entry is told after the pin bump, with the successor named", "a citation two removals back walks the metarepo's history to the entry that holds at the pin".
- `jig update`: PASS "jig update lists a superseded entry the log still holds under Repo files to review", "jig update doesn't list an entry only a proposal supersedes".
- RULES.md: Decision log "Released sections", R3, Checked, the M2 row and Newer wins say it (in the diff).
- `bash tests/smoke.sh` → exit 0, 921 PASS, 0 FAIL; `claude plugin validate ./plugin` → ✔ Validation passed; `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin` → nothing (exit 1); `.jig/scripts/check.sh` → exit 0.

## Review
- B1 (blocking) a Proposed entry's Supersedes removed a live decision, and counted as what holds now in `jig decision`, update and meta_citations: fixed in 5df4317 (`replaced()` counts an accepted entry's links only; smoke cases for both).
- S1 a shallow clone refused every log commit and `jig decision` died: fixed in 5df4317 (M2 passes the link when shallow; `jig decision` names the shallow clone; smoke case).
- S2 the pararepo successor was found one hop only: fixed in 5df4317 (`holds_now` walks through the metarepo's git at the pin; smoke case).
- S3 skills, messages and comments still said "never edit, supersede with a new one": fixed in 5df4317.
- O1 `history_re` didn't escape a `D-?slug`: taken (history lookups skip `?` ids).
- O4 a removed id with no successor walked history with an empty id: taken (guarded).
- O2 M2 reads all history while `jig decision` reads first-parent; a rejected Open id passes M2: deferred, row in `.jig/ledgers/DEFERRED.md`.
- O3 one `git log -G` per missing link: deferred, row in `.jig/ledgers/DEFERRED.md`.
- O5 blank-line edits in a released section pass: deferred, row in `.jig/ledgers/DEFERRED.md`.

## Fold-in
<!-- Every documentation page that covers code this changed: does it still describe the
     code? Replace each ___ and tick the box: the stale sentences are edited (deleting
     counts), or none went stale and this says why. Each Undefined entry on those pages has
     its own line: keep one answer, built, untouched or departed: <why>. Built means the
     entry is deleted from the page in this change. The gate refuses an unanswered line. An
     UNOWNED file has no page covering it: add it to docmap in the board, or say why it
     needs none. -->
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because the checker's documentation is `plugin/templates/jig/RULES.md` (Decision log's Released sections, R3, Checked, the M2 row and Newer wins, all updated here), with the subnode and stage skills' log lines updated to match.

## Shared files changed
- `plugin/templates/jig/jig.py`: the log's rules, `jig decision`, sync's citation check and update's review list live there.
- `tests/smoke.sh`: a new `supersede` section, added to UNITS.
- `plugin/skills/subnode/SKILL.md`, `plugin/skills/stage/SKILL.md`: "supersede, never edit" became "supersede and remove" (shares widened after review).
- `.jig/ledgers/DEFERRED.md` (common): rows for O2, O3, O5.

## Test by hand
In a repo with a released `D-001`, add an accepted `D-002 … Supersedes D-001.` under Unreleased and delete D-001's block in one commit: it commits. Then `python3 .jig/jig.py decision D-001` prints D-001's text, the commit and release it stood in, and D-002 as what holds now.

## Left
Nothing on this spec. decision-touches runs next and shares jig.py, RULES.md and smoke.sh: the log code it meets is `replaced`, `removed_entries`, `holds_now` and `removed_entry`.
