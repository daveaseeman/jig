# Handoff: branch-log-old-side

Commit: b50c6ed10443f4290b3d18e12119efa56f6ec05e
Date: 2026-11-12
Spec: .jig/specs/bug-branch-log-old-side.md
Review: tier 2, effort 2
Ran: claude-opus-5-5 at unknown

## Built
On a job's branch, the log's rules and R6 now judge a commit from where the branch left trunk,
not from the branch's last commit. Later commits on a branch may correct or revert earlier
ones, as their squash would.
- `since_trunk()` beside `base()`: on a branch, the merge base with trunk; on trunk, on a
  detached HEAD, or during a merge of trunk, `base()`. Used by `log_rules()`, `migrating_log()`
  and `reserved_refusals()` (R6). R3's log branch passes a log absent at both ends.
- Frozen sections: a release the branch's HEAD has beyond the merge base is trunk's too (a stale
  local trunk), judged against HEAD. Only the releases the branch's own `--merge-log` wrote are
  exempt: in the merge base's CHANGELOG.md, and in the log as the branch's first log-adding
  commit wrote it, and not when a remote's trunk holds that commit (`converted_versions`).
- Never deleted: refused when the merge base or HEAD has the log, unless the change undoes the
  conversion, every merged file back as the merge base had it (`unconverting`).
- Touches: while migrating, only the ids of the register's rows at the merge base are exempt
  (`migrated_ids`). The files `--merge-log` merges are CHANGELOG.md and a register (an entry
  file, or one named decisions.md): `merged_files_at`.
- The freeze names trunk: "release vX is frozen on main".

## Done-when evidence
- Symptom gone (sec_decisions, metarepo job ml after `--apply --merge-log` as commit A):
  `PASS  branch log: a later commit on the job changing a status line in its converted release passes`,
  `… adding ### Changed above its converted release's change line passes`,
  `… retitling a converted entry with no Touches line passes`.
- Revert: `PASS  branch log: reverting the conversion, staged and committed, passes with the counter on the register's rows`,
  and `PASS  branch log: jig check on the reverted tree, unstaged, agrees with the hook`.
- Beyond migration (sec_supersede, plain repo su, counter `^### D-(\d+)`):
  `PASS  branch log: reverting a job's supersede, staged and committed, passes with no R6`,
  `PASS  branch log: correcting a job's supersede to supersede D-002 instead passes with no R6`.
- Still refused on a branch: `PASS` for editing an entry trunk released (frozen on main),
  removing a released entry nothing supersedes, deleting a log trunk has, a new entry with no
  Touches line; plus the review's cases: a release a stale local trunk lacks, a reworded
  table row beside it, a stale trunk from before the log (status, dropped release, deleted
  log ×3), trunk's own release under a reused version, a conversion a remote's trunk holds,
  and a new numbered entry with no Touches on the converted branch.
- On trunk after the merge: `PASS  branch log: on trunk after the merge, the status-line edit is refused as frozen on main`.
- `bash tests/smoke.sh` (on 960e64b, synced with main): smoke_rc=0, 1061 PASS, 0 FAIL.
  `claude plugin validate ./plugin`: ✔ Validation passed. b50c6ed changes only the spec and DEFERRED.md.
- Controls: each round's new cases were run against the previous round's jig.py; exactly the
  new cases failed there (round 0: 6, round 1: 2, round 2: 4, round 3: 3 plus the revert's check).
- `grep -rnE 'Maige|maige|Daisy|daisy|"E-' plugin tests`: nothing new (0 added lines match).

## Review
Three rounds by the hubnode (Opus 5.5, effort read as unknown); round 3's final review found nothing blocking or should-fix.
- Round 1. B1 (blocking): a stale local trunk let a branch edit trunk's newer releases → HEAD's
  releases beyond the merge base are judged against HEAD; never-deleted also reads HEAD (fixed,
  93de8df). S1: the Touches exemption held for every commit on a migrated branch → only the
  register's ids (fixed). O1–O3 → DEFERRED.md.
- Round 2. 1 (blocking): a stale trunk from before the log reopened B1 through `migrating_log`,
  and `old_log_in_index` let the log go → option (b): exempt only releases in the merge base's
  CHANGELOG.md; the undo needs the merged files back byte-for-byte (fixed, a24377e). 2: a table
  row faked the conversion → `beyond` no longer depends on `migrating_log` (fixed). 3: one
  file set for every use, `merged_files_at` (taken).
- Round 3. A: any conversion counted as the branch's → intersect with the first log-adding
  commit's releases, nothing when a remote's trunk holds it (fixed, 960e64b); the no-remote
  case is a known limit in the spec, with `jig merge`'s hook as the backstop (b50c6ed). B: the
  undo compared unstripped text, so `jig check` disagreed with the hook (fixed).
- Deferred, with rows in .jig/ledgers/DEFERRED.md: rebase replaying trunk's conversion (t5),
  `added[0]` picking a stray add (t6, fails safe), concurrent conversions (t7), a second
  `## v0.1.0` from an untagged old v0.1.0, R3's line left to bug-r3-log-merge (O1), v0.1.0 vs
  v0.2.0 in the trunk smoke (O2), and the sec_touches grep (O3, no change needed).

## Fold-in
- [x] UNOWNED plugin/templates/jig/jig.py — no page needed because its documentation is `plugin/templates/jig/RULES.md`, updated here (Decision log, **Checked**: on a branch the log is judged from where the branch left trunk; a section is frozen once trunk has it). This repo has no docs tree for the checker.

## Shared files changed
- `plugin/templates/jig/jig.py`: the fix itself (shares).
- `plugin/templates/jig/RULES.md`: one sentence in Decision log, **Checked** (shares).
- `tests/smoke.sh`: the branch-log cases in sec_decisions and sec_supersede; three frozen
  greps now say "frozen on main"; `rment` also removes an entry at end of file (shares).
- `.jig/ledgers/DEFERRED.md`: the deferred review rows (common).
- `marketing/FEATURES.md` (hubnode's, main checkout, not changed here). Row changes:
  - R6 row: "the base had no match" → where the branch left trunk had no match (on trunk, the base).
  - Decision log row: released sections are frozen once trunk has them; on a branch the log is
    judged from where the branch left trunk, so a later commit may correct or revert an earlier
    one as their squash would. Trunk's releases a stale local trunk lacks stay frozen.

## Test by hand
In a jig repo with a released log, open a job, commit a supersede that removes a released
entry, then `git revert --no-commit HEAD && git commit -m "revert"`: it commits. Editing a
released entry on that branch is still refused with "release vX is frozen on main".

## Left
Nothing on this spec. The deferred rows above are follow-ups, not this job's.
