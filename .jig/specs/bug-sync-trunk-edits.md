# A sync is judged against trunk, and a moved line isn't new

Source: adventure-studio hubnode session / 2026-11-16 / Dave (staged as feedback-adventure-studio-2026-11-16-sync-judged-for-trunk-edits.md): "A sync is refused for an edit that came from trunk, and moving entries marks untouched ones as changed"

## Intent
Two independent fixes. The report thought they shared a cause; they don't, so each part has its
own whys and checks.
1. While a merge of trunk is being finished, R3's decision-log check judges the result against
   trunk, as RULES.md already promises. A `jig sync` that brings in trunk's in-place edit of an
   accepted entry commits.
2. The boundary rule's "added line" is decided by content, not by position: text the change
   only moves within a file (an entry accepted from `## Open` to `## Unreleased`, a paragraph
   in a page) is not added text.

This spec replaces `bug-r3-log-merge.md` (2026-11-11), which specced part 1 from this repo's
earlier report and was never built.

## Why
Part 1, the sync refused:
1. Why R3? The log check compared the merged log with `merge-base(trunk, HEAD)`, so trunk's
   in-place edit of an accepted line read as the job deleting it. [seen]
2. Why that base? While a merge is being finished, HEAD is still the job's tip, so the merge
   base is the old fork point. Only R3's log branch reads it raw. [seen]
3. Why not fixed already? `since_trunk()` handles this case (ff3d9a6, 11-12), but the R3 line
   was deferred to `bug-r3-log-merge`, which was never built. [seen]

Root: R3's log branch computes its own old side instead of calling `since_trunk()`.

Part 2, untouched entries refused:
1. Why was D-001 judged? The boundary rule reads added lines from a positional `git diff -U0`,
   and the move made git show D-001's heading and scope line as removed and re-added. [seen]
2. Why would a move read as added? A line diff can't show a reorder. One side of every move is
   a delete plus an add, under histogram too. [seen]
3. Why "names no page it touches" next? The touches rule compares each entry by id and text,
   and only the reword changed D-001. The move alone didn't. [seen]

Root: "added" is decided by where a line sits in the diff, not by whether its text is new to
the file.

## Givens
Part 1:
- [seen] Reproduced on main (c33c0d0) in a throwaway repo, with the reporter's done-when: the job
  adds a `D-?` entry under `## Open` and a DEFERRED.md row; trunk rewrites one line of accepted
  D-001 under `## Unreleased` and adds a DEFERRED.md row. `jig sync` exits 2 with "R3
  .jig/decisions.md: a job adds to the log, and changes lines in place only under ## Open", and
  the merge is left in progress. Without the DEFERRED rows (a clean merge, so the
  pre-merge-commit path) it fails the same way.
- [seen] `check_rules`, R3's log branch (jig.py ~652): `since = git("merge-base", trunk, "HEAD")
  or base(trunk)`. `merge-base` always answers, so `base()` never runs.
- [seen] `since_trunk()` (~423) returns `base()` on trunk, on a detached HEAD, or while
  finishing a merge of trunk. `base()` is trunk under pre-merge-commit, or `MERGE_HEAD` when
  that is trunk's. Otherwise `since_trunk()` returns the fork point. `log_rules`,
  `migrating_log`, `migrated_ids` and `reserved_refusals` already read it.
- [seen] In a scratch copy, that line changed to `since = since_trunk(trunk)`:
  - Both paths commit.
  - `jig merge` then merges with no new handoff. The `D-?` is numbered, and trunk's rewritten
    line is kept.
  - A sync whose resolution rewrites an accepted line is still refused R3, and so is a plain
    job commit that does.
- [seen] RULES.md, under the R-rules: "While a merge of trunk is being finished, a change is judged
  against trunk, so what trunk brought in is not the job's."
- [seen] `bug-r3-log-merge.md` (6a87431) has the same symptom from this repo's 11-11 report and
  the same design. No job or commit built it. DEFERRED.md's 2026-11-12 row "R3's log rule still
  reads the raw merge base, not `since_trunk`" defers to it.
- [seen] The reporter's first step no longer happens on main. Since a2720f4 (2026-11-13),
  `jig merge` resolves an append-only conflict the way sync would, and in the repro it merged
  the unsynced job. Sync is still how a job takes trunk: `jig merge` says "Sync the clean jobs."
  after each merge.
- [seen] The report's `jig_version` 1a8efef0e75c is the plugin's jig.py of 2026-11-12, from
  before ff3d9a6. R3's line has not changed since.
- [seen] The report's why 3 was [assumed], and is now seen with one correction: the old side is
  the fork point, not the first parent. The effect is the same.

Part 2:
- [seen] Reproduced on main with the reporter's done-when:
  - Setup: A, B, C under `## Open`. B has no `Touches:` and its body names `` `exits/capital-event` ``,
    a roadmap scope in code quotes. All three were committed before the rules, with the hooks
    bypassed.
  - A and C are moved to `## Unreleased` as accepted.
  - `jig check` (`rules`) and the commit both refuse: "line 11 names `exits/capital-event`, the
    project's".
  - `git diff -U0` shows B's heading and scope line as added.
