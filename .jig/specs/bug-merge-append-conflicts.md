# Bug: `jig merge` makes a job redo its DEFERRED.md rows: an append conflict aborts, rows beside the note refuse

Source: jig hubnode side session (Daisy survey), 2026-11-12, for the owner (staged as feedback-Daisy-2026-11-12-hubnode-merge-scripts.md): jig merge aborts when the only conflicts are in append files, so batch merges stop.
Source: Maige-Eco hubnode session / 2026-11-12 / Claude (Fable 5.2), filed on Dave's word ("Yes, file them") (staged as feedback-maige-ecosystem-2026-11-12-merge-log-conversion.md): jig merge refused a branch whose handoff commit also added the review's DEFERRED.md rows.

Checked against `plugin/templates/jig/jig.py` at 9d3b623. Both reports' `jig_version`,
`1a8efef0e75c`, is that file's blob here, unchanged since 15dc9f2. Daisy's section 2 (a repo's
post-merge steps) is another group's.

## Intent
A batch of gated jobs that each added DEFERRED.md rows merges back to back with `jig merge`
alone. A conflict where both sides only added is resolved in the merge exactly as `jig sync`
would resolve it, and rows a job adds to DEFERRED.md after its review don't count as a change
since the check.

## 1. Why
A. The append conflict
- Q: Why did `jig merge B` stop after `jig merge A`? A: Both added a row at DEFERRED.md's end.
  `cmd_merge`'s `appends` branch aborts any merge with an append-file conflict and names `jig sync`.
- Q: Why abort instead of resolving? A: Nov 2: on trunk the job is `theirs`, so resolving there
  needed `resolved_appends` reversed, "a second resolver to keep in step with sync's".
- Q: Why can't trunk use sync's own? A: It can: `changed_since` replays sync for any two commits
  (`merge-tree`, then `resolved_appends`). Root: `cmd_merge` alone merges trunk and a job without the rule.

B. Rows committed with the note
- Q: Why was C refused? A: `changed_since` counts every file changed after the note's `Commit:`
  except `.jig/handoffs/`, and C's note commit also added DEFERRED.md rows.
- Q: Why are the rows after the reviewed commit? A: When the hubnode records the review, a rows
  commit before the note makes `jig handoff` refuse. AGENTS.md says the rows come "at handoff".
- Q: Why do notes pass and rows not? A: bug-r6-m5-decisions-dest: "Handoff notes are the only
  bookkeeping made after a review by design." The rows are made then too. Root: one file short.

