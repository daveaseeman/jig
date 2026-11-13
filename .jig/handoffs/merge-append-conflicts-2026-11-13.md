# Handoff: merge-append-conflicts

Commit: 7725aba48517f2b22978ddaf508f792e644d36eb
Date: 2026-11-13
Spec: .jig/specs/bug-merge-append-conflicts.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
- `jig merge` handles an unsynced job whose only conflicts are in append files, provided each conflict has both sides only adding. It resolves them itself, taking each file from a replay of the job's sync (`replay_sync` / `sync_resolutions`), so the order is trunk's lines, then the job's. The job's branch isn't touched, and the merge message has no `# Conflicts:` lines.
- Anything else is refused as before:
  - an edited line
  - a modify/delete conflict
  - a conflict beside a non-append file
  - git older than 2.38
- `changed_since` leaves out a `.jig/ledgers/DEFERRED.md` change that deletes no line. The review's rows can therefore be committed with the note.
- RULES.md Handoff steps 1 and 3 and the M5 row are updated, and so is subnode step 4.

## Done-when evidence
- A, then B, merge back to back, with no sync and no new note: `bash tests/smoke.sh report_fixes`, "merge: then B merges with no sync and no new note: the base row, A's, then B's, B's branch untouched" PASS.
- The fix fires, prints that it resolved, and the message has no Conflicts lines: "merge: it says it resolved CHANGELOG.md as jig sync would, and the commit is 'merge L' with no Conflicts lines" PASS. The B case also greps the resolved line for `.jig/ledgers/DEFERRED.md`.
- Still refused, with trunk clean:
  - E's base-row edit: "merge: E, whose edit of the base row meets A's append, is refused…" PASS
  - M (append plus common.txt): "merge: M conflicts in CHANGELOG.md and common.txt: refused…" PASS
  - B under the 2.30 shim: "merge: with a git older than 2.38, B, whose row meets A's, is refused…" PASS
  - O's modify/delete: "merge: O deleted CHANGELOG.md, which trunk appended to: refused…" PASS
- C (note plus a row in one commit) merges with no second record: "merge: C, its note and a DEFERRED.md row in one commit after the review, merges with no second record" PASS.
- Refusals that name the file:
  - C2 (rewords the base row): "merge: C2, whose note commit also rewords the base row, is refused, naming DEFERRED.md" PASS
  - X (AGENTS.md after the note): "merge: X, with a line added to AGENTS.md after its note, is refused, naming AGENTS.md" PASS
  - The code-change case is the existing one, still passing.
- fu-sync:
  - L merges with no sync: "merge: L, unsynced, conflicts only in CHANGELOG.md: merged with no sync…" PASS
  - The 2.38 case still refuses, on synced job N: "merge: with a git older than 2.38, a synced job is refused, saying 2.38 is needed" PASS
- Byte identity with sync-then-merge: "merge: B's merge tree is the one jig sync, then jig merge, writes" PASS.
- RULES.md steps 1 and 3, the M5 row and subnode step 4 are edited. FEATURES.md is done by the hubnode on main.
- `bash tests/smoke.sh`: 1165 PASS, 0 FAIL, exit 0. `claude plugin validate ./plugin`: ✔ Validation passed. `.jig/scripts/check.sh`: exit 0.
- Control: the report_fixes section run against trunk's jig.py fails the four new "merges" cases.

## Review
The hubnode ran a fresh-subagent review of a2720f4 at tier 2, effort 2. Nothing was blocking. What happened to each finding:
- 2 (should-fix), modify/delete resolved instead of refused: fixed in 7725aba. `sync_resolutions` now requires conflict markers in the replay's blob. Smoke job O covers it.
- 3, the docstring overstated the check: fixed. It now says "a change that deletes no line", as does RULES.md step 1. Its substance, that a mid-table insert can re-state a disposition, is deferred to DEFERRED.md.
- 4, assert B's tree equals sync-then-merge's: added to smoke.
- 5, metarepo M5 not smoke-covered: deferred to DEFERRED.md (it shares `changed_since`).
- 6, RULES.md rewrap: done.

The hubnode checked 7725aba and recorded the review on it.

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Handoff, gate, merge steps 1 and 3; the M5 row).

## Shared files changed
- `plugin/templates/jig/jig.py`: `cmd_merge`'s append-conflict branch, plus the new `replay_sync` and `sync_resolutions` (taken out of `changed_since`), plus `changed_since`'s DEFERRED.md exemption and `counts_reviewed`'s docstring. These are the functions the spec names.
- `plugin/templates/jig/RULES.md`: Handoff steps 1 and 3, and the M5 row.
- `tests/smoke.sh`: sec_report_fixes, meaning the fu-sync block (new jobs N and O) and a new fu-defer block.
- `.jig/ledgers/DEFERRED.md`: two rows from the review.

## Test by hand
In a repo with two gated jobs that each added a DEFERRED.md row, run `jig merge` on one, then the other. The second merge should print "resolved .jig/ledgers/DEFERRED.md as `jig sync` would…", and `git log -1` should show `merge <job>` alone.

## Left
Nothing on this spec. Two DEFERRED rows are open: metarepo M5 coverage, and mid-table inserts.