- [seen] Rewording B's line, as the hubnode did, then gives "D-001 names no page it touches".
  `log_entries` sees B's block as equal after the move and as changed only after the reword.
- [seen] An entry that is itself moved and accepted, with such a line in its own body, is
  refused too, with `diff.algorithm=histogram` as well. So every acceptance of an entry that
  holds old text is refused.
- [seen] A page's old line moved within the same page is refused on main.
- [seen] `added_lines` (~8807) feeds only `boundary_rules`: project paths, quoted scope ids, root
  documents. It follows renames, so "a moved page's old lines aren't new" (RULES.md), but it
  doesn't follow moves within a file.
- [seen] `touches_problems` already compares per entry by id and block text, which is the
  report's proposed correction for that rule.
- [seen] In a scratch copy with the net count (Design), these commit: the done-when case, the
  moved-and-accepted case, and the moved page line. A new line naming the scope is still
  refused, and so is a second copy of B's line in a new entry.
- [seen] Survey still lists old text in pages and the log apart (RULES.md, the boundary
  paragraphs), so no old text drops out of view.
- [seen] With both changes in a scratch clone, the smoke sections rules, metarepo, boundary,
  decisions, supersede, touches, roadmap, merge_after_sync, cheaper_rounds, removals, glossary
  and merge_log: 489 PASS, 0 FAIL. No existing case relies on a moved line reading as added, or on
  R3 using the fork point during a sync.
- [assumed] The reporter's eight-entry move lined up like the three-entry repro. Their text
  isn't here. The fix doesn't depend on how the diff lines up: it ignores position.

## One layer up
- Part 1, siblings: every other old side `check_rules` reads goes through `base()`
  (`changed_paths`, `added_lines`, R7, `changelog_only_grows`) or `since_trunk()` (`log_rules`,
  `reserved_refusals`). R3's log branch is the only one left [seen].
  - M3 (`meta_rules`, metarepo only) reads `merge-base(HEAD, trunk, trunk@{u})` on purpose
    ("judged on the branch since it left trunk"). During a sync, trunk's changes to cited files
    arrive with trunk's own log entries, so M3 should still pass [assumed, not reproduced].
  - `changed_since`/`replay_sync` (cheaper-rounds) judge a synced job by replaying the merge.
    They don't change, and with the fix the sync's commit matches the replay, so `jig merge`
    passes [seen].
- Part 1, pattern: `since_trunk()` is this codebase's fix for exactly this shape.
- Part 2, sibling: docs pages go through the same `added_lines` and have the same problem [seen].
- Part 2, pattern: DEFERRED.md is judged by its net change, a `Counter` of rows
  (`deferred_deleted`: "a row edited and restored later deleted nothing"). Counting text instead
  of trusting the diff's positions is the same shape [seen].

## General?
- Part 1 is general: any repo where trunk edits a log line outside `## Open` in place while an
  open job has added to the log.
- Part 2 is general: every acceptance moves an entry. Any log or page still holds old text from
  before the boundary rule until the owner sweeps it, and `jig update` lists that text without
  forcing the sweep.

## Design
- **Part 1.** R3's log branch reads `since = since_trunk(trunk)`. That's one line, and RULES.md
  already says it, so RULES.md needs no change.
- **Part 2.** `added_lines` keeps an added line only while that file's diff adds its text more
  times than it removes it.
  - It keeps one `Counter` per file over the same `-U0 -M` diff: each `+` line counts up, each
    `-` line counts down, and each line kept uses up one.
  - Lines are counted only inside hunks, so the `--- a/` and `+++ b/` headers are never content.
  - The docstring says a moved line is not an added one.
  - Line numbers still come from the diff.
- **RULES.md**, the boundary paragraph: "a moved page's old lines aren't new" becomes "a moved
  page's old lines, or a line moved within a file, aren't new".
- **`marketing/FEATURES.md`**, the row "Boundary held at creation, not by search": one clause
  saying a moved line isn't created. The hook's refusals of new text are unchanged.

## Done when
Part 1, in the smoke `decisions` section:
- [ ] The reporter's done-when (the reported symptom gone):
  - The job adds `### D-?<slug>` under `## Open` and a DEFERRED.md row, then hands off.
  - On trunk, one line of an accepted entry's body under `## Unreleased` is rewritten, and a
    DEFERRED.md row is added.
  - `jig sync` in the job's worktree exits 0 and prints "append conflicts resolved
    automatically". Its output has no `R3 .jig/decisions.md`, no `MERGE_HEAD` is left, and HEAD
    has two parents.
  - Then, gated, `jig merge` merges with no new handoff. Trunk's log holds the rewritten line
    and the job's entry with a number.