## 2. Givens
A
- `[seen]` Repro, a throwaway repo on `jig init`'s defaults with DEFERRED.md from the template:
  jobs A and B each add a row in their reviewed commit, both gated. `jig merge A` passes;
  `jig merge B` exits 1, "merging B conflicts in append files (.jig/ledgers/DEFERRED.md): `jig
  sync` the job, then merge again", trunk clean.
- `[seen]` `cmd_merge` runs `git merge --no-ff --no-commit` without diff3 and aborts on any
  conflicted file in `append_globs`.
- `[seen]` `BOARD_DEFAULTS` puts `.jig/ledgers/**` in `append_files`, and the review skill gives
  every untaken should-fix or optional finding a DEFERRED.md row: most handoffs append at the
  same table end.
- `[seen]` `jig sync` in B, then `jig merge B`, passes with no new note. Trunk's DEFERRED.md then
  equals, byte for byte, `resolved_appends` of `git merge-tree --write-tree B main`, computed on
  trunk beforehand without touching B.
- `[seen]` `resolved_appends` run on trunk's side of a diff3 merge writes the job's row above
  trunk's: the reverse of sync's "trunk's lines, then the job's".
- `[seen]` Prototype, in the throwaway repo's copy of `jig.py`: `cmd_merge` takes each conflicted
  append file from that replay. B merges, the rows read base, A, B, and the hooks accept it. A
  job whose edit of the base row meets A's append still stops with today's message. The merge
  message kept git's `# Conflicts:` lines: `git commit --no-edit` doesn't strip them.
- `[seen]` Daisy's trunk, 2026-11-08: 96b3a348, 6abac451, 2a3868a0 and d5b7869e say "DEFERRED
  rows of both sides kept"; their combined diffs show both sides' rows, resolved on trunk by hand.
- `[assumed]` Daisy's `merge-lane.sh` stripped markers with no base check. The scripts are gone
  from `.git/jig/manager/`, so this is the report's `[seen]`, not mine. Nothing here depends on it.
- `[seen]` RULES.md step 3 and the hubnode's "After a merge" already say to sync the clean jobs
  after each merge; subnode step 5 lets a subnode keep building after its handoff, so its
  worktree may not be clean to sync.

B
- `[seen]` Repro: job C commits its note and one DEFERRED.md row together after `jig reviewed`.
  `jig merge C`: "C has changed since the commit .jig/handoffs/C-2026-11-12.md names
  (.jig/ledgers/DEFERRED.md)". `jig sync` doesn't change that; a second `jig reviewed --tier 2
  --effort 3` and `jig handoff` at the tip merges it, the reporter's way through.
- `[seen]` Repro, the hubnode-run review: the review recorded on D's commit, then D commits its
  rows, and `jig handoff` refuses, "no adversarial review on record for this commit". Subnode
  step 3: never a bare `jig reviewed` after the hubnode's.
- `[seen]` AGENTS.md template: a deferred finding "gets a row in `.jig/ledgers/DEFERRED.md` at
  handoff"; DEFERRED.md's own header: "not taken at handoff".
- `[seen]` Daisy's 8cad757b, 2026-11-08: "the branch tip adds the handoff note and two DEFERRED
  rows after the gated commit 2a7ed532, merged by hand".
- `[seen]`, in code: `counts_reviewed` (M5, in a metarepo) asks `changed_since` too, so a plain
  `git merge` of C's tip is refused there the same way.
- `[seen]` Prototype: after the note, a DEFERRED.md change that only adds lines passes; one that
  removes a row, and a code change, still refuse, naming the file.

## 3. One layer up
- A: `jig sync` and `jig gate` merge trunk and a job through `merge_trunk`, and `changed_since`
  replays that merge with `merge-tree`. `cmd_merge` is the one that doesn't. The replay is the
  existing pattern: run for (job, trunk), it is sync's resolution by construction, so there is
  no second resolver to keep in step.
- B: `changed_since` already leaves out `.jig/handoffs/`, made after the check by design. The
  note's `## Review` heading holds the same findings as the rows; only the ledger's copy counts.

## 4. Workaround or correction
Both are corrections: each changes the path that differs from its healthy sibling.
- A: when every conflicted file is an append file and each resolves cleanly in the replay,
  `cmd_merge` writes the replay's text, `git add`s it, prints that it resolved them as `jig sync`
  would, and goes on as a clean merge does (numbering, the roadmap view), with the merge's own
  message. Anything else (a non-append conflict beside them, an append conflict that edits a
  line, git older than 2.38) gets today's refusal, unchanged.
- B: `changed_since` leaves out a change to `.jig/ledgers/DEFERRED.md` that only adds lines,
  beside handoff notes, in both its branches (a job's own commit, and what a sync's resolution
  carries beyond the replay).

Two roots, one spec. A is the merge lacking sync's rule; B is the check's exemption. Both make a
job redo work over DEFERRED.md rows that nobody reviews and that jig handles mechanically
elsewhere. Daisy's batch hit both (8cad757b beside 96b3a348), and both change `cmd_merge`'s
refusals, RULES.md's step 3 and smoke's `fu-sync` section.

## 5. Spec

### Done when
Smoke, in a throwaway repo on `jig init`'s defaults with a DEFERRED.md holding one row:
- [ ] Jobs A and B each add a row at DEFERRED.md's end in their reviewed commit; both gated.
      `jig merge A`, then `jig merge B`, both exit 0 with no `jig sync` and no new note. B's
      branch tip is unchanged, and trunk's DEFERRED.md holds the base row, A's, then B's, with
      no conflict marker. (Daisy's symptom: the batch merges with no sync and no hand resolution.)
- [ ] The fix fires for A: `jig merge B` prints a line naming `.jig/ledgers/DEFERRED.md` as
      resolved the way `jig sync` resolves it, and the merge commit's message is `merge B` with
      no `# Conflicts:` line.
- [ ] Still refused as today, trunk clean and no `MERGE_HEAD`: a job whose DEFERRED.md edit of
      the base row meets A's append; the existing `fu-sync` job conflicting in an append file and
      `common.txt`; the first box's B under the existing git 2.30 shim.
- [ ] Job C commits its note and a DEFERRED.md row together after `jig reviewed`; `jig merge C`
      exits 0 with no second record. (Maige-Eco's symptom.)
- [ ] The fix fires for B: a twin of C whose note commit also rewords the base row is refused,
      naming DEFERRED.md. So is a commit after the note that adds a line to `AGENTS.md`, and the
      existing code-change case.
- [ ] `fu-sync`'s "L, unsynced, conflicts only in CHANGELOG.md: refused" now expects L merged
      with no sync; its git 2.38 case still refuses.
- [ ] RULES.md, Handoff step 1: the note and the review's DEFERRED.md rows may be one commit after
      the review. Step 3: a conflict in an append file where both sides only added is resolved in
      the merge as `jig sync` resolves it; anything else is still sent to `jig sync`. The M5 row
      lists added DEFERRED.md rows beside handoff notes. Subnode step 4 commits the rows with the
      note. FEATURES.md's `merge` and `append_files` rows say what changed.
- [ ] `bash tests/smoke.sh` passes, and `claude plugin validate ./plugin` passes.

### Out of scope
- Daisy's section 2, a repo's post-merge steps: another group.
- A conflict that mixes an append file with another file: still sent to `jig sync`, where the
  job resolves the rest and runs its checks.
- Additions to other ledgers or append files after the check: a BUFFER.md row is a contract
  statement P2 reads, a log entry is a decision, a WORKAROUNDS.md row comes with its code.
- When the hubnode syncs open jobs.

### Touches
- `plugin/templates/jig/jig.py`: `cmd_merge`'s `appends` branch and its commit; `changed_since`
  (its replay as a helper `cmd_merge` shares, and the DEFERRED.md exemption); `counts_reviewed`'s
  docstring.
- `plugin/templates/jig/RULES.md`: Handoff, gate, merge, steps 1 and 3; the M5 row.
- `plugin/skills/subnode/SKILL.md`: step 4.
- `tests/smoke.sh`: the `fu-sync` section.
- `marketing/FEATURES.md`: the `merge` and `append_files` rows.

No new dependency. No contract path.

### Alternatives considered
- Keep the refusal and sync the next job before each merge — rejected because RULES.md and the
  hubnode skill already say so, and Daisy's hubnode still resolved on trunk by hand, the outcome
  the refusal was meant to prevent; and a job still building can't be synced clean — this
  reason is [seen] (Daisy's four merges; subnode step 5).
- The report's correction: diff3 in trunk's merge, then `resolve_appends` on each file — rejected
  because on trunk the job is `theirs`, so it writes the job's rows above trunk's, the reverse of
  the sync and the gate; a flag to flip it is the second resolver Nov 2 rejected — this reason
  is [seen] (the repro).
- `jig merge` runs `jig sync` in the job's worktree first — rejected because it commits on a
  branch the subnode may be building on, and the owner ruled it out on Nov 2 — this reason is
  [seen] (report-fixes-followup.md, Decisions).
- For B, commit the rows before the review is recorded, and say so in the skills — rejected
  because with a hubnode-run review that commit makes `jig handoff` refuse until a second
  record, which subnode step 3 warns against, and the note's Review heading, already exempt,
  carries the same findings — this reason is [seen] (the repro).
- Leave out any `.jig/ledgers/**` change, or any append-file addition, after the check —
  rejected for bug-r6-m5-decisions-dest's reason: a branch could slip unreviewed ledger or log
  edits into trunk — this reason is [seen] (that spec's Alternatives).
- Leave out every DEFERRED.md change, edits too — rejected because an edit or a removal after
  the check rewrites a disposition no one saw — this reason is [assumed].

### Decisions
- Pending the owner: A revisits "Owner, Nov 2: agreed with both calls. Item 6 refuses and names
  `jig sync`; `jig merge` doesn't sync a job itself." (report-fixes-followup.md). The refusal
  goes for a conflict where both sides only added; "doesn't sync a job itself" still holds,
  since the job's branch is untouched. What is new: the batch cost and the hand resolutions on
  Daisy's trunk, and the replay, which answers "a second resolver".
- B supersedes bug-r6-m5-decisions-dest's "Handoff notes are the only bookkeeping made after a
  review by design": the review's added DEFERRED.md rows are too.
- No new gate for A: the tree `jig merge` now writes is the one `jig sync` then `jig merge`
  writes, which merges today with no new gate. `[seen]`: the byte-identical replay.
- The merge commit uses the merge's own message: the prototype's `git commit --no-edit` kept
  git's `# Conflicts:` lines.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