- [ ] The same with no DEFERRED.md rows, which is the pre-merge-commit path: `jig sync` exits 0
      and prints "nothing to resolve".
- [ ] Controls, both refused with `R3 .jig/decisions.md`: a sync merge whose resolution rewrites
      an accepted line trunk has, and a plain job commit that does the same.

Part 2, in the smoke `boundary` section, with a roadmap that has a scope:
- [ ] The reporter's done-when (the reported symptom gone):
  - A, B and C sit under `## Open`, committed with the hooks off. B has no `Touches:` and names
    the scope in code quotes.
  - Moving A and C to `## Unreleased` as accepted commits, and `jig rules` prints `ok`.
  - Nothing in the output names the scope, and B is byte for byte unchanged.
- [ ] An entry whose own body names the quoted scope, moved and accepted, commits.
- [ ] A page's old line naming the scope, moved within the page, commits.
- [ ] Controls, both refused with "names `…`, the project's": a new line naming the scope, and a
      second copy of an existing such line added in a new entry.
- [ ] The existing rename cases in the `boundary` section still pass.

Both parts:
- [ ] `.jig/scripts/check.sh` passes.
- [ ] The smoke sections `decisions`, `boundary`, `rules`, `merge_after_sync` and
      `cheaper_rounds` pass.
- [ ] `claude plugin validate ./plugin` passes.
- [ ] `grep -rni adventure plugin` finds nothing.

## Out of scope
- The touches rule on an accepted entry. Accepting an entry changes its status line, so its
  block changes, and M2 asks an entry added or changed to name its pages. The report asks that a
  status-only change not count. That would change M2, which is the owner's call, not this bug.
  Part 2 alone clears the reported untouched entries [seen].
- M3's old side during a sync: assumed harmless (One layer up), and it isn't in the symptom.
- `jig merge` refusing an append-file conflict (the report's first step): fixed by a2720f4.
- The hubnode skill's hand-merge route for a refusal before `jig merge` starts (the report's
  why 4). That refusal no longer happens for append conflicts, and with part 1 the sync it
  points to works.
- Dropping `bug-r3-log-merge.md` and closing its DEFERRED.md row: the hubnode does that when
  this job opens and when it merges.

## Touches
- `plugin/templates/jig/jig.py` (`check_rules`, R3's log branch; `added_lines`)
- `plugin/templates/jig/RULES.md` (the boundary paragraph, one clause)
- `tests/smoke.sh` (`decisions`, `boundary`)
- `marketing/FEATURES.md` (the "Boundary held at creation" row)

## Alternatives considered
- Part 1: the report's correction, which compares the diff from the merge base to the first
  parent — rejected because the first parent is the job's tip before the merge, so that diff
  can't hold a rewrite hidden in the sync's resolution. `since_trunk()` compares trunk with the
  result and catches it (control A) — this reason is [seen].
- Part 1: skip R3's log check during any merge of trunk — rejected because a sync could then
  carry the job's own rewrite of trunk's line — this reason is [seen] (control A).
- Part 1: build `bug-r3-log-merge.md` as written, as a job of its own — rejected because its
  design is now this one line, since its helper already exists. Two specs for one cause would
  split the work — this reason is [seen] (`since_trunk`'s docstring, DEFERRED.md row of 11-12).
- Part 2: the report's per-entry comparison for the boundary rule (judge only the lines of an
  entry whose block changed) — rejected because accepting an entry always changes its block, so
  its old text is still judged by the positional diff, and pages have no entries — this reason
  is [seen] (the moved-and-accepted repro; `log_entries` shows the accepted entries changed).
- Part 2: a different diff algorithm (histogram, patience) — rejected because a reorder is a
  delete plus an add under any line diff. Histogram still refused the moved entry — this reason
  is [seen].
- Part 2: text already in HEAD's file is never new (a set, not a count) — rejected because a
  second copy of an old line would pass, and the count keeps it new — this reason is [seen]
  (control 2 refused under the count).
- Part 2: `git diff --color-moved` to mark moves — rejected because it's a display option with a
  minimum block size, so a single moved line isn't marked, and it would mean parsing colour
  codes — this reason is [assumed].

## Decisions
- The count is per file, as `added_lines` is: a line moved from one page to another is new to
  the page it lands on, as it is today.
- One spec, two parts with their own Done when. Both are small rule-reading fixes in jig.py,
  built in one job. The causes are separate, so a reviewer judges each part apart.
- This spec replaces `bug-r3-log-merge.md`: same symptom, same design, and the old spec's Done
  when is carried into part 1.

## Workflow
spec: tier 2, effort 2
bug: tier 2, effort 1
execute: tier 2, effort 3
review: tier 2, effort 2
check: tier 3, effort 4
